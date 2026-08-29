# Logging & Audit Architecture

**Status:** Active (Phase 0) · **Related:** `SECURITY_RULES.md` §9, `DATABASE_RULES.md` §11, ADR-012

---

## 1. Two Different Things — Do Not Merge Them

| | **Logging** | **Audit** |
| --- | --- | --- |
| Question it answers | "Why is the system misbehaving?" | "Who changed this number, and when?" |
| Audience | Engineers | Business, auditors, the customer |
| Storage | Log stream (files/aggregator) | `audit_logs` table in PostgreSQL |
| Lifetime | Days to weeks | Years — it is business data |
| Mutability | Rotated, deleted | **Append-only, never deleted** |
| Contains PII | No | Yes, deliberately (actor identity) |
| Missing entries | Annoying | **A compliance failure** |

A common and costly mistake is treating the audit trail as "just logging". If audit lives only in a log
stream, it is unqueryable by the business, unretained, and unusable when a customer asks who wrote off
₹40,000 of stock.

---

## 2. Logging

### 2.1 Format

Structured JSON, one line per event, via a single logger in `core/logging`. **No `console.log`.**

```json
{
  "timestamp": "2026-08-28T10:15:00.000Z",
  "level": "info",
  "message": "purchase.created",
  "correlationId": "b7c1e5a2-3d4f-4a5b-9c8d-7e6f5a4b3c2d",
  "companyId": "a1b2...",
  "userId": "c3d4...",
  "module": "purchases",
  "purchaseId": "e5f6...",
  "durationMs": 142
}
```

Log the **decision and its identifiers**, not the payload.

### 2.2 Levels

| Level | Use | Example |
| --- | --- | --- |
| `error` | Needs human action | Unhandled exception, database unreachable |
| `warn` | Unexpected but handled | Domain error, 403, retry succeeded |
| `info` | Business events | Purchase created, stock adjusted, user logged in |
| `debug` | Development only | Query shapes, branch decisions |

### 2.3 Never log

- Access or refresh tokens, passwords, API keys, connection strings
- Full request bodies containing PII (vendor contact details, addresses)
- Entire database rows
- Anything you would not want in a support ticket screenshot

### 2.4 Correlation id

Generated at the edge, present in **every** log line for that request, in the error envelope, and on the
audit record. It is what makes a distributed failure reconstructable.

---

## 3. Audit

### 3.1 What must be audited

**Security events** (`SECURITY_RULES.md` §9): login success/failure, permission denied, role or permission
assignment change, user invited/deactivated/removed, data export.

**Business events:**

| Event | Why |
| --- | --- |
| Master created / updated | Someone changed a credit limit or a selling price |
| Master **deleted with reason** | The source document mandates a reason for vendor deletion (§5.1) |
| Purchase created / updated / cancelled | Financial document |
| Payment recorded | Money |
| **Stock adjustment** | The single most abusable operation in any inventory system |
| Any manual override of a computed value | It should be rare and visible |
| Approval actions | Accountability |

### 3.2 Schema

```sql
CREATE TABLE audit_logs (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id     uuid        NOT NULL REFERENCES companies(id),
  branch_id      uuid            NULL,
  actor_user_id  uuid        NOT NULL REFERENCES users(id),
  action         text        NOT NULL,     -- 'vendor.deleted', 'stock.adjusted'
  entity_type    text        NOT NULL,     -- 'vendor'
  entity_id      uuid        NOT NULL,
  before_state   jsonb           NULL,     -- changed fields only
  after_state    jsonb           NULL,
  reason         text            NULL,     -- required for deletes and adjustments
  correlation_id uuid        NOT NULL,
  ip_address     inet            NULL,
  user_agent     text            NULL,
  occurred_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_audit_logs__company_entity
  ON audit_logs (company_id, entity_type, entity_id, occurred_at DESC);
CREATE INDEX idx_audit_logs__company_actor
  ON audit_logs (company_id, actor_user_id, occurred_at DESC);
```

`audit_logs` is append-only and never deleted. Access to it is governed by permission, like every other
resource (ADR-014 — there is no tenant filter).

### 3.3 Rules

1. **Written inside the same database transaction** as the change it records. An audit entry that commits
   while the business change rolls back is a lie; the reverse is a gap.
2. **Append-only.** No `UPDATE`, no `DELETE`. Enforce with privileges and a trigger.
3. Store **changed fields only** in `before_state`/`after_state`, not whole rows — whole rows bloat storage
   and bury the actual change.
4. **Never store secrets** in the state snapshots. Redact token/password-like fields.
5. `reason` is **mandatory** for deletions and stock adjustments — enforced by a check constraint and by the
   DTO.
6. The actor is `ctx.userId` from the verified token, never from input.

### 3.4 Audit is not a substitute for the stock ledger

The `stock_transactions` ledger (ADR-005) is the **business** record of stock movement — it is what produces
the balance. `audit_logs` is the **accountability** record of who caused it. Both exist; neither replaces the
other.

---

## 4. Monitoring & Alerting (Phase 0 outline)

| Signal | Threshold | Action |
| --- | --- | --- |
| 5xx rate | > 1% over 5 min | Page on-call |
| Auth failure spike | Unusual rate per IP/user | Investigate credential stuffing |
| **403 spike from one user** | Sustained | Possible probing — investigate |
| **Repeated authorization failures from one user** | sustained | **Investigate — possible probing or a broken role** |
| Stock balance drift vs ledger | ≥ 1 mismatch | Investigate; block further posting for that item |
| Database connection saturation | > 80% | Scale/investigate |
| Migration failure | any | Block deployment |

The authorization-failure alert matters most. Instrument it so that a scoping or permission bug is found by us,
not by a customer.

---

## 5. Retention

| Data | Retention |
| --- | --- |
| `debug` logs | 7 days |
| `info` / `warn` logs | 30 days |
| `error` logs | 90 days |
| **Audit logs** | Per contract — years. Treated as business data, backed up with the database |
| **Stock transactions** | **Forever.** Never purged |

---

## 6. Fresher Checklist

Before merging anything that changes business data:

- [ ] Does it write an audit entry?
- [ ] Is the audit entry inside the same transaction as the change?
- [ ] Does it capture the actor from the token (not from input)?
- [ ] Does it capture a reason where the business requires one?
- [ ] Does the log line avoid tokens and PII?
- [ ] Is the correlation id present?
