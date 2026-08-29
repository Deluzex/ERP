# ADR-015: Discount, GST and Round-Off Calculation Rules

- **Status:** **Accepted** (client-confirmed 2026-08-29)
- **Date:** 2026-08-29
- **Deciders:** Client (business confirmation), Product Owner, Business Analyst
- **Phase:** 0 (rules) / 1 (implementation)
- **Related:** ADR-011 (decimal types), ADR-014, `Client Doc/FINAL_BUSINESS_DECISIONS.md`,
  `docs/modules/stock-management/BUSINESS_RULES.md`
- **Closes:** **Q-05** (calculation rules) and **Q-05a** (round-off behaviour — settled by the client sample
  invoice, now committed at `Client Doc/046 Hotel Winsome, Ahmedabad.pdf`)

## Context

The business source document specifies the line fields *Quantity, Rate, Discount, GST, Line Total* and a
*Total Amount*, but never stated **how** they are calculated. This was recorded as **Q-05** and marked a
blocker, because two of its sub-questions determine the **schema**, not merely the arithmetic:

- whether GST splits into CGST/SGST/IGST (separate columns), and
- whether documents carry a separate round-off amount (a separate column).

The rules were **not** guessed. They were obtained from the client using practical bill examples.

## Problem

What is the exact calculation order, GST treatment and rounding convention for Purchase and Sales documents?

## Decision — confirmed by the client

### 1. Calculation order — discount applies **before** GST

```
Gross Amount
   → Discount
      → Taxable Amount
         → GST
            → Round Off
               → Grand Total
```

Worked example, exactly as confirmed:

| Step | Value |
| --- | --- |
| Product amount (gross) | ₹1,000 |
| Discount | ₹100 |
| **Taxable amount** | **₹900** |
| GST | calculated on **₹900** — never on ₹1,000 |

**GST is never calculated on the pre-discount amount.**

### 2. GST treatment depends on transaction location

The client's place of business is **Gujarat**.

| Transaction location | Treatment |
| --- | --- |
| **Within Gujarat** (intra-state) | **IGST does NOT apply.** Intra-state treatment applies — CGST + SGST as applicable |
| **Outside Gujarat** (inter-state) | **IGST applies** |

**Do not hardcode a single GST type for all transactions.** The applicable treatment is **determined by the
system** from the relevant business/location rules on each transaction — it is not a fixed setting and not a
manual per-line choice.

**Schema consequence:** documents and their lines carry **separate CGST, SGST and IGST amounts**, and the
system stores the state information needed to determine which applies.

### 3. Round-off — settled by the client sample invoice (Q-05a closed 2026-08-29)

**Authoritative reference:** `Client Doc/046 Hotel Winsome, Ahmedabad.pdf` — Tax Invoice 046, 17-March-26,
Blazon Creative → Hotel Winsome. Now committed to the repository; see
`Client Doc/FINAL_BUSINESS_DECISIONS.md` for the full reconciliation.

What the invoice shows:

| Line | Value |
| --- | --- |
| Taxable Value | ₹84,825.00 |
| Output CGST @ 9% | ₹7,634.25 |
| Output SGST @ 9% | ₹7,634.25 |
| *(tax-inclusive sub-total)* | *(₹1,00,093.50)* |
| **Round Off** | **−₹93.50** |
| **Total** | **₹1,00,000.00** |

Confirmed rules:

1. Round-off is a **separate, labelled line**; it is **never** folded into an item amount or a tax amount —
   the Taxable Value and the CGST/SGST figures are untouched by it.
2. It is applied **after GST**, to the tax-inclusive sub-total.
3. It is a **signed amount** (negative in this example).
4. The **Total is the payable amount after** round-off.

#### ⚠️ It is not automatic paise-rounding

A nearest-rupee rounding of ₹1,00,093.50 would give a round-off of **−₹0.50** and a total of ₹1,00,093.00.
The invoice shows **−₹93.50**, producing a clean ₹1,00,000.00. The round-off on this document is an
**agreed adjustment to reach a negotiated total**, not the output of a rounding algorithm.

**Schema and implementation consequence:** `round_off_amount` is a **separate, enterable, signed column**,
and the total is derived as `taxable + tax + round_off`. It must **not** be implemented as a hard-coded
`ROUND()` of the sub-total — that would make this exact invoice impossible to reproduce.

Per the client instruction, this behaviour is followed as observed. **No generic rounding rule has been
invented.**

### 4. Precision

All of the above is computed with **decimal arithmetic** (ADR-011). Floating point is forbidden anywhere in
this chain.

## Reason

These are **client-confirmed business rules**, not engineering choices — this ADR records them so they are
traceable and cannot drift.

Two points are worth stating explicitly for implementers:

**Why discount-before-GST matters.** Applying GST to the gross amount and discounting afterwards produces a
different tax figure and therefore a different tax liability. This is a compliance matter, not a rounding
preference. The order in §1 is not negotiable and not an implementation detail.

**Why the GST type must be derived, not configured.** Hardcoding CGST+SGST because "the client is in Gujarat"
breaks the first inter-state transaction and produces incorrect tax on a real invoice. The determination must
be data-driven per transaction.

## Consequences

**Positive:** Q-05 is closed and the first migration is unblocked; the tax columns are known before the
schema is written rather than being retrofitted onto posted financial documents; the calculation has a single
authoritative definition to test against.

**Negative / accepted costs:**
- Additional columns on documents and lines: taxable amount, CGST/SGST/IGST amounts, round-off.
- The system must hold **state/place-of-supply information** for the client's organization and for each
  vendor and customer, in order to derive the GST treatment. Where that is missing on a master record, the
  determination cannot be made — validation must require it rather than silently defaulting to intra-state.
- Rounding must be applied at defined points with a documented mode; implicit rounding is forbidden.

**Follow-up actions:**
- `docs/modules/stock-management/BUSINESS_RULES.md`: rules `BR-CALC-*` added and BR-PUR-013 closed.
- `docs/modules/stock-management/DATABASE_DESIGN.md`: tax and round-off columns added; the Q-05 blocker
  removed.
- `docs/modules/stock-management/TEST_CASES.md`: `TC-CALC-*` scenarios added, including the ₹1,000 / ₹100 /
  ₹900 worked example, intra-state versus inter-state, and separate round-off presentation.

## Resolved: the former outstanding items

This ADR previously flagged two gaps. **Both are now closed** (2026-08-29):

1. ~~The client's sample bill is not in the repository.~~ ✅ It is now committed at
   `Client Doc/046 Hotel Winsome, Ahmedabad.pdf`, alongside a full arithmetic reconciliation.
2. ~~The exact round-off direction is not derivable from the wording alone.~~ ✅ Resolved — and the answer was
   **neither** of the two candidates previously considered. The sample shows a **−₹93.50** adjustment to a
   negotiated total, not a truncation or a nearest-rupee rounding. This is exactly why the rule was not
   guessed: both plausible guesses would have been wrong, and either would have produced invoices the client
   could not reproduce.

`PROJECT_RULES.md` §3 held: we did not invent the rule, and the source document settled it differently from
the recommendation.

## What the sample also verified

The invoice independently confirmed two rules this ADR had recorded from description alone:

- **Intra-state GST.** Seller GSTIN `24ANHPP9559M1Z5`, buyer GSTIN `24AABFH0054N1ZL` — both Gujarat state
  code `24`. The invoice carries **CGST + SGST and no IGST line**, as §2 requires.
- **Place-of-supply data is real.** GSTIN and State Name appear for seller, consignee and buyer, supporting
  the validation requirement in §Consequences.

It also surfaced a field the business source document never mentioned — **HSN/SAC codes**, present per line
and in a tax summary. Raised as **Q-23**; it is a GST-invoice requirement, not an optional extra.
