import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Inventory Domain Lifecycle & Stock Ledger (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  const testCid = `e2e_inv_${Date.now()}`;

  let testRawMaterialId: string;
  let testFinishedProductId: string;
  let testCategoryId: string;
  let testUnitId: string;
  const testRmCode = `RM-INV-${Date.now().toString().slice(-4)}`;
  const testFpCode = `FP-INV-${Date.now().toString().slice(-4)}`;
  const createdAdjustmentIds: string[] = [];
  const createdMovementIds: string[] = [];
  const createdAlertIds: string[] = [];

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    db = app.get(DatabasePool);

    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );

    await app.init();

    // 1. Authenticate as Admin
    const loginRes = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCid)
      .send({
        email: 'admin@deluzex.com',
        password: 'Admin@123',
      });

    expect(loginRes.status).toBe(200);
    accessToken = loginRes.body.data.accessToken;

    // 2. Obtain Category and Unit for test items
    const catRes = await db.query<{ id: string }>('SELECT id FROM categories LIMIT 1');
    testCategoryId = catRes.rows[0].id;
    const unitRes = await db.query<{ id: string }>('SELECT id FROM measurement_units LIMIT 1');
    testUnitId = unitRes.rows[0].id;

    // 3. Create test Raw Material
    const rmRes = await db.query<{ id: string }>(
      `INSERT INTO raw_materials (name, item_code, category_id, unit_id, opening_stock, current_stock, minimum_stock, default_purchase_price)
       VALUES ($1, $2, $3, $4, 100.0000, 100.0000, 20.0000, 500.00)
       RETURNING id`,
      ['Test Aluminum Extrusion', testRmCode, testCategoryId, testUnitId],
    );
    testRawMaterialId = rmRes.rows[0].id;

    // 4. Create test Finished Product
    const fpRes = await db.query<{ id: string }>(
      `INSERT INTO finished_products (name, item_code, category_id, unit_id, opening_stock, current_stock, minimum_stock, cost_price, dealer_selling_price, customer_selling_price)
       VALUES ($1, $2, $3, $4, 50.0000, 50.0000, 10.0000, 1500.00, 2200.00, 2500.00)
       RETURNING id`,
      ['Test LED Chandelier', testFpCode, testCategoryId, testUnitId],
    );
    testFinishedProductId = fpRes.rows[0].id;
  });

  afterAll(async () => {
    // Automated database teardown per Directive 2 (MANDATORY DB TEST CLEANUP)
    try {
      if (createdAlertIds.length > 0) {
        await db.query(`DELETE FROM low_stock_alerts WHERE id = ANY($1::uuid[])`, [createdAlertIds]);
      }
      if (createdMovementIds.length > 0) {
        await db.query(`DELETE FROM stock_movements WHERE id = ANY($1::uuid[])`, [createdMovementIds]);
      }
      if (createdAdjustmentIds.length > 0) {
        await db.query(`DELETE FROM stock_adjustments WHERE id = ANY($1::uuid[])`, [createdAdjustmentIds]);
      }
      // Also clean any movements matching our test item IDs
      await db.query(`DELETE FROM stock_movements WHERE item_id IN ($1, $2)`, [testRawMaterialId, testFinishedProductId]);
      await db.query(`DELETE FROM stock_adjustments WHERE item_id IN ($1, $2)`, [testRawMaterialId, testFinishedProductId]);
      await db.query(`DELETE FROM low_stock_alerts WHERE item_id IN ($1, $2)`, [testRawMaterialId, testFinishedProductId]);

      if (testRawMaterialId) {
        await db.query(`DELETE FROM raw_materials WHERE id = $1`, [testRawMaterialId]);
      }
      if (testFinishedProductId) {
        await db.query(`DELETE FROM finished_products WHERE id = $1`, [testFinishedProductId]);
      }
    } catch (err) {
      console.error('Teardown cleanup error:', err);
    } finally {
      await app.close();
    }
  });

  describe('6.1 Get Raw Materials Stock', () => {
    it('should return summary metrics and paginated raw materials stock list', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/inventory/raw-materials')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.summary).toBeDefined();
      expect(typeof res.body.data.summary.totalItems).toBe('number');
      expect(typeof res.body.data.summary.totalValuation).toBe('number');
      expect(Array.isArray(res.body.data.items)).toBe(true);

      const found = res.body.data.items.find((i: any) => i.id === testRawMaterialId);
      expect(found).toBeDefined();
      expect(found.itemCode).toBe(testRmCode);
      expect(Number(found.currentStock)).toBe(100);
    });
  });

  describe('6.2 Get Finished Products Stock', () => {
    it('should return summary metrics and finished products with available stock', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/inventory/finished-products')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.summary).toBeDefined();
      expect(typeof res.body.data.summary.totalSkus).toBe('number');
      expect(Array.isArray(res.body.data.items)).toBe(true);

      const found = res.body.data.items.find((i: any) => i.id === testFinishedProductId);
      expect(found).toBeDefined();
      expect(found.itemCode).toBe(testFpCode);
      expect(Number(found.currentStock)).toBe(50);
      expect(Number(found.availableStock)).toBe(50);
    });
  });

  describe('6.4 Perform Stock Adjustment (Transactional & Immutable Ledger)', () => {
    it('should adjust raw material stock, update balance, and record movement in ledger', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/inventory/stock-adjustments')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          itemId: testRawMaterialId,
          itemType: 'rawMaterial',
          adjustedStockAfter: 125.5,
          reason: 'physicalCountMismatch',
          remarks: 'Physical audit revealed 25.5 extra meters in Bay 2',
        });

      expect(res.status).toBe(201);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.adjustmentNumber).toBeDefined();
      expect(Number(res.body.data.currentStockBefore)).toBe(100);
      expect(Number(res.body.data.adjustedStockAfter)).toBe(125.5);
      expect(Number(res.body.data.adjustmentQuantity)).toBe(25.5);
      createdAdjustmentIds.push(res.body.data.id);

      // Verify the item's current_stock in database was directly updated
      const checkDb = await db.query<{ current_stock: string }>(
        'SELECT current_stock FROM raw_materials WHERE id = $1',
        [testRawMaterialId],
      );
      expect(Number(checkDb.rows[0].current_stock)).toBe(125.5);
    });

    it('should adjust finished product stock downwards for damaged goods', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/inventory/stock-adjustments')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          itemId: testFinishedProductId,
          itemType: 'finishedProduct',
          adjustedStockAfter: 48,
          reason: 'damagedGoods',
          remarks: '2 units broken during transit',
        });

      expect(res.status).toBe(201);
      expect(res.body.data).toBeDefined();
      expect(Number(res.body.data.adjustmentQuantity)).toBe(-2);
      createdAdjustmentIds.push(res.body.data.id);

      const checkDb = await db.query<{ current_stock: string }>(
        'SELECT current_stock FROM finished_products WHERE id = $1',
        [testFinishedProductId],
      );
      expect(Number(checkDb.rows[0].current_stock)).toBe(48);
    });

    it('should reject invalid adjustment reason with 400 Bad Request', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/inventory/stock-adjustments')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          itemId: testRawMaterialId,
          itemType: 'rawMaterial',
          adjustedStockAfter: 100,
          reason: 'invalid_reason_string',
        });

      expect(res.status).toBe(400);
    });
  });

  describe('6.3 Stock Movement Ledger', () => {
    it('should retrieve immutable audit entries for the adjustments made', async () => {
      const res = await request(app.getHttpServer())
        .get(`/api/v1/inventory/stock-movements?itemId=${testRawMaterialId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data).toBeDefined();
      expect(Array.isArray(res.body.data.items)).toBe(true);
      expect(res.body.data.items.length).toBeGreaterThanOrEqual(1);

      const movement = res.body.data.items[0];
      expect(movement.itemId).toBe(testRawMaterialId);
      expect(movement.transactionType).toBe('adjustment');
      expect(Number(movement.stockIn)).toBe(25.5);
      expect(Number(movement.currentBalance)).toBe(125.5);
      createdMovementIds.push(movement.id);
    });
  });

  describe('6.4 Stock Adjustments History', () => {
    it('should list historical stock adjustments', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/inventory/stock-adjustments')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data).toBeDefined();
      expect(Array.isArray(res.body.data.items)).toBe(true);
      expect(res.body.data.items.length).toBeGreaterThanOrEqual(2);
    });
  });

  describe('6.5, 6.6, 6.7 Low Stock Alerts', () => {
    let alertId: string;

    it('should trigger and persist a low stock alert', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/inventory/trigger-low-stock-alert')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          itemId: testRawMaterialId,
          itemType: 'rawMaterial',
          recipientId: 'REC-001',
          recipientName: 'Warehouse Head',
          recipientWhatsApp: '+919876543210',
          customMessage: 'Raw material stock is approaching critical minimum.',
        });

      expect(res.status).toBe(201);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.id).toBeDefined();
      expect(res.body.data.status).toBe('triggered');
      alertId = res.body.data.id;
      createdAlertIds.push(alertId);
    });

    it('should list low stock alert history with triggered status', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/inventory/low-stock-alerts')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data).toBeDefined();
      expect(Array.isArray(res.body.data.items)).toBe(true);

      const found = res.body.data.items.find((a: any) => a.id === alertId);
      expect(found).toBeDefined();
      expect(found.status).toBe('triggered');
    });

    it('should resolve the low stock alert', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/api/v1/inventory/low-stock-alerts/${alertId}/resolve`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.status).toBe('resolved');
      expect(res.body.data.resolvedAt).toBeDefined();
    });
  });
});
