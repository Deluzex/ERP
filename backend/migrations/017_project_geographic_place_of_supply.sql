-- ============================================================================
-- 017_project_geographic_place_of_supply.sql
-- Deluzex ERP: Architectural Project Geographic Place of Supply (POS) Schema
-- Statutory Compliance: Section 10 of IGST Act (Goods delivery to project site)
-- Safety: Unresolved locations are kept NULL (flagged for review; not defaulted)
-- ============================================================================

-- 1. Add Place of Supply location fields to projects table
ALTER TABLE projects
  ADD COLUMN IF NOT EXISTS site_state VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS site_state_code VARCHAR(10) NULL,
  ADD COLUMN IF NOT EXISTS site_address TEXT NULL,
  ADD COLUMN IF NOT EXISTS site_pincode VARCHAR(10) NULL,
  ADD COLUMN IF NOT EXISTS pos_verified BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Intelligent, Safe Backfill for Existing Projects
-- (Only backfill from verified linked master party data; DO NOT silently assume Gujarat)
DO $$
BEGIN
  -- Backfill from linked customer if customer has registered state
  UPDATE projects p
  SET site_state = c.state,
      site_state_code = COALESCE(c.state_code, CASE WHEN LOWER(c.state) = 'gujarat' THEN '24' WHEN LOWER(c.state) = 'maharashtra' THEN '27' ELSE NULL END),
      pos_verified = FALSE
  FROM customers c
  WHERE p.customer_id = c.id
    AND p.site_state IS NULL
    AND c.state IS NOT NULL
    AND TRIM(c.state) <> '';

  -- Backfill from linked architect if site_state is still NULL
  UPDATE projects p
  SET site_state = a.state,
      site_state_code = COALESCE(a.state_code, CASE WHEN LOWER(a.state) = 'gujarat' THEN '24' WHEN LOWER(a.state) = 'maharashtra' THEN '27' ELSE NULL END),
      pos_verified = FALSE
  FROM architects a
  WHERE p.architect_id = a.id
    AND p.site_state IS NULL
    AND a.state IS NOT NULL
    AND TRIM(a.state) <> '';

  -- NOTICE: Unlinked projects or projects with unknown party locations
  -- are intentionally left NULL (pos_verified = FALSE).
  -- The Sales & Quotations engine will block quotation finalization until
  -- an authorized user enters the real statutory site location.
END $$;

-- 3. Create index for high-speed Place of Supply resolution
CREATE INDEX IF NOT EXISTS idx_projects_site_state ON projects(site_state, site_state_code);
