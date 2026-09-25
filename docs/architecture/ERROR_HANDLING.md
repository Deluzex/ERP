# Error Handling Architecture

**Status:** Active (Phase 0) · **Related:** `API_CONVENTIONS.md` §6, `BACKEND_RULES.md` §6, `FLUTTER_RULES.md` §5

---

## 1. Principle

An error travels through three translations, and each layer only knows its own vocabulary:

```
Domain            "this purchase would take stock below zero"   → InsufficientStockError
   ↓
HTTP boundary     "that is a client-side business rule failure" → 422 + INSUFFICIENT_STOCK
   ↓
Client            "Not enough stock. Available: 100, needed 150" → user sees an actionable message
```

The domain must not know about HTTP. The widget must not know about HTTP. Exactly one place in the backend
translates domain → HTTP, and exactly one place in the client translates HTTP → user message.

---

## 2. Error Categories

| Category | Cause | Status | Retry? | Who fixes it |
| --- | --- | --- | --- | --- |
| **Validation** | Malformed input | 422 | After correction | User |
| **Authentication** | Missing/expired token | 401 | After re-auth | User |
| **Authorization** | Insufficient permission | 403 | No | Admin |
| **Not found** | Wrong id — the record does not exist | 404 | No | User |
| **Conflict** | Duplicate, illegal state transition | 409 | After correction | User |
| **Business rule** | A domain invariant would break | 422 | After correction | User |
| **Infrastructure** | Database down, timeout | 503 | Yes | Ops |
| **Programming error** | Null deref, bad cast | 500 | No | Engineering |

Confusing the last two rows is the most common mistake: a `500` that is really a `422` sends engineers
hunting a bug that is actually a user typing a negative quantity.

---

## 3. Backend Implementation

### 3.1 Typed domain errors

```ts
export abstract class DomainError extends Error {
  abstract readonly code: string;        // stable, machine-readable
  abstract readonly httpStatus: number;
  readonly details?: ErrorDetail[];
}

export class InsufficientStockError extends DomainError {
  readonly code = 'INSUFFICIENT_STOCK';
  readonly httpStatus = 422;
  constructor(itemId: string, available: string, requested: string) {
    super('Insufficient stock for the selected item.');
    this.details = [{ field: 'quantity', issue: `requested ${requested}, available ${available}` }];
  }
}
```

The `httpStatus` on the class is a pragmatic compromise: it keeps the mapping in one obvious place without
scattering `if (err instanceof X)` chains through the filter. The domain still never imports HTTP machinery.

### 3.2 One global exception filter

```ts
@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const correlationId = ctx.getRequest().correlationId;

    if (exception instanceof DomainError) {
      this.logger.warn({ code: exception.code, correlationId });
      return ctx.getResponse().status(exception.httpStatus).json({
        error: {
          code: exception.code,
          message: exception.message,
          details: exception.details,
          correlationId,
          timestamp: new Date().toISOString(),
        },
      });
    }

    // Anything unrecognised is a bug. Log everything, reveal nothing.
    this.logger.error({ err: exception, correlationId });
    return ctx.getResponse().status(500).json({
      error: {
        code: 'INTERNAL_ERROR',
        message: 'An unexpected error occurred.',
        correlationId,
        timestamp: new Date().toISOString(),
      },
    });
  }
}
```

### 3.3 Rules

- **Never** return a stack trace, SQL fragment, driver message, table name or file path to a client.
- **Never** swallow an error (`catch {}` with no handling or logging).
- **Never** use a bare `Error` for a business condition — reviewers cannot distinguish 500 from 422.
- Log at the boundary **once**. Do not log-and-rethrow at every layer; that produces five entries for one
  failure and hides the real one.
- Database driver errors are translated in the repository layer into domain errors
  (unique violation → `DuplicateResourceError`, FK violation → `ReferencedEntityNotFoundError`).
  A raw `23505` must never reach the filter.

### 3.4 Messages must not leak internals

An error message must never expose internal structure or another user private data:

```ts
// ❌ leaks
throw new NotFoundError(`Vendor ${id} belongs to company ${vendor.companyId}`);
// ✅
throw new NotFoundError('vendors', id);   // → 404, generic message
```

---

## 4. Flutter Implementation

```
HTTP response
  → ApiException          (data layer: status + code + message + correlationId)
    → Failure             (domain layer: typed, no HTTP knowledge)
      → user message      (presentation layer)
```

```dart
sealed class Failure {
  final String message;
  final String? correlationId;
}
class NetworkFailure     extends Failure {}   // no connectivity, timeout
class ValidationFailure  extends Failure {}   // 422 + field details
class PermissionFailure  extends Failure {}   // 403
class NotFoundFailure    extends Failure {}   // 404
class ServerFailure      extends Failure {}   // 500
```

Rules:

- Map using the stable `code` field. **Never** string-match the human `message` — it is localisable and will
  change.
- Widgets never see a status code.
- `401` → attempt token refresh; on failure, log out and clear **all** cached state.
- `403` → show an explicit permission message. Never render a silently empty screen; the user will report
  "data is missing" and support will chase a phantom data bug.
- `422` → attach field errors to the corresponding form fields.
- Always surface the `correlationId` in the error UI (small, copyable). It converts "it didn't work" into a
  one-second log lookup.
- Unknown/unexpected codes fall back to a generic message but are still logged with the correlation id.

---

## 5. Correlation Id

- Generated at the API edge (or accepted from `X-Correlation-Id`).
- Attached to the request context, every log line, the error envelope, and the audit record.
- Displayed to the user on error screens.

One id ties together: the user's screenshot, the API log, the database audit row.

---

## 6. Retry Rules

| Situation | Retry |
| --- | --- |
| `GET` on network failure | Yes — exponential backoff, capped |
| `POST` affecting stock or money | **Only with an `Idempotency-Key`** (`API_CONVENTIONS.md` §8) |
| `4xx` | Never — the request is wrong; retrying cannot help |
| `503` | Yes, with backoff |

Retrying a purchase creation without an idempotency key is how a warehouse ends up with double stock.

---

## 7. What Good Looks Like

| Bad | Good |
| --- | --- |
| `500 "Cannot read property 'id' of undefined"` | `422 VALIDATION_FAILED` with the offending field |
| `"Error"` toast | "Not enough stock for Aluminium Profile 40x40. Available 100 KG, required 150 KG." |
| Silent empty list on 403 | "You do not have permission to view purchases. Contact your administrator." |
| `404` for a record the user simply may not access | `403 PERMISSION_DENIED` with a clear message |
| Stack trace in the response body | Stack trace in the log, `correlationId` in the response |
