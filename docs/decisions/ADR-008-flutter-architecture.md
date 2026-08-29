# ADR-008: Flutter Layered Architecture with Riverpod

- **Status:** **Accepted** (approved 2026-08-29)
- **Date:** 2026-08-28
- **Deciders:** Flutter Architect, Solution Architect
- **Phase:** 0
- **Related:** `FLUTTER_RULES.md`, ADR-010

## Context

The existing Flutter prototype is a **two-layer** application: screens under `lib/features/*/screens/` read
directly from `MockDatabaseService`, a 1,300-line in-memory `ChangeNotifier`. Riverpod 2.5 is already a
dependency and is used for a small set of providers (`databaseServiceProvider`, navigation, filters,
sidebar state).

The charter mandates `Presentation → State Management → Domain → Data → API Client → Backend`, and forbids
business logic in the UI.

## Problem

Which state management approach and which layering do we standardise on for the production Flutter app?

## Options

### Option 1 — Keep the current pattern (screens read a shared service directly)
**Pros:** no migration; fastest to add the next screen.
**Cons:** untestable without pumping widgets; no seam to swap the mock for a real API; business logic drifts
into `build()`; violates the mandated architecture.

### Option 2 — Riverpod + full layering (presentation / application / domain / data)
**Pros:** already a dependency, so no new package; compile-safe dependency injection; providers are
overridable in tests, which makes a fake repository trivial; the domain layer is pure Dart and unit-testable
without `flutter_test`; matches the mandated architecture exactly.
**Cons:** more files per feature; freshers must learn provider lifecycles.

### Option 3 — BLoC + full layering
**Pros:** very explicit event/state modelling; widely documented.
**Cons:** significantly more boilerplate per feature; would mean removing Riverpod, which is already in use;
no advantage that matters for this product.

## Decision

We will adopt **Option 2**: Riverpod as the single state manager, with four layers per feature:

```
features/<feature>/presentation | application | domain | data
```

- `domain/` is **pure Dart** — no Flutter imports — and defines the repository *interface*.
- `data/` implements the repository against the REST API, with DTOs and mappers.
- `application/` holds Riverpod notifiers; it coordinates and holds UI state, never business rules.
- `presentation/` renders state and dispatches intents.

No second state manager may be introduced.

## Reason

Riverpod is already present, so this is the only option that adds zero dependencies. Its override mechanism
is the specific feature we need: a widget test can substitute a fake repository in one line, which is what
makes the testing rules practical rather than aspirational. BLoC would deliver the same architecture with more
ceremony and a package churn we cannot justify.

The layering is not optional under the charter; the only real decision here is the state manager, and the
cheapest correct answer is the one already installed.

## Consequences

**Positive:** testable without a running backend; a clean seam to replace the mock with the API feature by
feature; consistent structure across features; no new dependency.

**Negative:**
- More files per feature than the current prototype — freshers will initially find this slower.
- Provider lifecycle mistakes are a real hazard; specifically, **all provider state must be invalidated on
  logout and on a scope change**, or stale data appears in the UI under the wrong scope.
- The existing screens do not follow this structure and must be migrated (ADR-010).

**Follow-up actions:**
- Build `core/network/` (API client, interceptors, envelope unwrapping) and `core/errors/` (`Failure` types).
- Migrate one feature (Vendors) end to end as the reference implementation before migrating others.
- Add a global "invalidate all on auth/company change" mechanism.
- Test layout: `test/unit/`, `test/widget/`, `test/helpers/`.
