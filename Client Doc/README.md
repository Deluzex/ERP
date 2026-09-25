# Client Doc

Authoritative documents supplied **by the client**, plus the business decisions they settle.

Everything here is **evidence**, not interpretation. When a rule in `docs/` cites a client document, the
document itself lives in this folder so any developer can open it and check the claim.

---

## Contents

| File | What it is | Settles |
| --- | --- | --- |
| [`FINAL_BUSINESS_DECISIONS.md`](FINAL_BUSINESS_DECISIONS.md) | Four client-confirmed decisions, with the design consequences of each | **Q-22, Q-05a, Q-19, Q-15** |
| [`046 Hotel Winsome, Ahmedabad.pdf`](046%20Hotel%20Winsome,%20Ahmedabad.pdf) | Real Tax Invoice 046 (17-March-26), Blazon Creative → Hotel Winsome | **Q-05a** — the authoritative reference for round-off behaviour |

---

## Why the sample invoice matters

It is the only document in the project that shows the client's **actual** billing arithmetic end to end, and
it verified three things that documentation alone could not:

1. **Round-off is not paise-rounding.** The invoice shows a round-off of **−₹93.50** taking
   ₹1,00,093.50 → ₹1,00,000.00. An automatic nearest-rupee rule would have produced −₹0.50. The field must
   therefore be an **enterable signed amount**, not a computed `ROUND()`.
2. **Intra-state GST is real.** Both parties carry GST state code `24` (Gujarat), and the invoice shows
   **CGST + SGST with no IGST line** — confirming ADR-015 §2 against a live document rather than a
   description.
3. **HSN/SAC codes are present** per line and in a tax summary — a field the business source document never
   mentioned. Raised as **Q-23**.

The full arithmetic reconciliation is in `FINAL_BUSINESS_DECISIONS.md`.

---

## Rules for this folder

- **Do not edit client documents.** They are evidence. If the client sends a revision, add it alongside with
  a clear filename and date; do not overwrite.
- **Do not paraphrase a client document into a rule and then delete the document.** The rule and its source
  must both be checkable.
- When adding a document, record in `FINAL_BUSINESS_DECISIONS.md` (or a new decision file here) **what it
  settles** and **which project documents were updated** as a result.
- Client documents may contain commercial and personal data (GSTINs, addresses, prices). Treat this folder as
  confidential; do not copy its contents into public issues, screenshots or third-party services.
