import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';
import { GlobalExceptionFilter } from '../src/core/errors/global-exception.filter';
import { ResponseEnvelopeInterceptor } from '../src/core/interceptors/response-envelope.interceptor';

describe('Instance Subscription & Licensing Journey (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  const testCid = 'test-sub-cid-' + Date.now();
  let adminToken: string;

  // Track initial subscription row to deterministically restore in afterAll
  let initialSubBackup: any;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    app.setGlobalPrefix('api/v1');
    app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
    await app.init();

    db = app.get(DatabasePool);

    // Backup current subscription row
    const subRes = await db.query<any>('SELECT * FROM instance_subscriptions ORDER BY created_at ASC LIMIT 1');
    if (subRes.rows.length > 0) {
      initialSubBackup = subRes.rows[0];
    }

    // Login as admin for privileged endpoints
    const loginRes = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCid)
      .send({
        email: 'admin@deluzex.com',
        password: 'Admin@123',
      });

    if (loginRes.status === 200) {
      adminToken = loginRes.body.data.accessToken;
    }
  });

  afterAll(async () => {
    // Deterministic Auto-Cleanup: restore original subscription row
    if (initialSubBackup) {
      await db.query(
        `UPDATE instance_subscriptions 
         SET valid_until = $1, is_active = $2, warning_days = $3, updated_at = NOW()
         WHERE id = $4`,
        [
          initialSubBackup.valid_until,
          initialSubBackup.is_active,
          initialSubBackup.warning_days,
          initialSubBackup.id,
        ],
      );
    }

    if (app) {
      await app.close();
    }
  });

  it('1. GET /api/v1/subscription/status — Returns active status when healthy', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/subscription/status')
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data).toBeDefined();
    expect(res.body.data.isActive).toBe(true);
    expect(res.body.data.isExpired).toBe(false);
    expect(res.body.data.daysRemaining).toBeGreaterThan(30);
    expect(res.body.data.showRenewalWarning).toBe(false);
    expect(res.body.data.supportPhone).toBeDefined();
    expect(res.body.data.supportEmail).toBeDefined();
  });

  it('2. POST /api/v1/auth/login — Login succeeds when subscription is active and includes subscription meta', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCid)
      .send({
        email: 'admin@deluzex.com',
        password: 'Admin@123',
      });

    expect(res.status).toBe(200);
    expect(res.body.data.accessToken).toBeDefined();
    expect(res.body.data.subscription).toBeDefined();
    expect(res.body.data.subscription.isExpired).toBe(false);
    expect(res.body.data.subscription.daysRemaining).toBeGreaterThan(30);
    expect(res.body.data.subscription.showRenewalWarning).toBe(false);
  });

  it('3. GET /api/v1/subscription/status — Returns showRenewalWarning: true when daysRemaining <= 30', async () => {
    // Set valid_until to 20 days in future
    await db.query(`UPDATE instance_subscriptions SET valid_until = NOW() + INTERVAL '20 days'`);

    const res = await request(app.getHttpServer())
      .get('/api/v1/subscription/status')
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.isActive).toBe(true);
    expect(res.body.data.isExpired).toBe(false);
    expect(res.body.data.daysRemaining).toBeLessThanOrEqual(21);
    expect(res.body.data.daysRemaining).toBeGreaterThanOrEqual(19);
    expect(res.body.data.showRenewalWarning).toBe(true);
  });

  it('4. Negative / Hard Lockout: POST /api/v1/auth/login blocks login immediately when subscription is expired', async () => {
    // Set valid_until to 2 hours in the past
    await db.query(`UPDATE instance_subscriptions SET valid_until = NOW() - INTERVAL '2 hours'`);

    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCid)
      .send({
        email: 'admin@deluzex.com',
        password: 'Admin@123',
      });

    expect(res.status).toBe(403);
    expect(res.body.error).toBeDefined();
    expect(res.body.error.code).toBe('SUBSCRIPTION_EXPIRED');
    expect(res.body.error.message).toMatch(/સબ્સ્ક્રિપ્શન સમાપ્ત|subscription.*expired/i);
    expect(res.body.error.supportPhone).toBeDefined();
  });

  it('5. Edge Case: is_active = false immediately blocks login even if valid_until is in future', async () => {
    // Set valid_until to future, but is_active = false
    await db.query(`UPDATE instance_subscriptions SET valid_until = NOW() + INTERVAL '100 days', is_active = false`);

    const res = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCid)
      .send({
        email: 'admin@deluzex.com',
        password: 'Admin@123',
      });

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('SUBSCRIPTION_EXPIRED');
  });

  it('6. PATCH /api/v1/subscription/renew — Renews subscription by adding months and unblocks login', async () => {
    // Call renewal endpoint with 12 months
    const renewRes = await request(app.getHttpServer())
      .patch('/api/v1/subscription/renew')
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        months: 12,
      });

    expect(renewRes.status).toBe(200);
    expect(renewRes.body.data.isActive).toBe(true);
    expect(renewRes.body.data.isExpired).toBe(false);
    expect(renewRes.body.data.daysRemaining).toBeGreaterThan(350);

    // Immediate login test: now login MUST succeed
    const loginRes = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCid)
      .send({
        email: 'admin@deluzex.com',
        password: 'Admin@123',
      });

    expect(loginRes.status).toBe(200);
    expect(loginRes.body.data.accessToken).toBeDefined();
    expect(loginRes.body.data.subscription.isExpired).toBe(false);
  });
});
