# Final Business Decisions — Client Confirmed

**Date:** 2026-08-29 · **Source:** Client / CTO confirmation
**Status:** ✅ **CLOSED — do not re-ask these questions**

This file records four business decisions that close the last outstanding questions in
`docs/business/OPEN_QUESTIONS.md`. Where a decision names a client document, that document is stored in this
folder as the authoritative reference.

---

## Q-22 — Legal Entity ✅ CLOSED

> The current client has **ONE legal entity only**. The ERP is being built for this single legally
> registered entity/business.

**Consequences for the design:**

- `company_id` is **not** needed on documents, masters or unique constraints.
- Item Code, document numbers and all master identifiers are unique **across the organization**:
  `UNIQUE (item_code)`, not `UNIQUE (company_id, item_code)`.
- There is **one GSTIN** and **one place of business** (Gujarat — confirmed by the sample invoice below),
  so GST determination compares the counterparty's state against that single registered state.
- `company_id` survives only on `stock_locations`, as the organizational anchor for the stock hierarchy
  (ADR-013).

Combined with ADR-014 (single-client dedicated deployment), this means **no tenant column and no
organizational discriminator anywhere in the schema**.

---

## Q-05a — Round Off ✅ CLOSED

> The provided **Hotel Winsome sample invoice** is the authoritative reference for round-off behavior.
> Round-off must be shown separately and the confirmed billing behavior should be followed.
> **Do not invent a generic rounding rule.**

**Authoritative document:** [`046 Hotel Winsome, Ahmedabad.pdf`](046%20Hotel%20Winsome,%20Ahmedabad.pdf)
(Tax Invoice 046, dated 17-March-26, Blazon Creative → Hotel Winsome)

### What the invoice demonstrates

| Line | Value |
| --- | --- |
| 12mm Toughened glass @ ₹345.00 | ₹52,785.00 |
| Jummer, 12 No @ ₹2,670.00 | ₹32,040.00 |
| **Taxable Value** | **₹84,825.00** |
| Output CGST @ 9% | ₹7,634.25 |
| Output SGST @ 9% | ₹7,634.25 |
| *(sub-total including tax)* | *(₹1,00,093.50)* |
| **Round Off** | **−₹93.50** |
| **Total** | **₹1,00,000.00** |

The arithmetic reconciles exactly: `84,825.00 + 7,634.25 + 7,634.25 = 1,00,093.50`, and
`1,00,093.50 − 93.50 = 1,00,000.00`.

### Confirmed round-off behaviour

| # | Rule | Evidence from the invoice |
| --- | --- | --- |
| 1 | Round Off is a **separate, labelled line** on the invoice | Shown as its own "Round Off" row |
| 2 | It is applied **after GST**, to the tax-inclusive sub-total | It reduces 1,00,093.50 → 1,00,000.00 |
| 3 | It is **never folded into** an item amount or a tax amount | Taxable Value stays ₹84,825.00; CGST/SGST stay ₹7,634.25 each; the HSN summary is unaffected |
| 4 | It is **signed** — it may be negative | −93.50 |
| 5 | Its magnitude is **not limited to paise** | ₹93.50, not ₹0.50 |
| 6 | The **Total is the payable amount after** round off | ₹1,00,000.00, and "Amount Chargeable (in words): INR One lakh Only" |

### ⚠️ The most important detail — read this before implementing

**This is not automatic paise-rounding.** A nearest-rupee rounding of ₹1,00,093.50 would produce a round-off
of −₹0.50 and a total of ₹1,00,093.00. The invoice instead shows **−₹93.50**, bringing the total to a clean
**₹1,00,000.00**.

That means the round-off on this invoice is an **agreed/entered adjustment to reach a negotiated total**, not
a value computed by a rounding algorithm.

**Implementation consequence:** `round_off_amount` must be an **enterable, signed amount** on the document,
with the Total derived as `taxable + tax + round_off`. It must **not** be implemented as a hard-coded
`ROUND()` of the sub-total — doing so would make this exact invoice impossible to reproduce.

This is the behaviour the client's own document shows. Per the instruction, it is followed as-is; no generic
rounding rule has been invented.

### Also confirmed by this invoice

- **Intra-state GST treatment (ADR-015 §2).** Seller GSTIN `24ANHPP9559M1Z5` and buyer GSTIN
  `24AABFH0054N1ZL` — both State Code `24` (Gujarat). The invoice carries **CGST + SGST and no IGST line**,
  exactly as ADR-015 requires.
- **Place-of-supply data is real and required.** GSTIN and State Name appear for the seller, the consignee
  (Ship to) and the buyer (Bill to) — supporting BR-CALC-014.
- **Consignee and Buyer are separate fields** (Ship to vs Bill to), even when identical as here.
- **HSN/SAC codes appear per line and in a tax summary** (`7013` here) — see the note in
  `docs/business/OPEN_QUESTIONS.md` (Q-23).
- **Amount in words** is printed on the invoice.
- The unit `No` (Number) appears on line 2 — relevant to the Unit Master below.

---

## Q-19 — Stock Transfer ✅ CLOSED

> Stock transfer is **NOT currently required** and is not part of the approved Stock Management scope.
> **Do not implement it** unless explicitly required later.

**Consequences:**

- The `stock_transaction_type` enum keeps exactly the **eight** types from the business source document.
  **No `TRANSFER` type is added.**
- Multiple stock locations remain supported (ADR-013) — stock can be held at several locations, but the
  system does not move stock between them.
- If transfer is required later it is a **new business decision** requiring approval and its own ADR.

---

## Q-15 — Unit ✅ CLOSED

> Create a **dedicated Unit Master**. Products will reference the applicable unit.
> **Do not introduce unit-conversion functionality** unless explicitly required later.

**Consequences:**

- `units` is a first-class master table with its own CRUD, exactly as already designed in
  `docs/modules/stock-management/DATABASE_DESIGN.md` §3.
- Raw Materials and Finished Products each reference **one** unit (`unit_id`).
- **No conversion factors, no base unit, no dual-quantity columns** on the ledger.
- A ledger quantity is therefore always expressed in the item's own unit — unambiguous, which matters because
  the ledger is append-only (ADR-005) and cannot be reinterpreted retroactively.
- The sample invoice uses `No` (Number); the business source document names `kg`, `sq feet` and `piece`.

---

## Where these decisions are reflected

| Decision | Documents updated |
| --- | --- |
| Q-22 | ADR-014, `DATABASE_RULES.md`, `DATABASE_DESIGN.md`, `BUSINESS_RULES.md` |
| Q-05a | **ADR-015**, `BUSINESS_RULES.md` (`BR-CALC-*`), `DATABASE_DESIGN.md`, `TEST_CASES.md` |
| Q-19 | ADR-013, `GLOSSARY.md`, `BUSINESS_RULES.md` |
| Q-15 | ADR-013 / `REQUIREMENTS.md`, `DATABASE_DESIGN.md`, `BUSINESS_RULES.md` |

**These four questions are closed. Do not re-ask them.**
