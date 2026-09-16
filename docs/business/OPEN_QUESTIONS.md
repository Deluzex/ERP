# Open Questions — Requiring Human Decision

**Status:** Active · **Last decision round:** 2026-08-29 (final business decisions)
**Owner:** Business Analyst / Product Owner
**Rule:** Nobody — human or AI — may guess an answer to anything still open. See `PROJECT_RULES.md` §3.

---

## ⚠️ Governing Rule: Clarify Now, Implement Later

> Phase determines **WHEN functionality is implemented**.
> Phase does **NOT** determine when business requirements are clarified.

Questions are prioritised by **impact on design**, not by phase.

---

## ✅ Closed — do not re-ask

**Q-01, Q-02, Q-03, Q-05, Q-05a, Q-06, Q-07, Q-08, Q-09, Q-13, Q-15, Q-19, Q-22, Q-23** are **closed**. See Part B, and
`Client Doc/FINAL_BUSINESS_DECISIONS.md` for earlier closing decisions.

**The database schema is fully unblocked.** Every question that determined column shape and constraints is answered.

---

# PART A — Open Questions

## HIGH — affects a constraint or a required field

### Q-11 · Purchase Return, Damage and Adjustment — no defined flows
**Impact:** HIGH · **Ref:** source document §8

Defined transaction types with reports, but no screen or flow for creating them.

1. Who may create a stock adjustment, and **does it require approval?**
2. Does a purchase return reduce vendor outstanding, and **does it reverse the GST**?
3. Is "Damage" the same as "Wastage" in the production reports?

Approval adds columns (state, approver, timestamp) — hence HIGH.

---

### Q-16 · Commission slab configurability *(Phase 4 — clarified now)*
**Impact:** HIGH for schema · **Ref:** source document §12.2

Slabs are labelled *"Example"*. Configurable per dealer or fixed? Are boundaries inclusive or exclusive — is
exactly ₹5,00,000 in the 1% or 2% band? Do they vary by financial year?

Determines whether commission rules are a configuration table or constants.

---

### Q-18 · Multi-currency and multi-language
**Impact:** MEDIUM-HIGH

The sample invoice is INR, in English, with Indian GST — the answer is almost certainly "INR and English
only". **Please confirm**, so it can be closed.

**Recommendation:** store `currency_code` on the organization anyway — near-zero cost now, expensive to
retrofit onto posted financial documents.

---

## MEDIUM — affects screens and flows

### Q-24 · Consignee (Ship to) vs Buyer (Bill to) 🆕
**Impact:** MEDIUM · **Ref:** `Client Doc/046 Hotel Winsome, Ahmedabad.pdf`

The sample invoice has **separate "Consignee (Ship to)" and "Buyer (Bill to)" blocks**, each with its own
address, GSTIN and State Name. They are identical on this invoice, but the form provides for them to differ.

**Questions:**
1. Must sales invoices support a different ship-to and bill-to party?
2. If they differ, **which one determines the place of supply** for GST (BR-CALC-010)? *(Under GST law it is
   generally the ship-to location for goods — this needs confirmation, not assumption.)*

**Why it matters:** it changes which state drives the CGST/SGST-vs-IGST decision. Phase 3, but per the
governing rule it is asked now because it touches the tax engine.

---

### Q-04 · Missing sections in the source document
Sections **3, 9, 13, 14** do not exist; the screen list has a blank item 10 and jumps 23 → 30. Was content
intended there (approvals? settings?) and lost?

### Q-10 · Quotations and Sales Orders have no detail *(Phase 3)*
Listed as modules and in reports, but no fields or flow given. In scope? If so specify fields, statuses and
the Quotation → Sales Order → Invoice conversion.

### Q-12 · Draft documents and editing posted documents
1. Does a draft affect stock? (It must not — confirm.)
2. Does a draft consume a document number?
3. May a **confirmed** purchase be edited? How is stock corrected?
4. Can a posted purchase be cancelled — compensating ledger entry **and GST reversal**?

**Recommendation:** drafts touch neither stock nor numbering; posted documents are cancelled and re-entered,
preserving the ledger (ADR-005).

### Q-14 · "Retrieve data from image or pdf" on the purchase form
Is OCR import an actual requirement? **Recommendation:** out of scope until confirmed.

### Q-17 · Labour Cost missing from Production fields *(Phase 2)*
The costing formula includes Labour Cost but the field list has only *Other Expenses*. Manual entry, a rate
per unit, or folded in?

### Q-20 · Low stock threshold — Minimum Stock or Reorder Level?
Both fields exist; the document never says which drives the alert.
**Recommendation:** Minimum Stock triggers the alert; Reorder Level drives a purchase suggestion.

### Q-21 · Stock scope level changes after go-live
Can `stock_scope_level` change once stock exists? **Recommendation:** a controlled, audited migration, never
a settings dropdown. *(Note: this can no longer be done by transferring stock between locations, since
transfer is out of scope — Q-19. It would need an explicit corrective procedure.)*

### Q-25 · Amount in words 🆕
**Ref:** `Client Doc/046 Hotel Winsome, Ahmedabad.pdf`

The sample invoice prints **"Amount Chargeable (in words): INR One lakh Only"** and a tax amount in words.
Confirm this is required on printed documents, and in the **Indian numbering system** (lakh/crore).
Low risk, but it is a printing requirement nobody has listed.

---

# PART B — Answered Questions

| ID | Question | Answer | Date |
| --- | --- | --- | --- |
| **Q-01** | Existing Flutter implementation | **Keep it.** Not deleted, not frozen. New work follows the approved architecture (ADR-010) | 2026-08-29 |
| **Q-02** | Bill of Material | **Not a blocker. Proceed without BOM.** Do not invent BOM functionality | 2026-08-29 |
| **Q-03** | Branch and Warehouse | **Both optional.** All three shapes supported; `warehouse_id` never assumed mandatory — **ADR-013** | 2026-08-29 |
| **Q-05** | Discount, GST, tax and rounding | **Confirmed — ADR-015.** Discount **before** GST (₹1,000 − ₹100 → GST on ₹900); within Gujarat → CGST+SGST, outside → IGST, determined per transaction; round-off shown separately | 2026-08-29 |
| **Q-05a** | Round-off behaviour | **Closed by the client sample invoice** (`Client Doc/046 Hotel Winsome, Ahmedabad.pdf`). Round-off is a separate, **entered**, signed amount applied after GST: −₹93.50 takes ₹1,00,093.50 → ₹1,00,000.00. **Not** an automatic `ROUND()` | 2026-08-29 |
| **Q-06** | Item code reuse after deletion | **Confirmed.** Item code **can be reused** after soft-deletion. Unique index is partial: `UNIQUE (item_code) WHERE is_deleted = false` | 2026-09-16 |
| **Q-07** | Document numbering format | **Confirmed.** Use prefixed format: `PUR-2026-0046`, `INV-2026-0046`. Add prefix for identification | 2026-09-16 |
| **Q-08** | Number sequence reset | **Confirmed.** Reset is **not needed**; continue running sequence continuously across financial years | 2026-09-16 |
| **Q-09** | Roles and permissions | **No fixed or default role list.** Configurable roles, granular permissions, full CRUD — **ADR-004** | 2026-08-29 |
| **Q-13** | Credit limit enforcement | **Confirmed.** When credit limit is exceeded, system will **issue a warning** (not hard-block) | 2026-09-16 |
| **Q-15** | Unit / unit conversion | **Dedicated Unit Master.** Products reference the applicable unit. **No unit-conversion functionality** unless explicitly required later | 2026-08-29 |
| **Q-19** | Inter-location stock transfer | **NOT required**, not part of the approved Stock Management scope. **Eight transaction types only — no `TRANSFER`.** Do not implement unless explicitly required later | 2026-08-29 |
| **Q-22** | Number of legal entities | **ONE legal entity only.** The ERP is built for this single legally registered business. No `company_id` on documents, masters or unique constraints | 2026-08-29 |
| **Q-23** | HSN/SAC codes | **Confirmed.** Add nullable `hsn_sac_code` to `raw_materials` and `finished_products` in Phase 1 schema now | 2026-09-16 |

### Closed by the scope change (ADR-014)

| Former question | Outcome |
| --- | --- |
| Tenant isolation design, cross-tenant testing, RLS policy scope | **Removed from scope.** Not multi-tenant; separation is by dedicated deployment |
| Whether masters are company-wide or per branch | Organization-wide — reinforced by Q-22 (one legal entity) |

---

# PART C — Status Summary

| Status | Count | IDs |
| --- | --- | --- |
| **Answered** | 14 | Q-01, Q-02, Q-03, Q-05, Q-05a, Q-06, Q-07, Q-08, Q-09, Q-13, Q-15, Q-19, Q-22, Q-23 |
| **Open — HIGH** | 3 | Q-11, Q-16, Q-18 |
| **Open — MEDIUM** | 9 | **Q-24 (pending confirmation)**, **Q-25**, Q-04, Q-10, Q-12, Q-14, Q-17, Q-20, Q-21 |

**The database schema and constraint specifications are fully settled.**
- `hsn_sac_code` is added as nullable text to both item masters.
- Unique constraints on item codes allow reuse after deletion (`WHERE is_deleted = false`).
- Document numbering follows continuous prefixed sequence (`PUR-2026-0046`).
- Credit limit violations issue a warning.
- **Q-24 (Consignee vs Buyer state for place of supply determination)** remains pending.
