-- ============================================================================
-- 011_payments_and_expenses.sql
-- Deluzex ERP Phase 7: Payments, Commissions & Expenses Schema
-- Implements: Section 11 of BACKEND_API_REQUIREMENTS.md
--             ADR-011 (NUMERIC(18,2) currency)
-- ============================================================================

-- Sequences for sequential document numbering
CREATE SEQUENCE IF NOT EXISTS seq_payment_number START WITH 1;
CREATE SEQUENCE IF NOT EXISTS seq_commission_number START WITH 1;
CREATE SEQUENCE IF NOT EXISTS seq_expense_number START WITH 1;

-- 1. Upgrade / Align Payments Table
-- Handle previously created minimal table from 006_purchases.sql
ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS party_id UUID NULL,
  ADD COLUMN IF NOT EXISTS party_name TEXT NULL,
  ADD COLUMN IF NOT EXISTS reference_document_id UUID NULL,
  ADD COLUMN IF NOT EXISTS reference_document_number TEXT NULL,
  ADD COLUMN IF NOT EXISTS payment_status TEXT NOT NULL DEFAULT 'completed',
  ADD COLUMN IF NOT EXISTS attachment_url TEXT NULL,
  ADD COLUMN IF NOT EXISTS is_full_payment BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS total_document_amount NUMERIC(18,2) NULL,
  ADD COLUMN IF NOT EXISTS remaining_amount NUMERIC(18,2) NULL,
  ADD COLUMN IF NOT EXISTS project_id UUID REFERENCES projects(id) ON DELETE SET NULL NULL,
  ADD COLUMN IF NOT EXISTS project_name TEXT NULL,
  ADD COLUMN IF NOT EXISTS transaction_reference TEXT NULL,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Update party_id/party_name from vendor_id for legacy records if any
UPDATE payments
SET party_id = vendor_id,
    party_name = COALESCE((SELECT name FROM vendors WHERE vendors.id = payments.vendor_id), 'Vendor'),
    reference_document_id = purchase_id
WHERE party_id IS NULL AND vendor_id IS NOT NULL;

-- Relax / align payment_type check constraint to accommodate full enum
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_payment_type_check;
ALTER TABLE payments ADD CONSTRAINT payments_payment_type_check CHECK (
  payment_type IN ('customerPayment', 'dealerPayment', 'vendorPayment', 'commissionPayment', 'customerReceipt', 'expense')
);

-- Relax payment_mode check constraint to include 'card'
ALTER TABLE payments DROP CONSTRAINT IF EXISTS payments_payment_mode_check;
ALTER TABLE payments ADD CONSTRAINT payments_payment_mode_check CHECK (
  payment_mode IN ('cash', 'bankTransfer', 'cheque', 'upi', 'credit', 'creditNote', 'card')
);

CREATE INDEX IF NOT EXISTS idx_payments__party
  ON payments (party_id, payment_type);

CREATE INDEX IF NOT EXISTS idx_payments__type
  ON payments (payment_type);

CREATE INDEX IF NOT EXISTS idx_payments__ref_doc
  ON payments (reference_document_id);

CREATE INDEX IF NOT EXISTS idx_payments__date
  ON payments (payment_date DESC);

-- 2. Upgrade / Align Architect Commissions Table
ALTER TABLE architect_commissions
  ADD COLUMN IF NOT EXISTS approved_date TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS payment_id UUID REFERENCES payments(id) ON DELETE SET NULL NULL,
  ADD COLUMN IF NOT EXISTS rejection_reason TEXT NULL;

CREATE INDEX IF NOT EXISTS idx_arch_comm__status_date
  ON architect_commissions (status, generated_date DESC);

-- 3. Create Expenses Table
CREATE TABLE IF NOT EXISTS expenses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  expense_number TEXT UNIQUE NOT NULL,
  expense_date TIMESTAMPTZ NOT NULL DEFAULT now(),
  expense_name TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN (
    'transportation', 'courier', 'fuel', 'labour', 'electricity',
    'maintenance', 'officeExpense', 'productionExpense', 'projectExpense', 'other'
  )),
  amount NUMERIC(18,2) NOT NULL CHECK (amount > 0),
  paid_by TEXT NOT NULL,
  payment_method TEXT NOT NULL,
  vendor_payee TEXT NULL,
  project_id UUID REFERENCES projects(id) ON DELETE SET NULL NULL,
  project_name TEXT NULL,
  purchase_id UUID REFERENCES purchases(id) ON DELETE SET NULL NULL,
  purchase_number TEXT NULL,
  production_id UUID REFERENCES production_orders(id) ON DELETE SET NULL NULL,
  production_number TEXT NULL,
  expense_reference TEXT NULL,
  description TEXT NULL,
  receipt_attachment_name TEXT NULL,
  payment_status TEXT NOT NULL DEFAULT 'paid' CHECK (payment_status IN (
    'paid', 'partial', 'pending'
  )),
  created_by TEXT NOT NULL DEFAULT 'Admin',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_expenses__date
  ON expenses (expense_date DESC);

CREATE INDEX IF NOT EXISTS idx_expenses__category
  ON expenses (category);

CREATE INDEX IF NOT EXISTS idx_expenses__project
  ON expenses (project_id);

CREATE INDEX IF NOT EXISTS idx_expenses__number
  ON expenses (expense_number);
