# AGENTS.md — AI Agent Directives for Deluzex ERP

Welcome, AI Agent. You are pair programming on **Deluzex ERP**, an enterprise manufacturing & inventory management system.

## Golden Engineering Directives

1. **AI Test-Driven Development (AI-TDD)**:
   - Always follow the RED → GREEN → REFACTOR lifecycle.
   - For every feature or bugfix, write automated tests first, observe the failure, implement minimal code, and verify green.
   - Cover **Positive**, **Negative**, and **Edge cases**.

2. **Automated Database Test Cleanup (Mandatory)**:
   - When tests write records to the database (local or Supabase), they **MUST clean up after themselves**.
   - Use transactional rollbacks or deterministic `afterAll()` / `afterEach()` teardowns. Never leave leftover test data polluting the database.

3. **System-Wide Impact Analysis**:
   - Before editing existing models, APIs, or schemas, perform an impact analysis across the whole system (backend services, database foreign keys, and Flutter frontend screens).

4. **Pragmatic Schema & API Design (Anti-Overkill & Anti-Bloat)**:
   - Avoid overkill over-normalization (do not create 5 micro-tables where clean columns or typed JSONB suffice).
   - Avoid bulky "god-tables" (keep modules cleanly separated).
   - Never use floating-point types for currency or stock quantities (`numeric(18,2)` for money, `numeric(18,4)` for stock quantities per ADR-011).

5. **Testing Frameworks**:
   - **Backend User Journeys**: Jest + Supertest (`backend/test/`).
   - **Frontend Web User UI**: Playwright (`frontend-e2e/`).

6. **Full Governance**:
   - Read `.agents/rules/ai-tdd-rules.md`, `AI_CODING_RULES.md`, `TESTING_RULES.md`, `DATABASE_RULES.md`, and `API_CONVENTIONS.md`.
