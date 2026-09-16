# Deluzex ERP — Comprehensive Project Context & Reference

**Document Version:** 1.1.0  
**Last Updated:** 2026-09-16  
**Current Branch:** `Feat---Backend-Setup`  
**Current Phase:** Phase 1 — Master Data Registry & Stock Management (Phase 0 Foundation Complete)  
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
6. **Statutory GST Accounting:** Intra-state (CGST + SGST) vs inter-state (IGST) calculation based on place of supply, signed entered round-offs, and immutable audit logging.

### 1.2 Target Users & Roles
- **Procurement Team:** Manages vendor master data, raises Purchase Orders, processes Inward Bills.
- **Store & Warehouse Managers:** Audits stock, manages `Stock In`, issues materials to production (`Stock Out`), performs adjustments with mandatory audit reasons.
- **Production Operators:** Executes production work orders, logs raw material consumption and finished goods assembly.
- **Sales & Billing Executives:** Issues quotations, converts to sales orders/challans, generates GST tax invoices.
- **Project Coordinators:** Connects architects and dealers to projects and client installations.
- **Finance & Accounts Team:** Manages GST tax summaries, vendor payments, customer collections, and commission payouts.
- **Business Owners / Admins:** Controls user access, defines custom RBAC roles, audits operations.

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
Riverpod Notifiers & Services (State Management)
    │
    ▼
Dio ApiClient (/api/v1 REST)
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

## 4. Modules & Domain Features

```
┌────────────────────────────────────────────────────────────────────────┐
│                          DELUZEX ERP MODULES                           │
├──────────────────┬──────────────────┬─────────────────┬────────────────┤
│     MASTERS      │  STOCK & PURCH.  │  MANUFACTURING  │ SALES & COMM.  │
│  (Units, RM, FP, │ (Purchases, PO,  │ (Work Orders,   │ (Quotations,   │
│   Vendors, Cust, │  Stock Ledger,   │  BOM/Assembly,  │  Invoices,     │
│   Dealers, Arch) │  Adjustments)    │  Costing)       │  Commissions)  │
└──────────────────┴──────────────────┴─────────────────┴────────────────┘
```

### 4.1 Master Data Registry (Current Work Focus)
- **Categories & Measurement Units (`categories`, `measurement_units`):**
  - Standard measurement units: `PCS`, `MTR`, `KG`, `BOX`, `SET`, `ROL`, `LITRE`.
  - Exactly one unit per item. **No unit conversions** (Q-15 confirmed).
- **Vendors (`vendors`):**
  - Name, Contact Person, Mobile, Email, GST Number (15-char), PAN (10-char), Address, Payment Terms, Credit Limit.
  - Soft-delete with mandatory `delete_reason`.
  - Partial unique index on `gst_number WHERE is_deleted = false`.
- **Raw Materials (`raw_materials`):**
  - Item Code (`UNIQUE WHERE is_deleted = false`, Q-06 allows reuse after soft delete).
  - Category, Unit, nullable `hsn_sac_code` (Q-23), stock thresholds (`opening_stock`, `minimum_stock`, `reorder_level` as `numeric(18,4)`), `default_purchase_price` (`numeric(18,2)`), `gst_percent`.
- **Finished Products (`finished_products`):**
  - Item Code, Category, Unit, HSN/SAC, stock quantities, multi-tier pricing (`cost_price`, `dealer_selling_price`, `customer_selling_price`), `gst_percent`.
- **Parties (Customers, Dealers, Architects):**
  - Customers: Direct buyers with mobile, GSTIN (optional), state code, balance tracking.
  - Dealers: Commercial distributors with company name, mandatory GSTIN, credit limits.
  - Architects: Design partners with default commission rate (e.g. 5–7%), commission balance tracking.
  - **Dual Identity Linking:** Bi-directional link between Customer and Architect (`customers.linked_architect_id` ↔ `architects.linked_customer_id`) allowing an entity to act as both specifier and purchaser.

### 4.2 Stock Management & Ledger (Phase 1 Next Step)
- **Append-Only Ledger (`stock_transactions`):**
  - Immutable insert-only table. Mutation triggers forbid `UPDATE` and `DELETE`.
  - Exactly **8 Transaction Types:** `PURCHASE`, `PRODUCTION_CONSUMPTION`, `PRODUCTION_OUTPUT`, `SALE`, `SALE_RETURN`, `PURCHASE_RETURN`, `DAMAGE`, `ADJUSTMENT`.
  - **No `TRANSFER` type:** Inter-location stock transfer is explicitly out of scope (Q-19).
- **Cached Stock Balances (`stock_balances`):**
  - `(stock_location_id, item_type, item_id) → quantity`.
  - Maintained atomically within ledger transactions using `SELECT ... FOR UPDATE`.
  - 100% reconstructible from ledger `SUM(quantity_in) - SUM(quantity_out)`.
- **Stock Scoping (ADR-013):**
  - Every transaction and balance is anchored to `stock_location_id` (`NOT NULL`).
  - Branch and warehouse hierarchies are optional.

### 4.3 Purchase & Inward Management
- **Workflow:** Draft → Confirmed.
- **Draft:** No stock or financial impact; fully editable.
- **Confirmation:** Atomic execution inserting `stock_transactions`, updating `stock_balances`, and incrementing vendor payable.
- **Statutory Calculation Chain (ADR-015):**
  $$\text{Gross Amount} - \text{Discount} = \text{Taxable Amount} \xrightarrow{+ \text{GST}} \text{Sub-Total} \xrightarrow{+ \text{Round Off}} \text{Grand Total}$$
  - Discount is applied **before** GST.
  - Intra-state (Gujarat State Code 24) = CGST + SGST (IGST = 0).
  - Inter-state (Other States) = IGST (CGST = SGST = 0).
  - **Round-Off (ADR-015 §3, Sample Invoice 046):** Must be an **entered, signed adjustment** (e.g. −₹93.50), **not** an automated paise-rounding algorithm.

---

## 5. Current Branch & Work-in-Progress Analysis

### 5.1 Git Context
- **Current Branch:** `Feat---Backend-Setup`
- **Upstream:** `origin/Feat---Backend-Setup` (in sync)
- **Last Committed Commit (`d73595e`):** Initialized NestJS backend, foundation migrations (`001_foundation.sql`, `002_seed_foundation.sql`), core auth/identity, and initial Flutter setup.

### 5.2 Working Tree Status & Untracked Files
The following major work has been implemented in the working tree:

| Component | Files | Implementation Status | Test Status |
|---|---|---|---|
| **Database Migration** | `backend/migrations/003_masters.sql` | Applied on Supabase PostgreSQL (Categories, Units, Vendors, RM, FP, Customers, Dealers, Architects) | Verified active in DB |
| **Backend Masters Module** | `backend/src/modules/masters/` (6 controllers, 6 services, 8 DTOs, module) | Complete CRUD + soft-delete + dual-linking | `test/masters-journey.e2e-spec.ts` **PASSED (17/17)** |
| **Backend Integration** | `backend/src/app.module.ts` | `MastersModule` imported into Root Module | Builds cleanly (`nest build`) |
| **Flutter API Services** | `frontend/lib/core/api/` (10 service files) | Implemented using Dio with auth token injection | Unit tested |
| **Flutter Models** | `frontend/lib/core/models/*_model.dart` | Updated with `fromJson` and `toJson` matching NestJS DTOs | Unit tested |
| **Flutter Validators** | `frontend/lib/core/utils/validators.dart` | Statutory regex validation for 15-char GSTIN, 10-char PAN | `test/vendor_api_binding_test.dart` **PASSED (5/5)** |
| **Flutter Mock DB Bridge** | `frontend/lib/shared/services/mock_database_service.dart` | Augmented with async methods calling backend API with fallback | Working |
| **Flutter Master Screens** | `frontend/lib/features/masters/screens/*.dart` | Rewired to call async database/API methods | **3 Screens have missing import** |

### 5.3 Exact Diagnosis of Where Work Stopped
Right before the previous session paused, the agent was wiring the frontend master screens to the backend API:
1. **`vendors_screen.dart`:** Fully updated and tested.
2. **`dealers_screen.dart`, `customers_screen.dart`, `architects_screen.dart`:** Updated to use `ErpConfirmDeleteDialog`, but the file import:
   ```dart
   import '../../../core/widgets/erp_confirm_dialog.dart';
   ```
   was **omitted from the imports list** in those three files. This causes `flutter analyze` and widget tests to report:
   `Error: The method 'ErpConfirmDeleteDialog' isn't defined for the type ...`
3. **`document_sharing_service.dart`:** Line 33 imports `dart:html` unconditionally, which causes VM-based `widget_test.dart` to fail on desktop.
4. **Active Open File:** `backend/src/modules/masters/controllers/vendors.controller.ts` was open in the IDE.

---

## 6. Open Questions & Technical Risk Assessment

### 6.1 Status of Architectural Questions
- **Q-05a (Round-Off):** Closed. Enterable signed amount; followed Invoice 046.
- **Q-06 (Item Code Reuse):** Closed. Allowed after soft-delete via partial index.
- **Q-07 & Q-08 (Document Numbering):** Closed. Continuous sequence, no yearly reset.
- **Q-13 (Credit Limit):** Closed. Warning issued upon exceeding limit.
- **Q-15 (Units):** Closed. Dedicated Master, no unit conversions.
- **Q-19 (Stock Transfer):** Closed. Inter-location transfer is out of scope. Exactly 8 transaction types.
- **Q-22 (Legal Entity):** Closed. Single client entity in Gujarat (ADR-014).
- **Q-23 (HSN/SAC Code):** Closed. Nullable text column on raw materials and finished products.
- **Q-24 (Consignee vs Buyer State for Place of Supply):** **PENDING BUSINESS CLARIFICATION.** When Consignee (Ship-to) and Buyer (Bill-to) are in different states, which state governs intra-state vs inter-state GST?

### 6.2 Key Risks & Mitigations
- **Ledger Concurrency:** Concurrent operations updating stock balances. *Mitigation:* Explicit row locking (`SELECT ... FOR UPDATE`) in PostgreSQL transactions.
- **Precision Leaks:** Accidental use of `double` in new financial calculations. *Mitigation:* ADR-011 decimal rule enforcement and unit test coverage.
- **Dual-State Out-of-Sync:** Flutter frontend managing both in-memory mock state and remote API state. *Mitigation:* Ticket-by-ticket migration to pure Riverpod `AsyncNotifier` consuming the REST API.

---

## 7. Immediate Resumption Plan

When starting back work:
1. **Fix Missing Imports:** Add `import '../../../core/widgets/erp_confirm_dialog.dart';` to:
   - `frontend/lib/features/masters/screens/dealers_screen.dart`
   - `frontend/lib/features/masters/screens/customers_screen.dart`
   - `frontend/lib/features/masters/screens/architects_screen.dart`
2. **Fix Web Guard:** Guard `dart:html` in `frontend/lib/core/utils/document_sharing_service.dart` with `kIsWeb` check so tests run cleanly across all platforms.
3. **Verify Frontend Suite:** Run `flutter analyze lib test` and `flutter test` to ensure zero compilation or test failures.
4. **Stage & Commit Masters Module:** Clean commit for Phase 1 Master Data Registry (NestJS + Flutter + Migration 003).
5. **Begin Stock Management & Purchases:** Implement `004_stock_ledger.sql`, `stock_transactions`, and `purchases` modules per Phase 1 specification.
