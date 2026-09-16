import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Manufacturing & Production Domain Lifecycle (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  const testCid = `e2e_production_${Date.now()}`;

  let testCategoryId: string;
  let testUnitId: string;
  let testRawMaterialId1: string;
  let testRawMaterialId2: string;
  let testFinishedProductId: string;

  const testRmCode1 = `RM-PRD1-${Date.now().toString().slice(-4)}`;
  const testRmCode2 = `RM-PRD2-${Date.now().toString().slice(-4)}`;
  const testFpCode = `FP-PRD-${Date.now().toString().slice(-4)}`;
  const createdOrderIds: string[] = [];
  const createdBomIds: string[] = [];

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

    // Authenticate as Super Admin
    const loginRes = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCid)
      .send({
        email: 'admin@deluzex.com',
        password: 'Admin@123',
      });

    expect(loginRes.status).toBe(200);
    accessToken = loginRes.body.data.accessToken;

    // Fetch Category and Unit
    const catRes = await db.query<{ id: string }>('SELECT id FROM categories LIMIT 1');
    testCategoryId = catRes.rows[0].id;
    const unitRes = await db.query<{ id: string }>('SELECT id FROM measurement_units LIMIT 1');
    testUnitId = unitRes.rows[0].id;

    // Create Test Raw Materials with Initial Stock
    const rm1Res = await db.query<{ id: string }>(
      `INSERT INTO raw_materials (
         name, item_code, category_id, unit_id, opening_stock, current_stock,
         minimum_stock, reorder_level, default_purchase_price, gst_percent
       ) VALUES ($1, $2, $3, $4, 100.0000, 100.0000, 10.0000, 20.0000, 250.00, 18.00)
       RETURNING id`,
      ['Test Aluminum Ingot', testRmCode1, testCategoryId, testUnitId],
    );
    testRawMaterialId1 = rm1Res.rows[0].id;

    const rm2Res = await db.query<{ id: string }>(
      `INSERT INTO raw_materials (
         name, item_code, category_id, unit_id, opening_stock, current_stock,
         minimum_stock, reorder_level, default_purchase_price, gst_percent
       ) VALUES ($1, $2, $3, $4, 50.0000, 50.0000, 5.0000, 10.0000, 400.00, 18.00)
       RETURNING id`,
      ['Test LED Driver', testRmCode2, testCategoryId, testUnitId],
    );
    testRawMaterialId2 = rm2Res.rows[0].id;

    // Create Test Finished Product
    const fpRes = await db.query<{ id: string }>(
      `INSERT INTO finished_products (
         name, item_code, category_id, unit_id, opening_stock, current_stock,
         minimum_stock, cost_price, dealer_selling_price, customer_selling_price, gst_percent
       ) VALUES ($1, $2, $3, $4, 5.0000, 5.0000, 2.0000, 1200.00, 1800.00, 2200.00, 18.00)
       RETURNING id`,
      ['Test Architectural Light Bar', testFpCode, testCategoryId, testUnitId],
    );
    testFinishedProductId = fpRes.rows[0].id;
  });

  afterAll(async () => {
    // Deterministic Auto-Cleanup
    if (createdOrderIds.length > 0) {
      await db.query(`DELETE FROM stock_movements WHERE reference_number IN (
        SELECT production_number FROM production_orders WHERE id = ANY($1)
      )`, [createdOrderIds]);
      await db.query('DELETE FROM production_raw_materials WHERE production_order_id = ANY($1)', [createdOrderIds]);
      await db.query('DELETE FROM production_orders WHERE id = ANY($1)', [createdOrderIds]);
    }
    if (createdBomIds.length > 0) {
      await db.query('DELETE FROM bom_items WHERE bom_id = ANY($1)', [createdBomIds]);
      await db.query('DELETE FROM bill_of_materials WHERE id = ANY($1)', [createdBomIds]);
    }
    await db.query('DELETE FROM raw_materials WHERE id IN ($1, $2)', [testRawMaterialId1, testRawMaterialId2]);
    await db.query('DELETE FROM finished_products WHERE id = $1', [testFinishedProductId]);

    if (app) {
      await app.close();
    }
  });

  describe('8.1 List Production Orders', () => {
    it('should return paginated production orders with summary metrics', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/production/orders')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data).toHaveProperty('summary');
      expect(res.body.data.summary).toHaveProperty('totalOrders');
      expect(res.body.data.summary).toHaveProperty('completedBatches');
      expect(res.body.data.summary).toHaveProperty('inProgressBatches');
      expect(res.body.data.summary).toHaveProperty('totalProductionCost');
      expect(res.body.data).toHaveProperty('orders');
      expect(Array.isArray(res.body.data.orders)).toBe(true);
      expect(res.body.data).toHaveProperty('pagination');
    });
  });

  describe('8.2 Bill of Materials (BOM) Management', () => {
    it('should create and retrieve a persistent BOM recipe for finished product', async () => {
      // 1. Create BOM
      const createBomRes = await request(app.getHttpServer())
        .post('/api/v1/production/bom')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          finishedProductId: testFinishedProductId,
          name: 'Standard Architectural Bar Recipe',
          description: 'Standard factory bill of materials',
          outputQuantity: 1.0,
          items: [
            {
              rawMaterialId: testRawMaterialId1,
              rawMaterialName: 'Test Aluminum Ingot',
              rawMaterialCode: testRmCode1,
              quantityPerUnit: 2.5,
              unit: 'kg',
            },
            {
              rawMaterialId: testRawMaterialId2,
              rawMaterialName: 'Test LED Driver',
              rawMaterialCode: testRmCode2,
              quantityPerUnit: 1.0,
              unit: 'PCS',
            },
          ],
        });

      expect(createBomRes.status).toBe(201);
      const bom = createBomRes.body.data;
      expect(bom).toHaveProperty('id');
      expect(bom.finishedProductId).toBe(testFinishedProductId);
      expect(bom.items.length).toBe(2);
      createdBomIds.push(bom.id);

      // 2. Fetch BOM by finished product ID
      const getBomRes = await request(app.getHttpServer())
        .get(`/api/v1/production/bom/${testFinishedProductId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(getBomRes.status).toBe(200);
      expect(getBomRes.body.data.id).toBe(bom.id);
      expect(getBomRes.body.data.items.length).toBe(2);
    });
  });

  describe('8.3 Create & Complete Production Order (Atomic Consumption & Output)', () => {
    let createdOrderId: string;
    let createdOrderNumber: string;

    it('should deduct raw materials, increase finished good stock, and write immutable ledger entries', async () => {
      const produceQty = 10.0;
      const rm1UsageQty = 25.0; // 10 * 2.5
      const rm2UsageQty = 10.0; // 10 * 1.0

      const createRes = await request(app.getHttpServer())
        .post('/api/v1/production/orders')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          finishedProductId: testFinishedProductId,
          finishedProductName: 'Test Architectural Light Bar',
          finishedProductCode: testFpCode,
          unit: 'PCS',
          plannedQuantity: produceQty,
          actualQuantityProduced: produceQty,
          rawMaterialsUsed: [
            {
              rawMaterialId: testRawMaterialId1,
              rawMaterialName: 'Test Aluminum Ingot',
              rawMaterialCode: testRmCode1,
              quantityUsed: rm1UsageQty,
              unit: 'kg',
              unitCost: 250.0,
              totalCost: rm1UsageQty * 250.0, // 6250.00
            },
            {
              rawMaterialId: testRawMaterialId2,
              rawMaterialName: 'Test LED Driver',
              rawMaterialCode: testRmCode2,
              quantityUsed: rm2UsageQty,
              unit: 'PCS',
              unitCost: 400.0,
              totalCost: rm2UsageQty * 400.0, // 4000.00
            },
          ],
          rawMaterialCost: 10250.0,
          labourCost: 1500.0,
          otherExpenses: 500.0,
          totalProductionCost: 12250.0,
          costPerUnit: 1225.0,
          productionDate: new Date().toISOString(),
          status: 'completed',
          notes: 'Batch test production run for Architectural Bar',
        });

      expect(createRes.status).toBe(201);
      const order = createRes.body.data;
      expect(order).toHaveProperty('id');
      expect(order.status).toBe('completed');
      expect(order.productionNumber).toMatch(/^PRD-/);
      expect(order.rawMaterialsUsed.length).toBe(2);

      createdOrderId = order.id;
      createdOrderNumber = order.productionNumber;
      createdOrderIds.push(createdOrderId);

      // Verify Raw Material 1 stock deduction: 100 - 25 = 75
      const rm1Res = await db.query<{ current_stock: string }>('SELECT current_stock FROM raw_materials WHERE id = $1', [testRawMaterialId1]);
      expect(Number(rm1Res.rows[0].current_stock)).toBe(75.0);

      // Verify Raw Material 2 stock deduction: 50 - 10 = 40
      const rm2Res = await db.query<{ current_stock: string }>('SELECT current_stock FROM raw_materials WHERE id = $1', [testRawMaterialId2]);
      expect(Number(rm2Res.rows[0].current_stock)).toBe(40.0);

      // Verify Finished Product stock addition: 5 + 10 = 15
      const fpRes = await db.query<{ current_stock: string; produced_stock: string }>(
        'SELECT current_stock, produced_stock FROM finished_products WHERE id = $1',
        [testFinishedProductId],
      );
      expect(Number(fpRes.rows[0].current_stock)).toBe(15.0);
      expect(Number(fpRes.rows[0].produced_stock)).toBe(10.0);

      // Verify Immutable Stock Movements Ledger
      const movementsRes = await db.query<{
        transaction_type: string;
        reference_number: string;
        stock_in: string;
        stock_out: string;
      }>(
        'SELECT transaction_type, reference_number, stock_in, stock_out FROM stock_movements WHERE reference_number = $1 ORDER BY created_at ASC',
        [createdOrderNumber],
      );

      expect(movementsRes.rows.length).toBe(3); // 2 consumptions + 1 output
      const consumptions = movementsRes.rows.filter((m) => m.transaction_type === 'productionConsumption');
      expect(consumptions.length).toBe(2);
      const outputs = movementsRes.rows.filter((m) => m.transaction_type === 'productionOutput');
      expect(outputs.length).toBe(1);
      expect(Number(outputs[0].stock_in)).toBe(produceQty);
    });

    it('8.4 should get production order details by ID', async () => {
      const res = await request(app.getHttpServer())
        .get(`/api/v1/production/orders/${createdOrderId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe(createdOrderId);
      expect(res.body.data.rawMaterialsUsed.length).toBe(2);
      expect(res.body.data.finishedProductId).toBe(testFinishedProductId);
    });

    it('8.5 should cancel/soft-delete production order and rollback consumed and produced stock', async () => {
      const cancelRes = await request(app.getHttpServer())
        .delete(`/api/v1/production/orders/${createdOrderId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          reason: 'QC failure inspection defect detected in batch',
        });

      expect(cancelRes.status).toBe(200);
      expect(cancelRes.body.data.status).toBe('cancelled');
      expect(cancelRes.body.data.isDeleted).toBe(true);

      // Verify Raw Material 1 rolled back: 75 + 25 = 100
      const rm1Res = await db.query<{ current_stock: string }>('SELECT current_stock FROM raw_materials WHERE id = $1', [testRawMaterialId1]);
      expect(Number(rm1Res.rows[0].current_stock)).toBe(100.0);

      // Verify Raw Material 2 rolled back: 40 + 10 = 50
      const rm2Res = await db.query<{ current_stock: string }>('SELECT current_stock FROM raw_materials WHERE id = $1', [testRawMaterialId2]);
      expect(Number(rm2Res.rows[0].current_stock)).toBe(50.0);

      // Verify Finished Product rolled back: 15 - 10 = 5
      const fpRes = await db.query<{ current_stock: string }>(
        'SELECT current_stock FROM finished_products WHERE id = $1',
        [testFinishedProductId],
      );
      expect(Number(fpRes.rows[0].current_stock)).toBe(5.0);
    });
  });

  describe('Validation & Edge Cases', () => {
    it('should reject completed production order when raw material stock is insufficient', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/production/orders')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          finishedProductId: testFinishedProductId,
          finishedProductName: 'Test Architectural Light Bar',
          finishedProductCode: testFpCode,
          unit: 'PCS',
          plannedQuantity: 1000.0,
          actualQuantityProduced: 1000.0,
          rawMaterialsUsed: [
            {
              rawMaterialId: testRawMaterialId1,
              rawMaterialName: 'Test Aluminum Ingot',
              rawMaterialCode: testRmCode1,
              quantityUsed: 9999.0, // Exceeds available stock (100)
              unit: 'kg',
              unitCost: 250.0,
              totalCost: 2499750.0,
            },
          ],
          rawMaterialCost: 2499750.0,
          totalProductionCost: 2500000.0,
          status: 'completed',
        });

      expect(res.status).toBe(400);
      expect(res.body.error.message).toMatch(/insufficient stock/i);
    });
  });
});
