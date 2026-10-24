import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Expense Categories Master Module (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  const testCid = `e2e_exp_cat_${Date.now()}`;
  const createdCategoryIds: string[] = [];

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
    if (createdCategoryIds.length > 0) {
      await db.query('DELETE FROM expense_categories WHERE id = ANY($1)', [createdCategoryIds]);
    }
    await app.close();
  });

  it('1. GET /api/v1/expense-categories — List default seeded expense categories', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/expense-categories')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.items).toBeDefined();
    expect(res.body.data.items.length).toBeGreaterThanOrEqual(1);
  });

  it('2. POST /api/v1/expense-categories — Create new expense category', async () => {
    const catCode = `EXP-TEST-${Date.now().toString().slice(-4)}`;
    const res = await request(app.getHttpServer())
      .post('/api/v1/expense-categories')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        name: 'Factory CNC Laser Gas & Tooling',
        code: catCode,
        description: 'Argon gas and high-precision CNC laser tips',
        isActive: true,
      });

    expect(res.status).toBe(201);
    expect(res.body.data.code).toBe(catCode);
    expect(res.body.data.name).toBe('Factory CNC Laser Gas & Tooling');
    createdCategoryIds.push(res.body.data.id);
  });

  it('3. Negative: POST /api/v1/expense-categories rejects duplicate category code', async () => {
    const existingCode = `EXP-DUP-${Date.now().toString().slice(-4)}`;
    const createFirst = await request(app.getHttpServer())
      .post('/api/v1/expense-categories')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        name: 'Packaging & Wooden Crating',
        code: existingCode,
      });
    expect(createFirst.status).toBe(201);
    createdCategoryIds.push(createFirst.body.data.id);

    // Duplicate attempt
    const res = await request(app.getHttpServer())
      .post('/api/v1/expense-categories')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        name: 'Duplicate Packaging',
        code: existingCode,
      });

    expect(res.status).toBe(409);
  });

  it('4. PATCH /api/v1/expense-categories/:id/status — Toggle active status', async () => {
    const id = createdCategoryIds[0];
    const res = await request(app.getHttpServer())
      .patch(`/api/v1/expense-categories/${id}/status`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({ isActive: false });

    expect(res.status).toBe(200);
    expect(res.body.data.isActive).toBe(false);
  });
});
