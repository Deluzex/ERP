# ADR-013: Flexible Stock Scope via a Stock Location Abstraction

- **Status:** **Accepted** (approved 2026-08-29)
- **Date:** 2026-08-29
- **Deciders:** CTO, Solution Architect, Database Architect
- **Phase:** 0
- **Related:** ADR-005, ADR-012, **ADR-014**, `docs/architecture/ORGANIZATION_AND_SCOPE.md`,
  `docs/modules/stock-management/DATABASE_DESIGN.md`
- **Supersedes:** the assumption in ADR-005 and the original `DATABASE_DESIGN.md` that
  `warehouse_id` is always mandatory on stock records. Closes the structural half of open question **Q-03**.

> **Revision note (2026-08-29, ADR-014).** The SaaS scope was withdrawn after this ADR was accepted.
> **The decision is unaffected and remains in force** — the reasoning below was never about tenancy. It is
> about keeping the ledger key `NOT NULL` across three organizational shapes, which matters just as much for
> a single client. §6 has been rewritten: "Company" is now an organizational entity, not a tenant.

## Context

The ERP must serve companies with **different organisational structures**. The CTO confirmed three shapes,
all of which must be supported:

```
Company → Stock                        (small company, one implicit location)
Company → Branch → Stock               (branches, no separate warehouses)
Company → Branch → Warehouse → Stock   (full hierarchy)
```

Therefore **Branch is not mandatory** for every company, and **Warehouse is not mandatory** for every company.
The database must not be designed assuming `warehouse_id` is always present.

At the same time, ADR-005 (append-only ledger with a reconstructible balance) remains binding. Whatever we do
must not weaken it.

The business source document itself describes only a single implicit stock location — it never mentions
branches or warehouses. The hierarchy comes from the client organizational structure.

## Problem

How do we model stock location so that a company may keep stock at company, branch **or** warehouse level,
without making the ledger identity columns nullable?

## Options

### Option 1 — Nullable `branch_id` and `warehouse_id` on stock tables
Stock rows carry both columns; a company-level company leaves both `NULL`.

**Pros:** conceptually direct; no new table.
**Cons:** **the balance key breaks.** `stock_balances` needs a unique key over
`(branch_id, warehouse_id, item_id)`, and in PostgreSQL `NULL` is not equal to `NULL`, so a
standard unique constraint does **not** deduplicate rows where those columns are null — the same
company-level item could acquire multiple balance rows. `NULLS NOT DISTINCT` (PG 15+) mitigates this but
makes the constraint subtle. Every query acquires `IS NULL` branches; every join becomes conditional;
composite foreign keys to a nullable column are awkward. This is the design that looks simplest and produces
the most defects.

### Option 2 — Sentinel rows (a synthetic "default branch" and "default warehouse" for every company)
**Pros:** keeps columns `NOT NULL`; uniform queries.
**Cons:** every company-level customer sees fabricated "Main Branch / Main Warehouse" entities they never
asked for, in pickers and reports; the UI must then hide them conditionally, which is the same complexity
moved somewhere less testable; the data model lies about the customer's structure.

### Option 3 — A **stock location** abstraction: stock always belongs to a `stock_location`, whose *level* varies
Every company has one or more `stock_locations`. A stock location is anchored at exactly one level —
`COMPANY`, `BRANCH` or `WAREHOUSE` — according to that company's configuration.

**Pros:** the ledger and balance always reference a single `NOT NULL` identifier, so keys, constraints,
composite FKs and queries stay uniform and simple; the organizational structure is represented honestly;
the organization can move up the hierarchy
later by adding locations rather than by a schema change.
**Cons:** one more table and one more concept to learn; changing a company's scope level after it holds stock
requires a controlled migration of balances, not just a settings flip.

### Option 4 — Separate schemas or tables per structure shape
**Cons:** three code paths for the same business concept; unacceptable maintenance cost. Rejected without
detailed analysis.

## Decision

We will adopt **Option 3**.

### 1. Company declares its stock scope level

```
companies.stock_scope_level  ∈  { COMPANY, BRANCH, WAREHOUSE }
```

Set at company setup. It determines what stock locations may exist, and what the UI asks the user to choose.

### 2. Branch and Warehouse are optional entities

- `branches` may be empty for a `COMPANY`-level company.
- `warehouses` may be empty for a `COMPANY`- or `BRANCH`-level company.
- Neither is required for the system to function.

### 3. `stock_locations` is the single stock anchor

```
stock_locations
  id, company_id (NOT NULL),
  level         ∈ { COMPANY, BRANCH, WAREHOUSE },
  branch_id     NULL,     -- required when level = BRANCH or WAREHOUSE
  warehouse_id  NULL,     -- required when level = WAREHOUSE
  name, is_default, is_active
```

Consistency is enforced by a check constraint so a row cannot claim a level it does not satisfy:

```sql
CHECK (
  (level = 'COMPANY'   AND branch_id IS NULL     AND warehouse_id IS NULL) OR
  (level = 'BRANCH'    AND branch_id IS NOT NULL AND warehouse_id IS NULL) OR
  (level = 'WAREHOUSE' AND branch_id IS NOT NULL AND warehouse_id IS NOT NULL)
)
```

Nullability is thereby confined to **one table**, where a constraint governs it — instead of spreading
through the ledger, the balances and every query.

### 4. Stock always references a stock location, always `NOT NULL`

- `stock_transactions.stock_location_id` — `NOT NULL`
- `stock_balances` primary key — `(stock_location_id, item_type, item_id)`. **Q-22 closed: one legal entity, so no `company_id` in the key.**

Every company, including a `COMPANY`-level one, has at least one stock location (its default). The ledger
therefore never contains a null location, and the balance key never contains a nullable column.

### 5. Every company gets a default stock location at setup

Created automatically when the company is created, at the company's declared level. A `COMPANY`-level
customer never sees a location picker; the default is applied server-side.

### 6. Company is an organizational entity, not a tenant

**Revised 2026-08-29 (ADR-014).** There is no multi-tenancy. `company_id` on `stock_locations` is an
**organizational** column identifying the client business entity that owns the location — not a tenant key,
not an RLS discriminator, and not a security filter. Client separation is achieved by **separate deployment**
with a separate database. Stock location remains a **scoping** concept inside the organization.

### 7. Access scoping

User access is granted at **stock location** granularity (and at branch level where branches exist). A
requested `stockLocationId` is validated against the caller's scope and rejected with
`403 STOCK_LOCATION_OUT_OF_SCOPE` if outside it. A `404` means the location genuinely does not exist
(`SECURITY_RULES.md` §6.1).

### 8. API behaviour

- `stockLocationId` is **optional** in requests. When omitted, the server resolves the company's default
  location; when the company has more than one and none is supplied, the request is rejected with `422`
  rather than guessed.
- Responses always state the resolved stock location, so the client is never ambiguous about where stock
  moved.

## Reason

Option 3 is the only option that keeps the **ledger** simple. That matters more than it might appear: the
ledger is append-only (ADR-005), so a modelling mistake there cannot be quietly corrected later — it is
already history. Confining nullability to one small, constraint-guarded table, and keeping
`stock_location_id NOT NULL` everywhere it counts, means the balance key, the composite foreign keys and
every stock query stay uniform across all three company shapes.

Option 1 is the design a team reaches for first and the one that generates duplicate balance rows in
production, because `NULL <> NULL` in a unique constraint is a subtlety a fresher will not anticipate.
Option 2 solves the technical problem by lying to the customer about their own structure.

The additional concept costs one table and one paragraph of explanation. The alternative costs conditional
logic in every stock query, forever.

## Consequences

**Positive:** all three organisational shapes are supported by one schema and one code path; the ledger and
balances keep `NOT NULL` keys and simple constraints; the organization can grow from
company-level to branch- or warehouse-level by adding locations; the model represents the client structure honestly.

**Negative / accepted costs:**
- One additional table and concept for developers to learn.
- Company setup must create the default stock location — a company with zero stock locations is an invalid
  state and must be impossible to reach.
- **Changing `stock_scope_level` after stock exists is a controlled migration**, not a settings toggle:
  balances must be transferred to new locations, and the ledger must record that transfer as transactions
  rather than being rewritten. This needs its own design and must not be exposed as a simple dropdown.
- The UI must adapt: hide the location picker at `COMPANY` level, show branch selection at `BRANCH` level,
  show warehouse selection at `WAREHOUSE` level.
- Reporting must aggregate across stock locations when a company operates several.

**Follow-up actions:**
- `docs/modules/stock-management/DATABASE_DESIGN.md` updated to use `stock_location_id` instead of a
  mandatory `warehouse_id`.
- `docs/architecture/MULTI_TENANCY.md` updated for stock-scope resolution and access checks.
- Test cases for all three shapes, including: a `COMPANY`-level company posts stock without supplying a
  location; a multi-location company omitting the location gets `422`; a location of another company gets
  `404`; a location outside the caller's scope gets `403`.
- ✅ **Q-19 closed (2026-08-29): inter-location stock transfer is NOT required** and is not part of the
  approved Stock Management scope. **Do not implement it.** The `stock_transaction_type` enum keeps exactly
  the **eight** types from the business source document — **no `TRANSFER` type is added.** Multiple stock
  locations remain supported; stock simply does not move between them. If transfer is required later it is a
  new business decision with its own ADR. See `Client Doc/FINAL_BUSINESS_DECISIONS.md`.
