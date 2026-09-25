# ADR-010: Retain the Existing Flutter Implementation; New Development Follows the Approved Architecture

- **Status:** **Accepted** (approved 2026-08-29)
- **Date:** 2026-08-28 · **Revised:** 2026-08-29
- **Deciders:** CTO, Product Owner, Solution Architect
- **Phase:** 0
- **Related:** ADR-001, ADR-002, ADR-008, ADR-011, `PROJECT_RULES.md` §4

> **Revision note (2026-08-29).** The original proposal was to **freeze** the prototype. That was **not
> approved**. The CTO directed that the existing implementation be **retained as existing project work and
> reference**, neither deleted nor frozen. This ADR records the approved position. Open question Q-01 is
> closed.

## Context

The repository contains approximately **11,700 lines of Dart** implementing screens across all phases:

| Area | Screens | Phase |
| --- | --- | --- |
| Auth, Dashboard | 2 | 0/1 |
| Masters (vendors, customers, dealers, architects, categories/units) | 5 | 1 & 3 |
| Inventory (raw material, finished product, movement, adjustment) | 4 | 1 |
| Purchase | 2 | 1 |
| Production | 2 | 2 |
| Sales | 2 | 3 |
| Projects | 1 | 3 |
| Payments | 1 | 3 |
| Reports, Settings | 2 | 5 |

All are backed by `lib/shared/services/mock_database_service.dart`, an in-memory `ChangeNotifier` with seeded
demo data and client-side document counters.

The implementation carries a validated design system (`lib/core/widgets/`, `lib/app/theme/`), a navigation
model, and terminology already reviewed with the client. It also contains patterns that predate the approved
architecture.

## Problem

What is the disposition of the existing implementation, and what rules govern working on it?

## Options

### Option 1 — Delete it and start clean
**Cons:** discards a working design system, a validated navigation model and UX knowledge the client has
already seen. Rejected.

### Option 2 — Freeze it: no changes at all *(originally proposed, not approved)*
**Cons:** treats existing project work as untouchable, which blocks legitimate maintenance and creates an
awkward two-codebases situation; overly rigid for a team that must keep delivering.

### Option 3 — Retain it as existing project work; hold **new** development to the approved architecture
**Pros:** preserves the investment and the design system; allows normal maintenance; concentrates the
architectural standard where it matters — on new code — rather than demanding a big-bang rewrite.
**Cons:** the repository temporarily contains two standards, so a developer must know which rules apply to
what they are touching.

## Decision

We will adopt **Option 3**.

1. **The existing Flutter implementation stays in the repository** as existing project work and reference.
   It is **not** deleted and **not** frozen.
2. **New development must follow the approved architecture** — the layering in ADR-008, decimal types
   (ADR-011), tenant-scoped API access (ADR-002), and backend-owned authentication (ADR-003).
3. **Do not assume existing prototype code follows the new architecture.** Before reusing or extending a
   prototype file, check it against the current rules rather than copying its patterns forward.
4. **Do not rewrite unrelated existing functionality** unless a specific Jira task requires it. Opportunistic
   refactoring of working screens is out of scope.
5. Where prototype behaviour contradicts the business source document, **the source document wins** — report
   the contradiction rather than silently following either.
6. The design system (`lib/core/widgets/`, `lib/app/theme/`) is **promoted** as the project's design system
   and is reused by new development.

### What this does and does not permit

| Action | Permitted? |
| --- | --- |
| Leave existing screens in place and running | ✅ Yes |
| Fix a bug in an existing screen under a Jira ticket | ✅ Yes |
| Reuse `ErpButton`, `ErpDataTable`, theme tokens in new code | ✅ Yes — encouraged |
| Build a **new** feature in the prototype's two-layer style | ❌ No — new code follows ADR-008 |
| Add new business logic to `MockDatabaseService` | ❌ No — new features use the real API |
| Copy `double` money handling into new code | ❌ No — ADR-011 |
| Rewrite a working screen because its style is old | ❌ No — needs a Jira task |
| Ship a blocked-phase feature because its screen exists | ❌ No — phase discipline still applies |

### Patterns that must not propagate into new code

| Prototype pattern | Why | Governing decision |
| --- | --- | --- |
| No `companyId` on any model | No tenant boundary | ADR-002 |
| `UserModel.role` as a display `String` | Not an authorization model | ADR-004 |
| `double` for money and quantity | Float rounding on money | ADR-011 |
| `StockMovement.currentBalance` stored per row | Balance treated as a stored fact | ADR-005 |
| Screens reading the data service directly | Two layers where four are required | ADR-008 |
| Client-generated document numbers | Not concurrency-safe, not per-company | `DATABASE_RULES.md` §13 |

These are listed as **guidance for new work**, not as defects to be fixed on sight. Fixing them happens when
a Jira task brings that area into scope.

## Reason

The existing implementation is real project work with real value: a design system, a navigation model, and a
UX the client recognises. Deleting it wastes that; freezing it makes ordinary maintenance awkward and treats
the team's output as a liability.

The actual risk was never the existence of the prototype — it was **prototype patterns silently becoming the
standard for new code**. Option 3 addresses that risk directly, by placing the constraint on new development
rather than on the existing files, and it does so without a disruptive rewrite.

## Consequences

**Positive:** existing work is preserved and remains useful; the design system is reused rather than
recreated; maintenance is unblocked; the architectural standard applies where it has leverage — new code.

**Negative / accepted costs:**
- The repository contains two architectural standards for a period. Developers — especially freshers — must
  know which applies. **Mitigation:** `FLUTTER_RULES.md` states the rule plainly, and code review checks that
  new files follow ADR-008.
- Prototype screens for blocked-phase features exist and may lead a stakeholder to believe those features are
  near-complete. **Mitigation:** phase status is stated in `README.md` and `PROJECT_RULES.md`; demo builds
  should be labelled as demonstrations, not releases.
- The mock data layer remains until features are migrated to the real API, so some screens show seeded demo
  data rather than real data.

**Follow-up actions:**
- `FLUTTER_RULES.md` states the "new code follows ADR-008; existing code is retained" rule.
- Migrate features to the real API as their backend endpoints land, driven by Jira tickets — not
  speculatively.
- Vendors serves as the reference migration: backend API + Flutter four-layer implementation + tests, as the
  worked example other features copy.
