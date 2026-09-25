# Stock Management — Business Rules (Phase 1)

**Status:** Active — rules marked ⚠️ depend on an open question. Calculation rules (`BR-CALC-*`) are
**client-confirmed** as of 2026-08-29 (ADR-015).
**Source:** `docs/business/STOCK_MANAGEMENT_SOURCE_DOCUMENT.md`
**Rule format:** `BR-<AREA>-<NNN>` — quote this id in code comments, tests and PR descriptions.

> Every rule below is either **quoted from the source document** or marked **[ENG]** (an engineering
> necessity derived from the architecture) or ⚠️ (blocked on a business answer). No rule here was invented.

---

## Vendor — `BR-VEN-*`

| Id | Rule | Source |
| --- | --- | --- |
| BR-VEN-001 | Vendor Name, Contact Person, Mobile and Address are mandatory | §5.1 |
| BR-VEN-002 | Vendors are organization-wide; visibility is governed by the `vendor.view` permission | [ENG] ADR-014 |
| BR-VEN-003 | Deleting a vendor **requires a reason**; the vendor is soft-deleted, never removed | §5.1, ADR-012 |
| BR-VEN-004 | A soft-deleted vendor cannot be selected for a new purchase | [ENG] |
| BR-VEN-005 | A soft-deleted vendor remains resolvable on historical purchases | [ENG] ADR-012 |
| BR-VEN-006 | Vendor outstanding is **derived** (confirmed purchases − payments), never directly editable | [ENG] |
| BR-VEN-007 | Email, when supplied, must be a valid address | [ENG] |
| BR-VEN-008 | When vendor or customer credit limit is exceeded, the system **issues a warning** (not a hard block) | ✅ Client-confirmed (Q-13, 2026-09-16) |
| BR-VEN-009 ⚠️ | GST Number format validation, and whether it is mandatory (needed for BR-CALC-014) | **open** |

---

## Raw Material — `BR-RM-*`

| Id | Rule | Source |
| --- | --- | --- |
| BR-RM-001 | Material Name, Item Code and Unit are mandatory | §5.5 |
| BR-RM-002 | Item Code is unique among active records (`WHERE is_deleted = false`); codes can be reused after soft-deletion | ✅ Client-confirmed (Q-06, 2026-09-16) |
| BR-RM-003 | Opening Stock is recorded as an `ADJUSTMENT` stock transaction with reason "Opening Stock" — it is never a stored balance | [ENG] ADR-005 |
| BR-RM-004 | Minimum Stock and Reorder Level are **distinct** fields and must not be merged | §5.5 |
| BR-RM-005 | An item is **low stock** when current balance < Minimum Stock | §4, §5.5 |
| BR-RM-006 | Default Purchase Price pre-fills a purchase line but is always editable | §5.5 |
| BR-RM-007 | A raw material with any stock transaction can never be hard-deleted | [ENG] ADR-012 |
| BR-RM-008 | Quantity is stored with 4 decimal places (`kg` and `sq feet` are divisible) | [ENG] ADR-011 |
| BR-RM-009 | An Item Code **can be reused** after soft-deletion | ✅ Client-confirmed (Q-06, 2026-09-16) |
| BR-RM-010 | An item references **exactly one** unit from the Unit Master. **No unit conversion** — a purchase unit and a consumption unit are always the same | ✅ Client-confirmed (Q-15) |

---

## Finished Product — `BR-FP-*`

| Id | Rule | Source |
| --- | --- | --- |
| BR-FP-001 | Product Name and Unit are mandatory | §5.6 |
| BR-FP-002 | Three separate prices are held: Cost Price, Dealer Selling Price, Customer Selling Price | §5.6 |
| BR-FP-003 | Dealer and Customer prices are independent — a Dealer sale does not use the Customer price | §5.6 |
| BR-FP-004 | Finished Product stock can only be increased by `PRODUCTION_OUTPUT` or `SALE_RETURN` | §8 |
| BR-FP-005 | In Phase 1 no transaction creates finished product stock; the master and its (zero) balance exist only | [ENG] phase discipline |
| BR-FP-006 ⚠️ | Whether Item Code is mandatory for Finished Products (not marked `*` in the source) | open |

---

## Purchase — `BR-PUR-*`

| Id | Rule | Source |
| --- | --- | --- |
| BR-PUR-001 | Purchase Number is auto-generated **server-side** with a prefixed continuous format (`PUR-2026-0046`), unique across the organization | §6, [ENG], Q-07 |
| BR-PUR-002 | A purchase must have at least one line | [ENG] |
| BR-PUR-003 | Quantity > 0 and Rate ≥ 0 on every line | [ENG] |
| BR-PUR-004 | Only active (not soft-deleted) raw materials may be purchased | [ENG] |
| BR-PUR-005 | An unknown vendor returns **404**; a vendor the caller may not use returns **403** | [ENG] `SECURITY_RULES.md` §6.1 |
| BR-PUR-006 | **A draft purchase does not affect stock and creates no vendor outstanding** | §6 (Save Draft), [ENG] |
| BR-PUR-007 | Confirming a purchase writes **one `PURCHASE` stock transaction per line**, increasing Raw Material stock | §6, §8 |
| BR-PUR-008 | Purchase persistence, stock posting, balance update, outstanding update and audit entry are **one atomic database transaction** — all or nothing | [ENG] ADR-005 |
| BR-PUR-009 | Vendor outstanding increases by the pending amount on confirmation | §6 |
| BR-PUR-010 | Pending Amount = Grand Total − Paid Amount (BR-CALC-*) | §6 |
| BR-PUR-011 | Totals are computed server-side; a client-supplied total is ignored | [ENG] |
| BR-PUR-012 | The same Vendor Invoice Number may not be recorded twice for the same vendor | [ENG] duplicate-bill protection |
| BR-PUR-013 | Calculation order for discount, GST and rounding | ✅ **Client-confirmed — see `BR-CALC-*`** (ADR-015) |
| BR-PUR-014 ⚠️ | Whether a confirmed purchase may be edited, and how stock is corrected if so | **Q-12** |
| BR-PUR-015 | Purchase Number format: continuous prefixed pattern (`PUR-2026-0046`), **no financial-year reset** | ✅ Client-confirmed (Q-07, Q-08, 2026-09-16) |

---

## Calculation, Tax and Rounding — `BR-CALC-*`  ✅ **client-confirmed 2026-08-29 (ADR-015)**

These were previously the project's hard blocker (Q-05). They are now **approved business rules**.

### Order of calculation

```
Gross Amount → Discount → Taxable Amount → GST → Round Off → Grand Total
```

| Id | Rule | Source |
| --- | --- | --- |
| **BR-CALC-001** | **Discount is applied BEFORE GST.** GST is calculated on the **taxable amount**, never on the gross amount | Client-confirmed, ADR-015 §1 |
| BR-CALC-002 | `Taxable Amount = Gross Amount − Discount` | Client-confirmed |
| BR-CALC-003 | Worked example: gross ₹1,000, discount ₹100 → taxable **₹900**; GST is computed on ₹900 | Client-confirmed |
| BR-CALC-004 | The **discount amount** (in rupees) is stored, not only a percentage, so a historical document never re-derives differently | [ENG] ADR-015 |
| **BR-CALC-010** | **GST treatment is determined per transaction from the place of supply** — it is never a fixed configuration value and never a manual per-line choice | Client-confirmed, ADR-015 §2 |
| BR-CALC-011 | Transaction **within Gujarat** (intra-state): **IGST does not apply**; CGST + SGST apply as applicable | Client-confirmed |
| BR-CALC-012 | Transaction **outside Gujarat** (inter-state): **IGST applies** | Client-confirmed |
| BR-CALC-013 | CGST/SGST and IGST are **mutually exclusive** on a document and on a line | [ENG] — enforced by check constraint |
| BR-CALC-014 | A vendor or customer without place-of-supply information **cannot have its GST determined** — validation rejects the transaction rather than defaulting to intra-state | [ENG] ADR-015 |
| BR-CALC-015 | The organization has **one GSTIN and one registered state** (Gujarat). GST type compares the counterparty state against that single state | ✅ Q-22 — one legal entity |
| BR-CALC-016 | **HSN/SAC code** per item is a nullable field on Raw Materials and Finished Products; tax invoices print HSN code and HSN tax summary | ✅ Client-confirmed (Q-23, 2026-09-16) |
| **BR-CALC-020** | **Round-off is shown separately** on the bill/invoice | Client-confirmed, ADR-015 §3 |
| BR-CALC-021 | The round-off value is **never hidden inside** an item amount or a tax amount | Client-confirmed |
| BR-CALC-022 | The **Total is the payable amount after** round-off | ✅ Client sample invoice |
| **BR-CALC-023** | Round-off is an **enterable, signed amount**, applied after GST to the tax-inclusive sub-total. `Total = taxable + tax + round_off`. It is **not** an automatic `ROUND()` — the client sample shows −₹93.50 taking ₹1,00,093.50 to ₹1,00,000.00 | ✅ Client sample invoice (Q-05a) |
| BR-CALC-024 | Round-off must **never** alter the Taxable Value or the CGST/SGST/IGST amounts, nor the HSN tax summary | ✅ Client sample invoice |
| BR-CALC-030 | All of the above uses decimal arithmetic; floating point is forbidden anywhere in the chain | ADR-011 |
| BR-CALC-031 | Totals are computed **server-side**; a client-supplied total is ignored | BR-PUR-011 |

> **BR-CALC-001 is a compliance matter, not a rounding preference.** Applying GST to the gross amount and
> discounting afterwards produces a different tax figure and therefore a different tax liability. The order is
> not negotiable.
>
> **BR-CALC-010 must not be shortcut.** Hardcoding CGST+SGST "because the client is in Gujarat" breaks on the
> first inter-state transaction and puts incorrect tax on a real invoice.
>
> **BR-CALC-023 is the rule most likely to be implemented wrongly.** The obvious implementation —
> `round_off = ROUND(subtotal) - subtotal` — cannot reproduce the client sample invoice, which shows a
> **−₹93.50** adjustment to a negotiated total of ₹1,00,000.00. The field is an **input**, not a computation.
> See `Client Doc/046 Hotel Winsome, Ahmedabad.pdf`.

---

## Vendor Payment — `BR-PAY-*`

| Id | Rule | Source |
| --- | --- | --- |
| BR-PAY-001 | A payment reduces the pending amount of the purchase it is applied to | §15 |
| BR-PAY-002 | A payment reduces vendor outstanding | §15 |
| BR-PAY-003 | Payment amount must be > 0 | [ENG] |
| BR-PAY-004 | Total payments against a purchase may not exceed its Total Amount | [ENG] |
| BR-PAY-005 | Payments are never deleted; a mistake is corrected by a reversing entry | [ENG] ADR-012 |
| BR-PAY-006 | Payment mode is recorded | §6 |

---

## Stock Transactions — `BR-STK-*`  *(the core rules)*

| Id | Rule | Source |
| --- | --- | --- |
| BR-STK-001 | **Every** stock movement is recorded as a stock transaction | **§21 (verbatim)** |
| BR-STK-002 | Current stock is **never** the only source of truth | **§21 (verbatim)** |
| BR-STK-003 | Historical stock movements are **never** destroyed to simplify implementation | **§21 (verbatim)** |
| BR-STK-004 | The ledger is **append-only**: no `UPDATE`, no `DELETE` | [ENG] ADR-005 |
| BR-STK-005 | Exactly one direction per row: either Stock In > 0 or Stock Out > 0, never both, never neither | [ENG] |
| BR-STK-006 | Every row references the document that caused it (type, id, number) | §8 |
| BR-STK-007 | Only these eight types exist: `PURCHASE`, `PRODUCTION_CONSUMPTION`, `PRODUCTION_OUTPUT`, `SALE`, `SALE_RETURN`, `PURCHASE_RETURN`, `DAMAGE`, `ADJUSTMENT`. **No `TRANSFER`** — stock transfer is out of scope (Q-19 closed) | §8, Q-19 |
| BR-STK-008 | Stock is tracked per **item per stock location** — branch and warehouse are optional per company | [ENG] ADR-013 (Q-03 closed) |
| BR-STK-009 | `SUM(quantity_in) − SUM(quantity_out) = stock_balances.quantity` per item per **stock location**, always | [ENG] ADR-005 |
| BR-STK-010 | The balance cache is updated in the same transaction, under `SELECT … FOR UPDATE` | [ENG] |
| BR-STK-011 | Corrections are compensating transactions, never edits | [ENG] ADR-005 |
| BR-STK-012 | A ledger row records the acting user | §8 (`performedBy`), ADR-012 |
| BR-STK-013 ⚠️ | Whether stock may go negative | **open — recommend: no for `SALE`/`PRODUCTION_CONSUMPTION`; `ADJUSTMENT` may correct downward but not below zero** |

---

## Stock Adjustment — `BR-ADJ-*`

| Id | Rule | Source |
| --- | --- | --- |
| BR-ADJ-001 | An adjustment requires a **mandatory reason** | §8, ADR-012 |
| BR-ADJ-002 | An adjustment writes an `ADJUSTMENT` stock transaction (in or out) | §8 |
| BR-ADJ-003 | An adjustment writes an audit entry with actor, before and after balance | [ENG] |
| BR-ADJ-004 | An adjustment may not reduce stock below zero | [ENG] ⚠️ see BR-STK-013 |
| BR-ADJ-005 ⚠️ | Whether adjustments require approval, and who may perform them | **Q-11** |

---

## Cross-Cutting — `BR-SEC-*` **[ENG]**

| Id | Rule |
| --- | --- |
| BR-SEC-001 | Every operation verifies authentication, permission, resource access, and branch / stock-location scope where applicable |
| BR-SEC-002 | Permission and scope claims are never accepted from client input |
| BR-SEC-003 | An existing resource the caller may not act on returns **403**; **404** means genuinely not found (ADR-014) |
| BR-SEC-004 | Every business-data change writes an audit entry in the same transaction as the change |
| BR-SEC-005 | Money and quantity use decimal types end to end; floating point is forbidden |

---

## Blocked Rules Summary

These **must** be answered before the corresponding implementation starts:

| Rule | Question | Blocks | Status |
| --- | --- | --- | --- |
| ~~BR-PUR-013~~ | ~~Q-05~~ | ~~Tax calculation~~ | ✅ Closed — ADR-015, see `BR-CALC-*` |
| ~~BR-CALC-023~~ | ~~Q-05a~~ | ~~Round-off entered~~ | ✅ Closed — client sample invoice, ADR-015 §3 |
| ~~BR-STK-008~~ | ~~Q-03~~ | ~~Stock scope location~~ | ✅ Closed 2026-08-29 — ADR-013 |
| ~~BR-VEN-008~~ | ~~Q-13~~ | ~~Credit limit behaviour~~ | ✅ Closed 2026-09-16 — System issues warning |
| ~~BR-RM-009~~ | ~~Q-06~~ | ~~Item code reuse~~ | ✅ Closed 2026-09-16 — Reusable after deletion |
| ~~BR-RM-010~~ | ~~Q-15~~ | ~~Unit conversion~~ | ✅ Closed — dedicated Unit Master, no conversion |
| ~~BR-PUR-015~~ | ~~Q-07, Q-08~~ | ~~Document numbering~~ | ✅ Closed 2026-09-16 — Prefixed continuous sequence |
| ~~BR-CALC-016~~ | ~~Q-23~~ | ~~HSN/SAC codes~~ | ✅ Closed 2026-09-16 — Nullable `hsn_sac_code` on items |
| BR-PUR-014 | Q-12 — editing confirmed documents | Purchase edit UX | Open |
| BR-ADJ-005 | Q-11 — adjustment approval | Stock adjustment | Open |
| BR-STK-013 | negative stock | Ledger validation | Open |
