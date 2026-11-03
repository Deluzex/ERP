import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Chat Broadcast Journey (e2e with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;

  let adminToken: string;
  let staffToken: string;
  let adminUserId: string;

  const testCid = `e2e_chat_${Date.now()}`;
  const createdNotificationIds: string[] = [];

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
    adminUserId = adminLogin.body.data.user.id;

    // Authenticate as Purchase Manager (non-admin staff)
    const staffLogin = await request(app.getHttpServer())
      .post('/api/v1/auth/login')
      .set('X-Correlation-ID', testCid)
      .send({ email: 'purchase@deluzex.com', password: 'Admin@123' })
      .expect(200);
    staffToken = staffLogin.body.data.accessToken;
  });

  afterAll(async () => {
    try {
      if (createdNotificationIds.length > 0) {
        await db.query(
          `DELETE FROM notifications WHERE id = ANY($1::uuid[])`,
          [createdNotificationIds],
        );
      }
      await db.query(
        `DELETE FROM notifications WHERE notification_type = 'team_broadcast' AND source_module = 'chat'`,
      );
    } catch (err) {
      console.warn('Cleanup error during chat-broadcast teardown:', err);
    } finally {
      await app.close();
    }
  });

  describe('POST /api/v1/chat/broadcast', () => {
    it('Negative: rejects unauthenticated requests (401)', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/chat/broadcast')
        .set('X-Correlation-ID', testCid)
        .send({
          recipients: [{ userId: adminUserId, name: 'Admin', phone: '919876543210' }],
          subject: 'Unauthorized test',
          message: 'Should fail',
        })
        .expect(401);
    });

    it('Negative: rejects non-admin users (403)', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/chat/broadcast')
        .set('Authorization', `Bearer ${staffToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          recipients: [{ userId: adminUserId, name: 'Admin', phone: '919876543210' }],
          subject: 'Forbidden test',
          message: 'Should fail with 403',
          sendWhatsApp: false,
          sendInApp: true,
        })
        .expect(403);
    });

    it('Negative: rejects empty body with 400 Bad Request', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/chat/broadcast')
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCid)
        .send({})
        .expect(400);
    });

    it('Negative: rejects payload missing required message field (400)', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/chat/broadcast')
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          recipients: [{ userId: adminUserId, name: 'Admin', phone: '919876543210' }],
          subject: 'Missing message',
        })
        .expect(400);
    });

    it('Negative: rejects invalid recipient object in recipients array (400)', async () => {
      await request(app.getHttpServer())
        .post('/api/v1/chat/broadcast')
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          recipients: [{ userId: adminUserId }], // missing name and phone
          subject: 'Invalid recipient',
          message: 'Testing validation',
        })
        .expect(400);
    });

    it('Positive: accepts valid payload, persists in-app notification, and returns BroadcastResult (201)', async () => {
      const subject = `Broadcast Test ${Date.now()}`;
      const res = await request(app.getHttpServer())
        .post('/api/v1/chat/broadcast')
        .set('Authorization', `Bearer ${adminToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          recipients: [
            {
              userId: adminUserId,
              name: 'Admin User',
              phone: '919876543210',
            },
          ],
          subject,
          message: 'Automated E2E WhatsApp + In-App Broadcast verification.',
          sendWhatsApp: false,
          sendInApp: true,
        })
        .expect(201);

      expect(res.body.data).toBeDefined();
      expect(res.body.data.sent).toBe(0);
      expect(res.body.data.failed).toBe(0);
      expect(res.body.data.inAppCreated).toBe(1);

      // Verify record exists in DB
      const dbCheck = await db.query<any>(
        `SELECT id, title, message, notification_type, source_module, recipient_user_id
         FROM notifications
         WHERE title = $1 AND source_module = 'chat'`,
        [subject],
      );

      expect(dbCheck.rows.length).toBe(1);
      expect(dbCheck.rows[0].notification_type).toBe('team_broadcast');
      expect(dbCheck.rows[0].recipient_user_id).toBe(adminUserId);

      createdNotificationIds.push(dbCheck.rows[0].id);
    });
  });
});
