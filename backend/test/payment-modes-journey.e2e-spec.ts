import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Payment Modes Master Module (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  const testCid = `e2e_pm_${Date.now()}`;
  const createdPaymentModeIds: string[] = [];

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
    if (createdPaymentModeIds.length > 0) {
      await db.query('DELETE FROM payment_modes WHERE id = ANY($1)', [createdPaymentModeIds]);
    }
    await app.close();
  });

  it('1. GET /api/v1/payment-modes — List payment modes including seeded defaults', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/payment-modes')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.data.length).toBeGreaterThanOrEqual(4);
  });

  it('2. POST /api/v1/payment-modes — Create custom payment mode', async () => {
    const code = `PM-LC-${Date.now().toString().slice(-4)}`;
    const res = await request(app.getHttpServer())
      .post('/api/v1/payment-modes')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        name: 'Letter of Credit (LC 90 Days)',
        code,
        requiresReference: true,
        description: 'Trade bank verified LC document',
        isActive: true,
      });

    expect(res.status).toBe(201);
    expect(res.body.data.code).toBe(code);
    expect(res.body.data.requiresReference).toBe(true);
    createdPaymentModeIds.push(res.body.data.id);
  });

  it('3. PUT /api/v1/payment-modes/:id — Update payment mode details', async () => {
    const id = createdPaymentModeIds[0];
    const res = await request(app.getHttpServer())
      .put(`/api/v1/payment-modes/${id}`)
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        name: 'Irrevocable Confirmed LC',
        requiresReference: true,
      });

    expect(res.status).toBe(200);
    expect(res.body.data.name).toBe('Irrevocable Confirmed LC');
  });
});
