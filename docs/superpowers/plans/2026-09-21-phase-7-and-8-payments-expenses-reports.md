# Phase 7 & 8 (Payments, Expenses & Reports) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Phase 7 (Payments, Ledgers & Expenses) and Phase 8 (Reports & Business Intelligence) with full-stack live PostgreSQL database migrations, NestJS backend API modules, Flutter Dio services, live screen bindings, and 100% automated test coverage.

**Architecture:** Forward-only SQL migrations applied to Supabase PostgreSQL, NestJS modular controllers/services with transactional UnitOfWork for atomic ledger balancing, Flutter Riverpod + Dio API clients with JSON DTO mapping, and Jest + Supertest E2E journey tests following AI-TDD.

**Tech Stack:** Node.js, NestJS, TypeScript, PostgreSQL (Supabase), Flutter, Dart, Dio, Riverpod, Jest, Supertest.

**Spec:** [`BACKEND_API_REQUIREMENTS.md`](../../BACKEND_API_REQUIREMENTS.md) §11 and §13, [`PROJECT_RULES.md`](../../PROJECT_RULES.md), [`DATABASE_RULES.md`](../../DATABASE_RULES.md), [`FLUTTER_RULES.md`](../../FLUTTER_RULES.md).

## Global Constraints
- All currency values stored as `numeric(18,2)` strings (ADR-011).
- Single legal entity scope in Gujarat (ADR-014).
- Append-only audit trail and transactional balance reconciliation (`UnitOfWork`).
- Mandatory automated database test cleanup in all E2E test suites.

---

### Task 1: Database Migration `011_payments_and_expenses.sql`
- Create `backend/migrations/011_payments_and_expenses.sql` with `payments`, `architect_commissions`, and `expenses` tables, indices, and sequence generators.
- Apply migration to live Supabase PostgreSQL.

### Task 2: Backend Payments Module
- Implement `backend/src/modules/payments/`: DTOs, service, controller, module.
- Endpoints: `GET /api/v1/payments`, `POST /api/v1/payments`, `GET /api/v1/payments/commissions`, `POST /api/v1/payments/commissions/:id/approve`, `POST /api/v1/payments/commissions/:id/pay`, `POST /api/v1/payments/commissions/:id/reject`.
- Write AI-TDD E2E tests: `backend/test/payments-journey.e2e-spec.ts`.

### Task 3: Backend Expenses Module
- Implement `backend/src/modules/expenses/`: DTOs, service, controller, module.
- Endpoints: `GET /api/v1/expenses`, `POST /api/v1/expenses`, `PUT /api/v1/expenses/:id`, `DELETE /api/v1/expenses/:id`.
- Write AI-TDD E2E tests: `backend/test/expenses-journey.e2e-spec.ts`.

### Task 4: Backend Reports & BI Module
- Implement `backend/src/modules/reports/`: service with 8 SQL aggregation queries, controller, module.
- Endpoints: `GET /api/v1/reports/:reportType`.
- Write AI-TDD E2E tests: `backend/test/reports-journey.e2e-spec.ts`.

### Task 5: Flutter Models, API Services & Screen Bindings
- Update models: `payment_model.dart`, `commission_model.dart`, `expense_model.dart` with `fromJson`/`toJson`.
- Create API services: `payments_api_service.dart`, `expenses_api_service.dart`, `reports_api_service.dart`.
- Bind `mock_database_service.dart`, `payment_center_screen.dart`, `expenses_screen.dart`, and `reports_hub_screen.dart`.
- Write Flutter binding tests: `payments_expenses_api_binding_test.dart`.

### Task 6: Full-Stack Verification & Audit Documentation Update
- Run `npm test` and `npm run test:e2e` in backend.
- Run `flutter test` and `flutter analyze` in frontend.
- Update `docs/PROJECT_PROGRESS_AND_MODULE_AUDIT.md` and `docs/PROJECT_CONTEXT.md`.
