import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Expenses & Operational Vouchers Domain Lifecycle (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  const testCid = `e2e_expenses_${Date.now()}`;
  const createdExpenseIds: string[] = [];

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
  });

  afterAll(async () => {
    for (const id of createdExpenseIds) {
      await db.query(`DELETE FROM expenses WHERE id = $1`, [id]);
    }
    await app.close();
  });

  it('1. POST /api/v1/expenses — Create expense voucher with auto-numbering', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/expenses')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        expenseName: 'Specialized Chandelier Hoisting Crane',
        category: 'transportation',
        amount: 8500.00,
        paidBy: 'Site Engineer Alex',
        paymentMethod: 'Bank Transfer',
        vendorPayee: 'QuickCrane Services LLP',
        expenseReference: 'CRANE/AHM/102',
        description: 'Hoisting 4-meter luxury brass chandelier at Penthouse 4',
      });

    expect(res.status).toBe(201);
    expect(res.body.data).toBeDefined();
    expect(res.body.data.expenseNumber).toMatch(/^EXP-\d{4}-\d+/);
    expect(res.body.data.amount).toBe(8500.00);
    expect(res.body.data.category).toBe('transportation');
    createdExpenseIds.push(res.body.data.id);
  });

  it('2. GET /api/v1/expenses/:id — Retrieve single expense voucher', async () => {
    const id = createdExpenseIds[0];
    const res = await request(app.getHttpServer())
      .get(`/api/v1/expenses/${id}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe(id);
    expect(res.body.data.expenseName).toBe('Specialized Chandelier Hoisting Crane');
  });

  it('3. GET /api/v1/expenses — List vouchers with KPI category summaries', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/expenses?category=transportation')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    const summary = res.body.meta.pagination?.summary || res.body.meta.summary;
    expect(summary).toBeDefined();
    expect(parseFloat(summary.totalExpense)).toBeGreaterThanOrEqual(8500);
  });

  it('4. PUT /api/v1/expenses/:id — Update expense voucher', async () => {
    const id = createdExpenseIds[0];
    const res = await request(app.getHttpServer())
      .put(`/api/v1/expenses/${id}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        amount: 9000.00,
        description: 'Updated with overtime operator charges',
      });

    expect(res.status).toBe(200);
    expect(res.body.data.amount).toBe(9000.00);
    expect(res.body.data.description).toBe('Updated with overtime operator charges');
  });

  it('5. DELETE /api/v1/expenses/:id — Delete expense voucher', async () => {
    const id = createdExpenseIds[0];
    const res = await request(app.getHttpServer())
      .delete(`/api/v1/expenses/${id}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.success).toBe(true);

    // Verify deletion
    const checkRes = await request(app.getHttpServer())
      .get(`/api/v1/expenses/${id}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(checkRes.status).toBe(404);
  });

  it('6. Negative Cases: Reject invalid category or non-positive amount', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/expenses')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        expenseName: 'Invalid Expense',
        category: 'invalid_category_xyz',
        amount: -500,
        paidBy: 'Alex',
        paymentMethod: 'Cash',
      });

    expect(res.status).toBe(400);
  });
});
