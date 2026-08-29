# DATABASE_RULES.md — PostgreSQL / Supabase Standards

**Status:** Active · **Related:** ADR-005, ADR-011, ADR-012, ADR-013, **ADR-014**, **ADR-015**,
`docs/architecture/ORGANIZATION_AND_SCOPE.md`, `docs/modules/stock-management/DATABASE_DESIGN.md`

> ### ⚠️ Scope change — 2026-08-29 (ADR-014)
> **The database is single-client.** Multi-tenancy is out of scope:
> **no multi-tenant RLS policies**, **no `company_id` as a mandatory tenant discriminator**, and no composite
> foreign keys added purely for cross-tenant safety.
>
> `company_id` appears **only on `stock_locations`** (ADR-013). **Q-22 confirmed the client has one legal
> entity**, so it is not needed on documents, masters or unique keys either. Do not add it "for a future
> SaaS": a discriminator with no enforcement is security theatre.
>
> Everything else here — constraints, decimal types, transactions, the append-only ledger, migrations —
> is unchanged and remains mandatory.

---

## 1. Principles, in Priority Order

```
Data Integrity → Authorization Support → Auditability → Clarity → Performance
```

The database is the **last line of defence**. Application code has bugs; a `CHECK` constraint does not.
If a rule can be expressed as a constraint, express it as a constraint **in addition to** the domain rule —
not instead of it.

---

## 2. Naming Conventions

| Object | Convention | Example |
| --- | --- | --- |
| Table | `snake_case`, **plural** | `raw_materials`, `stock_transactions` |
| Column | `snake_case`, singular | `item_code`, `company_id` |
| Primary key | `id` | `id uuid` |
| Foreign key | `<referenced_singular>_id` | `vendor_id`, `warehouse_id` |
| Boolean | `is_` / `has_` prefix | `is_active`, `is_deleted` |
| Timestamp | `_at` suffix, `timestamptz` | `created_at`, `deleted_at` |
| Enum type | `snake_case` singular | `stock_transaction_type` |
| Index | `idx_<table>__<cols>` | `idx_stock_transactions__item_location` |
| Unique constraint | `uq_<table>__<cols>` | `uq_raw_materials__item_code` |
| Foreign key constraint | `fk_<table>__<ref_table>` | `fk_purchase_items__raw_materials` |
| Check constraint | `ck_<table>__<rule>` | `ck_stock_transactions__single_direction` |
| Migration file | `<timestamp>_<verb>_<subject>.sql` | `20260901120000_create_companies.sql` |

**Business terminology is fixed by the source document.** The table is `vendors`, not `suppliers`.
The table is `architects`, not `consultants`. Do not "improve" the client's vocabulary.

---

## 3. Mandatory Columns

Every **business** table carries:

```sql
id           uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
created_at   timestamptz NOT NULL DEFAULT now(),
created_by   uuid        NOT NULL REFERENCES users(id),
updated_at   timestamptz NOT NULL DEFAULT now(),
updated_by   uuid            NULL REFERENCES users(id)
```

> **`company_id` is NOT in this list** (ADR-014, Q-22). The client has **one legal entity**, so it is not
> needed for organizational attribution either. It appears **only on `stock_locations`**, as the anchor of
> the stock hierarchy (ADR-013). It is never a tenant discriminator and never a security filter.

Tables that support soft delete additionally carry (ADR-012):

```sql
is_deleted    boolean     NOT NULL DEFAULT false,
deleted_at    timestamptz     NULL,
deleted_by    uuid            NULL REFERENCES users(id),
delete_reason text            NULL
```

> The source document requires a **reason** when deleting a Vendor (§5.1: `Delete(Reason *)`).
> That is why `delete_reason` exists — enforce it with a check constraint:
> `CHECK (is_deleted = false OR delete_reason IS NOT NULL)`.

**Stock-bearing tables carry `stock_location_id NOT NULL`** (ADR-013) — never a mandatory `warehouse_id`.
Branch and warehouse are optional per the client's structure; nullability is confined to the single
`stock_locations` table, where a check constraint governs it. See `ORGANIZATION_AND_SCOPE.md` §2.

---

## 4. Data Types — Hard Rules

| Data | Type | Never use |
| --- | --- | --- |
| Identifier | `uuid` (`gen_random_uuid()`) | Sequential integers exposed in URLs (enumeration risk) |
| **Money** | `numeric(18,2)` | `float`, `double precision`, `real`, `money` |
| **Quantity** | `numeric(18,4)` | `float`, `double precision`, `integer` |
| **Rate / percentage** | `numeric(9,4)` | float |
| Timestamp | `timestamptz` (always UTC) | `timestamp` without time zone |
| Date only | `date` | text |
| Enumerated value | PostgreSQL `enum` **or** `text` + `CHECK` | Bare `text` with no constraint |
| Free text | `text` | `varchar(n)` chosen arbitrarily |

**Why `numeric` and not `double precision`:** binary floating point cannot represent `0.1` exactly. Summing a
purchase of 3 lines at `33.33` gives `99.99000000000001`, and an ERP that reports a one-paisa discrepancy on
an invoice loses the customer's trust in every other number it shows. See **ADR-011**.

> ⚠️ The existing Flutter implementation uses `double` for every amount and quantity (ADR-010: retained, but
> not a pattern for new code). New code must never do this.

Quantities use 4 decimal places because the source document's units include `kg` and `sq feet`, which are
divisible; `piece` quantities simply carry zeros.

### 4.1 Tax and round-off columns (ADR-015 — client-confirmed)

The calculation chain is fixed:

```
Gross Amount → Discount → Taxable Amount → GST → Round Off → Grand Total
```

**Discount is applied BEFORE GST.** GST is calculated on the taxable amount, never on the gross amount.

Consequently, every taxable document (purchase, and later sales invoice) carries these columns —
all `numeric(18,2)`:

| Column | Purpose |
| --- | --- |
| `gross_amount` | Before discount |
| `discount_amount` | The discount applied |
| `taxable_amount` | `gross_amount − discount_amount` — **the GST base** |
| `cgst_amount` | Intra-state component |
| `sgst_amount` | Intra-state component |
| `igst_amount` | Inter-state component |
| `round_off_amount` | **Separate column — never folded into line or tax amounts** |
| `grand_total` | Final payable |

Rules:

1. **Never store a single undifferentiated `tax_amount`.** CGST/SGST and IGST are mutually exclusive per
   transaction and must be reported separately.
2. **The GST type is derived per transaction**, from the place of supply — not a fixed configuration value.
   The client's place of business is Gujarat: **within Gujarat → CGST + SGST; outside Gujarat → IGST.**
   This means the schema must hold **state / place-of-supply information** on the organization and on each
   vendor and customer. A master without it cannot have its GST determined — validation must require it
   rather than silently defaulting to intra-state.
3. **`round_off_amount` is its own column, and it is an ENTERED value.** It must be presentable separately on
   the bill and must never be hidden inside an item amount or a tax amount. **It is not computed with
   `ROUND()`** — see below.
4. All of these are decimal (ADR-011).

> **Round-off is an input, not a calculation (Q-05a, closed).** The client sample invoice
> (`Client Doc/046 Hotel Winsome, Ahmedabad.pdf`) shows a round-off of **−₹93.50** taking ₹1,00,093.50 to a
> negotiated **₹1,00,000.00**. A nearest-rupee rule would have produced −₹0.50. Therefore:
> `grand_total = taxable_amount + cgst + sgst + igst + round_off_amount`, with `round_off_amount` supplied,
> signed, and never derived. See ADR-015 §3 and BR-CALC-023.

---

## 5. Constraints — Use Them

Every table must declare, where applicable:

1. **Primary key** — always.
2. **Foreign keys** — always, with an explicit `ON DELETE` action. Default to `ON DELETE RESTRICT` for
   business data. Never `ON DELETE CASCADE` on financial or inventory history.
3. **Unique constraints** — scoped to the level at which the business requires uniqueness:
   ```sql
   CONSTRAINT uq_raw_materials__item_code UNIQUE (item_code)
   ```
   ✅ **Q-22 is closed: the client has ONE legal entity.** An Item Code is therefore unique **across the
   organization** — a plain `UNIQUE (item_code)`. **Do not add `company_id` to unique keys.**


4. **NOT NULL** — for every field the source document marks with `*`.
5. **CHECK constraints** — for invariants:
   ```sql
   CHECK (quantity_in >= 0),
   CHECK (quantity_out >= 0),
   CHECK ((quantity_in > 0) <> (quantity_out > 0))  -- exactly one direction per ledger row
   ```

### 5.1 Composite foreign keys — only where they express a real business constraint

The previous rule required composite `(company_id, id)` foreign keys everywhere, to make **cross-tenant**
references physically impossible. **That rule is withdrawn** (ADR-014) — there are no tenants to keep apart,
and the extra unique keys and wider foreign keys would be pure overhead.

Use a composite foreign key when it enforces a genuine business invariant. The clearest case here is
**stock location consistency**: a stock transaction must not reference a location belonging to a different
organizational entity. **Q-22 is closed — the client has one legal entity**, so even this case does not arise
today; a single-column foreign key suffices.

Plain single-column foreign keys are the default:

```sql
ALTER TABLE purchases
  ADD CONSTRAINT fk_purchases__vendors
  FOREIGN KEY (vendor_id) REFERENCES vendors (id);
```

---

## 6. Database Access Model (Single-Client — ADR-014)

**There are no multi-tenant RLS policies.** The previous four-layer tenant-isolation model
(`company_id` discriminator + scoped repositories + forced RLS + composite FKs) is **superseded**: it existed
to separate SaaS tenants, and there are none. Client separation is achieved by **separate deployments with
separate databases**.

### 6.1 What replaces it

| Concern | Control |
| --- | --- |
| Which user may perform an action | Permission guard in the backend (ADR-004) |
| Which resources a user may act on | Resource-level authorization in the use case / repository |
| Which branch / stock location a user may act in | Scope validated against `RequestContext` (`SECURITY_RULES.md` §2) |
| Data correctness | Constraints, foreign keys, check constraints — §5 |
| History integrity | Append-only ledger + trigger (§10), audit log |

Authorization is enforced in the **application**, deliberately and testably. The database enforces
**integrity**, which is what databases are good at.

### 6.2 Database access rules that still apply

- The application connects with a **least-privilege role** — not a superuser, not the Supabase service-role
  key.
- The **service-role key and connection credentials never leave the server** and are never exposed to Flutter.
- No raw SQL outside the repository/infrastructure layer; all queries parameterised.
- Never use user-editable metadata as an authorization authority.

### 6.3 If RLS is ever wanted again

Do **not** add RLS policies speculatively. With a single client there is no tenant boundary for a policy to
enforce, and a policy driven by a session variable nobody sets is a latent outage. If a future requirement
needs row-level restrictions (for example, restricting sensitive cost data by role), that is a **new
decision** requiring an ADR.

---

## 7. Migrations

1. **All schema changes go through migration files** committed to Git. No manual edits in the Supabase
   dashboard outside `local`.
2. Migrations are **forward-only and immutable once merged**. To fix a merged migration, add a new one.
3. Every migration must be **reviewed** and must state its rollback plan.
4. Destructive changes (drop column, drop table, narrow a type) require:
   - an ADR or explicit architect approval,
   - a deprecation period where possible,
   - a verified backup.
5. Migrations run in CI against a scratch database before they can reach any shared environment.
6. Seed data (units, permissions, roles) lives in versioned seed scripts, separate from schema migrations.

Migration checklist:

- [ ] Idempotent or guaranteed single-run
- [ ] No speculative `company_id` or RLS policy added (ADR-014)
- [ ] Adds indexes for the foreign keys it introduces
- [ ] Unique constraints scoped to the level the business requires
- [ ] Does not drop or rewrite historical inventory/financial rows
- [ ] Rollback plan documented in the PR

---

## 8. Indexing

Index deliberately, not reflexively:

- Every foreign key column gets an index (PostgreSQL does not create one automatically).
- Stock tables get a composite index matching their main access path:
  ```sql
  CREATE INDEX idx_stock_transactions__item_location_date
    ON stock_transactions (item_type, item_id, stock_location_id, occurred_at DESC);
  ```
- Index the columns used by list screens' filters and sorts (documented in `UI_FLOW.md`).
- Do not add an index without a query that needs it — every index costs write throughput.

---

## 9. Transactions

- Any business operation that writes **more than one row across more than one table** runs inside a single
  database transaction.
- The transaction boundary is owned by the **use case** layer, never by a repository or a controller.
- A purchase that writes `purchases`, `purchase_items`, `stock_transactions`, `stock_balances` and
  `audit_logs` either commits all five or none.
- Keep transactions short. Do not perform HTTP calls, file I/O or PDF generation inside one.
- Use the appropriate isolation level for balance-sensitive operations, and lock the balance row
  (`SELECT ... FOR UPDATE`) when updating a cached stock balance to avoid lost updates under concurrency.

---

## 10. The Stock Ledger Rule

`stock_transactions` is **append-only** (ADR-005):

- `INSERT` only. No `UPDATE`, no `DELETE` — enforce with database privileges and a trigger that raises on
  update/delete.
- Every row references the document that caused it (`reference_type`, `reference_id`, `reference_number`).
- Corrections are new compensating rows, never edits.
- A cached `stock_balances` row may exist for performance, but it must be **fully reconstructible** from the
  ledger. A scheduled reconciliation job compares them and alerts on drift.

Invariant that must always hold:

```sql
-- for any item in any warehouse
SUM(quantity_in) - SUM(quantity_out) = stock_balances.quantity
```

This invariant is a required integration test (`TESTING_RULES.md` §4).

---

## 11. Soft Delete vs Hard Delete

| Data | Deletion policy |
| --- | --- |
| Stock transactions, purchases, invoices, payments, audit logs | **Never deleted.** Reversed by compensating entries |
| Masters (Vendor, Raw Material, Finished Product, Customer, Dealer, Architect) | **Soft delete** with reason, actor and timestamp |
| Draft documents never posted to the ledger | May be hard-deleted, audit-logged |
| Reference data (units) | Deactivate (`is_active = false`), do not delete once referenced |

A soft-deleted master must not be selectable for new transactions but must remain resolvable for historical
documents — otherwise old purchases become unreadable.

---

## 12. What Must Never Live Only in the Frontend

Important business state must exist in the database, not in Dart:

- Stock balances and movements
- Document numbering sequences
- Permissions and role assignments
- Business rule parameters (minimum stock, reorder level, credit limit, GST rates, commission slabs)

> ⚠️ Today all of this lives in `lib/shared/services/mock_database_service.dart`, including hard-coded
> document counters (`_purchaseCounter = 104`). None of it survives a restart, and none of it is concurrency-safe.
> This is prototype behaviour and must not be replicated.

---

## 13. Document Numbering

Purchase Number, Production Number, Invoice Number etc. are **business identifiers**:

- Generated **server-side**, never by the client.
- **Unique across the organization** (and per financial year where the business requires it):
  `UNIQUE (document_type, document_number)`. **Q-22 closed: one legal entity — do not add `company_id`.**
- Generated inside the same transaction as the document, using a sequence table with row locking or a
  PostgreSQL sequence per document type — not `MAX(number) + 1`, which races under concurrency.
- Gaps are acceptable; duplicates are not. Never reuse a number from a deleted draft.

---

## 14. Review Checklist for Any Schema Change

- [ ] No tenant machinery added: no speculative `company_id`, no RLS policy (ADR-014)
- [ ] Unique constraints scoped correctly for the business rule
- [ ] Composite foreign keys used only where they enforce a real business invariant
- [ ] Money is `numeric(18,2)`, quantity `numeric(18,4)` — no floats
- [ ] `NOT NULL` matches the required fields in the source document
- [ ] Check constraints encode the invariants
- [ ] Indexes cover the foreign keys and the real access paths
- [ ] Audit columns present
- [ ] Soft-delete policy correct for this data class
- [ ] No cascade delete on financial or inventory history
- [ ] Migration is forward-only with a documented rollback plan
- [ ] Constraints are covered by integration tests
