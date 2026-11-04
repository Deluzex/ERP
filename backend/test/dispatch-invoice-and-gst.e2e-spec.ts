import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Sales Module: Dispatch Challan Single Invoice & Direct Sale GST (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  const testCid = `e2e_gst_inv_${Date.now()}`;

  let testCustomerId: string;
  let testCategoryId: string;
  let testUnitId: string;
  let testFpId: string;

  const testCustomerMobile = `+91 97${Math.floor(10000000 + Math.random() * 90000000)}`;
  const testCustomerGst = `24AABCO${Math.floor(1000 + Math.random() * 9000)}K1Z8`;
  const testFpCode = `FP-GST-${Date.now().toString().slice(-4)}`;

  const createdSaleIds: string[] = [];

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

    // 2. Fetch category and unit
    const catRes = await db.query<{ id: string }>('SELECT id FROM categories LIMIT 1');
    testCategoryId = catRes.rows[0].id;
    const unitRes = await db.query<{ id: string }>('SELECT id FROM measurement_units LIMIT 1');
    testUnitId = unitRes.rows[0].id;

    // 3. Create Test Customer
    const custRes = await db.query<{ id: string }>(
      `INSERT INTO customers (name, mobile, email, gst_number, address, state, state_code, pincode, outstanding_amount)
       VALUES ($1, $2, 'gst-test@deluzex.com', $3, 'Bodakdev, Ahmedabad, Gujarat', 'Gujarat', '24', '380054', 0.00)
       RETURNING id`,
      ['GST & Challan Test Client', testCustomerMobile, testCustomerGst],
    );
    testCustomerId = custRes.rows[0].id;

    // 4. Create Test Finished Product with stock 100
    const fpRes = await db.query<{ id: string }>(
      `INSERT INTO finished_products (name, item_code, category_id, unit_id, opening_stock, current_stock, reserved_stock, minimum_stock, cost_price, customer_selling_price, gst_percent)
       VALUES ($1, $2, $3, $4, 100.0000, 100.0000, 0.0000, 5.0000, 1000.00, 2000.00, 18.00)
       RETURNING id`,
      ['Zero GST Modular Light', testFpCode, testCategoryId, testUnitId],
    );
    testFpId = fpRes.rows[0].id;
  });

  afterAll(async () => {
    // Deterministic DB Teardown
    if (createdSaleIds.length > 0) {
      await db.query(`DELETE FROM stock_movements WHERE reference_number IN (SELECT invoice_number FROM sales WHERE id = ANY($1))`, [createdSaleIds]);
      await db.query(`DELETE FROM payments WHERE reference_number IN (SELECT invoice_number FROM sales WHERE id = ANY($1))`, [createdSaleIds]);
      await db.query(`DELETE FROM architect_commissions WHERE sale_invoice_id = ANY($1)`, [createdSaleIds]);
      await db.query(`DELETE FROM sale_items WHERE sale_id = ANY($1)`, [createdSaleIds]);
      await db.query(`DELETE FROM sales WHERE id = ANY($1)`, [createdSaleIds]);
    }
    if (testFpId) {
      await db.query(`DELETE FROM stock_movements WHERE item_id = $1`, [testFpId]);
      await db.query(`DELETE FROM finished_products WHERE id = $1`, [testFpId]);
    }
    if (testCustomerId) {
      await db.query(`DELETE FROM customers WHERE id = $1`, [testCustomerId]);
    }

    if (app) {
      await app.close();
    }
  });

  // ==========================================================================
  // 1. ALLOW 0% GST IN DIRECT SALES & VALIDATIONS
  // ==========================================================================
  describe('Direct Sales GST & Invoice Total Validations', () => {
    it('Positive: Should accept 0% GST and compute 0 tax with grandTotal = taxableAmount', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/direct-sale')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          partyType: 'customer',
          partyId: testCustomerId,
          items: [
            {
              finishedProductId: testFpId,
              quantity: 2.0,
              rate: 2000.0,
              discountAmount: 0.0,
              gstPercent: 0.0, // 0% GST
            },
          ],
          paidAmount: 4000.0,
          paymentMode: 'cash',
          notes: '0% GST direct sale verification',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.documentType).toBe('invoice');
      expect(res.body.data.taxableAmount).toBe(4000.0);
      expect(res.body.data.gstAmount).toBe(0.0);
      expect(res.body.data.cgstAmount).toBe(0.0);
      expect(res.body.data.sgstAmount).toBe(0.0);
      expect(res.body.data.igstAmount).toBe(0.0);
      expect(res.body.data.totalAmount).toBe(4000.0);
      expect(res.body.data.items[0].gstPercent).toBe(0.0);
      expect(res.body.data.items[0].lineTotal).toBe(4000.0);

      createdSaleIds.push(res.body.data.id);
    });

    it('Positive: Should accept standard GST rates (5%, 12%, 18%, 28%) and compute correct tax', async () => {
      const rates = [5.0, 12.0, 18.0, 28.0];
      for (const rate of rates) {
        const expectedTaxable = 2000.0;
        const expectedGst = expectedTaxable * (rate / 100);
        const expectedTotal = expectedTaxable + expectedGst;

        const res = await request(app.getHttpServer())
          .post('/api/v1/sales/direct-sale')
          .set('Authorization', `Bearer ${accessToken}`)
          .set('X-Correlation-ID', testCid)
          .send({
            partyType: 'customer',
            partyId: testCustomerId,
            items: [
              {
                finishedProductId: testFpId,
                quantity: 1.0,
                rate: 2000.0,
                discountAmount: 0.0,
                gstPercent: rate,
              },
            ],
            paidAmount: expectedTotal,
            paymentMode: 'cash',
            notes: `${rate}% GST direct sale test`,
          });

        expect(res.status).toBe(201);
        expect(res.body.data.taxableAmount).toBe(expectedTaxable);
        expect(res.body.data.gstAmount).toBeCloseTo(expectedGst, 2);
        expect(res.body.data.totalAmount).toBeCloseTo(expectedTotal, 2);
        createdSaleIds.push(res.body.data.id);
      }
    });

    it('Negative: Should reject negative GST percent (-5%) with 400 Bad Request', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/direct-sale')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          partyType: 'customer',
          partyId: testCustomerId,
          items: [
            {
              finishedProductId: testFpId,
              quantity: 1.0,
              rate: 2000.0,
              gstPercent: -5.0, // Negative GST
            },
          ],
        });

      expect(res.status).toBe(400);
    });

    it('Negative: Should reject zero invoice total with 400 Bad Request', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/direct-sale')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          partyType: 'customer',
          partyId: testCustomerId,
          items: [
            {
              finishedProductId: testFpId,
              quantity: 1.0,
              rate: 2000.0,
              discountAmount: 2000.0, // Discount equals rate, taxable = 0, gst = 0 -> grandTotal = 0
              gstPercent: 0.0,
            },
          ],
        });

      expect(res.status).toBe(400);
      expect(res.body.error?.message || res.body.message).toContain('Invoice total must be strictly greater than 0');
    });
  });

  // ==========================================================================
  // 2. DISPATCH CHALLAN -> ONLY ONE SALES INVOICE
  // ==========================================================================
  describe('Dispatch Challan Single Invoice Lifecycle', () => {
    let salesOrderId: string;
    let deliveryId: string;
    let deliveryNumber: string;
    let firstInvoiceId: string;

    beforeAll(async () => {
      // 1. Create dedicated Sales Order
      const soRes = await request(app.getHttpServer())
        .post('/api/v1/sales/orders')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          partyType: 'customer',
          partyId: testCustomerId,
          items: [
            {
              finishedProductId: testFpId,
              quantity: 5.0,
              rate: 2000.0,
              gstPercent: 18.0,
            },
          ],
        });
      expect(soRes.status).toBe(201);
      salesOrderId = soRes.body.data.id;
      createdSaleIds.push(salesOrderId);

      // 2. Create Delivery Challan
      const dlvRes = await request(app.getHttpServer())
        .post('/api/v1/sales/deliveries')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          salesOrderId: salesOrderId,
          vehicleNumber: 'GJ-01-XX-9900',
          items: [{ finishedProductId: testFpId, quantity: 5.0 }],
        });
      expect(dlvRes.status).toBe(201);
      deliveryId = dlvRes.body.data.id;
      deliveryNumber = dlvRes.body.data.invoiceNumber;
      createdSaleIds.push(deliveryId);

      // Verify initial delivery status is dispatched
      expect(dlvRes.body.data.deliveryStatus).toBe('dispatched');
    });

    it('Positive: Should generate the single allowed Tax Invoice from Delivery Challan', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/invoices/from-delivery')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          deliveryId: deliveryId,
          discountAmount: 0.0,
          initialPaidAmount: 0.0,
          notes: `Invoice against Delivery ${deliveryNumber}`,
        });

      expect(res.status).toBe(201);
      expect(res.body.data.documentType).toBe('invoice');
      expect(res.body.data.deliveryReferenceId).toBe(deliveryId);

      firstInvoiceId = res.body.data.id;
      createdSaleIds.push(firstInvoiceId);

      // Verify Challan document in DB has transitioned to 'invoiced'
      const dlvCheck = await db.query<{ status: string; delivery_status: string }>(
        `SELECT status, delivery_status FROM sales WHERE id = $1`,
        [deliveryId],
      );
      expect(dlvCheck.rows[0].status).toBe('invoiced');
      expect(dlvCheck.rows[0].delivery_status).toBe('invoiced');
    });

    it('Negative: Second invoice creation attempt for the same Challan via API must be rejected with 409 Conflict', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/invoices/from-delivery')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          deliveryId: deliveryId,
          discountAmount: 0.0,
          initialPaidAmount: 0.0,
          notes: `Duplicate Invoice attempt against ${deliveryNumber}`,
        });

      expect(res.status).toBe(409);
      expect(res.body.error?.message || res.body.message).toContain('Invoice has already been generated for this Dispatch Challan');
    });

    it('Positive: Delivery listing and detail should persist invoiced status and invoice linkage across refreshes', async () => {
      const res = await request(app.getHttpServer())
        .get(`/api/v1/sales/deliveries/${deliveryId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('invoiced');
      expect(res.body.data.deliveryStatus).toBe('invoiced');
      expect(res.body.data.linkedInvoiceId).toBe(firstInvoiceId);
    });

    it('Negative: Zero or negative invoice total from delivery must be rejected with 400', async () => {
      // Create another SO and Delivery
      const so2Res = await request(app.getHttpServer())
        .post('/api/v1/sales/orders')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          partyType: 'customer',
          partyId: testCustomerId,
          items: [{ finishedProductId: testFpId, quantity: 1.0, rate: 2000.0, gstPercent: 0.0 }],
        });
      const so2Id = so2Res.body.data.id;
      createdSaleIds.push(so2Id);

      const dlv2Res = await request(app.getHttpServer())
        .post('/api/v1/sales/deliveries')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          salesOrderId: so2Id,
          vehicleNumber: 'GJ-01-YY-1122',
          items: [{ finishedProductId: testFpId, quantity: 1.0 }],
        });
      const dlv2Id = dlv2Res.body.data.id;
      createdSaleIds.push(dlv2Id);

      // Attempt to invoice with discount equal to subtotal
      const invFailRes = await request(app.getHttpServer())
        .post('/api/v1/sales/invoices/from-delivery')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          deliveryId: dlv2Id,
          discountAmount: 2000.0, // Subtotal is 2000, gst is 0 -> total = 0
        });

      expect(invFailRes.status).toBe(400);

      // Verify Challan dlv2 was NOT marked as invoiced after failure, so retry is possible
      const dlv2Check = await db.query<{ status: string; delivery_status: string }>(
        `SELECT status, delivery_status FROM sales WHERE id = $1`,
        [dlv2Id],
      );
      expect(dlv2Check.rows[0].status).toBe('completed');
      expect(dlv2Check.rows[0].delivery_status).toBe('dispatched');

      // Retry with valid discount and verify it succeeds
      const retryRes = await request(app.getHttpServer())
        .post('/api/v1/sales/invoices/from-delivery')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          deliveryId: dlv2Id,
          discountAmount: 100.0, // valid total = 1900 > 0
        });

      expect(retryRes.status).toBe(201);
      createdSaleIds.push(retryRes.body.data.id);
    });
  });
});

