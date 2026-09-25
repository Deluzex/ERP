# ADR-004: Authorization — RBAC with Configurable Roles and Granular Permissions

- **Status:** **Accepted** (approved 2026-08-29)
- **Date:** 2026-08-28 · **Revised:** 2026-08-29
- **Deciders:** CTO, Security Architect, Solution Architect
- **Phase:** 0
- **Related:** ADR-003, **ADR-014**, `docs/architecture/AUTHENTICATION_AUTHORIZATION.md`

> **Revision note (2026-08-29).** RBAC with granular permissions was approved. Two directions were added:
> (1) Roles and Permissions require **full CRUD functionality** in the ERP itself, and
> (2) **no fixed or default role list** may be invented — roles are configurable per company. The previously
> proposed seed roles (Owner, Company Admin, Store Manager, Store Keeper, Accountant, Viewer) are
> **withdrawn**, and open question Q-09 is closed on that basis.
>
> **Second revision (2026-08-29, ADR-014).** The SaaS scope was withdrawn — this is now a **single-client**
> deployment. Where this ADR says "per company" or "each customer", read it as **the client organization**.
> The decision itself is unchanged and remains **fully in force**: removing multi-tenancy removed *tenant
> isolation*, not authorization. Roles remain customer-configurable because the client organization still
> needs roles that match its own structure. **Q-22 is closed: one legal entity**, so roles are simply
> organization-wide.

## Context

The charter states that authentication must never be assumed to mean authorization, and that every protected
operation must verify permission plus company and stock-scope access.

The existing prototype models this as `UserModel.role` — a free-text display `String` such as
`'Service Manager'`. The business source document defines no roles and no permissions.

Different customer companies organise differently: a small company may have three people wearing every hat;
a larger one may separate purchasing, stores and accounts. A user may also belong to more than one company
with different rights in each.

## Problem

How do we express "may this user perform this action, in this company, within this stock scope?" — in a way
that each customer can configure for their own organisation?

## Options

### Option 1 — Role-name checks in code (`if (user.role === 'admin')`)
**Pros:** trivial to write.
**Cons:** every new role requires editing every check; a single `role` field cannot express per-company
rights; renaming a role in the customer's org chart breaks security logic; customers cannot define their own
roles at all.

### Option 2 — RBAC with a fixed, system-defined role list
**Pros:** simple to seed and reason about; predictable.
**Cons:** imposes our org chart on every customer; the first customer whose structure does not match forces
either a workaround or a schema change; no vendor can predict how a client organizes its
purchasing, stores and accounts functions.

### Option 3 — RBAC with **granular permissions and customer-configurable roles**
**Pros:** code checks a stable statement about the system (`purchase.approve`), never an org-chart label;
each company defines the roles it needs; permission grants are reviewable and auditable; supports users
holding different roles in different companies.
**Cons:** requires role/permission CRUD in the product itself, a maintained permission catalogue, and
guardrails so a company cannot lock itself out.

### Option 4 — ABAC / policy engine
**Pros:** maximum expressiveness (e.g. approval limits by amount).
**Cons:** significant complexity; hard to reason about and to test; a fresher team will not maintain policy
rules correctly; solves problems the business has not posed.

## Decision

We will adopt **Option 3**: RBAC with **granular, company-scoped permissions** and **fully configurable
roles**.

### 1. Permissions

- Named `<module>.<action>` — e.g. `vendor.create`, `stock.adjust`, `purchase.approve`, `role.manage`.
- **Granular**: read, create, update and delete are separate permissions, not one "manage" grant.
- Defined by the system as a **catalogue** (permissions are what the code enforces, so they cannot be
  user-invented), and extended module by module as modules are built.
- Every permission is exercised **within a company scope**.

### 2. Roles

- Roles are **data, created by the customer**, not code.
- **No fixed or default role list is shipped.** We do not invent Admin, Manager, Accountant or any other
  named role. *(This reverses the earlier proposal.)*
- Each role belongs to exactly one company and holds any subset of the permission catalogue.
- A company may create as many roles as its structure requires.

### 3. Role and Permission CRUD — a product feature

The ERP must provide, subject to authorization:

| Capability | Permission |
| --- | --- |
| Create a role | `role.create` |
| View roles and their permissions | `role.view` |
| Update a role (rename, change permissions) | `role.update` |
| Delete a role where allowed | `role.delete` |
| Assign permissions to a role | `role.update` |
| Assign roles to a user | `user.assign-role` |
| View the permission catalogue | `role.view` |

Rules:
- A role that is still assigned to a user cannot be deleted until reassigned (or deletion cascades to an
  explicit reassignment step — a UX decision, but never a silent removal of a user's access).
- Every role and permission change is **audited** (actor, before, after) per ADR-012.
- **Lockout guard:** a company must always retain at least one user holding the role-management and
  user-management permissions. The system must refuse the operation that would remove the last such user.

### 4. Enforcement

- Code checks **permissions**, never role names: `@RequirePermission('purchase.create')`.
- Roles are assigned **per company** (`user_company_roles`), so one user may hold different roles in
  different companies.
- Stock-scope access (company / branch / stock location, per ADR-013) is a **separate** dimension from
  permissions and is validated independently.
- **Deny by default:** an endpoint without an explicit permission declaration fails closed.
- Permissions are resolved server-side per request; they are never read from client-influenced token metadata.

### 5. Permission matrix

The exact permission list is defined **module by module** as each module is built. The architecture must
support custom roles and granular permissions **from the beginning** — that is, the tables, the guard and the
CRUD exist in Phase 0 even though the catalogue grows over time.

## Reason

An ERP cannot impose an org chart on the organization that buys it. Option 2 would work until the first
structure that does not match. Option 1 is the pattern the existing prototype already got wrong.
Option 4 solves problems the business has not posed; if approval limits appear in Phase 4, a narrow rule can
be added to specific use cases without adopting a general engine.

Granularity matters for the same reason: a customer who wants a store keeper who can *record* stock but not
*adjust* it cannot express that if the only grant is "inventory access". Splitting read/create/update/delete
from the start costs nothing at design time and is expensive to retrofit.

## Consequences

**Positive:** each customer configures roles to match their own organisation; adding a role is a
configuration change, not a deployment; permission checks are greppable and auditable; per-company rights are
expressible; the model extends naturally as modules are added.

**Negative / accepted costs:**
- Role and permission CRUD is **product scope in Phase 0**, not infrastructure — it needs screens, APIs and
  tests.
- The permission catalogue must be maintained and seeded as modules are added; a module that forgets to
  register its permissions cannot be granted to anyone.
- Customers can misconfigure roles (grant too much, or lock themselves out). The lockout guard is mandatory;
  over-granting is the customer's prerogative but should be visible in the UI.
- Onboarding a new company requires creating its roles — there is no default set. **This creates a UX
  requirement:** company setup must make role creation easy, possibly via an optional, clearly-labelled
  starting template the customer can edit or ignore. A template offered at setup is not a fixed role list,
  and does not violate this ADR.
- A permission lookup per request (mitigated by a short-lived cache keyed by user **and** company).
- The Flutter client needs the user's permission list to hide unavailable actions — a **UX** convenience that
  must never be mistaken for enforcement.

**Follow-up actions:**
- Phase 0 task 7: `permissions`, `roles`, `role_permissions`, `user_company_roles`, plus stock-scope access
  tables (ADR-013), the permission guard and decorators.
- Phase 0: Role/Permission CRUD API and screens, with the lockout guard.
- A permission-catalogue registration mechanism so each module declares its own permissions.
- Per-module permission lists documented in each module's `API_SPECIFICATION.md`.
- Mandatory 401 / 403-permission / 403-out-of-scope tests per endpoint (`TESTING_RULES.md` §3.3), plus tests that a
  user cannot escalate their own permissions, and that the lockout guard holds.
