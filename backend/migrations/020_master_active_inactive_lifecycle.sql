-- ============================================================================
-- 019_master_active_inactive_lifecycle.sql
-- Deluzex ERP Master Data Status Lifecycle Migration
-- Adds is_active column and creates partial indexes for dropdown queries
-- ============================================================================

-- 1. Customers Master
ALTER TABLE customers 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_customers__active_dropdown 
ON customers (name, id) 
WHERE is_deleted = false AND is_active = true;

-- 2. Dealers Master
ALTER TABLE dealers 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_dealers__active_dropdown 
ON dealers (name, id) 
WHERE is_deleted = false AND is_active = true;

-- 3. Vendors Master
ALTER TABLE vendors 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_vendors__active_dropdown 
ON vendors (name, id) 
WHERE is_deleted = false AND is_active = true;

-- 4. Architects Master
ALTER TABLE architects 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_architects__active_dropdown 
ON architects (name, id) 
WHERE is_deleted = false AND is_active = true;

-- 5. Finished Products Master
ALTER TABLE finished_products 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_finished_products__active_dropdown 
ON finished_products (name, item_code, id) 
WHERE is_deleted = false AND is_active = true;

-- 6. Raw Materials Master
ALTER TABLE raw_materials 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_raw_materials__active_dropdown 
ON raw_materials (name, item_code, id) 
WHERE is_deleted = false AND is_active = true;

-- 7. Categories Master
ALTER TABLE categories 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_categories__active_dropdown 
ON categories (name, id) 
WHERE is_active = true;

-- 8. Measurement Units Master
ALTER TABLE measurement_units 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_measurement_units__active_dropdown 
ON measurement_units (name, id) 
WHERE is_active = true;

