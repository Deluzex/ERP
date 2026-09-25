import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Payments, Receipts & Commissions Lifecycle (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  const testCid = `e2e_payments_${Date.now()}`;

  let testCustomerId: string;
  let testVendorId: string;
  let testArchitectId: string;
  let testInvoiceId: string;
  let testPurchaseId: string;
  let testCommissionId: string;

  const createdPaymentIds: string[] = [];
  const createdCommissionIds: string[] = [];

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

    // Seed test customer
    const custRes = await db.query<{ id: string }>(
      `INSERT INTO customers (name, mobile, email, address, outstanding_amount)
       VALUES ('E2E Payment Customer', '9898011221', 'payment.cust@deluzex.com', 'Ahmedabad', 10000.00)
       RETURNING id`,
    );
    testCustomerId = custRes.rows[0].id;

    // Seed test vendor
    const vendRes = await db.query<{ id: string }>(
      `INSERT INTO vendors (name, contact_person, mobile, email, gst_number, pan_number, address, payment_terms, credit_limit, outstanding_balance)
       VALUES ('E2E Payment Vendor', 'Mr. Vendor', '9898011222', 'payment.vend@deluzex.com', '24AAAAA0000A1Z5', 'AAAAA0000A', 'Surat', 'Net 30', 50000, 15000.00)
       RETURNING id`,
    );
    testVendorId = vendRes.rows[0].id;

    // Seed test architect
    const archRes = await db.query<{ id: string }>(
      `INSERT INTO architects (name, company_name, mobile, email, address, default_commission_rate, pending_commission, approved_commission, paid_commission)
       VALUES ('E2E Payment Architect', 'Studio Payout', '9898011223', 'payment.arch@deluzex.com', 'Vadodara', 5.00, 2500.00, 0.00, 0.00)
       RETURNING id`,
    );
    testArchitectId = archRes.rows[0].id;

    // Seed test invoice
    const invRes = await db.query<{ id: string }>(
      `INSERT INTO sales (
         invoice_number, document_type, sale_date, party_type, party_id, party_name,
         taxable_amount, gst_amount, total_amount, paid_amount, pending_amount, status
       )
       VALUES (
         'INV-E2E-PAY-01', 'invoice', now(), 'customer', $1, 'E2E Payment Customer',
         10000.00, 1800.00, 11800.00, 0.00, 11800.00, 'active'
       )
       RETURNING id`,
      [testCustomerId],
    );
    testInvoiceId = invRes.rows[0].id;

    // Seed test purchase
    const purRes = await db.query<{ id: string }>(
      `INSERT INTO purchases (
         purchase_number, vendor_id, vendor_name, purchase_type,
         taxable_amount, gst_amount, total_amount, paid_amount, pending_amount, status
       )
       VALUES (
         'PUR-E2E-PAY-01', $1, 'E2E Payment Vendor', 'rawMaterial',
         12000.00, 2160.00, 14160.00, 0.00, 14160.00, 'saved'
       )
       RETURNING id`,
      [testVendorId],
    );
    testPurchaseId = purRes.rows[0].id;

    // Seed test commission
    const commRes = await db.query<{ id: string }>(
      `INSERT INTO architect_commissions (
         commission_number, architect_id, architect_name, sale_invoice_id, sale_invoice_number,
         sale_amount, commission_rate, commission_amount, status
       )
       VALUES (
         'COM-E2E-001', $1, 'E2E Payment Architect', $2, 'INV-E2E-PAY-01',
         10000.00, 5.00, 500.00, 'generated'
       )
       RETURNING id`,
      [testArchitectId, testInvoiceId],
    );
    testCommissionId = commRes.rows[0].id;
    createdCommissionIds.push(testCommissionId);
  });

  afterAll(async () => {
    // Teardown
    for (const pid of createdPaymentIds) {
      await db.query(`DELETE FROM payments WHERE id = $1`, [pid]);
    }
    for (const cid of createdCommissionIds) {
      await db.query(`DELETE FROM architect_commissions WHERE id = $1`, [cid]);
    }
    if (testInvoiceId) {
      await db.query(`DELETE FROM sales WHERE id = $1`, [testInvoiceId]);
    }
    if (testPurchaseId) {
      await db.query(`DELETE FROM purchases WHERE id = $1`, [testPurchaseId]);
    }
    if (testCustomerId) {
      await db.query(`DELETE FROM customers WHERE id = $1`, [testCustomerId]);
    }
    if (testVendorId) {
      await db.query(`DELETE FROM vendors WHERE id = $1`, [testVendorId]);
    }
    if (testArchitectId) {
      await db.query(`DELETE FROM architects WHERE id = $1`, [testArchitectId]);
    }
    await app.close();
  });

  it('1. POST /api/v1/payments — Record customer receipt and verify atomic invoice & ledger rebalancing', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/payments')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        paymentType: 'customerPayment',
        partyId: testCustomerId,
        partyName: 'E2E Payment Customer',
        referenceDocumentId: testInvoiceId,
        referenceDocumentNumber: 'INV-E2E-PAY-01',
        amount: 5000.00,
        paymentMode: 'bankTransfer',
        transactionReference: 'NEFT-HDFC-10029',
        notes: 'Partial invoice settlement',
      });

    expect(res.status).toBe(201);
    expect(res.body.data).toBeDefined();
    expect(res.body.data.paymentNumber).toMatch(/^PAY-\d{4}-\d+/);
    expect(res.body.data.amount).toBe(5000.00);
    createdPaymentIds.push(res.body.data.id);

    // Verify invoice balance
    const invCheck = await db.query<any>(`SELECT paid_amount, pending_amount, status FROM sales WHERE id = $1`, [testInvoiceId]);
    expect(parseFloat(invCheck.rows[0].paid_amount)).toBe(5000.00);
    expect(parseFloat(invCheck.rows[0].pending_amount)).toBe(6800.00);
    expect(invCheck.rows[0].status).toBe('partialPaid');

    // Verify customer outstanding decreased
    const custCheck = await db.query<any>(`SELECT outstanding_amount FROM customers WHERE id = $1`, [testCustomerId]);
    expect(parseFloat(custCheck.rows[0].outstanding_amount)).toBe(5000.00);
  });

  it('2. POST /api/v1/payments — Record vendor payment and verify purchase & vendor ledger rebalancing', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/payments')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        paymentType: 'vendorPayment',
        partyId: testVendorId,
        partyName: 'E2E Payment Vendor',
        referenceDocumentId: testPurchaseId,
        referenceDocumentNumber: 'PUR-E2E-PAY-01',
        amount: 14160.00,
        paymentMode: 'bankTransfer',
        transactionReference: 'RTGS-AXIS-9921',
        isFullPayment: true,
      });

    expect(res.status).toBe(201);
    expect(res.body.data.amount).toBe(14160.00);
    createdPaymentIds.push(res.body.data.id);

    // Verify purchase fully paid
    const purCheck = await db.query<any>(`SELECT paid_amount, pending_amount, status FROM purchases WHERE id = $1`, [testPurchaseId]);
    expect(parseFloat(purCheck.rows[0].paid_amount)).toBe(14160.00);
    expect(parseFloat(purCheck.rows[0].pending_amount)).toBe(0.00);
    expect(purCheck.rows[0].status).toBe('paid');

    // Verify vendor outstanding decreased
    const vendCheck = await db.query<any>(`SELECT outstanding_balance FROM vendors WHERE id = $1`, [testVendorId]);
    expect(parseFloat(vendCheck.rows[0].outstanding_balance)).toBe(840.00);
  });

  it('3. GET /api/v1/payments — Query vouchers with KPI summaries', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/payments')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBeGreaterThanOrEqual(2);
    const summary = res.body.meta.pagination?.summary || res.body.meta.summary;
    expect(summary).toBeDefined();
    expect(parseFloat(summary.totalCustomerReceipts)).toBeGreaterThanOrEqual(5000);
    expect(parseFloat(summary.totalVendorPayments)).toBeGreaterThanOrEqual(14160);
  });

  it('4. Architect Commission Lifecycle: Approve & Disburse Payout', async () => {
    // 4a. Approve commission
    const approveRes = await request(app.getHttpServer())
      .post(`/api/v1/payments/commissions/${testCommissionId}/approve`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(approveRes.status).toBe(201);
    expect(approveRes.body.data.status).toBe('approved');
    expect(approveRes.body.data.approvedDate).toBeDefined();

    // Verify architect balance updated
    const archCheck1 = await db.query<any>(`SELECT approved_commission, pending_commission FROM architects WHERE id = $1`, [testArchitectId]);
    expect(parseFloat(archCheck1.rows[0].approved_commission)).toBe(500.00);

    // 4b. Disburse payout
    const payRes = await request(app.getHttpServer())
      .post(`/api/v1/payments/commissions/${testCommissionId}/pay`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        paymentMode: 'bankTransfer',
        transactionReference: 'NEFT-COMM-PAYOUT-01',
        notes: 'Disbursed commission',
      });

    expect(payRes.status).toBe(201);
    expect(payRes.body.data.commission.status).toBe('paid');
    expect(payRes.body.data.payment).toBeDefined();
    createdPaymentIds.push(payRes.body.data.payment.id);

    // Verify architect paid balance
    const archCheck2 = await db.query<any>(`SELECT paid_commission, approved_commission FROM architects WHERE id = $1`, [testArchitectId]);
    expect(parseFloat(archCheck2.rows[0].paid_commission)).toBe(500.00);
    expect(parseFloat(archCheck2.rows[0].approved_commission)).toBe(0.00);
  });

  it('5. Negative Cases: Reject invalid payment amount (zero or negative)', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/payments')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        paymentType: 'customerPayment',
        partyId: testCustomerId,
        partyName: 'E2E Payment Customer',
        amount: -100,
        paymentMode: 'cash',
      });

    expect(res.status).toBe(400);
  });
});
