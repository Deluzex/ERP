-- ============================================================================
-- 013_purchase_transportation.sql
-- Deluzex ERP: Transportation Charges & Landed Cost on Purchases
-- Implements: Backward-compatible columns for PO-level transportation charges,
--             per-item allocated transportation cost, and unit landed rate.
--             ADR-011: NUMERIC(18,2) for currency amounts.
-- ============================================================================

-- 1. Add transportation_charges to purchases table
ALTER TABLE purchases
  ADD COLUMN IF NOT EXISTS transportation_charges NUMERIC(18,2) NOT NULL DEFAULT 0.00;

-- 2. Add transportation_cost and landed_rate to purchase_items table
ALTER TABLE purchase_items
  ADD COLUMN IF NOT EXISTS transportation_cost NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS landed_rate NUMERIC(18,2) NOT NULL DEFAULT 0.00;

-- 3. Backfill landed_rate for existing historical purchase_items
-- For historical items with zero transportation, landed_rate = (taxable_amount / quantity) or rate
UPDATE purchase_items
SET landed_rate = CASE
  WHEN quantity > 0 THEN ROUND(((quantity * rate) - discount_amount) / quantity, 2)
  ELSE rate
END
WHERE landed_rate = 0.00;
