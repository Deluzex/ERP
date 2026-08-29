# ADR-002: Multi-Tenancy — Shared Schema with `company_id` and Row Level Security

- **Status:** ❌ **SUPERSEDED by [ADR-014](ADR-014-single-client-dedicated-deployment.md)** (2026-08-29)
- **Original date:** 2026-08-28 · **Superseded:** 2026-08-29
- **Deciders:** Solution Architect, Database Architect, Security Architect
- **Phase:** 0

---

> # ⚠️ THIS DECISION IS NO LONGER IN FORCE
>
> **Do not implement anything described below.**
>
> The multi-tenant SaaS requirement was **withdrawn** on 2026-08-29. The ERP is now built for **one client**
> as a **dedicated deployment**. See **[ADR-014](ADR-014-single-client-dedicated-deployment.md)**.
>
> **What this means concretely:**
>
> | This ADR proposed | Current position (ADR-014) |
> | --- | --- |
> | `company_id` as a mandatory tenant discriminator on every table | ❌ Not a tenant discriminator. Company is an **organizational** entity only |
> | Multi-tenant RLS policies on every table | ❌ Not implemented |
> | Tenant-scoped repositories and guards for SaaS isolation | ❌ Not implemented |
> | Composite foreign keys for cross-tenant safety | ❌ Not needed for that purpose |
> | Cross-tenant `404` responses and tests | ❌ Replaced by resource-level authorization tests |
>
> **What survives:** Company, Branch and Warehouse remain **organizational concepts** where the client's
> business needs them (ADR-013), and **authorization remains fully mandatory** (ADR-004). Removing
> multi-tenancy removed *tenant isolation*, **not** access control.
>
> The original text is preserved below for historical context only.

---

## Context *(historical)*

The product was scoped as a SaaS ERP sold to multiple companies. The charter stated that one company must
never be able to access another company's data, and that multi-tenancy must be designed from the beginning
rather than added later.

The hierarchy was Company → Branch → Warehouse → Users → Roles/Permissions. The database is PostgreSQL on
Supabase, which provides Row Level Security.

Expected scale: tens to low hundreds of tenant companies.

## Problem *(historical)*

How do we physically separate tenant data so that isolation does not depend on every developer remembering
to write a `WHERE` clause?

## Options *(historical)*

### Option 1 — Database per tenant
**Pros:** strongest isolation; simple mental model; per-tenant backup and restore.
**Cons:** every migration must run across N databases; connection management and cost grow linearly;
provisioning a customer becomes an operational project.

### Option 2 — Schema per tenant
**Pros:** good isolation; a single database.
**Cons:** the same N-way migration problem; `search_path` manipulation is error-prone with connection
pooling.

### Option 3 — Shared database, shared schema, `company_id` discriminator
**Pros:** one migration path; natural fit for Supabase RLS; trivial tenant provisioning.
**Cons:** isolation depends on correctness — a single missing filter leaks data.

## Decision *(historical — no longer in force)*

Option 3, with isolation enforced by four independent layers: guard-derived scope, scoped repositories,
forced RLS driven by a transaction-local session variable, and composite foreign keys.

## Note on the outcome

Interestingly, the requirement change landed on something close to this ADR's **rejected Option 1** — the
strongest isolation available — but achieved by **deployment** rather than by database provisioning within a
shared product. Its cost (N migrations, N environments) is now an operational concern per client rather than
a per-tenant one, and ADR-014 records that cost explicitly.

Nothing had been implemented when this ADR was superseded, so no code required unwinding.
