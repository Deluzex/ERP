import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Architectural Projects Domain Lifecycle (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  const testCid = `e2e_projects_${Date.now()}`;

  let testCustomerId: string;
  let testArchitectId: string;
  let testDealerId: string;
  const createdProjectIds: string[] = [];
  const createdCustomerIds: string[] = [];
  const createdArchitectIds: string[] = [];
  const createdDealerIds: string[] = [];

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

    // Create Test Customer
    const custRes = await db.query<{ id: string }>(
      `INSERT INTO customers (name, mobile, email, address, is_also_architect)
       VALUES ('E2E Project Client Ltd', '9898099881', 'client@e2eproject.com', 'SG Highway, Ahmedabad', false)
       RETURNING id`,
    );
    testCustomerId = custRes.rows[0].id;
    createdCustomerIds.push(testCustomerId);

    // Create Test Architect
    const archRes = await db.query<{ id: string }>(
      `INSERT INTO architects (name, company_name, mobile, email, address, default_commission_rate)
       VALUES ('Ar. Vikram Sompura', 'Sompura Architectural Studio', '9825099882', 'vikram@sompura.in', 'Navrangpura, Ahmedabad', 6.5)
       RETURNING id`,
    );
    testArchitectId = archRes.rows[0].id;
    createdArchitectIds.push(testArchitectId);

    // Create Test Dealer
    const dlrRes = await db.query<{ id: string }>(
      `INSERT INTO dealers (name, company_name, contact_person, mobile, email, gst_number, address)
       VALUES ('Royal Lightings LLP', 'Royal Lightings LLP', 'Ramesh Shah', '9898099883', 'royal@dealer.com', '24AAACR1234F1Z8', 'Relief Road, Ahmedabad')
       RETURNING id`,
    );
    testDealerId = dlrRes.rows[0].id;
    createdDealerIds.push(testDealerId);
  });

  afterAll(async () => {
    try {
      if (createdProjectIds.length > 0) {
        await db.query(`DELETE FROM audit_logs WHERE entity_type = 'projects' AND entity_id = ANY($1::uuid[])`, [createdProjectIds]);
        await db.query(`DELETE FROM projects WHERE id = ANY($1::uuid[])`, [createdProjectIds]);
      }
      if (createdCustomerIds.length > 0) {
        await db.query(`DELETE FROM customers WHERE id = ANY($1::uuid[])`, [createdCustomerIds]);
      }
      if (createdArchitectIds.length > 0) {
        await db.query(`DELETE FROM architects WHERE id = ANY($1::uuid[])`, [createdArchitectIds]);
      }
      if (createdDealerIds.length > 0) {
        await db.query(`DELETE FROM dealers WHERE id = ANY($1::uuid[])`, [createdDealerIds]);
      }
    } finally {
      if (app) {
        await app.close();
      }
    }
  });

  describe('1. Project Creation & Validation', () => {
    it('Positive: should create a new architectural project successfully', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/projects')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          name: 'The Grand Hyatt Presidential Suites',
          customerId: testCustomerId,
          architectId: testArchitectId,
          dealerId: testDealerId,
          startDate: '2026-10-01',
          expectedCompletionDate: '2027-04-30',
          status: 'planned',
          budgetAmount: 4500000.0,
          notes: 'Custom solid brass chandeliers and architectural cove lighting fixtures',
        });

      expect(res.status).toBe(201);
      expect(res.body.data).toBeDefined();
      const p = res.body.data;
      expect(p.name).toBe('The Grand Hyatt Presidential Suites');
      expect(p.projectCode).toMatch(/^PRJ-\d{4}-\d{4}$/);
      expect(p.customerId).toBe(testCustomerId);
      expect(p.customerName).toBe('E2E Project Client Ltd');
      expect(p.architectId).toBe(testArchitectId);
      expect(p.architectName).toBe('Ar. Vikram Sompura');
      expect(p.dealerId).toBe(testDealerId);
      expect(p.dealerName).toBe('Royal Lightings LLP');
      expect(p.status).toBe('planned');
      expect(p.budgetAmount).toBe(4500000.0);

      createdProjectIds.push(p.id);
    });

    it('Negative: should reject creation without project name', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/projects')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          customerId: testCustomerId,
          budgetAmount: 100000.0,
        });

      expect(res.status).toBe(400);
      expect(res.body.error).toBeDefined();
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
    });

    it('Negative: should reject creation with negative budget amount', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/projects')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          name: 'Invalid Budget Project',
          budgetAmount: -5000.0,
        });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_FAILED');
    });
  });

  describe('2. Project Query, Filter & Search', () => {
    it('Positive: should list projects with KPIs and pagination meta', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/projects')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(Array.isArray(res.body.data)).toBe(true);
      expect(res.body.data.length).toBeGreaterThanOrEqual(1);
      expect(res.body.meta).toBeDefined();
      const pagination = res.body.meta.pagination;
      expect(pagination).toBeDefined();
      expect(pagination.kpis).toBeDefined();
      expect(pagination.kpis.totalProjects).toBeGreaterThanOrEqual(1);
      expect(pagination.kpis.totalBudget).toBeGreaterThanOrEqual(4500000.0);
    });

    it('Positive: should filter projects by status', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/projects?status=planned')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data.every((p: any) => p.status === 'planned')).toBe(true);
    });

    it('Positive: should search projects by text query', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/projects?search=Hyatt')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data.some((p: any) => p.name.includes('Grand Hyatt'))).toBe(true);
    });
  });

  describe('3. Project Detail & Update Lifecycle', () => {
    it('Positive: should retrieve project details by ID', async () => {
      const projectId = createdProjectIds[0];
      const res = await request(app.getHttpServer())
        .get(`/api/v1/projects/${projectId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe(projectId);
      expect(res.body.data.customerName).toBe('E2E Project Client Ltd');
    });

    it('Positive: should update project status to active and record audit trail', async () => {
      const projectId = createdProjectIds[0];
      const res = await request(app.getHttpServer())
        .put(`/api/v1/projects/${projectId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          status: 'active',
          budgetAmount: 5000000.0,
          notes: 'Scope expanded to include ballroom facade lighting',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.status).toBe('active');
      expect(res.body.data.budgetAmount).toBe(5000000.0);
      expect(res.body.data.notes).toContain('ballroom facade');

      // Verify audit log
      const auditRes = await db.query<any>(
        `SELECT action, entity_type, entity_id, before_snapshot, after_snapshot
         FROM audit_logs
         WHERE entity_id = $1 AND action = 'projects.edit'`,
        [projectId],
      );
      expect(auditRes.rows.length).toBeGreaterThanOrEqual(1);
      expect(auditRes.rows[0].before_snapshot.status).toBe('planned');
      expect(auditRes.rows[0].after_snapshot.status).toBe('active');
    });
  });

  describe('4. Project Financials', () => {
    it('Positive: should return financial summary for project', async () => {
      const projectId = createdProjectIds[0];
      const res = await request(app.getHttpServer())
        .get(`/api/v1/projects/${projectId}/financials`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(200);
      expect(res.body.data).toBeDefined();
      expect(res.body.data.projectId).toBe(projectId);
      expect(res.body.data.budgetAmount).toBe(5000000.0);
      expect(typeof res.body.data.totalSalesAmount).toBe('number');
      expect(typeof res.body.data.totalPurchaseCost).toBe('number');
      expect(typeof res.body.data.netMargin).toBe('number');
    });
  });

  describe('5. Authorization & Soft Delete', () => {
    it('Security: should reject unauthenticated project access with 401', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/projects')
        .set('X-Correlation-ID', testCid);

      expect(res.status).toBe(401);
    });

    it('Positive: should soft-delete project with mandatory audit reason', async () => {
      const projectId = createdProjectIds[0];
      const res = await request(app.getHttpServer())
        .delete(`/api/v1/projects/${projectId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          reason: 'Client cancelled hotel expansion due to municipal permits',
        });

      expect(res.status).toBe(200);
      expect(res.body.data.id).toBe(projectId);

      // Verify DB soft delete flag
      const checkRes = await db.query<any>(
        `SELECT is_deleted, delete_reason FROM projects WHERE id = $1`,
        [projectId],
      );
      expect(checkRes.rows[0].is_deleted).toBe(true);
      expect(checkRes.rows[0].delete_reason).toContain('municipal permits');

      // Verify standard findById returns 404
      const getRes = await request(app.getHttpServer())
        .get(`/api/v1/projects/${projectId}`)
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid);
      expect(getRes.status).toBe(404);
    });
  });
});
