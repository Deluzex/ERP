# ADR-001: Monorepo Structure — `apps/frontend` + `apps/backend`

- **Status:** **Accepted** (approved 2026-08-29)
- **Date:** 2026-08-28
- **Deciders:** Solution Architect, CTO
- **Phase:** 0
- **Related:** `docs/architecture/REPOSITORY_STRUCTURE.md`

## Context

The repository today **is** a Flutter project: `pubspec.yaml`, `analysis_options.yaml`, `lib/`, `test/`,
`android/`, `ios/`, `web/` and the rest all sit at the repository root. The pubspec declares
`name: frontend`, which already anticipates a split that the folder layout does not have.

The product requires a NestJS backend and a PostgreSQL schema with migrations. Neither exists yet. The team
is mainly freshers, so the layout must make "where does this file go?" obvious without asking.

## Problem

Where do the backend, the migrations and the CI configuration live, given that a Flutter app currently
occupies the repository root?

## Options

### Option 1 — Separate repositories (frontend repo, backend repo)
**Pros:** clean separation; independent pipelines and access control.
**Cons:** an API contract change spans two repositories and two PRs; a fresher can merge a breaking backend
change without seeing the client it breaks; shared documentation duplicates or drifts; local setup doubles.

### Option 2 — Keep Flutter at the root, put the backend in `backend/`
**Pros:** no move, zero disruption today.
**Cons:** asymmetric and confusing — the root is simultaneously "the repository" and "the Flutter app";
root-level tool configs (`analysis_options.yaml`, `pubspec.yaml`) apply to only half the codebase; CI path
filters become awkward; the layout misrepresents the system as frontend-first.

### Option 3 — Monorepo with `apps/frontend` and `apps/backend`
**Pros:** symmetric and self-explanatory; one PR can change API and client together with the contract
visible in the diff; shared docs and ADRs at the root; per-app CI via path filters; matches the existing
`name: frontend`.
**Cons:** a one-time move of every Flutter file; local paths and IDE configs change once.

## Decision

We will adopt **Option 3**. The Flutter application moves to `apps/frontend/`, the NestJS backend is created
at `apps/backend/`, and governance documentation plus ADRs remain at the repository root.

## Reason

Maintainability and correctness of the **API contract** dominate here. In an ERP the expensive defects live
at the boundary between client and server; keeping both in one commit makes that boundary reviewable. The
move is cheapest now — it gets more expensive with every file added, and we are at the earliest possible
moment.

Option 1 was rejected because contract drift across repositories is precisely the failure mode a fresher team
is least equipped to catch. Option 2 was rejected because an ambiguous root is a permanent source of "where
does this go?" questions.

## Consequences

**Positive:** a clear home for every artefact; atomic contract changes; independent CI pipelines; the docs
tree is discoverable from the root.

**Negative:** one disruptive move commit; everyone must re-point their IDE; CI must be written with path
filters from day one; developers now run two toolchains locally.

**Follow-up actions:**
- Ticket `chore/ERP-102-repo-restructure` — a pure `git mv` with **no content changes**, per
  `docs/architecture/REPOSITORY_STRUCTURE.md` §3.
- Scaffold `apps/backend` in the following ticket.
- Update `README.md` with setup instructions for both apps.
