# API_CONVENTIONS.md — REST API Standards

**Status:** Active · **Related:** `BACKEND_RULES.md`, `SECURITY_RULES.md`, ADR-007
**Base URL:** `https://<host>/api/v1`

---

## 1. Every New API Must Define These Twelve Things

A ticket that adds an endpoint is not Ready until all twelve are written down in
`docs/modules/<module>/API_SPECIFICATION.md`:

1. Endpoint path
2. HTTP method
3. Authentication requirement
4. Authorization requirement (the exact permission)
5. Branch / stock-location scope, and which permission gates it
6. Request DTO
7. Validation rules
8. Success response (status + body)
9. Error responses (every one that can occur)
10. Business rules applied
11. Side effects (stock movements, audit entries, outstanding balance changes)
12. Test scenarios

> An API is **not complete** because it returns the expected response on the happy path.

---

## 2. Resource Naming

| Rule | Example |
| --- | --- |
| Plural nouns, `kebab-case` | `/raw-materials`, `/finished-products`, `/stock-transactions` |
| No verbs in paths | `/purchases` not `/createPurchase` |
| Nested only one level | `/purchases/{id}/items` |
| Actions that are not CRUD use a sub-resource | `POST /purchases/{id}/payments` |
| State transitions are explicit sub-resources | `POST /purchases/{id}/confirmation` |
| Business terminology from the source document | `/vendors` — never `/suppliers` |

Never put an organizational or scope id in a path as an **authority**. Permissions and scope come from the
token (`SECURITY_RULES.md` §3). `/companies/{companyId}/vendors` is forbidden — it invites the client to
choose its own scope. A stock location may be **requested** as a query parameter or body field, but the
server validates it against the caller's scope before use.

---

## 3. HTTP Methods and Status Codes

| Method | Use | Success |
| --- | --- | --- |
| `GET` | Read. Safe, idempotent, never changes state | `200` |
| `POST` | Create, or a non-idempotent action | `201` (create), `200` (action) |
| `PATCH` | Partial update | `200` |
| `PUT` | Full replace (rare here) | `200` |
| `DELETE` | Soft delete per `DATABASE_RULES.md` §11 | `200` or `204` |

| Status | Meaning in this API |
| --- | --- |
| `200` | Success with body |
| `201` | Created — includes a `Location` header |
| `204` | Success, no body |
| `400` | Malformed request (bad JSON) |
| `401` | Missing/invalid/expired token |
| `403` | Authenticated but lacks the permission, or out-of-scope branch/stock location |
| `404` | Not found **or belongs to another company** (deliberately indistinguishable) |
| `409` | Conflict — duplicate, or state transition not allowed |
| `422` | Validation failed, or a business rule was violated |
| `429` | Rate limited |
| `500` | Unexpected server error — no internal detail in the body |

The `403` vs `404` distinction is a security control, not a style preference. See `SECURITY_RULES.md` §6.1.

---

## 4. Request and Response Envelope

### 4.1 Success — single resource

```json
{
  "data": {
    "id": "8f14e45f-ceea-467a-9d2b-1c3f4a5b6c7d",
    "vendorName": "Apex Aluminum Extrusions Ltd",
    "creditLimit": "500000.00",
    "createdAt": "2026-08-28T10:15:00.000Z"
  },
  "meta": { "correlationId": "b7c1e5a2-..." }
}
```

### 4.2 Success — collection

```json
{
  "data": [ { "id": "..." } ],
  "meta": {
    "correlationId": "b7c1e5a2-...",
    "pagination": { "page": 1, "pageSize": 25, "totalItems": 137, "totalPages": 6 }
  }
}
```

### 4.3 Conventions

- JSON field names are **`camelCase`** (database columns stay `snake_case`; the mapper translates).
- Timestamps are **ISO 8601 UTC** with `Z`.
- **Money and quantity are transported as strings**, never JSON numbers — `"1234.50"`, not `1234.5`.
  JSON numbers are IEEE 754 doubles in most clients and will silently corrupt money. See ADR-011.
- Booleans are real booleans, not `"Y"`/`"N"`.
- `null` means "not set"; omit nothing that the contract promises.
- Enums are `UPPER_SNAKE_CASE` strings matching the source document terminology
  (`PURCHASE`, `PRODUCTION_CONSUMPTION`, `PRODUCTION_OUTPUT`, `SALE`, `SALE_RETURN`, `PURCHASE_RETURN`,
  `DAMAGE`, `ADJUSTMENT`).

---

## 5. Pagination, Filtering, Sorting

Every list endpoint is paginated. There is no unbounded list.

```
GET /raw-materials?page=1&pageSize=25&sort=-createdAt&search=aluminium&isActive=true
```

| Parameter | Rules |
| --- | --- |
| `page` | 1-based, default `1` |
| `pageSize` | default `25`, **max `100`** — a larger value is rejected with `422`, not silently clamped |
| `sort` | `field` ascending, `-field` descending; only whitelisted fields |
| `search` | free text across documented fields only |
| Filters | explicit, documented, whitelisted query params |

Sort and filter fields must be **whitelisted**. Passing a column name straight into `ORDER BY` is an
injection vector and leaks the schema.

---

## 6. Error Envelope

Every error, from every endpoint, has this shape:

```json
{
  "error": {
    "code": "INSUFFICIENT_STOCK",
    "message": "Insufficient stock for the selected raw material.",
    "details": [
      { "field": "items[0].quantity", "issue": "requested 150, available 100" }
    ],
    "correlationId": "b7c1e5a2-3d4f-4a5b-9c8d-7e6f5a4b3c2d",
    "timestamp": "2026-08-28T10:15:00.000Z"
  }
}
```

Rules:

- `code` is **stable and machine-readable**. Clients branch on `code`, never on `message`.
- `message` is human-readable, safe to display, and contains **no internal detail** — no SQL, no stack trace,
  no file path, no table name.
- `details` carries field-level validation problems.
- `correlationId` appears in both the response and the server logs so a user report is traceable.
- Error messages never expose internal structure; see `docs/architecture/ERROR_HANDLING.md`.

### Standard error codes

| Code | Status | Meaning |
| --- | --- | --- |
| `UNAUTHENTICATED` | 401 | Missing/invalid/expired token |
| `PERMISSION_DENIED` | 403 | Lacks the required permission |
| `BRANCH_OUT_OF_SCOPE` | 403 | Branch not assigned to this user |
| `STOCK_LOCATION_OUT_OF_SCOPE` | 403 | Stock location not assigned to this user |
| `NOT_FOUND` | 404 | Genuinely not found |
| `DUPLICATE_RESOURCE` | 409 | Unique constraint violated |
| `INVALID_STATE_TRANSITION` | 409 | e.g. confirming an already-confirmed purchase |
| `VALIDATION_FAILED` | 422 | DTO validation failed |
| `BUSINESS_RULE_VIOLATION` | 422 | Generic domain rule failure |
| `INSUFFICIENT_STOCK` | 422 | Not enough stock for the movement |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Unexpected — details logged, never returned |

---

## 7. Headers

| Header | Direction | Purpose |
| --- | --- | --- |
| `Authorization: Bearer <jwt>` | Request | Authentication. **Required** on every non-public endpoint |
| `X-Correlation-Id` | Request (optional) / Response | Tracing; generated if absent |
| `Idempotency-Key` | Request | Required on financial `POST`s (§8) |
| `Content-Type: application/json` | Both | |

There is **no** `X-Company-Id` or scope header. Identity, permissions and scope come from the token only.

---

## 8. Idempotency

Financial and inventory-affecting `POST` endpoints (create purchase, record payment, post adjustment) accept
an `Idempotency-Key`. A repeated key returns the **original** result instead of creating a duplicate.

This matters in the field: a warehouse tablet on poor connectivity retries a request whose response was lost.
Without idempotency, stock is posted twice and the ledger is permanently wrong.

---

## 9. Versioning

- The version is in the path: `/api/v1/...`.
- Additive changes (a new optional field, a new endpoint) do **not** bump the version.
- Breaking changes (removing/renaming a field, changing a type, tightening validation) require `/v2` and a
  documented deprecation period.
- Clients must ignore unknown fields — never break on an added response field.

---

## 10. Documentation

- OpenAPI/Swagger generated from the NestJS decorators and DTOs, served in non-production environments.
- Generated docs are **not** a substitute for `docs/modules/<module>/API_SPECIFICATION.md`, which records the
  business rules, side effects and test scenarios that a schema cannot express.
- The spec is updated in the **same PR** as the endpoint.

---

## 11. Worked Example

### `POST /api/v1/purchases`

| Item | Value |
| --- | --- |
| **Authentication** | Required |
| **Permission** | `purchase.create` |
| **Scope** | Company (from token); `branchId` and `stockLocationId` validated against the caller's scope |
| **Idempotency** | `Idempotency-Key` required |

**Request**

```json
{
  "vendorId": "8f14e45f-ceea-467a-9d2b-1c3f4a5b6c7d",
  "branchId": "2c1a...",
  "stockLocationId": "9d3b...",
  "purchaseDate": "2026-08-28",
  "vendorInvoiceNumber": "APX/2026/1187",
  "invoiceDate": "2026-08-27",
  "items": [
    { "rawMaterialId": "5a2f...", "quantity": "150.0000", "rate": "245.50",
      "discountPercent": "2.5", "gstPercent": "18.0" }
  ],
  "paidAmount": "10000.00",
  "paymentMode": "BANK_TRANSFER"
}
```

Note what is **absent**: no `companyId`, no `purchaseNumber`, no line totals, no grand total.
All are derived server-side — the client cannot dictate them.

**Success `201`**

```json
{
  "data": {
    "id": "c4d5...",
    "purchaseNumber": "PUR-2026-0105",
    "status": "CONFIRMED",
    "totalAmount": "43439.06",
    "paidAmount": "10000.00",
    "pendingAmount": "33439.06",
    "stockTransactionIds": ["e1f2..."]
  },
  "meta": { "correlationId": "..." }
}
```

**Errors**

| Condition | Status | Code |
| --- | --- | --- |
| No token | 401 | `UNAUTHENTICATED` |
| Lacks `purchase.create` | 403 | `PERMISSION_DENIED` |
| Stock location not in scope | 403 | `STOCK_LOCATION_OUT_OF_SCOPE` |
| Vendor belongs to another company | **404** | `NOT_FOUND` |
| Quantity `<= 0` | 422 | `VALIDATION_FAILED` |
| Duplicate vendor invoice for that vendor | 409 | `DUPLICATE_RESOURCE` |
| Raw material soft-deleted | 422 | `BUSINESS_RULE_VIOLATION` |

**Side effects** — all inside one database transaction:
`purchases` + `purchase_items` inserted · `stock_transactions` rows of type `PURCHASE` (stock IN) inserted ·
`stock_balances` updated · vendor outstanding recalculated · `audit_logs` entry written.
