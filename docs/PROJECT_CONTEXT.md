# Deluzex ERP — Comprehensive Project Context & Reference

**Document Version:** 3.0.0  
**Last Updated:** 2026-09-21  
**Current Branch:** `Feat---Backend-Setup`  
**Current Phase Status:** **Phases 1 through 8 are 100% Complete, Bound, and Verified** (Phases 9 & 10 are strictly ON HOLD awaiting QA/BA sign-off)  
**Detailed Audit Reference:** [`docs/PROJECT_PROGRESS_AND_MODULE_AUDIT.md`](PROJECT_PROGRESS_AND_MODULE_AUDIT.md)  
**Primary Authorities:**  
1. [`PROJECT_RULES.md`](../PROJECT_RULES.md) (The Constitution)  
2. [`Client Doc/FINAL_BUSINESS_DECISIONS.md`](../Client%20Doc/FINAL_BUSINESS_DECISIONS.md) & [`Client Doc/046 Hotel Winsome, Ahmedabad.pdf`](../Client%20Doc/046%20Hotel%20Winsome,%20Ahmedabad.pdf) (Authoritative Client Evidence)  
3. [`docs/business/STOCK_MANAGEMENT_SOURCE_DOCUMENT.md`](business/STOCK_MANAGEMENT_SOURCE_DOCUMENT.md) (Business Source of Truth)  
4. [`docs/decisions/`](decisions/) (Accepted ADRs: ADR-001 through ADR-015)  
5. Specialized Rulebooks: [`ARCHITECTURE.md`](../ARCHITECTURE.md), [`SECURITY_RULES.md`](../SECURITY_RULES.md), [`DATABASE_RULES.md`](../DATABASE_RULES.md), [`BACKEND_RULES.md`](../BACKEND_RULES.md), [`FLUTTER_RULES.md`](../FLUTTER_RULES.md), [`API_CONVENTIONS.md`](../API_CONVENTIONS.md), [`TESTING_RULES.md`](../TESTING_RULES.md), [`BACKEND_API_REQUIREMENTS.md`](../BACKEND_API_REQUIREMENTS.md)

---

## 1. Project Overview

### 1.1 Business Purpose & Problem Domain
**Deluzex ERP** is an enterprise-grade ERP built specifically for **Blazon Creative / Deluxex Lighting & Living Ltd.**, an architectural fabrication and luxury lighting manufacturing company based in **Gujarat, India** (specializing in aluminum extrusions, toughened architectural glass, custom lighting fixtures, chandeliers, and decorative hardware).

The business solves several operational challenges:
1. **Raw Material Procurement:** Managing supplier catalogs, GST/PAN compliance, credit limits, purchase orders, inward MRNs, and vendor outstandings.
2. **Flexible Stock Management:** Multi-tier physical inventory tracking across stock locations without requiring rigid branch/warehouse hierarchies (ADR-013).
3. **BOM & Manufacturing:** Converting raw materials into finished lighting fixtures, tracking production consumption, wastage, and cost allocation.
4. **Commercial Sales & Projects:** Multi-tier pricing (direct Customer vs wholesale Dealer), Quotations, Proforma Invoices, Sales Orders, Delivery Challans, and GST Tax Invoices.
5. **Architect Commission Attribution:** Tracking dual identities (e.g. an architect who is also a direct customer), project-specific commissions, approval workflows, and disbursements.
6. **Payments & Reconciliations:** Tracking Customer & Dealer receipts, Vendor bill-wise disbursements, Architect commission payouts, and categorized operating expenses.
7. **Statutory GST Accounting & BI:** Intra-state (CGST + SGST) vs inter-state (IGST) calculation based on place of supply, signed entered round-offs, 8 core managerial/statutory reports, and immutable audit logging.

### 1.2 Target Users & Roles
- **Procurement Team:** Manages vendor master data, raises Purchase Orders, processes Inward Bills.
- **Store & Warehouse Managers:** Audits stock, manages `Stock In`, issues materials to production (`Stock Out`), performs adjustments with mandatory audit reasons.
- **Production Operators:** Executes production work orders, logs raw material consumption and finished goods assembly.
- **Sales & Billing Executives:** Issues quotations, converts to sales orders/challans, generates GST tax invoices.
- **Project Coordinators:** Connects architects and dealers to projects and client installations.
- **Finance & Accounts Team:** Manages GST tax summaries, vendor payments, customer collections, commission payouts, and operating expenses.
- **Business Owners / Admins:** Controls user access, defines custom RBAC roles, audits operations, inspects financial and working capital reports.

### 1.3 Target Deployment & Single Legal Entity Scope (ADR-014, Q-22)
- **Dedicated Single-Client Instance:** The platform is built for **one single legal entity** registered in Gujarat (State Code 24).
- **Zero Multi-Tenant Bloat:** No `company_id` discriminator on master records, transactions, or documents. No multi-tenant RLS in PostgreSQL.
- Organization-wide uniqueness applies directly to business codes: `UNIQUE (item_code)`, `UNIQUE (gst_number)` (scoped by active records).

---

## 2. Technology Stack & Environment

| Layer | Mandated Technology | Details & Constraints |
|---|---|---|
| **Frontend UI** | Flutter + Dart (v3.47.3 / SDK ^3.11.5) | Desktop (Windows/macOS/Linux), Web, Tablet, Mobile responsive layout. |
| **Frontend State** | Flutter Riverpod (`^2.5.1`) | `StateNotifier` / `Provider` with explicit loading, error, and optimistic state. |
| **Frontend Network** | Dio (`^5.11.1`) | Typed REST API client with Bearer Token interceptor and global error mapping. |
| **Backend API** | Node.js + TypeScript + NestJS (`^11.0.0`) | Modular clean architecture, class-validator (`whitelist: true, forbidNonWhitelisted: true`). |
| **Database** | PostgreSQL on Supabase (`aws-0-ap-northeast-1`) | Managed pg connection pool (`DatabasePool`), raw parameterized SQL, forward-only migrations. |
| **Authentication** | Backend-Owned (ADR-003) | Custom auth module: Argon2id password hashing, signed JWT access tokens (15m), database-persisted refresh tokens (7d). **Supabase Auth is NOT used.** |
| **Authorization** | Granular RBAC (ADR-004) | Customer-defined roles; `<module>.<action>` permission strings; deny by default. |
| **API Protocol** | REST (`/api/v1`) | Envelopes `{ data, meta }` or `{ error: { code, message, correlationId } }`, `camelCase` JSON. |
| **Data Precision** | Decimal End-to-End (ADR-011) | `numeric(18,2)` for currency, `numeric(18,4)` for stock quantities; transported as JSON strings. Floating-point numbers are strictly forbidden. |
| **Testing** | Jest + Supertest (Backend), Flutter Test (Frontend) | Mandatory AI-TDD lifecycle (RED → GREEN → REFACTOR) with automated database cleanup. |

---

## 3. System Architecture & End-to-End Flow

### 3.1 Linear Dependency Flow
```
Flutter UI (Presentation)
    │
    ▼
Riverpod Notifiers & MockDatabaseService (State Management & Offline Fallback)
    │
    ▼
Dio ApiClient (/api/v1 REST with Auth & Correlation Interceptors)
    │
    ▼
NestJS Controllers (AuthGuard, PermissionGuard, ScopeGuard, ValidationPipe)
    │
    ▼
Domain / Application Services (Business Logic, Unit of Work, Audit Trail)
    │
    ▼
DatabasePool (PostgreSQL on Supabase)
```

### 3.2 End-to-End Request Pipeline
1. **Client Request:** Flutter sends HTTP request to `/api/v1/...` with Bearer JWT and `X-Correlation-ID`.
2. **Correlation ID Middleware:** Assigns or preserves the correlation ID across the entire execution life.
3. **Authentication Guard:** Verifies JWT signature and expiry, extracts `userId` and `roles`.
4. **Permission Guard:** Checks user permissions against `@RequirePermission('<module>.<action>')`.
5. **Scope Guard:** Resolves branch and stock-location access bounds for the user.
6. **Validation Pipe:** Validates input DTO using `class-validator` (strips untrusted properties, rejects invalid types).
7. **Business Service:** Executes domain logic inside transactional Unit of Work where required.
8. **Audit Logging:** Automatically logs business actions into immutable `audit_logs` table.
9. **Response Envelope Interceptor:** Wraps successful result in `{ data, meta }`.
10. **Exception Filter:** Catches domain and HTTP errors, returning unified `{ error: { code, message, correlationId, details } }`.

---

## 4. Current Implementation Status (Phases 1 to 8: 100% Complete)

| Component | Status | Evidence & Metrics |
|---|---|---|
| **Phase 0: Auth & RBAC** | ✅ Complete | JWT + Argon2id, dynamic RBAC, `auth-journey` + `rbac-journey` passing |
| **Phase 1: Masters** | ✅ Complete | 7 master entities, soft deletes, GSTIN/PAN checks, `masters-journey` passing |
| **Phase 2: Inventory** | ✅ Complete | Immutable stock ledger, adjustments, alerts, `inventory-journey` passing |
| **Phase 3: Purchases** | ✅ Complete | PO + Inward Bills, GST calculations, stock inward, `purchases-journey` passing |
| **Phase 4: Production** | ✅ Complete | Work orders, BOM consumption, assembly inward, rollback, `production-journey` passing |
| **Phase 5: Sales** | ✅ Complete | 7-stage commercial pipeline, signed round-off, `sales-journey` passing |
| **Phase 6: Projects** | ✅ Complete | Portfolios, material consumption, financials, `projects-journey` passing |
| **Phase 7: Payments & Expenses** | ✅ Complete | Receipts, vendor payments, commissions, expenses, `payments-journey` + `expenses-journey` passing |
| **Phase 8: Reports & BI** | ✅ Complete | 8 core reports (Inventory, Purchases, Production, Sales, Costing, Expenses, Commissions, Financial Balance), `reports-journey` passing |
| **Phase 9: OCR & WhatsApp** | ⏸️ ON HOLD | Strictly on hold per user instructions awaiting QA/BA sign-off |
| **Phase 10: Release Hardening** | ⏸️ ON HOLD | Strictly on hold per user instructions awaiting QA/BA sign-off |

---

## 5. Verification Test Suite Summary

- **Backend Unit Tests:** **47 passing** (`npm test`)
- **Backend E2E Database Journey Tests:** **119 passing** (`npm run test:e2e`)
- **Frontend Flutter Unit & Binding Tests:** **36 passing** (`flutter test`)
- **Total Automated Tests:** **202 / 202 Green (100% Passing)**
- **Build Status:** TypeScript backend compiles with 0 errors (`npm run build`). Flutter static analysis has 0 compilation errors (`flutter analyze lib test`).
