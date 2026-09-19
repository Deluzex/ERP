-- ============================================================================
-- 010_projects.sql
-- Deluzex ERP Phase 6: Architectural Projects & Portfolio Module Schema
-- Implements: Section 10 of BACKEND_API_REQUIREMENTS.md
--             ADR-011 (NUMERIC(18,2) financial currency)
--             ADR-012 (Soft delete with mandatory reason & audit trail)
-- ============================================================================

-- 1. Create Projects Table
CREATE TABLE IF NOT EXISTS projects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  project_code TEXT NOT NULL,
  name TEXT NOT NULL,
  customer_id UUID NULL REFERENCES customers(id) ON DELETE SET NULL,
  customer_name TEXT NULL,
  dealer_id UUID NULL REFERENCES dealers(id) ON DELETE SET NULL,
  dealer_name TEXT NULL,
  architect_id UUID NULL REFERENCES architects(id) ON DELETE SET NULL,
  architect_name TEXT NULL,
  start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  expected_completion_date DATE NULL,
  actual_completion_date DATE NULL,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('planned', 'active', 'completed', 'closed', 'cancelled')),
  budget_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  total_sales_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  total_commission_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
  notes TEXT NULL,
  is_deleted BOOLEAN NOT NULL DEFAULT false,
  deleted_at TIMESTAMPTZ NULL,
  delete_reason TEXT NULL,
  created_by UUID NULL REFERENCES users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Partial unique index allowing project code reuse after soft-delete
CREATE UNIQUE INDEX IF NOT EXISTS uq_projects__project_code
  ON projects (project_code) WHERE is_deleted = false;

CREATE INDEX IF NOT EXISTS idx_projects__search
  ON projects (name, status, customer_id, architect_id);

CREATE INDEX IF NOT EXISTS idx_projects__dates
  ON projects (start_date, expected_completion_date);

-- 2. Seed Canonical Permissions for Projects Module
INSERT INTO permissions (id, module, action, description)
VALUES
  ('projects.view', 'projects', 'view', 'View architectural projects and site portfolios'),
  ('projects.create', 'projects', 'create', 'Create architectural projects'),
  ('projects.edit', 'projects', 'edit', 'Modify architectural projects'),
  ('projects.delete', 'projects', 'delete', 'Soft-delete architectural projects with reason'),
  ('projects.approve', 'projects', 'approve', 'Approve project milestones and budgets'),
  ('projects.cancel', 'projects', 'cancel', 'Cancel or close architectural projects'),
  ('projects.export', 'projects', 'export', 'Export project portfolio registers'),
  ('projects.print', 'projects', 'print', 'Print project job sheets and financials'),
  ('projects.share', 'projects', 'share', 'Share project portfolio reports')
ON CONFLICT (id) DO NOTHING;

-- Map to Super Admin role
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'admin', id FROM permissions WHERE module = 'projects'
ON CONFLICT DO NOTHING;

-- Map to Project Manager role
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'project_manager', id FROM permissions WHERE module = 'projects'
ON CONFLICT DO NOTHING;

-- 3. Safely Link Existing Tables to Projects Table
DO $$
BEGIN
  -- purchases
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_purchases__project'
  ) THEN
    ALTER TABLE purchases
      ADD CONSTRAINT fk_purchases__project
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL;
  END IF;

  -- production_orders
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_production_orders__project'
  ) THEN
    ALTER TABLE production_orders
      ADD CONSTRAINT fk_production_orders__project
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL;
  END IF;

  -- sales
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_sales__project'
  ) THEN
    ALTER TABLE sales
      ADD CONSTRAINT fk_sales__project
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL;
  END IF;

  -- sales_quotations
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_sales_quotations__project'
  ) THEN
    ALTER TABLE sales_quotations
      ADD CONSTRAINT fk_sales_quotations__project
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL;
  END IF;

  -- sales_orders
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'fk_sales_orders__project'
  ) THEN
    ALTER TABLE sales_orders
      ADD CONSTRAINT fk_sales_orders__project
      FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    RAISE NOTICE 'Constraint creation notice: %', SQLERRM;
END $$;
