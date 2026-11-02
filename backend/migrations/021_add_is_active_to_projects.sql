-- ============================================================================
-- 021_add_is_active_to_projects.sql
-- Deluzex ERP: Project Master Status Lifecycle Support
-- Adds is_active column to projects table to support active/inactive toggling
-- ============================================================================

ALTER TABLE projects
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_projects_is_active
  ON projects (is_active) WHERE is_deleted = false;

