-- ============================================================================
-- API_CONFIGURATION TABLE SCHEMA
-- ============================================================================
-- This file creates the api_configuration table for API settings
-- ============================================================================

-- ============================================================================
-- 1. CREATE API_CONFIGURATION TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS api_configuration (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1), -- Singleton table
    enabled BOOLEAN NOT NULL DEFAULT false,
    xpub_key TEXT NOT NULL DEFAULT '',
    wallet_hash TEXT NOT NULL DEFAULT '',
    webhook_url TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_api_configuration_id ON api_configuration(id);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_api_configuration_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to get API configuration
CREATE OR REPLACE FUNCTION get_api_configuration()
RETURNS JSON AS $$
DECLARE
    config RECORD;
BEGIN
    SELECT * INTO config
    FROM api_configuration
    WHERE id = 1;
    
    IF NOT FOUND THEN
        -- Insert default configuration if not exists
        INSERT INTO api_configuration (id, enabled, xpub_key, wallet_hash, webhook_url)
        VALUES (1, false, '', '', '')
        RETURNING * INTO config;
    END IF;
    
    RETURN json_build_object(
        'id', config.id,
        'enabled', config.enabled,
        'xpub_key', config.xpub_key,
        'wallet_hash', config.wallet_hash,
        'webhook_url', config.webhook_url,
        'created_at', config.created_at,
        'updated_at', config.updated_at
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_api_configuration_updated_at ON api_configuration;
CREATE TRIGGER update_api_configuration_updated_at
    BEFORE UPDATE ON api_configuration
    FOR EACH ROW
    EXECUTE FUNCTION update_api_configuration_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE api_configuration ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access api_configuration" ON api_configuration;
CREATE POLICY "Service role full access api_configuration"
ON api_configuration
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated users can read
DROP POLICY IF EXISTS "Authenticated can read api_configuration" ON api_configuration;
CREATE POLICY "Authenticated can read api_configuration"
ON api_configuration
FOR SELECT
TO authenticated
USING (true);

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON api_configuration TO service_role;
GRANT SELECT ON api_configuration TO authenticated;
GRANT EXECUTE ON FUNCTION get_api_configuration() TO authenticated, service_role;

-- ============================================================================
-- 8. INITIALIZE DEFAULT CONFIGURATION
-- ============================================================================
INSERT INTO api_configuration (id, enabled, xpub_key, wallet_hash, webhook_url)
VALUES (1, false, '', '', '')
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- END OF API_CONFIGURATION SCHEMA
-- ============================================================================

