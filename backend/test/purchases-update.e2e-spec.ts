import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

/**
 * 7.5+ Update Purchase (Edit) E2E — covers the reported bug:
 * "After editing a purchase, the edited date is not reflected."
 *
 * Root cause being fixed: the edit flow persisted nothing on the original
 * purchase (it re-created a new bill). These specs enforce a PATCH
 * /api/v1/purchases/:id contract that:
 *  - updates header fields (purchase date, vendor invoice no, notes, ...)
 *  - keeps purchase_number and (when items omitted) line items intact
 *  - adjusts stock by NET quantity deltas and writes the ledger
 *  - replaces line items fully and safely (revert old, inward new)
 *  - applies/transitions stock + vendor balance when draft -> posted
 *  - rejects editing cancelled purchases and revert-to-draft transitions
 * All records created here are torn down (automated cleanup).
 */

describe('Purchase Update / Edit Lifecycle (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  const testCid = `e2e_purchase_update_${Date.now()}`;

  let testVendorId: string;
  let testVendor2Id: string;
  let testVendor2Name: string;
  let testCategoryId: string;
  let testUnitId: string;
  let testRawMaterialId: string;
  let testFinishedProductId: string;

  const testRmCode = `RM-UPD-${Date.now().toString().slice(-4)}`;
  const testFpCode = `FP-UPD-${Date.now().toString().slice(-4)}`;
  const testVendorGst = `24AABCU${Math.floor(1000 + Math.random() * 9000)}B1Z5`;
  const testVendorGst2 = `24AABCV${Math.floor(1000 + Math.random() * 9000)}C1Z6`;
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

    const catRes = await db.query<{ id: string }>('SELECT id FROM categories LIMIT 1');
    testCategoryId = catRes.rows[0].id;
    const unitRes = await db.query<{ id: string }>('SELECT id FROM measurement_units LIMIT 1');
    testUnitId = unitRes.rows[0].id;

    // Create Test Vendor starting at zero outstanding
    const venRes = await db.query<{ id: string }>(
      `INSERT INTO vendors (name, contact_person, mobile, email, gst_number, pan_number, address, payment_terms, credit_limit, outstanding_balance)
       VALUES ($1, 'Test Update Vendor Head', '+91 98980 44556', 'vendor@update-test.com', $2, 'AABCU1234B', 'GIDC Vatva, Ahmedabad', 'Net 30 Days', 1000000.00, 0.00)
       RETURNING id`,
      ['Update Test Extruder Pvt Ltd', testVendorGst],
    );
    testVendorId = venRes.rows[0].id;

    // Second vendor to verify pending balance transfer when the vendor is switched on edit
    const ven2Res = await db.query<{ id: string; name: string }>(
      `INSERT INTO vendors (name, contact_person, mobile, email, gst_number, pan_number, address, payment_terms, credit_limit, outstanding_balance)
       VALUES ($1, 'Test Update Vendor Head B', '+91 98980 77889', 'vendor2@update-test.com', $2, 'AABCV5678C', 'Makarpura GIDC, Vadodara', 'Net 45 Days', 500000.00, 0.00)
       RETURNING id, name`,
      [`Vendor Two Switch Test ${Math.floor(1000 + Math.random() * 9000)}`, testVendorGst2],
    );
    testVendor2Id = ven2Res.rows[0].id;
    testVendor2Name = ven2Res.rows[0].name;

    // Raw material with baseline stock 50.0
    const rmRes = await db.query<{ id: string }>(
      `INSERT INTO raw_materials (name, item_code, category_id, unit_id, opening_stock, current_stock, minimum_stock, default_purchase_price)
       VALUES ($1, $2, $3, $4, 50.0000, 50.0000, 10.0000, 450.00)
       RETURNING id`,
      ['Update Test Profile 6063', testRmCode, testCategoryId, testUnitId],
    );
    testRawMaterialId = rmRes.rows[0].id;

    // Finished product with baseline stock 10.0
    const fpRes = await db.query<{ id: string }>(
      `INSERT INTO finished_products (name, item_code, category_id, unit_id, opening_stock, current_stock, minimum_stock, cost_price)
       VALUES ($1, $2, $3, $4, 10.0000, 10.0000, 5.0000, 1200.00)
       RETURNING id`,
      ['Update Test Pendant Light', testFpCode, testCategoryId, testUnitId],
    );
    testFinishedProductId = fpRes.rows[0].id;
  });

  afterAll(async () => {
    try {
      if (createdPurchaseIds.length > 0) {
        await db.query(
          `DELETE FROM stock_movements WHERE reference_number IN (SELECT purchase_number FROM purchases WHERE id = ANY($1::uuid[]))`,
          [createdPurchaseIds],
        );
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
      if (testVendor2Id) {
        await db.query(`DELETE FROM vendors WHERE id = $1`, [testVendor2Id]);
      }
    } catch (err) {
      console.error('Teardown error in purchases-update:', err);
    } finally {
      await app.close();
    }
  });

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------
  const getRmStock = async (): Promise<number> => {
    const res = await db.query<{ current_stock: string }>(
      'SELECT current_stock FROM raw_materials WHERE id = $1',
      [testRawMaterialId],
    );
    return Number(res.rows[0].current_stock);
  };

  const getFpStock = async (): Promise<number> => {
    const res = await db.query<{ current_stock: string }>(
      'SELECT current_stock FROM finished_products WHERE id = $1',
      [testFinishedProductId],
    );
    return Number(res.rows[0].current_stock);
  };

  const getVendorOutstanding = async (): Promise<number> => {
    const res = await db.query<{ outstanding_balance: string }>(
      'SELECT outstanding_balance FROM vendors WHERE id = $1',
      [testVendorId],
    );
    return Number(res.rows[0].outstanding_balance);
  };

  const createPurchase = async (body: Record<string, any>): Promise<any> => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/purchases')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send(body);
    expect(res.status).toBe(201);
    createdPurchaseIds.push(res.body.data.id);
    return res.body.data;
  };

  const patchPurchase = async (id: string, body: Record<string, any>): Promise<any> => {
    return request(app.getHttpServer())
      .patch(`/api/v1/purchases/${id}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send(body);
  };

  const rmLine = (qty: number, rate: number) => ({
    itemType: 'rawMaterial',
    rawMaterialId: testRawMaterialId,
    rawMaterialName: 'Update Test Profile 6063',
    rawMaterialCode: testRmCode,
    quantity: qty,
    unit: 'MTR',
    rate,
    discountAmount: 0.0,
    gstPercent: 18.0,
    taxableAmount: qty * rate,
    cgstAmount: qty * rate * 0.09,
    sgstAmount: qty * rate * 0.09,
    igstAmount: 0.0,
    lineTotal: qty * rate * 1.18,
  });

  const fpLine = (qty: number, rate: number) => ({
    itemType: 'finishedProduct',
    finishedProductId: testFinishedProductId,
    finishedProductName: 'Update Test Pendant Light',
    finishedProductCode: testFpCode,
    quantity: qty,
    unit: 'PCS',
    rate,
    discountAmount: 0.0,
    gstPercent: 18.0,
    taxableAmount: qty * rate,
    cgstAmount: qty * rate * 0.09,
    sgstAmount: qty * rate * 0.09,
    igstAmount: 0.0,
    lineTotal: qty * rate * 1.18,
  });

  // -------------------------------------------------------------------------
  // Positive — The reported bug: edited date must be persisted & returned
  // -------------------------------------------------------------------------
  describe('7.A Update header fields (reported date-not-updating bug)', () => {
    it('should save the edited purchase date and header fields, keeping number, items, and stock intact', async () => {
      const created = await createPurchase({
        vendorId: testVendorId,
        vendorName: 'Update Test Extruder Pvt Ltd',
        vendorInvoiceNumber: 'INV-UPD-ORIG',
        purchaseDate: '2026-10-01T09:00:00.000Z',
        purchaseType: 'rawMaterial',
        items: [rmLine(10, 450)],
        subtotalAmount: 4500.0,
        discountAmount: 0.0,
        taxableAmount: 4500.0,
        cgstAmount: 405.0,
        sgstAmount: 405.0,
        igstAmount: 0.0,
        gstAmount: 810.0,
        totalAmount: 5310.0,
        paidAmount: 0.0,
        pendingAmount: 5310.0,
        paymentMode: 'credit',
        status: 'saved',
        notes: 'Original bill',
      });

      const stockBefore = await getRmStock();
      const outstandingBefore = await getVendorOutstanding();

      const res = await patchPurchase(created.id, {
        purchaseDate: '2026-01-15T09:00:00.000Z',
        vendorInvoiceNumber: 'INV-UPD-EDITED',
        notes: 'Date corrected after supplier reprint',
      });

      expect(res.status).toBe(200);
      expect(res.body.data).toBeDefined();
      // THE reported bug assertion: the edited date is returned & persisted
      expect(res.body.data.purchaseDate).toContain('2026-01-15');
      // PO number must remain the same document
      expect(res.body.data.purchaseNumber).toBe(created.purchaseNumber);
      expect(res.body.data.vendorInvoiceNumber).toBe('INV-UPD-EDITED');
      expect(res.body.data.notes).toBe('Date corrected after supplier reprint');
      // Items preserved when omitted from the payload
      expect(res.body.data.items.length).toBe(1);
      expect(res.body.data.items[0].rawMaterialCode).toBe(testRmCode);

      // Persisted state check via GET detail
      const getRes = await request(app.getHttpServer())
        .get(`/api/v1/purchases/${created.id}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);
      expect(getRes.status).toBe(200);
      expect(getRes.body.data.purchaseDate).toContain('2026-01-15');
      expect(getRes.body.data.updatedAt).not.toBe(created.updatedAt ?? null);

      // Stock absolutely untouched by a header-only edit
      expect(await getRmStock()).toBe(stockBefore);
      // Vendor outstanding untouched (pending unchanged)
      expect(await getVendorOutstanding()).toBe(outstandingBefore);

      // List view reflects the edited date
      const listRes = await request(app.getHttpServer())
        .get(`/api/v1/purchases?search=INV-UPD-EDITED`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);
      expect(listRes.status).toBe(200);
      expect(listRes.body.data.items.length).toBe(1);
      expect(listRes.body.data.items[0].purchaseDate).toContain('2026-01-15');
    });
  });

  // -------------------------------------------------------------------------
  // Positive — Net stock delta on quantity edition
  // -------------------------------------------------------------------------
  describe('7.B Net stock delta when editing line quantities', () => {
    it('should adjust raw material stock by +20 when quantity is edited 40 -> 60 and log one ledger movement', async () => {
      const created = await createPurchase({
        vendorId: testVendorId,
        vendorName: 'Update Test Extruder Pvt Ltd',
        vendorInvoiceNumber: 'INV-UPD-QTY',
        purchaseDate: '2026-10-02T09:00:00.000Z',
        purchaseType: 'rawMaterial',
        items: [rmLine(40, 300)],
        subtotalAmount: 12000.0,
        discountAmount: 0.0,
        taxableAmount: 12000.0,
        cgstAmount: 1080.0,
        sgstAmount: 1080.0,
        igstAmount: 0.0,
        gstAmount: 2160.0,
        totalAmount: 14160.0,
        paidAmount: 0.0,
        pendingAmount: 14160.0,
        paymentMode: 'credit',
        status: 'saved',
      });

      const stockBefore = await getRmStock();

      const res = await patchPurchase(created.id, {
        purchaseDate: '2026-10-05T09:00:00.000Z',
        purchaseType: 'rawMaterial',
        items: [rmLine(60, 300)],
        subtotalAmount: 18000.0,
        discountAmount: 0.0,
        taxableAmount: 18000.0,
        cgstAmount: 1620.0,
        sgstAmount: 1620.0,
        igstAmount: 0.0,
        gstAmount: 3240.0,
        totalAmount: 21240.0,
        paidAmount: 0.0,
        pendingAmount: 21240.0,
      });

      expect(res.status).toBe(200);
      expect(res.body.data.items.length).toBe(1);
      expect(Number(res.body.data.items[0].quantity)).toBe(60.0);

      // Net stock delta: out of 40 applied, now 60 due => +20
      expect(await getRmStock()).toBe(stockBefore + 20.0);

      // One consolidated 'purchase' ledger movement for the +20 net delta
      const movRes = await db.query<{ stock_in: string; stock_out: string; transaction_type: string; date: string }>(
        `SELECT stock_in, stock_out, transaction_type, date
         FROM stock_movements
         WHERE reference_number = $1 AND item_id = $2
         ORDER BY date DESC, created_at DESC LIMIT 2`,
        [created.purchaseNumber, testRawMaterialId],
      );
      expect(movRes.rows.length).toBeGreaterThanOrEqual(1);
      const latest = movRes.rows[0];
      expect(latest.transaction_type).toBe('purchase');
      expect(Number(latest.stock_in)).toBe(20.0);
      expect(Number(latest.stock_out)).toBe(0.0);
    });
  });

  // -------------------------------------------------------------------------
  // Positive — Full line replacement: revert old item, inward new item
  // -------------------------------------------------------------------------
  describe('7.C Replace raw material line with finished product line', () => {
    it('should revert the old item stock, inward the new item stock, and write balanced ledger movements', async () => {
      const created = await createPurchase({
        vendorId: testVendorId,
        vendorName: 'Update Test Extruder Pvt Ltd',
        vendorInvoiceNumber: 'INV-UPD-REPLACE',
        purchaseDate: '2026-10-03T09:00:00.000Z',
        purchaseType: 'rawMaterial',
        items: [rmLine(40, 350)],
        subtotalAmount: 14000.0,
        discountAmount: 0.0,
        taxableAmount: 14000.0,
        cgstAmount: 1260.0,
        sgstAmount: 1260.0,
        igstAmount: 0.0,
        gstAmount: 2520.0,
        totalAmount: 16520.0,
        paidAmount: 0.0,
        pendingAmount: 16520.0,
        paymentMode: 'credit',
        status: 'saved',
      });

      const rmBefore = await getRmStock();
      const fpBefore = await getFpStock();

      const res = await patchPurchase(created.id, {
        purchaseType: 'finishedProduct',
        items: [fpLine(10, 1000)],
        subtotalAmount: 10000.0,
        discountAmount: 0.0,
        taxableAmount: 10000.0,
        cgstAmount: 900.0,
        sgstAmount: 900.0,
        igstAmount: 0.0,
        gstAmount: 1800.0,
        totalAmount: 11800.0,
        paidAmount: 0.0,
        pendingAmount: 11800.0,
      });

      expect(res.status).toBe(200);
      expect(res.body.data.purchaseType).toBe('finishedProduct');
      expect(res.body.data.items.length).toBe(1);
      expect(res.body.data.items[0].finishedProductCode).toBe(testFpCode);

      // New stock levels
      expect(await getRmStock()).toBe(rmBefore - 40.0);
      expect(await getFpStock()).toBe(fpBefore + 10.0);

      // Ledger: revert out (purchaseReturn) and inward (purchase)
      const rmMov = await db.query<{ stock_out: string; transaction_type: string }>(
        `SELECT stock_out, transaction_type FROM stock_movements
         WHERE reference_number = $1 AND item_id = $2
         ORDER BY created_at DESC LIMIT 1`,
        [created.purchaseNumber, testRawMaterialId],
      );
      expect(rmMov.rows.length).toBe(1);
      expect(rmMov.rows[0].transaction_type).toBe('purchaseReturn');
      expect(Number(rmMov.rows[0].stock_out)).toBe(40.0);

      const fpMov = await db.query<{ stock_in: string; transaction_type: string }>(
        `SELECT stock_in, transaction_type FROM stock_movements
         WHERE reference_number = $1 AND item_id = $2
         ORDER BY created_at DESC LIMIT 1`,
        [created.purchaseNumber, testFinishedProductId],
      );
      expect(fpMov.rows.length).toBe(1);
      expect(fpMov.rows[0].transaction_type).toBe('purchase');
      expect(Number(fpMov.rows[0].stock_in)).toBe(10.0);
    });
  });

  // -------------------------------------------------------------------------
  // Positive — Draft -> Posted transition stocks the purchase in
  // -------------------------------------------------------------------------
  describe('7.D Draft to posted transition on edit', () => {
    it('should apply stock inward and vendor outstanding only on posting', async () => {
      const created = await createPurchase({
        vendorId: testVendorId,
        vendorName: 'Update Test Extruder Pvt Ltd',
        vendorInvoiceNumber: 'INV-UPD-DRAFT',
        purchaseDate: '2026-10-04T09:00:00.000Z',
        purchaseType: 'rawMaterial',
        items: [rmLine(30, 300)],
        subtotalAmount: 9000.0,
        discountAmount: 0.0,
        taxableAmount: 9000.0,
        cgstAmount: 810.0,
        sgstAmount: 810.0,
        igstAmount: 0.0,
        gstAmount: 1620.0,
        totalAmount: 10620.0,
        paidAmount: 0.0,
        pendingAmount: 10620.0,
        paymentMode: 'credit',
        status: 'draft',
      });

      const stockBefore = await getRmStock();
      const outstandingBefore = await getVendorOutstanding();

      const res = await patchPurchase(created.id, {
        status: 'saved',
        items: [rmLine(30, 300)],
        subtotalAmount: 9000.0,
        discountAmount: 0.0,
        taxableAmount: 9000.0,
        cgstAmount: 810.0,
        sgstAmount: 810.0,
        igstAmount: 0.0,
        gstAmount: 1620.0,
        totalAmount: 10620.0,
        paidAmount: 0.0,
        pendingAmount: 10620.0,
      });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('saved');

      expect(await getRmStock()).toBe(stockBefore + 30.0);
      expect(await getVendorOutstanding()).toBeCloseTo(outstandingBefore + 10620.0, 2);
    });
  });

  // -------------------------------------------------------------------------
  // Negative
  // -------------------------------------------------------------------------
  describe('7.E Negative & edge cases', () => {
    it('should return 404 when updating a non-existent purchase', async () => {
      const res = await patchPurchase('00000000-0000-4000-8000-0000000000d1', {
        notes: 'ghost edit',
      });
      expect(res.status).toBe(404);
    });

    it('should return 409 and keep balances intact when editing a cancelled purchase', async () => {
      const created = await createPurchase({
        vendorId: testVendorId,
        vendorName: 'Update Test Extruder Pvt Ltd',
        vendorInvoiceNumber: 'INV-UPD-CANCEL',
        purchaseDate: '2026-10-06T09:00:00.000Z',
        purchaseType: 'rawMaterial',
        items: [rmLine(25, 400)],
        subtotalAmount: 10000.0,
        discountAmount: 0.0,
        taxableAmount: 10000.0,
        cgstAmount: 900.0,
        sgstAmount: 900.0,
        igstAmount: 0.0,
        gstAmount: 1800.0,
        totalAmount: 11800.0,
        paidAmount: 0.0,
        pendingAmount: 11800.0,
        paymentMode: 'credit',
        status: 'saved',
      });

      const cancelRes = await request(app.getHttpServer())
        .patch(`/api/v1/purchases/${created.id}/status`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({ status: 'cancelled', reason: 'Test cancellation' });
      expect(cancelRes.status).toBe(200);

      const stockBefore = await getRmStock();
      const outstandingBefore = await getVendorOutstanding();

      const res = await patchPurchase(created.id, {
        purchaseDate: '2026-01-01T00:00:00.000Z',
      });
      expect(res.status).toBe(409);

      // No side effects on rejected edit
      expect(await getRmStock()).toBe(stockBefore);
      expect(await getVendorOutstanding()).toBe(outstandingBefore);
    });

    it('should return 409 when reverting a posted purchase back to draft', async () => {
      const created = await createPurchase({
        vendorId: testVendorId,
        vendorName: 'Update Test Extruder Pvt Ltd',
        vendorInvoiceNumber: 'INV-UPD-REVERT',
        purchaseDate: '2026-10-07T09:00:00.000Z',
        purchaseType: 'rawMaterial',
        items: [rmLine(15, 300)],
        subtotalAmount: 4500.0,
        discountAmount: 0.0,
        taxableAmount: 4500.0,
        cgstAmount: 405.0,
        sgstAmount: 405.0,
        igstAmount: 0.0,
        gstAmount: 810.0,
        totalAmount: 5310.0,
        paidAmount: 0.0,
        pendingAmount: 5310.0,
        paymentMode: 'credit',
        status: 'saved',
      });

      const res = await patchPurchase(created.id, { status: 'draft' });
      expect(res.status).toBe(409);
    });

    it('should reject non-whitelisted fields (purchaseNumber) with 400', async () => {
      const createdPurchaseIdsLast = createdPurchaseIds[createdPurchaseIds.length - 1];
      const res = await patchPurchase(createdPurchaseIdsLast, {
        purchaseNumber: 'PO-2026-9999',
      });
      expect(res.status).toBe(400);
    });

    it('should reject directly cancelling a purchase via edit (409) and advise the cancellation endpoint', async () => {
      const created = await createPurchase({
        vendorId: testVendorId,
        vendorName: 'Update Test Extruder Pvt Ltd',
        vendorInvoiceNumber: 'INV-UPD-NO-CANCEL',
        purchaseDate: '2026-10-08T09:00:00.000Z',
        purchaseType: 'rawMaterial',
        items: [rmLine(5, 450)],
        subtotalAmount: 2250.0,
        discountAmount: 0.0,
        taxableAmount: 2250.0,
        cgstAmount: 202.5,
        sgstAmount: 202.5,
        igstAmount: 0.0,
        gstAmount: 405.0,
        totalAmount: 2655.0,
        paidAmount: 0.0,
        pendingAmount: 2655.0,
        paymentMode: 'credit',
        status: 'saved',
      });

      const res = await patchPurchase(created.id, { status: 'cancelled' });
      expect(res.status).toBe(409);
    });

    it('should transfer vendor pending balance to the new vendor when the vendor is switched on edit', async () => {
      const created = await createPurchase({
        vendorId: testVendorId,
        vendorName: 'Update Test Extruder Pvt Ltd',
        vendorInvoiceNumber: 'INV-UPD-VSWITCH',
        purchaseDate: '2026-10-09T09:00:00.000Z',
        purchaseType: 'rawMaterial',
        items: [rmLine(10, 450)],
        subtotalAmount: 4500.0,
        discountAmount: 0.0,
        taxableAmount: 4500.0,
        cgstAmount: 405.0,
        sgstAmount: 405.0,
        igstAmount: 0.0,
        gstAmount: 810.0,
        totalAmount: 5310.0,
        paidAmount: 0.0,
        pendingAmount: 5310.0,
        paymentMode: 'credit',
        status: 'saved',
      });

      const v1Before = await getVendorOutstanding();
      const v2ResBefore = await db.query<{ outstanding_balance: string }>(
        'SELECT outstanding_balance FROM vendors WHERE id = $1',
        [testVendor2Id],
      );
      const v2Before = Number(v2ResBefore.rows[0].outstanding_balance);

      const res = await patchPurchase(created.id, { vendorId: testVendor2Id });

      expect(res.status).toBe(200);
      expect(res.body.data.vendorId).toBe(testVendor2Id);
      // Vendor display name is adopted from the vendor master when not supplied
      expect(res.body.data.vendorName).toBe(testVendor2Name);

      const v1After = await getVendorOutstanding();
      const v2ResAfter = await db.query<{ outstanding_balance: string }>(
        'SELECT outstanding_balance FROM vendors WHERE id = $1',
        [testVendor2Id],
      );
      const v2After = Number(v2ResAfter.rows[0].outstanding_balance);

      // Pending 5310 moved from vendor 1 ledger to vendor 2 ledger
      expect(v1After).toBeCloseTo(v1Before - 5310.0, 2);
      expect(v2After).toBeCloseTo(v2Before + 5310.0, 2);
    });

    it('should reject a malformed purchaseDate with 400', async () => {
      const res = await patchPurchase('00000000-0000-4000-8000-0000000000d2', {
        purchaseDate: 'not-a-date',
      });
      expect(res.status).toBe(400);
    });
  });
});
