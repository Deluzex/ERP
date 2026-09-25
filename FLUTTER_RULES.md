# FLUTTER_RULES.md — Flutter / Dart Standards

**Status:** Active · **Related:** `ARCHITECTURE.md` §4, ADR-008, ADR-010, `API_CONVENTIONS.md`

---

## 0. The Rule That Governs Everything Below

**ADR-010 (approved):** the existing Flutter implementation is **retained** — not deleted, not frozen.

| | |
| --- | --- |
| **New code** | Must follow the layering in §2 and every rule in this document |
| **Existing code** | Stays as it is. Not rewritten unless a specific Jira task requires it |
| **Existing design system** | Promoted and reused — `lib/core/widgets/`, `lib/app/theme/` |
| **Assumption to avoid** | "It's in `lib/`, so it must be the pattern to follow." It predates these rules |

A reviewer's question for any new file is *"does this follow ADR-008?"* — never *"does this look like the
file next to it?"*

---

## 1. Current State (be honest about it)

The repository contains a working Flutter implementation:

- `lib/app/` — bootstrap, theme, routing enum, constants — **good, keep**
- `lib/core/widgets/` — a reusable design-system widget set — **good, keep**
- `lib/core/utils/` — validators, formatters, id generator — keep validators/formatters; the client-side
  `id_generator` must not be used for business document numbers (`DATABASE_RULES.md` §13)
- `lib/core/models/` — plain models with **no `companyId`**, `double` money, free-text `role`
- `lib/features/*/screens/` — screens that read **directly** from `MockDatabaseService`
- `lib/shared/services/mock_database_service.dart` — a 1,300-line in-memory fake database

This is a two-layer app: **UI → fake data store**. The target is four layers (§2).

Per ADR-010 this code **stays**. What changes is where new work goes: new features are built in the layered
structure against the real API, and features migrate from the mock as their backend endpoints land — driven
by Jira tickets, not speculatively. Do not add new business logic to `MockDatabaseService`.

---

## 2. Target Layering

```
Presentation (Screens/Widgets)
  → State Management (Riverpod providers/notifiers)
    → Domain (entities, value objects, repository interfaces)   ← pure Dart
      → Data (repository implementations, DTOs, mappers)
        → API Client (HTTP, interceptors)
          → Backend
```

### Folder structure per feature

```
lib/features/<feature>/
├── presentation/     # screens, widgets. Dumb. Renders state, sends intents.
├── application/      # Riverpod notifiers/providers. UI state, no business rules.
├── domain/           # entities, value objects, repository *interfaces*, failures
└── data/             # repository *implementations*, DTOs, mappers to/from JSON
```

### Rules

1. **Presentation contains no business logic.** A widget may format a date or a currency for display. It may
   not decide whether a purchase is valid, compute a stock balance, or apply a discount rule.
2. **The domain layer imports no Flutter.** `import 'package:flutter/...'` in `domain/` is a review failure.
   Pure Dart means it is unit-testable without `flutter_test`.
3. **Presentation depends on the repository *interface***, never on the implementation. That is what makes a
   fake repository possible in widget tests.
4. **DTOs are not entities.** JSON shape belongs in `data/`. If the API renames a field, exactly one mapper
   changes.
5. **No direct database or Supabase access from the client.** Ever. See `SECURITY_RULES.md` §4.

---

## 3. State Management — Riverpod

Riverpod is the chosen state manager (already in `pubspec.yaml`, confirmed by ADR-008). Do not introduce
BLoC, GetX, Provider or `setState`-based architecture alongside it.

- Use `Notifier` / `AsyncNotifier` for feature state; `Provider` for dependencies; `StateProvider` only for
  trivial UI flags (a sidebar toggle is fine — the current `sidebarExpandedProvider` is an acceptable use).
- **Never put business rules in a provider.** A provider coordinates; the domain decides.
- Model async state explicitly with `AsyncValue` — every screen handles **loading**, **error** and **empty**,
  not just the happy path. An ERP list screen with no empty state and no error state is incomplete.
- Dispose/auto-dispose providers that hold request-scoped state so switching stock location or logging out cannot
  leak a previous user session data into the UI.

> ⚠️ **Session-change rule:** on logout — or on a change of the active branch / stock location — **all**
> affected cached provider state must be invalidated. Stale data rendered under a new scope misleads the user
> even when the API was correct.

---

## 4. Models, Money and Identifiers

| Concern | Rule |
| --- | --- |
| Money | Never `double`. Use a `Money` value object backed by `Decimal`, or transport as `String` and format for display. See ADR-011. |
| Quantity | Same — decimal, not `double`. |
| Ids | `String` UUIDs from the server. The client never invents a business id. |
| Document numbers | Server-generated. `lib/core/utils/id_generator.dart` must not be used for them. |
| Scope fields | Stock entities carry `stockLocationId` where the API returns it; the client never *sends* scope as authority. |
| Enums | Dart `enum` mapped explicitly from API strings, with a defined fallback for unknown values so an added server enum value does not crash old clients. |

Every entity gets `==`/`hashCode` (or uses a code-generated equatable pattern approved by ADR) so list
rebuilds and tests behave predictably.

---

## 5. Error Handling

```
HTTP error → ApiException (data layer)
           → Failure (domain layer)     ← typed: NetworkFailure, ValidationFailure,
                                          PermissionFailure, NotFoundFailure, ServerFailure
           → user-facing message (presentation)
```

- Widgets never see an HTTP status code.
- Map the standard error envelope (`API_CONVENTIONS.md` §6) into typed failures using the stable `code` field,
  never by string-matching the human message.
- Show actionable messages. "Something went wrong" is a last resort, and must still log the correlation id
  from the error envelope so support can trace it.
- `401` triggers the token refresh flow; a failed refresh logs the user out and clears all cached state.
- `403` shows a permission message — it never silently returns an empty screen.

---

## 6. Responsive / Adaptive UI

The product must work on smartphone, tablet, laptop and desktop.

Standard breakpoints (define once in `lib/app/constants/`, do not scatter magic numbers):

| Class | Width | Typical layout |
| --- | --- | --- |
| Compact (phone) | `< 600` | Single column, bottom nav, cards instead of tables |
| Medium (tablet) | `600–1023` | Two panes, collapsible rail |
| Expanded (laptop) | `1024–1439` | Sidebar + content |
| Large (desktop) | `>= 1440` | Sidebar + content + detail pane |

Rules:

- **Never** branch on `Platform.isAndroid` for layout — branch on available width via `LayoutBuilder`.
- Data tables do not survive a phone screen. Provide a card/list presentation in the compact class.
- Touch targets ≥ 48dp; keyboard navigation and shortcuts on desktop.
- Test at every breakpoint before marking a screen done.

---

## 7. Design System

`lib/core/widgets/` already contains `ErpButton`, `ErpDataTable`, `ErpHeader`, `ErpSidebar`,
`ErpStatusBadge`, `StatCard` and others. **Reuse them.**

- No inline colours, spacing or text styles. Use `app/theme/` tokens (`AppColors`, `AppSpacing`,
  `AppRadius`, `AppTextStyles`).
- A new shared widget goes in `core/widgets/` with a widget test.
- Do not fork an existing widget to make a one-off variant — extend it with a parameter, or justify the fork.

---

## 8. Testing (Flutter)

| Type | Scope | Required |
| --- | --- | --- |
| Unit — domain | entities, value objects, validators, mappers | **Mandatory** |
| Unit — application | notifier state transitions with a fake repository | **Mandatory** |
| Widget | screen renders loading/error/empty/data states | Required for new screens |
| Golden | design-system widgets | Recommended |

- Fake the repository **interface**; never hit a real network in a test.
- Every screen test covers **loading, error, empty and populated** states.
- Business calculations belong to backend tests as well — never test a business rule *only* in Flutter, since
  the client is not authoritative.

Current baseline: one smoke test in `test/widget_test.dart`. Target structure:

```
test/
├── unit/       # domain + application
├── widget/     # screens and design-system widgets
└── helpers/    # fakes, fixtures, pump helpers
```

---

## 9. Dart Standards

- Follow `analysis_options.yaml` (`flutter_lints`). CI runs `flutter analyze` with **zero** warnings tolerated.
- `const` constructors wherever possible.
- No business logic in `build()`.
- Keep widgets small; extract a widget when `build()` exceeds roughly one screen of code.
- No `print` — use the project logger.
- No `late` without a clear initialisation guarantee.
- Avoid `dynamic`; type your JSON maps at the mapper boundary.
- Dispose controllers, focus nodes, subscriptions and timers.

---

## 10. Security Rules for the Client

- Tokens in secure storage (Keychain/Keystore), never plain preferences or web `localStorage`.
- **No secrets in the app bundle.** Anything shipped to a device is public — assume decompilation.
- Hiding a widget by permission is **UX**, not security. The backend enforces authorization.
- Clear all cached data on logout and on company switch.
- Do not log PII or tokens.
- Certificate pinning considered for production builds (ADR when decided).

---

## 11. Flutter Review Checklist

- [ ] Correct layer for every file — no logic in widgets, no Flutter in domain
- [ ] Depends on repository interface, not implementation
- [ ] Loading, error and empty states handled
- [ ] Money/quantity are decimal, not `double`
- [ ] No `company_id` sent as authority; no direct Supabase access
- [ ] Provider state invalidated on logout/company switch
- [ ] Responsive at all four breakpoints
- [ ] Theme tokens used; existing `Erp*` widgets reused
- [ ] Unit tests for domain/application; widget test for new screens
- [ ] `flutter analyze` clean
- [ ] No new dependency without an ADR
- [ ] No new code added to `MockDatabaseService`
