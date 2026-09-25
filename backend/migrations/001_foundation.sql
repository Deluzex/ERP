-- ============================================================================
-- 001_foundation.sql
-- Deluzex ERP Phase 0 Foundation Schema
-- Applies: ADR-003 (Backend Auth), ADR-004 (RBAC), ADR-012 (Audit),
--          ADR-013 (Flexible Stock Scope), ADR-014 (Dedicated Instance)
-- ============================================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Migration Tracking Table
CREATE TABLE IF NOT EXISTS _migrations (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,
  executed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Stock Scope Level Enum (ADR-013)
DO $$ BEGIN
  CREATE TYPE stock_scope_level AS ENUM ('COMPANY', 'BRANCH', 'WAREHOUSE');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- 1. Companies Table (Single Client Legal Entity - Q-22 Closed)
CREATE TABLE IF NOT EXISTS companies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  trade_name TEXT NULL,
  gstin TEXT NULL,
  pan TEXT NULL,
  state_code TEXT NOT NULL DEFAULT '24', -- 24 = Gujarat
  state_name TEXT NOT NULL DEFAULT 'Gujarat',
  registered_address TEXT NOT NULL,
  email TEXT NULL,
  phone TEXT NULL,
  stock_scope_level stock_scope_level NOT NULL DEFAULT 'COMPANY',
  currency_code TEXT NOT NULL DEFAULT 'INR',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Optional Branches Table
CREATE TABLE IF NOT EXISTS branches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT NOT NULL,
  address TEXT NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_branches__company_code UNIQUE (company_id, code)
);

-- 3. Optional Warehouses Table
CREATE TABLE IF NOT EXISTS warehouses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT NOT NULL,
  address TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_warehouses__branch_code UNIQUE (branch_id, code)
);

-- 4. Stock Locations Table (ADR-013 Flexible Scope Anchor)
-- Confines nullability here with consistency checks; all downstream stock tables use NOT NULL
CREATE TABLE IF NOT EXISTS stock_locations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
  level stock_scope_level NOT NULL,
  branch_id UUID NULL REFERENCES branches(id) ON DELETE RESTRICT,
  warehouse_id UUID NULL REFERENCES warehouses(id) ON DELETE RESTRICT,
  name TEXT NOT NULL,
  is_default BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT ck_stock_locations__level_consistency CHECK (
    (level = 'COMPANY' AND branch_id IS NULL AND warehouse_id IS NULL) OR
    (level = 'BRANCH' AND branch_id IS NOT NULL AND warehouse_id IS NULL) OR
    (level = 'WAREHOUSE' AND branch_id IS NOT NULL AND warehouse_id IS NOT NULL)
  )
);

-- Enforce exactly one default stock location per company
CREATE UNIQUE INDEX IF NOT EXISTS uq_stock_locations__one_default
  ON stock_locations (company_id) WHERE is_default = true;

-- 5. Users Table (ADR-003 Backend Owned Auth)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  mobile TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  avatar_url TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT true,
  last_login_at TIMESTAMPTZ NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. Roles Table (ADR-004 Customer Configurable RBAC)
CREATE TABLE IF NOT EXISTS roles (
  id TEXT PRIMARY KEY, -- e.g. 'admin', 'inventory_manager', or custom UUID
  name TEXT NOT NULL,
  description TEXT NOT NULL,
  is_system_role BOOLEAN NOT NULL DEFAULT false,
  is_active BOOLEAN NOT NULL DEFAULT true,
  default_dashboard_section TEXT NOT NULL DEFAULT 'dashboard',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. Permissions Table
CREATE TABLE IF NOT EXISTS permissions (
  id TEXT PRIMARY KEY, -- e.g. 'vendor.create', 'purchase.approve'
  module TEXT NOT NULL,
  action TEXT NOT NULL,
  description TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. Role Permissions (Many-to-Many)
CREATE TABLE IF NOT EXISTS role_permissions (
  role_id TEXT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id TEXT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);

-- 9. User Roles (User primary & assigned roles)
CREATE TABLE IF NOT EXISTS user_roles (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  role_id TEXT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  is_primary BOOLEAN NOT NULL DEFAULT false,
  PRIMARY KEY (user_id, role_id)
);

-- 10. User Scope Assignments
CREATE TABLE IF NOT EXISTS user_branch_access (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  branch_id UUID NOT NULL REFERENCES branches(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, branch_id)
);

CREATE TABLE IF NOT EXISTS user_stock_location_access (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  stock_location_id UUID NOT NULL REFERENCES stock_locations(id) ON DELETE CASCADE,
  PRIMARY KEY (user_id, stock_location_id)
);

-- 11. Refresh Tokens (Revocable & Rotatable)
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_id UUID NOT NULL UNIQUE,
  is_revoked BOOLEAN NOT NULL DEFAULT false,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens__user_id ON refresh_tokens (user_id);

-- 12. Audit Logs Table (Immutable History)
CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NULL REFERENCES users(id) ON DELETE SET NULL,
  user_name TEXT NULL,
  action TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id UUID NULL,
  before_snapshot JSONB NULL,
  after_snapshot JSONB NULL,
  reason TEXT NULL,
  correlation_id TEXT NULL,
  ip_address TEXT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_logs__entity ON audit_logs (entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs__created_at ON audit_logs (created_at DESC);
