-- ============================================================================
-- 008_sales.sql
-- Deluzex ERP Phase 5: Sales & Commercial Lifecycle Module Schema
-- Implements: Section 9 of BACKEND_API_REQUIREMENTS.md
--             ADR-011 (NUMERIC(18,4) stock precision, NUMERIC(18,2) currency)
--             Quotations, Proforma, Sales Orders, Deliveries, Invoices, Returns
-- ============================================================================

-- 1. Sales Documents Table (Unified Commercial Document Ledger)
CREATE TABLE IF NOT EXISTS sales (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_number TEXT UNIQUE NOT NULL,
  document_type TEXT NOT NULL CHECK (document_type IN (
    'quotation', 'proformaInvoice', 'salesOrder', 'delivery', 'invoice', 'salesReturn'
  )),
  party_type TEXT NOT NULL CHECK (party_type IN ('customer', 'dealer', 'architect')),
  party_id UUID NOT NULL,
  party_name TEXT NOT NULL,
  customer_contact_person TEXT NULL,
  customer_mobile TEXT NULL,
  customer_email TEXT NULL,
  customer_gst_number TEXT NULL,
  billing_address TEXT NULL,
  shipping_address TEXT NULL,
  project_id UUID NULL,
  project_name TEXT NULL,
  architect_id UUID REFERENCES architects(id) ON DELETE SET NULL NULL,
  architect_name TEXT NULL,
  sales_executive TEXT NULL,
  sale_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  delivery_date TIMESTAMPTZ NULL,
  valid_until TIMESTAMPTZ NULL,
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
  payment_mode TEXT NOT NULL DEFAULT 'bankTransfer' CHECK (payment_mode IN (
    'cash', 'bankTransfer', 'cheque', 'upi', 'credit', 'creditNote'
  )),
  status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN (
    'draft', 'active', 'partialPaid', 'paid', 'overdue', 'completed', 'cancelled'
  )),
  architect_commission_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  is_inter_state_tax BOOLEAN NOT NULL DEFAULT false,
  notes TEXT NULL,
  terms_and_conditions TEXT NULL,
  bank_details TEXT NULL,
  revision_number INT NOT NULL DEFAULT 0,
  original_quotation_id UUID REFERENCES sales(id) ON DELETE SET NULL NULL,
  parent_quotation_id UUID REFERENCES sales(id) ON DELETE SET NULL NULL,
  parent_quotation_number TEXT NULL,
  quotation_status TEXT NULL CHECK (quotation_status IN (
    'draft', 'sent', 'accepted', 'approved', 'rejected', 'expired', 'superseded', 'converted', 'cancelled'
  )),
  proforma_status TEXT NULL CHECK (proforma_status IN (
    'draft', 'issued', 'partialPaid', 'paid', 'cancelled', 'converted'
  )),
  proforma_reference_id UUID REFERENCES sales(id) ON DELETE SET NULL NULL,
  proforma_number TEXT NULL,
  sales_order_number TEXT NULL,
  sales_order_reference_id UUID REFERENCES sales(id) ON DELETE SET NULL NULL,
  sales_order_status TEXT NULL CHECK (sales_order_status IN (
    'draft', 'pending', 'confirmed', 'stockAllocationPending', 'productionPending',
    'inProduction', 'readyForDispatch', 'partiallyDelivered', 'dispatched',
    'delivered', 'completed', 'done', 'onHold', 'cancelled'
  )),
  delivery_status TEXT NULL CHECK (delivery_status IN (
    'draft', 'dispatched', 'delivered', 'cancelled'
  )),
  delivery_number TEXT NULL,
  vehicle_number TEXT NULL,
  driver_contact TEXT NULL,
  courier_name TEXT NULL,
  tracking_number TEXT NULL,
  expected_delivery_date TIMESTAMPTZ NULL,
  courier_contact TEXT NULL,
  dispatch_notes TEXT NULL,
  sales_return_status TEXT NULL CHECK (sales_return_status IN (
    'draft', 'submitted', 'itemsReceived', 'inspection', 'approved', 'completed', 'rejected', 'pending', 'requested'
  )),
  return_condition TEXT NULL CHECK (return_condition IN (
    'resalable', 'damaged', 'scrap', 'goodCondition', 'repairable'
  )),
  return_financial_action TEXT NULL CHECK (return_financial_action IN (
    'creditNote', 'refund', 'adjustOutstanding'
  )),
  return_type TEXT NULL CHECK (return_type IN (
    'fullReturn', 'partialReturn'
  )),
  refund_status TEXT NULL CHECK (refund_status IN (
    'notRequired', 'pending', 'approved', 'processed', 'cancelled'
  )),
  refund_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  refund_payment_mode TEXT NULL CHECK (refund_payment_mode IN (
    'cash', 'bankTransfer', 'cheque', 'upi', 'credit', 'creditNote'
  )),
  refund_transaction_ref TEXT NULL,
  refund_date TIMESTAMPTZ NULL,
  is_processed BOOLEAN NOT NULL DEFAULT false,
  original_invoice_id UUID REFERENCES sales(id) ON DELETE SET NULL NULL,
  original_invoice_number TEXT NULL,
  return_reason TEXT NULL,
  quotation_reference_id UUID REFERENCES sales(id) ON DELETE SET NULL NULL,
  attachment_url TEXT NULL,
  created_by UUID REFERENCES users(id) ON DELETE SET NULL NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sales__doc_type
  ON sales (document_type);

CREATE INDEX IF NOT EXISTS idx_sales__number
  ON sales (invoice_number);

CREATE INDEX IF NOT EXISTS idx_sales__party
  ON sales (party_id, party_type);

CREATE INDEX IF NOT EXISTS idx_sales__date
  ON sales (sale_date DESC);

CREATE INDEX IF NOT EXISTS idx_sales__status
  ON sales (status);

CREATE INDEX IF NOT EXISTS idx_sales__so_status
  ON sales (sales_order_status);

CREATE INDEX IF NOT EXISTS idx_sales__orig_inv
  ON sales (original_invoice_id);

CREATE INDEX IF NOT EXISTS idx_sales__so_ref
  ON sales (sales_order_reference_id);

-- 2. Sale Line Items Table
CREATE TABLE IF NOT EXISTS sale_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sale_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  finished_product_id UUID NOT NULL REFERENCES finished_products(id),
  finished_product_name TEXT NOT NULL,
  finished_product_code TEXT NOT NULL,
  product_description TEXT NULL,
  quantity NUMERIC(18,4) NOT NULL,
  reserved_quantity NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  produced_quantity NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  delivered_quantity NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  invoiced_quantity NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  returned_quantity NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
  unit TEXT NOT NULL,
  rate NUMERIC(18,2) NOT NULL,
  discount_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  gst_percent NUMERIC(5,2) NOT NULL DEFAULT 18.00,
  taxable_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  cgst_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  sgst_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  igst_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  line_total NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  product_condition TEXT NULL,
  return_condition TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sale_items__sale
  ON sale_items (sale_id);

CREATE INDEX IF NOT EXISTS idx_sale_items__product
  ON sale_items (finished_product_id);

-- 3. Architect Commissions Registry Table
CREATE TABLE IF NOT EXISTS architect_commissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  commission_number TEXT UNIQUE NOT NULL,
  architect_id UUID NOT NULL REFERENCES architects(id) ON DELETE RESTRICT,
  architect_name TEXT NOT NULL,
  sale_invoice_id UUID NOT NULL REFERENCES sales(id) ON DELETE CASCADE,
  sale_invoice_number TEXT NOT NULL,
  project_id UUID NULL,
  project_name TEXT NULL,
  sale_amount NUMERIC(18,2) NOT NULL,
  commission_rate NUMERIC(5,2) NOT NULL,
  commission_amount NUMERIC(18,2) NOT NULL,
  status TEXT NOT NULL DEFAULT 'generated' CHECK (status IN (
    'generated', 'approved', 'paid', 'reversed', 'rejected'
  )),
  generated_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  paid_date TIMESTAMPTZ NULL,
  payment_reference TEXT NULL,
  notes TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_arch_comm__architect
  ON architect_commissions (architect_id);

CREATE INDEX IF NOT EXISTS idx_arch_comm__invoice
  ON architect_commissions (sale_invoice_id);

CREATE INDEX IF NOT EXISTS idx_arch_comm__status
  ON architect_commissions (status);
