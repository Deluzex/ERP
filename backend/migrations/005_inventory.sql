-- ============================================================================
-- 005_inventory.sql
-- Deluzex ERP Phase 2: Inventory & Warehouse Management Module Schema
-- Implements: Section 6 of BACKEND_API_REQUIREMENTS.md
--             ADR-011 (NUMERIC(18,4) stock precision, NUMERIC(18,2) valuation)
--             Immutable stock ledger & transactional stock adjustments
-- ============================================================================

-- 1. Ensure Stock Columns on Raw Materials Catalog
ALTER TABLE raw_materials
  ADD COLUMN IF NOT EXISTS current_stock NUMERIC(18,4) NOT NULL DEFAULT 0.0000;

UPDATE raw_materials
  SET current_stock = opening_stock
  WHERE current_stock = 0.0000 AND opening_stock > 0;

-- 2. Ensure Stock Columns on Finished Products Catalog
ALTER TABLE finished_products
  ADD COLUMN IF NOT EXISTS current_stock NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  ADD COLUMN IF NOT EXISTS reserved_stock NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  ADD COLUMN IF NOT EXISTS produced_stock NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  ADD COLUMN IF NOT EXISTS purchased_stock NUMERIC(18,4) NOT NULL DEFAULT 0.0000;

UPDATE finished_products
  SET current_stock = opening_stock
  WHERE current_stock = 0.0000 AND opening_stock > 0;

-- 3. Immutable Stock Movement Ledger (Audit Log)
CREATE TABLE IF NOT EXISTS stock_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date TIMESTAMPTZ NOT NULL DEFAULT now(),
  item_id UUID NOT NULL,
  item_type TEXT NOT NULL CHECK (item_type IN ('rawMaterial', 'finishedProduct')),
  transaction_type TEXT NOT NULL CHECK (transaction_type IN (
    'purchase',
    'productionConsumption',
    'productionOutput',
    'sale',
    'saleReturn',
    'purchaseReturn',
    'damage',
    'adjustment'
  )),
  reference_number TEXT NOT NULL,
  stock_in NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  stock_out NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  current_balance NUMERIC(18,4) NOT NULL,
  unit TEXT NOT NULL,
  notes TEXT NULL,
  performed_by UUID REFERENCES users(id) ON DELETE SET NULL NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stock_movements__item_date
  ON stock_movements (item_id, date DESC);

CREATE INDEX IF NOT EXISTS idx_stock_movements__type
  ON stock_movements (transaction_type);

CREATE INDEX IF NOT EXISTS idx_stock_movements__reference
  ON stock_movements (reference_number);

-- 4. Stock Adjustments (Physical count mismatches, damages, reconciliations)
CREATE TABLE IF NOT EXISTS stock_adjustments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  adjustment_number TEXT UNIQUE NOT NULL,
  adjustment_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  item_id UUID NOT NULL,
  item_type TEXT NOT NULL CHECK (item_type IN ('rawMaterial', 'finishedProduct')),
  item_name TEXT NOT NULL,
  item_code TEXT NOT NULL,
  current_stock_before NUMERIC(18,4) NOT NULL,
  adjusted_stock_after NUMERIC(18,4) NOT NULL,
  adjustment_quantity NUMERIC(18,4) NOT NULL,
  unit TEXT NOT NULL,
  reason TEXT NOT NULL CHECK (reason IN (
    'physicalCountMismatch',
    'damagedGoods',
    'expiry',
    'theftOrLoss',
    'internalConsumption',
    'revaluation',
    'other'
  )),
  remarks TEXT NULL,
  performed_by UUID REFERENCES users(id) ON DELETE SET NULL NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_stock_adjustments__item
  ON stock_adjustments (item_id, created_at DESC);

-- 5. Low Stock Alert Logs (WhatsApp broadcast records)
CREATE TABLE IF NOT EXISTS low_stock_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id UUID NOT NULL,
  item_type TEXT NOT NULL CHECK (item_type IN ('rawMaterial', 'finishedProduct')),
  item_name TEXT NOT NULL,
  item_code TEXT NOT NULL,
  recipient_id TEXT NULL,
  recipient_name TEXT NULL,
  recipient_whatsapp TEXT NULL,
  custom_message TEXT NULL,
  current_stock NUMERIC(18,4) NOT NULL,
  minimum_stock NUMERIC(18,4) NOT NULL,
  reorder_level NUMERIC(18,4) NOT NULL,
  status TEXT NOT NULL DEFAULT 'triggered' CHECK (status IN ('triggered', 'resolved')),
  resolved_at TIMESTAMPTZ NULL,
  resolved_by UUID REFERENCES users(id) ON DELETE SET NULL NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_low_stock_alerts__item_status
  ON low_stock_alerts (item_id, status);
