# ADR-006: Versioned, Forward-Only SQL Migrations

- **Status:** **Accepted** (approved 2026-08-29)
- **Date:** 2026-08-28
- **Deciders:** Database Architect, Backend Architect
- **Phase:** 0
- **Related:** `DATABASE_RULES.md` §7, ADR-002

## Context

The database is PostgreSQL on Supabase. Supabase offers a dashboard where a developer can change the schema
by hand — convenient, and the fastest possible way to get environments out of sync.

We need triggers on the stock ledger, check constraints (including the CGST/SGST-vs-IGST exclusivity rule of
ADR-015), partial indexes and carefully scoped unique keys.
These are not expressible in most ORM auto-migration tools without escape hatches.

The team is mainly freshers, and schema mistakes in an ERP are expensive and often irreversible.

## Problem

How do schema changes get authored, reviewed, versioned and applied across `local`, `dev`, `staging` and
`production`?

## Options

### Option 1 — Manual changes in the Supabase dashboard
**Pros:** immediate; no tooling.
**Cons:** no version history, no review, no reproducibility; environments drift silently; a new developer
cannot create a working database; rollback is guesswork. Unacceptable for a product.

### Option 2 — ORM auto-generated migrations (e.g. entity-diff based)
**Pros:** little authoring effort; schema follows the code model.
**Cons:** generated SQL routinely misses triggers, partial indexes, composite keys and check constraints; the
diff engine sometimes proposes destructive changes (drop-and-recreate) that would delete inventory history;
reviewers end up reading machine-written SQL they did not intend.

### Option 3 — Hand-written, versioned SQL migration files, forward-only
**Pros:** exactly the SQL we intend, reviewable line by line; triggers and constraints are first-class;
history is explicit; CI can apply them to a scratch database.
**Cons:** more authoring effort; developers must know SQL (which, for an ERP team, is a feature).

## Decision

We will adopt **Option 3**: hand-written SQL migrations in `apps/backend/migrations/`, named
`<timestamp>_<verb>_<subject>.sql`, applied by a lightweight runner in CI.

Rules:
- **Forward-only.** Once merged, a migration is immutable; corrections are new migrations.
- Every migration is reviewed and states its rollback plan in the PR.
- Destructive changes require architect approval and a verified backup.
- CI applies all migrations to a scratch database on every PR.
- **Manual dashboard edits are forbidden outside `local`.**
- Seed data (units, permissions, roles) lives in separate, idempotent seed scripts.

## Reason

Data integrity ranks above developer convenience. The specific things this product depends on —
the append-only trigger on the ledger, tax and quantity check constraints, and partial indexes — are exactly the
things auto-generation handles worst. Writing them by hand also means a fresher reads and understands the
constraints that protect the ledger rather than trusting a generator.

Option 1 is not a serious candidate for a product with financial and inventory history. Option 2 was rejected because
its failure mode is a generated `DROP` on a table containing inventory history.

## Consequences

**Positive:** reproducible databases; reviewable security policies; no environment drift; CI verifies every
migration before merge.

**Negative:** more effort per schema change; developers must learn SQL DDL; no automatic model/schema sync,
so the code model and the schema can diverge if a PR is careless — mitigated by integration tests that
exercise real constraints.

**Follow-up actions:**
- Phase 0 task 5: migration runner + the first migration (companies, branches, warehouses, users, roles,
  permissions, `user_company_roles`).
- Add the "migrations apply cleanly" CI gate (`GIT_WORKFLOW.md` §6, gate 7).
- Document the local database bootstrap in `README.md`.
