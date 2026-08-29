# Deluzex ERP

A production-ready ERP covering stock management, manufacturing, sales and commission — built **for one
client**, deployed as a **dedicated instance**.

**Current status: Phase 0 — Foundation.** Feature development has not started.

> ### ⚠️ Scope: single-client, not SaaS (ADR-014)
> The earlier multi-tenant SaaS requirement has been **withdrawn**. **Do not implement multi-tenancy** — no
> tenant isolation, no `company_id` discriminator, no multi-tenant RLS, no cross-tenant tests.
> "Company" means **the client's own organization**, not a SaaS tenant.
> Future clients get their own instance, handled as a separate engagement.
>
> This removed *tenant isolation*. It did **not** remove access control — authentication, granular
> permissions and resource-level authorization remain fully mandatory.

---

## Technology Flow

```
Flutter → REST API → NestJS → Node.js → PostgreSQL → Supabase
```

| Layer | Technology |
| --- | --- |
| Frontend | Flutter + Dart (responsive: phone, tablet, laptop, desktop) |
| Backend | Node.js + TypeScript + NestJS |
| Database | PostgreSQL hosted on Supabase |

The Flutter client talks **only** to our NestJS API — never directly to Supabase for business data, and it
never holds a database credential.

**Authentication is owned by our backend** (ADR-003) — Supabase Auth is not used. Supabase hosts PostgreSQL;
that choice must remain reversible. Full detail: [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## Read This First

Before writing a single line of code:

1. [`PROJECT_RULES.md`](PROJECT_RULES.md) — the constitution
2. [`docs/README.md`](docs/README.md) — the documentation index
3. [`ARCHITECTURE.md`](ARCHITECTURE.md) — technology flow and layering
4. [`TESTING_RULES.md`](TESTING_RULES.md) — the mandatory TDD cycle

Using an AI tool (Claude, Cursor, Codex, ChatGPT)? Read
[`AI_CODING_RULES.md`](AI_CODING_RULES.md) first — it is binding on AI-generated code.

---

## The Rules in One Screen

| Rule | Detail |
| --- | --- |
| **Authentication is not authorization** | Every protected endpoint checks a permission, resource access and scope — all from the verified token |
| **Every stock movement is a stock transaction** | The ledger is append-only; balances are derived; corrections are new transactions |
| **Branch and warehouse are optional** | Stock is anchored to a stock location (ADR-013). Never assume `warehouse_id` |
| **Authentication is ours, not the database provider's** | Backend owns hashing, tokens, validation (ADR-003) |
| **No default roles** | The client defines its own roles from granular permissions (ADR-004) |
| **Discount before GST** | GST applies to the taxable amount; GST type derived per transaction from the place of supply (ADR-015) |
| **Round-off shown separately** | Never folded into item or tax amounts (ADR-015) |
| **Never use floating point for money or quantity** | Decimal end to end |
| **Tests are written before implementation** | And the RED run is recorded in the PR |
| **Business logic lives in the backend domain layer** | Not in widgets, not in controllers |
| **Never invent or silently change a business requirement** | Ambiguity goes to `docs/business/OPEN_QUESTIONS.md` |
| **Phase governs implementation, not clarification** | A later-phase feature's business rules are still clarified now |
| **Build the ERP as a product, not a collection of screens** | Business → Architecture → Database → API → Security → UI → Testing → Deployment |

---

## Development Phases

| Phase | Scope | Status |
| --- | --- | --- |
| **0 — Foundation** | Architecture, auth, RBAC + Role/Permission CRUD, org & stock-scope foundation, DB/API standards, security, audit, testing, CI/CD | **Current** |
| **1 — Stock Management** | Vendors, Raw Materials, Finished Products, Purchase, Inventory, Stock Transactions | Next |
| 2 — Manufacturing | Production, consumption, output, costing | Blocked |
| 3 — Sales & Projects | Customers, Dealers, Architects, Projects, Invoices, Payments | Blocked |
| 4 — Commission | Rules, project-based, yearly purchase, approval, payment | Blocked |
| 5 — Final Features | Reports, analytics, advanced permissions, settings, notifications, export | Blocked |

**Blocked means: no backend code, no tables, no APIs.** See [`PROJECT_RULES.md`](PROJECT_RULES.md) §4.

---

## Client Documents

[`Client Doc/`](Client%20Doc/) holds documents supplied **by the client**, plus the decisions they settle:

- **`046 Hotel Winsome, Ahmedabad.pdf`** — a real tax invoice. It is the **authoritative reference for
  round-off behaviour** (ADR-015 §3) and independently confirmed the intra-state GST rule.
- **`FINAL_BUSINESS_DECISIONS.md`** — the four closing decisions with their design consequences.

These are **evidence**. When a rule cites a client document, the document itself is in the repository so any
developer can open it and check the claim. Do not edit them.

---

## Repository Layout

**Current** — the Flutter app sits at the repository root:

```
ERP/
├── Client Doc/          # client-supplied evidence (sample invoice + final decisions)
├── lib/                 # Flutter app (~11,700 lines) - retained, see ADR-010
├── test/                # one smoke test
├── pubspec.yaml         # declares name: frontend
└── docs/                # documentation
```

**Target** — see [ADR-001](docs/decisions/ADR-001-monorepo-structure.md):

```
ERP/
├── apps/
│   ├── frontend/        # the Flutter app, moved here
│   └── backend/         # NestJS + TypeScript (to be created)
├── Client Doc/          # client-supplied evidence
├── docs/
└── *.md                 # governance documents
```

> **The existing Flutter app is retained** as project work and reference — not deleted, not frozen
> ([ADR-010](docs/decisions/ADR-010-existing-prototype-disposition.md)). It predates the approved
> architecture (it runs on an in-memory mock database, with no authentication or access control), so **do not
> assume it follows the current rules and do not copy its patterns into new code**. Existing functionality is
> not rewritten unless a Jira task requires it. Its design system is promoted and reused.

---

## Running the Existing Flutter App

```bash
flutter pub get
```

```bash
flutter run
```

```bash
flutter analyze
```

```bash
flutter test
```

The backend does not exist yet; it is Phase 0 task 3.

---

## Contributing

Every change follows [`DEVELOPMENT_WORKFLOW.md`](DEVELOPMENT_WORKFLOW.md):

```
Jira → Feature Branch → Tests → RED → Implementation → GREEN → Refactor
     → Regression → PR → Code Review → QA → Merge
```

Branch: `feature/ERP-123-short-description` · Commit: `ERP-123: Add purchase entry API`

See [`GIT_WORKFLOW.md`](GIT_WORKFLOW.md). Never commit directly to `main` or `dev`.

---

## Decisions & Open Questions

**Fifteen ADRs: fourteen Accepted, ADR-002 superseded.** Five business questions were answered:

| Answered | Outcome |
| --- | --- |
| Q-01 — existing Flutter implementation | **Keep it.** Not deleted, not frozen |
| Q-05 / Q-05a — discount, GST, round-off | **Confirmed.** Discount before GST; CGST+SGST within Gujarat, IGST outside; round-off is a separate **entered** amount — proven against the real client invoice (ADR-015) |
| Q-15 — Unit | **Dedicated Unit Master**, one unit per item, **no conversion** |
| Q-19 — Stock transfer | **Not required.** Eight transaction types only — no `TRANSFER` |
| Q-22 — Legal entities | **ONE legal entity.** No `company_id` on documents, masters or unique keys |
| Q-02 — Bill of Material | **Not a blocker.** Proceed without BOM; do not invent BOM functionality |
| Q-03 — Branch / Warehouse | **Both optional** — ADR-013 |
| Q-09 — roles and permissions | **No default role list.** Configurable — ADR-004 |
| *(scope change)* | **Multi-tenancy withdrawn** — single-client dedicated deployment (ADR-014) |

**Nine questions are closed** (Q-01, Q-02, Q-03, Q-05, Q-05a, Q-09, Q-15, Q-19, Q-22) — recorded with their
design consequences in [`Client Doc/FINAL_BUSINESS_DECISIONS.md`](Client%20Doc/FINAL_BUSINESS_DECISIONS.md).

**17 remain open. None blocks the database schema:**

- 🟠 **Q-23 — HSN/SAC codes.** Present on the client sample invoice, absent from the requirements document.
  A GST-compliance field — worth adding to both item masters before the migration.
- 🟠 **Q-24 — Ship-to vs Bill-to.** The sample invoice has separate blocks; if they can differ, which one
  determines the place of supply for GST?

See [`docs/business/OPEN_QUESTIONS.md`](docs/business/OPEN_QUESTIONS.md).
**Nobody — human or AI — may guess an answer to an open question.**

> **Phase determines when a feature is implemented. Phase does not determine when its business rules are
> clarified.** Questions are prioritised by design impact, not by phase.
