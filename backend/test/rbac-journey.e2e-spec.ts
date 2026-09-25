import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('RBAC & Identity User Management Journey (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let adminToken: string;
  const testTimestamp = Date.now();
  const testCorrelationId = `test_rbac_${testTimestamp}`;
  const customRoleId = `test_role_${testTimestamp}`;
  const testUserEmail = `inspector_${testTimestamp}@deluzex.test`;
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
  });

  afterAll(async () => {
    // Automated database cleanup
    try {
      if (testUserId) {
        await db.query('DELETE FROM user_roles WHERE user_id = $1', [testUserId]);
        await db.query('DELETE FROM refresh_tokens WHERE user_id = $1', [testUserId]);
        await db.query('DELETE FROM users WHERE id = $1', [testUserId]);
      }
      await db.query('DELETE FROM role_permissions WHERE role_id = $1', [customRoleId]);
      await db.query('DELETE FROM roles WHERE id = $1', [customRoleId]);
      await db.query('DELETE FROM audit_logs WHERE correlation_id = $1', [testCorrelationId]);
    } catch (err) {
      // Ignore cleanup error if DB is disconnected
    }
    await app.close();
  });

  describe('1. Permissions Catalogue & Roles Overview', () => {
    it('Positive: should fetch 90 canonical permissions catalogue', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/roles/permissions/catalogue')
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .expect(200);

      expect(res.body.data).toBeDefined();
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(90);
    });

    it('Positive: should list existing system roles with admin and permissions', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/roles')
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .expect(200);

      expect(res.body.data).toBeDefined();
      expect(Array.isArray(res.body.data)).toBe(true);
      const adminRole = res.body.data.find((r: any) => r.id === 'admin');
      expect(adminRole).toBeDefined();
      expect(adminRole.isSystemRole).toBe(true);
    });
  });

  describe('2. Custom Role Full CRUD Lifecycle', () => {
    it('Positive: should create a new custom role', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/roles')
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .send({
          id: customRoleId,
          name: 'Quality Assurance Lead',
          description: 'Responsible for inspection and quality verification',
          defaultDashboardSection: 'production',
          permissions: ['production.view', 'production.edit', 'inventory.view'],
        })
        .expect(201);

      expect(res.body.data).toBeDefined();
      expect(res.body.data.id).toBe(customRoleId);
      expect(res.body.data.name).toBe('Quality Assurance Lead');
      expect(res.body.data.isSystemRole).toBe(false);
      expect(res.body.data.permissions).toContain('production.view');
    });

    it('Positive: should update custom role metadata (PUT /roles/:id)', async () => {
      const res = await request(app.getHttpServer())
        .put(`/api/v1/roles/${customRoleId}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .send({
          name: 'Senior QA Inspector',
          description: 'Updated inspection duties and oversight',
          defaultDashboardSection: 'inventory',
        })
        .expect(200);

      expect(res.body.data).toBeDefined();
      expect(res.body.data.name).toBe('Senior QA Inspector');
      expect(res.body.data.description).toBe('Updated inspection duties and oversight');
      expect(res.body.data.defaultDashboardSection).toBe('inventory');
    });

    it('Positive: should update role permissions matrix (PUT /roles/:id/permissions)', async () => {
      const updatedPerms = [
        'production.view',
        'production.edit',
        'inventory.view',
        'inventory.edit',
        'masters.view',
      ];

      const res = await request(app.getHttpServer())
        .put(`/api/v1/roles/${customRoleId}/permissions`)
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .send({
          permissions: updatedPerms,
        })
        .expect(200);

      expect(res.body.data).toBeDefined();
      expect(res.body.data.permissions.length).toBe(updatedPerms.length);
      expect(res.body.data.permissions).toContain('inventory.edit');
    });
  });

  describe('3. User Management, Multi-Role, and Admin Password Reset', () => {
    it('Positive: should create user with primary and secondary roles', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/users')
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .send({
          name: 'Quality Officer Kamal',
          email: testUserEmail,
          mobile: '9876543299',
          password: 'InitialPassword@123',
          roleId: customRoleId,
          assignedRoleIds: [customRoleId, 'data_entry'],
        })
        .expect(201);

      expect(res.body.data).toBeDefined();
      expect(res.body.data.id).toBeDefined();
      expect(res.body.data.email).toBe(testUserEmail);
      expect(res.body.data.roleId).toBe(customRoleId);
      expect(res.body.data.assignedRoleIds).toContain(customRoleId);
      expect(res.body.data.assignedRoleIds).toContain('data_entry');

      testUserId = res.body.data.id;
    });

    it('Positive: should retrieve user by ID and verify multi-role mapping', async () => {
      const res = await request(app.getHttpServer())
        .get(`/api/v1/users/${testUserId}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .expect(200);

      expect(res.body.data).toBeDefined();
      expect(res.body.data.id).toBe(testUserId);
      expect(res.body.data.assignedRoleIds).toContain(customRoleId);
      expect(res.body.data.assignedRoleIds).toContain('data_entry');
    });

    it('Positive: should reset user password from admin endpoint (POST /users/:id/reset-password)', async () => {
      const res = await request(app.getHttpServer())
        .post(`/api/v1/users/${testUserId}/reset-password`)
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .send({
          newPassword: 'BrandNewSecurePassword@456',
        })
        .expect(201);

      expect(res.body.data.success).toBe(true);
    });

    it('Positive: should verify that the user can now login with the new password', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .set('X-Correlation-ID', testCorrelationId)
        .send({
          email: testUserEmail,
          password: 'BrandNewSecurePassword@456',
        })
        .expect(200);

      expect(res.body.data.accessToken).toBeDefined();
      expect(res.body.data.user.email).toBe(testUserEmail);
    });

    it('Negative: should reject login with the old password (401)', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/auth/login')
        .set('X-Correlation-ID', testCorrelationId)
        .send({
          email: testUserEmail,
          password: 'InitialPassword@123',
        })
        .expect(401);
    });
  });

  describe('4. Deletion Safety Guards & Clean Teardown', () => {
    it('Negative: should reject deleting system role admin (400)', async () => {
      const res = await request(app.getHttpServer())
        .delete('/api/v1/roles/admin')
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .expect(400);

      expect(res.body.error).toBeDefined();
      expect(res.body.error.message).toMatch(/System roles cannot be deleted/i);
    });

    it('Negative: should reject deleting custom role while assigned to an active user (400)', async () => {
      const res = await request(app.getHttpServer())
        .delete(`/api/v1/roles/${customRoleId}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .expect(400);

      expect(res.body.error).toBeDefined();
      expect(res.body.error.message).toMatch(/currently assigned/i);
    });

    it('Positive: should reassign user role and allow custom role deletion', async () => {
      // Reassign user to data_entry only
      await request(app.getHttpServer())
        .put(`/api/v1/users/${testUserId}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .send({
          roleId: 'data_entry',
          assignedRoleIds: ['data_entry'],
        })
        .expect(200);

      // Now delete the custom role
      const delRes = await request(app.getHttpServer())
        .delete(`/api/v1/roles/${customRoleId}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .expect(200);

      expect(delRes.body.data.success).toBe(true);

      // Verify role no longer exists
      await request(app.getHttpServer())
        .get(`/api/v1/roles/${customRoleId}`)
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCorrelationId)
        .expect(404);
    });
  });
});
