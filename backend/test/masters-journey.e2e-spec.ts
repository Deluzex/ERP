import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Masters Domain Lifecycle (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  const testCid = `e2e_masters_${Date.now()}`;
  const testVendorGst = `24AAATE${Math.floor(1000 + Math.random() * 9000)}F1Z5`;
  const testItemCode = `RM-TEST-${Date.now().toString().slice(-4)}`;

  let categoryId: string;
  let unitId: string;
  let vendorId: string;
  let rawMaterialId: string;
  let finishedProductId: string;
  let customerId: string;
  let architectId: string;
  let dealerId: string;

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

    // Login as Super Admin
    const loginRes = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCid)
      .send({
        email: 'admin@deluzex.com',
        password: 'Admin@123',
      });

    accessToken = loginRes.body.data.accessToken;
  });

  afterAll(async () => {
    // Automated database cleanup: remove test entries leaving zero pollution
    try {
      if (rawMaterialId) {
        await db.query('DELETE FROM raw_materials WHERE id = $1', [rawMaterialId]);
      }
      await db.query('DELETE FROM raw_materials WHERE item_code = $1', [testItemCode]);
      if (finishedProductId) {
        await db.query('DELETE FROM finished_products WHERE id = $1', [finishedProductId]);
      }
      if (customerId && architectId) {
        await db.query('UPDATE customers SET linked_architect_id = NULL WHERE id = $1', [customerId]);
        await db.query('UPDATE architects SET linked_customer_id = NULL WHERE id = $1', [architectId]);
      }
      if (customerId) {
        await db.query('DELETE FROM customers WHERE id = $1', [customerId]);
      }
      if (architectId) {
        await db.query('DELETE FROM architects WHERE id = $1', [architectId]);
      }
      if (dealerId) {
        await db.query('DELETE FROM dealers WHERE id = $1', [dealerId]);
      }
      if (vendorId) {
        await db.query('DELETE FROM vendors WHERE id = $1', [vendorId]);
      }
      if (categoryId) {
        await db.query('DELETE FROM categories WHERE id = $1', [categoryId]);
      }
      await db.query('DELETE FROM audit_logs WHERE correlation_id = $1', [testCid]);
    } catch (err) {
      console.error('Cleanup notice:', (err as Error).message);
    }
    await app.close();
  });

  describe('1. Categories & Measurement Units', () => {
    it('Positive: should fetch seeded measurement units including PCS', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/masters/units')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      expect(Array.isArray(res.body.data)).toBe(true);
      const pcs = res.body.data.find((u: any) => u.symbol === 'PCS');
      expect(pcs).toBeDefined();
      unitId = pcs.id;
    });

    it('Positive: should create a new category', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/masters/categories')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          name: `Aluminium Extrusions ${Date.now()}`,
          description: 'High grade aluminium structural channels',
        })
        .expect(201);

      expect(res.body.data.id).toBeDefined();
      categoryId = res.body.data.id;
    });
  });

  describe('2. Vendors Master & Soft Delete', () => {
    it('Positive: should create a vendor with credit limit and payment terms', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/masters/vendors')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          name: 'Shreeji Aluminium Corp',
          contactPerson: 'Kishore Bhai',
          mobile: '+91 98250 12345',
          email: 'kishore@shreejialum.com',
          gstNumber: testVendorGst,
          panNumber: 'AAATE1234F',
          address: 'Plot 12, GIDC Odhav, Ahmedabad',
          paymentTerms: 'Net 30 Days',
          creditLimit: 750000.0,
        })
        .expect(201);

      expect(res.body.data.id).toBeDefined();
      expect(res.body.data.gstNumber).toBe(testVendorGst);
      expect(res.body.data.creditLimit).toBe('750000.00');
      vendorId = res.body.data.id;
    });

    it('Negative: should reject creating duplicate vendor with same active GSTIN (409)', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/masters/vendors')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          name: 'Another Vendor Copy',
          contactPerson: 'Dummy Person',
          mobile: '+91 98250 00000',
          email: 'dummy@vendor.com',
          gstNumber: testVendorGst,
          panNumber: 'AAATE1234F',
          address: 'Ahmedabad',
        })
        .expect(409);

      expect(res.body.error).toBeDefined();
      expect(res.body.error.code).toBe('CONFLICT');
    });

    it('Positive: should soft-delete vendor', async () => {
      await request(app.getHttpServer())
        .delete(`/api/v1/masters/vendors/${vendorId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({ deleteReason: 'Operational contract ended' })
        .expect(200);

      // Verify vendor does not appear in standard active list
      const listRes = await request(app.getHttpServer())
        .get('/api/v1/masters/vendors')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      const found = listRes.body.data.find((v: any) => v.id === vendorId);
      expect(found).toBeUndefined();

      // Verify vendor appears when includeDeleted=true
      const deletedListRes = await request(app.getHttpServer())
        .get('/api/v1/masters/vendors?includeDeleted=true')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      const deletedFound = deletedListRes.body.data.find((v: any) => v.id === vendorId);
      expect(deletedFound).toBeDefined();
      expect(deletedFound.isDeleted).toBe(true);
    });
  });

  describe('3. Raw Materials & Q-06 Item Code Reuse', () => {
    it('Positive: should create raw material with nullable HSN/SAC code (Q-23)', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/masters/raw-materials')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          name: 'Aluminium Heat Sink Profile 2M',
          itemCode: testItemCode,
          categoryId,
          unitId,
          hsnSacCode: '7604',
          openingStock: 100.0,
          minimumStock: 25.0,
          reorderLevel: 40.0,
          defaultPurchasePrice: 850.5,
          gstPercent: 18.0,
        })
        .expect(201);

      expect(res.body.data.id).toBeDefined();
      expect(res.body.data.itemCode).toBe(testItemCode);
      expect(res.body.data.openingStock).toBe('100.0000');
      expect(res.body.data.defaultPurchasePrice).toBe('850.50');
      rawMaterialId = res.body.data.id;
    });

    it('Positive (Q-06): should allow reusing itemCode after soft-delete', async () => {
      // 1. Soft-delete the initial raw material
      await request(app.getHttpServer())
        .delete(`/api/v1/masters/raw-materials/${rawMaterialId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      // 2. Re-create a brand new raw material with the SAME item code
      const recreateRes = await request(app.getHttpServer())
        .post('/api/v1/masters/raw-materials')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          name: 'Reused Aluminium Heat Sink Profile 2M',
          itemCode: testItemCode, // Reusing the exact same item code
          categoryId,
          unitId,
          openingStock: 50.0,
          minimumStock: 10.0,
          defaultPurchasePrice: 890.0,
        })
        .expect(201);

      expect(recreateRes.body.data.itemCode).toBe(testItemCode);
      expect(recreateRes.body.data.id).not.toBe(rawMaterialId);

      // Store new ID for cleanup
      rawMaterialId = recreateRes.body.data.id;
    });
  });

  describe('4. Finished Products SKUs & Multi-Tier Pricing', () => {
    it('Positive: should create finished product SKU with dealer and customer pricing', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/masters/finished-products')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          name: 'Nova Architectural Chandelier 120W',
          itemCode: `FP-${Date.now().toString().slice(-4)}`,
          categoryId,
          unitId,
          hsnSacCode: '9405',
          openingStock: 15.0,
          minimumStock: 5.0,
          costPrice: 9500.0,
          dealerSellingPrice: 14000.0,
          customerSellingPrice: 18500.0,
          gstPercent: 18.0,
        })
        .expect(201);

      expect(res.body.data.id).toBeDefined();
      expect(res.body.data.costPrice).toBe('9500.00');
      expect(res.body.data.dealerSellingPrice).toBe('14000.00');
      expect(res.body.data.customerSellingPrice).toBe('18500.00');
      finishedProductId = res.body.data.id;
    });
  });

  describe('5b. Customer email validation & normalization', () => {
    const post = (body: Record<string, unknown>, token = accessToken) =>
      request(app.getHttpServer())
        .post('/api/v1/masters/customers')
        .set('Authorization', `Bearer ${token}`)
        .set('X-Correlation-ID', testCid)
        .send({ name: 'Email Test', mobile: '9898011223', address: 'Ahmedabad', ...body });
    const created: string[] = [];

    afterAll(async () => {
      for (const id of created) await db.query('DELETE FROM customers WHERE id = $1', [id]);
    });

    it('creates with trimmed + lowercased email', async () => {
      const res = await post({ email: '  E2E.Plus+ERP@Company.CO.IN ' }).expect(201);
      created.push(res.body.data.id);
      expect(res.body.data.email).toBe('e2e.plus+erp@company.co.in');
    });

    it.each(['kamalgmail.com', 'kamal@@gmail.com', '@gmail.com', 'kamal@', 'kamal @gmail.com', '', `a@${'b'.repeat(250)}.com`])(
      'rejects invalid create email %j (frontend bypass)',
      async (email) => {
        const res = await post({ email }).expect(400);
        expect(res.body.error.code).toBe('VALIDATION_FAILED');
      },
    );

    it('updates with normalization and rejects invalid update', async () => {
      const id = created[0];
      const ok = await request(app.getHttpServer())
        .put(`/api/v1/masters/customers/${id}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({ email: ' UPDATED@Gmail.com ' })
        .expect(200);
      expect(ok.body.data.email).toBe('updated@gmail.com');

      const bad = await request(app.getHttpServer())
        .put(`/api/v1/masters/customers/${id}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({ email: 'not-an-email' })
        .expect(400);
      expect(bad.body.error.code).toBe('VALIDATION_FAILED');
    });

    it('rejects unauthenticated create/update', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/masters/customers')
        .send({ name: 'x', mobile: '9898011223', address: 'x', email: 'a@b.com' })
        .expect(401);
      await request(app.getHttpServer())
        .put(`/api/v1/masters/customers/${created[0]}`)
        .send({ email: 'a@b.com' })
        .expect(401);
    });

    it('DB constraint rejects invalid/over-length email inserted directly', async () => {
      await expect(
        db.query(`INSERT INTO customers (name, mobile, email, address) VALUES ('x','1','bad email','x')`),
      ).rejects.toBeDefined();
      await expect(
        db.query(`INSERT INTO customers (name, mobile, email, address) VALUES ('x','1',$1,'x')`, [`a@${'b'.repeat(260)}.com`]),
      ).rejects.toBeDefined();
    });
  });

  describe('5. Parties & Dual Identity Linking', () => {
    it('Positive: should create Customer, Dealer, and Architect', async () => {
      // Customer
      const custRes = await request(app.getHttpServer())
        .post('/api/v1/masters/customers')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          name: 'Vikram Mehta',
          mobile: '+91 98980 11223',
          email: 'vikram@mehtahomes.com',
          address: 'Bungalow 7, Bodakdev, Ahmedabad',
          stateCode: '24',
        })
        .expect(201);
      customerId = custRes.body.data.id;

      // Dealer
      const dealerRes = await request(app.getHttpServer())
        .post('/api/v1/masters/dealers')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          name: 'Surat Lighting Gallery',
          contactPerson: 'Pankaj Vora',
          companyName: 'Vora Electricals LLP',
          mobile: '+91 98240 55667',
          email: 'pankaj@voralights.com',
          gstNumber: `24AABPV${Math.floor(1000 + Math.random() * 9000)}A1Z2`,
          address: 'Ring Road, Surat',
        })
        .expect(201);
      dealerId = dealerRes.body.data.id;

      // Architect
      const archRes = await request(app.getHttpServer())
        .post('/api/v1/masters/architects')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          name: 'Ar. Ananya Sen Design Studio',
          companyName: 'Ananya Sen Designs',
          mobile: '+91 98790 99887',
          email: 'ananya@asdesign.in',
          address: 'Sindhu Bhavan Road, Ahmedabad',
          defaultCommissionRate: 6.5,
        })
        .expect(201);
      architectId = archRes.body.data.id;
      expect(archRes.body.data.defaultCommissionRate).toBe(6.5);
    });

    it('Positive: should link Architect and Customer dual identity', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/masters/link-architect-customer')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          architectId,
          customerId,
        })
        .expect(201);

      expect(res.body.data.success).toBe(true);

      // Verify customer has linked architect
      const custRes = await request(app.getHttpServer())
        .get(`/api/v1/masters/customers/${customerId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      expect(custRes.body.data.linkedArchitectId).toBe(architectId);
      expect(custRes.body.data.isAlsoArchitect).toBe(true);

      // Verify architect has linked customer
      const archRes = await request(app.getHttpServer())
        .get(`/api/v1/masters/architects/${architectId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      expect(archRes.body.data.linkedCustomerId).toBe(customerId);
      expect(archRes.body.data.isAlsoCustomer).toBe(true);
    });
  });
});
