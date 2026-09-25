# ADR-007: REST Conventions and a Standard Response Envelope

- **Status:** **Accepted** (approved 2026-08-29)
- **Date:** 2026-08-28
- **Deciders:** Backend Architect, Flutter Architect
- **Phase:** 0
- **Related:** `API_CONVENTIONS.md`, ADR-011

## Context

A Flutter client on four form factors consumes one backend. The team is mainly freshers, and inconsistent API
shapes are a reliable source of client-side bugs: every endpoint that returns data differently becomes a new
special case in the client.

The system deals with money and quantities, where JSON number handling is a real correctness hazard.

## Problem

What are the API style, the response shape, and the transport representation of money and quantity?

## Options

### Option 1 — REST with bare responses (return the object or array directly)
**Pros:** least ceremony; smallest payloads.
**Cons:** nowhere to put pagination metadata or a correlation id; adding either later is a breaking change;
error and success shapes differ per endpoint.

### Option 2 — REST with a `{ data, meta }` / `{ error }` envelope
**Pros:** one parsing path in the client; pagination and correlation id have a home; errors are uniform and
machine-readable via a stable `code`.
**Cons:** slightly larger payloads; one extra level of nesting.

### Option 3 — GraphQL
**Pros:** flexible querying; no over-fetching.
**Cons:** authorization must be enforced per field, which multiplies the access-control surface;
rate limiting and query-cost control are extra work; the team has no GraphQL experience; caching and
tooling are more complex. The client is a single first-party app whose queries we control anyway.

## Decision

We will adopt **Option 2**: REST under `/api/v1`, with

- success: `{ "data": …, "meta": { correlationId, pagination? } }`
- error: `{ "error": { code, message, details?, correlationId, timestamp } }`
- `camelCase` JSON fields; ISO 8601 UTC timestamps
- **money and quantity transported as strings** (`"1234.50"`), never JSON numbers
- `UPPER_SNAKE_CASE` enums matching the business source document's terminology
- mandatory pagination on all list endpoints, `pageSize` capped at 100
- the `403` vs `404` distinction as a security control (`SECURITY_RULES.md` §6.1)

## Reason

The envelope pays for itself the first time we need pagination or a correlation id — both of which we need
immediately. A stable machine-readable `code` lets the Flutter client branch on errors without string-matching
a localisable message.

Money as a string is the decision most likely to be questioned, so state it plainly: JSON numbers are
IEEE 754 doubles in Dart and JavaScript. `0.1 + 0.2 !== 0.3`. Transporting `1234.50` as a number invites the
client to parse it into a `double` and print `1234.4999999999998` on an invoice. A string forces the client to
use a decimal type. See ADR-011.

GraphQL was rejected on security grounds as much as on complexity: per-field authorization across a
an ERP with granular permissions is a much larger surface to get right than per-endpoint authorization.

## Consequences

**Positive:** one client parsing path; uniform errors; pagination and tracing built in; money is
representation-safe end to end; API versioning is straightforward.

**Negative:** every response is wrapped, so ad-hoc `curl` output is slightly noisier; developers must remember
to unwrap `data`; string money requires a decimal type on both sides rather than naive arithmetic.

**Follow-up actions:**
- Response/error envelope helpers in `core/common`.
- The global exception filter emits the error envelope (`docs/architecture/ERROR_HANDLING.md`).
- A Flutter `ApiClient` that unwraps envelopes and maps `code` to typed `Failure`s.
- OpenAPI generation for non-production environments.
