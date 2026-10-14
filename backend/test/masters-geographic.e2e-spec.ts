import { INestApplication, ValidationPipe } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
const request = require('supertest');
import { AppModule } from '../src/app.module';
import { DatabasePool } from '../src/core/database/connection';

describe('Geographic Localization & Tax Determination (E2E with Auto-Cleanup)', () => {
  let app: INestApplication;
  let db: DatabasePool;
  let accessToken: string;
  const testCid = `e2e_geo_${Date.now()}`;
  const createdCustomerIds: string[] = [];
  const createdVendorIds: string[] = [];

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
    if (createdCustomerIds.length > 0) {
      await db.query('DELETE FROM customers WHERE id = ANY($1)', [createdCustomerIds]);
    }
    if (createdVendorIds.length > 0) {
      await db.query('DELETE FROM vendors WHERE id = ANY($1)', [createdVendorIds]);
    }
    await app.close();
  });

  it('1. POST /api/v1/masters/customers — Create Customer with valid Gujarat state and 6-digit pincode', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/masters/customers')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        name: 'Hotel Winsome Palace',
        mobile: '+91 98251 12345',
        email: `procurement_${Date.now()}@hotelwinsome.com`,
        gstNumber: '24AABFH0054N1ZL',
        address: 'Sindhu Bhavan Road, Bodakdev',
        city: 'Ahmedabad',
        state: 'Gujarat',
        pincode: '380054',
      });

    expect(res.status).toBe(201);
    expect(res.body.data.state).toBe('Gujarat');
    expect(res.body.data.pincode).toBe('380054');
    createdCustomerIds.push(res.body.data.id);
  });

  it('2. Negative: POST /api/v1/masters/customers rejects invalid pincodes', async () => {
    const invalidPincodes = ['012345', '40006', '4000667', '40006A'];

    for (const pincode of invalidPincodes) {
      const res = await request(app.getHttpServer())
        .post('/api/v1/masters/customers')
        .set('Authorization', `Bearer ${accessToken}`)
        .set('X-Correlation-ID', testCid)
        .send({
          name: 'Invalid Pincode Customer',
          mobile: '+91 98250 99999',
          email: `invalid_${Date.now()}@test.com`,
          address: 'Test Address',
          state: 'Gujarat',
          pincode,
        });

      expect(res.status).toBe(400);
      expect(JSON.stringify(res.body)).toMatch(/pincode/i);
    }
  });

  it('3. POST /api/v1/masters/vendors — Create Vendor with interstate (Maharashtra) state & pincode', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/masters/vendors')
      .set('Authorization', `Bearer ${accessToken}`)
      .set('X-Correlation-ID', testCid)
      .send({
        name: 'Mumbai Aluminum Extrusions Ltd',
        contactPerson: 'Karan Mehra',
        mobile: '+91 98200 44556',
        email: `sales_${Date.now()}@mumbaialu.com`,
        gstNumber: '27AAACM1122K1Z8',
        panNumber: 'AAACM1122K',
        address: 'Plot 42, Andheri East Industrial Area',
        state: 'Maharashtra',
        pincode: '400069',
      });

    expect(res.status).toBe(201);
    expect(res.body.data.state).toBe('Maharashtra');
    expect(res.body.data.pincode).toBe('400069');
    createdVendorIds.push(res.body.data.id);
  });
});
