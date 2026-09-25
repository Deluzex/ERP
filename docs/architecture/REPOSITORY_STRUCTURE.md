# Repository Structure

**Status:** Proposed (Phase 0) · **Decision:** ADR-001 · **Related:** `ARCHITECTURE.md`

---

## 1. Current Structure (as inspected)

```
ERP/
├── .metadata, analysis_options.yaml, pubspec.yaml   ← a Flutter app AT THE ROOT
├── README.md                                        ← "#Deluzex ERP" (one line)
├── android/ ios/ linux/ macos/ web/ windows/
├── lib/                                             ← ~11,700 lines of Dart
│   ├── app/  core/  features/  shared/
├── test/widget_test.dart                            ← the only test
└── docs/
    └── ERP PROJECT — MASTER INSTRUCTIONS.md
```

Observations:

- `pubspec.yaml` declares `name: frontend`, but the Flutter project **is** the repository root. The name
  already anticipates a frontend/backend split that the layout does not have.
- There is no backend, no database, no migrations, no CI.
- All data lives in `lib/shared/services/mock_database_service.dart`.

---

## 2. Target Structure (ADR-001)

```
ERP/
├── PROJECT_RULES.md  ARCHITECTURE.md  AI_CODING_RULES.md  …      ← governance at the root
├── docs/
│   ├── business/            # business source documents, glossary, open questions
│   ├── architecture/        # cross-cutting architecture deep-dives
│   ├── modules/
│   │   └── stock-management/
│   └── decisions/           # ADRs
├── apps/
│   ├── frontend/            # the Flutter app (moved from the root)
│   │   ├── lib/  test/  android/ ios/ web/ …
│   │   └── pubspec.yaml
│   └── backend/             # NestJS + TypeScript  (NEW)
│       ├── src/
│       │   ├── core/        # auth, access, database, errors, logging, audit, common
│       │   └── modules/     # one folder per business module
│       ├── test/e2e/
│       ├── migrations/
│       └── package.json
├── .github/workflows/       # CI  (NEW)
└── README.md
```

### Why move the Flutter app into `apps/frontend/`

1. The backend needs a home, and burying it under a Flutter project root is worse than a symmetric layout.
2. CI can run frontend and backend pipelines independently on path filters.
3. `pubspec.yaml` already says `name: frontend` — the move makes the repository match the intent.
4. Documentation and governance stay at the repository root where every tool and every developer finds them.

### Cost of the move

- Every relative path in tooling and IDE configuration changes once.
- Git history for the Flutter files is preserved if the move is done with `git mv` in a **single dedicated
  commit** that changes nothing else.

Do it early — the cost grows with every file added.

---

## 3. Migration Plan

Execute as **one chore ticket**, one PR, no behaviour change:

| Step | Command / action |
| --- | --- |
| 1 | Branch `chore/ERP-102-repo-restructure` |
| 2 | `mkdir -p apps/frontend` |
| 3 | `git mv lib test android ios linux macos web windows pubspec.yaml pubspec.lock analysis_options.yaml .metadata apps/frontend/` |
| 4 | Move Flutter-specific entries in `.gitignore` under `apps/frontend/` paths |
| 5 | Verify: `cd apps/frontend && flutter pub get && flutter analyze && flutter test` |
| 6 | `mkdir -p apps/backend` (scaffolded in the next ticket) |
| 7 | Update `README.md` with the new layout |
| 8 | PR — reviewed as a pure move: **the diff must contain no content changes** |

Do not combine this with any feature work. A restructure PR that also changes code is unreviewable.

---

## 4. Backend Layout

```
apps/backend/src/
├── main.ts
├── app.module.ts
├── core/
│   ├── auth/         # token verification, RequestContext, guards, @RequirePermission, @Ctx
│   ├── access/       # permission guard, scope resolution, BaseRepository
│   ├── database/     # connection, UnitOfWork/transaction manager
│   ├── errors/       # DomainError hierarchy, GlobalExceptionFilter
│   ├── logging/      # structured logger, correlation id middleware
│   ├── audit/        # AuditLogger
│   └── common/       # pagination, Money value object, decimal helpers
└── modules/
    ├── companies/    # Phase 0
    ├── branches/     # Phase 0
    ├── warehouses/   # Phase 0
    ├── users/        # Phase 0
    ├── auth/         # Phase 0
    ├── vendors/          # Phase 1
    ├── raw-materials/    # Phase 1
    ├── finished-products/# Phase 1
    ├── purchases/        # Phase 1
    └── inventory/        # Phase 1  (stock transactions + balances)
```

Each module: `api/` `application/` `domain/` `infrastructure/` `__tests__/` (`ARCHITECTURE.md` §3.3).

**No folders for Phase 2+ modules until that phase starts.** An empty `production/` folder is an invitation.

---

## 5. Frontend Layout (target)

```
apps/frontend/lib/
├── app/            # bootstrap, router, theme, constants          (exists)
├── core/
│   ├── network/    # api client, interceptors, error mapping      (new)
│   ├── errors/     # Failure types                                (new)
│   ├── widgets/    # design system                                (exists)
│   └── utils/      # validators, formatters                       (exists)
└── features/<feature>/
    ├── presentation/   application/   domain/   data/
```

Migration from the current two-layer implementation is feature-by-feature, driven by Jira tickets, and only once the backend API for that
feature exists (ADR-010).

---

## 6. Root-Level Files

| File | Purpose |
| --- | --- |
| `PROJECT_RULES.md` … `GIT_WORKFLOW.md` | Governance — deliberately at the root so no one can miss them |
| `README.md` | What this is, how to run it, where the rules live |
| `.github/workflows/*.yml` | CI pipelines with path filters per app |
| `.gitignore` | Combined ignores for both apps |
| `.env.example` | Committed with empty values; real `.env` never committed |

---

## 7. Naming Conventions Across the Repository

| Item | Convention | Example |
| --- | --- | --- |
| Directory | `kebab-case` | `raw-materials/`, `stock-management/` |
| TypeScript file | `kebab-case.<role>.ts` | `create-purchase.use-case.ts` |
| TypeScript class | `PascalCase` | `CreatePurchaseUseCase` |
| Dart file | `snake_case.dart` | `create_purchase_screen.dart` |
| Dart class | `PascalCase` | `CreatePurchaseScreen` |
| Test file (TS) | `*.spec.ts`, `*.int-spec.ts`, `*.e2e-spec.ts` | |
| Test file (Dart) | `*_test.dart` | |
| Migration | `<timestamp>_<verb>_<subject>.sql` | `20260901120000_create_companies.sql` |
| ADR | `ADR-NNN-kebab-title.md` | `ADR-014-single-client-dedicated-deployment.md` |
| Docs | `UPPER_SNAKE_CASE.md` | `BUSINESS_RULES.md` |
