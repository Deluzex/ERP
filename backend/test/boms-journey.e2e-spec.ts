import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('BOM Master Module & Lifecycle Journey (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  const testCid = `e2e_bom_${Date.now()}`;

  // Created IDs for deterministic cleanup
  const createdBomIds: string[] = [];
  let testFinishedProductId: string;
  let testRawMaterial1Id: string;
  let testRawMaterial2Id: string;
  let testCategoryId: string;
  let testUnitId: string;

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

    // Fetch or create prerequisite master entities
    const catRes = await db.query<{ id: string }>('SELECT id FROM categories LIMIT 1');
    testCategoryId = catRes.rows[0].id;

    const unitRes = await db.query<{ id: string }>('SELECT id FROM measurement_units WHERE symbol = $1 LIMIT 1', ['PCS']);
    testUnitId = unitRes.rows[0].id;

    // Create a dedicated finished product for BOM tests
    const fpCode = `FP-BOM-${Date.now().toString().slice(-6)}`;
    const fpRes = await db.query<{ id: string }>(
      `INSERT INTO finished_products (name, item_code, category_id, unit_id, cost_price, customer_selling_price)
       VALUES ($1, $2, $3, $4, 1000.00, 4800.00) RETURNING id`,
      ['Architectural Linear Light 2.4M', fpCode, testCategoryId, testUnitId],
    );
    testFinishedProductId = fpRes.rows[0].id;

    // Create two raw materials with known prices
    const rm1Code = `RM-ALU-${Date.now().toString().slice(-5)}`;
    const rm1Res = await db.query<{ id: string }>(
      `INSERT INTO raw_materials (name, item_code, category_id, unit_id, default_purchase_price)
       VALUES ($1, $2, $3, $4, 480.00) RETURNING id`,
      ['Extrusion Profile 6063-T6', rm1Code, testCategoryId, testUnitId],
    );
    testRawMaterial1Id = rm1Res.rows[0].id;

    const rm2Code = `RM-DRV-${Date.now().toString().slice(-5)}`;
    const rm2Res = await db.query<{ id: string }>(
      `INSERT INTO raw_materials (name, item_code, category_id, unit_id, default_purchase_price)
       VALUES ($1, $2, $3, $4, 850.00) RETURNING id`,
      ['Constant Current LED Driver 40W', rm2Code, testCategoryId, testUnitId],
    );
    testRawMaterial2Id = rm2Res.rows[0].id;
  });

  afterAll(async () => {
    // Deterministic DB cleanup
    if (createdBomIds.length > 0) {
      await db.query('DELETE FROM bom_items WHERE bom_id = ANY($1)', [createdBomIds]);
      await db.query('DELETE FROM boms WHERE id = ANY($1)', [createdBomIds]);
    }
    if (testFinishedProductId) {
      await db.query('DELETE FROM finished_products WHERE id = $1', [testFinishedProductId]);
    }
    if (testRawMaterial1Id) {
      await db.query('DELETE FROM raw_materials WHERE id = $1', [testRawMaterial1Id]);
    }
    if (testRawMaterial2Id) {
      await db.query('DELETE FROM raw_materials WHERE id = $1', [testRawMaterial2Id]);
    }
    await app.close();
  });

  // --------------------------------------------------------------------------
  // Positive Test Cases
  // --------------------------------------------------------------------------
  it('1. POST /api/v1/boms — Create new DRAFT BOM with itemized scrap & total cost calculation', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/boms')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        finishedProductId: testFinishedProductId,
        yieldQuantity: 1.0,
        status: 'DRAFT',
        notes: 'Initial production recipe for Architectural Linear Series',
        items: [
          {
            rawMaterialId: testRawMaterial1Id,
            quantity: 1.5,
            unit: 'MTR',
            scrapPercentage: 2.5,
            itemNotes: 'Profile casing',
          },
          {
            rawMaterialId: testRawMaterial2Id,
            quantity: 1.0,
            unit: 'PCS',
            scrapPercentage: 0.0,
            itemNotes: 'Power driver',
          },
        ],
      });

    expect(res.status).toBe(201);
    expect(res.body.data).toBeDefined();
    expect(res.body.data.id).toBeDefined();
    expect(res.body.data.bomNumber).toMatch(/^BOM-.*-V1$/);
    expect(res.body.data.version).toBe(1);
    expect(res.body.data.status).toBe('DRAFT');
    expect(res.body.data.itemCount).toBe(2);

    // Cost verification:
    // Item 1: 1.5 * (1 + 0.025) * 480 = 1.5375 * 480 = 738.00
    // Item 2: 1.0 * (1 + 0.0) * 850 = 850.00
    // Total = 738 + 850 = 1588.00
    expect(Number(res.body.data.totalCost)).toBe(1588.00);

    createdBomIds.push(res.body.data.id);
  });

  it('2. GET /api/v1/boms — List BOMs with pagination & search filter', async () => {
    const res = await request(app.getHttpServer())
      .get(`/api/v1/boms?productId=${testFinishedProductId}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.items).toBeDefined();
    expect(res.body.data.items.length).toBeGreaterThanOrEqual(1);
    expect(res.body.data.pagination).toBeDefined();
  });

  it('3. GET /api/v1/boms/:id — Get full BOM details by ID including child line items', async () => {
    const bomId = createdBomIds[0];
    const res = await request(app.getHttpServer())
      .get(`/api/v1/boms/${bomId}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe(bomId);
    expect(res.body.data.items.length).toBe(2);
    expect(res.body.data.items[0]).toHaveProperty('rawMaterialName');
    expect(res.body.data.items[0]).toHaveProperty('unitCost');
    expect(res.body.data.items[0]).toHaveProperty('lineTotalCost');
  });

  it('4. PUT /api/v1/boms/:id — Update existing DRAFT BOM', async () => {
    const bomId = createdBomIds[0];
    const res = await request(app.getHttpServer())
      .put(`/api/v1/boms/${bomId}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        notes: 'Updated recipe with revised 2.0% scrap tolerance',
        items: [
          {
            rawMaterialId: testRawMaterial1Id,
            quantity: 1.5,
            unit: 'MTR',
            scrapPercentage: 2.0,
            itemNotes: 'Profile casing with 2% scrap',
          },
          {
            rawMaterialId: testRawMaterial2Id,
            quantity: 1.0,
            unit: 'PCS',
            scrapPercentage: 0.0,
            itemNotes: 'Power driver',
          },
        ],
      });

    expect(res.status).toBe(200);
    // Item 1: 1.5 * 1.02 * 480 = 734.40
    // Item 2: 850.00
    // Total = 1584.40
    expect(Number(res.body.data.totalCost)).toBe(1584.40);
  });

  it('5. PATCH /api/v1/boms/:id/status — Activate BOM & auto-update finished product cost_price', async () => {
    const bomId = createdBomIds[0];
    const res = await request(app.getHttpServer())
      .patch(`/api/v1/boms/${bomId}/status`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({ status: 'ACTIVE' });

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('ACTIVE');

    // Verify finished product cost_price got synchronized
    const fpRes = await db.query<{ cost_price: string }>(
      'SELECT cost_price FROM finished_products WHERE id = $1',
      [testFinishedProductId],
    );
    expect(Number(fpRes.rows[0].cost_price)).toBe(1584.40);
  });

  it('6. POST /api/v1/boms/:id/duplicate — Clone active BOM to new DRAFT version (V2)', async () => {
    const bomId = createdBomIds[0];
    const res = await request(app.getHttpServer())
      .post(`/api/v1/boms/${bomId}/duplicate`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(201);
    expect(res.body.data.newBomId).toBeDefined();
    expect(res.body.data.version).toBe(2);
    expect(res.body.data.status).toBe('DRAFT');
    createdBomIds.push(res.body.data.newBomId);
  });

  it('7. GET /api/v1/boms/by-product/:productId — Return active recipe for manufacturing order', async () => {
    const res = await request(app.getHttpServer())
      .get(`/api/v1/boms/by-product/${testFinishedProductId}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe(createdBomIds[0]);
    expect(res.body.data.status).toBe('ACTIVE');
  });

  it('8. GET /api/v1/boms/:id/cost-rollup — Dynamic cost rollup vs live raw material purchase prices', async () => {
    const bomId = createdBomIds[0];

    // Update RM1 purchase price in DB to simulate inflation (480 -> 520)
    await db.query('UPDATE raw_materials SET default_purchase_price = 520.00 WHERE id = $1', [testRawMaterial1Id]);

    const res = await request(app.getHttpServer())
      .get(`/api/v1/boms/${bomId}/cost-rollup`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.bomId).toBe(bomId);
    expect(res.body.data.storedBomCost).toBe(1584.40);
    // New market cost: (1.5 * 1.02 * 520 = 795.60) + 850 = 1645.60
    expect(res.body.data.currentMarketCost).toBe(1645.60);
    expect(res.body.data.costVariance).toBe(61.20);
    expect(res.body.data.sellingPriceCustomer).toBe(4800.00);
    expect(res.body.data.currentGrossMarginPercent).toBeGreaterThan(60);
  });

  // --------------------------------------------------------------------------
  // Negative & Boundary Test Cases
  // --------------------------------------------------------------------------
  it('9. Negative: PUT /api/v1/boms/:id rejects modification on ACTIVE BOM', async () => {
    const activeBomId = createdBomIds[0];
    const res = await request(app.getHttpServer())
      .put(`/api/v1/boms/${activeBomId}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        notes: 'Attempting illegal update on locked active recipe',
        items: [
          {
            rawMaterialId: testRawMaterial1Id,
            quantity: 2.0,
            unit: 'MTR',
          },
        ],
      });

    expect(res.status).toBe(400);
    expect(res.body.error.message).toMatch(/active.*cannot be modified|immutable/i);
  });

  it('10. Edge Case: Activating V2 marks previous V1 as OBSOLETE', async () => {
    const v2BomId = createdBomIds[1];
    const res = await request(app.getHttpServer())
      .patch(`/api/v1/boms/${v2BomId}/status`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({ status: 'ACTIVE' });

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('ACTIVE');

    // Check V1 is now OBSOLETE
    const v1Res = await request(app.getHttpServer())
      .get(`/api/v1/boms/${createdBomIds[0]}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(v1Res.body.data.status).toBe('OBSOLETE');
  });
});
