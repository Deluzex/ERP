# AI_CODING_RULES.md — Governance for AI Development Tools

**Applies to:** Claude, Cursor, Codex, ChatGPT, and any future AI assistant used on this repository.
**Status:** Active · **Related:** `PROJECT_RULES.md`, `TESTING_RULES.md`, `DEVELOPMENT_WORKFLOW.md`

---

## 0. The One Sentence Version

> **AI is an implementation assistant, not an architecture or business decision maker.**

AI may write code, tests and documentation. AI may **not** decide what the business needs, change a business
rule, choose an architecture, or weaken security. Those decisions belong to humans and are recorded as ADRs.

---

## 1. Mandatory Pre-Coding Procedure

Before writing code for any non-trivial task, the AI **must** complete all ten steps and state the results:

| # | Step | What it means in this repository |
| --- | --- | --- |
| 1 | **Inspect existing code** | Actually read the files you will change. Do not assume structure. |
| 2 | **Read relevant documentation** | `PROJECT_RULES.md`, the module doc under `docs/modules/`, relevant ADRs |
| 3 | **Identify affected modules** | List them explicitly in the plan |
| 4 | **Understand existing architecture** | Which layer does this belong in? Controller / Use Case / Domain / Repository |
| 5 | **Identify dependencies** | What else reads or writes this data? What breaks if the shape changes? |
| 6 | **Create an implementation plan** | Files to add/change, in order; tests first |
| 7 | **Identify security & data-integrity risks** | Permissions, resource access, branch/stock-location scope, transaction boundaries, money precision |
| 8 | **Implement only the requested scope** | No opportunistic refactors of unrelated files |
| 9 | **Run tests** | RED before implementation, GREEN after, then regression |
| 10 | **Report what changed** | Files, decisions, risks, anything left undone |

"Non-trivial" means anything beyond a typo, a comment, or a formatting fix. When in doubt, treat it as
non-trivial.

---

## 2. Absolute Prohibitions

The AI must **NEVER**:

1. **Invent business requirements.** If the source document does not say it, it is not a requirement.
2. **Silently change business rules.** Changing a rule requires a human decision and an ADR.
3. **Bypass authorization.** No "temporarily removing the guard to test".
4. **Disable security to make tests pass.** A failing security test means the *code* is wrong.
5. **Add unnecessary dependencies.** Every new package needs an ADR and a justification.
6. **Introduce a new architecture** without written justification and approval.
7. **Modify unrelated modules.** Fix what the ticket asks for; report anything else you noticed.
8. **Duplicate existing functionality.** Search first. Reuse the existing validator, repository, widget.
9. **Assume authentication means authorization.** Logged in ≠ allowed. Always check the permission and the
   authorization scope.
10. **Delete or weaken a test to get a green run.**
11. **Delete or mutate stock history** to simplify an implementation.
12. **Take a scope or permission claim from the request body** and use it as authority.
13. **Implement future-phase features** (Production, Sales, Commission, Reports) during Phase 0/1.
14. **Commit secrets**, connection strings, signing keys or `.env` files.
15. **Implement multi-tenancy** — out of scope (ADR-014). No tenant columns, no RLS, no cross-tenant tests.

---

## 3. When the AI Must Stop and Ask

Stop and ask a human when:

- The requirement is ambiguous and the interpretations lead to materially different data models or rules.
- The task appears to require a business decision (a slab value, a rounding rule, whether a document can be
  edited after approval).
- Implementing the ticket would require breaking one of the rules above.
- The ticket conflicts with the source document, an ADR, or existing code.
- A schema change would be destructive or would need a data backfill.

Record the question in `docs/business/OPEN_QUESTIONS.md` (business) or propose an ADR (technical).
**Do not guess and proceed on high-impact decisions.** Guessing produces plausible code that quietly encodes
the wrong business rule — the most expensive defect class in an ERP.

---

## 4. Backend Work Is Test-Driven — No Exceptions

For any new API, use case, business rule or important backend change, the AI must follow the seven-step cycle
in `TESTING_RULES.md`:

```
1. Understand requirement
2. Define test scenarios
3. RED     - run the new tests, observe them fail for the right reason
4. IMPLEMENT the minimum production code
5. GREEN   - run the tests, all pass
6. REFACTOR - improve quality, behaviour unchanged, tests still green
7. REGRESSION - run the module/broader suite
```

The AI must **report the actual RED output**, not claim it. "Tests were written first" without an observed
failing run is not TDD; it is a claim. If a test passes *before* implementation, the test is wrong — say so
and fix the test.

---

## 5. Required Report Format

Every non-trivial AI contribution ends with:

```markdown
### Summary
<what was built, in one or two sentences>

### Files Created
- path — purpose

### Files Modified
- path — what changed and why

### Tests
- RED run: <command> → N failing (expected: <reason>)
- GREEN run: <command> → N passing
- Regression: <command> → result

### Security & Tenancy
- Permission required: <permission>
- Scope enforced at: <layer(s)>
- Access-control tests: <test names for 401 / 403 permission / 403 out-of-scope>

### Decisions Made
- <decision> — <why> — (ADR needed? yes/no)

### Risks / Follow-ups
- <anything a reviewer must know>

### Not Done
- <anything in scope that was deliberately left out, and why>
```

Reporting "done" when a step was skipped is a process violation, not a shortcut.

---

## 6. Working With the Existing Flutter Implementation

The repository contains a Flutter implementation backed by `MockDatabaseService` covering all phases.
Per **ADR-010** it is **retained** as existing project work — **not deleted and not frozen**.

Rules for AI tools:

- **Do not assume it follows the approved architecture.** It predates these documents. Check a file against
  the current rules before reusing its patterns.
- **New development must follow the approved architecture** (ADR-008 layering, ADR-011 decimals, ADR-002
  ADR-014 single-client scope, ADR-003 backend auth) — regardless of how the surrounding files are written.
- **Do not rewrite unrelated existing functionality** unless a specific Jira task requires it. Opportunistic
  refactoring of working screens is out of scope and will be rejected in review.
- **Do not treat existing screens as a specification.** Where behaviour contradicts the business source
  document, the **source document wins** — report the contradiction rather than silently following either.
- **Do reuse** the design system (`lib/core/widgets/`, `lib/app/theme/`) — it is promoted, not deprecated.
- **Do not add new business logic to `MockDatabaseService`.** New features go through the real API.

Patterns that must **not** propagate into new code:

| Existing pattern | Why it is wrong for new code | Correct approach |
| --- | --- | --- |
| No branch / stock-location scope on any model | No access control | Stock entities carry `stockLocationId` (ADR-013) |
| `role` as a free-text `String` on `UserModel` | Not an authorization model | Customer-defined roles + granular permissions, server-side (ADR-004) |
| `double` for money and quantity | Float rounding errors on money | `NUMERIC` in DB, decimal transport (ADR-011) |
| `StockMovement.currentBalance` stored per row | Balance treated as a stored fact | Ledger is truth; balance derived/cached (ADR-005) |
| Screens read the data service directly | No domain/data layers | Presentation → State → Domain → Data → API (ADR-008) |
| Client-generated document numbers | Not concurrency-safe or per-company | Server-side numbering |

These are **guidance for new work**, not a defect list to act on unprompted.

---

## 7. Prompting Guidance for Developers

When you ask an AI tool to do work on this repository, give it:

1. The **Jira ticket ID** and the acceptance criteria.
2. The **module documentation** path.
3. The instruction: *"Follow `PROJECT_RULES.md` and `AI_CODING_RULES.md`. Write tests first and show me the
   RED run before implementing."*
4. The **phase constraint**: *"We are in Phase 0/1. Do not implement Production, Sales or Commission."*

A good starting prompt:

> Read `PROJECT_RULES.md`, `AI_CODING_RULES.md`, `TESTING_RULES.md` and
> `docs/modules/stock-management/BUSINESS_RULES.md`. Implement ERP-104 (create purchase entry API).
> Follow the mandatory TDD cycle: write the test scenarios first, run them, show me the RED output, then
> implement. Enforce authorization scope from the token only. Do not touch other modules.

---

## 8. Review Checklist for AI-Generated Code

A human reviewer must confirm:

- [ ] The change matches the ticket scope — nothing extra
- [ ] Tests existed before implementation and a RED run was reported
- [ ] Tests verify **behaviour**, not implementation details
- [ ] Access-control tests exist for any protected endpoint (401, 403 permission, 403 out-of-scope)
- [ ] Permission check present and correct
- [ ] No `company_id` taken from client input
- [ ] Money/quantity use the decimal type, not float
- [ ] Multi-record writes are inside one database transaction
- [ ] No new dependency without an ADR
- [ ] No unrelated files touched
- [ ] Business terminology matches the source document
- [ ] Documentation updated where the change affects it

AI-generated code is reviewed **more** carefully than human code, not less. It is fluent, which makes wrong
code look right.
