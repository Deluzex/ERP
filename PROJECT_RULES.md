# PROJECT_RULES.md — The Constitution of this Project

**Status:** Active · **Applies to:** every human developer and every AI tool (Claude, Cursor, Codex, ChatGPT)

**Authority.** This file is the top-level rule set. Where documents disagree, the order of authority is:

1. `PROJECT_RULES.md` (this file)
2. `docs/ERP PROJECT — MASTER INSTRUCTIONS.md` (the project charter)
3. `docs/business/STOCK_MANAGEMENT_SOURCE_DOCUMENT.md` (business source of truth for Stock scope)
   and `Client Doc/` (client-supplied documents — a real client invoice outranks any interpretation of it)
4. `docs/decisions/ADR-*.md` (accepted architectural decisions)
5. The specialised rule files (`ARCHITECTURE.md`, `SECURITY_RULES.md`, `DATABASE_RULES.md`, …)
6. Existing code

> If code contradicts a rule, **the code is wrong** — not the rule. Raise it, do not copy it.

---

## 1. Product Vision

We are building a **production-ready ERP for one specific client**, deployed as a **dedicated instance**
(ADR-014).

> ### ⚠️ Scope change — 2026-08-29
> The earlier **Multi-Tenant SaaS** requirement has been **withdrawn**.
> **Do not implement multi-tenancy**: no tenant isolation architecture, no `company_id` as a mandatory tenant
> discriminator, no multi-tenant RLS policies, no tenant-aware guards or repositories built for SaaS
> isolation, no cross-tenant tests.
>
> Future clients are handled **separately** — understand their requirements, make the required changes, and
> deploy a **separate instance**. Isolation between clients is achieved by **separate deployments with
> separate databases**, which is a stronger boundary than row-level filtering.
>
> **This removes tenant isolation. It does NOT remove access control** — see §5.1.

### Organization hierarchy

**"Company" means the client's own organization / business entity — not a SaaS tenant.**

```
Company                          ← the client's organization
  └── Branch      (OPTIONAL)
        └── Warehouse  (OPTIONAL)
  └── Users
        └── Roles / Permissions  ← customer-defined, granular
              └── ERP Modules
```

**Branch and Warehouse are optional** (ADR-013). The system must serve all three shapes:

```
Scenario A: Company → Stock
Scenario B: Company → Branch → Stock
Scenario C: Company → Branch → Warehouse → Stock
```

Stock is therefore anchored to a **stock location** that resolves to whichever level the client operates at.
**Never design assuming `warehouse_id` is always present.**

The system must be fully responsive/adaptive for **smartphone, tablet, laptop and desktop** — never designed
for a single fixed screen size.

---

## 2. Technology (fixed — changes require an ADR)

| Layer | Technology |
| --- | --- |
| Frontend | Flutter + Dart |
| Backend | Node.js + TypeScript + NestJS |
| Database | PostgreSQL hosted on Supabase |

Do not introduce an alternative framework, ORM, state manager or architectural pattern per module.
A new library or pattern requires an ADR in `docs/decisions/` **before** the code is written.

---

## 3. Business Source of Truth

`docs/business/STOCK_MANAGEMENT_SOURCE_DOCUMENT.md` is the business source for the Stock Management scope.

You must:

- **Preserve its terminology.** The document says *Vendor*, *Dealer*, *Architect*, *Raw Material*,
  *Finished Product*, *Stock Transaction*. Use exactly these words in code, tables, APIs and UI.
  Do not rename Vendor to Supplier. Do not rename Architect to Consultant.
- **Preserve its business flow.**
- **Preserve its business rules.**

You must **never**:

- Invent a missing business requirement.
- Silently modify a business rule.
- "Simplify" a rule because it is inconvenient to implement.

If a requirement is ambiguous, record it in `docs/business/OPEN_QUESTIONS.md`, stop, and ask.
High-impact business decisions require explicit human approval, recorded as an ADR.

---

## 4. Phase Discipline

Development is strictly phase-wise. **Do not build future-phase features.**

| Phase | Scope | Status |
| --- | --- | --- |
| **Phase 0 — Foundation** | Architecture, AuthN (ours, ADR-003), AuthZ + Role/Permission CRUD (ADR-004), Company/Branch/Warehouse/Stock-Location foundation, DB standards, API standards, security, error handling, logging, audit, testing foundation, Git/Jira workflow, CI/CD, AI rules | **CURRENT** |
| **Phase 1 — Stock Management** | Vendors, Raw Materials, Finished Products, Purchase, Inventory, Stock Transactions (Dashboard = low priority) | Next |
| Phase 2 — Manufacturing | Production, Raw Material Consumption, Finished Product Output, Production Cost | Blocked |
| Phase 3 — Sales & Projects | Customers, Dealers, Architects, Projects, Sales Invoices, Payments | Blocked |
| Phase 4 — Commission | Commission Rules, Project-Based, Yearly Purchase, Approval, Payment | Blocked |
| Phase 5 — Final Features | Reports, Analytics, Advanced permissions, Settings, Notifications, PDF/Excel export | Blocked |

**"Blocked" means: no backend code, no database tables, no APIs.**

Designing the *database and API so that future phases fit* is required and encouraged.
*Implementing* them is forbidden. The distinction:

- ✅ Allowed: `stock_transactions.transaction_type` includes `PRODUCTION_CONSUMPTION` in the enum, because
  the ledger design must be stable and the source document defines all eight types.
- ❌ Forbidden: building a `POST /production-orders` endpoint during Phase 1.

> **Existing Flutter implementation.** The repository already contains screens across all phases, built on an
> in-memory `MockDatabaseService`. Per **ADR-010** it is **retained** as existing project work and reference —
> **not deleted and not frozen**. But do not assume it follows the approved architecture: **new development
> must follow these rules**, and existing functionality is not rewritten unless a specific Jira task requires
> it. Where it contradicts the business source document, the source document wins.

### 4.1 Phase governs implementation, not clarification

**Approved 2026-08-29 (CTO):**

> Do not postpone business clarification simply because a feature belongs to a later development phase.
> Business requirements should be clarified and documented **now**, even if their implementation happens in a
> future phase.
>
> **Phase determines WHEN a feature is implemented.**
> **Phase does NOT determine WHEN its business rules are clarified.**

In practice: a Phase 4 commission rule that affects the Phase 1 schema must be answered **before** the schema
is written. Questions in `docs/business/OPEN_QUESTIONS.md` are prioritised by **impact on design**, not by
phase. "That's Phase 3, we'll ask later" is not an acceptable reason to leave a question open.

---

## 5. Non-Negotiable Engineering Rules

### 5.1 Authorization and resource-level access control
Every protected operation must verify, in this order:

1. **Authentication** — who is the caller? → `401` if unknown
2. **Authorization** — does the caller hold the required permission? → `403` if not
3. **Resource access** — may this user act on **this** resource? → `403` if not
4. **Branch scope** — is the branch within the user's scope? → `403` if not (where branches exist)
5. **Stock location scope** — is the location within the user's scope? → `403` if not

**Authentication does NOT mean authorization.** A valid token proves identity and nothing else.

**Never trust `branch_id`, `stock_location_id`, `user_id`, `role` or any permission claim supplied by the
client.** Scope and permissions are derived from the verified access token on the server, always. A client
may *request* a branch or location; the server **validates it against the caller's scope** before use.

See `SECURITY_RULES.md` and `docs/architecture/ORGANIZATION_AND_SCOPE.md`.

> Under the withdrawn SaaS scope this section was "tenant isolation" and required a `404` for another
> tenant's resource. That is superseded: within one organization a user may legitimately know a record
> exists while being denied access, so **`403` is now correct** and `404` means genuinely not found.

### 5.2 Stock is a ledger
Current stock must **NOT** be the only source of truth. Every stock movement is an immutable
**stock transaction**. Never delete or mutate historical stock movements to simplify an implementation.
Corrections are made by posting a compensating transaction. See **ADR-005**.

### 5.3 Business logic placement
Business logic lives in the backend **Domain / Use-Case** layer. It must **not** live in:

- Flutter widgets or providers,
- NestJS controllers,
- database triggers used as a hiding place for rules,
- or duplicated across frontend and backend.

Frontend validation is a **usability** feature. Backend validation is the **security** feature.
Never trust frontend validation alone.

### 5.4 Money and quantity
Never use floating-point (`float`, `double`, JavaScript `number`) for money or stock quantity. See **ADR-011**.

### 5.5 Test-first backend
Every new API, use case or business rule follows the mandatory TDD cycle in `TESTING_RULES.md`:
**RED → IMPLEMENT → GREEN → REFACTOR → REGRESSION.** Tests are written *before* implementation, and the
RED run must actually be observed. Never weaken or delete a test to make a suite pass.

### 5.6 Auditability
ERP transactions must be auditable: who, what, when, which company, which reference, and the reason where
required. Do not physically delete financial or inventory history.
See `docs/architecture/LOGGING_AND_AUDIT.md`.

---

## 6. Decision Priority

When evaluating **any** technical approach, prioritise in this exact order:

```
Business Correctness
  → Security
    → Data Integrity
      → Maintainability
        → Scalability
          → Performance
            → Developer Convenience
```

If an approach is faster to build but weakens authorization or stock accuracy, it is the wrong approach.
Developer convenience is last — but it is on the list. Do not over-engineer a simple CRUD screen; do not
under-engineer anything touching security, money, inventory or tenancy.

---

## 7. Definition of Done

A feature is **not** Done because the UI works. Done requires **all** of:

- [ ] Requirement understood and traced to the business source document or a Jira ticket
- [ ] Correct architecture followed (no shortcut layers)
- [ ] Tests written **before** implementation
- [ ] Initial **RED** test execution observed and reported
- [ ] Implementation completed
- [ ] **GREEN** — all required tests pass
- [ ] Refactoring completed where needed, tests still green
- [ ] Regression suite for the affected module passes
- [ ] Validation implemented (backend DTO validation, not just UI)
- [ ] Authorization checked (permission + resource access + branch / stock-location scope)
- [ ] Access-control failure paths explicitly tested (401 unauthenticated, 403 unauthorized, 403 out-of-scope)
- [ ] Database integrity checked (FKs, unique constraints, transaction/rollback behaviour)
- [ ] Documentation updated (module docs, API spec, ADR if a decision was made)
- [ ] Code reviewed
- [ ] QA completed where applicable
- [ ] No known critical issue remains

---

## 8. Guidance for Freshers

The team is mainly freshers. That changes *how much we explain*, never *what standard we hold*.

When a task is explained or reviewed, cover all eight points:

1. **What** are we building?
2. **Why** is it needed (which business rule)?
3. **Where** does it belong (which layer, which module)?
4. **How** does the architecture handle it?
5. What are the **business rules**?
6. What are the **edge cases**?
7. What **tests** are required?
8. What **mistakes** must be avoided?

If you do not understand *why* a rule exists, ask before you code. Asking is cheap. A corrupted stock ledger is not.

---

## 9. Golden Rule

> **Build the ERP as a product, not as a collection of screens.**

Every implementation must fit the complete system:

```
Business → Architecture → Database → API → Security → UI → Testing → Deployment
```

---

## 10. Document Map

| Document | Purpose |
| --- | --- |
| `PROJECT_RULES.md` | This file — top-level constitution |
| `ARCHITECTURE.md` | System, layer and module architecture |
| `AI_CODING_RULES.md` | Governance for Claude / Cursor / Codex / ChatGPT |
| `DEVELOPMENT_WORKFLOW.md` | End-to-end ticket lifecycle including mandatory TDD |
| `DATABASE_RULES.md` | Schema, naming, constraints, transactions, migrations |
| `BACKEND_RULES.md` | NestJS layering, DTOs, errors, transactions |
| `FLUTTER_RULES.md` | Flutter layering, Riverpod, responsive rules |
| `API_CONVENTIONS.md` | REST, envelopes, status codes, pagination, errors |
| `SECURITY_RULES.md` | AuthN, AuthZ, tenancy, secrets, IDOR/BOLA |
| `TESTING_RULES.md` | Mandatory TDD workflow and test quality rules |
| `GIT_WORKFLOW.md` | Branching, commits, PRs, code review, CI gates |
| `docs/` | Business, architecture deep-dives, module docs, ADRs |
| `Client Doc/` | **Client-supplied evidence** — the sample tax invoice and the final business decisions it settles |

> **Superseded documents.** `ADR-002` (multi-tenancy) and `docs/architecture/MULTI_TENANCY.md` are marked
> **SUPERSEDED** by ADR-014 and retained only as historical pointers. Do not implement anything they describe.
