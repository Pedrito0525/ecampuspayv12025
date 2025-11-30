-- ============================================================================
-- SERVICE_ACCOUNTS TABLE SCHEMA
-- ============================================================================
-- This file creates the service_accounts table with main/sub hierarchy support
-- ============================================================================

-- ============================================================================
-- 1. CREATE SERVICE_ACCOUNTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS service_accounts (
    id SERIAL PRIMARY KEY,
    service_name VARCHAR(255) NOT NULL,
    service_category VARCHAR(100) NOT NULL,
    operational_type VARCHAR(20) NOT NULL CHECK (operational_type IN ('Main', 'Sub')),
    main_service_id INTEGER REFERENCES service_accounts(id) ON DELETE CASCADE,
    contact_person VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    balance DECIMAL(10,2) DEFAULT 0.00 CHECK (balance >= 0),
    is_active BOOLEAN DEFAULT true,
    scanner_id VARCHAR(100) UNIQUE,
    commission_rate DECIMAL(5,2) DEFAULT 0.00 CHECK (commission_rate >= 0 AND commission_rate <= 100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT check_sub_account_has_main CHECK (
        (operational_type = 'Main' AND main_service_id IS NULL) OR 
        (operational_type = 'Sub' AND main_service_id IS NOT NULL)
    ),
    CONSTRAINT check_sub_account_no_balance CHECK (
        operational_type = 'Main' OR balance = 0.00
    )
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_service_accounts_service_name ON service_accounts(service_name);
CREATE INDEX IF NOT EXISTS idx_service_accounts_operational_type ON service_accounts(operational_type);
CREATE INDEX IF NOT EXISTS idx_service_accounts_main_service_id ON service_accounts(main_service_id);
CREATE INDEX IF NOT EXISTS idx_service_accounts_username ON service_accounts(username);
CREATE INDEX IF NOT EXISTS idx_service_accounts_scanner_id ON service_accounts(scanner_id) WHERE scanner_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_service_accounts_is_active ON service_accounts(is_active);
CREATE INDEX IF NOT EXISTS idx_service_accounts_service_category ON service_accounts(service_category);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_service_accounts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_service_accounts_updated_at ON service_accounts;
CREATE TRIGGER update_service_accounts_updated_at
    BEFORE UPDATE ON service_accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_service_accounts_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE service_accounts ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access service_accounts" ON service_accounts;
CREATE POLICY "Service role full access service_accounts"
ON service_accounts
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated users can read active service accounts
DROP POLICY IF EXISTS "Authenticated can read active service_accounts" ON service_accounts;
CREATE POLICY "Authenticated can read active service_accounts"
ON service_accounts
FOR SELECT
TO authenticated
USING (is_active = true);

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON service_accounts TO service_role;
GRANT SELECT ON service_accounts TO authenticated;
GRANT USAGE ON SEQUENCE service_accounts_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF SERVICE_ACCOUNTS SCHEMA
-- ============================================================================

