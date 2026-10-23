import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Role-Based Notifications & Visibility Journey (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;

  let adminToken: string;
  let purchaseToken: string;
  let productionToken: string;
  let salesToken: string;
  let dataEntryToken: string;

  const createdNotificationIds: string[] = [];
  const testCid = `e2e_notif_${Date.now()}`;

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

    // Authenticate as Admin
    const adminLogin = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCid)
      .send({ email: 'admin@deluzex.com', password: 'Admin@123' })
      .expect(200);
    adminToken = adminLogin.body.data.accessToken;

    // Authenticate as Purchase Manager
    const purchaseLogin = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCid)
      .send({ email: 'purchase@deluzex.com', password: 'Admin@123' })
      .expect(200);
    purchaseToken = purchaseLogin.body.data.accessToken;

    // Authenticate as Production Manager
    const prodLogin = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCid)
      .send({ email: 'production@deluzex.com', password: 'Admin@123' })
      .expect(200);
    productionToken = prodLogin.body.data.accessToken;

    // Authenticate as Sales Manager
    const salesLogin = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCid)
      .send({ email: 'sales@deluzex.com', password: 'Admin@123' })
      .expect(200);
    salesToken = salesLogin.body.data.accessToken;

    // Authenticate as Data Entry Clerk (Unrelated role)
    const dataLogin = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCid)
      .send({ email: 'dataentry@deluzex.com', password: 'Admin@123' })
      .expect(200);
    dataEntryToken = dataLogin.body.data.accessToken;
  });

  afterAll(async () => {
    // Automated database test cleanup
    try {
      if (createdNotificationIds.length > 0) {
        await db.query(
          `DELETE FROM notifications WHERE id = ANY($1::uuid[])`,
          [createdNotificationIds],
        );
      }
      await app.close();
    } catch (err) {
      console.warn('Error during notification test cleanup:', err);
    }
  });

  describe('1. Requisition Notification Creation & Idempotency', () => {
    let purchaseNotifId: string;
    let productionNotifId: string;

    it('Positive: Should create and persist a Purchase Requisition notification with full metadata', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/notifications')
        .set('Authorization', `Bearer ${salesToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          title: 'Purchase Requisition: Brass Architectural Sconce',
          message: 'Requisition of 40 PCS requested for Sales Order SO-2026-TEST-PUR (Customer: Luxury Living Ltd).',
          notificationType: 'purchase_requisition',
          targetRole: 'purchase_manager',
          sourceModule: 'sales',
          relatedEntityType: 'sales_order',
          data: {
            salesOrderNumber: 'SO-2026-TEST-PUR',
            customerName: 'Luxury Living Ltd',
            productName: 'Brass Architectural Sconce',
            productSku: 'FP-BRASS-SCONCE',
            requestedQuantity: 50,
            availableStock: 10,
            shortageQuantity: 40,
            requestType: 'Purchase',
            route: '/purchase/orders',
          },
        })
        .expect(201);

      expect(res.body.data).toBeDefined();
      expect(res.body.data.id).toBeDefined();
      expect(res.body.data.targetRole).toBe('purchase_manager');
      expect(res.body.data.data.salesOrderNumber).toBe('SO-2026-TEST-PUR');
      expect(res.body.data.data.productSku).toBe('FP-BRASS-SCONCE');
      expect(res.body.data.isRead).toBe(false);

      purchaseNotifId = res.body.data.id;
      createdNotificationIds.push(purchaseNotifId);
    });

    it('Positive: Repeated purchase request within retry window returns existing record without duplication', async () => {
      const retryRes = await request(app.getHttpServer())
        .post('/api/v1/notifications')
        .set('Authorization', `Bearer ${salesToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          title: 'Purchase Requisition: Brass Architectural Sconce (Retry)',
          message: 'Requisition of 40 PCS requested for Sales Order SO-2026-TEST-PUR.',
          notificationType: 'purchase_requisition',
          targetRole: 'purchase_manager',
          data: {
            salesOrderNumber: 'SO-2026-TEST-PUR',
            productSku: 'FP-BRASS-SCONCE',
            requestType: 'Purchase',
          },
        })
        .expect(201);

      // Must return identical notification ID, not duplicate row
      expect(retryRes.body.data.id).toBe(purchaseNotifId);
    });

    it('Positive: Should create and persist a Production Requisition notification with full metadata', async () => {
      const res = await request(app.getHttpServer())
        .post('/api/v1/notifications')
        .set('Authorization', `Bearer ${salesToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          title: 'Production Requisition: Linear LED Suspension 1200mm',
          message: 'Requisition of 25 PCS requested for Sales Order SO-2026-TEST-PRD (Customer: Modern Arch Studio).',
          notificationType: 'production_requisition',
          targetRole: 'production_manager',
          sourceModule: 'sales',
          relatedEntityType: 'sales_order',
          data: {
            salesOrderNumber: 'SO-2026-TEST-PRD',
            customerName: 'Modern Arch Studio',
            productName: 'Linear LED Suspension 1200mm',
            productSku: 'FP-LINEAR-1200',
            requestedQuantity: 30,
            availableStock: 5,
            shortageQuantity: 25,
            requestType: 'Production',
            route: '/production/orders',
          },
        })
        .expect(201);

      expect(res.body.data).toBeDefined();
      expect(res.body.data.targetRole).toBe('production_manager');
      expect(res.body.data.data.salesOrderNumber).toBe('SO-2026-TEST-PRD');

      productionNotifId = res.body.data.id;
      createdNotificationIds.push(productionNotifId);
    });
  });

  describe('2. Role-Based Notification Visibility & Isolation', () => {
    it('Admin can view all notifications (Oversight of Purchase and Production)', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      const items = res.body.data.items as any[];
      const ids = items.map((n) => n.id);

      // Admin sees both purchase and production notifications
      expect(createdNotificationIds.every((id) => ids.includes(id))).toBe(true);
      expect(res.body.data.unreadCount).toBeGreaterThanOrEqual(2);
    });

    it('Purchase user sees Purchase notifications, but cannot see Production notifications', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${purchaseToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      const items = res.body.data.items as any[];
      const purchaseNotif = items.find((n) => n.data?.salesOrderNumber === 'SO-2026-TEST-PUR');
      const productionNotif = items.find((n) => n.data?.salesOrderNumber === 'SO-2026-TEST-PRD');

      expect(purchaseNotif).toBeDefined();
      expect(purchaseNotif.targetRole).toBe('purchase_manager');
      // Production notification MUST NOT be visible to Purchase role
      expect(productionNotif).toBeUndefined();
    });

    it('Production user sees Production notifications, but cannot see Purchase notifications', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${productionToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      const items = res.body.data.items as any[];
      const purchaseNotif = items.find((n) => n.data?.salesOrderNumber === 'SO-2026-TEST-PUR');
      const productionNotif = items.find((n) => n.data?.salesOrderNumber === 'SO-2026-TEST-PRD');

      expect(productionNotif).toBeDefined();
      expect(productionNotif.targetRole).toBe('production_manager');
      // Purchase notification MUST NOT be visible to Production role
      expect(purchaseNotif).toBeUndefined();
    });

    it('Unrelated role (Data Entry) cannot view internal Purchase or Production notifications', async () => {
      const res = await request(app.getHttpServer())
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${dataEntryToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      const items = res.body.data.items as any[];
      const purchaseNotif = items.find((n) => n.data?.salesOrderNumber === 'SO-2026-TEST-PUR');
      const productionNotif = items.find((n) => n.data?.salesOrderNumber === 'SO-2026-TEST-PRD');

      expect(purchaseNotif).toBeUndefined();
      expect(productionNotif).toBeUndefined();
    });

    it('Direct API request cannot bypass role filtering via query parameters', async () => {
      // Purchase tries to supply targetRole=production_manager to bypass
      const res = await request(app.getHttpServer())
        .get('/api/v1/notifications?targetRole=production_manager')
        .set('Authorization', `Bearer ${purchaseToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      const items = res.body.data.items as any[];
      const productionNotif = items.find((n) => n.data?.salesOrderNumber === 'SO-2026-TEST-PRD');
      expect(productionNotif).toBeUndefined();
    });
  });

  describe('3. Notification Read / Unread Status Lifecycle', () => {
    it('Purchase user can mark their authorized Purchase notification as read', async () => {
      const purchaseNotifId = createdNotificationIds[0];

      const res = await request(app.getHttpServer())
        .patch(`/api/v1/notifications/${purchaseNotifId}/read`)
        .set('Authorization', `Bearer ${purchaseToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      expect(res.body.data.isRead).toBe(true);
      expect(res.body.data.readAt).toBeDefined();

      // Verify unread count decreases
      const listRes = await request(app.getHttpServer())
        .get('/api/v1/notifications?unreadOnly=true')
        .set('Authorization', `Bearer ${purchaseToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      const readItem = (listRes.body.data.items as any[]).find((n) => n.id === purchaseNotifId);
      expect(readItem).toBeUndefined();
    });

    it('Negative: Production user cannot mark Purchase notification as read (Forbidden 403)', async () => {
      const purchaseNotifId = createdNotificationIds[0];

      await request(app.getHttpServer())
        .patch(`/api/v1/notifications/${purchaseNotifId}/read`)
        .set('Authorization', `Bearer ${productionToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(403);
    });

    it('Positive: Mark all as read updates all visible notifications for user', async () => {
      const res = await request(app.getHttpServer())
        .patch('/api/v1/notifications/mark-all-read')
        .set('Authorization', `Bearer ${productionToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      expect(res.body.data.count).toBeGreaterThanOrEqual(1);

      // Verify unread count is now 0 for production
      const listRes = await request(app.getHttpServer())
        .get('/api/v1/notifications')
        .set('Authorization', `Bearer ${productionToken}`)
        .set('X-Correlation-ID', testCid)
        .expect(200);

      expect(listRes.body.data.unreadCount).toBe(0);
    });
  });
});
