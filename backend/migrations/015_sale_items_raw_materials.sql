-- 015_sale_items_raw_materials.sql
-- Deluzex ERP: Allow both Finished Products and Raw Materials in Quotations and Sales Documents

ALTER TABLE sale_items
  ALTER COLUMN finished_product_id DROP NOT NULL;

ALTER TABLE sale_items
  ADD COLUMN IF NOT EXISTS item_type TEXT NOT NULL DEFAULT 'finished_product',
  ADD COLUMN IF NOT EXISTS raw_material_id UUID NULL REFERENCES raw_materials(id);

CREATE INDEX IF NOT EXISTS idx_sale_items__raw_material
  ON sale_items (raw_material_id);
