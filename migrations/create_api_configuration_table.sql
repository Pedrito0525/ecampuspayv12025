-- Create api_configuration table for Paytaca settings
CREATE TABLE IF NOT EXISTS api_configuration (
    id SERIAL PRIMARY KEY,
    enabled BOOLEAN NOT NULL DEFAULT false,
    xpub_key TEXT NOT NULL DEFAULT '',
    wallet_hash TEXT NOT NULL DEFAULT '',
    webhook_url TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    -- PayMongo configuration fields
    paymongo_enabled BOOLEAN NOT NULL DEFAULT false,
    paymongo_public_key TEXT NOT NULL DEFAULT '',
    paymongo_secret_key TEXT NOT NULL DEFAULT '',
    paymongo_webhook_secret TEXT NOT NULL DEFAULT '',
    paymongo_provider TEXT NOT NULL DEFAULT 'gcash'
);

-- Insert default configuration (only if no records exist)
INSERT INTO api_configuration (
    enabled, xpub_key, wallet_hash, webhook_url,
    paymongo_enabled, paymongo_public_key, paymongo_secret_key, paymongo_webhook_secret, paymongo_provider
)
SELECT false, '', '', '', false, '', '', '', 'gcash'
WHERE NOT EXISTS (SELECT 1 FROM api_configuration);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_api_configuration_enabled ON api_configuration(enabled);

-- Add comment to table
COMMENT ON TABLE api_configuration IS 'Stores API configuration settings for Paytaca/PayMongo';
COMMENT ON COLUMN api_configuration.enabled IS 'Whether Paytaca payment system is enabled';
COMMENT ON COLUMN api_configuration.xpub_key IS 'Extended public key for Paytaca wallet';
COMMENT ON COLUMN api_configuration.wallet_hash IS 'Wallet hash for Paytaca wallet';
COMMENT ON COLUMN api_configuration.webhook_url IS 'Webhook URL for payment notifications';
COMMENT ON COLUMN api_configuration.paymongo_enabled IS 'Whether PayMongo gateway is enabled';
COMMENT ON COLUMN api_configuration.paymongo_public_key IS 'PayMongo public key';
COMMENT ON COLUMN api_configuration.paymongo_secret_key IS 'PayMongo secret key';
COMMENT ON COLUMN api_configuration.paymongo_webhook_secret IS 'PayMongo webhook signing secret';
COMMENT ON COLUMN api_configuration.paymongo_provider IS 'Selected payment provider (gcash, maya, grabpay)';

-- Note: RLS policies will be added later once we understand the auth_students table structure
-- For now, the table is accessible to all authenticated users
-- Run inspect_auth_students.sql to check the table structure first
