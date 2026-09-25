# Documentation Index

Everything a developer needs, in the order they need it.

---

## Start Here (first day, in this order)

1. **`../PROJECT_RULES.md`** — the constitution. Read it fully before writing any code.
2. **`ERP PROJECT — MASTER INSTRUCTIONS.md`** — the project charter from the client/CTO.
3. **`../ARCHITECTURE.md`** — the technology flow and layering.
4. **`business/GLOSSARY.md`** — the words we use, and the words we never use.
5. **`../DEVELOPMENT_WORKFLOW.md`** — how a ticket becomes merged code.
6. **`../TESTING_RULES.md`** — the mandatory TDD cycle.

---

## Root Governance Documents

| Document | Read when |
| --- | --- |
| [`PROJECT_RULES.md`](../PROJECT_RULES.md) | Always — top-level authority |
| [`ARCHITECTURE.md`](../ARCHITECTURE.md) | Before writing any feature |
| [`AI_CODING_RULES.md`](../AI_CODING_RULES.md) | Before using Claude / Cursor / Codex / ChatGPT |
| [`DEVELOPMENT_WORKFLOW.md`](../DEVELOPMENT_WORKFLOW.md) | Starting a ticket |
| [`DATABASE_RULES.md`](../DATABASE_RULES.md) | Touching the schema |
| [`BACKEND_RULES.md`](../BACKEND_RULES.md) | Writing NestJS code |
| [`FLUTTER_RULES.md`](../FLUTTER_RULES.md) | Writing Dart code |
| [`API_CONVENTIONS.md`](../API_CONVENTIONS.md) | Designing an endpoint |
| [`SECURITY_RULES.md`](../SECURITY_RULES.md) | Always — especially anything protected |
| [`TESTING_RULES.md`](../TESTING_RULES.md) | Before writing any test — i.e. before any code |
| [`GIT_WORKFLOW.md`](../GIT_WORKFLOW.md) | Branching, committing, opening a PR |

---

## `Client Doc/` — Client-supplied evidence

| Document | Purpose |
| --- | --- |
| [`FINAL_BUSINESS_DECISIONS.md`](../Client%20Doc/FINAL_BUSINESS_DECISIONS.md) | Four client-confirmed decisions (Q-22, Q-05a, Q-19, Q-15) and their design consequences |
| `046 Hotel Winsome, Ahmedabad.pdf` | Real tax invoice — **the authoritative reference for round-off** (ADR-015 §3) |

---

## `business/` — What the product must do

| Document | Purpose |
| --- | --- |
| [`STOCK_MANAGEMENT_SOURCE_DOCUMENT.md`](business/STOCK_MANAGEMENT_SOURCE_DOCUMENT.md) | **The business source of truth**, transcribed from the client PDF |
| [`GLOSSARY.md`](business/GLOSSARY.md) | Canonical terminology — Vendor, Dealer, Architect, Stock Transaction, Round Off … |
| [`OPEN_QUESTIONS.md`](business/OPEN_QUESTIONS.md) | **17 open, 9 answered.** Nobody may guess an answer |

> ✅ **Nine closed:** Q-01, Q-02, Q-03, Q-05, **Q-05a**, Q-09, **Q-15**, **Q-19**, **Q-22**. Do not re-ask
> them — see `Client Doc/FINAL_BUSINESS_DECISIONS.md`.
> ⚠️ **Nothing blocks the schema.** The one item worth settling before the migration is **Q-23** (HSN/SAC —
> a GST-compliance field found on the client sample invoice, absent from the requirements document).
>
> **Governing rule:** phase determines when a feature is *implemented*, **not** when its business rules are
> *clarified*. Questions are prioritised by design impact, not by phase.

---

## `architecture/` — How the system is built

| Document | Purpose |
| --- | --- |
| [`ORGANIZATION_AND_SCOPE.md`](architecture/ORGANIZATION_AND_SCOPE.md) | Organization hierarchy, flexible stock scope, access control (replaces `MULTI_TENANCY.md`) |
| [`AUTHENTICATION_AUTHORIZATION.md`](architecture/AUTHENTICATION_AUTHORIZATION.md) | AuthN vs AuthZ vs scoping; the RBAC model |
| [`ERROR_HANDLING.md`](architecture/ERROR_HANDLING.md) | Domain errors → HTTP → user messages |
| [`LOGGING_AND_AUDIT.md`](architecture/LOGGING_AND_AUDIT.md) | Logging vs audit trail; what must be recorded |
| [`REPOSITORY_STRUCTURE.md`](architecture/REPOSITORY_STRUCTURE.md) | Current vs target layout, and the migration |

---

## `modules/stock-management/` — Phase 1 feature documentation

| Document | Purpose |
| --- | --- |
| [`REQUIREMENTS.md`](modules/stock-management/REQUIREMENTS.md) | Scope, fields, acceptance criteria, traceability |
| [`BUSINESS_RULES.md`](modules/stock-management/BUSINESS_RULES.md) | Numbered rules (`BR-*`) to cite in code and tests |
| [`DATABASE_DESIGN.md`](modules/stock-management/DATABASE_DESIGN.md) | Tables, constraints, the append-only ledger |
| [`API_SPECIFICATION.md`](modules/stock-management/API_SPECIFICATION.md) | Endpoints, DTOs, errors, side effects |
| [`UI_FLOW.md`](modules/stock-management/UI_FLOW.md) | Screens, flows, states, responsive behaviour |
| [`TEST_CASES.md`](modules/stock-management/TEST_CASES.md) | Scenarios to write **before** implementation |

---

## `decisions/` — Why the system is built that way

[ADR index](decisions/README.md) · [template](decisions/ADR-000-template.md)

**Fifteen ADRs. Fourteen Accepted; ADR-002 superseded** (2026-08-29).

| ADR | Decision |
| --- | --- |
| [001](decisions/ADR-001-monorepo-structure.md) | Monorepo: `apps/frontend` + `apps/backend` |
| [002](decisions/ADR-002-multi-tenancy-strategy.md) | ~~Multi-tenancy~~ — ❌ **SUPERSEDED by ADR-014** |
| [003](decisions/ADR-003-authentication-strategy.md) | **Authentication owned by our NestJS backend** — not Supabase Auth, for portability |
| [004](decisions/ADR-004-authorization-model.md) | RBAC with **customer-configurable roles**, granular permissions, full CRUD |
| [005](decisions/ADR-005-stock-transaction-ledger.md) | Stock is an append-only ledger |
| [006](decisions/ADR-006-database-migrations.md) | Hand-written, forward-only SQL migrations |
| [007](decisions/ADR-007-api-conventions.md) | REST + `{data, meta}` envelope; money as strings |
| [008](decisions/ADR-008-flutter-architecture.md) | Riverpod + four-layer feature structure |
| [009](decisions/ADR-009-testing-strategy.md) | Mandatory TDD with recorded RED evidence |
| [010](decisions/ADR-010-existing-prototype-disposition.md) | **Retain** the existing Flutter implementation; new code follows the approved architecture |
| [011](decisions/ADR-011-money-and-quantity-types.md) | Decimal types end to end; never floating point |
| [012](decisions/ADR-012-soft-delete-and-audit.md) | Soft delete with reason + separate audit trail |
| [013](decisions/ADR-013-flexible-stock-scope.md) | **Branch and warehouse optional** — stock anchored to a stock location |
| [014](decisions/ADR-014-single-client-dedicated-deployment.md) | **Single-client dedicated deployment** — multi-tenancy removed from scope |
| [015](decisions/ADR-015-discount-gst-rounding.md) | **Discount before GST**; CGST/SGST vs IGST by place of supply; separate round-off |

---

## Quick Answers

| Question | Answer |
| --- | --- |
| What phase are we in? | **Phase 0 — Foundation.** No feature development yet |
| Where do I put business logic? | Backend Domain/Use-Case layer — never in a widget or a controller |
| Is this multi-tenant? | **No** (ADR-014). One client, one dedicated deployment. `company_id` is organizational, not a tenant key |
| Is GST calculated before or after discount? | **After discount** — GST applies to the taxable amount (ADR-015) |
| CGST+SGST or IGST? | Determined **per transaction** from the place of supply. Within Gujarat → CGST+SGST; outside → IGST. Never hardcoded |
| Can I use `double` for money? | **No.** ADR-011 |
| Can I delete a stock transaction? | **No.** ADR-005 — the ledger is append-only |
| Do I write tests first? | **Yes**, and you must show the RED run in the PR |
| The requirement is unclear — what do I do? | Add it to `business/OPEN_QUESTIONS.md` and ask. **Never guess** |
| Can I add a package? | Only with an ADR |
| Can I work on the Sales screens? | No — Phase 3 is blocked for *implementation*. Its business rules may still be clarified now |
| Is `warehouse_id` always required on stock? | **No.** Branch and warehouse are optional; stock uses `stock_location_id` (ADR-013) |
| Do we use Supabase Auth? | **No.** Authentication is ours (ADR-003). Supabase hosts PostgreSQL, nothing more |
| Which default roles ship? | **None.** Roles are created by the client organization (ADR-004) |
| How is round-off calculated? | **It is not calculated — it is entered.** A signed amount applied after GST. See the client invoice in `Client Doc/` (ADR-015 §3) |
| Can stock move between locations? | **No.** Transfer is out of scope; there is no `TRANSFER` type (Q-19) |
| Do items have unit conversion? | **No.** One unit per item from the Unit Master (Q-15) |
| Do I write a cross-tenant 404 test? | **No.** Not multi-tenant. Write resource-level authorization tests returning **403** |
| Can I extend the existing Flutter screens? | They are retained, not frozen — but **new** work follows ADR-008, and you do not rewrite existing screens without a Jira task (ADR-010) |
