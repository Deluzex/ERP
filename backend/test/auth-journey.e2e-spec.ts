import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Auth & Identity User Journey (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  let refreshToken: string;
  const testCorrelationId = `test_e2e_${Date.now()}`;

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
  });

  afterAll(async () => {
    // Automated Test Cleanup: remove any test-generated audit logs or refresh tokens
    try {
      await db.query(
        'DELETE FROM audit_logs WHERE correlation_id = $1',
        [testCorrelationId],
      );
    } catch {
      // Ignore cleanup error if DB is disconnected
    }
    await app.close();
  });

  describe('1. Authentication Flow', () => {
    it('Negative: should reject login with invalid credentials (401)', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .set('X-Correlation-ID', testCorrelationId)
        .send({
          email: 'admin@deluzex.com',
          password: 'WrongPassword@999',
        })
        .expect(401);

      expect(res.body.error).toBeDefined();
      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('Positive: should successfully login seeded Super Admin and issue token pair', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .set('X-Correlation-ID', testCorrelationId)
        .send({
          email: 'admin@deluzex.com',
          password: 'Admin@123',
        })
        .expect(200);

      expect(res.body.data).toBeDefined();
      expect(res.body.data.accessToken).toBeDefined();
      expect(res.body.data.refreshToken).toBeDefined();
      expect(res.body.data.user.email).toBe('admin@deluzex.com');
      expect(res.body.data.user.roleId).toBe('admin');
      expect(res.body.meta.correlationId).toBe(testCorrelationId);

      accessToken = res.body.data.accessToken;
      refreshToken = res.body.data.refreshToken;
    });

    it('Positive: should fetch current user profile via /auth/me with valid Bearer token', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/auth/me')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .expect(200);

      expect(res.body.data.email).toBe('admin@deluzex.com');
      expect(res.body.data.roleId).toBe('admin');
      expect(Array.isArray(res.body.data.permissions)).toBe(true);
      expect(res.body.data.permissions.length).toBeGreaterThanOrEqual(90);
    });

    it('Negative: should reject unauthenticated request to protected endpoint (401)', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/auth/me')
        .set('X-Correlation-ID', testCorrelationId)
        .expect(401);

      expect(res.body.error.code).toBe('UNAUTHENTICATED');
    });

    it('Positive: should access RBAC protected endpoint /roles as Super Administrator', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/roles')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .expect(200);

      expect(Array.isArray(res.body.data)).toBe(true);
      const adminRole = res.body.data.find((r: any) => r.id === 'admin');
      expect(adminRole).toBeDefined();
    });

    it('Positive: should rotate refresh token and issue new token pair', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .set('X-Correlation-ID', testCorrelationId)
        .send({ refreshToken })
        .expect(200);

      expect(res.body.data.accessToken).toBeDefined();
      expect(res.body.data.refreshToken).toBeDefined();
      expect(res.body.data.refreshToken).not.toBe(refreshToken);

      // Save new refresh token
      const newRefreshToken = res.body.data.refreshToken;

      // Negative: Replay attack prevention - attempting to reuse old revoked refresh token MUST fail
      await request(app.getHttpServer())
        .post('/api/v1/auth/refresh')
        .set('X-Correlation-ID', testCorrelationId)
        .send({ refreshToken })
        .expect(401);

      // Update to new refresh token
      refreshToken = newRefreshToken;
    });

    it('Positive: should successfully logout and revoke session', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/auth/logout')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .send({ refreshToken })
        .expect(200);
    });
  });
});
