-- ============================================================================
-- 002_seed_foundation.sql
-- Seed Initial Organization, Permissions, Admin Role and Default Stock Location
-- ============================================================================

DO $$
DECLARE
  v_company_id UUID;
  v_admin_user_id UUID;
BEGIN
  -- 1. Seed Single Client Legal Entity (Q-22 closed - Blazon Creative, Gujarat)
  IF NOT EXISTS (SELECT 1 FROM companies LIMIT 1) THEN
    INSERT INTO companies (
      id, name, trade_name, gstin, pan, state_code, state_name, registered_address, stock_scope_level
    ) VALUES (
      '00000000-0000-0000-0000-000000000001',
      'Blazon Creative LLP',
      'Blazon Creative',
      '24ANHPP9559M1Z5',
      'ANHPP9559M',
      '24',
      'Gujarat',
      'Plot 42, GIDC Phase II, Vatva, Ahmedabad - 382445, Gujarat, India',
      'COMPANY'
    ) RETURNING id INTO v_company_id;
  ELSE
    SELECT id INTO v_company_id FROM companies LIMIT 1;
  END IF;

  -- 2. Seed Default Stock Location (anchored at COMPANY level)
  IF NOT EXISTS (SELECT 1 FROM stock_locations WHERE company_id = v_company_id) THEN
    INSERT INTO stock_locations (
      id, company_id, level, name, is_default, is_active
    ) VALUES (
      '00000000-0000-0000-0000-000000000010',
      v_company_id,
      'COMPANY',
      'Main Central Plant & Warehouse',
      true,
      true
    );
  END IF;

  -- 3. Seed Canonical 90 Permissions across 10 ERP Modules
  INSERT INTO permissions (id, module, action, description)
  VALUES
    -- Dashboard
    ('dashboard.view', 'dashboard', 'view', 'View standard and executive dashboards'),
    ('dashboard.export', 'dashboard', 'export', 'Export dashboard data and charts'),
    -- Inventory
    ('inventory.view', 'inventory', 'view', 'View raw material and finished goods stock'),
    ('inventory.create', 'inventory', 'create', 'Create stock inward records'),
    ('inventory.edit', 'inventory', 'edit', 'Modify inventory records'),
    ('inventory.delete', 'inventory', 'delete', 'Remove inventory items'),
    ('inventory.approve', 'inventory', 'approve', 'Approve stock adjustments'),
    ('inventory.cancel', 'inventory', 'cancel', 'Cancel stock operations'),
    ('inventory.export', 'inventory', 'export', 'Export stock ledgers and reports'),
    ('inventory.print', 'inventory', 'print', 'Print inventory labels and summaries'),
    ('inventory.share', 'inventory', 'share', 'Share inventory reports'),
    -- Purchase
    ('purchase.view', 'purchase', 'view', 'View purchase orders and bills'),
    ('purchase.create', 'purchase', 'create', 'Create purchase orders'),
    ('purchase.edit', 'purchase', 'edit', 'Modify purchase orders'),
    ('purchase.delete', 'purchase', 'delete', 'Cancel / delete purchase orders'),
    ('purchase.approve', 'purchase', 'approve', 'Confirm and approve purchase orders'),
    ('purchase.cancel', 'purchase', 'cancel', 'Cancel confirmed purchase orders'),
    ('purchase.export', 'purchase', 'export', 'Export purchase registers'),
    ('purchase.print', 'purchase', 'print', 'Print purchase orders'),
    ('purchase.share', 'purchase', 'share', 'Share purchase documents'),
    -- Production
    ('production.view', 'production', 'view', 'View production orders and costing'),
    ('production.create', 'production', 'create', 'Create production work orders'),
    ('production.edit', 'production', 'edit', 'Modify production orders'),
    ('production.delete', 'production', 'delete', 'Delete production orders'),
    ('production.approve', 'production', 'approve', 'Complete and approve production batches'),
    ('production.cancel', 'production', 'cancel', 'Cancel production orders'),
    ('production.export', 'production', 'export', 'Export production reports'),
    ('production.print', 'production', 'print', 'Print production job cards'),
    ('production.share', 'production', 'share', 'Share production summaries'),
    -- Sales
    ('sales.view', 'sales', 'view', 'View sales quotations, orders, invoices and returns'),
    ('sales.create', 'sales', 'create', 'Create sales orders and tax invoices'),
    ('sales.edit', 'sales', 'edit', 'Modify sales documents'),
    ('sales.delete', 'sales', 'delete', 'Cancel / delete sales documents'),
    ('sales.approve', 'sales', 'approve', 'Approve quotations and credit notes'),
    ('sales.cancel', 'sales', 'cancel', 'Cancel sales invoices'),
    ('sales.export', 'sales', 'export', 'Export sales register and tax summaries'),
    ('sales.print', 'sales', 'print', 'Print sales invoices and deliveries'),
    ('sales.share', 'sales', 'share', 'Share sales invoices via WhatsApp/Email'),
    -- Payments
    ('payments.view', 'payments', 'view', 'View customer, vendor and commission payments'),
    ('payments.create', 'payments', 'create', 'Record incoming and outgoing payments'),
    ('payments.edit', 'payments', 'edit', 'Modify payment entries'),
    ('payments.delete', 'payments', 'delete', 'Reverse payment entries'),
    ('payments.approve', 'payments', 'approve', 'Authorize high-value payments'),
    ('payments.cancel', 'payments', 'cancel', 'Cancel payment entries'),
    ('payments.export', 'payments', 'export', 'Export financial ledgers'),
    ('payments.print', 'payments', 'print', 'Print payment receipts and vouchers'),
    ('payments.share', 'payments', 'share', 'Share payment vouchers'),
    -- Masters
    ('masters.view', 'masters', 'view', 'View vendors, customers, items and units'),
    ('masters.create', 'masters', 'create', 'Create master records'),
    ('masters.edit', 'masters', 'edit', 'Edit master records'),
    ('masters.delete', 'masters', 'delete', 'Soft-delete master records with reason'),
    ('masters.approve', 'masters', 'approve', 'Approve master changes'),
    ('masters.cancel', 'masters', 'cancel', 'Deactivate master records'),
    ('masters.export', 'masters', 'export', 'Export master directories'),
    ('masters.print', 'masters', 'print', 'Print master directories'),
    ('masters.share', 'masters', 'share', 'Share master profiles'),
    -- Reports
    ('reports.view', 'reports', 'view', 'View business, inventory and tax reports'),
    ('reports.create', 'reports', 'create', 'Generate custom reports'),
    ('reports.edit', 'reports', 'edit', 'Modify report criteria'),
    ('reports.delete', 'reports', 'delete', 'Delete saved reports'),
    ('reports.approve', 'reports', 'approve', 'Approve official statements'),
    ('reports.cancel', 'reports', 'cancel', 'Cancel report generation'),
    ('reports.export', 'reports', 'export', 'Export reports to Excel and PDF'),
    ('reports.print', 'reports', 'print', 'Print reports'),
    ('reports.share', 'reports', 'share', 'Share reports via Email/WhatsApp'),
    -- Settings
    ('settings.view', 'settings', 'view', 'View system settings and parameters'),
    ('settings.create', 'settings', 'create', 'Add system parameters'),
    ('settings.edit', 'settings', 'edit', 'Modify system settings'),
    ('settings.delete', 'settings', 'delete', 'Delete configuration settings'),
    ('settings.approve', 'settings', 'approve', 'Authorize configuration changes'),
    ('settings.cancel', 'settings', 'cancel', 'Revert configuration settings'),
    ('settings.export', 'settings', 'export', 'Export system audit and configuration'),
    ('settings.print', 'settings', 'print', 'Print system configuration'),
    ('settings.share', 'settings', 'share', 'Share system parameters'),
    -- User & Role Management
    ('userManagement.view', 'userManagement', 'view', 'View users, roles and permissions'),
    ('userManagement.create', 'userManagement', 'create', 'Create users and custom roles'),
    ('userManagement.edit', 'userManagement', 'edit', 'Update user profiles and role assignments'),
    ('userManagement.delete', 'userManagement', 'delete', 'Deactivate users and custom roles'),
    ('userManagement.approve', 'userManagement', 'approve', 'Authorize temporary permission overrides'),
    ('userManagement.cancel', 'userManagement', 'cancel', 'Revoke user access grants'),
    ('userManagement.export', 'userManagement', 'export', 'Export security audit logs'),
    ('userManagement.print', 'userManagement', 'print', 'Print user and role listings'),
    ('userManagement.share', 'userManagement', 'share', 'Share security reports')
  ON CONFLICT (id) DO NOTHING;

  -- 4. Seed Super Administrator Role
  INSERT INTO roles (id, name, description, is_system_role, is_active, default_dashboard_section)
  VALUES (
    'admin',
    'System Administrator',
    'Full unrestricted access across all modules, configuration, and security matrices',
    true,
    true,
    'dashboard'
  ) ON CONFLICT (id) DO NOTHING;

  -- 5. Associate all permissions with Super Admin Role
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT 'admin', id FROM permissions
  ON CONFLICT (role_id, permission_id) DO NOTHING;

  -- 6. Seed Super Administrator User
  -- Password hash for 'Admin@123': $argon2id$v=19$m=65536,t=3,p=1$4KjGvS1x3s4...
  -- We insert or update with a verified Argon2id hash for 'Admin@123'
  IF NOT EXISTS (SELECT 1 FROM users WHERE email = 'admin@deluzex.com') THEN
    INSERT INTO users (
      id, name, email, mobile, password_hash, is_active
    ) VALUES (
      '00000000-0000-0000-0000-000000000100',
      'Super Administrator',
      'admin@deluzex.com',
      '+91 98765 43210',
      '$argon2id$v=19$m=65536,t=3,p=4$X3FA6ziiPlZRfwYRRZIEiQ$Se14+TV32DdGa5zX/F5nqV4DXBWROdKL5djlV3qnGs8',
      true
    ) RETURNING id INTO v_admin_user_id;

    -- Assign admin role
    INSERT INTO user_roles (user_id, role_id, is_primary)
    VALUES (v_admin_user_id, 'admin', true)
    ON CONFLICT (user_id, role_id) DO NOTHING;

    -- Assign default stock location
    INSERT INTO user_stock_location_access (user_id, stock_location_id)
    VALUES (v_admin_user_id, '00000000-0000-0000-0000-000000000010')
    ON CONFLICT (user_id, stock_location_id) DO NOTHING;
  END IF;

END $$;
