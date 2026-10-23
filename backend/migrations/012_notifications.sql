-- ============================================================================
-- 012_notifications.sql
-- Deluzex ERP: Role-Based Notifications Architecture
-- Implements: Persistent notifications for Sales -> Purchase/Production requisitions,
--             Role-based visibility & recipient routing (Admin, Purchase, Production, Sales)
-- ============================================================================

-- 1. Create Notifications Table
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  notification_type TEXT NOT NULL DEFAULT 'requisition',
  target_role TEXT NULL, -- e.g. 'purchase_manager', 'production_manager', 'sales_manager', 'admin'
  recipient_user_id UUID NULL REFERENCES users(id) ON DELETE CASCADE,
  recipient_name TEXT NULL,
  recipient_email TEXT NULL,
  source_module TEXT NOT NULL DEFAULT 'sales',
  related_entity_type TEXT NULL DEFAULT 'sales_order',
  related_entity_id UUID NULL,
  data JSONB NOT NULL DEFAULT '{}'::jsonb,
  is_read BOOLEAN NOT NULL DEFAULT false,
  read_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Create Optimized Indexes
CREATE INDEX IF NOT EXISTS idx_notifications__recipient
  ON notifications (recipient_user_id, is_read, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications__role
  ON notifications (target_role, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_notifications__created
  ON notifications (created_at DESC);

-- 3. Seed Canonical Notification Permissions
INSERT INTO permissions (id, module, action, description)
VALUES
  ('notifications.view', 'notifications', 'view', 'View authorized role and user notifications'),
  ('notifications.create', 'notifications', 'create', 'Create and dispatch notifications'),
  ('notifications.edit', 'notifications', 'edit', 'Mark notifications as read or resolved')
ON CONFLICT (id) DO NOTHING;

-- 4. Associate Notification Permissions with System and Demo Roles
-- Super Admin
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'admin', id FROM permissions WHERE module = 'notifications'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Sales Manager
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'sales_manager', id FROM permissions WHERE module = 'notifications'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Purchase Manager
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'purchase_manager', id FROM permissions WHERE module = 'notifications'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Production Manager
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'production_manager', id FROM permissions WHERE module = 'notifications'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Inventory Manager
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'inventory_manager', id FROM permissions WHERE module = 'notifications'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Accounts Manager
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'accounts_manager', id FROM permissions WHERE module = 'notifications'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Project Manager
INSERT INTO role_permissions (role_id, permission_id)
SELECT 'project_manager', id FROM permissions WHERE module = 'notifications'
ON CONFLICT (role_id, permission_id) DO NOTHING;
