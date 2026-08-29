# Architecture Decision Records (ADRs)

An ADR records **one** significant decision: the context, the options considered, what was decided, why, and
what it costs us. It is written **when the decision is made**, not afterwards.

## Why we do this

Six months from now someone will ask "why is money a string in the API?" Without an ADR the answer is a
guess, and the rule gets "fixed" by someone who does not know what it was protecting against. An ADR turns
tribal knowledge into a reviewable artefact — which matters more, not less, on a team of freshers.

## When an ADR is required

- Choosing or replacing a technology, framework or library
- Any change to the multi-tenancy, authentication or authorization model
- A database strategy decision (data types, partitioning, soft delete, ledger design)
- An API contract convention
- A cross-cutting pattern (error handling, logging, transactions)
- Interpreting an ambiguous business requirement in a way that shapes the data model
- Deviating from any rule in the root governance documents

If you are about to write "we decided to..." in a pull request description, it needs an ADR.

## Format

Copy `ADR-000-template.md`, take the next free number, and fill in every section:

**Context · Problem · Options · Decision · Reason · Consequences**

## Status values

| Status | Meaning |
| --- | --- |
| `Proposed` | Written, under review |
| `Accepted` | Agreed and binding |
| `Rejected` | Considered and declined — kept, so it is not re-proposed |
| `Deprecated` | No longer relevant |
| `Superseded by ADR-NNN` | Replaced |

**ADRs are immutable once Accepted.** To change a decision, write a new ADR that supersedes it and update the
old one's status line. Never edit history.

## Index

| ADR | Title | Status |
| --- | --- | --- |
| [ADR-001](ADR-001-monorepo-structure.md) | Monorepo structure: `apps/frontend` + `apps/backend` | ✅ **Accepted** |
| [ADR-002](ADR-002-multi-tenancy-strategy.md) | ~~Multi-tenancy: shared schema + `company_id` + RLS~~ | ❌ **SUPERSEDED by ADR-014** |
| [ADR-003](ADR-003-authentication-strategy.md) | **Authentication owned by our NestJS backend** (not Supabase Auth) | ✅ **Accepted — revised** |
| [ADR-004](ADR-004-authorization-model.md) | Authorization: RBAC, **configurable roles**, granular permissions, CRUD | ✅ **Accepted — revised** |
| [ADR-005](ADR-005-stock-transaction-ledger.md) | Stock as an append-only ledger | ✅ **Accepted** |
| [ADR-006](ADR-006-database-migrations.md) | Versioned, forward-only SQL migrations | ✅ **Accepted** |
| [ADR-007](ADR-007-api-conventions.md) | REST conventions and response envelope | ✅ **Accepted** |
| [ADR-008](ADR-008-flutter-architecture.md) | Flutter layering with Riverpod | ✅ **Accepted** |
| [ADR-009](ADR-009-testing-strategy.md) | Mandatory TDD for backend work | ✅ **Accepted** |
| [ADR-010](ADR-010-existing-prototype-disposition.md) | **Retain** the existing Flutter implementation; new code follows the approved architecture | ✅ **Accepted — revised** |
| [ADR-011](ADR-011-money-and-quantity-types.md) | Decimal types for money and quantity | ✅ **Accepted** |
| [ADR-012](ADR-012-soft-delete-and-audit.md) | Soft delete, reason capture and audit trail | ✅ **Accepted** |
| [ADR-013](ADR-013-flexible-stock-scope.md) | **Flexible stock scope** — branch and warehouse optional | ✅ **Accepted** |
| [ADR-014](ADR-014-single-client-dedicated-deployment.md) | **Single-client dedicated deployment** — multi-tenancy removed from scope | ✅ **Accepted** |
| [ADR-015](ADR-015-discount-gst-rounding.md) | **Discount before GST; CGST/SGST vs IGST by place of supply; separate round-off** | ✅ **Accepted** (client-confirmed) |

**All ADRs were accepted on 2026-08-29.** ADR-002 was subsequently **superseded** by ADR-014 when the
multi-tenant SaaS requirement was withdrawn. Three others were revised before
acceptance (003, 004, 010) — each carries a revision note explaining what changed and why. ADR-013 was added
in the same round to implement the approved flexible stock scope.

**The database schema is no longer blocked.** ADR-013 settled stock scope and ADR-015 settled the tax and
round-off columns. The remaining gap is
**Q-23** — HSN/SAC codes, discovered from the client sample invoice. Q-05a is **closed**: the sample invoice
is committed at `Client Doc/046 Hotel Winsome, Ahmedabad.pdf`.
