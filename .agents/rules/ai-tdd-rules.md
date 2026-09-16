# AI Test-Driven Development (AI-TDD) & Engineering Governance

**Applies to:** All AI coding agents, subagents, and human developers contributing to the Deluzex ERP codebase.
**Enforcement:** Mandatory on all new features, schema changes, and bug fixes.

---

## 1. Automated Database Test Cleanup (Zero Leakage)
Every automated test (Unit, Integration, E2E) that writes records to the database MUST clean up after itself:
1. **Transactional Rollback (Preferred)**: Run test scenarios within a transaction block (`BEGIN` ... `ROLLBACK`) so no data ever persists to the permanent store.
2. **Deterministic Teardown**: When testing across commit boundaries (e.g., verifying committed transactions), use isolated test identifiers (e.g., prefix `TEST_E2E_` or unique UUIDs) and execute a mandatory cleanup in `afterEach()` or `afterAll()`:
   ```typescript
   afterAll(async () => {
     await db.query(`DELETE FROM users WHERE email LIKE 'test_%@example.com'`);
     await db.query(`DELETE FROM audit_logs WHERE correlation_id LIKE 'test_cid_%'`);
   });
   ```
3. **Never Pollute Production/Shared Data**: Tests must never alter, overwrite, or delete seeded system data (such as default Super Admin or canonical permissions).

---

## 2. System-Wide Impact Analysis
Before writing or modifying any code:
1. **Identify Upstream & Downstream Dependencies**: Check which controllers, services, repositories, and frontend models touch the data being altered.
2. **Detect Breaking Changes**: Any change to API payload shapes, column names, or permission codes must be evaluated for breaking contract changes with the Flutter frontend.
3. **Verify Cascade Effects**: If an entity is soft-deleted or updated, ensure foreign key constraints, inventory ledgers, and financial balances maintain referential and transactional integrity.

---

## 3. Comprehensive Test Scenario Matrix
Every feature must have tests covering three dimensions:
- **Positive Scenarios (Happy Path)**: Valid payloads, successful creation/updates, expected response shapes with `{ data, meta }`.
- **Negative Scenarios (Rejection & Validation)**: Invalid inputs, missing required fields, malformed formats (e.g., invalid GSTIN, negative quantity), unauthorized (401), and forbidden access (403).
- **Edge Cases**: Zero amounts, boundary lengths, concurrent requests, special characters in descriptions, unique constraint collisions on soft-deleted rows.

---

## 4. Pragmatic Schema & API Design (Anti-Overkill & Anti-Bloat)
1. **No Overkill Over-Normalization**:
   - Do NOT split simple entity attributes across 5–10 micro-tables (e.g., do not create separate tables for simple address fields, contact person details, or metadata when clean columns or typed JSONB columns are faster and more maintainable).
   - Only normalize when an entity has true 1-to-many cardinality that requires independent querying, indexing, or transaction history.
2. **No Monolithic "God-Tables"**:
   - Avoid dumping unrelated business domains into one table. Keep Purchase, Inventory, Sales, and Master entities cleanly separated.
3. **High-Performance Relational Design**:
   - Always index foreign keys and frequent filter columns (`is_deleted`, `is_active`, `created_at`, `status`).
   - Use `numeric(18,2)` for currency and `numeric(18,4)` for stock quantities (ADR-011).

---

## 5. Automation Testing Stack Standard
- **Backend User Journey & API Integration**: **Jest + Supertest**
  - Simulates end-to-end API workflows (Auth -> Vendor -> PO -> Approval -> Stock Ledger).
  - Fast, deterministic, and tests real business logic and database constraints.
- **Frontend Web User Simulation**: **Playwright**
  - Automates real browser interactions on the compiled Flutter Web application.
  - Tests user clicks, form typing, responsive layouts, data tables, and PDF previews.
