-- ============================================================================
-- 003_masters.sql
-- Deluzex ERP Phase 1 Master Data Registry Schema
-- Implements: ADR-011 (Decimals), Q-06 (Item code reuse), Q-23 (Nullable HSN)
--             Pragmatic Schema Design (Anti-Overkill & Anti-Bloat)
-- ============================================================================

-- 1. Item Categories
CREATE TABLE IF NOT EXISTS categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  description TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Measurement Units
CREATE TABLE IF NOT EXISTS measurement_units (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  symbol TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed standard measurement units
INSERT INTO measurement_units (name, symbol)
VALUES
  ('Pieces', 'PCS'),
  ('Meters', 'MTR'),
  ('Kilograms', 'KG'),
  ('Boxes', 'BOX'),
  ('Sets', 'SET'),
  ('Rolls', 'ROL'),
  ('Litres', 'LITRE')
ON CONFLICT (symbol) DO NOTHING;

-- 3. Vendors Master
CREATE TABLE IF NOT EXISTS vendors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  contact_person TEXT NOT NULL,
  mobile TEXT NOT NULL,
  email TEXT NOT NULL,
  gst_number TEXT NOT NULL,
  pan_number TEXT NOT NULL,
  address TEXT NOT NULL,
  payment_terms TEXT NOT NULL DEFAULT 'Net 30 Days',
  credit_limit NUMERIC(18,2) NOT NULL DEFAULT 500000.00,
  outstanding_balance NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  delete_reason TEXT NULL,
  deleted_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Partial unique index allowing GST reuse after soft-delete
CREATE UNIQUE INDEX IF NOT EXISTS uq_vendors__gst
  ON vendors (gst_number) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_vendors__search
  ON vendors (name, contact_person, mobile);

-- 4. Raw Materials Catalog
CREATE TABLE IF NOT EXISTS raw_materials (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  item_code TEXT NOT NULL,
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  unit_id UUID NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT,
  hsn_sac_code TEXT NULL,
  opening_stock NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  minimum_stock NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  reorder_level NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  default_purchase_price NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  gst_percent NUMERIC(5,2) NOT NULL DEFAULT 18.00,
  preferred_vendor_ids UUID[] NULL,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  deleted_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Q-06: Partial unique index allowing item code reuse after soft-delete
CREATE UNIQUE INDEX IF NOT EXISTS uq_raw_materials__item_code
  ON raw_materials (item_code) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_raw_materials__search
  ON raw_materials (name, item_code, category_id);

-- 5. Finished Products Catalog
CREATE TABLE IF NOT EXISTS finished_products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  item_code TEXT NOT NULL,
  category_id UUID NOT NULL REFERENCES categories(id) ON DELETE RESTRICT,
  unit_id UUID NOT NULL REFERENCES measurement_units(id) ON DELETE RESTRICT,
  hsn_sac_code TEXT NULL,
  opening_stock NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  minimum_stock NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  cost_price NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  dealer_selling_price NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  customer_selling_price NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  gst_percent NUMERIC(5,2) NOT NULL DEFAULT 18.00,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  deleted_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Q-06: Partial unique index on finished product item codes
CREATE UNIQUE INDEX IF NOT EXISTS uq_finished_products__item_code
  ON finished_products (item_code) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_finished_products__search
  ON finished_products (name, item_code, category_id);

-- 6. Customers Master
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  mobile TEXT NOT NULL,
  email TEXT NOT NULL,
  gst_number TEXT NULL,
  address TEXT NOT NULL,
  state_code TEXT NOT NULL DEFAULT '24', -- 24 = Gujarat
  outstanding_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  credit_balance NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  linked_architect_id UUID NULL,
  is_also_architect BOOLEAN NOT NULL DEFAULT false,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_customers__search
  ON customers (name, mobile, email);

-- 7. Dealers Master
CREATE TABLE IF NOT EXISTS dealers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  contact_person TEXT NOT NULL,
  company_name TEXT NOT NULL,
  mobile TEXT NOT NULL,
  email TEXT NOT NULL,
  gst_number TEXT NOT NULL,
  address TEXT NOT NULL,
  state_code TEXT NOT NULL DEFAULT '24',
  outstanding_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dealers__search
  ON dealers (name, company_name, mobile);

-- 8. Architects Master
CREATE TABLE IF NOT EXISTS architects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  company_name TEXT NOT NULL,
  mobile TEXT NOT NULL,
  email TEXT NOT NULL,
  gst_number TEXT NULL,
  address TEXT NOT NULL,
  default_commission_rate NUMERIC(5,2) NOT NULL DEFAULT 5.00,
  total_commission_earned NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  pending_commission NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  approved_commission NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  paid_commission NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  linked_customer_id UUID NULL REFERENCES customers(id) ON DELETE SET NULL,
  is_also_customer BOOLEAN NOT NULL DEFAULT false,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_architects__search
  ON architects (name, company_name, mobile);

-- Foreign key linking customer back to architect
DO $$ BEGIN
  ALTER TABLE customers
    ADD CONSTRAINT fk_customers__linked_architect
    FOREIGN KEY (linked_architect_id) REFERENCES architects(id) ON DELETE SET NULL;
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;
