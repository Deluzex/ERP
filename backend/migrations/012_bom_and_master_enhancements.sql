-- ============================================================================
-- 012_bom_and_master_enhancements.sql
-- Deluzex ERP: Bill of Materials (BOM) Master Module, Expense & Payment Modes,
--              Geographic Localization (State & Pincode) & Automated Tax Resolution
-- Implements: BACKEND_API_REQUIREMENTS_UPDATE.md
--             ADR-011 (Decimal numerical precision NUMERIC(18,4) & NUMERIC(18,2))
--             ADR-014 (Single-Client Dedicated Instance, No tenant_id)
--             Company Origin: Gujarat (State Code: 24)
-- ============================================================================

-- 1. Create BOM Status Enum safely
DO $$ BEGIN
  CREATE TYPE bom_status_enum AS ENUM ('DRAFT', 'ACTIVE', 'OBSOLETE');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- 2. Create boms Table
CREATE TABLE IF NOT EXISTS boms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bom_number VARCHAR(50) NOT NULL UNIQUE,
    finished_product_id UUID NOT NULL REFERENCES finished_products(id) ON DELETE CASCADE,
    version INT NOT NULL DEFAULT 1,
    status bom_status_enum NOT NULL DEFAULT 'DRAFT',
    yield_quantity NUMERIC(18, 4) NOT NULL DEFAULT 1.0000,
    total_cost NUMERIC(18, 2) NOT NULL DEFAULT 0.00,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_product_version UNIQUE(finished_product_id, version)
);

-- Seed existing legacy bill_of_materials into boms table if any exist
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bill_of_materials') THEN
    INSERT INTO boms (id, bom_number, finished_product_id, version, status, yield_quantity, total_cost, notes, created_at, updated_at)
    SELECT 
      bm.id,
      'BOM-LEGACY-' || substr(bm.id::text, 1, 8),
      bm.finished_product_id,
      1,
      CASE WHEN bm.is_active THEN 'ACTIVE'::bom_status_enum ELSE 'OBSOLETE'::bom_status_enum END,
      bm.output_quantity,
      0.00,
      bm.description,
      bm.created_at,
      bm.updated_at
    FROM bill_of_materials bm
    ON CONFLICT (id) DO NOTHING;
  END IF;
END $$;

-- 3. Upgrade / Align bom_items Table
CREATE TABLE IF NOT EXISTS bom_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bom_id UUID NOT NULL REFERENCES boms(id) ON DELETE CASCADE,
    raw_material_id UUID NOT NULL REFERENCES raw_materials(id) ON DELETE RESTRICT,
    quantity NUMERIC(18, 4) NOT NULL DEFAULT 1.0000,
    unit VARCHAR(20) NOT NULL DEFAULT 'PCS',
    unit_cost NUMERIC(18, 2) NOT NULL DEFAULT 0.00,
    scrap_percentage NUMERIC(5, 2) NOT NULL DEFAULT 0.00,
    item_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure all new columns exist on bom_items if it pre-existed from 007_production.sql
DO $$ BEGIN
  -- If bom_items pre-existed, ensure it links to boms(id)
  ALTER TABLE bom_items ADD COLUMN IF NOT EXISTS quantity NUMERIC(18, 4);
  ALTER TABLE bom_items ADD COLUMN IF NOT EXISTS unit_cost NUMERIC(18, 2) NOT NULL DEFAULT 0.00;
  ALTER TABLE bom_items ADD COLUMN IF NOT EXISTS scrap_percentage NUMERIC(5, 2) NOT NULL DEFAULT 0.00;
  ALTER TABLE bom_items ADD COLUMN IF NOT EXISTS item_notes TEXT;
  ALTER TABLE bom_items ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

  -- Copy legacy quantity_per_unit to quantity if quantity was null
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bom_items' AND column_name = 'quantity_per_unit') THEN
    UPDATE bom_items SET quantity = quantity_per_unit WHERE quantity IS NULL;
  END IF;

  -- Make legacy columns nullable if table pre-existed
  ALTER TABLE bom_items ALTER COLUMN raw_material_name DROP NOT NULL;
  ALTER TABLE bom_items ALTER COLUMN raw_material_code DROP NOT NULL;
  ALTER TABLE bom_items ALTER COLUMN quantity_per_unit DROP NOT NULL;

  -- Re-point foreign key to boms(id) if needed
  ALTER TABLE bom_items DROP CONSTRAINT IF EXISTS bom_items_bom_id_fkey;
  ALTER TABLE bom_items ADD CONSTRAINT bom_items_bom_id_fkey FOREIGN KEY (bom_id) REFERENCES boms(id) ON DELETE CASCADE;
EXCEPTION
  WHEN others THEN null;
END $$;

-- Indexes for high-speed BOM queries
CREATE INDEX IF NOT EXISTS idx_boms_product_status ON boms(finished_product_id, status);
CREATE INDEX IF NOT EXISTS idx_bom_items_bom_id ON bom_items(bom_id);
CREATE INDEX IF NOT EXISTS idx_bom_items_raw_material ON bom_items(raw_material_id);

-- 4. Create expense_categories Table
CREATE TABLE IF NOT EXISTS expense_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_expense_categories_code ON expense_categories(code);
CREATE INDEX IF NOT EXISTS idx_expense_categories_active ON expense_categories(is_active);

-- Seed default expense categories
INSERT INTO expense_categories (name, code, description, is_active)
VALUES
  ('Transportation & Logistics', 'EXP-TRANS', 'Site delivery trucks, dedicated cranes, and shipping freight', true),
  ('Factory Tooling & Maintenance', 'EXP-MAINT', 'CNC tooling, powder coat nozzle replacements, machine servicing', true),
  ('Architectural Site Travel', 'EXP-TRAVEL', 'Outstation travel and lodging for lighting consultants', true),
  ('Utilities & Factory Power', 'EXP-UTIL', 'Factory 3-phase electricity, generator diesel, and utilities', true)
ON CONFLICT (code) DO NOTHING;

-- 5. Create payment_modes Table
CREATE TABLE IF NOT EXISTS payment_modes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    code VARCHAR(50) NOT NULL UNIQUE,
    requires_reference BOOLEAN NOT NULL DEFAULT TRUE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_payment_modes_code ON payment_modes(code);
CREATE INDEX IF NOT EXISTS idx_payment_modes_active ON payment_modes(is_active);

-- Seed default payment modes
INSERT INTO payment_modes (name, code, requires_reference, description, is_active)
VALUES
  ('Bank Transfer (NEFT / RTGS)', 'BANK_TRANSFER', true, 'Direct bank settlement via UTR / Transaction reference', true),
  ('UPI / QR Code', 'UPI', true, 'Unified Payments Interface instant transfer', true),
  ('Company Cheque', 'CHEQUE', true, 'Subject to bank clearance', true),
  ('Cash', 'CASH', false, 'Direct counter petty cash receipt', true)
ON CONFLICT (code) DO NOTHING;

-- 6. Geographic Localization (state & pincode across party masters)
-- Customers
ALTER TABLE customers 
  ADD COLUMN IF NOT EXISTS state VARCHAR(100) DEFAULT 'Gujarat',
  ADD COLUMN IF NOT EXISTS pincode VARCHAR(10);

-- Vendors
ALTER TABLE vendors 
  ADD COLUMN IF NOT EXISTS state VARCHAR(100) DEFAULT 'Gujarat',
  ADD COLUMN IF NOT EXISTS pincode VARCHAR(10);

-- Dealers
ALTER TABLE dealers 
  ADD COLUMN IF NOT EXISTS state VARCHAR(100) DEFAULT 'Gujarat',
  ADD COLUMN IF NOT EXISTS pincode VARCHAR(10);

-- Architects
ALTER TABLE architects 
  ADD COLUMN IF NOT EXISTS state VARCHAR(100) DEFAULT 'Gujarat',
  ADD COLUMN IF NOT EXISTS pincode VARCHAR(10);

-- 7. Add expense_category_id to expenses table
ALTER TABLE expenses
  ADD COLUMN IF NOT EXISTS expense_category_id UUID REFERENCES expense_categories(id) ON DELETE SET NULL;
