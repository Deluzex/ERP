# ADR-014: Single-Client Dedicated Deployment (Multi-Tenancy Removed from Scope)

- **Status:** **Accepted** (approved 2026-08-29)
- **Date:** 2026-08-29
- **Deciders:** CTO, Product Owner, Solution Architect
- **Phase:** 0
- **Supersedes:** **ADR-002** (Multi-tenancy — shared schema + `company_id` + RLS)
- **Related:** ADR-004, ADR-013, `docs/architecture/ORGANIZATION_AND_SCOPE.md`, `SECURITY_RULES.md`

## Context

The project was previously scoped as a **multi-tenant SaaS ERP** sold to many companies, and ADR-002
established a four-layer tenant-isolation design (token-derived scope, scoped repositories, PostgreSQL RLS,
composite foreign keys).

**That requirement has been withdrawn.** The approved scope is now:

- Build the ERP **for one specific client**.
- Deploy a **dedicated instance** for that client.
- Future clients are handled **separately**: understand their requirements, make the required changes, deploy
  a **separate instance**.

No implementation had started, so nothing built on the multi-tenant assumption has to be unwound — only
documentation.

## Problem

Does the system keep multi-tenant isolation machinery, and what happens to the Company concept?

## Options

### Option 1 — Keep the multi-tenant architecture anyway, "for the future"
**Pros:** ready if SaaS returns.
**Cons:** builds and maintains machinery no current requirement needs — RLS policies on every table,
composite foreign keys, scope plumbing on every query, and a large class of tests. On a fresher team this is
significant complexity with no present payoff, and speculative architecture tends to be subtly wrong because
nothing exercises it. It also slows every feature in Phase 1.

### Option 2 — Remove multi-tenancy; single dedicated deployment per client
**Pros:** matches the actual requirement; simpler schema, simpler queries, simpler tests; each client's data
is isolated by the strongest possible boundary — **a separate database and a separate deployment**; each
client can diverge to fit their own business.
**Cons:** if SaaS is later required, retrofitting tenancy is expensive. Per-client instances multiply
operational work (deployments, upgrades, backups) as clients are added.

### Option 3 — Remove RLS but keep `company_id` on every table as a "future tenant hook"
**Pros:** looks like a cheap hedge.
**Cons:** the worst of both. A discriminator column with no enforcement is **security theatre** — it creates
the appearance of isolation while providing none, and a future developer may trust it. If SaaS returns, the
column alone saves very little; the hard parts are enforcement, scope resolution and tests.

## Decision

We will adopt **Option 2**.

1. **Multi-tenancy is out of scope.** No tenant isolation architecture, no tenant-aware guards or repositories
   built for SaaS isolation, no multi-tenant RLS policies, no cross-tenant tests.
2. **Isolation between clients is achieved by deployment**: each client gets a dedicated instance with its own
   database. This is a *stronger* boundary than row-level filtering, not a weaker one.
3. **`company_id` is NOT a tenant discriminator** and is not mandatory on every table.
4. **Company, Branch and Warehouse are retained as organizational concepts** where the client business
   requires them. **"Company" means the client's own organization / business entity — not a SaaS tenant.**
   They remain the levels of the stock scope hierarchy in ADR-013.
5. Authorization remains fully required (ADR-004): authentication still does not imply authorization. What is
   removed is *tenant* isolation, **not** access control.
6. Future SaaS, if ever required, will be a **new decision with its own ADR**, informed by real multi-client
   requirements rather than by speculation.

## Reason

The decision priority is Business Correctness → Security → Data Integrity → Maintainability → … Multi-tenancy
served none of these under the current requirement; it served a *hypothetical* one. Building isolation
machinery for tenants that do not exist adds risk rather than removing it: untested security code is a
liability, and every Phase 1 feature would pay a complexity tax for it.

Option 3 was rejected specifically because a discriminator without enforcement is misleading. If we are not
multi-tenant, the documentation and the schema should say so plainly.

The important nuance — and the reason this ADR is careful about it — is that **removing multi-tenancy is not
removing access control.** Roles, granular permissions, deny-by-default and resource-level authorization all
remain mandatory. Users within the client's organization still must not access what they are not entitled to.

## Consequences

**Positive:** materially simpler schema, queries, guards and tests; no RLS policy maintenance; no composite
foreign keys needed purely for tenant safety; the strongest possible client separation (separate databases);
each client instance can be tailored; faster Phase 1 delivery.

**Negative / accepted costs:**
- **Retrofitting SaaS later would be a substantial project**, not a configuration change. This is accepted
  explicitly.
- Per-client instances multiply operational work: N deployments, N upgrade paths, N backup regimes. A
  release process that handles this should be designed before the second client, not after.
- Client-specific divergence can fan out into per-client code branches if not governed. Recommend keeping
  client-specific behaviour **configuration-driven** wherever cheap, so instances stay on one codebase.
- Documentation written under the SaaS assumption had to be revised; several documents and ADR-002 are
  superseded (see below).

**Follow-up actions:**
- ADR-002 marked **Superseded by this ADR**.
- `docs/architecture/MULTI_TENANCY.md` replaced by
  `docs/architecture/ORGANIZATION_AND_SCOPE.md`; the old file retained as a superseded pointer.
- `SECURITY_RULES.md`, `DATABASE_RULES.md`, `TESTING_RULES.md`, `ARCHITECTURE.md`, `PROJECT_RULES.md` revised:
  tenant isolation replaced with **resource-level authorization and scope checks**.
- Cross-tenant `404` test requirements replaced with resource-level authorization tests
  (`TESTING_RULES.md` §3.3).
- ✅ **Q-22 answered (2026-08-29): the client has ONE legal entity only.** The ERP is built for that single
  registered business. Therefore `company_id` is **not** required on documents, masters or unique
  constraints — `UNIQUE (item_code)`, not `UNIQUE (company_id, item_code)`. There is one GSTIN and one place
  of business (Gujarat). See `Client Doc/FINAL_BUSINESS_DECISIONS.md`.
