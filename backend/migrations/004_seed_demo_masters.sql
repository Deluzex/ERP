-- ============================================================================
-- 004_seed_demo_masters.sql
-- Seed Standard Item Categories, Demo Roles, and Demo Users for Live Testing
-- ============================================================================

DO $$
DECLARE
  v_company_id UUID;
  v_stock_loc_id UUID;
  v_pwd_hash TEXT := '$argon2id$v=19$m=65536,t=3,p=4$X3FA6ziiPlZRfwYRRZIEiQ$Se14+TV32DdGa5zX/F5nqV4DXBWROdKL5djlV3qnGs8'; -- 'Admin@123'
BEGIN
  -- Get default company and stock location
  SELECT id INTO v_company_id FROM companies LIMIT 1;
  SELECT id INTO v_stock_loc_id FROM stock_locations WHERE is_default = true LIMIT 1;

  -- 1. Seed Standard Categories
  INSERT INTO categories (name, description)
  VALUES
    ('Wall Lights & Sconces', 'Architectural wall mounted lighting and decorative sconces'),
    ('Pendants & Chandeliers', 'Suspension ceiling lights and luxury crystal chandeliers'),
    ('Raw Metals & Aluminum', 'Extruded aluminum profiles, brass rods, and sheet metals'),
    ('LED Drivers & Diodes', 'SMD LED strips, COB modules, and constant-current drivers'),
    ('Diffusers & Glassware', 'Frosted acrylic panels, optical lenses, and hand-blown glass')
  ON CONFLICT (name) DO NOTHING;

  -- 2. Seed Canonical Demo Roles
  INSERT INTO roles (id, name, description, is_system_role, is_active, default_dashboard_section)
  VALUES
    ('sales_manager', 'Sales Manager', 'Quotations, Sales Orders, Tax Invoices, Delivery Challans, and Client Masters', true, true, 'salesDashboard'),
    ('inventory_manager', 'Inventory Manager', 'Warehouse operations, raw material stock, finished goods, and adjustments', true, true, 'inventoryDashboard'),
    ('purchase_manager', 'Purchase Manager', 'Supplier procurement, vendor management, POs, and GRNs', true, true, 'purchaseDashboard'),
    ('production_manager', 'Production Manager', 'Manufacturing work orders, BOM assembly, routing, and machine assignment', true, true, 'productionDashboard'),
    ('accounts_manager', 'Accounts Manager', 'Receivables, payables, dealer ledgers, expenses, and GST reporting', true, true, 'paymentsDashboard'),
    ('project_manager', 'Project Manager', 'Architectural project portfolio, site tracking, and material budget consumption', true, true, 'projectList'),
    ('report_viewer', 'Auditor / Report Viewer', 'Read-only analytics, financial ledgers, compliance audits, and tax registers', true, true, 'reportsSection'),
    ('data_entry', 'Data Entry Clerk', 'Restricted transactional entry with maker-checker controls', true, true, 'dashboard')
  ON CONFLICT (id) DO NOTHING;

  -- 3. Assign Permissions to Demo Roles
  -- Sales Manager
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT 'sales_manager', id FROM permissions
  WHERE module IN ('dashboard', 'sales', 'masters', 'reports')
  ON CONFLICT (role_id, permission_id) DO NOTHING;

  -- Inventory Manager
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT 'inventory_manager', id FROM permissions
  WHERE module IN ('dashboard', 'inventory', 'masters', 'reports')
  ON CONFLICT (role_id, permission_id) DO NOTHING;

  -- Purchase Manager
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT 'purchase_manager', id FROM permissions
  WHERE module IN ('dashboard', 'purchase', 'masters', 'reports')
  ON CONFLICT (role_id, permission_id) DO NOTHING;

  -- Production Manager
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT 'production_manager', id FROM permissions
  WHERE module IN ('dashboard', 'production', 'inventory', 'masters', 'reports')
  ON CONFLICT (role_id, permission_id) DO NOTHING;

  -- Accounts Manager
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT 'accounts_manager', id FROM permissions
  WHERE module IN ('dashboard', 'payments', 'sales', 'purchase', 'reports')
  ON CONFLICT (role_id, permission_id) DO NOTHING;

  -- Project Manager
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT 'project_manager', id FROM permissions
  WHERE module IN ('dashboard', 'sales', 'production', 'inventory', 'masters', 'reports')
  ON CONFLICT (role_id, permission_id) DO NOTHING;

  -- Report Viewer
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT 'report_viewer', id FROM permissions
  WHERE action IN ('view', 'export', 'print')
  ON CONFLICT (role_id, permission_id) DO NOTHING;

  -- Data Entry Clerk
  INSERT INTO role_permissions (role_id, permission_id)
  SELECT 'data_entry', id FROM permissions
  WHERE module IN ('dashboard', 'masters', 'inventory', 'sales', 'purchase')
    AND action IN ('view', 'create', 'edit')
  ON CONFLICT (role_id, permission_id) DO NOTHING;

  -- 4. Seed Demo Users (all with password 'Admin@123')
  -- Sales User
  IF NOT EXISTS (SELECT 1 FROM users WHERE email = 'sales@deluzex.com') THEN
    INSERT INTO users (id, name, email, mobile, password_hash, is_active)
    VALUES ('00000000-0000-0000-0000-000000000101', 'Sameer Kapoor', 'sales@deluzex.com', '+91 98765 00001', v_pwd_hash, true);
    INSERT INTO user_roles (user_id, role_id, is_primary) VALUES ('00000000-0000-0000-0000-000000000101', 'sales_manager', true) ON CONFLICT DO NOTHING;
    IF v_stock_loc_id IS NOT NULL THEN
      INSERT INTO user_stock_location_access (user_id, stock_location_id) VALUES ('00000000-0000-0000-0000-000000000101', v_stock_loc_id) ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  -- Inventory User
  IF NOT EXISTS (SELECT 1 FROM users WHERE email = 'inventory@deluzex.com') THEN
    INSERT INTO users (id, name, email, mobile, password_hash, is_active)
    VALUES ('00000000-0000-0000-0000-000000000102', 'Rohan Varma', 'inventory@deluzex.com', '+91 98765 00002', v_pwd_hash, true);
    INSERT INTO user_roles (user_id, role_id, is_primary) VALUES ('00000000-0000-0000-0000-000000000102', 'inventory_manager', true) ON CONFLICT DO NOTHING;
    IF v_stock_loc_id IS NOT NULL THEN
      INSERT INTO user_stock_location_access (user_id, stock_location_id) VALUES ('00000000-0000-0000-0000-000000000102', v_stock_loc_id) ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  -- Purchase User
  IF NOT EXISTS (SELECT 1 FROM users WHERE email = 'purchase@deluzex.com') THEN
    INSERT INTO users (id, name, email, mobile, password_hash, is_active)
    VALUES ('00000000-0000-0000-0000-000000000103', 'Vikram Mehta', 'purchase@deluzex.com', '+91 98765 00003', v_pwd_hash, true);
    INSERT INTO user_roles (user_id, role_id, is_primary) VALUES ('00000000-0000-0000-0000-000000000103', 'purchase_manager', true) ON CONFLICT DO NOTHING;
    IF v_stock_loc_id IS NOT NULL THEN
      INSERT INTO user_stock_location_access (user_id, stock_location_id) VALUES ('00000000-0000-0000-0000-000000000103', v_stock_loc_id) ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  -- Production User
  IF NOT EXISTS (SELECT 1 FROM users WHERE email = 'production@deluzex.com') THEN
    INSERT INTO users (id, name, email, mobile, password_hash, is_active)
    VALUES ('00000000-0000-0000-0000-000000000104', 'Ananya Desai', 'production@deluzex.com', '+91 98765 00004', v_pwd_hash, true);
    INSERT INTO user_roles (user_id, role_id, is_primary) VALUES ('00000000-0000-0000-0000-000000000104', 'production_manager', true) ON CONFLICT DO NOTHING;
    IF v_stock_loc_id IS NOT NULL THEN
      INSERT INTO user_stock_location_access (user_id, stock_location_id) VALUES ('00000000-0000-0000-0000-000000000104', v_stock_loc_id) ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  -- Accounts User
  IF NOT EXISTS (SELECT 1 FROM users WHERE email = 'accounts@deluzex.com') THEN
    INSERT INTO users (id, name, email, mobile, password_hash, is_active)
    VALUES ('00000000-0000-0000-0000-000000000105', 'Kavita Iyer', 'accounts@deluzex.com', '+91 98765 00005', v_pwd_hash, true);
    INSERT INTO user_roles (user_id, role_id, is_primary) VALUES ('00000000-0000-0000-0000-000000000105', 'accounts_manager', true) ON CONFLICT DO NOTHING;
    IF v_stock_loc_id IS NOT NULL THEN
      INSERT INTO user_stock_location_access (user_id, stock_location_id) VALUES ('00000000-0000-0000-0000-000000000105', v_stock_loc_id) ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  -- Projects User
  IF NOT EXISTS (SELECT 1 FROM users WHERE email = 'projects@deluzex.com') THEN
    INSERT INTO users (id, name, email, mobile, password_hash, is_active)
    VALUES ('00000000-0000-0000-0000-000000000106', 'Manish Trivedi', 'projects@deluzex.com', '+91 98765 00006', v_pwd_hash, true);
    INSERT INTO user_roles (user_id, role_id, is_primary) VALUES ('00000000-0000-0000-0000-000000000106', 'project_manager', true) ON CONFLICT DO NOTHING;
    IF v_stock_loc_id IS NOT NULL THEN
      INSERT INTO user_stock_location_access (user_id, stock_location_id) VALUES ('00000000-0000-0000-0000-000000000106', v_stock_loc_id) ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  -- Reports User
  IF NOT EXISTS (SELECT 1 FROM users WHERE email = 'reports@deluzex.com') THEN
    INSERT INTO users (id, name, email, mobile, password_hash, is_active)
    VALUES ('00000000-0000-0000-0000-000000000107', 'Neha Saxena', 'reports@deluzex.com', '+91 98765 00007', v_pwd_hash, true);
    INSERT INTO user_roles (user_id, role_id, is_primary) VALUES ('00000000-0000-0000-0000-000000000107', 'report_viewer', true) ON CONFLICT DO NOTHING;
    IF v_stock_loc_id IS NOT NULL THEN
      INSERT INTO user_stock_location_access (user_id, stock_location_id) VALUES ('00000000-0000-0000-0000-000000000107', v_stock_loc_id) ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  -- Data Entry User
  IF NOT EXISTS (SELECT 1 FROM users WHERE email = 'dataentry@deluzex.com') THEN
    INSERT INTO users (id, name, email, mobile, password_hash, is_active)
    VALUES ('00000000-0000-0000-0000-000000000108', 'Deepak Sharma', 'dataentry@deluzex.com', '+91 98765 00008', v_pwd_hash, true);
    INSERT INTO user_roles (user_id, role_id, is_primary) VALUES ('00000000-0000-0000-0000-000000000108', 'data_entry', true) ON CONFLICT DO NOTHING;
    IF v_stock_loc_id IS NOT NULL THEN
      INSERT INTO user_stock_location_access (user_id, stock_location_id) VALUES ('00000000-0000-0000-0000-000000000108', v_stock_loc_id) ON CONFLICT DO NOTHING;
    END IF;
  END IF;

END $$;
