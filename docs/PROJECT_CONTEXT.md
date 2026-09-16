# Deluzex ERP — Comprehensive Project Context & Reference

**Document Version:** 1.0.0  
**Date:** 2026-09-16  
**Current Phase:** Phase 0 — Foundation  
**Primary Authorities:**  
1. [`PROJECT_RULES.md`](../PROJECT_RULES.md) (The Constitution)  
2. [`Client Doc/FINAL_BUSINESS_DECISIONS.md`](../Client%20Doc/FINAL_BUSINESS_DECISIONS.md) & [`Client Doc/046 Hotel Winsome, Ahmedabad.pdf`](../Client%20Doc/046%20Hotel%20Winsome,%20Ahmedabad.pdf) (Authoritative Client Evidence)  
3. [`docs/business/STOCK_MANAGEMENT_SOURCE_DOCUMENT.md`](business/STOCK_MANAGEMENT_SOURCE_DOCUMENT.md) (Business Source of Truth)  
4. [`docs/decisions/`](decisions/) (Accepted ADRs: ADR-001 through ADR-015)  
5. Specialized Rulebooks: [`ARCHITECTURE.md`](../ARCHITECTURE.md), [`SECURITY_RULES.md`](../SECURITY_RULES.md), [`DATABASE_RULES.md`](../DATABASE_RULES.md), [`BACKEND_RULES.md`](../BACKEND_RULES.md), [`FLUTTER_RULES.md`](../FLUTTER_RULES.md), [`API_CONVENTIONS.md`](../API_CONVENTIONS.md), [`TESTING_RULES.md`](../TESTING_RULES.md)

---

## 1. Project Overview

### 1.1 Business Purpose & Real-World Problem
Deluzex ERP is a complete, production-grade enterprise resource planning system tailored for a manufacturing and fabrication business operating in Gujarat, India (specializing in materials like aluminum extrusions, toughened glass, decorative hardware, etc.). 

The business manages the entire lifecycle:
1. Sourcing raw materials from vendors.
2. Holding inventory in flexible stock locations.
3. Manufacturing / assembling finished products (consuming raw materials and outputting finished goods).
4. Selling finished products to direct customers or through commercial networks of dealers and architects.
5. Tracking complex commission arrangements (project-based commissions and annual turnover incentive slabs).
6. Managing payables, receivables, and statutory GST accounting.

### 1.2 Target Users & Roles
- **Procurement & Purchase Team:** Records vendors, monitors raw material stock thresholds, issues purchase orders, processes vendor bills and payments.
- **Inventory & Store Managers:** Audits stock, oversees stock receipts (`Stock In`), issues materials to production (`Stock Out`), conducts adjustments with mandatory audit reasons.
- **Production / Plant Operators:** Records production batches, monitors actual consumption vs output, calculates cost per product.
- **Sales & Billing Executives:** Issues quotations, sales orders, GST-compliant tax invoices, applies customer/dealer price books.
- **Project Coordinators & Relationship Managers:** Links architects and dealers to specific commercial projects for commission attribution.
- **Finance & Accounts Team:** Manages GST categorization (CGST/SGST vs IGST), vendor outstandings, customer receivables, entered round-offs, commission statements, and payment disbursement.
- **System Administrators / Business Owners:** Manages organization structure, configures granular role-permission mappings, reviews audit logs.

### 1.3 Target Deployment & Scope (ADR-014)
- **Dedicated Single-Client Instance:** The earlier requirement for a Multi-Tenant SaaS platform was **withdrawn on 2026-08-29 (ADR-014)**. 
- The system is built for **one legally registered entity** ( ब्लैज़न / Blazon Creative / client entity in Gujarat).
- **No multi-tenant machinery:** There is no tenant isolation layer, no multi-tenant RLS in PostgreSQL, and no `company_id` discriminator on master records or transaction tables.
- Future clients receive separate, independently deployed instances with separate databases.
- Access control within the instance remains strictly enforced via authentication, granular permissions, and branch/stock-location scoping.

---

## 2. Technology Stack & Environment

| Layer | Mandated Technology | Details & Constraints |
|---|---|---|
| **Frontend** | Flutter + Dart (v3.11.5+) | Responsive & adaptive UI for Desktop (Windows/macOS/Linux), Web, Tablet, and Mobile. |
| **State Management** | Flutter Riverpod (`^2.5.1`) | `Notifier` / `AsyncNotifier` for async state; explicit handling of loading/error/empty states. |
| **Backend API** | Node.js + TypeScript + NestJS | Modular enterprise architecture; strict clean layering. |
| **Database** | PostgreSQL hosted on Supabase | Accessed strictly through NestJS repositories; Supabase is an infrastructure host only. |
| **Authentication** | Backend-Owned (ADR-003) | Custom auth module: Argon2id/bcrypt hashing, signed JWT access tokens, rotating revocable refresh tokens in Postgres. **Supabase Auth is NOT used.** |
| **Authorization** | Granular RBAC (ADR-004) | Customer-defined roles; code checks fine-grained permissions (`<module>.<action>`); deny by default. |
| **API Protocol** | REST (`/api/v1`) | Envelopes `{ data, meta }`, `camelCase` JSON, HTTP status codes, strict DTO validation (`ValidationPipe`). |
| **Data Types** | Decimal end-to-end (ADR-011) | `numeric(18,2)` for currency, `numeric(18,4)` for stock quantities; transported as JSON strings. IEEE 754 floats forbidden. |
| **Testing** | Jest (Backend), Flutter Test (Frontend) | Mandatory Test-Driven Development (TDD: RED → GREEN → REFACTOR); recorded RED runs in PRs. |

---

## 3. System Architecture & Component Interaction

### 3.1 Linear Dependency Flow
```
Flutter UI → REST API Gateway → NestJS Backend → Repository Layer → PostgreSQL (Supabase)
```
- The Flutter client talks **only** to the NestJS REST API. It never connects directly to Supabase/PostgreSQL, and never possesses database credentials or service-role keys.
- Supabase provides the managed PostgreSQL engine; backend migration files are raw forward-only SQL managed via CI.

### 3.2 Backend Layered Architecture (NestJS)
No layer may be skipped, and dependencies only flow inward:
```
Controller
  ├── Guard / Auth (JWT validation, permission verification, scope resolution)
  │     └── Extracts trusted RequestContext (userId, permissions, branchIds, stockLocationIds)
  ├── Validation (DTO with class-validator: whitelist & forbidNonWhitelisted)
  └── Application / Use Case (Orchestration, Unit of Work / Transaction boundary, Audit events)
        ├── Domain Layer (Pure TypeScript business rules, entities, domain errors)
        └── Repository Layer (Data persistence, SQL mapping)
              └── PostgreSQL
```

### 3.3 Flutter Layered Architecture
New features follow ADR-008 (migrating away from the two-layer mock prototype):
```
Presentation (Widgets / Screens)
  └── State Management (Riverpod Notifiers / AsyncValue)
        └── Domain Layer (Pure Dart entities, value objects, repository interfaces)
              └── Data Layer (Repository implementations, DTOs, mappers)
                    └── Network (Dio/HTTP Client with Bearer Token interceptor)
```

### 3.4 Organizational & Stock Location Scope (ADR-013)
The system supports three structural shapes without requiring schema changes:
- **Scenario A:** Company → Stock (No branches, no warehouses)
- **Scenario B:** Company → Branch → Stock (Branches present, no sub-warehouses)
- **Scenario C:** Company → Branch → Warehouse → Stock (Full hierarchy)

**Key Architectural Invariant:**
- `warehouse_id` and `branch_id` are **never assumed mandatory**.
- Every stock movement and stock balance is anchored to a **`stock_location_id` (`NOT NULL`)**.
- The `stock_locations` table maps each location to `COMPANY`, `BRANCH`, or `WAREHOUSE` level with check constraints. This guarantees that balance keys `(stock_location_id, item_type, item_id)` never contain `NULL`, eliminating PostgreSQL `NULL <> NULL` deduplication bugs.

---

## 4. Modules & Domain Features

### Current Phase Discipline
- **Current Status: Phase 0 — Foundation.**
- **Phase 1 (Next):** Stock Management (Vendors, Units, Raw Materials, Finished Products, Purchases, Stock Ledger).
- **Phases 2–5 (Blocked for implementation):** Manufacturing (Phase 2), Sales & Projects (Phase 3), Commission (Phase 4), Reports/Export (Phase 5).
- *Governing Rule:* Implementation is strictly phase-gated, but business requirements and design clarity must be resolved immediately.

### Module Summary
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

#### 1. Masters Management
- **Units Master:** First-class entity (`units`). Dedicated symbol/name. Exactly **one unit per item** (e.g., `kg`, `sq feet`, `piece`, `No`). **No unit conversions** (Q-15 confirmed).
- **Raw Materials:** Code (`item_code`, unique org-wide), Name, Unit, Minimum Stock, Reorder Level, Default Purchase Rate, GST rate.
- **Finished Products:** Code, Name, Unit, Cost Price, Dealer Selling Price, Customer Selling Price, Minimum Stock, GST rate.
- **Vendors:** Name, Contact Person, Mobile, Email, GST Number, PAN, Address, Payment Terms, Credit Limit. Soft-deletable only with mandatory reason (`delete_reason`).
- **Customers, Dealers, Architects:** Stakeholder profiles linked to sales and commission calculations.

#### 2. Stock Management & Ledger (Core Heart of System)
- **The Append-Only Ledger (`stock_transactions`):** 
  - Every physical stock change is an immutable insert into `stock_transactions`.
  - Stored fields: `stock_location_id`, `item_type`, `item_id`, `transaction_type`, `quantity_in`, `quantity_out`, `reference_type`, `reference_id`, `reference_number`, `reason`, `occurred_at`, `performed_by`.
  - **No UPDATE, no DELETE:** Enforced at the database level via PostgreSQL triggers (`forbid_ledger_mutation()`).
  - Exactly **8 Transaction Types:** `PURCHASE`, `PRODUCTION_CONSUMPTION`, `PRODUCTION_OUTPUT`, `SALE`, `SALE_RETURN`, `PURCHASE_RETURN`, `DAMAGE`, `ADJUSTMENT`.
  - **No `TRANSFER` transaction type:** Inter-location stock transfer is explicitly out of scope (Q-19 closed).
- **Stock Balance Cache (`stock_balances`):**
  - Cached balances for fast lookup: `(stock_location_id, item_type, item_id) → quantity`.
  - Maintained atomically within the same database transaction using `SELECT ... FOR UPDATE`.
  - 100% reconstructible from `SUM(quantity_in) - SUM(quantity_out)` over the ledger.

#### 3. Purchase Management
- **Purchase Workflow:** Draft → Confirmed.
- **Draft Purchases:** Affect neither inventory nor vendor outstanding; can be edited or deleted.
- **Purchase Confirmation:** Atomic transaction performing:
  1. Status change to `CONFIRMED`.
  2. Inserts `PURCHASE` stock transaction for each line item (increasing Raw Material stock).
  3. Updates `stock_balances` cache.
  4. Increases vendor outstanding balance.
  5. Writes immutable audit log record.
- **Calculation Chain (ADR-015):**
  $$\text{Gross Amount} \longrightarrow \text{Discount} \longrightarrow \text{Taxable Amount} \longrightarrow \text{GST} \longrightarrow \text{Round Off} \longrightarrow \text{Grand Total}$$
  - **Discount is applied BEFORE GST:** $\text{Taxable Amount} = \text{Gross Amount} - \text{Discount}$.
  - **GST Determination:** Evaluated dynamically based on the place of supply. Single registered state is Gujarat:
    - Intra-state (Gujarat): CGST + SGST apply (IGST = 0).
    - Inter-state (Outside Gujarat): IGST applies (CGST = SGST = 0).
  - **Round-Off (ADR-015 §3):** An **entered, signed adjustment amount** applied after GST to reach a negotiated total (e.g., invoice total ₹1,00,093.50 with entered round-off −₹93.50 yields payable total ₹1,00,000.00). **Never compute round-off using an automatic rounding algorithm.**

#### 4. Manufacturing / Production (Phase 2 - Blocked)
- Finished goods production converts raw materials into finished products.
- Checks raw material availability → posts `PRODUCTION_CONSUMPTION` (RM stock OUT) → posts `PRODUCTION_OUTPUT` (FP stock IN).
- Production Costing: $\text{Raw Material Cost} + \text{Labour Cost} + \text{Other Expenses}$.

#### 5. Sales & Commission (Phases 3 & 4 - Blocked)
- Invoicing to Customers or Dealers.
- Linking Architects and Dealers for Project-Based or Yearly Purchase-Based commission tracking.
- Commission states: Generated → Admin Approved → Paid.

---

## 5. Roles, Permissions & Security

### 5.1 Authentication (ADR-003)
- Custom authentication service owned by NestJS.
- Endpoints: `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout`.
- Tokens: Short-lived access JWTs (15 min) + persistent, rotating, revocable refresh tokens stored in database.
- Credential security: Argon2id password hashing, timing-attack-safe comparison, rate-limiting on login.

### 5.2 Configurable RBAC (ADR-004)
- **No hard-coded or default system roles:** The client organization configures its own roles (e.g., "Plant Supervisor", "Accountant", "Store Manager") by assigning granular permissions.
- Permissions follow format: `<module>.<action>` (`vendor.create`, `vendor.view`, `purchase.approve`, `stock.adjust`, `role.assign`).
- Code guards enforce permissions: `@RequirePermission('purchase.create')`.
- Lockout prevention: Safeguard prevents removing admin privileges if no other user possesses user/role management rights.

### 5.3 Request Context & Scope Enforcement
Every incoming request runs through authentication and authorization guards to build a trusted `RequestContext`:
```typescript
export interface RequestContext {
  readonly userId: string;
  readonly branchIds: readonly string[];
  readonly stockLocationIds: readonly string[];
  readonly permissions: ReadonlySet<string>;
  readonly correlationId: string;
}
```
**Access Control Evaluation Order:**
1. Valid JWT? → If not, `401 UNAUTHENTICATED`.
2. Holds required permission? → If not, `403 PERMISSION_DENIED`.
3. Resource exists? → If not, `404 NOT_FOUND`.
4. Resource within caller's assigned branch / stock-location scope? → If not, `403 OUT_OF_SCOPE`.

*(Note: Under single-client architecture, forbidden access to an existing resource returns `403`, not `404`).*

---

## 6. Authoritative Decisions & Evidence

The project decisions are solidified across **15 Architectural Decision Records (ADRs)** and validated against real client artefacts:

| Decision Area | Status | Authoritative Rule & Source |
|---|---|---|
| **Multi-Tenancy vs Dedicated** | Closed | **ADR-014:** Multi-tenancy withdrawn. Dedicated single-client deployment. No tenant columns. |
| **Legal Entity** | Closed | **Q-22 / Client Confirmed:** Exactly **one legal entity** (Blazon Creative, Gujarat). |
| **Authentication** | Closed | **ADR-003:** Backend owns authentication; Supabase Auth is excluded for vendor portability. |
| **Authorization** | Closed | **ADR-004:** Customer-defined roles; granular permissions; no fixed role assumptions. |
| **Stock Ledger** | Closed | **ADR-005:** Append-only ledger; balances cached & derived; corrections are new transactions. |
| **Stock Scoping** | Closed | **ADR-013:** Branches/warehouses optional; stock anchored to `stock_location_id`. |
| **Tax & Discount** | Closed | **ADR-015:** Discount before GST; intra-state CGST/SGST vs inter-state IGST by place of supply. |
| **Round-Off** | Closed | **ADR-015 §3 & Invoice 046:** Round-off is a separate, **entered**, signed amount (not auto-paise rounding). |
| **Unit Master** | Closed | **Q-15:** Dedicated Unit Master; 1 unit per item; **no unit conversions**. |
| **Stock Transfer** | Closed | **Q-19:** Inter-location stock transfer is **not in scope**. Exactly 8 transaction types. |
| **Prototype Disposition** | Closed | **ADR-010:** Retain existing Flutter prototype (~11.7k lines) as reference/design system; new work follows ADR-008. |
| **Money & Quantity** | Closed | **ADR-011:** High-precision decimals (`numeric(18,2)` money, `numeric(18,4)` qty); strings in JSON. |
| **Soft Delete & Audit** | Closed | **ADR-012:** Soft delete with reason (`delete_reason`); immutable audit trail for all business changes. |

---

## 7. Existing Codebase Analysis & Current Layout

### 7.1 Repository Structure
```
ERP/
├── .git/
├── Client Doc/                      # Authoritative evidence (PDF sample invoice + final decisions)
│   ├── 046 Hotel Winsome, Ahmedabad.pdf
│   └── FINAL_BUSINESS_DECISIONS.md
├── docs/                            # Full architecture, business specs, ADRs, module designs
│   ├── architecture/
│   ├── business/
│   ├── decisions/
│   ├── modules/stock-management/
│   └── PROJECT_CONTEXT.md           # This comprehensive document
├── frontend/                        # Retained Flutter App (~11,700 lines of Dart)
│   ├── lib/
│   │   ├── app/                     # App shell, routing, theme tokens, constants
│   │   ├── core/                    # Widgets (ErpButton, ErpDataTable), models, formatters
│   │   ├── features/                # 12 feature folders (auth, inventory, purchase, etc.)
│   │   ├── shared/services/         # mock_database_service.dart (4,316-line in-memory DB)
│   │   └── main.dart
│   ├── pubspec.yaml
│   └── test/
└── *.md                             # Root constitutional rules (PROJECT_RULES.md, ARCHITECTURE.md, etc.)
```

### 7.2 Prototype State vs Target State
- The frontend currently renders UI by directly reading/writing to `MockDatabaseService` (in-memory state with 4,316 lines).
- **Migration Strategy:** The prototype is retained so business users can review screen flows and the design system remains usable. When Phase 1 backend endpoints are ready, Flutter features will be migrated on a ticket-by-ticket basis to the 4-layer Riverpod architecture connecting to `/api/v1`.

---

## 8. Open Questions & Technical Risk Assessment

### 8.1 Critical Questions Status
The key architectural and schema questions have now been fully answered (14 closed, see `docs/business/OPEN_QUESTIONS.md`):

1. **Q-23 — HSN/SAC Code Columns (CLOSED 2026-09-16):**
   - **Decision:** Confirmed. Add nullable `hsn_sac_code` (text) to `raw_materials` and `finished_products` in the Phase 1 schema.
2. **Q-06 — Item Code Reuse After Soft Deletion (CLOSED 2026-09-16):**
   - **Decision:** Confirmed. Item codes **can be reused** after soft deletion. Unique constraint is enforced via a partial index: `CREATE UNIQUE INDEX uq_raw_materials__item_code ON raw_materials (item_code) WHERE is_deleted = false;`.
3. **Q-07 & Q-08 — Document Numbering & Sequence (CLOSED 2026-09-16):**
   - **Decision:** Confirmed. Use prefixed format for clear identification (e.g. `PUR-2026-0046`, `INV-2026-0046`). Continuous sequence running across financial years — **no yearly reset**.
4. **Q-13 — Credit Limit Enforcement (CLOSED 2026-09-16):**
   - **Decision:** Confirmed. When a credit limit is exceeded, the system will **issue a warning** (rather than hard-blocking).
5. **Q-24 — Consignee (Ship-to) vs Buyer (Bill-to) for GST (PENDING):**
   - *Status:* Pending business confirmation. When consignee and buyer states differ, determines which state drives place of supply for CGST/SGST vs IGST.

### 8.2 Technical Debt & Architectural Risks
- **Prototype Leakage Risk:** Developers inadvertently copying `double` for money calculations or client-side document counter patterns from `MockDatabaseService`. *Mitigation:* Explicit rule enforcement and linting.
- **Ledger Concurrency:** Concurrent purchases or sales modifying stock balances. *Mitigation:* Mandatory row-locking (`SELECT ... FOR UPDATE`) on `stock_balances` inside the ledger transaction.
- **Round-off Misunderstanding:** An engineer attempting to auto-compute round-off using `Math.round()` instead of storing the entered amount from the bill. *Mitigation:* Extensive test suite validating negative manual round-offs.

---

## 9. Rules for All Future Tasks

Every future implementation must adhere to these governing rules:
1. **Read before writing:** Verify existing database schema, DTOs, and architecture before proposing changes.
2. **Test-First (TDD):** Write failing integration/unit tests first, record the RED run, then implement code to turn tests GREEN.
3. **Ledger Integrity:** Never write or update stock without creating an immutable entry in `stock_transactions`.
4. **No Premature Phases:** Do not implement Phase 2–5 tables or endpoints during Phase 0/1.
5. **Preserve Domain Terminology:** Use exact terms: *Vendor*, *Dealer*, *Architect*, *Raw Material*, *Finished Product*, *Stock Transaction*. Never substitute synonyms.
6. **Decimal End-to-End:** Currency and stock quantities are never floats.
