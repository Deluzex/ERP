# SECURITY_RULES.md — Security Standards

**Status:** Active · **Related:** ADR-003, ADR-004, **ADR-014**, `docs/architecture/ORGANIZATION_AND_SCOPE.md`,
`docs/architecture/AUTHENTICATION_AUTHORIZATION.md`, `DATABASE_RULES.md`

> **The single rule to remember:** *authenticated* is not *authorized*, and *authorized in general* is not
> *authorized for this resource*. All three checks are separate, and all three are mandatory.

> ### ⚠️ Scope change — 2026-08-29 (ADR-014)
> This ERP is **single-client, dedicated deployment**. **Multi-tenancy is out of scope**: no tenant
> isolation architecture, no multi-tenant RLS, no cross-tenant checks or tests.
>
> **This removed tenant isolation. It did NOT remove access control.** Everything below about
> authentication, permissions, resource-level authorization, scope validation, secrets and validation
> remains **fully mandatory**. Isolation between *clients* is achieved by separate deployments with separate
> databases.

---

## 1. Threat Model (what we are actually defending against)

Now that the product is single-client, the realistic threats come from **inside the client's organization**
and from the internet — not from another tenant.

| Threat | Realistic scenario in this ERP | Control |
| --- | --- | --- |
| **Privilege escalation** | A store keeper calls the "approve purchase" endpoint directly, bypassing the UI | Permission guard on **every** endpoint; deny by default |
| **IDOR / BOLA** | A user changes an id in a URL to act on a record outside their branch or stock-location scope | Resource-level authorization on every fetch and write; `403` |
| **Out-of-scope stock movement** | A user posts stock into a warehouse they are not assigned to | Scope validated against `RequestContext`, never from the payload |
| **Mass assignment** | Client sends `isApproved`, `createdBy` or `totalAmount` in a create payload | DTO whitelist + forbid unknown properties |
| **Credential exposure** | Database credentials or secrets shipped in the Flutter app | Secrets never leave the server; secret scanning in CI |
| **Inventory / financial tampering** | Editing a posted stock transaction to hide a shortage | Append-only ledger + audit log |
| **Authentication attacks** | Credential stuffing, brute force, token replay | Rate limiting, lockout, short-lived + revocable tokens (§5) |
| **Injection** | Hand-written SQL string concatenation in a report | Parameterised queries only |

---

## 2. The Five Mandatory Checks

Every protected operation verifies, in this order:

```
1. Authentication        → who is the caller?                        → 401 if unknown
2. Authorization         → does the caller hold the permission?       → 403 if not
3. Resource access       → may this user act on THIS resource?        → 403 if not
4. Branch scope          → is the branch in the caller's scope?       → 403 if not
5. Stock location scope  → is the location in the caller's scope?     → 403 if not (ADR-013)
```

Skipping any of these because "the UI only shows what they're allowed" is the exact mistake that causes a
breach. **The client is not a security boundary.** Hiding a button is UX; the API is the control.

### 2.1 Zero Hardcoded Superuser Bypasses (CWE-285 Prevention)
**Never** write hardcoded superuser shortcuts in backend services, guards, token issues, or frontend models:
- ❌ `if (user.roleId === 'admin') return true;`
- ❌ `permissions: role.id === 'admin' ? ALL_CANONICAL : ...`
- ✅ All privileges—including those of the System Administrator—must be read dynamically from the database `role_permissions` table.
- ✅ De-privileging must immediately take effect upon subsequent token generation and API authorization checks.

---

## 3. Never Trust the Client

**Never** accept these from the request body, query string, headers or path:

- `branch_id` / `stock_location_id` as an *authority* (they may be *requested*, but must be **verified**
  against the caller's scope before use)
- `user_id` of the actor
- `role`, `permissions`, `is_admin`
- prices or totals that the server can compute itself
- `created_by`, `approved_by`, or any audit field
- any approval or status flag the business rules control

These are derived on the server from the verified access token and the user's assignments.

```ts
// ❌ FORBIDDEN — trusts a client-supplied scope
async list(query: ListDto) {
  return this.repo.findByLocation(query.stockLocationId);
}

// ✅ CORRECT — scope validated against the trusted context
async list(query: ListDto, ctx: RequestContext) {
  const locationId = this.resolveLocation(query.stockLocationId, ctx); // throws 403 if out of scope
  return this.repo.findByLocation(locationId);
}
```

If a client *requests* a branch (a legitimate UI action), validate it:

```ts
if (!ctx.branchIds.includes(dto.branchId)) {
  throw new BranchOutOfScopeError(dto.branchId);   // 403
}
```

---

## 4. Secrets and Keys

| Secret | Where it may live | Where it must never live |
| --- | --- | --- |
| Supabase **service role** key | Backend environment only | Flutter app, web bundle, Git, logs, error responses |
| **Database connection string / credentials** | Backend environment only | **Never in Flutter** — explicit CTO direction |
| **JWT signing key** (ours — ADR-003) | Backend environment only | Client, Git, logs |
| Password hashing pepper (if used) | Backend environment only | Client, Git, logs |

Since authentication is ours (ADR-003), there is **no** Supabase client key of any kind in the Flutter app.
The client holds only its own access and refresh tokens.

Rules:

1. **The Flutter client never connects to PostgreSQL/Supabase directly for business data.** It calls our API.
2. No secrets in the repository. `.env` files are git-ignored; `.env.example` documents the variable names
   with empty values.
3. Secrets are injected by the environment/CI secret store.
4. CI runs a secret scanner; a hit blocks the pipeline.
5. Rotate any secret that has ever appeared in a log, a screenshot or a chat message — assume it is public.

---

## 5. Authentication — Owned by Our Backend (ADR-003)

**Supabase Auth is not used.** Authentication is implemented and owned by our NestJS backend, so the product
remains portable to another database, provider or infrastructure. Supabase/PostgreSQL is our database and
infrastructure only.

Because we own this code, the following are **mandatory**, not advisory:

| # | Control |
| --- | --- |
| 1 | Passwords hashed with **Argon2id** (recommended) or bcrypt at appropriate work factors, via a **vetted library**. Never MD5, never bare SHA, **never a hand-rolled scheme** |
| 2 | Passwords never logged, never returned by any endpoint, never in an audit before/after snapshot |
| 3 | Signed JWT access tokens, **short-lived**; refresh tokens **rotated on use** and **revocable server-side** so logout genuinely invalidates |
| 4 | The backend **verifies signature, `exp`, `iss`, `aud` on every request**. It never decodes without verifying |
| 5 | Token signing keys live in the backend environment only, and are rotatable |
| 6 | Login rate limiting and account lockout, applied per account **and** per source address |
| 7 | Password reset via single-use, expiring, non-guessable tokens; the flow never reveals whether an account exists |
| 8 | Timing-safe credential comparison; **identical response** for "unknown user" and "wrong password" |
| 9 | All auth events audited — success, failure, lockout, password change, reset, revocation — **without** the attempted password |
| 10 | Tokens stored in secure platform storage on the client; never plain shared preferences on mobile, never `localStorage` on web where an XSS can read them |

> **"We own authentication" does not mean "we invent cryptography."** Hashing and token signing use
> maintained, vetted libraries. What we own is the *flow*. Writing your own hash function or token format is
> forbidden.

Because a defect here compromises every other module, the auth module requires **senior review** and may not
be implemented by a fresher unsupervised.

**A valid token proves identity only.** It says nothing about what the user may do.

---

## 6. Authorization — Configurable RBAC (ADR-004)

- **RBAC with granular permissions.** Roles are collections of permissions; code checks **permissions**,
  never role names.

  ```ts
  // ❌ cannot work — roles are customer-defined, so we do not know their names
  if (user.role === 'admin') { ... }

  // ✅ correct
  @RequirePermission('purchase.create')
  ```

- **Roles are created by the client's organization.** **We ship no fixed or default role list** (no Admin,
  no Manager, no Accountant). Role-name checks are therefore not merely brittle — they are impossible.
- Permissions are **granular**: read, create, update and delete are separate grants, not one "manage" right.
- Permission naming: `<module>.<action>` — `vendor.create`, `vendor.delete`, `stock.adjust`,
  `purchase.approve`, `role.update`, `user.assign-role`.
- **Roles and Permissions have full CRUD in the product**, itself permission-controlled:
  create / view / update / delete roles, assign permissions to roles, assign roles to users.
  Additional rules:
  - every role/permission change is **audited** (actor, before, after);
  - the **lockout guard** — the system must refuse any operation that would leave the organization with no
    user able to manage roles and users.
- **Deny by default.** An endpoint with no permission declared must fail closed, not open. The global guard
  requires an explicit decorator; endpoints intentionally public are marked `@Public()` and reviewed.
- Authorization is enforced **server-side**. Hiding a menu item in Flutter is UX, not security.
- **Authentication does not imply authorization.** Every protected endpoint checks a permission, even ones
  "only admins would ever see".

### 6.1 Response codes

| Situation | Response | Why |
| --- | --- | --- |
| No / invalid / expired token | `401 UNAUTHENTICATED` | Caller is unknown |
| Valid token, missing permission | `403 PERMISSION_DENIED` | Caller is known, action refused |
| Resource exists, outside the caller's branch scope | `403 BRANCH_OUT_OF_SCOPE` | Known to exist; access denied |
| Resource exists, outside the caller's stock-location scope | `403 STOCK_LOCATION_OUT_OF_SCOPE` | Known to exist; access denied |
| Resource does not exist | `404 NOT_FOUND` | Genuinely not found |

> **Changed 2026-08-29 (ADR-014).** The previous rule returned **`404`** for a resource belonging to another
> *tenant*, so as not to confirm that another customer's record existed. That concern does not apply in a
> single-client deployment: within one organization a user may legitimately know a record exists while being
> denied access to it. **`403` is now correct** for an existing resource the user may not act on, and `404`
> means genuinely not found. Do not carry the old `404` convention into new code or tests.

---

## 7. Input Validation

- Every endpoint has a **DTO** with `class-validator` decorators.
- The global `ValidationPipe` runs with:
  ```ts
  new ValidationPipe({
    whitelist: true,             // strip unknown properties
    forbidNonWhitelisted: true,  // reject unknown properties outright
    transform: true,
  })
  ```
  `whitelist` is what stops mass assignment: a client sending `{"companyId": "...", "isApproved": true}` has
  those fields stripped before they can reach a repository.
- Validate types, ranges, lengths, formats (UUID, email, GST format), and enum membership.
- Validate **business** rules in the domain layer, not in the DTO (a DTO cannot know whether a vendor exists).
- Never build SQL by string concatenation. Parameterised queries only.
- Sanitise/escape anything rendered into PDF/Excel exports or HTML.
- Enforce request size limits and pagination limits (`API_CONVENTIONS.md` §5).

---

## 8. Data Protection

- **In transit:** HTTPS/TLS everywhere. No plaintext HTTP, including internal calls.
- **At rest:** database encryption as provided by Supabase; sensitive columns reviewed case by case.
- **PII:** vendor/customer contact details are personal data. Do not log them, do not include them in error
  messages, do not send them to third-party services without approval.
- **Logs:** never log tokens, passwords, full request bodies containing PII, or connection strings.
- **Error responses:** never include stack traces, SQL, driver messages or internal paths.

---

## 9. Audit Requirements

Security-relevant events must be recorded in the audit log with actor, timestamp, IP and outcome:

- Login success and failure
- Permission denied (403) events
- Role or permission assignment changes
- User invited, deactivated or removed
- Master data create / update / **delete with reason**
- Any stock adjustment (who, why, before/after)
- Approval actions
- Export of data

Audit records are **append-only**. See `docs/architecture/LOGGING_AND_AUDIT.md`.

---

## 10. Security Testing Is Mandatory

Per `TESTING_RULES.md` §3.3, every protected endpoint ships with:

1. Unauthenticated request → `401`
2. Authenticated but **missing permission** → `403`
3. **Unauthorized access to a protected resource** → `403` (an existing resource the caller may not act on)

Plus, for anything writing data:

4. Mass-assignment attempt (`isApproved`, `createdBy`, `totalAmount` in the payload) → the field is ignored
   or rejected
5. Out-of-scope branch / stock location → `403`

A PR adding a protected endpoint without these tests is rejected.

> **Changed 2026-08-29:** item 3 was previously "cross-tenant access attempt → `404`". The project is not
> multi-tenant (ADR-014), so **do not write tenant-isolation tests.** Test resource-level authorization
> instead — that is the threat that actually exists here.

---

## 11. Security Patterns in the Existing Implementation

The existing Flutter implementation is **retained** as project work (ADR-010). It predates this security
model, so its patterns are listed here to make one thing unambiguous: **nothing in `lib/` today may be
treated as a security reference for new code.**

| Pattern | Location | Where the real thing goes |
| --- | --- | --- |
| No authentication — login screen is cosmetic | `lib/features/auth/screens/login_screen.dart` | Backend auth module, Phase 0 task 6 (ADR-003) |
| No authorization model; `role` is a display `String` | `lib/core/models/user_model.dart` | Configurable RBAC, Phase 0 task 7 (ADR-004) |
| No branch / stock-location scope on any model | `lib/core/models/*` | Phase 0 task 8 (ADR-013) |
| All data in a client-side in-memory store | `lib/shared/services/mock_database_service.dart` | The real API, per feature, as endpoints land |
| Document numbers generated on the client | `lib/core/utils/id_generator.dart` | Server-side numbering (`DATABASE_RULES.md` §13) |

These are **not defects to file and not work to schedule on sight.** The implementation was never intended to
be a secure production system, and per ADR-010 it is neither frozen nor rewritten speculatively — it changes
when a Jira task brings that area into scope. The binding rule is that **new code must not reproduce these
patterns.**

---

## 12. Incident Response

A suspected **authorization bypass, credential compromise, or inventory/financial tampering is a P0**:

1. Stop the deployment pipeline.
2. Notify the Security Architect and Product Owner immediately.
3. Preserve logs and audit records — do not clean up.
4. Determine scope from the audit log: which records, which actors, over what period.
5. Fix, **add a regression test that reproduces the breach**, then deploy.
6. Post-mortem, with an ADR or rule update if the design allowed it.

Never attempt to quietly patch a security defect. For inventory tampering, remember that the ledger is
append-only (ADR-005) — the history needed to reconstruct what happened should still be intact, and
corrections are posted as new transactions rather than by editing the past.
