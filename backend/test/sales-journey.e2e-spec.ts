import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Sales & Commercial Lifecycle Domain (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  const testCid = `e2e_sales_${Date.now()}`;

  let testCustomerId: string;
  let testArchitectId: string;
  let testCategoryId: string;
  let testUnitId: string;
  let testFpId1: string;
  let testFpId2: string;

  const testCustomerMobile = `+91 98${Math.floor(10000000 + Math.random() * 90000000)}`;
  const testCustomerGst = `27AABCO${Math.floor(1000 + Math.random() * 9000)}K1Z9`;
  const testFpCode1 = `FP-SL1-${Date.now().toString().slice(-4)}`;
  const testFpCode2 = `FP-SL2-${Date.now().toString().slice(-4)}`;

  const createdSaleIds: string[] = [];
  const createdProductionOrderIds: string[] = [];

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
      `INSERT INTO customers (name, mobile, email, gst_number, address, outstanding_amount)
       VALUES ($1, $2, 'sales-test@oberoi.com', $3, 'Oberoi Sky City, Mumbai', 0.00)
       RETURNING id`,
      ['Oberoi Sky City Residences', testCustomerMobile, testCustomerGst],
    );
    testCustomerId = custRes.rows[0].id;

    // 4. Create Test Architect with 10% commission
    const archRes = await db.query<{ id: string }>(
      `INSERT INTO architects (name, company_name, mobile, email, gst_number, address, default_commission_rate, total_commission_earned, pending_commission, approved_commission, paid_commission)
       VALUES ($1, 'Sanjay Puri Architects', '+91 98200 44556', 'ar.puri@test.com', '27AABCS9988M1Z2', 'Worli, Mumbai', 10.00, 0.00, 0.00, 0.00, 0.00)
       RETURNING id`,
      ['Ar. Sanjay Puri'],
    );
    testArchitectId = archRes.rows[0].id;

    // 5. Create Test Finished Products
    // FP1: 50 in stock (for full reservation & dispatch)
    const fp1Res = await db.query<{ id: string }>(
      `INSERT INTO finished_products (name, item_code, category_id, unit_id, opening_stock, current_stock, reserved_stock, minimum_stock, cost_price, customer_selling_price)
       VALUES ($1, $2, $3, $4, 50.0000, 50.0000, 0.0000, 10.0000, 2000.00, 4000.00)
       RETURNING id`,
      ['Architectural Recessed Spotlight', testFpCode1, testCategoryId, testUnitId],
    );
    testFpId1 = fp1Res.rows[0].id;

    // FP2: 5 in stock (for shortage test)
    const fp2Res = await db.query<{ id: string }>(
      `INSERT INTO finished_products (name, item_code, category_id, unit_id, opening_stock, current_stock, reserved_stock, minimum_stock, cost_price, customer_selling_price)
       VALUES ($1, $2, $3, $4, 5.0000, 5.0000, 0.0000, 5.0000, 5000.00, 10000.00)
       RETURNING id`,
      ['Crystal Chandelier Pendant', testFpCode2, testCategoryId, testUnitId],
    );
    testFpId2 = fp2Res.rows[0].id;
  });

  afterAll(async () => {
    try {
      if (createdSaleIds.length > 0) {
        await db.query(`DELETE FROM architect_commissions WHERE sale_invoice_id = ANY($1::uuid[])`, [createdSaleIds]);
        await db.query(`DELETE FROM stock_movements WHERE reference_number IN (SELECT invoice_number FROM sales WHERE id = ANY($1::uuid[]))`, [createdSaleIds]);
        await db.query(`DELETE FROM stock_adjustments WHERE remarks LIKE ANY(ARRAY['%DEL/%', '%RET/%', '%SO/%', '%INV/%'])`);
        await db.query(`DELETE FROM payments WHERE reference_number IN (SELECT invoice_number FROM sales WHERE id = ANY($1::uuid[]))`, [createdSaleIds]);
        await db.query(`DELETE FROM sale_items WHERE sale_id = ANY($1::uuid[])`, [createdSaleIds]);
        await db.query(`DELETE FROM sales WHERE id = ANY($1::uuid[])`, [createdSaleIds]);
      }
      if (createdProductionOrderIds.length > 0) {
        await db.query(`DELETE FROM production_orders WHERE id = ANY($1::uuid[])`, [createdProductionOrderIds]);
      }
      if (testFpId1) {
        await db.query(`DELETE FROM stock_adjustments WHERE item_id = $1`, [testFpId1]);
        await db.query(`DELETE FROM stock_movements WHERE item_id = $1`, [testFpId1]);
        await db.query(`DELETE FROM finished_products WHERE id = $1`, [testFpId1]);
      }
      if (testFpId2) {
        await db.query(`DELETE FROM stock_adjustments WHERE item_id = $1`, [testFpId2]);
        await db.query(`DELETE FROM stock_movements WHERE item_id = $1`, [testFpId2]);
        await db.query(`DELETE FROM finished_products WHERE id = $1`, [testFpId2]);
      }
      if (testCustomerId) {
        await db.query(`DELETE FROM customers WHERE id = $1`, [testCustomerId]);
      }
      if (testArchitectId) {
        await db.query(`DELETE FROM architects WHERE id = $1`, [testArchitectId]);
      }
    } catch (err) {
      console.error('Error during sales E2E teardown:', err);
    } finally {
      await app.close();
    }
  });

  // ==========================================================================
  // MILESTONE 5A: QUOTATIONS & PROFORMA INVOICES
  // ==========================================================================
  describe('Milestone 5A: Quotations & Proforma Invoices Lifecycle', () => {
    let quotationId: string;
    let quotationNumber: string;
    let revisionId: string;
    let proformaId: string;

    it('Positive: Should create a price quotation with zero stock effect', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/quotations')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          partyType: 'customer',
          partyId: testCustomerId,
          architectId: testArchitectId,
          salesExecutive: 'Alex Sterling',
          validDays: 30,
          isInterStateTax: false,
          items: [
            {
              finishedProductId: testFpId1,
              quantity: 20.0,
              rate: 4000.0,
              discountAmount: 4000.0,
              gstPercent: 18.0,
            },
          ],
          notes: 'Standard warm white LED finish',
        });

      expect(res.status).toBe(201);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.documentType).toBe('quotation');
      expect(res.body.data.quotationStatus).toBe('sent');
      expect(res.body.data.totalAmount).toBe(89680.0);

      quotationId = res.body.data.id;
      quotationNumber = res.body.data.invoiceNumber;
      createdSaleIds.push(quotationId);

      // Verify ZERO stock deduction or reservation
      const fpCheck = await db.query<{ current_stock: string; reserved_stock: string }>(
        `SELECT current_stock, reserved_stock FROM finished_products WHERE id = $1`,
        [testFpId1],
      );
      expect(parseFloat(fpCheck.rows[0].current_stock)).toBe(50.0);
      expect(parseFloat(fpCheck.rows[0].reserved_stock)).toBe(0.0);
    });

    it('Positive: Should create a quotation revision, marking parent as superseded', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/v1/sales/quotations/${quotationId}/revisions`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          discountAmount: 8000.0,
          items: [
            {
              finishedProductId: testFpId1,
              quantity: 20.0,
              rate: 4000.0,
              discountAmount: 8000.0,
              gstPercent: 18.0,
            },
          ],
          notes: 'Revision with extra 5% volume discount',
        });

      expect(res.status).toBe(201);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.revisionNumber).toBe(1);
      expect(res.body.data.invoiceNumber).toBe(`${quotationNumber}-R1`);
      expect(res.body.data.quotationStatus).toBe('sent');

      revisionId = res.body.data.id;
      createdSaleIds.push(revisionId);

      // Verify parent is superseded
      const parentCheck = await db.query<{ quotation_status: string }>(
        `SELECT quotation_status FROM sales WHERE id = $1`,
        [quotationId],
      );
      expect(parentCheck.rows[0].quotation_status).toBe('superseded');
    });

    it('Negative: Creating revision on non-existent quotation returns 404', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/quotations/00000000-0000-0000-0000-000000000000/revisions')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          items: [
            {
              finishedProductId: testFpId1,
              quantity: 5.0,
              rate: 4000.0,
              gstPercent: 18.0,
            },
          ],
        });

      expect(res.status).toBe(404);
    });

    it('Positive: Should update quotation status to accepted', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/api/v1/sales/quotations/${revisionId}/status`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          status: 'accepted',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.quotationStatus).toBe('accepted');
    });

    it('Positive: Should convert accepted quotation to Proforma Invoice', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/v1/sales/quotations/${revisionId}/convert-to-proforma`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send();

      expect(res.status).toBe(201);
      expect(res.body.data.documentType).toBe('proformaInvoice');
      expect(res.body.data.proformaStatus).toBe('issued');
      expect(res.body.data.parentQuotationNumber).toBe(`${quotationNumber}-R1`);

      proformaId = res.body.data.id;
      createdSaleIds.push(proformaId);

      // Verify quotation status became converted
      const quoteCheck = await db.query<{ quotation_status: string }>(
        `SELECT quotation_status FROM sales WHERE id = $1`,
        [revisionId],
      );
      expect(quoteCheck.rows[0].quotation_status).toBe('converted');
    });

    it('Positive: Should record advance payment against Proforma Invoice', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/v1/sales/proforma/${proformaId}/advance-payment`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          amount: 40000.0,
          paymentMode: 'bankTransfer',
          transactionReference: 'NEFT-889922001',
          notes: '50% advance for raw material procurement',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.paidAmount).toBe(40000.0);
      expect(res.body.data.proformaStatus).toBe('partialPaid');
    });
  });

  // ==========================================================================
  // MILESTONE 5B: SALES ORDERS & AUTO-STOCK RESERVATION
  // ==========================================================================
  describe('Milestone 5B: Sales Orders with Stock Allocation & Shortage Detection', () => {
    let fullStockOrderId: string;
    let shortageOrderId: string;

    it('Positive (Full Availability): Should reserve stock and mark readyForDispatch', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/orders')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          partyType: 'customer',
          partyId: testCustomerId,
          architectId: testArchitectId,
          deliveryDate: new Date(Date.now() + 7 * 86400000).toISOString(),
          paymentMode: 'bankTransfer',
          items: [
            {
              finishedProductId: testFpId1,
              quantity: 20.0,
              rate: 4000.0,
              discountAmount: 0.0,
              gstPercent: 18.0,
            },
          ],
          notes: 'Full stock available in factory',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.documentType).toBe('salesOrder');
      expect(res.body.data.salesOrderStatus).toBe('readyForDispatch');
      expect(res.body.data.items[0].reservedQuantity).toBe(20.0);

      fullStockOrderId = res.body.data.id;
      createdSaleIds.push(fullStockOrderId);

      // Verify finished product reserved_stock incremented to 20.0
      const fpCheck = await db.query<{ current_stock: string; reserved_stock: string }>(
        `SELECT current_stock, reserved_stock FROM finished_products WHERE id = $1`,
        [testFpId1],
      );
      expect(parseFloat(fpCheck.rows[0].current_stock)).toBe(50.0);
      expect(parseFloat(fpCheck.rows[0].reserved_stock)).toBe(20.0);
    });

    it('Positive (Shortage Detection): Should reserve available, create ProductionOrder for shortage', async () => {
      // FP2 only has 5 in stock. Order 15 -> shortage = 10!
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/orders')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          partyType: 'customer',
          partyId: testCustomerId,
          deliveryDate: new Date(Date.now() + 14 * 86400000).toISOString(),
          paymentMode: 'bankTransfer',
          items: [
            {
              finishedProductId: testFpId2,
              quantity: 15.0,
              rate: 10000.0,
              discountAmount: 0.0,
              gstPercent: 18.0,
            },
          ],
          notes: 'Requires production batch for remaining units',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.documentType).toBe('salesOrder');
      expect(res.body.data.salesOrderStatus).toBe('productionPending');
      expect(res.body.data.items[0].reservedQuantity).toBe(5.0);

      shortageOrderId = res.body.data.id;
      createdSaleIds.push(shortageOrderId);

      // Verify auto-generated ProductionOrder in DB
      const prdCheck = await db.query<{ id: string; planned_quantity: string; status: string }>(
        `SELECT id, planned_quantity, status FROM production_orders WHERE sales_order_id = $1`,
        [shortageOrderId],
      );
      expect(prdCheck.rows.length).toBe(1);
      expect(parseFloat(prdCheck.rows[0].planned_quantity)).toBe(10.0);
      expect(prdCheck.rows[0].status).toBe('planned');
      createdProductionOrderIds.push(prdCheck.rows[0].id);

      // Verify finished product reserved_stock incremented to 5.0
      const fpCheck = await db.query<{ current_stock: string; reserved_stock: string }>(
        `SELECT current_stock, reserved_stock FROM finished_products WHERE id = $1`,
        [testFpId2],
      );
      expect(parseFloat(fpCheck.rows[0].current_stock)).toBe(5.0);
      expect(parseFloat(fpCheck.rows[0].reserved_stock)).toBe(5.0);
    });

    it('Negative: Ordering with invalid product ID returns 404', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/orders')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          partyType: 'customer',
          partyId: testCustomerId,
          items: [
            {
              finishedProductId: '00000000-0000-0000-0000-000000000000',
              quantity: 5.0,
              rate: 1000.0,
              gstPercent: 18.0,
            },
          ],
        });

      expect(res.status).toBe(404);
    });
  });

  // ==========================================================================
  // MILESTONE 5C: DELIVERY CHALLANS & PHYSICAL STOCK OUT
  // ==========================================================================
  describe('Milestone 5C: Delivery Challans & Dispatch (Physical Stock OUT)', () => {
    let salesOrderId: string;
    let deliveryId: string;
    let deliveryNumber: string;

    beforeAll(async () => {
      // Create a dedicated SO for delivery testing
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/orders')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          partyType: 'customer',
          partyId: testCustomerId,
          architectId: testArchitectId,
          items: [
            {
              finishedProductId: testFpId1,
              quantity: 10.0,
              rate: 4000.0,
              gstPercent: 18.0,
            },
          ],
        });
      salesOrderId = res.body.data.id;
      createdSaleIds.push(salesOrderId);
    });

    it('Positive: Should dispatch delivery challan, deduct physical stock, release reserved stock, and log StockMovement', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/deliveries')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          salesOrderId: salesOrderId,
          vehicleNumber: 'MH-04-AZ-8812',
          driverContact: '+91 98330 11992',
          courierName: 'Deluzex Dedicated Fleet',
          trackingNumber: 'DLZ-TRK-9902',
          dispatchNotes: 'Delivering 10 units of recessed spotlight',
          items: [
            {
              finishedProductId: testFpId1,
              quantity: 10.0,
            },
          ],
        });

      expect(res.status).toBe(201);
      expect(res.body.data.documentType).toBe('delivery');
      expect(res.body.data.deliveryStatus).toBe('dispatched');
      deliveryId = res.body.data.id;
      deliveryNumber = res.body.data.invoiceNumber;
      createdSaleIds.push(deliveryId);

      // Verify physical stock deducted: was 50, reserved was 30 (20 from first SO + 10 from this SO).
      // After dispatching 10: current_stock should be 40, reserved_stock should be 20!
      const fpCheck = await db.query<{ current_stock: string; reserved_stock: string }>(
        `SELECT current_stock, reserved_stock FROM finished_products WHERE id = $1`,
        [testFpId1],
      );
      expect(parseFloat(fpCheck.rows[0].current_stock)).toBe(40.0);
      expect(parseFloat(fpCheck.rows[0].reserved_stock)).toBe(20.0);

      // Verify StockMovement entry
      const smCheck = await db.query<{ transaction_type: string; stock_out: string; reference_number: string }>(
        `SELECT transaction_type, stock_out, reference_number FROM stock_movements WHERE reference_number = $1`,
        [deliveryNumber],
      );
      expect(smCheck.rows.length).toBe(1);
      expect(smCheck.rows[0].transaction_type).toBe('sale');
      expect(parseFloat(smCheck.rows[0].stock_out)).toBe(10.0);

      // Verify SO status updated to delivered
      const soCheck = await db.query<{ sales_order_status: string }>(
        `SELECT sales_order_status FROM sales WHERE id = $1`,
        [salesOrderId],
      );
      expect(soCheck.rows[0].sales_order_status).toBe('delivered');
    });

    it('Negative: Dispatching more than remaining order quantity returns 400 Bad Request', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/deliveries')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          salesOrderId: salesOrderId,
          vehicleNumber: 'MH-04-AZ-8812',
          items: [
            {
              finishedProductId: testFpId1,
              quantity: 5.0,
            },
          ],
        });

      expect(res.status).toBe(400);
    });

    it('Positive: Should update tracking details on delivery challan', async () => {
      const res = await request(app.getHttpServer())
        .patch(`/api/v1/sales/deliveries/${deliveryId}/tracking`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          courierName: 'Blue Dart Logistics',
          trackingNumber: 'BLU-8822001',
          dispatchNotes: 'Delivered at site gate 3',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.courierName).toBe('Blue Dart Logistics');
      expect(res.body.data.trackingNumber).toBe('BLU-8822001');
    });
  });

  // ==========================================================================
  // MILESTONE 5D: TAX INVOICES, COUNTER SALES & ARCHITECT COMMISSIONS
  // ==========================================================================
  describe('Milestone 5D: Tax Invoices, Ledgers, Direct POS Sales & Architect Commissions', () => {
    let deliveryId: string;
    let invoiceId: string;

    beforeAll(async () => {
      // Create and dispatch an order to get a delivery document
      const soRes = await request(app.getHttpServer())
        .post('/api/v1/sales/orders')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          partyType: 'customer',
          partyId: testCustomerId,
          architectId: testArchitectId,
          items: [
            {
              finishedProductId: testFpId1,
              quantity: 5.0,
              rate: 4000.0,
              gstPercent: 18.0,
            },
          ],
        });
      const soId = soRes.body.data.id;
      createdSaleIds.push(soId);

      const dlvRes = await request(app.getHttpServer())
        .post('/api/v1/sales/deliveries')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          salesOrderId: soId,
          vehicleNumber: 'MH-04-1234',
          items: [{ finishedProductId: testFpId1, quantity: 5.0 }],
        });
      deliveryId = dlvRes.body.data.id;
      createdSaleIds.push(deliveryId);
    });

    it('Positive: Should generate Tax Invoice from Delivery, debit Customer balance & generate Architect Commission', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/invoices/from-delivery')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          deliveryId: deliveryId,
          discountAmount: 0.0,
          initialPaidAmount: 0.0,
          notes: 'GST Tax Invoice against delivery',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.documentType).toBe('invoice');
      expect(res.body.data.totalAmount).toBe(23600.0);
      expect(res.body.data.pendingAmount).toBe(23600.0);

      invoiceId = res.body.data.id;
      createdSaleIds.push(invoiceId);

      // 1. Verify Customer Outstanding Balance increased by 23600.00
      const custCheck = await db.query<{ outstanding_amount: string }>(
        `SELECT outstanding_amount FROM customers WHERE id = $1`,
        [testCustomerId],
      );
      expect(parseFloat(custCheck.rows[0].outstanding_amount)).toBe(23600.0);

      // 2. Verify Architect Commission auto-registered: 10% on taxable (20000) = 2000.00
      const commCheck = await db.query<{ commission_amount: string; status: string }>(
        `SELECT commission_amount, status FROM architect_commissions WHERE sale_invoice_id = $1`,
        [invoiceId],
      );
      expect(commCheck.rows.length).toBe(1);
      expect(parseFloat(commCheck.rows[0].commission_amount)).toBe(2000.0);
      expect(commCheck.rows[0].status).toBe('generated');
    });

    it('Positive: Should record payment against Tax Invoice and reduce Customer outstanding balance', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/v1/sales/invoices/${invoiceId}/payments`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          amount: 23600.0,
          paymentMode: 'bankTransfer',
          transactionReference: 'RTGS-99001122',
          notes: 'Full invoice settlement',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('paid');
      expect(res.body.data.pendingAmount).toBe(0.0);

      // Verify Customer Outstanding Balance cleared back to 0.00
      const custCheck = await db.query<{ outstanding_amount: string }>(
        `SELECT outstanding_amount FROM customers WHERE id = $1`,
        [testCustomerId],
      );
      expect(parseFloat(custCheck.rows[0].outstanding_amount)).toBe(0.0);
    });

    it('Positive (Direct Counter POS Sale): Should execute invoice, stock deduction, and payment in one atomic step', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/direct-sale')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          partyType: 'customer',
          partyId: testCustomerId,
          items: [
            {
              finishedProductId: testFpId1,
              quantity: 2.0,
              rate: 4000.0,
              discountAmount: 0.0,
              gstPercent: 18.0,
            },
          ],
          paidAmount: 9440.0,
          paymentMode: 'upi',
          notes: 'Showroom counter purchase',
        });

      expect(res.status).toBe(201);
      expect(res.body.data.documentType).toBe('invoice');
      expect(res.body.data.status).toBe('paid');
      expect(res.body.data.totalAmount).toBe(9440.0);
      createdSaleIds.push(res.body.data.id);

      // Verify stock was deducted by 2.0 (was 25 available after 20 reserved, 10 delivered, 5 delivered).
      // current_stock was 35 (50 - 10 - 5). Now 35 - 2 = 33!
      const fpCheck = await db.query<{ current_stock: string }>(
        `SELECT current_stock FROM finished_products WHERE id = $1`,
        [testFpId1],
      );
      expect(parseFloat(fpCheck.rows[0].current_stock)).toBe(33.0);
    });
  });

  // ==========================================================================
  // MILESTONE 5E: SALES RETURNS (RMA) & REFUNDS
  // ==========================================================================
  describe('Milestone 5E: Sales Returns (RMA), Condition Inspection & Commission Reversal', () => {
    let testInvoiceId: string;
    let resalableReturnId: string;
    let damagedReturnId: string;

    beforeAll(async () => {
      // Create a direct sale invoice for return testing
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/direct-sale')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          partyType: 'customer',
          partyId: testCustomerId,
          architectId: testArchitectId,
          items: [
            {
              finishedProductId: testFpId1,
              quantity: 4.0,
              rate: 4000.0,
              gstPercent: 18.0,
            },
          ],
          paidAmount: 0.0,
          paymentMode: 'bankTransfer',
        });
      testInvoiceId = res.body.data.id;
      createdSaleIds.push(testInvoiceId);
    });

    it('Positive: Should submit a sales return request (RMA)', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/returns')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          originalInvoiceId: testInvoiceId,
          returnReason: 'Wrong beam angle delivered',
          condition: 'resalable',
          financialAction: 'adjustOutstanding',
          items: [
            {
              finishedProductId: testFpId1,
              quantity: 2.0,
              returnCondition: 'resalable',
            },
          ],
        });

      expect(res.status).toBe(201);
      expect(res.body.data.documentType).toBe('salesReturn');
      expect(res.body.data.salesReturnStatus).toBe('submitted');
      resalableReturnId = res.body.data.id;
      createdSaleIds.push(resalableReturnId);
    });

    it('Positive (Resalable Return): Approving should increment stock, adjust customer ledger & reverse commission', async () => {
      const preStock = await db.query<{ current_stock: string }>(
        `SELECT current_stock FROM finished_products WHERE id = $1`,
        [testFpId1],
      );
      const preCurrentStock = parseFloat(preStock.rows[0].current_stock);

      const res = await request(app.getHttpServer())
        .post(`/api/v1/sales/returns/${resalableReturnId}/approve`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send();

      expect(res.status).toBe(200);
      expect(res.body.data.salesReturnStatus).toBe('approved');
      expect(res.body.data.isProcessed).toBe(true);

      // Verify stock was restored by 2.0
      const postStock = await db.query<{ current_stock: string }>(
        `SELECT current_stock FROM finished_products WHERE id = $1`,
        [testFpId1],
      );
      expect(parseFloat(postStock.rows[0].current_stock)).toBe(preCurrentStock + 2.0);

      // Verify architect commission was marked reversed
      const commCheck = await db.query<{ status: string }>(
        `SELECT status FROM architect_commissions WHERE sale_invoice_id = $1`,
        [testInvoiceId],
      );
      if (commCheck.rows.length > 0) {
        expect(commCheck.rows[0].status).toBe('reversed');
      }
    });

    it('Positive (Damaged Return): Approving should create damaged StockAdjustment WITHOUT adding to salable stock', async () => {
      // Create return for 1 damaged unit
      const rmaRes = await request(app.getHttpServer())
        .post('/api/v1/sales/returns')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          originalInvoiceId: testInvoiceId,
          returnReason: 'Diffuser glass cracked in transit',
          condition: 'damaged',
          financialAction: 'adjustOutstanding',
          items: [
            {
              finishedProductId: testFpId1,
              quantity: 1.0,
              returnCondition: 'damaged',
            },
          ],
        });
      damagedReturnId = rmaRes.body.data.id;
      createdSaleIds.push(damagedReturnId);

      const preStock = await db.query<{ current_stock: string }>(
        `SELECT current_stock FROM finished_products WHERE id = $1`,
        [testFpId1],
      );
      const preCurrentStock = parseFloat(preStock.rows[0].current_stock);

      const res = await request(app.getHttpServer())
        .post(`/api/v1/sales/returns/${damagedReturnId}/approve`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send();

      expect(res.status).toBe(200);

      // Verify stock did NOT increase
      const postStock = await db.query<{ current_stock: string }>(
        `SELECT current_stock FROM finished_products WHERE id = $1`,
        [testFpId1],
      );
      expect(parseFloat(postStock.rows[0].current_stock)).toBe(preCurrentStock);

      // Verify StockAdjustment was recorded with reason damagedGoods
      const adjCheck = await db.query<{ reason: string }>(
        `SELECT reason FROM stock_adjustments WHERE remarks LIKE $1`,
        [`%${res.body.data.invoiceNumber}%`],
      );
      expect(adjCheck.rows.length).toBe(1);
      expect(adjCheck.rows[0].reason).toBe('damagedGoods');
    });

    it('Negative: Returning quantity exceeding remaining invoiced quantity returns 400 Bad Request', async () => {
      // 4 ordered, 2 returned resalable, 1 returned damaged -> only 1 remaining!
      // Trying to return 5 should fail:
      const res = await request(app.getHttpServer())
        .post('/api/v1/sales/returns')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          originalInvoiceId: testInvoiceId,
          returnReason: 'Excess return attempt',
          condition: 'resalable',
          items: [
            {
              finishedProductId: testFpId1,
              quantity: 5.0,
            },
          ],
        });

      expect(res.status).toBe(400);
    });

    it('Negative: Re-approving an already processed return returns 400 Bad Request', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/v1/sales/returns/${resalableReturnId}/approve`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send();

      expect(res.status).toBe(400);
    });
  });

  // ==========================================================================
  // MILESTONE 5F: SALES DASHBOARD & FUNNEL METRICS
  // ==========================================================================
  describe('Milestone 5F: Sales Operations Dashboard & Metrics', () => {
    it('Positive: Should return comprehensive sales pipeline metrics matching frontend dashboard', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/sales/dashboard')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data).toBeDefined();
      expect(res.body.data).toHaveProperty('totalQuotationsCount');
      expect(res.body.data).toHaveProperty('totalSalesOrdersCount');
      expect(res.body.data).toHaveProperty('totalInvoicedRevenue');
      expect(res.body.data).toHaveProperty('totalSalesReturnsAmount');
      expect(res.body.data).toHaveProperty('netSalesRevenue');
      expect(res.body.data).toHaveProperty('pendingRefundsCount');
    });
  });
});
