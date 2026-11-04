-- ============================================================================
-- 022_prevent_duplicate_challan_invoices.sql
-- Enforce 1:1 relationship between Dispatch Challan and Sales Invoice
-- Support 'invoiced' status on sales documents and delivery_status
-- ============================================================================

-- 1. Add delivery_reference_id to sales table if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'sales' AND column_name = 'delivery_reference_id'
  ) THEN
    ALTER TABLE sales ADD COLUMN delivery_reference_id UUID REFERENCES sales(id) ON DELETE SET NULL;
  END IF;
END $$;

-- 2. Update status CHECK constraint to allow 'invoiced'
ALTER TABLE sales DROP CONSTRAINT IF EXISTS sales_status_check;
ALTER TABLE sales ADD CONSTRAINT sales_status_check
  CHECK (status IN ('draft', 'active', 'partialPaid', 'paid', 'overdue', 'completed', 'cancelled', 'invoiced'));

-- 3. Update delivery_status CHECK constraint to allow 'invoiced'
ALTER TABLE sales DROP CONSTRAINT IF EXISTS sales_delivery_status_check;
ALTER TABLE sales ADD CONSTRAINT sales_delivery_status_check
  CHECK (delivery_status IN ('draft', 'dispatched', 'delivered', 'cancelled', 'invoiced'));

-- 4. Backfill delivery_reference_id on existing invoices that were created from deliveries
WITH matched_invoices AS (
  SELECT 
    i.id AS invoice_id,
    d.id AS delivery_id,
    ROW_NUMBER() OVER (PARTITION BY d.id ORDER BY i.created_at ASC) as rn
  FROM sales i
  JOIN sales d ON d.document_type = 'delivery'
  WHERE i.document_type = 'invoice'
    AND (
      i.notes LIKE '%' || d.invoice_number || '%'
      OR i.delivery_number = d.invoice_number
    )
)
UPDATE sales s
SET delivery_reference_id = mi.delivery_id
FROM matched_invoices mi
WHERE s.id = mi.invoice_id AND mi.rn = 1 AND s.delivery_reference_id IS NULL;

-- 5. Mark deliveries that have at least one invoice as 'invoiced'
UPDATE sales d
SET status = 'invoiced',
    delivery_status = 'invoiced',
    updated_at = now()
WHERE d.document_type = 'delivery'
  AND (
    EXISTS (
      SELECT 1 FROM sales i
      WHERE i.document_type = 'invoice'
        AND (i.delivery_reference_id = d.id OR i.notes LIKE '%' || d.invoice_number || '%')
    )
  );

-- 6. Add partial unique index to guarantee one invoice per dispatch challan at the database engine level
CREATE UNIQUE INDEX IF NOT EXISTS uq_sales__invoice_delivery_reference
  ON sales (delivery_reference_id)
  WHERE document_type = 'invoice' AND delivery_reference_id IS NOT NULL;

-- 7. Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_sales__delivery_reference_id
  ON sales (delivery_reference_id);

