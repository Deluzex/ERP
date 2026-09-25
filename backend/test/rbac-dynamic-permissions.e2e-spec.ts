import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Dynamic RBAC Permissions Lifecycle & De-Privileging (E2E)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let adminToken: string;
  const testTimestamp = Date.now();
  const testCorrelationId = `test_dyn_rbac_${testTimestamp}`;
  const testRoleId = `test_role_depriv_${testTimestamp}`;
  const testUserEmail = `tester_${testTimestamp}@deluzex.test`;
  const testPassword = 'Password@123';
  let testUserId: string;

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
      .set('X-Correlation-ID', testCorrelationId)
      .send({
        email: 'admin@deluzex.com',
        password: 'Admin@123',
      })
      .expect(200);

    adminToken = loginRes.body.data.accessToken;

    // Create a dedicated test role with initial permissions (masters and inventory)
    await request(app.getHttpServer())
      .post('/api/v1/roles')
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Correlation-ID', testCorrelationId)
      .send({
        id: testRoleId,
        name: 'Dynamic Test Operator',
        description: 'Test role for verifying dynamic permission reduction',
        permissions: ['masters.view', 'inventory.view', 'inventory.create'],
      })
      .expect(201);

    // Create a dedicated test user assigned to this role
    const userRes = await request(app.getHttpServer())
      .post('/api/v1/users')
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Correlation-ID', testCorrelationId)
      .send({
        email: testUserEmail,
        password: testPassword,
        name: 'Dynamic Test User',
        mobile: '9876543299',
        roleId: testRoleId,
        assignedRoleIds: [testRoleId],
      })
      .expect(201);

    testUserId = userRes.body.data.id;
  });

  afterAll(async () => {
    // Automated database teardown per Golden Directives
    try {
      if (testUserId) {
        await db.query('DELETE FROM user_roles WHERE user_id = $1', [testUserId]);
        await db.query('DELETE FROM refresh_tokens WHERE user_id = $1', [testUserId]);
        await db.query('DELETE FROM users WHERE id = $1', [testUserId]);
      }
      await db.query('DELETE FROM role_permissions WHERE role_id = $1', [testRoleId]);
      await db.query('DELETE FROM roles WHERE id = $1', [testRoleId]);
      await db.query('DELETE FROM audit_logs WHERE correlation_id = $1', [testCorrelationId]);
    } catch (err) {
      // Ignore cleanup error if DB connection already closed
    }
    await app.close();
  });

  it('1. Initial State: User should have masters.view and inventory.view', async () => {
    // Login as the test user
    const loginRes = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCorrelationId)
      .send({
        email: testUserEmail,
        password: testPassword,
      })
      .expect(200);

    const userToken = loginRes.body.data.accessToken;
    const perms: string[] = loginRes.body.data.permissions || loginRes.body.data.user.permissions;
    expect(perms).toContain('masters.view');
    expect(perms).toContain('inventory.view');

    // Verify user can access inventory endpoint
    await request(app.getHttpServer())
      .get('/api/v1/inventory/stock-movements')
      .set('Authorization', `Bearer ${userToken}`)
      .set('X-Correlation-ID', testCorrelationId)
      .expect(200);
  });

  it('2. De-Privileging: Strip inventory permissions from the role', async () => {
    // Admin updates the role to remove inventory permissions entirely
    await request(app.getHttpServer())
      .put(`/api/v1/roles/${testRoleId}/permissions`)
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Correlation-ID', testCorrelationId)
      .send({
        permissions: ['masters.view'],
      })
      .expect(200);

    // GET /roles/:id must return only the remaining permission
    const roleRes = await request(app.getHttpServer())
      .get(`/api/v1/roles/${testRoleId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Correlation-ID', testCorrelationId)
      .expect(200);

    expect(roleRes.body.data.permissions).toEqual(['masters.view']);
    expect(roleRes.body.data.permissions).not.toContain('inventory.view');
  });

  it('3. Token & Session Freshness: Re-login should NOT include stripped permissions', async () => {
    // User re-authenticates
    const loginRes = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCorrelationId)
      .send({
        email: testUserEmail,
        password: testPassword,
      })
      .expect(200);

    const newAccessToken = loginRes.body.data.accessToken;
    const perms: string[] = loginRes.body.data.permissions || loginRes.body.data.user.permissions;
    expect(perms).toEqual(['masters.view']);
    expect(perms).not.toContain('inventory.view');

    // /auth/me must also reflect the stripped permissions
    const meRes = await request(app.getHttpServer())
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${newAccessToken}`)
      .set('X-Correlation-ID', testCorrelationId)
      .expect(200);

    expect(meRes.body.data.permissions).toEqual(['masters.view']);
    expect(meRes.body.data.permissions).not.toContain('inventory.view');
  });

  it('4. Negative Edge Case: Accessing stripped endpoint must yield 403 Forbidden', async () => {
    // Log in to obtain latest token
    const loginRes = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCorrelationId)
      .send({
        email: testUserEmail,
        password: testPassword,
      })
      .expect(200);

    const token = loginRes.body.data.accessToken;

    // Attempting to view inventory movements must now fail with 403 Forbidden
    const res = await request(app.getHttpServer())
      .get('/api/v1/inventory/stock-movements')
      .set('Authorization', `Bearer ${token}`)
      .set('X-Correlation-ID', testCorrelationId)
      .expect(403);

    expect(res.body.error).toBeDefined();
    expect(res.body.error.code).toBe('PERMISSION_DENIED');
  });

  it('5. Admin Role Dynamism: stripping and restoring a permission on the admin role is reflected immediately (no hardcoded bypass)', async () => {
    // This test makes NO assumption about how many permissions the admin role has,
    // or which ones. RBAC is fully dynamic and client-configurable, so the admin
    // role's permission set is just data — the only thing worth regression-testing
    // is that GET /roles/admin reflects the database exactly, with no hardcoded
    // bypass forcing it back to "all permissions" regardless of what's persisted.
    //
    // We prove this by reading whatever admin's live permissions currently are,
    // stripping exactly one of them through the real API, confirming the read
    // reflects that change, and then restoring the original set — so this test
    // never leaves the live admin role in a mutated state, even on failure.
    const beforeRes = await request(app.getHttpServer())
      .get('/api/v1/roles/admin')
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Correlation-ID', testCorrelationId)
      .expect(200);

    expect(beforeRes.body.data.id).toBe('admin');
    const originalPermissions: string[] = beforeRes.body.data.permissions;
    expect(Array.isArray(originalPermissions)).toBe(true);
    expect(originalPermissions.length).toBeGreaterThan(0);

    // Pick whichever permission happens to be first — we don't hardcode which
    // one, since that would reintroduce the same brittleness we're removing.
    const permissionToStrip = originalPermissions[0];
    const reducedPermissions = originalPermissions.filter((p) => p !== permissionToStrip);

    try {
      await request(app.getHttpServer())
        .put('/api/v1/roles/admin/permissions')
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .send({ permissions: reducedPermissions })
        .expect(200);

      const afterStripRes = await request(app.getHttpServer())
        .get('/api/v1/roles/admin')
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .expect(200);

      // The response must match exactly what was just persisted — not a
      // hardcoded full list regardless of database state.
      expect(afterStripRes.body.data.permissions).toHaveLength(reducedPermissions.length);
      expect(afterStripRes.body.data.permissions).not.toContain(permissionToStrip);
      expect(new Set(afterStripRes.body.data.permissions)).toEqual(new Set(reducedPermissions));
    } finally {
      // Always restore admin's original permission set, regardless of the
      // assertions above succeeding or throwing.
      await request(app.getHttpServer())
        .put('/api/v1/roles/admin/permissions')
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .send({ permissions: originalPermissions });
    }

    // Confirm the restoration actually took effect, so this test is a no-op
    // against the live admin role by the time it completes.
    const restoredRes = await request(app.getHttpServer())
      .get('/api/v1/roles/admin')
      .set('Authorization', `Bearer ${adminToken}`)
      .set('X-Correlation-ID', testCorrelationId)
      .expect(200);
    expect(new Set(restoredRes.body.data.permissions)).toEqual(new Set(originalPermissions));
  }, 60000); // admin currently holds ~90 permissions; updatePermissions writes them one row at a time,
  // and this test does that twice (strip + restore) against the live remote DB — needs more than the 30s default.
});
