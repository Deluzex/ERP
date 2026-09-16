-- ============================================================================
-- 006_purchases.sql
-- Deluzex ERP Phase 3: Purchase & Procurement Management Module Schema
-- Implements: Section 7 of BACKEND_API_REQUIREMENTS.md
--             ADR-011 (NUMERIC(18,4) stock quantity, NUMERIC(18,2) currency)
-- ============================================================================

-- 1. Purchases Table (Purchase Orders & Inward Bills)
CREATE TABLE IF NOT EXISTS purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_number TEXT UNIQUE NOT NULL,
  vendor_id UUID NOT NULL REFERENCES vendors(id),
  vendor_name TEXT NOT NULL,
  vendor_invoice_number TEXT NULL,
  purchase_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  invoice_date TIMESTAMPTZ NULL,
  purchase_type TEXT NOT NULL CHECK (purchase_type IN ('rawMaterial', 'finishedProduct')),
  project_id UUID NULL,
  project_name TEXT NULL,
  subtotal_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  discount_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  taxable_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  cgst_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  sgst_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  igst_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  gst_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  total_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  paid_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  pending_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  payment_mode TEXT NOT NULL DEFAULT 'credit' CHECK (payment_mode IN (
    'cash', 'bankTransfer', 'cheque', 'upi', 'credit', 'creditNote'
  )),
  status TEXT NOT NULL DEFAULT 'saved' CHECK (status IN (
    'draft', 'saved', 'partialPaid', 'paid', 'cancelled'
  )),
  notes TEXT NULL,
  attachment_url TEXT NULL,
  cancel_reason TEXT NULL,
  cancelled_at TIMESTAMPTZ NULL,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_purchases__vendor_date
  ON purchases (vendor_id, purchase_date DESC);

CREATE INDEX IF NOT EXISTS idx_purchases__status
  ON purchases (status);

CREATE INDEX IF NOT EXISTS idx_purchases__type
  ON purchases (purchase_type);

CREATE INDEX IF NOT EXISTS idx_purchases__number
  ON purchases (purchase_number);

-- 2. Purchase Line Items
CREATE TABLE IF NOT EXISTS purchase_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_id UUID NOT NULL REFERENCES purchases(id) ON DELETE CASCADE,
  item_type TEXT NOT NULL CHECK (item_type IN ('rawMaterial', 'finishedProduct')),
  raw_material_id UUID REFERENCES raw_materials(id) ON DELETE SET NULL NULL,
  raw_material_name TEXT NULL,
  raw_material_code TEXT NULL,
  finished_product_id UUID REFERENCES finished_products(id) ON DELETE SET NULL NULL,
  finished_product_name TEXT NULL,
  finished_product_code TEXT NULL,
  quantity NUMERIC(18,4) NOT NULL,
  unit TEXT NOT NULL,
  rate NUMERIC(18,2) NOT NULL,
  discount_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  gst_percent NUMERIC(5,2) NOT NULL DEFAULT 18.00,
  taxable_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  cgst_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  sgst_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  igst_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  line_total NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_purchase_items__purchase
  ON purchase_items (purchase_id);

CREATE INDEX IF NOT EXISTS idx_purchase_items__raw_material
  ON purchase_items (raw_material_id);

CREATE INDEX IF NOT EXISTS idx_purchase_items__finished_product
  ON purchase_items (finished_product_id);

-- 3. Payments Table (Disbursements & Receipts)
CREATE TABLE IF NOT EXISTS payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_number TEXT UNIQUE NOT NULL,
  payment_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  payment_type TEXT NOT NULL CHECK (payment_type IN ('vendorPayment', 'customerReceipt', 'expense')),
  vendor_id UUID REFERENCES vendors(id) ON DELETE SET NULL NULL,
  purchase_id UUID REFERENCES purchases(id) ON DELETE SET NULL NULL,
  amount NUMERIC(18,2) NOT NULL,
  payment_mode TEXT NOT NULL CHECK (payment_mode IN ('cash', 'bankTransfer', 'cheque', 'upi', 'credit', 'creditNote')),
  reference_number TEXT NULL,
  notes TEXT NULL,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_payments__vendor
  ON payments (vendor_id);

CREATE INDEX IF NOT EXISTS idx_payments__purchase
  ON payments (purchase_id);
