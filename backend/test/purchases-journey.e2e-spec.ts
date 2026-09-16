import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Purchases & Procurement Domain Lifecycle (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  const testCid = `e2e_purchases_${Date.now()}`;

  let testVendorId: string;
  let testCategoryId: string;
  let testUnitId: string;
  let testRawMaterialId: string;
  let testFinishedProductId: string;

  const testRmCode = `RM-PO-${Date.now().toString().slice(-4)}`;
  const testFpCode = `FP-PO-${Date.now().toString().slice(-4)}`;
  const testVendorGst = `24AABCT${Math.floor(1000 + Math.random() * 9000)}B1Z5`;
  const createdPurchaseIds: string[] = [];

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

    // Create Test Vendor
    const venRes = await db.query<{ id: string }>(
      `INSERT INTO vendors (name, contact_person, mobile, email, gst_number, pan_number, address, payment_terms, credit_limit, outstanding_balance)
       VALUES ($1, 'Test Vendor Head', '+91 98980 11223', 'vendor@po-test.com', $2, 'AABCT1234B', 'GIDC Vatva, Ahmedabad', 'Net 30 Days', 1000000.00, 0.00)
       RETURNING id`,
      ['Test Aluminum Extruder Ltd', testVendorGst],
    );
    testVendorId = venRes.rows[0].id;

    // Create Test Raw Material with current_stock = 50.0
    const rmRes = await db.query<{ id: string }>(
      `INSERT INTO raw_materials (name, item_code, category_id, unit_id, opening_stock, current_stock, minimum_stock, default_purchase_price)
       VALUES ($1, $2, $3, $4, 50.0000, 50.0000, 10.0000, 450.00)
       RETURNING id`,
      ['Test Extrusion Profile 6063', testRmCode, testCategoryId, testUnitId],
    );
    testRawMaterialId = rmRes.rows[0].id;

    // Create Test Finished Product with current_stock = 10.0
    const fpRes = await db.query<{ id: string }>(
      `INSERT INTO finished_products (name, item_code, category_id, unit_id, opening_stock, current_stock, minimum_stock, cost_price)
       VALUES ($1, $2, $3, $4, 10.0000, 10.0000, 5.0000, 1200.00)
       RETURNING id`,
      ['Test Finished Pendant Light', testFpCode, testCategoryId, testUnitId],
    );
    testFinishedProductId = fpRes.rows[0].id;
  });

  afterAll(async () => {
    try {
      if (createdPurchaseIds.length > 0) {
        await db.query(`DELETE FROM stock_movements WHERE reference_number IN (SELECT purchase_number FROM purchases WHERE id = ANY($1::uuid[]))`, [createdPurchaseIds]);
        await db.query(`DELETE FROM payments WHERE purchase_id = ANY($1::uuid[])`, [createdPurchaseIds]);
        await db.query(`DELETE FROM purchase_items WHERE purchase_id = ANY($1::uuid[])`, [createdPurchaseIds]);
        await db.query(`DELETE FROM purchases WHERE id = ANY($1::uuid[])`, [createdPurchaseIds]);
      }
      if (testRawMaterialId) {
        await db.query(`DELETE FROM stock_movements WHERE item_id = $1`, [testRawMaterialId]);
        await db.query(`DELETE FROM raw_materials WHERE id = $1`, [testRawMaterialId]);
      }
      if (testFinishedProductId) {
        await db.query(`DELETE FROM stock_movements WHERE item_id = $1`, [testFinishedProductId]);
        await db.query(`DELETE FROM finished_products WHERE id = $1`, [testFinishedProductId]);
      }
      if (testVendorId) {
        await db.query(`DELETE FROM vendors WHERE id = $1`, [testVendorId]);
      }
    } catch (err) {
      console.error('Teardown error in purchases-journey:', err);
    } finally {
      await app.close();
    }
  });

  describe('7.1 List Purchases', () => {
    it('should return paginated purchases with summary metrics', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/purchases')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.summary).toBeDefined();
      expect(typeof res.body.data.summary.totalPurchases).toBe('number');
      expect(typeof res.body.data.summary.totalPaid).toBe('number');
      expect(typeof res.body.data.summary.totalPending).toBe('number');
      expect(Array.isArray(res.body.data.items)).toBe(true);
    });
  });

  describe('7.2 Create Purchase Order & Inward Bill (Transactional Stock & Ledger)', () => {
    let createdPurchaseId: string;
    let purchaseNumber: string;

    it('should create raw material purchase, increment current stock, write ledger, and update vendor balance', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/purchases')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          vendorId: testVendorId,
          vendorName: 'Test Aluminum Extruder Ltd',
          vendorInvoiceNumber: 'INV-2026-9901',
          purchaseDate: new Date().toISOString(),
          purchaseType: 'rawMaterial',
          items: [
            {
              itemType: 'rawMaterial',
              rawMaterialId: testRawMaterialId,
              rawMaterialName: 'Test Extrusion Profile 6063',
              rawMaterialCode: testRmCode,
              quantity: 100.0,
              unit: 'MTR',
              rate: 450.0,
              discountAmount: 1000.0,
              gstPercent: 18.0,
              taxableAmount: 44000.0,
              cgstAmount: 3960.0,
              sgstAmount: 3960.0,
              igstAmount: 0.0,
              lineTotal: 51920.0,
            },
          ],
          subtotalAmount: 45000.0,
          discountAmount: 1000.0,
          taxableAmount: 44000.0,
          cgstAmount: 3960.0,
          sgstAmount: 3960.0,
          igstAmount: 0.0,
          gstAmount: 7920.0,
          totalAmount: 51920.0,
          paidAmount: 20000.0,
          pendingAmount: 31920.0,
          paymentMode: 'bankTransfer',
          status: 'partialPaid',
          notes: 'Delivered to Bay 1',
        });

      expect(res.status).toBe(201);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.id).toBeDefined();
      expect(res.body.data.purchaseNumber).toBeDefined();
      createdPurchaseId = res.body.data.id;
      purchaseNumber = res.body.data.purchaseNumber;
      createdPurchaseIds.push(createdPurchaseId);

      // 1. Verify Raw Material stock increased by 100: 50.0 + 100.0 = 150.0
      const rmCheck = await db.query<{ current_stock: string }>(
        'SELECT current_stock FROM raw_materials WHERE id = $1',
        [testRawMaterialId],
      );
      expect(Number(rmCheck.rows[0].current_stock)).toBe(150.0);

      // 2. Verify immutable stock movement was posted
      const movCheck = await db.query<{ stock_in: string; transaction_type: string }>(
        'SELECT stock_in, transaction_type FROM stock_movements WHERE reference_number = $1 AND item_id = $2',
        [purchaseNumber, testRawMaterialId],
      );
      expect(movCheck.rows.length).toBe(1);
      expect(movCheck.rows[0].transaction_type).toBe('purchase');
      expect(Number(movCheck.rows[0].stock_in)).toBe(100.0);

      // 3. Verify vendor outstanding balance increased by pendingAmount (31920.0)
      const venCheck = await db.query<{ outstanding_balance: string }>(
        'SELECT outstanding_balance FROM vendors WHERE id = $1',
        [testVendorId],
      );
      expect(Number(venCheck.rows[0].outstanding_balance)).toBe(31920.0);

      // 4. Verify initial payment voucher was created for 20000.0
      const payCheck = await db.query<{ amount: string; payment_type: string }>(
        'SELECT amount, payment_type FROM payments WHERE purchase_id = $1',
        [createdPurchaseId],
      );
      expect(payCheck.rows.length).toBe(1);
      expect(Number(payCheck.rows[0].amount)).toBe(20000.0);
    });

    it('7.3 should get purchase details by ID', async () => {
      const res = await request(app.getHttpServer())
        .get(`/api/v1/purchases/${createdPurchaseId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.id).toBe(createdPurchaseId);
      expect(Array.isArray(res.body.data.items)).toBe(true);
      expect(res.body.data.items.length).toBe(1);
      expect(res.body.data.items[0].rawMaterialCode).toBe(testRmCode);
    });

    it('7.4 should cancel purchase order and rollback stock and vendor balances', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/api/v1/purchases/${createdPurchaseId}/status`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          status: 'cancelled',
          reason: 'Supplier delivered defective profile batch',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('cancelled');

      // 1. Verify Raw Material stock rolled back by 100: 150.0 - 100.0 = 50.0
      const rmCheck = await db.query<{ current_stock: string }>(
        'SELECT current_stock FROM raw_materials WHERE id = $1',
        [testRawMaterialId],
      );
      expect(Number(rmCheck.rows[0].current_stock)).toBe(50.0);

      // 2. Verify vendor balance rolled back: 31920.0 - 31920.0 = 0.0
      const venCheck = await db.query<{ outstanding_balance: string }>(
        'SELECT outstanding_balance FROM vendors WHERE id = $1',
        [testVendorId],
      );
      expect(Number(venCheck.rows[0].outstanding_balance)).toBe(0.0);
    });
  });

  describe('Validation & Edge Cases', () => {
    it('should reject purchase creation without items', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/purchases')
        .set('Authorization', `Bearer ${accessToken}`)
        .send({
          vendorId: testVendorId,
          vendorName: 'Test Vendor',
          purchaseType: 'rawMaterial',
          items: [],
          totalAmount: 1000,
        });

      expect(res.status).toBe(400);
    });
  });
});
