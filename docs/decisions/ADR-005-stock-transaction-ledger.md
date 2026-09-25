# ADR-005: Stock Is an Append-Only Transaction Ledger

- **Status:** **Accepted** (approved 2026-08-29)
- **Date:** 2026-08-28
- **Deciders:** Solution Architect, Database Architect, Business Analyst
- **Phase:** 0 (design) / 1 (implementation)
- **Related:** `docs/business/STOCK_MANAGEMENT_SOURCE_DOCUMENT.md` §8 and §21, `DATABASE_RULES.md` §10

## Context

The business source document is unusually explicit (§21, "Important Business Rule"):

> The system should maintain every stock movement as a stock transaction instead of only storing the current
> stock quantity. This is necessary for accurate stock calculation, audit history and reporting.

It defines eight transaction types: `PURCHASE`, `PRODUCTION_CONSUMPTION`, `PRODUCTION_OUTPUT`, `SALE`,
`SALE_RETURN`, `PURCHASE_RETURN`, `DAMAGE`, `ADJUSTMENT`.

The existing prototype's `StockMovement` model stores a `currentBalance` **on every movement row**, which
treats the balance as a stored fact and makes any inserted or corrected historical row silently wrong.

## Problem

Where does the truth about "how much stock do we have" live, and how are corrections made?

## Options

### Option 1 — Store only the current quantity on the item and update it in place
**Pros:** trivial; fastest reads.
**Cons:** directly violates the stated business rule; no audit history; a lost update under concurrency is
undetectable and unrecoverable; "why is this number 47?" becomes unanswerable.

### Option 2 — Append-only ledger; the balance is always computed with `SUM()`
**Pros:** a single source of truth; complete history; every balance is explainable.
**Cons:** balance queries slow as the ledger grows; every list screen showing current stock pays an
aggregation cost.

### Option 3 — Append-only ledger as the source of truth, plus a cached `stock_balances` table
**Pros:** all the integrity of Option 2 with fast reads; the cache is reconstructible and verifiable.
**Cons:** two places to keep consistent; requires row locking and a reconciliation job.

## Decision

We will adopt **Option 3**.

- `stock_transactions` is **append-only**: `INSERT` only, enforced by database privileges and a trigger that
  raises on `UPDATE` or `DELETE`.
- Every row carries company, **stock location** (per ADR-013 — which resolves to company, branch or
  warehouse level according to that company's configuration), item, item type, transaction type, reference
  document (`reference_type`, `reference_id`, `reference_number`), quantity in, quantity out, the timestamp
  and the actor.
- `stock_balances` is a **cache**, maintained in the same transaction using `SELECT … FOR UPDATE`, and fully
  reconstructible from the ledger.
- Ledger rows are written **inside the same database transaction** as the document that caused them.
- **Corrections never rewrite history** — they post a compensating transaction (`ADJUSTMENT`,
  `PURCHASE_RETURN`, `SALE_RETURN`) with a mandatory reason.

Invariant, enforced by test and by a reconciliation job:

```
SUM(quantity_in) - SUM(quantity_out) = stock_balances.quantity    -- per company / stock location / item
```

> **Revision note (2026-08-29).** This ADR originally assumed stock is always warehouse-scoped. **ADR-013**
> supersedes that assumption: branches and warehouses are optional per company, and the ledger references a
> `stock_location_id` instead. Everything else in this ADR — append-only, derived balances, compensating
> corrections — is unchanged and was **approved on 2026-08-29**.

## Reason

The business rule is explicit, and the priority order puts business correctness and data integrity above
performance. Option 1 is excluded by the requirement. Option 2 is correct but degrades on exactly the screens
users look at most (stock lists, low-stock alerts), and an ERP that gets slower the more the customer uses it
is a product problem. Option 3 keeps the ledger authoritative while making the common read fast, at the cost
of machinery we can test.

## Consequences

**Positive:** every balance is explainable down to the unit; a full audit history; concurrency-safe with
proper locking; reporting and stock valuation become straightforward; damage and adjustments are
first-class, visible events.

**Negative:**
- The cache can drift if a code path bypasses the ledger service — hence the reconciliation job and alert.
- Every stock-affecting operation **must** take the balance row lock, or concurrent posts lose updates.
- The ledger grows without bound; partitioning by company or period may be needed later (a future ADR).
- Slightly more code per operation than a naive `UPDATE`.

**Follow-up actions:**
- A `StockLedgerService` as the **only** writer of `stock_transactions` and `stock_balances`.
- A trigger blocking `UPDATE`/`DELETE` on the ledger.
- Integration tests: rollback consistency, concurrent posting, and the ledger-versus-balance invariant.
- A scheduled reconciliation job with a drift alert.
- The prototype's per-row `currentBalance` field is **not** carried into the production model.
