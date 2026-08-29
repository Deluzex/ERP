# BACKEND_RULES.md — NestJS / TypeScript Standards

**Status:** Active · **Related:** `ARCHITECTURE.md`, `API_CONVENTIONS.md`, `SECURITY_RULES.md`,
`DATABASE_RULES.md`, `TESTING_RULES.md`

> The backend does not exist yet. This document defines how it will be built, and is binding from the first
> commit of `apps/backend` (ADR-001).

---

## 1. Layering — Non-Negotiable

```
Controller → Guard/Auth → Validation → Application/Use Case → Domain → Repository → PostgreSQL
```

No layer may be skipped and no layer may reach past its neighbour. Specifically:

- A controller **must not** import a repository.
- A use case **must not** import `@nestjs/common` HTTP decorators or `Request`/`Response`.
- The domain **must not** import NestJS, the database client, or anything framework-specific.
- A repository **must not** decide business outcomes.

### 1.1 Controllers are thin

```ts
@Controller('purchases')
export class PurchasesController {
  constructor(private readonly createPurchase: CreatePurchaseUseCase) {}

  @Post()
  @RequirePermission('purchase.create')
  async create(
    @Body() dto: CreatePurchaseDto,
    @Ctx() ctx: RequestContext,
  ): Promise<PurchaseResponseDto> {
    const purchase = await this.createPurchase.execute(dto, ctx);
    return PurchaseResponseDto.from(purchase);
  }
}
```

A controller does four things: declare the route, declare the permission, pass validated input plus the
trusted context to a use case, and map the result to a response DTO. Nothing else. If you see an `if` about
business meaning in a controller, it is in the wrong file.

### 1.2 Use cases orchestrate

One class per use case, one public `execute` method:

```ts
@Injectable()
export class CreatePurchaseUseCase {
  constructor(
    private readonly uow: UnitOfWork,
    private readonly vendors: VendorRepository,
    private readonly materials: RawMaterialRepository,
    private readonly purchases: PurchaseRepository,
    private readonly ledger: StockLedgerService,
    private readonly audit: AuditLogger,
  ) {}

  async execute(input: CreatePurchaseInput, ctx: RequestContext): Promise<Purchase> {
    return this.uow.runInTransaction(async (tx) => {
      const vendor = await this.vendors.findByIdOrFail(input.vendorId, ctx, tx);
      const lines  = await this.resolveLines(input.items, ctx, tx);

      // domain decides; the use case only orchestrates
      const purchase = Purchase.create({ vendor, lines, ...input }, ctx);

      await this.purchases.insert(purchase, tx);
      await this.ledger.postPurchase(purchase, ctx, tx);
      await this.audit.record('purchase.created', purchase, ctx, tx);

      return purchase;
    });
  }
}
```

The **use case owns the transaction boundary**. Repositories join an existing transaction; they never open
their own.

### 1.3 Domain holds the rules

Pure TypeScript. No decorators, no imports from `@nestjs/*`, no database.

```ts
export class Purchase {
  static create(props: CreatePurchaseProps, ctx: RequestContext): Purchase {
    if (props.lines.length === 0) {
      throw new EmptyPurchaseError();
    }
    for (const line of props.lines) {
      if (line.quantity.lte(0)) throw new InvalidQuantityError(line.rawMaterialId);
      if (line.rate.lt(0))      throw new InvalidRateError(line.rawMaterialId);
    }
    // totals computed here, once, and tested here
    ...
  }
}
```

Because it is pure, it is unit-testable in milliseconds without a database or an HTTP server — which is what
makes test-first practical.

### 1.4 Repositories respect the caller scope by construction

```ts
export abstract class BaseRepository<T> {
  protected abstract table: string;

  async findByIdOrFail(id: string, tx?: Tx): Promise<T> {
    const row = await this.query(tx)
      .where({ id, is_deleted: false })   // soft-deleted rows excluded by default (ADR-012)
      .first();
    if (!row) throw new NotFoundError(this.table, id);   // 404 — genuinely not found
    return this.toDomain(row);
  }
}
```

For **stock-bearing** resources the caller's scope is applied explicitly, because it is a real authorization
decision rather than a silent filter:

```ts
async findBalance(itemId: string, locationId: string, ctx: RequestContext, tx?: Tx) {
  this.assertLocationInScope(locationId, ctx);   // throws 403 STOCK_LOCATION_OUT_OF_SCOPE
  return this.query(tx).where({ item_id: itemId, stock_location_id: locationId }).first();
}
```

> **Changed 2026-08-29 (ADR-014).** This class was previously `ScopedRepository`, filtering every query by
> `company_id` from the token for **tenant isolation**. There are no tenants — that filter is gone. What
> remains is **scope validation**, which is an explicit, testable authorization check rather than an implicit
> `WHERE` clause. Do not reintroduce a `company_id` filter as a security mechanism.

Any hand-written SQL lives in the repository/infrastructure layer and is parameterised.

---

## 2. Project Layout

```
apps/backend/
├── src/
│   ├── main.ts
│   ├── app.module.ts
│   ├── core/                  # platform concerns (see ARCHITECTURE.md §3.4)
│   │   ├── auth/  access/  database/  errors/  logging/  audit/  common/
│   └── modules/
│       └── <module>/
│           ├── api/ application/ domain/ infrastructure/ __tests__/
├── test/
│   └── e2e/
├── migrations/
└── package.json
```

---

## 3. TypeScript Standards

- `strict: true` in `tsconfig.json`. Also `noImplicitAny`, `strictNullChecks`, `noUncheckedIndexedAccess`.
- **`any` is forbidden** in application code. Use `unknown` and narrow. Exceptions need a comment explaining
  why and a linked ticket.
- No non-null assertions (`!`) to silence the compiler — handle the null case.
- Explicit return types on all public methods.
- `readonly` for anything not intended to mutate.
- Prefer composition over inheritance; the one sanctioned base class is `BaseRepository`.
- Named exports only (no `export default`) — it keeps import names consistent and greppable.
- ESLint + Prettier enforced in CI; formatting is not a review topic.

---

## 4. DTOs and Validation

Three distinct kinds of object — do not collapse them:

| Object | Purpose | Lives in |
| --- | --- | --- |
| **Request DTO** | Validate and shape client input | `api/dto/` |
| **Domain entity** | Business state and rules | `domain/` |
| **Response DTO** | Control exactly what leaves the API | `api/dto/` |

Never return a domain entity or a raw database row directly — that leaks internal fields
(`is_deleted`, `created_by`, internal ids) and couples clients to the schema.

```ts
export class CreatePurchaseDto {
  @IsUUID() vendorId!: string;
  @IsDateString() purchaseDate!: string;
  @IsString() @MaxLength(50) vendorInvoiceNumber!: string;

  @IsArray() @ArrayMinSize(1)
  @ValidateNested({ each: true }) @Type(() => CreatePurchaseItemDto)
  items!: CreatePurchaseItemDto[];

  // NOTE: no companyId, no branchId as authority, no totals.
  // Scope comes from the token; totals are computed server-side.
}
```

Global pipe configuration (`SECURITY_RULES.md` §7):

```ts
app.useGlobalPipes(new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
}));
```

---

## 5. RequestContext — the trusted scope object

Built by the auth guard from the **verified token**, attached to the request, injected via a `@Ctx()`
decorator. It is the only sanctioned source of permission and scope information.

```ts
export interface RequestContext {
  readonly userId: string;
  readonly companyId: string;
  readonly branchIds: readonly string[];
  readonly stockLocationIds: readonly string[];
  readonly permissions: ReadonlySet<string>;
  readonly correlationId: string;
}
```

Rules:

- It is **immutable**.
- It is never constructed from request body/query/headers.
- It is passed explicitly to use cases and repositories — not smuggled through a global or an async-local
  singleton that is easy to forget in tests.

---

## 6. Error Handling

### 6.1 Domain errors are typed

```ts
export abstract class DomainError extends Error {
  abstract readonly code: string;          // stable, machine-readable
  abstract readonly httpStatus: number;
}

export class InsufficientStockError extends DomainError {
  readonly code = 'INSUFFICIENT_STOCK';
  readonly httpStatus = 422;
  constructor(readonly itemId: string, readonly available: string, readonly requested: string) {
    super(`Insufficient stock for item ${itemId}`);
  }
}
```

The domain throws a business error. It does not know or care that it becomes HTTP 422.

### 6.2 One global exception filter

Maps `DomainError` → the standard error envelope in `API_CONVENTIONS.md` §6, logs with the correlation id,
and converts anything unrecognised into a generic `500` with **no internal detail** in the response.

### 6.3 Rules

- Never swallow an error silently (`catch {}` with no handling).
- Never return a driver/SQL message to the client.
- Never use a generic `Error` for a business condition — a reviewer cannot tell 500 from 422.
- Log at the boundary, once. Do not log-and-rethrow at every level.

---

## 7. Transactions and Concurrency

- The use case opens the transaction; repositories accept an optional `tx`.
- No HTTP calls, file I/O, PDF generation or email sending inside a transaction.
- Lock rows you intend to update based on their current value:
  ```sql
  SELECT quantity FROM stock_balances
   WHERE item_id = $1 AND stock_location_id = $2
   FOR UPDATE;
  ```
  Without the lock, two concurrent purchases can both read `100`, both write `110`, and lose ten units.
- Never rely on read-then-write without a lock or a constraint for anything affecting stock or money.
- Document number generation happens inside the transaction (`DATABASE_RULES.md` §13).

---

## 8. Logging

- Structured JSON via a single logger (`core/logging`). No `console.log`.
- Every request carries a **correlation id**, generated at the edge and included in every log line and in the
  error envelope so a customer report can be traced.
- Log levels: `error` (needs action), `warn` (unexpected, handled), `info` (business events), `debug` (dev).
- **Never log:** tokens, passwords, full PII, connection strings, whole request bodies.
- Log the *decision*, not the data: `"purchase.created"` with ids, not the entire payload.

---

## 9. Configuration

- All configuration via environment variables, validated at boot with a schema. **Fail fast** — the app must
  refuse to start with a missing or malformed variable rather than fail mysteriously at 3am.
- No `process.env` access scattered through the code; one typed config module.
- `.env.example` is committed with empty values; `.env` is git-ignored.

---

## 10. Dependencies

- A new dependency requires an ADR: what problem, what alternatives, maintenance status, licence, bundle and
  security impact.
- Prefer the platform (Node, NestJS, PostgreSQL) over a package for anything small.
- Pin versions; commit the lockfile; run dependency audit in CI.

---

## 11. Performance (last in priority, not absent)

- Paginate every list endpoint. No unbounded `SELECT *`.
- Beware N+1 queries in list endpoints — load related data in one query.
- Index according to the real access path (`DATABASE_RULES.md` §8).
- Do not cache scope-restricted data in a process-wide cache without the scope in the cache key. This is a
  classic access-control leak.
- Measure before optimising. Correctness first.

---

## 12. Backend Review Checklist

- [ ] Layering respected — no controller logic, no framework in domain
- [ ] Permission decorator present and correct
- [ ] Scope from `RequestContext` only; no scope or permission claim taken from input
- [ ] DTO validation with whitelist; response DTO used (no entity leakage)
- [ ] Multi-row writes inside one transaction, with the correct locking
- [ ] Money/quantity use decimal types end to end
- [ ] Typed domain errors, mapped by the global filter
- [ ] Tests written first; RED evidence in the PR
- [ ] Access-control tests present (401 / 403 permission / 403 out-of-scope)
- [ ] No `any`, no `!`, no `console.log`
- [ ] No new dependency without an ADR
