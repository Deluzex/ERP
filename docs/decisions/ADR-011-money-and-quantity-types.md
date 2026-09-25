# ADR-011: Decimal Types for Money and Quantity, End to End

- **Status:** **Accepted** (approved 2026-08-29)
- **Date:** 2026-08-28
- **Deciders:** Database Architect, Backend Architect, Flutter Architect
- **Phase:** 0
- **Related:** `DATABASE_RULES.md` §4, `API_CONVENTIONS.md` §4, ADR-007

## Context

This is an ERP handling purchase amounts, GST, discounts, payments, outstanding balances, production costing
and (in Phase 4) commission slabs. It also handles quantities in `kg`, `sq feet` and `piece` — the units named
in the business source document — two of which are divisible.

The existing Flutter prototype uses Dart `double` for every amount and every quantity.

Binary floating point cannot represent common decimal fractions exactly:

```
0.1 + 0.2 = 0.30000000000000004
```

Three purchase lines of `33.33` sum to `99.99000000000001`. An invoice showing that number, or a stock report
that says `99.9999` KG instead of `100`, destroys user trust in every other figure the system displays — and
in an ERP, trust in the numbers is the entire product.

## Problem

What type represents money and quantity in the database, in the backend, on the wire, and in the client?

## Options

### Option 1 — Floating point (`double precision`, `double`, JSON number) throughout
**Pros:** simplest; no libraries; arithmetic "just works".
**Cons:** silent, accumulating rounding errors; sums and comparisons become unreliable; `a == b` is unsafe;
reconciliation and audits fail in ways that are hard to explain to a customer.

### Option 2 — Integer minor units (store paise as `bigint`)
**Pros:** exact; fast; a common fintech pattern.
**Cons:** every read and write needs scaling, and a forgotten conversion is a factor-of-100 bug; quantities in
`kg`/`sq feet` need a different scale from money; GST percentages and unit rates with four decimals fit
awkwardly; readability of raw data suffers during support work.

### Option 3 — Decimal types end to end (`numeric` in PostgreSQL, a decimal library in code, strings on the wire)
**Pros:** exact decimal arithmetic; no scaling mistakes; natural representation in the database for reporting
and support queries; matches how accountants think.
**Cons:** requires a decimal library on both backend and client; slightly slower arithmetic (irrelevant at our
volumes); developers must not accidentally convert to `double` in the middle of a calculation.

## Decision

We will adopt **Option 3**, applied consistently at every layer:

| Layer | Money | Quantity | Rate / percentage |
| --- | --- | --- | --- |
| PostgreSQL | `numeric(18,2)` | `numeric(18,4)` | `numeric(9,4)` |
| NestJS | a decimal library type | same | same |
| JSON (wire) | **string** — `"1234.50"` | **string** — `"150.0000"` | **string** |
| Flutter | `Decimal`, wrapped in a `Money` value object | `Decimal` | `Decimal` |

**Rules:**
- `float`, `double precision`, `real`, Dart `double` and JavaScript `number` are **forbidden** for money,
  quantity and rates.
- Money and quantity cross the API as **strings**, because a JSON number is parsed as an IEEE 754 double by
  both Dart and JavaScript — the string forces the client into a decimal type.
- Rounding is explicit, at defined points, with a documented rounding mode. Never rely on implicit rounding.
- Totals are computed **server-side**. A client-supplied total is ignored.

## Reason

Business correctness and data integrity are our top two priorities, and there is no version of "correct" that
tolerates `99.99000000000001` on a purchase invoice.

Option 1 is excluded outright. Option 2 is exact but trades one silent failure mode (float drift) for another
(a missed scaling conversion) — and with a fresher team, a factor-of-100 error that reaches production is
worse than a slightly slower arithmetic library. Option 3 keeps the stored value readable and the arithmetic
exact, at a performance cost that is irrelevant at ERP transaction volumes.

Quantities use four decimal places because `kg` and `sq feet` are divisible; `piece` quantities simply carry
trailing zeros.

## Consequences

**Positive:** exact arithmetic; sums reconcile; the ledger-versus-balance invariant (ADR-005) holds exactly;
database values are directly readable during support; no scaling bugs.

**Negative:**
- A decimal dependency on both backend and client (each requires an ADR entry when selected).
- Developers must resist `double.parse()` — a lint rule and review checklist item are required.
- String money in JSON surprises newcomers and must be documented prominently in `API_CONVENTIONS.md`.
- Rounding points must be decided per calculation (line total, tax, invoice total) rather than left implicit.

**Follow-up actions:**
- Select the decimal libraries (backend and Flutter) and record them here when chosen.
- Implement a `Money` value object in `core/common` and in the Flutter domain layer.
- Add a lint rule / review checklist item banning `double` for monetary and quantity fields.
- Document the rounding rules for line total, discount, GST and grand total in
  `docs/modules/stock-management/BUSINESS_RULES.md` — **currently an open question (Q-05)**, since the source
  document does not state them.
- The prototype's `double` fields are **not** carried into production models (ADR-010).
