# Stock Management — Test Cases (Phase 1)

**Status:** Active · **Related:** `TESTING_RULES.md`, `BUSINESS_RULES.md`, ADR-014, ADR-015
**Purpose:** the scenarios that must exist **before** implementation (TDD Step 2). Each maps to a business
rule id, so a reviewer can check coverage against the rules rather than against a coverage percentage.

> **Revised 2026-08-29.** Tenant-isolation scenarios are **removed** — the project is single-client
> (ADR-014). They are replaced by resource-level authorization cases returning **403**, not 404.
> New `TC-CALC-*` scenarios cover the client-confirmed discount/GST/round-off rules (ADR-015), including
> **TC-CALC-023**, which reproduces the real client invoice in `Client Doc/` end to end.

---

## 0. How to use this document

1. Copy the relevant block into your test file **before writing any production code**.
2. Run it — this is the **RED** phase. Paste the output into the PR.
3. Implement until GREEN.
4. Never delete or weaken a case to reach green.

**Legend:** 🔒 = security test (mandatory) · 💾 = database/transaction test · ⚠️ = blocked on an open question

---

## 1. Mandatory Trio — Every Protected Endpoint

Applies to **every** endpoint in `API_SPECIFICATION.md`. No exceptions.

| Id | Scenario | Expected | Rule |
| --- | --- | --- | --- |
| TC-SEC-001 🔒 | Request with no token | `401 UNAUTHENTICATED` | BR-SEC-001 |
| TC-SEC-002 🔒 | Token without the required permission | `403 PERMISSION_DENIED` | BR-SEC-001 |
| TC-SEC-003 🔒 | Caller acts on an existing resource outside their scope | **`403`** (not 404 — ADR-014) | BR-SEC-003 |
| TC-SEC-004 🔒 | List endpoint with a stock-location filter outside scope | `403 STOCK_LOCATION_OUT_OF_SCOPE` | BR-SEC-002 |
| TC-SEC-005 🔒 | Payload includes `isApproved` / `createdBy` / `totalAmount` | Fields stripped or rejected; server values used | BR-SEC-002 |
| TC-SEC-006 🔒 | Expired token | `401` | BR-SEC-001 |
| TC-SEC-007 🔒 | Stock location outside the caller scope | `403 STOCK_LOCATION_OUT_OF_SCOPE` | BR-SEC-001 |

```ts
// the shape every module repeats
describe('access control', () => {
  it('returns 403 when the caller lacks the permission', async () => {
    const { token } = await seedUserWithPermissions(['vendor.view']);   // no vendor.delete

    const res = await api.delete('/vendors/' + vendor.id).auth(token).send({ reason: 'x' });

    expect(res.status).toBe(403);                        // not 404 - ADR-014
    expect(res.body.error.code).toBe('PERMISSION_DENIED');
  });
});
```

---

## 2. Vendor — `TC-VEN-*`

| Id | Scenario | Expected | Rule |
| --- | --- | --- | --- |
| TC-VEN-001 | Create with all required fields | `201`, vendor persisted | BR-VEN-001 |
| TC-VEN-002 | Create without `name` | `422 VALIDATION_FAILED` | BR-VEN-001 |
| TC-VEN-003 | Create without `contactPerson` / `mobile` / `address` | `422` | BR-VEN-001 |
| TC-VEN-004 | Create with malformed email | `422` | BR-VEN-007 |
| TC-VEN-005 | Create with negative credit limit | `422` | BR-VEN-001 |
| TC-VEN-006 🔒 | Create without `vendor.create` | `403 PERMISSION_DENIED` | BR-SEC-001 |
| TC-VEN-007 | **Delete without a reason** | `422` — vendor unchanged | **BR-VEN-003** |
| TC-VEN-008 | Delete with a reason | `200`, `is_deleted = true`, reason/actor/timestamp stored | BR-VEN-003 |
| TC-VEN-009 💾 | Deleted vendor rejected on a new purchase | `422 BUSINESS_RULE_VIOLATION` | BR-VEN-004 |
| TC-VEN-010 | Deleted vendor still resolves on a historical purchase | Name visible | BR-VEN-005 |
| TC-VEN-011 | Outstanding after one confirmed purchase of ₹43,439.06, no payment | `"43439.06"` | BR-VEN-006 |
| TC-VEN-012 | Outstanding after a ₹10,000 payment | `"33439.06"` | BR-VEN-006 |
| TC-VEN-013 | `outstandingBalance` supplied in the request payload | Ignored; value stays derived | BR-VEN-006 |
| TC-VEN-014 💾 | Delete writes an audit entry in the same transaction | Audit row with actor and reason | BR-SEC-004 |
| TC-VEN-015 | List pagination: `pageSize=101` | `422` (not silently clamped) | `API_CONVENTIONS.md` §5 |

---

## 3. Raw Material — `TC-RM-*`

| Id | Scenario | Expected | Rule |
| --- | --- | --- | --- |
| TC-RM-001 | Create with name, item code, unit | `201` | BR-RM-001 |
| TC-RM-002 💾 | Duplicate `itemCode` | `409 DUPLICATE_RESOURCE` | BR-RM-002 |
| TC-RM-003 💾 | Reactivating a soft-deleted item code | Per **Q-06** | BR-RM-009 |
| TC-RM-004 | Create with `openingStock = "100.0000"` | An `ADJUSTMENT` transaction exists with reason "Opening Stock" | **BR-RM-003** |
| TC-RM-005 | After opening stock, balance | `"100.0000"` | BR-RM-003 |
| TC-RM-006 | Quantity with 4 decimals (`"12.3456"`) | Stored exactly, no rounding | BR-RM-008 |
| TC-RM-007 | `minimumStock` and `reorderLevel` set differently | Both persisted independently | BR-RM-004 |
| TC-RM-008 | Balance below `minimumStock` | `isLowStock: true` | BR-RM-005 |
| TC-RM-009 | Balance equal to `minimumStock` | `isLowStock: false` (strict `<`) | BR-RM-005 |
| TC-RM-010 💾 | Unit referencing a non-existent unit id | Rejected by the foreign key | [ENG] |
| TC-RM-011 ⚠️ | Reuse an item code after deletion | Per **Q-06** | BR-RM-009 |
| TC-RM-012 | An item references exactly one unit; no conversion fields exist | Schema has no conversion columns | BR-RM-010 (Q-15) |

---

## 4. Purchase — `TC-PUR-*`

### Creation (draft)

| Id | Scenario | Expected | Rule |
| --- | --- | --- | --- |
| TC-PUR-001 | Create valid draft | `201`, `status: DRAFT` | BR-PUR-006 |
| TC-PUR-002 | **Draft creates no stock transaction** | Ledger count unchanged | **BR-PUR-006** |
| TC-PUR-003 | **Draft creates no vendor outstanding** | Outstanding unchanged | **BR-PUR-006** |
| TC-PUR-004 | Empty `items` array | `422` | BR-PUR-002 |
| TC-PUR-005 | Line with `quantity: "0"` | `422` | BR-PUR-003 |
| TC-PUR-006 | Line with negative quantity | `422` | BR-PUR-003 |
| TC-PUR-007 🔒 | Unknown vendor id | `404 NOT_FOUND` | BR-PUR-005 |
| TC-PUR-008 🔒 | Unknown raw material id | `404 NOT_FOUND` | BR-PUR-004 |
| TC-PUR-009 | Soft-deleted raw material on a line | `422 BUSINESS_RULE_VIOLATION` | BR-PUR-004 |
| TC-PUR-010 | Duplicate vendor invoice number for the same vendor | `409` | BR-PUR-012 |
| TC-PUR-011 | Same invoice number for a **different** vendor | `201` | BR-PUR-012 |
| TC-PUR-012 | Client supplies `totalAmount` | Ignored; server value used | BR-PUR-011 |
| TC-PUR-013 | Client supplies `purchaseNumber` | Ignored; server generates it | BR-PUR-001 |

### Confirmation — the critical path

| Id | Scenario | Expected | Rule |
| --- | --- | --- | --- |
| TC-PUR-020 | Confirm a draft | `200`, `status: CONFIRMED` | BR-PUR-007 |
| TC-PUR-021 | **One `PURCHASE` stock transaction per line** | 3 lines → 3 ledger rows | **BR-PUR-007** |
| TC-PUR-022 | Ledger rows are stock **IN** | `quantityIn > 0`, `quantityOut = 0` | BR-STK-005 |
| TC-PUR-023 | Balance after confirming 150 KG | `"150.0000"` | BR-STK-009 |
| TC-PUR-024 | Vendor outstanding after confirmation | Increases by pending amount | BR-PUR-009 |
| TC-PUR-025 💾 | **Stock posting fails → purchase not persisted** | 0 purchases, 0 ledger rows | **BR-PUR-008** |
| TC-PUR-026 💾 | **Balance update fails → nothing persisted** | Full rollback | **BR-PUR-008** |
| TC-PUR-027 💾 | Audit write fails → full rollback | Nothing persisted | BR-SEC-004 |
| TC-PUR-028 | Confirm an already-confirmed purchase | `409 INVALID_STATE_TRANSITION` | — |
| TC-PUR-029 | Same `Idempotency-Key` sent twice | One purchase, one set of ledger rows, same response | NFR-4 |
| TC-PUR-030 💾 | Two concurrent confirmations of the same draft | Exactly one succeeds; stock posted once | BR-STK-010 |
| TC-PUR-031 | `purchaseNumber` unique across the organization | Sequential, no duplicates | BR-PUR-001 |
| TC-PUR-032 💾 | Concurrent confirmations produce distinct numbers | No duplicate key error, no reuse | BR-PUR-001 |
| TC-PUR-033 | Calculation and rounding | See **`TC-CALC-*`** below — client-confirmed (ADR-015) | BR-CALC-* |
| TC-PUR-034 ⚠️ | Credit limit exceeded | Per **Q-13** | BR-VEN-008 |
| TC-PUR-035 ⚠️ | Edit a confirmed purchase | Per **Q-12** | BR-PUR-014 |

```ts
// TC-PUR-025 — the test that protects the ledger
it('does not persist the purchase when stock posting fails', async () => {
  jest.spyOn(stockLedger, 'post').mockRejectedValueOnce(new Error('boom'));

  await expect(confirmPurchase.execute(draftId, ctx)).rejects.toThrow();

  expect(await purchaseRepo.countConfirmed(ctx.companyId)).toBe(0);
  expect(await ledgerRepo.countFor(ctx.companyId)).toBe(0);
  expect(await vendorRepo.outstanding(vendorId, ctx)).toEqual(dec('0'));
});
```

---

## 5. Vendor Payment — `TC-PAY-*`

| Id | Scenario | Expected | Rule |
| --- | --- | --- | --- |
| TC-PAY-001 | Record a valid payment | `201`; pending reduced | BR-PAY-001 |
| TC-PAY-002 | Vendor outstanding reduced | By the payment amount | BR-PAY-002 |
| TC-PAY-003 | Payment of `"0"` or negative | `422` | BR-PAY-003 |
| TC-PAY-004 | Payment exceeding the pending amount | `422` | BR-PAY-004 |
| TC-PAY-005 | Payment exactly equal to pending | `201`; pending `"0.00"` | BR-PAY-004 |
| TC-PAY-006 | Payment against a DRAFT purchase | `422` | BR-PUR-006 |
| TC-PAY-007 | No `DELETE` endpoint exists for payments | Route absent | BR-PAY-005 |
| TC-PAY-008 🔒 | Payment recorded without `payment.create` | `403 PERMISSION_DENIED` | BR-SEC-001 |

---

## 6. Stock Transactions — `TC-STK-*`  *(the core suite)*

| Id | Scenario | Expected | Rule |
| --- | --- | --- | --- |
| TC-STK-001 💾 | **`UPDATE` on `stock_transactions`** | Database raises; row unchanged | **BR-STK-004** |
| TC-STK-002 💾 | **`DELETE` on `stock_transactions`** | Database raises; row remains | **BR-STK-004** |
| TC-STK-003 💾 | Row with both `quantityIn` and `quantityOut` > 0 | Check constraint rejects | BR-STK-005 |
| TC-STK-004 💾 | Row with both = 0 | Check constraint rejects | BR-STK-005 |
| TC-STK-005 💾 | `ADJUSTMENT` without a reason | Check constraint rejects | BR-ADJ-001 |
| TC-STK-006 | Every row carries a reference to its source document | `referenceType` + `referenceId` present | BR-STK-006 |
| TC-STK-007 | Every row records `performedBy` | Actor from the token | BR-STK-012 |
| TC-STK-008 💾 | **Ledger/balance invariant** after 20 mixed movements | `SUM(in) − SUM(out) = balance` | **BR-STK-009** |
| TC-STK-009 💾 | Rebuild balances from the ledger | Matches `stock_balances` exactly | BR-STK-009 |
| TC-STK-010 💾 | Two concurrent stock postings for the same item | Both applied; no lost update | BR-STK-010 |
| TC-STK-011 🔒 | Ledger query filtered to a stock location outside the caller scope | `403 STOCK_LOCATION_OUT_OF_SCOPE` | BR-SEC-002 |
| TC-STK-012 | Balances are per warehouse | 100 in W1, 50 in W2 → separate balances | BR-STK-008 |
| TC-STK-013 | Running balance in the history response | Matches the cumulative sum | `DATABASE_DESIGN.md` §10 |
| TC-STK-014 | No POST/PATCH/DELETE route on `/stock-transactions` | 404/405 | BR-STK-004 |
| TC-STK-015 | Invalid transaction type value | `422` — only the eight types accepted | BR-STK-007 |
| TC-STK-016 | `TRANSFER` submitted as a transaction type | `422` — **not a valid type**; transfer is out of scope (Q-19) | BR-STK-007 |

```ts
// TC-STK-008 — the invariant that defines the module
it('keeps the balance equal to the ledger sum after mixed movements', async () => {
  await postPurchase('100');
  await postAdjustment('OUT', '20', 'damage');
  await postPurchase('50');

  const ledgerSum = await db.query(
    `SELECT SUM(quantity_in) - SUM(quantity_out) AS q
       FROM stock_transactions
      WHERE company_id = $1 AND item_id = $2 AND stock_location_id = $3`,
    [companyId, itemId, stockLocationId]);

  const balance = await balanceRepo.get(itemId, stockLocationId, ctx);

  expect(balance).toEqual(dec(ledgerSum.rows[0].q));   // 130.0000
});
```

---

## 7. Stock Adjustment — `TC-ADJ-*`

| Id | Scenario | Expected | Rule |
| --- | --- | --- | --- |
| TC-ADJ-001 | **Adjustment without a reason** | `422` | **BR-ADJ-001** |
| TC-ADJ-002 | Adjustment with a reason | `201`; `ADJUSTMENT` row created | BR-ADJ-002 |
| TC-ADJ-003 | Adjustment IN increases the balance | Balance grows | BR-ADJ-002 |
| TC-ADJ-004 | Adjustment OUT decreases the balance | Balance shrinks | BR-ADJ-002 |
| TC-ADJ-005 | Adjustment OUT exceeding available stock | `422 INSUFFICIENT_STOCK` | BR-ADJ-004 |
| TC-ADJ-006 💾 | Audit entry records before and after balances | Present, same transaction | BR-ADJ-003 |
| TC-ADJ-007 🔒 | User without `stock.adjust` | `403` | BR-SEC-001 |
| TC-ADJ-008 🔒 | Adjustment against a stock location outside the caller scope | `403` | BR-SEC-003 |
| TC-ADJ-009 | Quantity `"0"` | `422` | BR-ADJ-002 |
| TC-ADJ-010 ⚠️ | Approval requirement | Per **Q-11** | BR-ADJ-005 |

---

## 7a. Calculation, Tax and Round-Off — `TC-CALC-*`  ✅ client-confirmed (ADR-015)

These replace the previously blocked Q-05 scenarios. The order of operations is a **compliance** requirement,
so these tests are as important as the ledger tests.

### Discount before GST

| Id | Scenario | Expected | Rule |
| --- | --- | --- | --- |
| **TC-CALC-001** | **The worked example:** gross `"1000.00"`, discount `"100.00"` | `taxableAmount = "900.00"` | **BR-CALC-002/003** |
| **TC-CALC-002** | GST at 18% on the above | Tax computed on **900**, i.e. `"162.00"` — **never** on 1000 (`"180.00"`) | **BR-CALC-001** |
| TC-CALC-003 | Zero discount | `taxableAmount == grossAmount` | BR-CALC-002 |
| TC-CALC-004 | Discount equal to gross | `taxableAmount = "0.00"`, tax `"0.00"` | BR-CALC-002 |
| TC-CALC-005 | Discount greater than gross | `422 VALIDATION_FAILED` | [ENG] |
| TC-CALC-006 | Discount entered as a percentage in the UI | The **resolved rupee amount** is stored | BR-CALC-004 |

```ts
// TC-CALC-002 — the test that protects tax compliance
it('calculates GST on the discounted amount, not the gross', async () => {
  const purchase = await createPurchase({
    items: [{ quantity: '1', rate: '1000.00', discountAmount: '100.00', gstPercent: '18' }],
  });

  expect(purchase.taxableAmount).toEqual(dec('900.00'));
  expect(totalTax(purchase)).toEqual(dec('162.00'));   // 18% of 900
  expect(totalTax(purchase)).not.toEqual(dec('180.00')); // 18% of 1000 would be wrong
});
```

### GST determination by place of supply

| Id | Scenario | Expected | Rule |
| --- | --- | --- | --- |
| **TC-CALC-010** | Transaction **within Gujarat** | `cgstAmount > 0`, `sgstAmount > 0`, **`igstAmount == "0.00"`** | **BR-CALC-011** |
| **TC-CALC-011** | Transaction **outside Gujarat** | **`igstAmount > 0`**, `cgstAmount == sgstAmount == "0.00"` | **BR-CALC-012** |
| TC-CALC-012 💾 | Row with both IGST and CGST/SGST non-zero | Check constraint rejects | BR-CALC-013 |
| TC-CALC-013 | Vendor with no place-of-supply information | `422` — the transaction is rejected, **not** defaulted to intra-state | BR-CALC-014 |
| TC-CALC-014 | GST type supplied by the client in the payload | Ignored; the server determines it | BR-CALC-010 |
| TC-CALC-015 | Same vendor, two transactions with different places of supply | Each gets its own treatment — no cached/fixed type | BR-CALC-010 |

> TC-CALC-015 is the test that catches the most likely implementation shortcut: computing the GST type once
> from a setting instead of per transaction.

### Round-off

| Id | Scenario | Expected | Rule |
| --- | --- | --- | --- |
| **TC-CALC-020** | Any document with a fractional total | `roundOffAmount` is present as its **own field** in the response | **BR-CALC-020** |
| TC-CALC-021 | Line amounts and tax amounts | **Do not** include the round-off — it is never folded in | BR-CALC-021 |
| TC-CALC-022 | Document with an exact rupee total | `roundOffAmount = "0.00"`, still present | BR-CALC-020 |
| **TC-CALC-023** | **Reproduce the client sample invoice end to end** (see below) | Taxable `"84825.00"`, CGST `"7634.25"`, SGST `"7634.25"`, IGST `"0.00"`, roundOff `"-93.50"`, grandTotal `"100000.00"` | **BR-CALC-023** |
| TC-CALC-024 | Round-off supplied; taxable and tax amounts | Unchanged by the round-off | BR-CALC-024 |
| TC-CALC-025 | `roundOffAmount` computed with `ROUND()` instead of accepted as input | **Must fail** — TC-CALC-023 cannot pass with an automatic rounding rule | BR-CALC-023 |


```ts
// TC-CALC-023 — the golden test: the real client invoice, end to end
// Source: Client Doc/046 Hotel Winsome, Ahmedabad.pdf (Tax Invoice 046, 17-March-26)
it('reproduces the Hotel Winsome invoice exactly', async () => {
  const inv = await createInvoice({
    sellerState: 'Gujarat', buyerState: 'Gujarat',   // intra-state
    items: [
      { description: '12mm Toughned glass', hsn: '7013', rate: '345.00', amount: '52785.00' },
      { description: 'Jummer', hsn: '7013', quantity: '12', unit: 'No', rate: '2670.00' },
    ],
    gstPercent: '18',                                // 9% CGST + 9% SGST
    roundOffAmount: '-93.50',                        // ENTERED, not computed
  });

  expect(inv.taxableAmount).toEqual(dec('84825.00'));
  expect(inv.cgstAmount).toEqual(dec('7634.25'));
  expect(inv.sgstAmount).toEqual(dec('7634.25'));
  expect(inv.igstAmount).toEqual(dec('0.00'));       // intra-state: no IGST
  expect(inv.roundOffAmount).toEqual(dec('-93.50'));
  expect(inv.grandTotal).toEqual(dec('100000.00'));  // 100093.50 - 93.50
});
```

> **This is the highest-value test in the calculation suite.** It is a real client document with real
> numbers, so it validates the whole chain at once: intra-state GST selection, the tax base, decimal
> precision, and round-off as an **entered** value. An implementation that computes round-off with `ROUND()`
> produces `100093.00` and fails this test — which is exactly the point (TC-CALC-025).

---

## 8. Money and Quantity Precision — `TC-NUM-*`

| Id | Scenario | Expected | Rule |
| --- | --- | --- | --- |
| TC-NUM-001 | Three lines of `"33.33"` | Total `"99.99"` exactly — never `99.99000000000001` | ADR-011 |
| TC-NUM-002 | Money serialised in JSON | A **string**, not a number | ADR-011 |
| TC-NUM-003 | Quantity `"0.0001"` | Stored and returned exactly | ADR-011 |
| TC-NUM-004 | Amount `"0.1"` + `"0.2"` | `"0.30"` | ADR-011 |
| TC-NUM-005 | Sum of 1,000 ledger rows | Exact to the last decimal | ADR-011 |

---

## 9. Flutter Tests — `TC-UI-*`

| Id | Scenario | Expected |
| --- | --- | --- |
| TC-UI-001 | Vendor list — loading state | Skeleton shown |
| TC-UI-002 | Vendor list — empty state | "No vendors yet" + add action |
| TC-UI-003 | Vendor list — error state | Message + correlation id + retry |
| TC-UI-004 | Vendor list — data state | Rows rendered |
| TC-UI-005 | `403` from the API | Permission message, **not** an empty list |
| TC-UI-006 | Delete vendor dialog | Confirm disabled until a reason is typed |
| TC-UI-007 | Logout | All cached provider state cleared |
| TC-UI-008 🔒 | Stock-location switch | Previous location data not rendered |
| TC-UI-009 | Compact width (375) | Cards, not a data table |
| TC-UI-010 | Expanded width (1440) | Table + sidebar |
| TC-UI-011 | Purchase totals | Taken from the API response, not computed in Dart |

---

## 10. Coverage Checklist Before "Done"

- [ ] All seven `TC-SEC-*` cases exist for every new endpoint (401 / 403 permission / 403 out-of-scope)
- [ ] Every `BR-*` rule in `BUSINESS_RULES.md` maps to at least one test
- [ ] Every 💾 rollback and constraint case runs against **real PostgreSQL**
- [ ] `TC-CALC-*` pass — discount before GST, place-of-supply GST type, separate round-off
- [ ] **TC-CALC-023 (the Hotel Winsome invoice) reproduces exactly** — the golden calculation test
- [ ] The ledger invariant test (TC-STK-008) passes
- [ ] The append-only tests (TC-STK-001/002) pass
- [ ] Money precision tests (TC-NUM-*) pass
- [ ] No test is skipped, weakened or marked `.only`
- [ ] The RED run for the new cases is recorded in the PR
