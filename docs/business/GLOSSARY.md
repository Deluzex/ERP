# Business Glossary — Canonical Terminology

**Status:** Active · **Rule:** These terms are fixed by the business source document. Use them **exactly** —
in code, tables, API fields, UI labels, tests and conversation. Do not substitute a synonym you find clearer.

## Why terminology discipline matters

If the database says `suppliers`, the API says `vendors` and the UI says "Parties", then every conversation
between a fresher, a reviewer and the client needs a translation step — and translation steps are where
requirements get lost. One word per concept, everywhere.

---

## Tenancy and Structure

| Term | Meaning | Code identifier |
| --- | --- | --- |
| **Company** | **The client organization** this ERP is built for — **one legal entity** (Q-22). An organizational entity, **not a SaaS tenant** (ADR-014) | `company`, `company_id` |
| **Branch** | A location of a Company (e.g. Ahmedabad Branch). **OPTIONAL per company** | `branch`, `branch_id` |
| **Warehouse** | A physical store within a Branch. **OPTIONAL per company** | `warehouse`, `warehouse_id` |
| **Stock Location** | Where stock actually sits. Anchored at COMPANY, BRANCH or WAREHOUSE level per that company. **Always present — every company has at least one** (ADR-013) | `stock_location`, `stock_location_id` |
| **Stock Scope Level** | A company setting: `COMPANY`, `BRANCH` or `WAREHOUSE` | `stock_scope_level` |
| **User** | A person with login access, belonging to one or more Companies | `user`, `user_id` |
| **Role** | A named set of Permissions, **created by the customer**, scoped to one Company. There is no default role list (ADR-004) | `role` |
| **Permission** | An atomic, granular right, `<module>.<action>` — system-defined catalogue | `permission` |

> Branch and Warehouse do **not** appear in the business source document — they come from the SaaS charter.
> **Both are OPTIONAL per company** (ADR-013, Q-03 answered 2026-08-29). Stock is anchored to a
> **Stock Location** instead — see below.

---

## Business Parties

| Term | Meaning | Never call it |
| --- | --- | --- |
| **Vendor** | Party we **buy** raw materials from | Supplier, Seller |
| **Customer** | Party we **sell** finished products to directly | Client, Buyer |
| **Dealer** | Reseller party; buys from us, earns commission | Distributor, Partner |
| **Architect** | Specifier who influences a sale and earns commission | Consultant, Designer |
| **Party** | Generic umbrella for Customer/Dealer/Architect on a sale | — |

Dealer and Architect are **commission-earning** parties. Customer is not. This distinction drives Phase 4.

---

## Items

| Term | Meaning | Code identifier |
| --- | --- | --- |
| **Raw Material** | Input purchased from a Vendor and consumed in Production | `raw_material` |
| **Finished Product** | Output of Production, sold to Customers/Dealers | `finished_product` |
| **Item** | Umbrella for Raw Material or Finished Product | `item`, with `item_type` |
| **Item Code** | Business identifier for an item, unique **per Company** | `item_code` |
| **Unit** | Measure held in a dedicated **Unit Master**. An item references exactly one. **No conversion** (Q-15). Seen: `kg`, `sq feet`, `piece`, `No` | `unit`, `unit_id` |
| **Minimum Stock** | Threshold below which an item is "low stock" | `minimum_stock` |
| **Reorder Level** | Level at which reordering should be triggered | `reorder_level` |
| **Opening Stock** | Initial quantity when the item is created | `opening_stock` |

**Minimum Stock and Reorder Level are different fields** in the source document (§5.5). Do not merge them.

---

## Stock

| Term | Meaning |
| --- | --- |
| **Stock Transaction** | An immutable ledger row recording one stock movement. **The source of truth** (ADR-005) |
| **Stock Movement** | The business event; recorded as a Stock Transaction |
| **Stock Balance** | Derived/cached current quantity for an item at a Stock Location. **Never authoritative** |
| **Stock In** | Quantity increasing stock |
| **Stock Out** | Quantity decreasing stock |
| **Stock Adjustment** | Manual correction, requiring a reason |

### Transaction Types (exactly the eight from source document §8)

| Type | Effect | Phase |
| --- | --- | --- |
| `PURCHASE` | Raw Material **+** | 1 |
| `PRODUCTION_CONSUMPTION` | Raw Material **−** | 2 |
| `PRODUCTION_OUTPUT` | Finished Product **+** | 2 |
| `SALE` | Finished Product **−** | 3 |
| `SALE_RETURN` | Finished Product **+** | 3 |
| `PURCHASE_RETURN` | Raw Material **−** | 1 (see Q-11) |
| `DAMAGE` | **−** | 1 (see Q-11) |
| `ADJUSTMENT` | **+ or −** | 1 (see Q-11) |

No other transaction type may be invented. Inter-location `TRANSFER` is **not** in this list **and is NOT
required** — stock transfer is out of scope (Q-19, client-confirmed 2026-08-29). Do not add a ninth type
unless a new business decision explicitly requires it.

---

## Documents

| Term | Meaning | Phase |
| --- | --- | --- |
| **Purchase** | Document recording a purchase from a Vendor; increases Raw Material stock | 1 |
| **Purchase Number** | Auto-generated business identifier, unique per Company | 1 |
| **Vendor Invoice Number** | The Vendor's own reference on their bill | 1 |
| **Production Order** | Document for a manufacturing run | 2 |
| **Sales Invoice** | Document recording a sale; decreases Finished Product stock | 3 |
| **Quotation** | Pre-sale offer (undefined in source — Q-10) | 3 |
| **Sales Order** | Confirmed order before invoicing (undefined in source — Q-10) | 3 |
| **Project** | Groups multiple sales for commission purposes | 3 |

### Document status vocabulary

| Status | Meaning |
| --- | --- |
| `DRAFT` | Saved, **not** posted to the ledger, editable |
| `CONFIRMED` | Posted; stock transactions exist; not editable (see Q-12) |
| `CANCELLED` | Reversed by compensating ledger entries; never deleted |

---

## Money

| Term | Meaning |
| --- | --- |
| **Gross Amount** | Line/document total **before** discount |
| **Taxable Amount** | `Gross − Discount` — **the GST base** (ADR-015) |
| **CGST / SGST** | Intra-state tax components (within Gujarat) |
| **IGST** | Inter-state tax component (outside Gujarat) |
| **Round Off** | A separate, **entered**, signed adjustment applied after GST. Never folded into item or tax amounts (ADR-015) |
| **Grand Total** | `Taxable + Tax + Round Off` — the payable amount |
| **HSN/SAC** | GST classification code per item (present on the client sample invoice — Q-23) |
| **Paid Amount** | Amount settled so far |
| **Pending Amount** | `Total Amount − Paid Amount` |
| **Outstanding** | Total pending across a party's documents |
| **Credit Limit** | Maximum outstanding allowed for a Vendor (enforcement: Q-13) |
| **Payment Terms** | Agreed settlement period, e.g. "Net 30 Days" |
| **Cost Price / Dealer Selling Price / Customer Selling Price** | The three prices on a Finished Product (§5.6) — a Dealer and a Customer pay different prices |

All monetary values are **decimal**, never floating point (ADR-011).

---

## Commission (Phase 4 — terminology only)

| Term | Meaning |
| --- | --- |
| **Project-Based Commission** | Commission on sales linked to a Project |
| **Yearly Purchase-Based Commission** | Slab commission on a Dealer's annual purchase total |
| **Commission Slab** | A purchase band with a commission rate (values are examples — Q-16) |
| **Commission Statement** | Generated summary submitted for approval |

---

## Engineering Terms (this project's meaning)

| Term | Meaning |
| --- | --- |
| **RequestContext** | The server-built, trusted object carrying `userId`, permissions, branch and stock-location scope, and permissions. The **only** valid source of permission and scope information |
| **Access control** | The guarantee that a Company can never access another Company's data |
| **Scoped repository** | A repository whose every query is filtered by `company_id` by construction |
| **Ledger** | `stock_transactions` — append-only, authoritative |
| **RED phase** | The mandatory observed test failure before implementation (`TESTING_RULES.md`) |
| **ADR** | Architecture Decision Record — `docs/decisions/` |
| **Existing implementation** | The Flutter app built on `MockDatabaseService`. **Retained** as project work, not frozen — but new code follows the approved architecture (ADR-010) |
