-- Seed standard expense categories matching Deluzex ERP taxonomy and add linked_key column
ALTER TABLE expense_categories ADD COLUMN IF NOT EXISTS linked_key VARCHAR(50);

INSERT INTO expense_categories (name, code, description, is_active, linked_key)
VALUES
  ('Transportation & Logistics', 'EXP-TRANS', 'Freight, vehicle hire, and site material delivery charges', true, 'transportation'),
  ('Courier & Packaging', 'EXP-COURIER', 'Domestic express parcels, blueprints, and sample dispatches', true, 'courier'),
  ('Fuel & Conveyance', 'EXP-FUEL', 'Diesel, petrol, client site visits, and local travel allowance', true, 'fuel'),
  ('Direct Labour & Overtime', 'EXP-LABOUR', 'Contract factory workers, loading/unloading, and site installation wages', true, 'labour'),
  ('Electricity & Utilities', 'EXP-UTIL', 'Factory power bills, backup generator diesel, and water utility', true, 'electricity'),
  ('Plant & Machinery Maintenance', 'EXP-MAINT', 'Machine servicing, tooling replacement, and workshop upkeep', true, 'maintenance'),
  ('Office & Administrative', 'EXP-OFFICE', 'Stationery, pantry supplies, software subscriptions, and internet', true, 'officeExpense'),
  ('Production Consumables', 'EXP-PROD-CONS', 'Safety gear, cutting blades, adhesives, and workshop consumables', true, 'productionExpense'),
  ('Project Site Expenses', 'EXP-SITE', 'Architect sample mocks, scaffold hire, and site coordination fees', true, 'projectExpense'),
  ('General & Miscellaneous', 'EXP-MISC', 'Incidental business expenses and petty cash charges', true, 'other')
ON CONFLICT (code) DO UPDATE SET
  name = EXCLUDED.name,
  description = EXCLUDED.description,
  linked_key = EXCLUDED.linked_key;
