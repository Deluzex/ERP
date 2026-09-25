# ADR-009: Mandatory Test-Driven Development for Backend Work

- **Status:** **Accepted** (approved 2026-08-29)
- **Date:** 2026-08-28
- **Deciders:** CTO, QA Lead, Backend Architect
- **Phase:** 0
- **Related:** `TESTING_RULES.md`, `DEVELOPMENT_WORKFLOW.md`, ADR-002, ADR-005

## Context

The charter mandates that backend development be strictly TDD-oriented, with an observed RED phase before
implementation.

The team is mainly freshers. The product two most dangerous failure modes — an authorization bypass and a
wrong stock balance — are both **invisible in the UI**. Manual QA cannot catch either: the screen looks
correct in both the working and the broken case.

The repository currently has exactly one test (a Flutter smoke test) and no backend test infrastructure.

## Problem

Is TDD mandatory, advisory, or applied selectively — and how is it enforced rather than merely encouraged?

## Options

### Option 1 — Tests written after implementation ("test-last")
**Pros:** feels faster; familiar to most freshers.
**Cons:** tests are written by reading the implementation, so they assert what the code does rather than what
the business requires; a test that never failed has never been validated; the security and tenancy cases are
exactly the ones that get skipped when the feature "already works".

### Option 2 — TDD advisory, enforced by code review
**Pros:** flexible; less process friction.
**Cons:** unenforceable in practice — a reviewer cannot tell from a diff whether the test or the code was
written first; under deadline pressure the advisory rule is the first thing dropped.

### Option 3 — TDD mandatory, with the RED run recorded as PR evidence
**Pros:** the RED output is objective proof that the test can fail and therefore tests something real;
forces the developer to state expected behaviour before becoming attached to an implementation; makes the
security and tenancy cases part of the design step rather than an afterthought.
**Cons:** slower per ticket, especially at first; requires test infrastructure up front; the evidence
requirement adds process weight.

## Decision

We will adopt **Option 3**. The seven-step cycle in `TESTING_RULES.md` §2 is mandatory for every new API,
use case, business rule or important backend change:

```
Understand → Define scenarios → RED → Implement → GREEN → Refactor → Regression
```

- The **RED output is pasted into the PR description**. A PR without it is rejected without review.
- If a new test passes before implementation, the test is wrong and must be fixed.
- Weakening, skipping or deleting a test to achieve green is a process violation.
- Every protected endpoint ships with 401 / 403-permission / 403-out-of-scope tests (ADR-014: **not**
  cross-tenant tests — the project is single-client).
- Integration tests run against a **real PostgreSQL**, because the constraints and triggers are part of
  what is under test.

## Reason

Business correctness and security are our top two priorities, and both depend on failure modes that only
automated tests can observe. The RED-evidence requirement is the part that makes this real: it is the only
mechanism that distinguishes genuine TDD from a claim of TDD, and it costs a copy-paste.

Option 1 was rejected because test-last systematically under-tests exactly the cases we most need. Option 2
was rejected because an unenforceable rule on a fresher team under deadline is not a rule.

We accept that this is slower per ticket. In an ERP, a wrong stock figure discovered by the customer costs
more than every hour TDD will ever spend.

## Consequences

**Positive:** tests verify behaviour rather than implementation; security cases are designed in, not bolted
on; refactoring becomes safe; the RED/GREEN commit history documents intent; freshers learn to state
requirements before coding.

**Negative:**
- Slower initial velocity; expect complaints in the first sprints.
- Test infrastructure (Jest, Supertest, a test database, factories, role/scope fixtures) must exist **before**
  the first feature ticket — it is Phase 0 task 4.
- Integration tests against a real database are slower than in-memory substitutes; mitigate with transaction
  rollback per test and parallelisation, not by faking the database.
- The evidence requirement adds process weight to every PR.

**Follow-up actions:**
- Phase 0 task 4: test harness and fixtures.
- Coverage floors and CI gates (`GIT_WORKFLOW.md` §6).
- The PR template with the mandatory TDD Evidence section.
- A worked reference example (Vendors CRUD) that new developers can copy.
