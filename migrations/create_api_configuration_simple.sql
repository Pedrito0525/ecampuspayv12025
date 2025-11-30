-- Simple version without RLS - for basic functionality
-- Create api_configuration table for Paytaca settings
CREATE TABLE IF NOT EXISTS api_configuration (
    id SERIAL PRIMARY KEY,
    enabled BOOLEAN NOT NULL DEFAULT false,
    xpub_key TEXT NOT NULL DEFAULT '',
    wallet_hash TEXT NOT NULL DEFAULT '',
    webhook_url TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insert default configuration (only if no records exist)
INSERT INTO api_configuration (enabled, xpub_key, wallet_hash, webhook_url)
SELECT false, '', '', ''
WHERE NOT EXISTS (SELECT 1 FROM api_configuration);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_api_configuration_enabled ON api_configuration(enabled);

-- Add comment to table
COMMENT ON TABLE api_configuration IS 'Stores Paytaca API configuration settings for the application';
COMMENT ON COLUMN api_configuration.enabled IS 'Whether Paytaca payment system is enabled';
COMMENT ON COLUMN api_configuration.xpub_key IS 'Extended public key for Paytaca wallet';
COMMENT ON COLUMN api_configuration.wallet_hash IS 'Wallet hash for Paytaca wallet';
COMMENT ON COLUMN api_configuration.webhook_url IS 'Webhook URL for payment notifications';
