-- ============================================================================
-- 007_production.sql
-- Deluzex ERP Phase 4: Manufacturing & Production Management Module Schema
-- Implements: Section 8 of BACKEND_API_REQUIREMENTS.md
--             ADR-011 (NUMERIC(18,4) stock precision, NUMERIC(18,2) currency)
--             Bill of Materials (BOM), Production Orders & Consumption Ledger
-- ============================================================================

-- 1. Bill of Materials (BOM Recipes)
CREATE TABLE IF NOT EXISTS bill_of_materials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  finished_product_id UUID NOT NULL REFERENCES finished_products(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT NULL,
  output_quantity NUMERIC(18,4) NOT NULL DEFAULT 1.0000,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bom__product
  ON bill_of_materials (finished_product_id);

-- 2. BOM Recipe Child Items
CREATE TABLE IF NOT EXISTS bom_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bom_id UUID NOT NULL REFERENCES bill_of_materials(id) ON DELETE CASCADE,
  raw_material_id UUID NOT NULL REFERENCES raw_materials(id) ON DELETE RESTRICT,
  raw_material_name TEXT NOT NULL,
  raw_material_code TEXT NOT NULL,
  quantity_per_unit NUMERIC(18,4) NOT NULL,
  unit TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_bom_items__bom
  ON bom_items (bom_id);

CREATE INDEX IF NOT EXISTS idx_bom_items__raw_material
  ON bom_items (raw_material_id);

-- 3. Production Orders (Manufacturing Work Orders & Batches)
CREATE TABLE IF NOT EXISTS production_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  production_number TEXT UNIQUE NOT NULL,
  finished_product_id UUID NOT NULL REFERENCES finished_products(id),
  finished_product_name TEXT NOT NULL,
  finished_product_code TEXT NOT NULL,
  unit TEXT NOT NULL,
  planned_quantity NUMERIC(18,4) NOT NULL,
  actual_quantity_produced NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  raw_material_cost NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  labour_cost NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  other_expenses NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  total_production_cost NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  cost_per_unit NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  production_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'completed' CHECK (status IN (
    'planned', 'inProgress', 'completed', 'cancelled'
  )),
  sales_order_id UUID NULL,
  sales_order_number TEXT NULL,
  project_id UUID NULL,
  project_name TEXT NULL,
  notes TEXT NULL,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  deleted_reason TEXT NULL,
  deleted_at TIMESTAMPTZ NULL,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_production_orders__product
  ON production_orders (finished_product_id);

CREATE INDEX IF NOT EXISTS idx_production_orders__status
  ON production_orders (status);

CREATE INDEX IF NOT EXISTS idx_production_orders__date
  ON production_orders (production_date DESC);

CREATE INDEX IF NOT EXISTS idx_production_orders__number
  ON production_orders (production_number);

-- 4. Production Raw Material Usage (Consumed Materials per Batch)
CREATE TABLE IF NOT EXISTS production_raw_materials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  production_order_id UUID NOT NULL REFERENCES production_orders(id) ON DELETE CASCADE,
  raw_material_id UUID NOT NULL REFERENCES raw_materials(id),
  raw_material_name TEXT NOT NULL,
  raw_material_code TEXT NOT NULL,
  quantity_used NUMERIC(18,4) NOT NULL,
  unit TEXT NOT NULL,
  unit_cost NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  total_cost NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_production_rm__order
  ON production_raw_materials (production_order_id);

CREATE INDEX IF NOT EXISTS idx_production_rm__material
  ON production_raw_materials (raw_material_id);
