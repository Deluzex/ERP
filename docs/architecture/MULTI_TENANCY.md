# Multi-Tenancy Architecture — ❌ SUPERSEDED

- **Status:** **Superseded 2026-08-29** by [ADR-014](../decisions/ADR-014-single-client-dedicated-deployment.md)
- **Replaced by:** **[`ORGANIZATION_AND_SCOPE.md`](ORGANIZATION_AND_SCOPE.md)**

---

> # ⚠️ DO NOT IMPLEMENT ANYTHING FROM THIS DOCUMENT
>
> This ERP is **not multi-tenant**. It is built for **one client** and deployed as a **dedicated instance**
> (ADR-014). The four-layer tenant-isolation design previously described here — token-derived tenant scope,
> tenant-scoped repositories, forced RLS on every table, and composite foreign keys for cross-tenant
> safety — is **out of scope and must not be built**.
>
> Its content has been removed rather than left in place, because a document describing an abandoned security
> architecture is worse than no document: a developer who finds it will implement it.

## Where to go instead

| You were looking for | Now in |
| --- | --- |
| Organization hierarchy (Company / Branch / Warehouse) | [`ORGANIZATION_AND_SCOPE.md`](ORGANIZATION_AND_SCOPE.md) §1 |
| Flexible stock scope, why `warehouse_id` is not mandatory | [`ORGANIZATION_AND_SCOPE.md`](ORGANIZATION_AND_SCOPE.md) §2, ADR-013 |
| Access control and the five mandatory checks | [`ORGANIZATION_AND_SCOPE.md`](ORGANIZATION_AND_SCOPE.md) §3 |
| `RequestContext` and trusted scope resolution | [`ORGANIZATION_AND_SCOPE.md`](ORGANIZATION_AND_SCOPE.md) §4 |
| What was removed vs kept | [`ORGANIZATION_AND_SCOPE.md`](ORGANIZATION_AND_SCOPE.md) §5 |
| The decision itself, with options and consequences | [ADR-014](../decisions/ADR-014-single-client-dedicated-deployment.md) |
| The superseded decision, preserved for history | [ADR-002](../decisions/ADR-002-multi-tenancy-strategy.md) |

## Two corrections worth carrying forward

Developers who read the old version should note two specific reversals:

1. **`403`, not `404`.** The old rule returned `404` for another tenant's resource so as not to confirm its
   existence. Within one organization that concern does not apply: **`403` is now correct** for a resource
   the user may not act on, and `404` means genuinely not found.

2. **`company_id` is not a security key.** It survives only as an *organizational* attribute where the
   client's business needs it (ADR-013, ADR-014). Do not filter on it for isolation, and do not add it to
   tables "for the future" — a discriminator with no enforcement is security theatre.

This file is retained as a pointer so that older links and references do not lead to an empty path.
