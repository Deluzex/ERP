-- Customer email hardening: 254-char maximum and basic structural check.
-- Constraints are added NOT VALID so existing rows are never modified or rejected;
-- they are enforced for every new INSERT/UPDATE of the email column.
-- Column type stays TEXT (a length CHECK is equivalent to VARCHAR(254) without a table rewrite).
--
-- To find legacy rows that violate the rules (then fix manually and run VALIDATE):
--   SELECT id, email FROM customers
--    WHERE char_length(email) > 254
--       OR email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$';
--   ALTER TABLE customers VALIDATE CONSTRAINT chk_customers_email_length;
--   ALTER TABLE customers VALIDATE CONSTRAINT chk_customers_email_format;
--
-- Rollback:
--   ALTER TABLE customers DROP CONSTRAINT IF EXISTS chk_customers_email_length;
--   ALTER TABLE customers DROP CONSTRAINT IF EXISTS chk_customers_email_format;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_customers_email_length') THEN
    ALTER TABLE customers
      ADD CONSTRAINT chk_customers_email_length CHECK (char_length(email) <= 254) NOT VALID;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_customers_email_format') THEN
    ALTER TABLE customers
      ADD CONSTRAINT chk_customers_email_format
      CHECK (email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$') NOT VALID;
  END IF;
END $$;
