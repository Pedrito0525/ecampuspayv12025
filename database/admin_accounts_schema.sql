-- ============================================================================
-- ADMIN_ACCOUNTS TABLE SCHEMA
-- ============================================================================
-- This file creates the admin_accounts table with authentication and permissions
-- ============================================================================

-- ============================================================================
-- 0. ENABLE EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- 1. CREATE ADMIN_ACCOUNTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS admin_accounts (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'admin' CHECK (role IN ('admin', 'moderator')),
    is_active BOOLEAN NOT NULL DEFAULT true,
    last_login TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by INTEGER REFERENCES admin_accounts(id),
    notes TEXT,
    scanner_id VARCHAR(100),
    supabase_uid UUID,
    email_verified BOOLEAN DEFAULT false,
    email_verified_at TIMESTAMP WITH TIME ZONE
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_admin_accounts_username ON admin_accounts(username);
CREATE INDEX IF NOT EXISTS idx_admin_accounts_email ON admin_accounts(email);
CREATE INDEX IF NOT EXISTS idx_admin_accounts_role ON admin_accounts(role);
CREATE INDEX IF NOT EXISTS idx_admin_accounts_is_active ON admin_accounts(is_active);
CREATE INDEX IF NOT EXISTS idx_admin_accounts_last_login ON admin_accounts(last_login);
CREATE INDEX IF NOT EXISTS idx_admin_accounts_supabase_uid ON admin_accounts(supabase_uid) WHERE supabase_uid IS NOT NULL;

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_admin_accounts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to authenticate admin
CREATE OR REPLACE FUNCTION authenticate_admin(
    p_username VARCHAR(50),
    p_password VARCHAR(255)
) RETURNS JSON AS $$
DECLARE
    admin_record RECORD;
BEGIN
    SELECT id, username, password_hash, full_name, email, role, is_active, last_login
    INTO admin_record
    FROM admin_accounts
    WHERE username = p_username;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Invalid username or password'
        );
    END IF;
    
    IF NOT admin_record.is_active THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Account is deactivated'
        );
    END IF;
    
    IF NOT (admin_record.password_hash = crypt(p_password, admin_record.password_hash)) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Invalid username or password'
        );
    END IF;
    
    UPDATE admin_accounts 
    SET last_login = NOW() 
    WHERE id = admin_record.id;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Authentication successful',
        'admin_data', json_build_object(
            'id', admin_record.id,
            'username', admin_record.username,
            'full_name', admin_record.full_name,
            'email', admin_record.email,
            'role', admin_record.role,
            'last_login', admin_record.last_login
        )
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Authentication error: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_admin_accounts_updated_at ON admin_accounts;
CREATE TRIGGER update_admin_accounts_updated_at
    BEFORE UPDATE ON admin_accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_admin_accounts_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE admin_accounts ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access admin_accounts" ON admin_accounts;
CREATE POLICY "Service role full access admin_accounts"
ON admin_accounts
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated users can read for authentication purposes
DROP POLICY IF EXISTS "Authenticated can read admin_accounts for auth" ON admin_accounts;
CREATE POLICY "Authenticated can read admin_accounts for auth"
ON admin_accounts
FOR SELECT
TO authenticated
USING (true);

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON admin_accounts TO service_role;
GRANT SELECT ON admin_accounts TO authenticated;
GRANT USAGE ON SEQUENCE admin_accounts_id_seq TO service_role;
GRANT EXECUTE ON FUNCTION authenticate_admin(VARCHAR, VARCHAR) TO authenticated, service_role;

-- ============================================================================
-- END OF ADMIN_ACCOUNTS SCHEMA
-- ============================================================================

