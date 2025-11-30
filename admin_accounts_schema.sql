-- =====================================================
-- ADMIN ACCOUNTS SCHEMA
-- =====================================================
-- Complete admin accounts system with authentication and permissions

-- =====================================================
-- 0. ENABLE EXTENSIONS
-- =====================================================
-- Enable pgcrypto extension for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- 1. DROP EXISTING TABLES AND FUNCTIONS (IF ANY)
-- =====================================================
DROP TABLE IF EXISTS admin_accounts CASCADE;
DROP FUNCTION IF EXISTS create_admin_account(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS authenticate_admin(VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS update_admin_password(VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS get_admin_by_username(VARCHAR);
DROP FUNCTION IF EXISTS get_all_admins();
DROP FUNCTION IF EXISTS update_admin_status(VARCHAR, BOOLEAN);
DROP FUNCTION IF EXISTS delete_admin_account(VARCHAR);

-- =====================================================
-- 2. CREATE ADMIN_ACCOUNTS TABLE
-- =====================================================
CREATE TABLE admin_accounts (
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
    notes TEXT
);

-- =====================================================
-- 3. CREATE INDEXES
-- =====================================================
CREATE INDEX idx_admin_accounts_username ON admin_accounts(username);
CREATE INDEX idx_admin_accounts_email ON admin_accounts(email);
CREATE INDEX idx_admin_accounts_role ON admin_accounts(role);
CREATE INDEX idx_admin_accounts_is_active ON admin_accounts(is_active);
CREATE INDEX idx_admin_accounts_last_login ON admin_accounts(last_login);

-- =====================================================
-- 4. CREATE TRIGGERS
-- =====================================================
-- Trigger to update updated_at column
CREATE OR REPLACE FUNCTION update_admin_accounts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_admin_accounts_updated_at
    BEFORE UPDATE ON admin_accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_admin_accounts_updated_at();

-- =====================================================
-- 5. CREATE FUNCTIONS
-- =====================================================

-- Function to create admin account
CREATE OR REPLACE FUNCTION create_admin_account(
    p_username VARCHAR(50),
    p_password VARCHAR(255),
    p_full_name VARCHAR(100),
    p_email VARCHAR(100),
    p_role VARCHAR(20) DEFAULT 'admin'
) RETURNS JSON AS $$
DECLARE
    admin_id INTEGER;
    result JSON;
BEGIN
    -- Check if username already exists
    IF EXISTS(SELECT 1 FROM admin_accounts WHERE username = p_username) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Username already exists'
        );
    END IF;
    
    -- Check if email already exists
    IF EXISTS(SELECT 1 FROM admin_accounts WHERE email = p_email) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Email already exists'
        );
    END IF;
    
    -- Insert new admin account with hashed password
    INSERT INTO admin_accounts (username, password_hash, full_name, email, role)
    VALUES (p_username, crypt(p_password, gen_salt('bf')), p_full_name, p_email, p_role)
    RETURNING id INTO admin_id;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Admin account created successfully',
        'admin_id', admin_id
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Error creating admin account: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to authenticate admin
CREATE OR REPLACE FUNCTION authenticate_admin(
    p_username VARCHAR(50),
    p_password VARCHAR(255)
) RETURNS JSON AS $$
DECLARE
    admin_record RECORD;
    result JSON;
BEGIN
    -- Get admin record
    SELECT id, username, password_hash, full_name, email, role, is_active, last_login
    INTO admin_record
    FROM admin_accounts
    WHERE username = p_username;
    
    -- Check if admin exists
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Invalid username or password'
        );
    END IF;
    
    -- Check if admin is active
    IF NOT admin_record.is_active THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Account is deactivated'
        );
    END IF;
    
    -- Check password using bcrypt
    IF NOT (admin_record.password_hash = crypt(p_password, admin_record.password_hash)) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Invalid username or password'
        );
    END IF;
    
    -- Update last login
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

-- Function to update admin password
CREATE OR REPLACE FUNCTION update_admin_password(
    p_username VARCHAR(50),
    p_old_password VARCHAR(255),
    p_new_password VARCHAR(255)
) RETURNS JSON AS $$
DECLARE
    admin_record RECORD;
    result JSON;
BEGIN
    -- Get admin record
    SELECT id, password_hash, is_active
    INTO admin_record
    FROM admin_accounts
    WHERE username = p_username;
    
    -- Check if admin exists
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Admin not found'
        );
    END IF;
    
    -- Check if admin is active
    IF NOT admin_record.is_active THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Account is deactivated'
        );
    END IF;
    
    -- Verify old password using bcrypt
    IF NOT (admin_record.password_hash = crypt(p_old_password, admin_record.password_hash)) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Current password is incorrect'
        );
    END IF;
    
    -- Update password with hash
    UPDATE admin_accounts 
    SET password_hash = crypt(p_new_password, gen_salt('bf')),
        updated_at = NOW()
    WHERE id = admin_record.id;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Password updated successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Error updating password: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get admin by username
CREATE OR REPLACE FUNCTION get_admin_by_username(
    p_username VARCHAR(50)
) RETURNS JSON AS $$
DECLARE
    admin_record RECORD;
    result JSON;
BEGIN
    SELECT id, username, full_name, email, role, is_active, last_login, created_at
    INTO admin_record
    FROM admin_accounts
    WHERE username = p_username;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Admin not found'
        );
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'admin_data', json_build_object(
            'id', admin_record.id,
            'username', admin_record.username,
            'full_name', admin_record.full_name,
            'email', admin_record.email,
            'role', admin_record.role,
            'is_active', admin_record.is_active,
            'last_login', admin_record.last_login,
            'created_at', admin_record.created_at
        )
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Error retrieving admin: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all admins
CREATE OR REPLACE FUNCTION get_all_admins()
RETURNS JSON AS $$
DECLARE
    admin_records RECORD;
    admins_array JSON[] := '{}';
    result JSON;
BEGIN
    FOR admin_records IN
        SELECT id, username, full_name, email, role, is_active, last_login, created_at
        FROM admin_accounts
        ORDER BY created_at DESC
    LOOP
        admins_array := array_append(admins_array, json_build_object(
            'id', admin_records.id,
            'username', admin_records.username,
            'full_name', admin_records.full_name,
            'email', admin_records.email,
            'role', admin_records.role,
            'is_active', admin_records.is_active,
            'last_login', admin_records.last_login,
            'created_at', admin_records.created_at
        ));
    END LOOP;
    
    RETURN json_build_object(
        'success', true,
        'admins', to_json(admins_array)
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Error retrieving admins: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update admin status
CREATE OR REPLACE FUNCTION update_admin_status(
    p_username VARCHAR(50),
    p_is_active BOOLEAN
) RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    UPDATE admin_accounts 
    SET is_active = p_is_active,
        updated_at = NOW()
    WHERE username = p_username;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Admin not found'
        );
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Admin status updated successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Error updating admin status: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to delete admin account
CREATE OR REPLACE FUNCTION delete_admin_account(
    p_username VARCHAR(50)
) RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    DELETE FROM admin_accounts WHERE username = p_username;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Admin not found'
        );
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Admin account deleted successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Error deleting admin account: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update admin credentials (for settings)
CREATE OR REPLACE FUNCTION update_admin_credentials(
    p_current_username VARCHAR(50),
    p_current_password VARCHAR(255),
    p_new_username VARCHAR(50),
    p_new_password VARCHAR(255),
    p_new_full_name VARCHAR(100),
    p_new_email VARCHAR(100)
) RETURNS JSON AS $$
DECLARE
    admin_record RECORD;
    result JSON;
BEGIN
    -- Get current admin record
    SELECT id, password_hash, is_active
    INTO admin_record
    FROM admin_accounts
    WHERE username = p_current_username;
    
    -- Check if admin exists
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Current admin not found'
        );
    END IF;
    
    -- Check if admin is active
    IF NOT admin_record.is_active THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Account is deactivated'
        );
    END IF;
    
    -- Verify current password using bcrypt
    IF NOT (admin_record.password_hash = crypt(p_current_password, admin_record.password_hash)) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Current password is incorrect'
        );
    END IF;
    
    -- Check if new username already exists (if different)
    IF p_new_username != p_current_username AND 
       EXISTS(SELECT 1 FROM admin_accounts WHERE username = p_new_username) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'New username already exists'
        );
    END IF;
    
    -- Check if new email already exists (if different)
    IF p_new_email != (SELECT email FROM admin_accounts WHERE id = admin_record.id) AND
       EXISTS(SELECT 1 FROM admin_accounts WHERE email = p_new_email) THEN
        RETURN json_build_object(
            'success', false,
            'message', 'New email already exists'
        );
    END IF;
    
    -- Update admin credentials with hashed password
    UPDATE admin_accounts 
    SET username = p_new_username,
        password_hash = crypt(p_new_password, gen_salt('bf')),
        full_name = p_new_full_name,
        email = p_new_email,
        updated_at = NOW()
    WHERE id = admin_record.id;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Admin credentials updated successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Error updating credentials: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 6. ROW LEVEL SECURITY
-- =====================================================
-- Enable RLS
ALTER TABLE admin_accounts ENABLE ROW LEVEL SECURITY;

-- Policy for service_role (full access)
CREATE POLICY admin_accounts_service_role_policy ON admin_accounts
    FOR ALL TO service_role
    USING (true)
    WITH CHECK (true);

-- Policy for authenticated users (read-only)
CREATE POLICY admin_accounts_authenticated_policy ON admin_accounts
    FOR SELECT TO authenticated
    USING (true);

-- Policy for anonymous users (no access)
CREATE POLICY admin_accounts_anon_policy ON admin_accounts
    FOR ALL TO anon
    USING (false);

-- =====================================================
-- 7. GRANT PERMISSIONS
-- =====================================================
-- Grant table permissions
GRANT ALL ON TABLE admin_accounts TO service_role;
GRANT SELECT ON TABLE admin_accounts TO authenticated;
GRANT USAGE ON SEQUENCE admin_accounts_id_seq TO service_role;
GRANT USAGE ON SEQUENCE admin_accounts_id_seq TO authenticated;

-- Grant function permissions
GRANT EXECUTE ON FUNCTION create_admin_account(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION create_admin_account(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION authenticate_admin(VARCHAR, VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION authenticate_admin(VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION update_admin_password(VARCHAR, VARCHAR, VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION update_admin_password(VARCHAR, VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_by_username(VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION get_admin_by_username(VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION get_all_admins() TO service_role;
GRANT EXECUTE ON FUNCTION get_all_admins() TO authenticated;
GRANT EXECUTE ON FUNCTION update_admin_status(VARCHAR, BOOLEAN) TO service_role;
GRANT EXECUTE ON FUNCTION update_admin_status(VARCHAR, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION update_admin_credentials(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION update_admin_credentials(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_admin_account(VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION delete_admin_account(VARCHAR) TO authenticated;

-- =====================================================
-- 8. INSERT DEFAULT ADMIN ACCOUNT
-- =====================================================
-- Insert default admin account with hashed password
INSERT INTO admin_accounts (username, password_hash, full_name, email, role, is_active, created_by)
VALUES (
    'Admin',
    crypt('Admin', gen_salt('bf')),  -- Hashed password using bcrypt
    'System Administrator',
    'admin@evsu.edu.ph',
    'admin',
    true,
    NULL
);

-- =====================================================
-- 9. COMMENTS
-- =====================================================
COMMENT ON TABLE admin_accounts IS 'Admin accounts table for system administrators and moderators';
COMMENT ON COLUMN admin_accounts.username IS 'Unique username for admin login';
COMMENT ON COLUMN admin_accounts.password_hash IS 'Hashed password for authentication';
COMMENT ON COLUMN admin_accounts.full_name IS 'Full name of the admin';
COMMENT ON COLUMN admin_accounts.email IS 'Email address of the admin';
COMMENT ON COLUMN admin_accounts.role IS 'Admin role: admin or moderator';
COMMENT ON COLUMN admin_accounts.is_active IS 'Whether the admin account is active';
COMMENT ON COLUMN admin_accounts.last_login IS 'Timestamp of last successful login';
COMMENT ON COLUMN admin_accounts.created_by IS 'ID of admin who created this account';

-- =====================================================
-- 10. VERIFICATION QUERIES
-- =====================================================
-- Test authentication (uncomment to test)
-- SELECT authenticate_admin('admin', 'admin123');

-- Get all admins
-- SELECT get_all_admins();

-- Get specific admin
-- SELECT get_admin_by_username('admin');
