# ADR-003: Authentication Owned by Our NestJS Backend

- **Status:** **Accepted** (approved 2026-08-29)
- **Date:** 2026-08-28 · **Revised:** 2026-08-29
- **Deciders:** CTO, Security Architect, Backend Architect
- **Phase:** 0
- **Related:** ADR-004, **ADR-014**, `docs/architecture/AUTHENTICATION_AUTHORIZATION.md`, `SECURITY_RULES.md`

> **Revision note (2026-08-29).** The originally proposed decision was to delegate authentication to
> **Supabase Auth**. That proposal was **not approved**. The CTO directed that authentication be owned by our
> own backend so the product is not coupled to Supabase and can be migrated to another database, provider or
> infrastructure with minimal impact. This ADR has been rewritten to record the approved decision. The
> superseded reasoning is preserved in §"Why the original proposal was rejected".
>
> **Note (2026-08-29, ADR-014).** The SaaS scope was later withdrawn. **This decision is unaffected and
> remains in force** — the portability argument applies to a single-client deployment just as strongly, and
> arguably more so, since each future client gets its own instance on possibly different infrastructure.

## Context

The product is an ERP for one client, deployed as a dedicated instance (ADR-014). The database is PostgreSQL
hosted on Supabase, and the client is Flutter across mobile, web and desktop.

Two constraints drive this decision:

1. **Portability.** Supabase is our current *hosting choice for PostgreSQL*. The business requires that this
   choice remain reversible — a future move to another managed Postgres, a self-hosted cluster, or another
   cloud must not require re-implementing user identity, re-issuing every credential, or migrating an
   external identity store.
2. **Control.** Authentication is where user identity originates. ADR-004 (authorization) depends entirely
   on the claim "this request is user X, holding these permissions, in this scope". That claim must be
   produced by code we own, test and can reason about.

The charter additionally forbids exposing database credentials or secrets to the Flutter client.

## Problem

Who owns user identity, credential storage and token issuance — an external provider, or our backend?

## Options

### Option 1 — Supabase Auth as the authentication authority *(originally proposed, rejected)*
**Pros:** no password cryptography written by us; reset and verification flows provided; fastest to stand up.
**Cons:** couples the product to Supabase at its most load-bearing point; migrating providers later would mean
migrating every user identity and every credential; the user lifecycle must be kept consistent across two
systems (Supabase Auth and our `users` table), which is a permanent source of drift; provider outages affect
login; provider semantics constrain our session model.

### Option 2 — Authentication owned by our NestJS backend
**Pros:** portability — moving database or infrastructure does not touch identity; one system of record for
users, so no cross-system drift; full control over the session model, token contents, lifetimes
and revocation; no dependency on a third-party auth service being available.
**Cons:** we own security-critical code (hashing, token issuance, refresh rotation, rate limiting, reset
flows); this must be built correctly and tested rigorously; more Phase 0 work.

### Option 3 — A third-party identity provider (Auth0, Cognito, Keycloak)
**Pros:** mature; offloads much of Option 2's risk.
**Cons:** re-introduces exactly the coupling Option 1 was rejected for, plus recurring per-user cost;
still requires our own `users` and membership tables; adds an external dependency to every login.

## Decision

We will adopt **Option 2**. **Authentication is implemented and owned by our NestJS backend.**

The backend owns:

| Responsibility | Detail |
| --- | --- |
| **User authentication** | `users` is our table; identity lives in our database |
| **Password hashing** | A vetted algorithm (**Argon2id** recommended, `bcrypt` acceptable) via a maintained library. **We never write our own cryptography** |
| **Login / session / token handling** | Our endpoints issue our tokens, signed with our key |
| **Token validation** | Every request verified by our guard |
| **Refresh and revocation** | Rotating refresh tokens, revocable server-side |
| **Authentication security logic** | Rate limiting, lockout, reset flows, audit of auth events |

**Supabase / PostgreSQL is used strictly as database and infrastructure.** Supabase Auth is **not** used as
the authentication authority. No business authentication logic lives outside our backend.

Unchanged from the original ADR, and reaffirmed:

- The Flutter client sends `Authorization: Bearer <token>` to **our** API and never queries the database
  directly for business data.
- **Database credentials, connection strings and service-role keys are never exposed to Flutter.**
- Permissions are **not** read from client-influenced token metadata; they are resolved server-side per
  request (ADR-004).

## Reason

Portability is the decisive factor, and it is a business requirement rather than an engineering preference:
each future client gets a separate instance, and infrastructure choices made now must not become irreversible.
Authentication is the single worst place to accept vendor coupling, because migrating identity later means
migrating every user credential — an operation that is disruptive to the whole client at once.

The trade-off is real and is accepted: we take on security-critical code that Option 1 would have avoided.
This is mitigated, not ignored — see the mandatory controls below. Note that "we own authentication" does
**not** mean "we invent cryptography": password hashing and token signing use vetted, maintained libraries.
What we own is the *flow*, not the primitives.

Option 3 was rejected because it solves Option 2's risk by re-creating Option 1's coupling, at additional
per-user cost.

## Mandatory controls (non-negotiable consequences of this decision)

Because we now own authentication, the following are **required**, not optional:

1. Passwords hashed with Argon2id (or bcrypt) at appropriate work factors. **Never** MD5, SHA-family alone,
   or any hand-rolled scheme.
2. Passwords never logged, never returned by any endpoint, never included in an audit `before`/`after`
   snapshot.
3. Access tokens short-lived; refresh tokens rotated on use and revocable server-side (a revocation store, so
   logout genuinely invalidates).
4. Token signing keys held in the backend environment only, rotatable.
5. Login rate limiting and account lockout, with both applied per account **and** per source address.
6. All authentication events audited: success, failure, lockout, password change, reset, token revocation —
   without the attempted password.
7. Password reset via single-use, expiring, non-guessable tokens; reset does not reveal whether an account
   exists.
8. Timing-safe credential comparison; identical response for "unknown user" and "wrong password".
9. A dedicated security test suite for the auth module — this is the one module where the tests protect every
   other module.

## Consequences

**Positive:** the product is portable across database providers and infrastructure; one system of record for
users, eliminating cross-system drift; full control over the session model, token contents,
lifetimes and revocation; no third-party dependency in the login path.

**Negative / accepted costs:**
- We carry the security burden of authentication code, on a team of freshers. **This module requires senior
  review and cannot be delegated to a fresher unsupervised.**
- More Phase 0 work than delegating: login, refresh, logout, reset, lockout, revocation store.
- Email delivery (verification, reset) becomes our concern and needs a provider decision — a follow-up ADR.
- A vulnerability here is a whole-product vulnerability, so the auth module warrants periodic security review.

**Follow-up actions:**
- Phase 0 task 6, expanded: `users` table with `password_hash`, login/refresh/logout endpoints, token
  verification guard, `RequestContext`, revocation store, rate limiting and lockout.
- Record the chosen hashing and JWT libraries in this ADR once selected (ADR required for new dependencies).
- A follow-up ADR for transactional email (verification and reset delivery).
- Define token lifetimes and the refresh rotation policy.
- Define the company-switch flow: switching the active company **re-issues a token**; it is never a
  client-supplied header.

## Why the original proposal was rejected

Recorded so the decision is not revisited without new information. The original ADR argued that delegating to
Supabase Auth avoided writing security-critical code for no product differentiation. That reasoning was sound
in isolation but was outweighed by the portability requirement: it optimised for build speed at the cost of a
coupling the business is not willing to accept. The mitigation for the risk it identified is the mandatory
controls list above, not delegation.
