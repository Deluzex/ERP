# Deluzex ERP — Vercel Deployment Preparation Guide

This guide documents the pre-deployment engineering audit, architectural compatibility, and manual deployment plan for hosting Deluzex ERP on Vercel with Supabase PostgreSQL.

---

## 1. Architecture

```
GitHub Repository (Monorepo)
       |
       +---> Vercel Project 1: Backend (NestJS 11 + Fluid Compute)
       |        |
       |        +---> Supabase PostgreSQL (Tokyo: aws-0-ap-northeast-1)
       |                 (PgBouncer Transaction Pooler on Port 6543)
       |
       +---> Vercel Project 2: Frontend (Flutter Web Single-Page Application)
                (Compiled to static HTML5/Wasm/CanvasKit output with SPA rewrites)
```

- **Backend**: NestJS 11 REST API deployed on Vercel as a single Vercel Function utilizing Fluid compute (zero-configuration entrypoint `src/main.ts`).
- **Frontend**: Flutter Web compiled to static assets (`frontend/build/web`), served with static caching and SPA rewrite rules routing unmatched paths to `index.html`.
- **Database**: PostgreSQL hosted on Supabase (Tokyo `ap-northeast-1`). Application traffic connects through Supabase's Transaction Pooler on port `6543`.
- **Authentication**: Stateless, backend-owned JWT with cryptographic access and refresh token pairs, RFC-compliant refresh token rotation, and database revocation ledger.

---

## 2. Backend Vercel Configuration

Vercel provides native **zero-configuration support for NestJS applications** (introduced October 2025, running on Fluid compute with active CPU pricing).

### Project Settings on Vercel:
- **Framework Preset**: NestJS (or `Other` if auto-detected as NestJS)
- **Root Directory**: `backend`
- **Build Command**: `npm run build` (runs `nest build`)
- **Output Directory**: Automatically determined by Vercel for NestJS serverless functions (`dist`)
- **Install Command**: `npm install`
- **Node.js Version**: `20.x` or `22.x`

### Entrypoint & Runtime Behavior:
- **Entrypoint**: `backend/src/main.ts` is automatically detected by Vercel.
- **Port & Host Binding**: `backend/src/main.ts` dynamically binds to `process.env.PORT` (or default 3000) on host `0.0.0.0` for container/cloud interface compatibility.
- **Production Start Script**: `backend/package.json` `start:prod` is set to `node dist/main.js` (corrected from `node dist/src/main`).

---

## 3. Frontend Vercel Configuration

Flutter Web is compiled into standard static HTML5/JS/Wasm/CSS web assets located in `frontend/build/web`. Because standard Vercel build images do not include the Flutter SDK by default, deployment can be performed via one of two strategies:

### Deployment Strategy Options:

#### Strategy A (Recommended for Manual Deployment): Local/CI Pre-build & CLI Deploy
1. Compile Flutter Web locally or in GitHub Actions:
   ```bash
   cd frontend
   flutter build web --release --dart-define=API_BASE_URL=https://YOUR-BACKEND.vercel.app/api/v1
   ```
2. Deploy the generated `build/web` folder to Vercel:
   ```bash
   cd build/web
   npx vercel deploy --prod
   ```

#### Strategy B (Vercel Git-linked Project): Prebuilt Output Repository or Custom Build Script
- **Framework Preset**: `Other`
- **Root Directory**: `frontend`
- **Output Directory**: `build/web`
- If building on Vercel directly, a custom build script must install the Flutter SDK (which increases build time by ~3-5 minutes).

### SPA Routing & Rewrite Rules:
A `vercel.json` file is placed in `frontend/web/vercel.json` (and automatically copied to `frontend/build/web/vercel.json` during `flutter build web`):
```json
{
  "cleanUrls": true,
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/index.html"
    }
  ]
}
```
This ensures that deep links (e.g. `/app`, `/login`, `/dashboard`) and browser page refreshes resolve cleanly to `index.html` without returning HTTP 404 errors.

---

## 4. Environment Variables

All sensitive values must be configured strictly in the **Vercel Project Settings > Environment Variables** dashboard. Never commit `.env` files.

### Backend Project Environment Variables:

| Variable | Required? | Secret? | Environment | Purpose / Example Value |
| :--- | :---: | :---: | :---: | :--- |
| `NODE_ENV` | Yes | No | Production, Preview | `production` |
| `PORT` | Managed | No | System (Vercel) | Automatically injected by Vercel runtime |
| `API_PREFIX` | Yes | No | All | `/api/v1` |
| `CORS_ORIGIN` | Yes | No | Production | `https://YOUR-FRONTEND.vercel.app` (or comma-separated URLs) |
| `DATABASE_URL` | Yes | **Yes** | Production, Preview | `postgresql://postgres.[REF]:[PASSWORD]@aws-0-ap-northeast-1.pooler.supabase.com:6543/postgres` |
| `DATABASE_SSL` | Yes | No | Production, Preview | `true` |
| `DATABASE_POOL_MIN`| Yes | No | Production, Preview | `0` (Prevents idle connections during serverless suspension) |
| `DATABASE_POOL_MAX`| Yes | No | Production, Preview | `5` (Conservative pool limit per serverless instance) |
| `JWT_ACCESS_SECRET`| Yes | **Yes** | Production, Preview | 64+ char cryptographically random hex/base64 string |
| `JWT_ACCESS_EXPIRES_IN`| No | No | All | `15m` (Default) |
| `JWT_REFRESH_SECRET`| Yes | **Yes** | Production, Preview | 64+ char cryptographically random hex/base64 string |
| `JWT_REFRESH_EXPIRES_IN`| No | No | All | `7d` (Default) |
| `THROTTLE_TTL` | No | No | Production | `60000` (Optional rate limiter window in ms) |
| `THROTTLE_LIMIT` | No | No | Production | `100` (Optional max requests per window) |

### Frontend Project Environment Variables:
- Flutter Web compiles constants at build time using `--dart-define=API_BASE_URL=...`.
- If building in CI/CD, provide `API_BASE_URL=https://YOUR-BACKEND.vercel.app/api/v1`.

---

## 5. Supabase Connection Strategy

### Runtime Application Connection:
- **Host**: `aws-0-ap-northeast-1.pooler.supabase.com`
- **Port**: `6543` (Supabase PgBouncer Transaction Pooler)
- **SSL**: Enabled (`rejectUnauthorized: false` or with Supabase CA)
- **Pooling Parameters**:
  - `min = 0`: Crucial for serverless environments. Prevents idle functions from keeping connections open to PgBouncer.
  - `max = 5`: Keeps total active connections well within Supabase's plan limits as Vercel instances scale horizontally.
  - `idleTimeoutMillis = 30000`
  - `connectionTimeoutMillis = 10000`

### Prepared Statement Compatibility:
The backend uses standard parameterized SQL queries via `pg.Pool` without named prepared statements. This is fully compatible with PgBouncer's transaction mode on port `6543`.

### Why `@vercel/functions attachDatabasePool()` is Not Required:
1. `attachDatabasePool` is designed for standalone global pool instances in Next.js Serverless Function files.
2. NestJS manages connection lifecycles through its Dependency Injection container (`DatabasePool` in `core/database/connection.ts`), implementing `OnModuleInit` and `OnModuleDestroy` hooks (`pool.end()`).
3. Because the backend connects through Supabase's **Transaction Pooler (port 6543)**, physical connections to Postgres are multiplexed and recycled immediately after each query or transaction. Setting `min: 0` achieves serverless safety without adding vendor lock-in.

---

## 6. Migration Procedure

**CRITICAL RULE: Migrations must NEVER execute on serverless application startup.**
Multiple concurrent cold starts executing DDL migrations simultaneously cause deadlock and race conditions.

### Recommended Migration Workflow:
1. Migrations are executed out-of-band before deploying new code.
2. Connection Method:
   - For DDL migrations, use Supabase Session Mode (`port 5432` on pooler) or Direct Connection (`db.[REF].supabase.co:5432`).
3. Migration Commands:
   ```bash
   cd backend
   # Check status of applied vs pending migrations
   npm run migrate:status
   
   # Apply pending migrations
   npm run migrate:up
   ```
4. Verify all 11 migration files (`001_foundation.sql` through `011_payments_and_expenses.sql`) are marked `APPLIED` before promoting a new production release.

---

## 7. CORS Configuration

Permissive CORS (`origin: true` with `credentials: true`) allows any site to issue authenticated requests if a victim has a session.

### Production Behavior:
The backend reads `CORS_ORIGIN`:
- When `NODE_ENV === 'production'` and `CORS_ORIGIN` is configured, only the authorized frontend domain(s) are allowed:
  ```
  CORS_ORIGIN=https://YOUR-FRONTEND.vercel.app
  ```
- Multiple origins can be specified separated by commas:
  ```
  CORS_ORIGIN=https://YOUR-FRONTEND.vercel.app,https://erp.yourdomain.com
  ```
- In local development (`NODE_ENV !== 'production'`), CORS defaults to `origin: true` so development on `localhost` continues seamlessly.

---

## 8. JWT Secret Requirements

### Security Hardening:
The backend enforces that when `NODE_ENV === 'production'`, `JWT_ACCESS_SECRET` and `JWT_REFRESH_SECRET` must be set and **cannot** match development fallback strings (`deluzex_dev_access_secret`, `deluzex_dev_super_secret...`).

### Secret Generation:
Generate cryptographically strong secrets using OpenSSL or Node.js crypto before deployment:
```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```
Generate separate secrets for `JWT_ACCESS_SECRET` and `JWT_REFRESH_SECRET`.

---

## 9. Admin Credential Handling

Migration `002_seed_foundation.sql` seeds an initial super administrator:
- **Email**: `admin@deluzex.com`
- **Default Password**: `Admin@123`

### Pre-Production Remediation Steps:
1. **Never deploy to real business users with the default password.**
2. Immediately upon initial database setup, execute one of the following:
   - **Method A (SQL Update in Supabase SQL Editor)**:
     Generate a new Argon2id password hash and update the record:
     ```sql
     UPDATE users 
     SET password_hash = '<NEW_ARGON2ID_HASH>' 
     WHERE email = 'admin@deluzex.com';
     ```
   - **Method B (Immediate Login & Change)**:
     Log in immediately after initial deployment using a private browser session and change the administrator password.
3. In `frontend/lib/features/auth/screens/login_screen.dart`, remove or hide the demo quick-login role chips before production release.

---

## 10. Manual Deployment Steps

### Step 1: Database Verification
1. Ensure your Supabase project is active in `ap-northeast-1`.
2. Run database migrations from a secure operator machine:
   ```bash
   cd backend
   DATABASE_URL="postgresql://postgres.[REF]:[PASS]@aws-0-ap-northeast-1.pooler.supabase.com:6543/postgres" npm run migrate:status
   DATABASE_URL="postgresql://postgres.[REF]:[PASS]@aws-0-ap-northeast-1.pooler.supabase.com:6543/postgres" npm run migrate:up
   ```
3. Update the admin password in Supabase.

### Step 2: Deploy Backend to Vercel
1. In the Vercel Dashboard, click **Add New > Project**.
2. Select your GitHub repository.
3. Set **Root Directory** to `backend`.
4. Vercel detects **NestJS**. Ensure:
   - Build Command: `npm run build`
   - Output Directory: `dist`
5. Configure Environment Variables (from Section 4).
   - Set `CORS_ORIGIN=https://YOUR-FRONTEND.vercel.app` (you can update this once the frontend domain is generated).
6. Click **Deploy**.
7. Note your backend URL: `https://YOUR-BACKEND.vercel.app`.

### Step 3: Deploy Frontend to Vercel
1. Build Flutter Web pointing to the live backend:
   ```bash
   cd frontend
   flutter build web --release --dart-define=API_BASE_URL=https://YOUR-BACKEND.vercel.app/api/v1
   ```
2. Deploy the built static output to Vercel:
   ```bash
   cd build/web
   npx vercel deploy --prod
   ```
3. Once deployed, note your frontend URL: `https://YOUR-FRONTEND.vercel.app`.
4. Go back to Vercel Backend Project Settings and update `CORS_ORIGIN` to match your frontend URL. Redeploy backend if required.

---

## 11. Testing Checklist (Post-Deployment Validation)

- [ ] **Backend Health / API Root**: Verify `GET https://YOUR-BACKEND.vercel.app/api/v1` or Swagger at `https://YOUR-BACKEND.vercel.app/api/docs`.
- [ ] **CORS Verification**: Inspect headers on `OPTIONS /api/v1/auth/login` to ensure `Access-Control-Allow-Origin` matches your frontend domain.
- [ ] **Authentication Flow**:
  - [ ] Login via `POST /api/v1/auth/login` with admin credentials.
  - [ ] Verify access token (`sub`, `roles`, `permissions`) and refresh token return.
  - [ ] Call `GET /api/v1/auth/me` with Bearer token.
  - [ ] Test token refresh via `POST /api/v1/auth/refresh`.
  - [ ] Test logout via `POST /api/v1/auth/logout`.
- [ ] **Database CRUD Validation**:
  - [ ] Create and fetch a record (e.g. Master Category, Customer, or Vendor).
  - [ ] Verify atomic transaction rollback on invalid inputs.
- [ ] **Frontend Validation**:
  - [ ] Load `https://YOUR-FRONTEND.vercel.app`.
  - [ ] Test browser refresh on an internal route (e.g. `/app` or `/dashboard`) to confirm SPA rewrite rules work.
  - [ ] Verify font loading, responsive layout, and icon rendering.
  - [ ] Perform a full user journey: Login -> Navigate to Inventory -> View stock -> Logout.

---

## 12. Known Limitations & Recommendations

1. **Cold Starts**: NestJS on serverless functions experiences cold-start latency (~1-2 seconds on initial wake). Vercel's Fluid compute mitigates this significantly through connection pooling and concurrency multiplexing.
2. **WebSockets / Server-Sent Events**: Standard Vercel Serverless Functions have maximum execution durations. If long-lived bi-directional WebSockets are needed in the future, Supabase Realtime or a dedicated container service is recommended.
3. **File Storage**: The backend does not store files locally. If file uploads (receipts, vouchers, attachments) are added in the future, integrate Supabase Storage or AWS S3 presigned URLs.

---

## 13. Future CI/CD Plan

```
      Git Push
         |
  +------+------+
  |             |
branch: dev   branch: main
  |             |
  v             v
Vercel        Vercel
Preview       Production
Deployment    Deployment
```

1. **Branching Strategy**:
   - `main`: Deploys to Production environment (`YOUR-BACKEND.vercel.app` & `YOUR-FRONTEND.vercel.app`).
   - `dev` / `development`: Deploys to Preview environment with staging Supabase database.
   - Feature branches (`feat/*`): Automatic ephemeral Vercel preview environments.
2. **Automated Pipeline**:
   - Step 1: Run Jest unit tests & linting on GitHub Actions.
   - Step 2: Run Flutter analyze & test on GitHub Actions.
   - Step 3: Run database migration check against staging.
   - Step 4: Trigger Vercel deployment with appropriate environment bindings.
