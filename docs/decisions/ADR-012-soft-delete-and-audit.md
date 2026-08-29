# ADR-012: Soft Delete with Reason, and a Separate Audit Trail

- **Status:** **Accepted** (approved 2026-08-29)
- **Date:** 2026-08-28
- **Deciders:** Database Architect, Business Analyst, Security Architect
- **Phase:** 0
- **Related:** `DATABASE_RULES.md` §11, `docs/architecture/LOGGING_AND_AUDIT.md`, ADR-005

## Context

The business source document §5.1 specifies vendor actions as: *Add, View, Edit, **Delete (Reason \*)**,
Create Purchase, Purchase History and Payment History*. The asterisk marks the reason as **required** — so
deletion with a mandatory justification is an explicit business requirement, not an engineering preference.

Meanwhile §21 requires that stock history is never destroyed, and ERP transactions must be auditable: who,
what, when, which company, which reference.

The prototype's `Vendor` model already carries `isDeleted`, `deleteReason` and `deletedAt` — the intent is
present, but there is no audit trail and no actor recorded.

## Problem

What happens when a user deletes a record, and how do we record who changed business data?

## Options

### Option 1 — Hard delete everything
**Pros:** simple; the database stays small.
**Cons:** deleting a vendor orphans or destroys its purchase history, making old documents unreadable;
violates the auditability requirement; irreversible user error becomes a support catastrophe.

### Option 2 — Soft delete everything
**Pros:** nothing is ever lost; uniform rule.
**Cons:** every query must remember `WHERE is_deleted = false`; unique constraints collide with deleted rows
(a deleted item code blocks reuse); tables accumulate rows that no longer serve a purpose.

### Option 3 — Data-class-specific policy, plus a dedicated audit trail
**Pros:** matches how the business actually thinks — a draft is disposable, an invoice is not; keeps
transactional history intact while allowing masters to be retired; the audit trail answers "who did this"
independently of the deletion mechanism.
**Cons:** developers must know which class a table belongs to; more rules to learn.

## Decision

We will adopt **Option 3**.

### Deletion policy by data class

| Data class | Policy |
| --- | --- |
| Stock transactions, purchases, invoices, payments, audit logs | **Never deleted.** Reversed by compensating entries (ADR-005) |
| Masters: Vendor, Raw Material, Finished Product, Customer, Dealer, Architect | **Soft delete**, with mandatory reason, actor and timestamp |
| Draft documents never posted to the ledger | May be hard-deleted, but the deletion is audit-logged |
| Reference data (units) | Deactivate (`is_active = false`); never delete once referenced |

### Soft-delete columns

```sql
is_deleted    boolean     NOT NULL DEFAULT false,
deleted_at    timestamptz     NULL,
deleted_by    uuid            NULL REFERENCES users(id),
delete_reason text            NULL,
CONSTRAINT ck_<table>__delete_reason
  CHECK (is_deleted = false OR delete_reason IS NOT NULL)
```

The check constraint is what makes the business requirement real: a soft delete without a reason is rejected
by the database, not merely by a form validator.

### Rules

1. A soft-deleted master is **not selectable** for new transactions but **remains resolvable** for historical
   documents — otherwise old purchases become unreadable, which defeats the purpose.
2. Unique constraints include `is_deleted` where code reuse after deletion is required — decide per table and
   document it.
3. Every delete, and every create/update of business data, writes an `audit_logs` row **in the same
   transaction** as the change.
4. The actor comes from `ctx.userId` (the verified token), never from request input.
5. `audit_logs` is append-only. It is never updated or deleted.

### Audit is separate from soft delete

Soft delete answers *"is this record still active?"*. The audit trail answers *"who changed it, when, from
what, to what, and why?"*. Both are required; neither substitutes for the other. And neither replaces the
stock ledger, which is the *business* record of movement (ADR-005).

## Reason

The mandatory reason on vendor deletion is stated in the source document, so it is a requirement rather than a
choice. Hard-deleting masters would break historical documents — an ERP that cannot render last year's
purchase because a vendor was removed has lost the customer's records. Soft-deleting *everything* would push
`WHERE is_deleted = false` into every query and complicate the unique constraints we already
need.

A per-class policy costs a little learning and buys correct behaviour for each kind of data.

## Consequences

**Positive:** the business requirement is enforced by a constraint; historical documents stay readable;
accountability is queryable by the business, not buried in a log stream; accidental deletion is recoverable.

**Negative:**
- Developers must know which policy applies to the table they are touching — this belongs in the review
  checklist and in each module's `DATABASE_DESIGN.md`.
- Queries on master tables must filter `is_deleted = false` (mitigated: the scoped base repository does this
  by default).
- Unique-constraint interaction with soft-deleted rows must be decided per table.
- `audit_logs` grows steadily and must be included in backup and retention planning.

**Follow-up actions:**
- Implement `audit_logs` and the `AuditLogger` in Phase 0 task 11.
- The base scoped repository excludes soft-deleted rows by default, with an explicit opt-in for history views.
- Add "is the audit entry in the same transaction?" to the review checklist.
- Decide and document the unique-constraint policy for `raw_materials.item_code` reuse after deletion —
  **open question (Q-06)**.
