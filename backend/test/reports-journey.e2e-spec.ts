import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';

describe('Reports & Business Intelligence Domain (E2E)', () => {
  let app: INestApplication;
  let accessToken: string;
  const testCid = `e2e_reports_${Date.now()}`;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
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
    await app.close();
  });

  it('1. GET /api/v1/reports/inventory — Inventory & Stock Valuation Statement', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/reports/inventory')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.reportType).toBe('inventory');
    expect(res.body.data.summary).toBeDefined();
    expect(typeof res.body.data.summary.totalStockValuation).toBe('number');
    expect(Array.isArray(res.body.data.rawMaterials)).toBe(true);
    expect(Array.isArray(res.body.data.finishedProducts)).toBe(true);
  });

  it('2. GET /api/v1/reports/purchase — Purchases Register Statement', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/reports/purchase')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.reportType).toBe('purchase');
    expect(res.body.data.summary).toBeDefined();
    expect(typeof res.body.data.summary.totalAmount).toBe('number');
    expect(Array.isArray(res.body.data.records)).toBe(true);
  });

  it('3. GET /api/v1/reports/production — Manufacturing Output & Costing Statement', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/reports/production')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.reportType).toBe('production');
    expect(res.body.data.summary).toBeDefined();
    expect(typeof res.body.data.summary.totalProductionCost).toBe('number');
    expect(Array.isArray(res.body.data.records)).toBe(true);
  });

  it('4. GET /api/v1/reports/sales — Sales Revenue & Statutory GST Register', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/reports/sales')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.reportType).toBe('sales');
    expect(res.body.data.summary).toBeDefined();
    expect(typeof res.body.data.summary.totalSalesRevenue).toBe('number');
    expect(typeof res.body.data.summary.totalGstCollected).toBe('number');
    expect(Array.isArray(res.body.data.records)).toBe(true);
  });

  it('5. GET /api/v1/reports/project-costing — Project Margins & Material Costing', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/reports/project-costing')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.reportType).toBe('project-costing');
    expect(res.body.data.summary).toBeDefined();
    expect(Array.isArray(res.body.data.records)).toBe(true);
  });

  it('6. GET /api/v1/reports/expenses — Operational & Overhead Statement', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/reports/expenses')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.reportType).toBe('expenses');
    expect(res.body.data.summary).toBeDefined();
    expect(typeof res.body.data.summary.totalExpense).toBe('number');
  });

  it('7. GET /api/v1/reports/commissions — Architect Referrals & Payout Statement', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/reports/commissions')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.reportType).toBe('commissions');
    expect(res.body.data.summary).toBeDefined();
    expect(typeof res.body.data.summary.totalCommissionAmount).toBe('number');
  });

  it('8. GET /api/v1/reports/financial-balance — Working Capital & Balance Statement', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/reports/financial-balance')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(200);
    expect(res.body.data.reportType).toBe('financial-balance');
    expect(res.body.data.summary).toBeDefined();
    expect(typeof res.body.data.summary.workingCapitalEstimate).toBe('number');
    expect(typeof res.body.data.summary.totalReceivables).toBe('number');
    expect(typeof res.body.data.summary.totalPayables).toBe('number');
  });

  it('9. Negative Cases: Reject unknown report type', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/reports/unknown-statement-xyz')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid);

    expect(res.status).toBe(400);
  });
});
