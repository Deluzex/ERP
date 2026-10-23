-- 014_item_transportation_charges.sql
-- Deluzex ERP: Transportation charge per raw material & finished product in Master Module

ALTER TABLE raw_materials
  ADD COLUMN IF NOT EXISTS transportation_charge NUMERIC(18,2) NOT NULL DEFAULT 0.00;

ALTER TABLE finished_products
  ADD COLUMN IF NOT EXISTS transportation_charge NUMERIC(18,2) NOT NULL DEFAULT 0.00;
