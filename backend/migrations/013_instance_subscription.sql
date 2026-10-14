-- ============================================================================
-- 013_instance_subscription.sql
-- Deluzex ERP: Instance Licensing & Subscription Management Subsystem
-- Single-Client Dedicated Cloud Architecture (ADR-014)
-- ============================================================================

CREATE TABLE IF NOT EXISTS instance_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_name VARCHAR(150) NOT NULL DEFAULT 'Deluzex Client',
    plan_name VARCHAR(100) NOT NULL DEFAULT 'Enterprise Annual',
    valid_from TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    valid_until TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '1 year'),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    warning_days INT NOT NULL DEFAULT 30,
    support_phone VARCHAR(20) NOT NULL DEFAULT '+91 98250 12345',
    support_email VARCHAR(100) NOT NULL DEFAULT 'billing@deluzex.com',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Ensure there is at least one active subscription row for this instance
INSERT INTO instance_subscriptions (
    client_name, plan_name, valid_from, valid_until, is_active, warning_days, support_phone, support_email
)
SELECT 
    'Deluzex Lighting & Living Ltd.', 
    'Enterprise Annual Edition', 
    NOW(), 
    NOW() + INTERVAL '1 year', 
    TRUE, 
    30, 
    '+91 98250 12345', 
    'billing@deluzex.com'
WHERE NOT EXISTS (SELECT 1 FROM instance_subscriptions);

CREATE INDEX IF NOT EXISTS idx_instance_subscriptions_active 
ON instance_subscriptions(is_active, valid_until);
