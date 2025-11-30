-- ============================================================================
-- COMPLETE DATABASE SCHEMA - ALL TABLES, FUNCTIONS, AND POLICIES
-- ============================================================================
-- This file contains all database schemas consolidated into one file
-- Generated: 2025-11-23 18:47:15
-- 
-- INSTRUCTIONS:
-- 1. Copy this entire file
-- 2. Paste into Supabase SQL Editor
-- 3. Run the script
-- 4. All tables, functions, triggers, and policies will be created
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- ============================================================================
-- FILE: system_update_settings_schema.sql
-- ============================================================================

-- ============================================================================
-- SYSTEM_UPDATE_SETTINGS TABLE SCHEMA
-- ============================================================================
-- This file creates the system_update_settings table for managing app updates
-- and maintenance modes
-- ============================================================================

-- ============================================================================
-- 1. CREATE SYSTEM_UPDATE_SETTINGS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS system_update_settings (
    id INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1), -- Singleton table
    maintenance_mode BOOLEAN NOT NULL DEFAULT false,
    force_update_mode BOOLEAN NOT NULL DEFAULT false,
    disable_all_logins BOOLEAN NOT NULL DEFAULT false,
    updated_by TEXT,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_system_update_settings_id ON system_update_settings(id);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to get system update settings
CREATE OR REPLACE FUNCTION get_system_update_settings()
RETURNS JSON AS $$
DECLARE
    settings RECORD;
BEGIN
    SELECT * INTO settings
    FROM system_update_settings
    WHERE id = 1;
    
    IF NOT FOUND THEN
        -- Insert default settings if not exists
        INSERT INTO system_update_settings (id, maintenance_mode, force_update_mode, disable_all_logins)
        VALUES (1, false, false, false)
        RETURNING * INTO settings;
    END IF;
    
    RETURN json_build_object(
        'id', settings.id,
        'maintenance_mode', settings.maintenance_mode,
        'force_update_mode', settings.force_update_mode,
        'disable_all_logins', settings.disable_all_logins,
        'updated_by', settings.updated_by,
        'updated_at', settings.updated_at
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update system update settings
CREATE OR REPLACE FUNCTION update_system_update_settings(
    p_maintenance_mode BOOLEAN DEFAULT NULL,
    p_force_update_mode BOOLEAN DEFAULT NULL,
    p_disable_all_logins BOOLEAN DEFAULT NULL,
    p_updated_by TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    updated_settings RECORD;
BEGIN
    -- Ensure row exists
    INSERT INTO system_update_settings (id, maintenance_mode, force_update_mode, disable_all_logins, updated_by)
    VALUES (1, 
        COALESCE(p_maintenance_mode, false),
        COALESCE(p_force_update_mode, false),
        COALESCE(p_disable_all_logins, false),
        p_updated_by
    )
    ON CONFLICT (id) DO UPDATE
    SET
        maintenance_mode = COALESCE(p_maintenance_mode, system_update_settings.maintenance_mode),
        force_update_mode = COALESCE(p_force_update_mode, system_update_settings.force_update_mode),
        disable_all_logins = COALESCE(p_disable_all_logins, system_update_settings.disable_all_logins),
        updated_by = COALESCE(p_updated_by, system_update_settings.updated_by),
        updated_at = NOW()
    RETURNING * INTO updated_settings;
    
    RETURN json_build_object(
        'success', true,
        'message', 'System settings updated successfully',
        'data', json_build_object(
            'id', updated_settings.id,
            'maintenance_mode', updated_settings.maintenance_mode,
            'force_update_mode', updated_settings.force_update_mode,
            'disable_all_logins', updated_settings.disable_all_logins,
            'updated_by', updated_settings.updated_by,
            'updated_at', updated_settings.updated_at
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. ENABLE RLS
-- ============================================================================
ALTER TABLE system_update_settings ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 5. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access system_update_settings" ON system_update_settings;
CREATE POLICY "Service role full access system_update_settings"
ON system_update_settings
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated users can read
DROP POLICY IF EXISTS "Authenticated can read system_update_settings" ON system_update_settings;
CREATE POLICY "Authenticated can read system_update_settings"
ON system_update_settings
FOR SELECT
TO authenticated
USING (true);

-- ============================================================================
-- 6. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON system_update_settings TO service_role;
GRANT SELECT ON system_update_settings TO authenticated;
GRANT EXECUTE ON FUNCTION get_system_update_settings() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_system_update_settings(BOOLEAN, BOOLEAN, BOOLEAN, TEXT) TO service_role;

-- ============================================================================
-- 7. INITIALIZE DEFAULT SETTINGS
-- ============================================================================
INSERT INTO system_update_settings (id, maintenance_mode, force_update_mode, disable_all_logins)
VALUES (1, false, false, false)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- END OF SYSTEM_UPDATE_SETTINGS SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: admin_accounts_schema.sql
-- ============================================================================

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





-- ============================================================================
-- FILE: admin_activity_log_schema.sql
-- ============================================================================

-- ============================================================================
-- ADMIN_ACTIVITY_LOG TABLE SCHEMA
-- ============================================================================
-- This file creates the admin_activity_log table for tracking admin actions
-- ============================================================================

-- ============================================================================
-- 1. CREATE ADMIN_ACTIVITY_LOG TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS admin_activity_log (
    id BIGSERIAL PRIMARY KEY,
    admin_username VARCHAR(50) NOT NULL,
    action TEXT NOT NULL,
    description TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_admin_username ON admin_activity_log(admin_username);
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_timestamp ON admin_activity_log(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_action ON admin_activity_log(action);
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_created_at ON admin_activity_log(created_at DESC);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to log admin activity
CREATE OR REPLACE FUNCTION log_admin_activity(
    p_admin_username VARCHAR(50),
    p_action TEXT,
    p_description TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    log_id BIGINT;
BEGIN
    INSERT INTO admin_activity_log (admin_username, action, description)
    VALUES (p_admin_username, p_action, p_description)
    RETURNING id INTO log_id;
    
    RETURN json_build_object(
        'success', true,
        'log_id', log_id,
        'message', 'Activity logged successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Failed to log activity: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get admin activity logs (paginated)
CREATE OR REPLACE FUNCTION get_admin_activity_logs(
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0,
    p_admin_username VARCHAR(50) DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    logs JSON;
    total_count INTEGER;
BEGIN
    -- Get total count
    IF p_admin_username IS NULL THEN
        SELECT COUNT(*) INTO total_count FROM admin_activity_log;
    ELSE
        SELECT COUNT(*) INTO total_count
        FROM admin_activity_log
        WHERE admin_username = p_admin_username;
    END IF;
    
    -- Get paginated results
    IF p_admin_username IS NULL THEN
        SELECT json_agg(
            json_build_object(
                'id', id,
                'admin_username', admin_username,
                'action', action,
                'description', description,
                'timestamp', timestamp,
                'created_at', created_at
            )
        ) INTO logs
        FROM admin_activity_log
        ORDER BY timestamp DESC
        LIMIT p_limit
        OFFSET p_offset;
    ELSE
        SELECT json_agg(
            json_build_object(
                'id', id,
                'admin_username', admin_username,
                'action', action,
                'description', description,
                'timestamp', timestamp,
                'created_at', created_at
            )
        ) INTO logs
        FROM admin_activity_log
        WHERE admin_username = p_admin_username
        ORDER BY timestamp DESC
        LIMIT p_limit
        OFFSET p_offset;
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'data', COALESCE(logs, '[]'::json),
        'total', total_count,
        'limit', p_limit,
        'offset', p_offset
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. ENABLE RLS
-- ============================================================================
ALTER TABLE admin_activity_log ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 5. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access admin_activity_log" ON admin_activity_log;
CREATE POLICY "Service role full access admin_activity_log"
ON admin_activity_log
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated users can read (for admin dashboard)
DROP POLICY IF EXISTS "Authenticated can read admin_activity_log" ON admin_activity_log;
CREATE POLICY "Authenticated can read admin_activity_log"
ON admin_activity_log
FOR SELECT
TO authenticated
USING (true);

-- ============================================================================
-- 6. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON admin_activity_log TO service_role;
GRANT SELECT ON admin_activity_log TO authenticated;
GRANT INSERT ON admin_activity_log TO authenticated;
GRANT USAGE ON SEQUENCE admin_activity_log_id_seq TO service_role, authenticated;
GRANT EXECUTE ON FUNCTION log_admin_activity(VARCHAR, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_admin_activity_logs(INTEGER, INTEGER, VARCHAR) TO authenticated, service_role;

-- ============================================================================
-- END OF ADMIN_ACTIVITY_LOG SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: student_info_schema.sql
-- ============================================================================

-- ============================================================================
-- STUDENT_INFO TABLE SCHEMA
-- ============================================================================
-- This file creates the student_info table with all necessary components:
-- - Table structure with constraints
-- - Indexes for performance
-- - Functions for common operations
-- - Row Level Security (RLS) policies
-- - Triggers for automatic updates
-- ============================================================================
-- NOTE: student_info is used for CSV import and autofill during registration
-- It contains unencrypted data for quick lookup
-- ============================================================================

-- ============================================================================
-- 1. DROP EXISTING OBJECTS (IF NEEDED)
-- ============================================================================
-- Uncomment these if you need to recreate everything from scratch
-- DROP TRIGGER IF EXISTS update_student_info_updated_at ON student_info;
-- DROP FUNCTION IF EXISTS update_student_info_updated_at();
-- DROP POLICY IF EXISTS "Service role can manage student_info" ON student_info;
-- DROP POLICY IF EXISTS "Allow all operations on student_info" ON student_info;
-- DROP TABLE IF EXISTS student_info CASCADE;

-- ============================================================================
-- 2. CREATE STUDENT_INFO TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS student_info (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    course VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT student_info_student_id_unique UNIQUE (student_id),
    CONSTRAINT student_info_email_unique UNIQUE (email),
    CONSTRAINT student_info_email_format CHECK (email ~* '^[a-zA-Z0-9._%+-]+@evsu\.edu\.ph$')
);

-- ============================================================================
-- 3. CREATE INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_student_info_student_id ON student_info(student_id);
CREATE INDEX IF NOT EXISTS idx_student_info_email ON student_info(email);
CREATE INDEX IF NOT EXISTS idx_student_info_course ON student_info(course);
CREATE INDEX IF NOT EXISTS idx_student_info_created_at ON student_info(created_at);
CREATE INDEX IF NOT EXISTS idx_student_info_updated_at ON student_info(updated_at);

-- ============================================================================
-- 4. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp automatically
CREATE OR REPLACE FUNCTION update_student_info_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to search student info by student_id
CREATE OR REPLACE FUNCTION search_student_info(p_student_id VARCHAR(50))
RETURNS JSON AS $$
DECLARE
    student_record RECORD;
BEGIN
    SELECT 
        id,
        student_id,
        name,
        email,
        course,
        created_at,
        updated_at
    INTO student_record
    FROM student_info
    WHERE student_id = p_student_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Student info not found'
        );
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'data', json_build_object(
            'id', student_record.id,
            'student_id', student_record.student_id,
            'name', student_record.name,
            'email', student_record.email,
            'course', student_record.course,
            'created_at', student_record.created_at,
            'updated_at', student_record.updated_at
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search student info by email
CREATE OR REPLACE FUNCTION search_student_info_by_email(p_email VARCHAR(255))
RETURNS JSON AS $$
DECLARE
    student_record RECORD;
BEGIN
    SELECT 
        id,
        student_id,
        name,
        email,
        course,
        created_at,
        updated_at
    INTO student_record
    FROM student_info
    WHERE email = p_email;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Student info not found'
        );
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'data', json_build_object(
            'id', student_record.id,
            'student_id', student_record.student_id,
            'name', student_record.name,
            'email', student_record.email,
            'course', student_record.course,
            'created_at', student_record.created_at,
            'updated_at', student_record.updated_at
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to bulk insert student info (for CSV import)
CREATE OR REPLACE FUNCTION bulk_insert_student_info(
    p_students JSON
)
RETURNS JSON AS $$
DECLARE
    student_item JSON;
    inserted_count INTEGER := 0;
    skipped_count INTEGER := 0;
    error_count INTEGER := 0;
    errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Loop through each student in the JSON array
    FOR student_item IN SELECT * FROM json_array_elements(p_students)
    LOOP
        BEGIN
            INSERT INTO student_info (student_id, name, email, course)
            VALUES (
                student_item->>'student_id',
                student_item->>'name',
                student_item->>'email',
                student_item->>'course'
            )
            ON CONFLICT (student_id) DO UPDATE
            SET
                name = EXCLUDED.name,
                email = EXCLUDED.email,
                course = EXCLUDED.course,
                updated_at = NOW();
            
            inserted_count := inserted_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                error_count := error_count + 1;
                errors := array_append(
                    errors,
                    format('Student ID %s: %s', 
                        COALESCE(student_item->>'student_id', 'unknown'),
                        SQLERRM
                    )
                );
        END;
    END LOOP;
    
    RETURN json_build_object(
        'success', true,
        'inserted', inserted_count,
        'skipped', skipped_count,
        'errors', error_count,
        'error_messages', errors
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all student info (paginated)
CREATE OR REPLACE FUNCTION get_all_student_info(
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0,
    p_search_term VARCHAR(255) DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    students JSON;
    total_count INTEGER;
BEGIN
    -- Get total count
    IF p_search_term IS NULL THEN
        SELECT COUNT(*) INTO total_count FROM student_info;
    ELSE
        SELECT COUNT(*) INTO total_count
        FROM student_info
        WHERE 
            student_id ILIKE '%' || p_search_term || '%'
            OR name ILIKE '%' || p_search_term || '%'
            OR email ILIKE '%' || p_search_term || '%'
            OR course ILIKE '%' || p_search_term || '%';
    END IF;
    
    -- Get paginated results
    IF p_search_term IS NULL THEN
        SELECT json_agg(
            json_build_object(
                'id', id,
                'student_id', student_id,
                'name', name,
                'email', email,
                'course', course,
                'created_at', created_at,
                'updated_at', updated_at
            )
        ) INTO students
        FROM student_info
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset;
    ELSE
        SELECT json_agg(
            json_build_object(
                'id', id,
                'student_id', student_id,
                'name', name,
                'email', email,
                'course', course,
                'created_at', created_at,
                'updated_at', updated_at
            )
        ) INTO students
        FROM student_info
        WHERE 
            student_id ILIKE '%' || p_search_term || '%'
            OR name ILIKE '%' || p_search_term || '%'
            OR email ILIKE '%' || p_search_term || '%'
            OR course ILIKE '%' || p_search_term || '%'
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset;
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'data', COALESCE(students, '[]'::json),
        'total', total_count,
        'limit', p_limit,
        'offset', p_offset
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 5. CREATE TRIGGERS
-- ============================================================================

-- Trigger to automatically update updated_at timestamp
CREATE TRIGGER update_student_info_updated_at
    BEFORE UPDATE ON student_info
    FOR EACH ROW
    EXECUTE FUNCTION update_student_info_updated_at();

-- ============================================================================
-- 6. ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================================================
ALTER TABLE student_info ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 7. CREATE RLS POLICIES
-- ============================================================================

-- Policy: Service role has full access
DROP POLICY IF EXISTS "Service role can manage student_info" ON student_info;
CREATE POLICY "Service role can manage student_info"
ON student_info
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy: Allow authenticated users to read (for autofill during registration)
DROP POLICY IF EXISTS "Allow authenticated read on student_info" ON student_info;
CREATE POLICY "Allow authenticated read on student_info"
ON student_info
FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert (for CSV import)
DROP POLICY IF EXISTS "Allow authenticated insert on student_info" ON student_info;
CREATE POLICY "Allow authenticated insert on student_info"
ON student_info
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update (for data updates)
DROP POLICY IF EXISTS "Allow authenticated update on student_info" ON student_info;
CREATE POLICY "Allow authenticated update on student_info"
ON student_info
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- ============================================================================
-- 8. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON student_info TO service_role;
GRANT SELECT, INSERT, UPDATE ON student_info TO authenticated;
GRANT USAGE ON SEQUENCE student_info_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF STUDENT_INFO SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: auth_students_schema.sql
-- ============================================================================

-- ============================================================================
-- AUTH_STUDENTS TABLE SCHEMA
-- ============================================================================
-- This file creates the auth_students table with all necessary components:
-- - Table structure with constraints
-- - Indexes for performance
-- - Functions for common operations
-- - Row Level Security (RLS) policies
-- - Triggers for automatic updates
-- ============================================================================

-- ============================================================================
-- 1. DROP EXISTING OBJECTS (IF NEEDED)
-- ============================================================================
-- Uncomment these if you need to recreate everything from scratch
-- DROP TRIGGER IF EXISTS update_auth_students_updated_at ON auth_students;
-- DROP FUNCTION IF EXISTS update_auth_students_updated_at();
-- DROP POLICY IF EXISTS "Service role can do everything on auth_students" ON auth_students;
-- DROP POLICY IF EXISTS "Students can view own data" ON auth_students;
-- DROP POLICY IF EXISTS "Students can update own data" ON auth_students;
-- DROP POLICY IF EXISTS "Allow authenticated insert for registration" ON auth_students;
-- DROP TABLE IF EXISTS auth_students CASCADE;

-- ============================================================================
-- 2. CREATE AUTH_STUDENTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS auth_students (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) UNIQUE NOT NULL,
    name TEXT NOT NULL, -- Encrypted data (can be longer)
    email TEXT UNIQUE NOT NULL, -- Encrypted data (can be longer)
    course TEXT NOT NULL, -- Encrypted data (can be longer)
    rfid_id TEXT UNIQUE, -- Encrypted data (can be longer)
    password TEXT NOT NULL, -- Hashed password (SHA-256 with salt)
    auth_user_id UUID, -- References auth.users(id) but no FK constraint to avoid circular dependencies
    balance DECIMAL(10,2) DEFAULT 0.00 CHECK (balance >= 0),
    is_active BOOLEAN DEFAULT true,
    taptopay BOOLEAN DEFAULT true, -- Enable/disable tap to pay functionality
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT auth_students_student_id_unique UNIQUE (student_id),
    CONSTRAINT auth_students_email_unique UNIQUE (email),
    CONSTRAINT auth_students_rfid_id_unique UNIQUE (rfid_id),
    CONSTRAINT auth_students_balance_non_negative CHECK (balance >= 0)
);

-- ============================================================================
-- 3. CREATE INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_auth_students_student_id ON auth_students(student_id);
CREATE INDEX IF NOT EXISTS idx_auth_students_email ON auth_students(email);
CREATE INDEX IF NOT EXISTS idx_auth_students_rfid_id ON auth_students(rfid_id) WHERE rfid_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_auth_students_auth_user_id ON auth_students(auth_user_id) WHERE auth_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_auth_students_is_active ON auth_students(is_active);
CREATE INDEX IF NOT EXISTS idx_auth_students_taptopay ON auth_students(taptopay);
CREATE INDEX IF NOT EXISTS idx_auth_students_created_at ON auth_students(created_at);
CREATE INDEX IF NOT EXISTS idx_auth_students_updated_at ON auth_students(updated_at);

-- ============================================================================
-- 4. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp automatically
CREATE OR REPLACE FUNCTION update_auth_students_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to get student balance
CREATE OR REPLACE FUNCTION get_student_balance(p_student_id VARCHAR(50))
RETURNS DECIMAL(10,2) AS $$
DECLARE
    student_balance DECIMAL(10,2);
BEGIN
    SELECT balance INTO student_balance
    FROM auth_students
    WHERE student_id = p_student_id AND is_active = true;
    
    RETURN COALESCE(student_balance, 0.00);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update student balance (with validation)
CREATE OR REPLACE FUNCTION update_student_balance(
    p_student_id VARCHAR(50),
    p_amount DECIMAL(10,2)
)
RETURNS JSON AS $$
DECLARE
    current_balance DECIMAL(10,2);
    new_balance DECIMAL(10,2);
BEGIN
    -- Get current balance
    SELECT balance INTO current_balance
    FROM auth_students
    WHERE student_id = p_student_id AND is_active = true;
    
    IF current_balance IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Student not found or inactive'
        );
    END IF;
    
    -- Calculate new balance
    new_balance := current_balance + p_amount;
    
    -- Check if balance would be negative
    IF new_balance < 0 THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Insufficient balance',
            'current_balance', current_balance,
            'requested_amount', p_amount
        );
    END IF;
    
    -- Update balance
    UPDATE auth_students
    SET balance = new_balance,
        updated_at = NOW()
    WHERE student_id = p_student_id;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Balance updated successfully',
        'previous_balance', current_balance,
        'new_balance', new_balance,
        'amount_changed', p_amount
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if student exists and is active
CREATE OR REPLACE FUNCTION check_student_active(p_student_id VARCHAR(50))
RETURNS BOOLEAN AS $$
DECLARE
    is_student_active BOOLEAN;
BEGIN
    SELECT is_active INTO is_student_active
    FROM auth_students
    WHERE student_id = p_student_id;
    
    RETURN COALESCE(is_student_active, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get student info by student_id (for admin use)
CREATE OR REPLACE FUNCTION get_student_info(p_student_id VARCHAR(50))
RETURNS JSON AS $$
DECLARE
    student_record RECORD;
BEGIN
    SELECT 
        id,
        student_id,
        name,
        email,
        course,
        rfid_id,
        balance,
        is_active,
        taptopay,
        created_at,
        updated_at
    INTO student_record
    FROM auth_students
    WHERE student_id = p_student_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Student not found'
        );
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'data', json_build_object(
            'id', student_record.id,
            'student_id', student_record.student_id,
            'name', student_record.name,
            'email', student_record.email,
            'course', student_record.course,
            'rfid_id', student_record.rfid_id,
            'balance', student_record.balance,
            'is_active', student_record.is_active,
            'taptopay', student_record.taptopay,
            'created_at', student_record.created_at,
            'updated_at', student_record.updated_at
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 5. CREATE TRIGGERS
-- ============================================================================

-- Trigger to automatically update updated_at timestamp
CREATE TRIGGER update_auth_students_updated_at
    BEFORE UPDATE ON auth_students
    FOR EACH ROW
    EXECUTE FUNCTION update_auth_students_updated_at();

-- ============================================================================
-- 6. ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================================================
ALTER TABLE auth_students ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 7. CREATE RLS POLICIES
-- ============================================================================

-- Policy: Service role has full access
DROP POLICY IF EXISTS "Service role can do everything on auth_students" ON auth_students;
CREATE POLICY "Service role can do everything on auth_students"
ON auth_students
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy: Students can view their own data
DROP POLICY IF EXISTS "Students can view own data" ON auth_students;
CREATE POLICY "Students can view own data"
ON auth_students
FOR SELECT
TO authenticated
USING (auth_user_id = auth.uid());

-- Policy: Students can update their own data (limited fields)
-- Note: In practice, students should only update via service role functions
-- This policy allows minimal updates but prevents critical field changes
DROP POLICY IF EXISTS "Students can update own data" ON auth_students;
CREATE POLICY "Students can update own data"
ON auth_students
FOR UPDATE
TO authenticated
USING (auth_user_id = auth.uid())
WITH CHECK (
    auth_user_id = auth.uid()
    -- Ensure critical fields remain unchanged
    AND NEW.student_id = OLD.student_id
    AND NEW.email = OLD.email
    AND NEW.password = OLD.password
    AND NEW.balance = OLD.balance
);

-- Policy: Allow authenticated users to insert (for registration)
DROP POLICY IF EXISTS "Allow authenticated insert for registration" ON auth_students;
CREATE POLICY "Allow authenticated insert for registration"
ON auth_students
FOR INSERT
TO authenticated
WITH CHECK (true);

-- ============================================================================
-- 8. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON auth_students TO service_role;
GRANT SELECT, INSERT, UPDATE ON auth_students TO authenticated;
GRANT USAGE ON SEQUENCE auth_students_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF AUTH_STUDENTS SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: service_accounts_schema.sql
-- ============================================================================

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





-- ============================================================================
-- FILE: payment_items_schema.sql
-- ============================================================================

-- ============================================================================
-- PAYMENT_ITEMS TABLE SCHEMA
-- ============================================================================
-- This file creates the payment_items table for catalog of sellable items
-- ============================================================================

-- ============================================================================
-- 1. CREATE PAYMENT_ITEMS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS payment_items (
    id BIGSERIAL PRIMARY KEY,
    service_account_id BIGINT NOT NULL REFERENCES service_accounts(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    base_price DECIMAL(12,2) NOT NULL CHECK (base_price >= 0),
    has_sizes BOOLEAN NOT NULL DEFAULT false,
    size_options JSONB,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_payment_items_service_account_id ON payment_items(service_account_id);
CREATE INDEX IF NOT EXISTS idx_payment_items_is_active ON payment_items(is_active);
CREATE INDEX IF NOT EXISTS idx_payment_items_category ON payment_items(category);
CREATE INDEX IF NOT EXISTS idx_payment_items_created_at ON payment_items(created_at DESC);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_payment_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_payment_items_updated_at ON payment_items;
CREATE TRIGGER update_payment_items_updated_at
    BEFORE UPDATE ON payment_items
    FOR EACH ROW
    EXECUTE FUNCTION update_payment_items_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE payment_items ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access payment_items" ON payment_items;
CREATE POLICY "Service role full access payment_items"
ON payment_items
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated users can read active items
DROP POLICY IF EXISTS "Authenticated can read active payment_items" ON payment_items;
CREATE POLICY "Authenticated can read active payment_items"
ON payment_items
FOR SELECT
TO authenticated
USING (is_active = true);

-- Authenticated users can manage items (for service accounts)
DROP POLICY IF EXISTS "Authenticated can manage payment_items" ON payment_items;
CREATE POLICY "Authenticated can manage payment_items"
ON payment_items
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON payment_items TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON payment_items TO authenticated;
GRANT USAGE ON SEQUENCE payment_items_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF PAYMENT_ITEMS SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: service_transactions_schema.sql
-- ============================================================================

-- ============================================================================
-- SERVICE_TRANSACTIONS TABLE SCHEMA
-- ============================================================================
-- This file creates the service_transactions table for recording service sales
-- ============================================================================

-- ============================================================================
-- 1. CREATE SERVICE_TRANSACTIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS service_transactions (
    id BIGSERIAL PRIMARY KEY,
    service_account_id BIGINT NOT NULL REFERENCES service_accounts(id) ON DELETE RESTRICT,
    main_service_id BIGINT REFERENCES service_accounts(id) ON DELETE SET NULL,
    student_id VARCHAR(50) REFERENCES auth_students(student_id),
    items JSONB NOT NULL,
    total_amount DECIMAL(14,2) NOT NULL CHECK (total_amount >= 0),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_service_transactions_service_account_id ON service_transactions(service_account_id);
CREATE INDEX IF NOT EXISTS idx_service_transactions_main_service_id ON service_transactions(main_service_id);
CREATE INDEX IF NOT EXISTS idx_service_transactions_student_id ON service_transactions(student_id) WHERE student_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_service_transactions_created_at ON service_transactions(created_at DESC);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to get service transactions (paginated)
CREATE OR REPLACE FUNCTION get_service_transactions(
    p_service_account_id BIGINT DEFAULT NULL,
    p_student_id VARCHAR(50) DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON AS $$
DECLARE
    transactions JSON;
    total_count INTEGER;
BEGIN
    -- Build dynamic query based on filters
    IF p_service_account_id IS NOT NULL AND p_student_id IS NOT NULL THEN
        SELECT COUNT(*) INTO total_count
        FROM service_transactions
        WHERE service_account_id = p_service_account_id AND student_id = p_student_id;
        
        SELECT json_agg(
            json_build_object(
                'id', id,
                'service_account_id', service_account_id,
                'main_service_id', main_service_id,
                'student_id', student_id,
                'items', items,
                'total_amount', total_amount,
                'metadata', metadata,
                'created_at', created_at
            )
        ) INTO transactions
        FROM service_transactions
        WHERE service_account_id = p_service_account_id AND student_id = p_student_id
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset;
    ELSIF p_service_account_id IS NOT NULL THEN
        SELECT COUNT(*) INTO total_count
        FROM service_transactions
        WHERE service_account_id = p_service_account_id;
        
        SELECT json_agg(
            json_build_object(
                'id', id,
                'service_account_id', service_account_id,
                'main_service_id', main_service_id,
                'student_id', student_id,
                'items', items,
                'total_amount', total_amount,
                'metadata', metadata,
                'created_at', created_at
            )
        ) INTO transactions
        FROM service_transactions
        WHERE service_account_id = p_service_account_id
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset;
    ELSIF p_student_id IS NOT NULL THEN
        SELECT COUNT(*) INTO total_count
        FROM service_transactions
        WHERE student_id = p_student_id;
        
        SELECT json_agg(
            json_build_object(
                'id', id,
                'service_account_id', service_account_id,
                'main_service_id', main_service_id,
                'student_id', student_id,
                'items', items,
                'total_amount', total_amount,
                'metadata', metadata,
                'created_at', created_at
            )
        ) INTO transactions
        FROM service_transactions
        WHERE student_id = p_student_id
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset;
    ELSE
        SELECT COUNT(*) INTO total_count FROM service_transactions;
        
        SELECT json_agg(
            json_build_object(
                'id', id,
                'service_account_id', service_account_id,
                'main_service_id', main_service_id,
                'student_id', student_id,
                'items', items,
                'total_amount', total_amount,
                'metadata', metadata,
                'created_at', created_at
            )
        ) INTO transactions
        FROM service_transactions
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset;
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'data', COALESCE(transactions, '[]'::json),
        'total', total_count,
        'limit', p_limit,
        'offset', p_offset
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. ENABLE RLS
-- ============================================================================
ALTER TABLE service_transactions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 5. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access service_transactions" ON service_transactions;
CREATE POLICY "Service role full access service_transactions"
ON service_transactions
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated users can insert transactions
DROP POLICY IF EXISTS "Authenticated can insert service_transactions" ON service_transactions;
CREATE POLICY "Authenticated can insert service_transactions"
ON service_transactions
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Authenticated users can read transactions
DROP POLICY IF EXISTS "Authenticated can read service_transactions" ON service_transactions;
CREATE POLICY "Authenticated can read service_transactions"
ON service_transactions
FOR SELECT
TO authenticated
USING (true);

-- ============================================================================
-- 6. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON service_transactions TO service_role;
GRANT SELECT, INSERT ON service_transactions TO authenticated;
GRANT USAGE ON SEQUENCE service_transactions_id_seq TO service_role, authenticated;
GRANT EXECUTE ON FUNCTION get_service_transactions(BIGINT, VARCHAR, INTEGER, INTEGER) TO authenticated, service_role;

-- ============================================================================
-- END OF SERVICE_TRANSACTIONS SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: loan_plans_schema.sql
-- ============================================================================

-- ============================================================================
-- LOAN_PLANS TABLE SCHEMA
-- ============================================================================
-- This file creates the loan_plans table for admin-defined loan products
-- ============================================================================

-- ============================================================================
-- 1. CREATE LOAN_PLANS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS loan_plans (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    term_days INTEGER NOT NULL CHECK (term_days > 0),
    interest_rate DECIMAL(5,2) NOT NULL CHECK (interest_rate >= 0),
    penalty_rate DECIMAL(5,2) NOT NULL CHECK (penalty_rate >= 0),
    min_topup DECIMAL(10,2) NOT NULL CHECK (min_topup >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_loan_plans_status ON loan_plans(status);
CREATE INDEX IF NOT EXISTS idx_loan_plans_created_at ON loan_plans(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_loan_plans_name ON loan_plans(name);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_loan_plans_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_loan_plans_updated_at ON loan_plans;
CREATE TRIGGER update_loan_plans_updated_at
    BEFORE UPDATE ON loan_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_loan_plans_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE loan_plans ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access loan_plans" ON loan_plans;
CREATE POLICY "Service role full access loan_plans"
ON loan_plans
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated users can read active loan plans
DROP POLICY IF EXISTS "Authenticated can read active loan_plans" ON loan_plans;
CREATE POLICY "Authenticated can read active loan_plans"
ON loan_plans
FOR SELECT
TO authenticated
USING (status = 'active');

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON loan_plans TO service_role;
GRANT SELECT ON loan_plans TO authenticated;
GRANT USAGE ON SEQUENCE loan_plans_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF LOAN_PLANS SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: active_loans_schema.sql
-- ============================================================================

-- ============================================================================
-- ACTIVE_LOANS TABLE SCHEMA
-- ============================================================================
-- This file creates the active_loans table for student loan applications
-- ============================================================================

-- ============================================================================
-- 1. CREATE ACTIVE_LOANS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS active_loans (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL REFERENCES auth_students(student_id),
    loan_plan_id INTEGER NOT NULL REFERENCES loan_plans(id),
    loan_amount DECIMAL(10,2) NOT NULL CHECK (loan_amount > 0),
    interest_amount DECIMAL(10,2) NOT NULL CHECK (interest_amount >= 0),
    penalty_amount DECIMAL(10,2) DEFAULT 0 CHECK (penalty_amount >= 0),
    total_amount DECIMAL(10,2) NOT NULL CHECK (total_amount > 0),
    term_days INTEGER NOT NULL CHECK (term_days > 0),
    due_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paid', 'overdue')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    paid_at TIMESTAMP WITH TIME ZONE
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_active_loans_student_id ON active_loans(student_id);
CREATE INDEX IF NOT EXISTS idx_active_loans_status ON active_loans(status);
CREATE INDEX IF NOT EXISTS idx_active_loans_due_date ON active_loans(due_date);
CREATE INDEX IF NOT EXISTS idx_active_loans_loan_plan_id ON active_loans(loan_plan_id);
CREATE INDEX IF NOT EXISTS idx_active_loans_created_at ON active_loans(created_at DESC);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_active_loans_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_active_loans_updated_at ON active_loans;
CREATE TRIGGER update_active_loans_updated_at
    BEFORE UPDATE ON active_loans
    FOR EACH ROW
    EXECUTE FUNCTION update_active_loans_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE active_loans ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access active_loans" ON active_loans;
CREATE POLICY "Service role full access active_loans"
ON active_loans
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Students can read their own loans
DROP POLICY IF EXISTS "Students can read own active_loans" ON active_loans;
CREATE POLICY "Students can read own active_loans"
ON active_loans
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE auth_students.student_id = active_loans.student_id
        AND auth_students.auth_user_id = auth.uid()
    )
);

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON active_loans TO service_role;
GRANT SELECT ON active_loans TO authenticated;
GRANT INSERT ON active_loans TO authenticated;
GRANT USAGE ON SEQUENCE active_loans_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF ACTIVE_LOANS SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: loan_payments_schema.sql
-- ============================================================================

-- ============================================================================
-- LOAN_PAYMENTS TABLE SCHEMA
-- ============================================================================
-- This file creates the loan_payments table for tracking loan payments
-- ============================================================================

-- ============================================================================
-- 1. CREATE LOAN_PAYMENTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS loan_payments (
    id SERIAL PRIMARY KEY,
    loan_id INTEGER NOT NULL REFERENCES active_loans(id),
    student_id VARCHAR(50) NOT NULL REFERENCES auth_students(student_id),
    payment_amount DECIMAL(10,2) NOT NULL CHECK (payment_amount > 0),
    payment_type VARCHAR(20) NOT NULL DEFAULT 'full' CHECK (payment_type IN ('full', 'partial')),
    remaining_balance DECIMAL(10,2) NOT NULL CHECK (remaining_balance >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_loan_payments_loan_id ON loan_payments(loan_id);
CREATE INDEX IF NOT EXISTS idx_loan_payments_student_id ON loan_payments(student_id);
CREATE INDEX IF NOT EXISTS idx_loan_payments_created_at ON loan_payments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_loan_payments_payment_type ON loan_payments(payment_type);

-- ============================================================================
-- 3. ENABLE RLS
-- ============================================================================
ALTER TABLE loan_payments ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 4. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access loan_payments" ON loan_payments;
CREATE POLICY "Service role full access loan_payments"
ON loan_payments
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Students can read their own loan payments
DROP POLICY IF EXISTS "Students can read own loan_payments" ON loan_payments;
CREATE POLICY "Students can read own loan_payments"
ON loan_payments
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE auth_students.student_id = loan_payments.student_id
        AND auth_students.auth_user_id = auth.uid()
    )
);

-- ============================================================================
-- 5. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON loan_payments TO service_role;
GRANT SELECT ON loan_payments TO authenticated;
GRANT INSERT ON loan_payments TO authenticated;
GRANT USAGE ON SEQUENCE loan_payments_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF LOAN_PAYMENTS SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: loan_applications_schema.sql
-- ============================================================================

-- Loan Applications Table with OCR Auto-Checking
-- This table stores loan applications with OCR-extracted enrollment data
--
-- IMPORTANT: Before running this script, ensure you have created a Supabase Storage bucket
-- named 'loan_proof_image' in your Supabase dashboard (Storage section).
-- The bucket should be set to Public or have appropriate RLS policies configured.

CREATE TABLE IF NOT EXISTS loan_applications (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL,
    loan_plan_id INTEGER NOT NULL REFERENCES loan_plans(id),
    
    -- OCR Extracted Data
    ocr_name VARCHAR(255),
    ocr_status VARCHAR(100),
    ocr_academic_year VARCHAR(50),
    ocr_semester VARCHAR(50),
    ocr_subjects TEXT, -- JSON array or comma-separated list
    ocr_date VARCHAR(50),
    ocr_confidence DECIMAL(5,2),
    ocr_raw_text TEXT, -- Full OCR text for debugging
    
    -- Uploaded Image
    upload_image_url TEXT, -- URL to Supabase storage bucket
    
    -- Auto-Check Results
    decision VARCHAR(20) NOT NULL CHECK (decision IN ('pending', 'approved', 'rejected')),
    rejection_reason TEXT,
    
    -- System Fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_loan_applications_student_id ON loan_applications(student_id);
CREATE INDEX IF NOT EXISTS idx_loan_applications_loan_plan_id ON loan_applications(loan_plan_id);
CREATE INDEX IF NOT EXISTS idx_loan_applications_decision ON loan_applications(decision);
CREATE INDEX IF NOT EXISTS idx_loan_applications_created_at ON loan_applications(created_at);

-- Enable RLS
ALTER TABLE loan_applications ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Students can read their own loan applications
-- Note: This policy allows authenticated users to read applications where student_id exists in auth_students
CREATE POLICY "Students can read own loan applications" ON loan_applications 
FOR SELECT TO authenticated 
USING (
  -- Allow if student_id exists in auth_students table
  EXISTS (
    SELECT 1 FROM auth_students 
    WHERE auth_students.student_id = loan_applications.student_id
  )
);

-- Students can insert their own loan applications
-- Note: This policy allows authenticated users to insert applications where student_id exists in auth_students
CREATE POLICY "Students can insert own loan applications" ON loan_applications 
FOR INSERT TO authenticated 
WITH CHECK (
  -- Allow if student_id exists in auth_students table
  EXISTS (
    SELECT 1 FROM auth_students 
    WHERE auth_students.student_id = loan_applications.student_id
  )
);

-- Admins can read all loan applications (via service_role or authenticated with admin check)
-- Note: Adjust this policy based on your admin_accounts table structure
CREATE POLICY "Admins can read all loan applications" ON loan_applications 
FOR SELECT TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM admin_accounts 
        WHERE is_active = true
        -- If admin_accounts has auth_user_id, uncomment the line below:
        -- AND auth_user_id = auth.uid()
    )
);

-- Service role has full access
CREATE POLICY "Service role full access loan_applications" ON loan_applications 
FOR ALL TO service_role 
USING (true) WITH CHECK (true);

-- Function to get current academic year and semester from system settings
-- This assumes you have a system_settings table, or you can modify to use a different source
CREATE OR REPLACE FUNCTION get_current_academic_year_semester()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    -- Try to get from system_settings table if it exists
    -- Otherwise, return default values (you may need to adjust this based on your system)
    BEGIN
        SELECT json_build_object(
            'academic_year', COALESCE((SELECT value FROM system_settings WHERE key = 'current_academic_year'), '2024-2025'),
            'semester', COALESCE((SELECT value FROM system_settings WHERE key = 'current_semester'), '1st Semester')
        ) INTO result;
    EXCEPTION WHEN OTHERS THEN
        -- Fallback if system_settings doesn't exist
        result := json_build_object(
            'academic_year', '2024-2025',
            'semester', '1st Semester'
        );
    END;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_current_academic_year_semester() TO authenticated, service_role;

-- Function to apply for loan with auto-approval (for approved OCR applications)
CREATE OR REPLACE FUNCTION apply_for_loan_with_auto_approval(
    p_student_id VARCHAR(50),
    p_loan_plan_id INTEGER,
    p_application_id INTEGER DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    plan_record RECORD;
    total_topup DECIMAL(10,2);
    active_loan_count INTEGER;
    new_loan_id INTEGER;
    due_date TIMESTAMP WITH TIME ZONE;
    interest_amount DECIMAL(10,2);
    total_amount DECIMAL(10,2);
    result JSON;
BEGIN
    -- Check if student exists
    IF NOT EXISTS (SELECT 1 FROM auth_students WHERE student_id = p_student_id) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Student not found',
            'message', 'Student ID does not exist'
        );
    END IF;
    
    -- Get loan plan details
    SELECT * INTO plan_record
    FROM loan_plans 
    WHERE id = p_loan_plan_id AND status = 'active';
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Loan plan not found',
            'message', 'Selected loan plan is not available'
        );
    END IF;
    
    -- Check if student has active loans
    SELECT COUNT(*) INTO active_loan_count
    FROM active_loans 
    WHERE student_id = p_student_id AND status = 'active';
    
    IF active_loan_count > 0 THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Active loan exists',
            'message', 'You already have an active loan. Please pay it off first.'
        );
    END IF;
    
    -- Calculate loan details
    interest_amount := plan_record.amount * plan_record.interest_rate / 100;
    total_amount := plan_record.amount + interest_amount;
    due_date := NOW() + (plan_record.term_days || ' days')::INTERVAL;
    
    -- Create the loan
    INSERT INTO active_loans (
        student_id, loan_plan_id, loan_amount, interest_amount, 
        penalty_amount, total_amount, term_days, due_date, status
    ) VALUES (
        p_student_id, p_loan_plan_id, plan_record.amount, interest_amount,
        0, total_amount, plan_record.term_days, due_date, 'active'
    ) RETURNING id INTO new_loan_id;
    
    -- Add loan amount to student balance
    UPDATE auth_students 
    SET balance = balance + plan_record.amount,
        updated_at = NOW()
    WHERE student_id = p_student_id;
    
    -- Update loan application status if application_id provided
    IF p_application_id IS NOT NULL THEN
        UPDATE loan_applications
        SET decision = 'approved',
            updated_at = NOW()
        WHERE id = p_application_id;
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Loan applied and approved successfully',
        'loan_id', new_loan_id,
        'loan_amount', plan_record.amount,
        'total_amount', total_amount,
        'due_date', due_date
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION apply_for_loan_with_auto_approval(VARCHAR, INTEGER, INTEGER) TO authenticated, service_role;

-- ============================================================================
-- Storage Policies for "loan_proof_image" Bucket
-- ============================================================================
-- IMPORTANT: Before running these policies, ensure the bucket "loan_proof_image" 
-- exists in Supabase Storage (Dashboard â†’ Storage â†’ Create bucket)

-- Policy 1: Allow authenticated students to INSERT (upload) files to loan_proof_image bucket
-- This allows any authenticated user to upload (simpler and more reliable)
-- Drop policy if it exists first
DROP POLICY IF EXISTS "Students can upload loan proof images" ON storage.objects;
CREATE POLICY "Students can upload loan proof images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'loan_proof_image');

-- Policy 2: Allow authenticated students to SELECT (view) files from loan_proof_image bucket
-- This allows any authenticated user to view (simpler and more reliable)
DROP POLICY IF EXISTS "Students can view loan proof images" ON storage.objects;
CREATE POLICY "Students can view loan proof images"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'loan_proof_image');

-- Policy 3: Allow admins to SELECT (view) all files in loan_proof_image bucket
DROP POLICY IF EXISTS "Admins can view all loan proof images" ON storage.objects;
CREATE POLICY "Admins can view all loan proof images"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'loan_proof_image'
  AND EXISTS (
    SELECT 1 FROM admin_accounts 
    WHERE is_active = true
    -- If admin_accounts has auth_user_id, uncomment the line below:
    -- AND auth_user_id = auth.uid()
  )
);

-- Policy 4: Service role has full access
DROP POLICY IF EXISTS "Service role full access loan_proof_image" ON storage.objects;
CREATE POLICY "Service role full access loan_proof_image"
ON storage.objects
FOR ALL
TO service_role
USING (bucket_id = 'loan_proof_image')
WITH CHECK (bucket_id = 'loan_proof_image');

-- ============================================================================
-- ALTERNATIVE: Simple Policies (if the above don't work)
-- ============================================================================
-- If the above policies are too restrictive, use these simpler ones:
-- These allow any authenticated user to upload/view files in the bucket

/*
-- Drop existing policies first if needed
DROP POLICY IF EXISTS "Students can upload loan proof images" ON storage.objects;
DROP POLICY IF EXISTS "Students can view loan proof images" ON storage.objects;
DROP POLICY IF EXISTS "Admins can view all loan proof images" ON storage.objects;
DROP POLICY IF EXISTS "Service role full access loan_proof_image" ON storage.objects;

-- Simple INSERT policy (any authenticated user can upload)
CREATE POLICY "Allow authenticated uploads to loan_proof_image"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'loan_proof_image');

-- Simple SELECT policy (any authenticated user can view)
CREATE POLICY "Allow authenticated reads from loan_proof_image"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'loan_proof_image');
*/




-- ============================================================================
-- FILE: top_up_transactions_schema.sql
-- ============================================================================

-- ============================================================================
-- TOP_UP_TRANSACTIONS TABLE SCHEMA
-- ============================================================================
-- This file creates the top_up_transactions table for tracking top-up history
-- ============================================================================

-- ============================================================================
-- 1. CREATE TOP_UP_TRANSACTIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS top_up_transactions (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL REFERENCES auth_students(student_id),
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    previous_balance DECIMAL(10,2) NOT NULL CHECK (previous_balance >= 0),
    new_balance DECIMAL(10,2) NOT NULL CHECK (new_balance >= 0),
    transaction_type VARCHAR(50) NOT NULL DEFAULT 'top_up' CHECK (
        transaction_type IN ('top_up', 'top_up_gcash', 'top_up_services', 'loan_disbursement')
    ),
    processed_by VARCHAR(100),
    notes TEXT,
    admin_earn DECIMAL(10,2) DEFAULT 0.00 CHECK (admin_earn >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraint to ensure balance calculation is correct
    CONSTRAINT check_balance_calculation CHECK (new_balance = previous_balance + amount)
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_top_up_transactions_student_id ON top_up_transactions(student_id);
CREATE INDEX IF NOT EXISTS idx_top_up_transactions_created_at ON top_up_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_top_up_transactions_transaction_type ON top_up_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_top_up_transactions_processed_by ON top_up_transactions(processed_by) WHERE processed_by IS NOT NULL;

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_top_up_transactions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_top_up_transactions_updated_at ON top_up_transactions;
CREATE TRIGGER update_top_up_transactions_updated_at
    BEFORE UPDATE ON top_up_transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_top_up_transactions_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE top_up_transactions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access top_up_transactions" ON top_up_transactions;
CREATE POLICY "Service role full access top_up_transactions"
ON top_up_transactions
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Students can read their own transactions
DROP POLICY IF EXISTS "Students can read own top_up_transactions" ON top_up_transactions;
CREATE POLICY "Students can read own top_up_transactions"
ON top_up_transactions
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE auth_students.student_id = top_up_transactions.student_id
        AND auth_students.auth_user_id = auth.uid()
    )
);

-- Authenticated users can insert (for admin processing)
DROP POLICY IF EXISTS "Authenticated can insert top_up_transactions" ON top_up_transactions;
CREATE POLICY "Authenticated can insert top_up_transactions"
ON top_up_transactions
FOR INSERT
TO authenticated
WITH CHECK (true);

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON top_up_transactions TO service_role;
GRANT SELECT, INSERT ON top_up_transactions TO authenticated;
GRANT USAGE ON SEQUENCE top_up_transactions_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF TOP_UP_TRANSACTIONS SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: top_up_requests_schema.sql
-- ============================================================================

-- ============================================================================
-- TOP_UP_REQUESTS TABLE SCHEMA
-- ============================================================================
-- This file creates the top_up_requests table for student top-up requests
-- ============================================================================

-- ============================================================================
-- 1. CREATE TOP_UP_REQUESTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS top_up_requests (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL REFERENCES auth_students(student_id),
    amount INTEGER NOT NULL CHECK (amount > 0),
    screenshot_url TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Pending Verification' CHECK (
        status IN ('Pending Verification', 'Approved', 'Rejected')
    ),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    processed_by TEXT,
    notes TEXT
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_top_up_requests_user_id ON top_up_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_top_up_requests_status ON top_up_requests(status);
CREATE INDEX IF NOT EXISTS idx_top_up_requests_created_at ON top_up_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_top_up_requests_processed_at ON top_up_requests(processed_at) WHERE processed_at IS NOT NULL;

-- ============================================================================
-- 3. ENABLE RLS
-- ============================================================================
ALTER TABLE top_up_requests ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 4. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access top_up_requests" ON top_up_requests;
CREATE POLICY "Service role full access top_up_requests"
ON top_up_requests
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Students can read and insert their own requests
DROP POLICY IF EXISTS "Students can manage own top_up_requests" ON top_up_requests;
CREATE POLICY "Students can manage own top_up_requests"
ON top_up_requests
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE auth_students.student_id = top_up_requests.user_id
        AND auth_students.auth_user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE auth_students.student_id = top_up_requests.user_id
        AND auth_students.auth_user_id = auth.uid()
    )
);

-- ============================================================================
-- 5. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON top_up_requests TO service_role;
GRANT SELECT, INSERT, UPDATE ON top_up_requests TO authenticated;
GRANT USAGE ON SEQUENCE top_up_requests_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF TOP_UP_REQUESTS SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: user_transfers_schema.sql
-- ============================================================================

-- ============================================================================
-- USER_TRANSFERS TABLE SCHEMA
-- ============================================================================
-- This file creates the user_transfers table for money transfers between users
-- ============================================================================

-- ============================================================================
-- 1. CREATE USER_TRANSFERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_transfers (
    id SERIAL PRIMARY KEY,
    sender_student_id VARCHAR(50) NOT NULL REFERENCES auth_students(student_id),
    recipient_student_id VARCHAR(50) NOT NULL REFERENCES auth_students(student_id),
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    sender_previous_balance DECIMAL(10,2) NOT NULL CHECK (sender_previous_balance >= 0),
    sender_new_balance DECIMAL(10,2) NOT NULL CHECK (sender_new_balance >= 0),
    recipient_previous_balance DECIMAL(10,2) NOT NULL CHECK (recipient_previous_balance >= 0),
    recipient_new_balance DECIMAL(10,2) NOT NULL CHECK (recipient_new_balance >= 0),
    transaction_type VARCHAR(20) NOT NULL DEFAULT 'transfer' CHECK (transaction_type = 'transfer'),
    status VARCHAR(20) NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'failed', 'pending')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT check_no_self_transfer CHECK (sender_student_id != recipient_student_id),
    CONSTRAINT check_sender_balance_calculation CHECK (sender_new_balance = sender_previous_balance - amount),
    CONSTRAINT check_recipient_balance_calculation CHECK (recipient_new_balance = recipient_previous_balance + amount)
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_user_transfers_sender_student_id ON user_transfers(sender_student_id);
CREATE INDEX IF NOT EXISTS idx_user_transfers_recipient_student_id ON user_transfers(recipient_student_id);
CREATE INDEX IF NOT EXISTS idx_user_transfers_created_at ON user_transfers(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_transfers_status ON user_transfers(status);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_transfers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_user_transfers_updated_at ON user_transfers;
CREATE TRIGGER update_user_transfers_updated_at
    BEFORE UPDATE ON user_transfers
    FOR EACH ROW
    EXECUTE FUNCTION update_user_transfers_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE user_transfers ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access user_transfers" ON user_transfers;
CREATE POLICY "Service role full access user_transfers"
ON user_transfers
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Students can read transfers where they are sender or recipient
DROP POLICY IF EXISTS "Students can read own user_transfers" ON user_transfers;
CREATE POLICY "Students can read own user_transfers"
ON user_transfers
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE (auth_students.student_id = user_transfers.sender_student_id 
               OR auth_students.student_id = user_transfers.recipient_student_id)
        AND auth_students.auth_user_id = auth.uid()
    )
);

-- Students can insert transfers (as sender)
DROP POLICY IF EXISTS "Students can insert user_transfers" ON user_transfers;
CREATE POLICY "Students can insert user_transfers"
ON user_transfers
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE auth_students.student_id = user_transfers.sender_student_id
        AND auth_students.auth_user_id = auth.uid()
    )
);

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON user_transfers TO service_role;
GRANT SELECT, INSERT ON user_transfers TO authenticated;
GRANT USAGE ON SEQUENCE user_transfers_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF USER_TRANSFERS SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: withdrawal_transactions_table.sql
-- ============================================================================

-- ================================================================
-- WITHDRAWAL TRANSACTIONS TABLE
-- ================================================================
-- This table tracks all withdrawal transactions from users and service accounts
-- Users can withdraw to Admin or to Service accounts
-- Service accounts can only withdraw to Admin
-- ================================================================

-- Create the withdrawal_transactions table
CREATE TABLE IF NOT EXISTS public.withdrawal_transactions (
    id BIGSERIAL PRIMARY KEY,
    student_id TEXT,  -- NULL for service withdrawals
    service_account_id INTEGER,  -- NULL for user withdrawals
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    transaction_type TEXT NOT NULL,  -- 'Withdraw to Admin', 'Withdraw to Service', 'Service Withdraw to Admin'
    destination_service_id INTEGER,  -- NULL if withdrawing to admin
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT check_has_student_or_service CHECK (
        (student_id IS NOT NULL AND service_account_id IS NULL) OR
        (student_id IS NULL AND service_account_id IS NOT NULL)
    ),
    CONSTRAINT valid_transaction_type CHECK (
        transaction_type IN ('Withdraw to Admin', 'Withdraw to Service', 'Service Withdraw to Admin')
    )
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_withdrawal_transactions_student_id ON public.withdrawal_transactions(student_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_transactions_service_account_id ON public.withdrawal_transactions(service_account_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_transactions_created_at ON public.withdrawal_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_withdrawal_transactions_transaction_type ON public.withdrawal_transactions(transaction_type);

-- Enable Row Level Security
ALTER TABLE public.withdrawal_transactions ENABLE ROW LEVEL SECURITY;

-- ================================================================
-- RLS POLICIES
-- ================================================================

-- Policy 1: Allow users to view their own withdrawal transactions
DROP POLICY IF EXISTS "Users can view own withdrawals" ON public.withdrawal_transactions;
CREATE POLICY "Users can view own withdrawals" 
ON public.withdrawal_transactions
FOR SELECT
USING (
    student_id IS NOT NULL AND 
    student_id = current_setting('request.jwt.claims', true)::json->>'student_id'
);

-- Policy 2: Allow service accounts to view their own withdrawal transactions
DROP POLICY IF EXISTS "Service accounts can view own withdrawals" ON public.withdrawal_transactions;
CREATE POLICY "Service accounts can view own withdrawals" 
ON public.withdrawal_transactions
FOR SELECT
USING (
    service_account_id IS NOT NULL AND 
    service_account_id::text = current_setting('request.jwt.claims', true)::json->>'service_id'
);

-- Policy 3: Allow authenticated users to insert their own withdrawal transactions
DROP POLICY IF EXISTS "Users can insert own withdrawals" ON public.withdrawal_transactions;
CREATE POLICY "Users can insert own withdrawals" 
ON public.withdrawal_transactions
FOR INSERT
WITH CHECK (
    student_id IS NOT NULL AND 
    student_id = current_setting('request.jwt.claims', true)::json->>'student_id'
);

-- Policy 4: Allow service accounts to insert their own withdrawal transactions
DROP POLICY IF EXISTS "Service accounts can insert own withdrawals" ON public.withdrawal_transactions;
CREATE POLICY "Service accounts can insert own withdrawals" 
ON public.withdrawal_transactions
FOR INSERT
WITH CHECK (
    service_account_id IS NOT NULL AND 
    service_account_id::text = current_setting('request.jwt.claims', true)::json->>'service_id'
);

-- Policy 5: Allow service role (backend/admin) full access
DROP POLICY IF EXISTS "Service role has full access" ON public.withdrawal_transactions;
CREATE POLICY "Service role has full access" 
ON public.withdrawal_transactions
FOR ALL
USING (true)
WITH CHECK (true);

-- ================================================================
-- GRANT PERMISSIONS
-- ================================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT ON public.withdrawal_transactions TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE withdrawal_transactions_id_seq TO authenticated;

-- Grant full permissions to service role (for admin operations)
GRANT ALL ON public.withdrawal_transactions TO service_role;
GRANT ALL ON SEQUENCE withdrawal_transactions_id_seq TO service_role;

-- Grant select to anon (read-only public access if needed)
GRANT SELECT ON public.withdrawal_transactions TO anon;

-- ================================================================
-- COMMENTS
-- ================================================================

COMMENT ON TABLE public.withdrawal_transactions IS 'Stores all withdrawal transactions from users and service accounts';
COMMENT ON COLUMN public.withdrawal_transactions.student_id IS 'Student ID for user withdrawals (NULL for service withdrawals)';
COMMENT ON COLUMN public.withdrawal_transactions.service_account_id IS 'Service account ID for service withdrawals (NULL for user withdrawals)';
COMMENT ON COLUMN public.withdrawal_transactions.amount IS 'Withdrawal amount in PHP';
COMMENT ON COLUMN public.withdrawal_transactions.transaction_type IS 'Type: Withdraw to Admin, Withdraw to Service, or Service Withdraw to Admin';
COMMENT ON COLUMN public.withdrawal_transactions.destination_service_id IS 'Target service ID when withdrawing to a service (NULL for admin withdrawals)';
COMMENT ON COLUMN public.withdrawal_transactions.metadata IS 'Additional transaction metadata in JSON format';
COMMENT ON COLUMN public.withdrawal_transactions.created_at IS 'Timestamp when withdrawal was created';

-- ================================================================
-- VERIFICATION QUERY
-- ================================================================
-- Run this to verify the table was created successfully:
-- SELECT * FROM public.withdrawal_transactions LIMIT 1;

-- ================================================================
-- SAMPLE INSERT (for testing)
-- ================================================================
-- User withdrawal to admin:
-- INSERT INTO public.withdrawal_transactions (student_id, amount, transaction_type, metadata)
-- VALUES ('2021-12345', 500.00, 'Withdraw to Admin', '{"destination_type": "admin"}'::jsonb);

-- User withdrawal to service:
-- INSERT INTO public.withdrawal_transactions (student_id, amount, transaction_type, destination_service_id, metadata)
-- VALUES ('2021-12345', 200.00, 'Withdraw to Service', 1, '{"destination_type": "service", "destination_service_name": "Canteen"}'::jsonb);

-- Service withdrawal to admin:
-- INSERT INTO public.withdrawal_transactions (service_account_id, amount, transaction_type, metadata)
-- VALUES (1, 1000.00, 'Service Withdraw to Admin', '{"destination_type": "admin", "service_name": "Canteen"}'::jsonb);





-- ============================================================================
-- FILE: create_withdrawal_requests_table.sql
-- ============================================================================

-- =====================================================
-- Create withdrawal_requests Table for Admin Approval
-- =====================================================
-- This script creates the table to store user withdrawal requests
-- that need admin verification and approval
-- =====================================================

-- Create the table
CREATE TABLE IF NOT EXISTS public.withdrawal_requests (
    id BIGSERIAL PRIMARY KEY,
    student_id TEXT NOT NULL,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    transfer_type TEXT NOT NULL CHECK (transfer_type IN ('Gcash', 'Cash')),
    gcash_number TEXT,
    gcash_account_name TEXT,
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    processed_by TEXT,
    admin_notes TEXT,
    CONSTRAINT fk_student_id FOREIGN KEY (student_id) REFERENCES public.auth_students(student_id) ON DELETE CASCADE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_student_id ON public.withdrawal_requests(student_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_status ON public.withdrawal_requests(status);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_created_at ON public.withdrawal_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_transfer_type ON public.withdrawal_requests(transfer_type);

-- Enable Row Level Security
ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow admin read access to withdrawal_requests" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "Allow admin update access to withdrawal_requests" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "Allow admin delete access to withdrawal_requests" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "Allow students to insert their own requests" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "Allow students to read their own requests" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "public_all_access" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "service_role_full_access" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "public_read_all" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "public_insert" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "public_update" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "public_delete" ON public.withdrawal_requests;

-- Policy 1: Allow service_role (admin) FULL ACCESS
CREATE POLICY "service_role_full_access"
ON public.withdrawal_requests
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy 2: Allow public to SELECT all (for admin panel using service key)
CREATE POLICY "public_read_all"
ON public.withdrawal_requests
FOR SELECT
USING (true);

-- Policy 3: Allow public to INSERT (for students submitting requests)
CREATE POLICY "public_insert"
ON public.withdrawal_requests
FOR INSERT
WITH CHECK (true);

-- Policy 4: Allow public to UPDATE (for admin status changes)
CREATE POLICY "public_update"
ON public.withdrawal_requests
FOR UPDATE
USING (true)
WITH CHECK (true);

-- Policy 5: Allow public to DELETE (for admin after processing)
CREATE POLICY "public_delete"
ON public.withdrawal_requests
FOR DELETE
USING (true);

-- Grant permissions to all roles
GRANT ALL ON public.withdrawal_requests TO public;
GRANT ALL ON public.withdrawal_requests TO anon;
GRANT ALL ON public.withdrawal_requests TO authenticated;
GRANT ALL ON public.withdrawal_requests TO service_role;

-- Grant sequence permissions
GRANT USAGE, SELECT ON SEQUENCE public.withdrawal_requests_id_seq TO public;
GRANT USAGE, SELECT ON SEQUENCE public.withdrawal_requests_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE public.withdrawal_requests_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.withdrawal_requests_id_seq TO service_role;

-- Verify table was created
SELECT 
    'âœ… Table Created Successfully' AS status,
    tablename AS table_name,
    schemaname AS schema_name
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'withdrawal_requests';

-- List all policies
SELECT 
    'âœ… Policies Created' AS status,
    policyname AS "Policy Name",
    cmd AS "Command"
FROM pg_policies
WHERE tablename = 'withdrawal_requests'
ORDER BY policyname;

-- =====================================================
-- NOTES:
-- =====================================================
-- 
-- This table stores withdrawal requests from students that need
-- admin verification before being processed.
--
-- Fields:
-- - id: Auto-increment primary key
-- - student_id: Student ID (foreign key to auth_students)
-- - amount: Withdrawal amount (must be > 0)
-- - transfer_type: 'Gcash' or 'Cash' (onsite)
-- - gcash_number: GCash number (required if transfer_type is 'Gcash')
-- - gcash_account_name: GCash account name (required if transfer_type is 'Gcash')
-- - status: 'Pending', 'Approved', or 'Rejected'
-- - created_at: When request was submitted
-- - processed_at: When admin processed the request
-- - processed_by: Admin username who processed it
-- - admin_notes: Optional notes from admin
--
-- The admin can:
-- 1. View all pending requests
-- 2. See withdrawal details (amount, transfer type, GCash info if applicable)
-- 3. Approve (deducts balance, creates withdrawal_transaction, updates status)
-- 4. Reject (updates status with optional reason, no balance change)
--
-- Students can:
-- 1. Submit withdrawal requests
-- 2. View their withdrawal request history with status
-- 3. See pending, approved, or rejected requests
--
-- =====================================================

\echo 'â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•'
\echo 'WITHDRAWAL REQUESTS TABLE CREATION COMPLETE'
\echo 'â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•'
\echo ''
\echo 'Next steps:'
\echo '1. Run this SQL script in Supabase SQL Editor'
\echo '2. Verify table exists in Supabase Dashboard'
\echo '3. Test by submitting a withdrawal request from the app'
\echo '4. Check console for debug messages'
\echo ''





-- ============================================================================
-- FILE: create_service_withdrawal_requests_table.sql
-- ============================================================================

-- =====================================================
-- Create service_withdrawal_requests Table for Admin Approval
-- =====================================================
-- This script creates the table to store service account withdrawal requests
-- that need admin verification and approval
-- =====================================================

-- Create the table
CREATE TABLE IF NOT EXISTS public.service_withdrawal_requests (
    id BIGSERIAL PRIMARY KEY,
    service_account_id INTEGER NOT NULL,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    processed_by TEXT,
    admin_notes TEXT,
    CONSTRAINT fk_service_account_id FOREIGN KEY (service_account_id) REFERENCES public.service_accounts(id) ON DELETE CASCADE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_service_withdrawal_requests_service_account_id ON public.service_withdrawal_requests(service_account_id);
CREATE INDEX IF NOT EXISTS idx_service_withdrawal_requests_status ON public.service_withdrawal_requests(status);
CREATE INDEX IF NOT EXISTS idx_service_withdrawal_requests_created_at ON public.service_withdrawal_requests(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.service_withdrawal_requests ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow admin read access to service_withdrawal_requests" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "Allow admin update access to service_withdrawal_requests" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "Allow admin delete access to service_withdrawal_requests" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "Allow services to insert their own requests" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "Allow services to read their own requests" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "public_all_access" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "service_role_full_access" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "public_read_all" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "public_insert" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "public_update" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "public_delete" ON public.service_withdrawal_requests;

-- Policy 1: Allow service_role (admin) FULL ACCESS
CREATE POLICY "service_role_full_access"
ON public.service_withdrawal_requests
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy 2: Allow public to SELECT all (for admin panel using service key)
CREATE POLICY "public_read_all"
ON public.service_withdrawal_requests
FOR SELECT
USING (true);

-- Policy 3: Allow public to INSERT (for service accounts submitting requests)
CREATE POLICY "public_insert"
ON public.service_withdrawal_requests
FOR INSERT
WITH CHECK (true);

-- Policy 4: Allow public to UPDATE (for admin status changes)
CREATE POLICY "public_update"
ON public.service_withdrawal_requests
FOR UPDATE
USING (true)
WITH CHECK (true);

-- Policy 5: Allow public to DELETE (for admin after processing)
CREATE POLICY "public_delete"
ON public.service_withdrawal_requests
FOR DELETE
USING (true);

-- Grant permissions to all roles
GRANT ALL ON public.service_withdrawal_requests TO public;
GRANT ALL ON public.service_withdrawal_requests TO anon;
GRANT ALL ON public.service_withdrawal_requests TO authenticated;
GRANT ALL ON public.service_withdrawal_requests TO service_role;

-- Grant sequence permissions
GRANT USAGE, SELECT ON SEQUENCE public.service_withdrawal_requests_id_seq TO public;
GRANT USAGE, SELECT ON SEQUENCE public.service_withdrawal_requests_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE public.service_withdrawal_requests_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.service_withdrawal_requests_id_seq TO service_role;

-- Verify table was created
SELECT 
    'âœ… Table Created Successfully' AS status,
    tablename AS table_name,
    schemaname AS schema_name
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'service_withdrawal_requests';

-- List all policies
SELECT 
    'âœ… Policies Created' AS status,
    policyname AS "Policy Name",
    cmd AS "Command"
FROM pg_policies
WHERE tablename = 'service_withdrawal_requests'
ORDER BY policyname;

-- =====================================================
-- NOTES:
-- =====================================================
-- 
-- This table stores withdrawal requests from service accounts that need
-- admin verification before being processed.
--
-- Fields:
-- - id: Auto-increment primary key
-- - service_account_id: Service account ID (foreign key to service_accounts)
-- - amount: Withdrawal amount (must be > 0)
-- - status: 'Pending', 'Approved', or 'Rejected'
-- - created_at: When request was submitted
-- - processed_at: When admin processed the request
-- - processed_by: Admin username who processed it
-- - admin_notes: Optional notes from admin
--
-- The admin can:
-- 1. View all pending requests
-- 2. See withdrawal details (amount, service name)
-- 3. Approve (deducts balance, creates withdrawal_transaction, updates status)
-- 4. Reject (updates status with optional reason, no balance change)
--
-- Service accounts can:
-- 1. Submit withdrawal requests
-- 2. View their withdrawal request history with status
-- 3. See pending, approved, or rejected requests
--
-- =====================================================

\echo 'â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•'
\echo 'Service Withdrawal Requests Table Created'
\echo 'â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•â•'
















-- ============================================================================
-- FILE: feedback_schema.sql
-- ============================================================================

-- ============================================================================
-- FEEDBACK TABLE SCHEMA
-- ============================================================================
-- This file creates the feedback table for storing feedback from users and services
-- ============================================================================

-- ============================================================================
-- 1. CREATE FEEDBACK TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('user', 'service_account')),
    account_username VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_feedback_user_type ON feedback(user_type);
CREATE INDEX IF NOT EXISTS idx_feedback_created_at ON feedback(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_username ON feedback(account_username);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_feedback_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_feedback_updated_at_trigger ON feedback;
CREATE TRIGGER update_feedback_updated_at_trigger
    BEFORE UPDATE ON feedback
    FOR EACH ROW
    EXECUTE FUNCTION update_feedback_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access feedback" ON feedback;
CREATE POLICY "Service role full access feedback"
ON feedback
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Service accounts can insert and view all feedback
DROP POLICY IF EXISTS "Service accounts can manage feedback" ON feedback;
CREATE POLICY "Service accounts can manage feedback"
ON feedback
FOR ALL
TO authenticated
USING (
    user_type = 'service_account' OR
    EXISTS (
        SELECT 1 FROM service_accounts
        WHERE username = account_username
        AND is_active = true
    )
)
WITH CHECK (
    user_type = 'service_account' OR
    EXISTS (
        SELECT 1 FROM service_accounts
        WHERE username = account_username
        AND is_active = true
    )
);

-- Users can insert and view their own feedback
DROP POLICY IF EXISTS "Users can manage own feedback" ON feedback;
CREATE POLICY "Users can manage own feedback"
ON feedback
FOR ALL
TO authenticated
USING (
    user_type = 'user' AND
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE student_id = account_username
        AND auth_user_id = auth.uid()
    )
)
WITH CHECK (
    user_type = 'user' AND
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE student_id = account_username
        AND auth_user_id = auth.uid()
    )
);

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON feedback TO service_role;
GRANT SELECT, INSERT ON feedback TO authenticated;

-- ============================================================================
-- END OF FEEDBACK SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: api_configuration_schema.sql
-- ============================================================================

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





-- ============================================================================
-- FILE: scanner_devices_schema.sql
-- ============================================================================

-- ============================================================================
-- SCANNER_DEVICES TABLE SCHEMA
-- ============================================================================
-- This file creates the scanner_devices table for RFID Bluetooth scanner management
-- ============================================================================

-- ============================================================================
-- 1. CREATE SCANNER_DEVICES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS scanner_devices (
    id SERIAL PRIMARY KEY,
    scanner_id VARCHAR(50) UNIQUE NOT NULL,
    device_name VARCHAR(255) NOT NULL,
    device_type VARCHAR(50) DEFAULT 'RFID_Bluetooth_Scanner',
    model VARCHAR(100) DEFAULT 'ESP32 RFID',
    serial_number VARCHAR(100) UNIQUE NOT NULL,
    status VARCHAR(20) DEFAULT 'Available' CHECK (status IN ('Available', 'Assigned', 'Maintenance')),
    notes TEXT,
    assigned_service_id INTEGER REFERENCES service_accounts(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_scanner_devices_scanner_id ON scanner_devices(scanner_id);
CREATE INDEX IF NOT EXISTS idx_scanner_devices_status ON scanner_devices(status);
CREATE INDEX IF NOT EXISTS idx_scanner_devices_assigned_service_id ON scanner_devices(assigned_service_id) WHERE assigned_service_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_scanner_devices_serial_number ON scanner_devices(serial_number);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_scanner_devices_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_scanner_devices_updated_at ON scanner_devices;
CREATE TRIGGER update_scanner_devices_updated_at
    BEFORE UPDATE ON scanner_devices
    FOR EACH ROW
    EXECUTE FUNCTION update_scanner_devices_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE scanner_devices ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access scanner_devices" ON scanner_devices;
CREATE POLICY "Service role full access scanner_devices"
ON scanner_devices
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated users can read
DROP POLICY IF EXISTS "Authenticated can read scanner_devices" ON scanner_devices;
CREATE POLICY "Authenticated can read scanner_devices"
ON scanner_devices
FOR SELECT
TO authenticated
USING (true);

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON scanner_devices TO service_role;
GRANT SELECT ON scanner_devices TO authenticated;
GRANT USAGE ON SEQUENCE scanner_devices_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF SCANNER_DEVICES SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: read_inbox_schema.sql
-- ============================================================================

-- ============================================================================
-- READ_INBOX TABLE SCHEMA
-- ============================================================================
-- This file creates the read_inbox table for tracking read/unread transactions
-- ============================================================================

-- ============================================================================
-- 1. CREATE READ_INBOX TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS read_inbox (
    id BIGSERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL,
    transaction_type VARCHAR(50) NOT NULL,
    transaction_id BIGINT NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- A student can only mark a specific transaction once
    UNIQUE(student_id, transaction_type, transaction_id)
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_read_inbox_student_id ON read_inbox(student_id);
CREATE INDEX IF NOT EXISTS idx_read_inbox_transaction_type ON read_inbox(transaction_type);
CREATE INDEX IF NOT EXISTS idx_read_inbox_transaction_id ON read_inbox(transaction_id);
CREATE INDEX IF NOT EXISTS idx_read_inbox_read_at ON read_inbox(read_at);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to mark transaction as read
CREATE OR REPLACE FUNCTION mark_transaction_as_read(
    p_student_id VARCHAR(50),
    p_transaction_type VARCHAR(50),
    p_transaction_id BIGINT
)
RETURNS BOOLEAN AS $$
BEGIN
    INSERT INTO read_inbox (student_id, transaction_type, transaction_id, read_at)
    VALUES (p_student_id, p_transaction_type, p_transaction_id, NOW())
    ON CONFLICT (student_id, transaction_type, transaction_id) DO UPDATE
    SET read_at = EXCLUDED.read_at;
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get unread transaction count
CREATE OR REPLACE FUNCTION get_unread_transaction_count(p_student_id VARCHAR(50))
RETURNS INTEGER AS $$
DECLARE
    v_top_up INTEGER;
    v_service INTEGER;
    v_transfer INTEGER;
    v_read INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_top_up
    FROM top_up_transactions
    WHERE student_id = p_student_id;
    
    SELECT COUNT(*) INTO v_service
    FROM service_transactions
    WHERE student_id = p_student_id;
    
    SELECT COUNT(*) INTO v_transfer
    FROM user_transfers
    WHERE sender_student_id = p_student_id OR recipient_student_id = p_student_id;
    
    SELECT COUNT(*) INTO v_read
    FROM read_inbox
    WHERE student_id = p_student_id;
    
    RETURN (v_top_up + v_service + v_transfer) - v_read;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. ENABLE RLS
-- ============================================================================
ALTER TABLE read_inbox ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 5. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access to read_inbox" ON read_inbox;
CREATE POLICY "Service role full access to read_inbox"
ON read_inbox
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Users can view their read transactions
DROP POLICY IF EXISTS "Users can view their read transactions" ON read_inbox;
CREATE POLICY "Users can view their read transactions"
ON read_inbox
FOR SELECT
TO authenticated
USING (
    auth.uid() IS NOT NULL AND student_id = (
        SELECT student_id FROM auth_students
        WHERE auth_user_id = auth.uid() AND is_active = true
    )
);

-- Users can insert their read transactions
DROP POLICY IF EXISTS "Users can insert their read transactions" ON read_inbox;
CREATE POLICY "Users can insert their read transactions"
ON read_inbox
FOR INSERT
TO authenticated
WITH CHECK (
    auth.uid() IS NOT NULL AND student_id = (
        SELECT student_id FROM auth_students
        WHERE auth_user_id = auth.uid() AND is_active = true
    )
);

-- Users can delete their read transactions
DROP POLICY IF EXISTS "Users can delete their read transactions" ON read_inbox;
CREATE POLICY "Users can delete their read transactions"
ON read_inbox
FOR DELETE
TO authenticated
USING (
    auth.uid() IS NOT NULL AND student_id = (
        SELECT student_id FROM auth_students
        WHERE auth_user_id = auth.uid() AND is_active = true
    )
);

-- Anonymous can insert (for system functions)
DROP POLICY IF EXISTS "Anonymous can insert read_inbox" ON read_inbox;
CREATE POLICY "Anonymous can insert read_inbox"
ON read_inbox
FOR INSERT
TO anon
WITH CHECK (true);

-- ============================================================================
-- 6. GRANT PERMISSIONS
-- ============================================================================
GRANT SELECT, INSERT, DELETE ON read_inbox TO authenticated;
GRANT INSERT ON read_inbox TO anon;
GRANT ALL ON read_inbox TO service_role;
GRANT USAGE ON SEQUENCE read_inbox_id_seq TO authenticated, anon, service_role;
GRANT EXECUTE ON FUNCTION mark_transaction_as_read(VARCHAR, VARCHAR, BIGINT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION get_unread_transaction_count(VARCHAR) TO authenticated;

-- ============================================================================
-- END OF READ_INBOX SCHEMA
-- ============================================================================





-- ============================================================================
-- FILE: create_id_replacement_table.sql
-- ============================================================================

-- Create id_replacement table to track RFID card replacements
CREATE TABLE IF NOT EXISTS public.id_replacement (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL,
    student_name VARCHAR(255) NOT NULL,
    old_rfid_id VARCHAR(255),
    new_rfid_id VARCHAR(255) NOT NULL,
    issue_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on student_id for faster queries
CREATE INDEX IF NOT EXISTS idx_id_replacement_student_id ON public.id_replacement(student_id);

-- Create index on issue_date for sorting recent replacements
CREATE INDEX IF NOT EXISTS idx_id_replacement_issue_date ON public.id_replacement(issue_date DESC);

-- Enable Row Level Security
ALTER TABLE public.id_replacement ENABLE ROW LEVEL SECURITY;

-- Policy: Allow service_role (admin) FULL ACCESS
DROP POLICY IF EXISTS "service_role_full_access" ON public.id_replacement;
CREATE POLICY "service_role_full_access"
    ON public.id_replacement
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Policy: Allow admins to read all id_replacement records
DROP POLICY IF EXISTS "Allow admins to read id_replacement" ON public.id_replacement;
CREATE POLICY "Allow admins to read id_replacement" ON public.id_replacement
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_accounts
            WHERE public.admin_accounts.email = (SELECT email FROM auth.users WHERE id = auth.uid())
        )
    );

-- Policy: Allow admins to insert id_replacement records
DROP POLICY IF EXISTS "Allow admins to insert id_replacement" ON public.id_replacement;
CREATE POLICY "Allow admins to insert id_replacement" ON public.id_replacement
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_accounts
            WHERE public.admin_accounts.email = (SELECT email FROM auth.users WHERE id = auth.uid())
        )
    );

-- Grant full access to service_role (admin operations)
GRANT ALL ON public.id_replacement TO service_role;

-- Add comment to table
COMMENT ON TABLE public.id_replacement IS 'Tracks RFID card replacements with old and new RFID IDs, student info, and issue date';





-- ============================================================================
-- FILE: create_commission_settings_table.sql
-- ============================================================================

-- =====================================================
-- Create commission_settings table
-- =====================================================
-- This table stores global commission percentages for
-- vendor and admin earnings from top-up transactions
-- =====================================================

-- Step 1: Create commission_settings table
CREATE TABLE IF NOT EXISTS commission_settings (
    id SERIAL PRIMARY KEY,
    vendor_commission DECIMAL(5,2) NOT NULL DEFAULT 1.00 CHECK (vendor_commission >= 0 AND vendor_commission <= 100),
    admin_commission DECIMAL(5,2) NOT NULL DEFAULT 0.50 CHECK (admin_commission >= 0 AND admin_commission <= 100),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'Asia/Manila'),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'Asia/Manila')
);

-- Step 2: Insert default row if table is empty
INSERT INTO commission_settings (vendor_commission, admin_commission)
SELECT 1.00, 0.50
WHERE NOT EXISTS (SELECT 1 FROM commission_settings);

-- Step 3: Create unique constraint to ensure only one row (or add type column for multiple types in future)
-- For now, we'll use a trigger to ensure only one row exists
CREATE OR REPLACE FUNCTION ensure_single_commission_setting()
RETURNS TRIGGER AS $$
BEGIN
    -- If more than one row exists, keep only the most recent one
    IF (SELECT COUNT(*) FROM commission_settings) > 1 THEN
        DELETE FROM commission_settings
        WHERE id NOT IN (
            SELECT id FROM commission_settings
            ORDER BY updated_at DESC
            LIMIT 1
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 4: Create trigger to maintain single row
DROP TRIGGER IF EXISTS trigger_ensure_single_commission_setting ON commission_settings;
CREATE TRIGGER trigger_ensure_single_commission_setting
    AFTER INSERT OR UPDATE ON commission_settings
    FOR EACH ROW
    EXECUTE FUNCTION ensure_single_commission_setting();

-- Step 5: Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_commission_settings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = (NOW() AT TIME ZONE 'Asia/Manila');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_commission_settings_updated_at ON commission_settings;
CREATE TRIGGER trigger_update_commission_settings_updated_at
    BEFORE UPDATE ON commission_settings
    FOR EACH ROW
    EXECUTE FUNCTION update_commission_settings_updated_at();

-- Step 6: Create index for better performance
CREATE INDEX IF NOT EXISTS idx_commission_settings_updated_at ON commission_settings(updated_at);

-- Step 7: Enable Row Level Security (RLS)
ALTER TABLE commission_settings ENABLE ROW LEVEL SECURITY;

-- Step 8: Create RLS Policies
-- Policy for service_role (full access)
CREATE POLICY "Service role can manage commission_settings" ON commission_settings
    FOR ALL TO service_role
    USING (true)
    WITH CHECK (true);

-- Policy for authenticated users (read only)
CREATE POLICY "Authenticated users can view commission_settings" ON commission_settings
    FOR SELECT TO authenticated
    USING (true);

-- Step 9: Grant permissions
GRANT ALL ON commission_settings TO service_role;
GRANT SELECT ON commission_settings TO authenticated;
GRANT USAGE ON SEQUENCE commission_settings_id_seq TO service_role;

-- Step 10: Add comments
COMMENT ON TABLE commission_settings IS 'Global commission percentages for vendor and admin earnings from top-up transactions';
COMMENT ON COLUMN commission_settings.vendor_commission IS 'Commission percentage for vendors (0.00 to 100.00)';
COMMENT ON COLUMN commission_settings.admin_commission IS 'Commission percentage for admin/platform (0.00 to 100.00)';
COMMENT ON COLUMN commission_settings.updated_at IS 'Timestamp when settings were last updated (Asia/Manila timezone)';

-- Step 11: Create function to get current commission settings
CREATE OR REPLACE FUNCTION get_commission_settings()
RETURNS JSON AS $$
DECLARE
    settings_record RECORD;
BEGIN
    SELECT * INTO settings_record
    FROM commission_settings
    ORDER BY updated_at DESC
    LIMIT 1;
    
    IF settings_record IS NULL THEN
        -- Return defaults if no settings exist
        RETURN json_build_object(
            'success', true,
            'data', json_build_object(
                'vendor_commission', 1.00,
                'admin_commission', 0.50,
                'updated_at', NOW()
            )
        );
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'data', json_build_object(
            'id', settings_record.id,
            'vendor_commission', settings_record.vendor_commission,
            'admin_commission', settings_record.admin_commission,
            'updated_at', settings_record.updated_at,
            'created_at', settings_record.created_at
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 12: Create function to update commission settings
CREATE OR REPLACE FUNCTION update_commission_settings(
    p_vendor_commission DECIMAL(5,2),
    p_admin_commission DECIMAL(5,2)
)
RETURNS JSON AS $$
DECLARE
    updated_record RECORD;
BEGIN
    -- Validate commission values
    IF p_vendor_commission < 0 OR p_vendor_commission > 100 THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Vendor commission must be between 0.00 and 100.00',
            'error', 'INVALID_VENDOR_COMMISSION'
        );
    END IF;
    
    IF p_admin_commission < 0 OR p_admin_commission > 100 THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Admin commission must be between 0.00 and 100.00',
            'error', 'INVALID_ADMIN_COMMISSION'
        );
    END IF;
    
    -- Update or insert the single row
    INSERT INTO commission_settings (vendor_commission, admin_commission)
    VALUES (p_vendor_commission, p_admin_commission)
    ON CONFLICT (id) DO UPDATE SET
        vendor_commission = EXCLUDED.vendor_commission,
        admin_commission = EXCLUDED.admin_commission,
        updated_at = (NOW() AT TIME ZONE 'Asia/Manila');
    
    -- If no conflict (table was empty), get the inserted row
    SELECT * INTO updated_record
    FROM commission_settings
    ORDER BY updated_at DESC
    LIMIT 1;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Commission settings updated successfully',
        'data', json_build_object(
            'id', updated_record.id,
            'vendor_commission', updated_record.vendor_commission,
            'admin_commission', updated_record.admin_commission,
            'updated_at', updated_record.updated_at
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 13: Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION get_commission_settings() TO service_role;
GRANT EXECUTE ON FUNCTION get_commission_settings() TO authenticated;
GRANT EXECUTE ON FUNCTION update_commission_settings(DECIMAL, DECIMAL) TO service_role;

-- =====================================================
-- IMPORTANT NOTES:
-- 1. Run this script in Supabase SQL Editor
-- 2. The table will maintain only one row (most recent)
-- 3. Default values: vendor_commission = 1.00%, admin_commission = 0.50%
-- 4. Commission values are stored as percentages (0.00 to 100.00)
-- 5. Use get_commission_settings() function to retrieve current settings
-- 6. Use update_commission_settings() function to update settings
-- =====================================================
-- END OF MIGRATION SCRIPT
-- =====================================================





-- ============================================================================
-- FILE: create_staff_permissions_table.sql
-- ============================================================================

-- =====================================================
-- STAFF PERMISSIONS TABLE
-- =====================================================
-- Stores tab permissions for admin staff accounts (moderator role)

-- =====================================================
-- 1. CREATE STAFF_PERMISSIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.staff_permissions (
    id SERIAL PRIMARY KEY,
    staff_id INTEGER NOT NULL REFERENCES admin_accounts(id) ON DELETE CASCADE,
    dashboard BOOLEAN NOT NULL DEFAULT false,
    reports BOOLEAN NOT NULL DEFAULT false,
    transactions BOOLEAN NOT NULL DEFAULT false,
    topup BOOLEAN NOT NULL DEFAULT false,
    withdrawal_requests BOOLEAN NOT NULL DEFAULT false,
    settings BOOLEAN NOT NULL DEFAULT false,
    user_management BOOLEAN NOT NULL DEFAULT false,
    service_ports BOOLEAN NOT NULL DEFAULT false,
    admin_management BOOLEAN NOT NULL DEFAULT false,
    loaning BOOLEAN NOT NULL DEFAULT false,
    feedback BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Manila'),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Manila'),
    UNIQUE(staff_id)
);

-- =====================================================
-- 2. CREATE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_staff_permissions_staff_id ON public.staff_permissions(staff_id);

-- =====================================================
-- 3. ENABLE ROW LEVEL SECURITY
-- =====================================================
ALTER TABLE public.staff_permissions ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 4. CREATE RLS POLICIES
-- =====================================================
-- Policy for authenticated users (admins) to read and update permissions
DROP POLICY IF EXISTS "Allow authenticated read/update staff permissions" ON public.staff_permissions;
CREATE POLICY "Allow authenticated read/update staff permissions" ON public.staff_permissions
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- =====================================================
-- 5. CREATE FUNCTIONS
-- =====================================================

-- Function to get staff permissions
CREATE OR REPLACE FUNCTION public.get_staff_permissions(p_staff_id INTEGER)
RETURNS JSON AS $$
DECLARE
    permissions_data JSON;
BEGIN
    SELECT json_build_object(
        'id', id,
        'staff_id', staff_id,
        'dashboard', dashboard,
        'reports', reports,
        'transactions', transactions,
        'topup', topup,
        'withdrawal_requests', withdrawal_requests,
        'settings', settings,
        'user_management', user_management,
        'service_ports', service_ports,
        'admin_management', admin_management,
        'loaning', loaning,
        'feedback', feedback,
        'created_at', created_at,
        'updated_at', updated_at
    )
    INTO permissions_data
    FROM public.staff_permissions
    WHERE staff_id = p_staff_id;

    IF permissions_data IS NULL THEN
        -- Return default permissions (all false) if not found
        RETURN json_build_object(
            'id', NULL,
            'staff_id', p_staff_id,
            'dashboard', false,
            'reports', false,
            'transactions', false,
            'topup', false,
            'withdrawal_requests', false,
            'settings', false,
            'user_management', false,
            'service_ports', false,
            'admin_management', false,
            'loaning', false,
            'feedback', false,
            'created_at', NULL,
            'updated_at', NULL
        );
    END IF;

    RETURN json_build_object('success', true, 'data', permissions_data);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update staff permissions
CREATE OR REPLACE FUNCTION public.update_staff_permissions(
    p_staff_id INTEGER,
    p_dashboard BOOLEAN DEFAULT false,
    p_reports BOOLEAN DEFAULT false,
    p_transactions BOOLEAN DEFAULT false,
    p_topup BOOLEAN DEFAULT false,
    p_withdrawal_requests BOOLEAN DEFAULT false,
    p_settings BOOLEAN DEFAULT false,
    p_user_management BOOLEAN DEFAULT false,
    p_service_ports BOOLEAN DEFAULT false,
    p_admin_management BOOLEAN DEFAULT false,
    p_loaning BOOLEAN DEFAULT false,
    p_feedback BOOLEAN DEFAULT false
)
RETURNS JSON AS $$
DECLARE
    updated_permissions JSON;
BEGIN
    -- Use INSERT ... ON CONFLICT to handle both insert and update
    INSERT INTO public.staff_permissions (
        staff_id,
        dashboard,
        reports,
        transactions,
        topup,
        withdrawal_requests,
        settings,
        user_management,
        service_ports,
        admin_management,
        loaning,
        feedback,
        updated_at
    ) VALUES (
        p_staff_id,
        p_dashboard,
        p_reports,
        p_transactions,
        p_topup,
        p_withdrawal_requests,
        p_settings,
        p_user_management,
        p_service_ports,
        p_admin_management,
        p_loaning,
        p_feedback,
        (now() AT TIME ZONE 'Asia/Manila')
    )
    ON CONFLICT (staff_id) DO UPDATE SET
        dashboard = EXCLUDED.dashboard,
        reports = EXCLUDED.reports,
        transactions = EXCLUDED.transactions,
        topup = EXCLUDED.topup,
        withdrawal_requests = EXCLUDED.withdrawal_requests,
        settings = EXCLUDED.settings,
        user_management = EXCLUDED.user_management,
        service_ports = EXCLUDED.service_ports,
        admin_management = EXCLUDED.admin_management,
        loaning = EXCLUDED.loaning,
        feedback = EXCLUDED.feedback,
        updated_at = EXCLUDED.updated_at
    RETURNING json_build_object(
        'id', id,
        'staff_id', staff_id,
        'dashboard', dashboard,
        'reports', reports,
        'transactions', transactions,
        'topup', topup,
        'withdrawal_requests', withdrawal_requests,
        'settings', settings,
        'user_management', user_management,
        'service_ports', service_ports,
        'admin_management', admin_management,
        'loaning', loaning,
        'feedback', feedback,
        'updated_at', updated_at
    ) INTO updated_permissions;

    RETURN json_build_object(
        'success', true,
        'data', updated_permissions,
        'message', 'Staff permissions updated successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all staff permissions (for admin view)
CREATE OR REPLACE FUNCTION public.get_all_staff_permissions()
RETURNS JSON AS $$
DECLARE
    permissions_array JSON[];
    perm_record RECORD;
BEGIN
    permissions_array := ARRAY[]::JSON[];

    FOR perm_record IN
        SELECT 
            sp.*,
            aa.username,
            aa.full_name,
            aa.email
        FROM public.staff_permissions sp
        INNER JOIN public.admin_accounts aa ON sp.staff_id = aa.id
        WHERE aa.role = 'moderator'
        ORDER BY aa.full_name
    LOOP
        permissions_array := array_append(permissions_array, json_build_object(
            'id', perm_record.id,
            'staff_id', perm_record.staff_id,
            'username', perm_record.username,
            'full_name', perm_record.full_name,
            'email', perm_record.email,
            'dashboard', perm_record.dashboard,
            'reports', perm_record.reports,
            'transactions', perm_record.transactions,
            'topup', perm_record.topup,
            'withdrawal_requests', perm_record.withdrawal_requests,
            'settings', perm_record.settings,
            'user_management', perm_record.user_management,
            'service_ports', perm_record.service_ports,
            'admin_management', perm_record.admin_management,
            'loaning', perm_record.loaning,
            'feedback', perm_record.feedback,
            'updated_at', perm_record.updated_at
        ));
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'data', permissions_array
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;





-- ============================================================================
-- FILE: add_topup_fee_columns.sql
-- ============================================================================

-- =====================================================
-- Add fee columns to top_up_transactions table
-- =====================================================
-- This script adds vendor_earn and admin_earn columns
-- to track fees from top-up transactions
-- =====================================================

-- Step 1: Add vendor_earn and admin_earn columns
ALTER TABLE top_up_transactions 
ADD COLUMN IF NOT EXISTS vendor_earn DECIMAL(10,2) DEFAULT 0.00 CHECK (vendor_earn >= 0),
ADD COLUMN IF NOT EXISTS admin_earn DECIMAL(10,2) DEFAULT 0.00 CHECK (admin_earn >= 0);

-- Step 2: Update existing records to have 0.00 for fee columns (if any exist)
UPDATE top_up_transactions 
SET vendor_earn = 0.00, admin_earn = 0.00 
WHERE vendor_earn IS NULL OR admin_earn IS NULL;

-- Step 3: Drop the old function versions to avoid conflicts
DROP FUNCTION IF EXISTS process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT, VARCHAR);

-- Step 4: Create updated function with fee parameters
CREATE OR REPLACE FUNCTION process_top_up_transaction(
    p_student_id VARCHAR(50),
    p_amount DECIMAL(10,2),
    p_processed_by VARCHAR(100),
    p_notes TEXT DEFAULT NULL,
    p_transaction_type VARCHAR(20) DEFAULT 'top_up',
    p_admin_earn DECIMAL(10,2) DEFAULT 0.00,
    p_vendor_earn DECIMAL(10,2) DEFAULT 0.00
) RETURNS JSON AS $$
DECLARE
    current_balance DECIMAL(10,2);
    new_balance DECIMAL(10,2);
    transaction_id INTEGER;
    student_exists BOOLEAN;
    valid_transaction_type BOOLEAN;
BEGIN
    -- Validate transaction type
    valid_transaction_type := p_transaction_type IN ('top_up', 'top_up_gcash', 'top_up_services');
    IF NOT valid_transaction_type THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Invalid transaction type. Must be: top_up, top_up_gcash, or top_up_services',
            'error', 'INVALID_TRANSACTION_TYPE'
        );
    END IF;
    
    -- Validate fee amounts
    IF p_admin_earn < 0 OR p_vendor_earn < 0 THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Fee amounts cannot be negative',
            'error', 'INVALID_FEE_AMOUNT'
        );
    END IF;
    
    -- Check if student exists
    SELECT EXISTS(SELECT 1 FROM auth_students WHERE student_id = p_student_id) INTO student_exists;
    
    IF NOT student_exists THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Student not found',
            'error', 'STUDENT_NOT_FOUND'
        );
    END IF;
    
    -- Get current balance
    SELECT COALESCE(balance, 0) INTO current_balance
    FROM auth_students 
    WHERE student_id = p_student_id;
    
    -- Calculate new balance
    new_balance := current_balance + p_amount;
    
    -- Start transaction
    BEGIN
        -- Update student balance
        UPDATE auth_students 
        SET balance = new_balance,
            updated_at = NOW()
        WHERE student_id = p_student_id;
        
        -- Insert transaction record with fee information
        INSERT INTO top_up_transactions (
            student_id,
            amount,
            previous_balance,
            new_balance,
            transaction_type,
            processed_by,
            notes,
            admin_earn,
            vendor_earn,
            created_at
        ) VALUES (
            p_student_id,
            p_amount,
            current_balance,
            new_balance,
            p_transaction_type,
            p_processed_by,
            p_notes,
            COALESCE(p_admin_earn, 0.00),
            COALESCE(p_vendor_earn, 0.00),
            NOW()
        ) RETURNING id INTO transaction_id;
        
        -- Return success response
        RETURN json_build_object(
            'success', true,
            'message', 'Top-up processed successfully',
            'data', json_build_object(
                'transaction_id', transaction_id,
                'student_id', p_student_id,
                'amount', p_amount,
                'previous_balance', current_balance,
                'new_balance', new_balance,
                'transaction_type', p_transaction_type,
                'processed_by', p_processed_by,
                'admin_earn', COALESCE(p_admin_earn, 0.00),
                'vendor_earn', COALESCE(p_vendor_earn, 0.00),
                'created_at', NOW()
            )
        );
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Rollback on error
            RETURN json_build_object(
                'success', false,
                'message', 'Failed to process top-up: ' || SQLERRM,
                'error', 'PROCESSING_ERROR'
            );
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Grant execute permissions on the updated function
GRANT EXECUTE ON FUNCTION process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT, VARCHAR, DECIMAL, DECIMAL) TO service_role;
GRANT EXECUTE ON FUNCTION process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT, VARCHAR, DECIMAL, DECIMAL) TO authenticated;

-- Step 6: Add comments to the new columns
COMMENT ON COLUMN top_up_transactions.vendor_earn IS 'Fee amount earned by vendor/service provider (if applicable)';
COMMENT ON COLUMN top_up_transactions.admin_earn IS 'Fee amount earned by admin/platform from the top-up transaction';

-- Step 7: Update the get_recent_top_up_transactions function to include fee columns
CREATE OR REPLACE FUNCTION get_recent_top_up_transactions(
    p_limit INTEGER DEFAULT 20
) RETURNS JSON AS $$
DECLARE
    transactions JSON;
BEGIN
    -- Get recent transactions with student names and fee information
    SELECT json_agg(
        json_build_object(
            'id', t.id,
            'student_id', t.student_id,
            'student_name', COALESCE(s.name, 'Unknown Student'),
            'amount', t.amount,
            'previous_balance', t.previous_balance,
            'new_balance', t.new_balance,
            'transaction_type', t.transaction_type,
            'processed_by', t.processed_by,
            'notes', t.notes,
            'admin_earn', COALESCE(t.admin_earn, 0.00),
            'vendor_earn', COALESCE(t.vendor_earn, 0.00),
            'created_at', t.created_at
        )
    ) INTO transactions
    FROM (
        SELECT *
        FROM top_up_transactions 
        ORDER BY created_at DESC
        LIMIT p_limit
    ) t
    LEFT JOIN auth_students s ON t.student_id = s.student_id;
    
    RETURN json_build_object(
        'success', true,
        'data', COALESCE(transactions, '[]'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- IMPORTANT NOTES:
-- 1. Run this script in Supabase SQL Editor
-- 2. The function now accepts optional admin_earn and vendor_earn parameters
-- 3. For manual admin top-ups, pass the calculated admin_earn fee
-- 4. For GCash/other payment methods, set fees as needed
-- =====================================================
-- END OF MIGRATION SCRIPT
-- =====================================================





-- ============================================================================
-- FILE: update_top_up_transactions_for_services.sql
-- ============================================================================

-- =====================================================
-- Update top_up_transactions table to support top_up_services
-- =====================================================
-- This script updates the transaction_type constraint to allow
-- 'top_up', 'top_up_gcash', and 'top_up_services'
-- =====================================================

-- Step 1: Drop the existing CHECK constraint
ALTER TABLE top_up_transactions 
DROP CONSTRAINT IF EXISTS top_up_transactions_transaction_type_check;

-- Step 2: Add new CHECK constraint that allows multiple transaction types
ALTER TABLE top_up_transactions
ADD CONSTRAINT top_up_transactions_transaction_type_check 
CHECK (transaction_type IN ('top_up', 'top_up_gcash', 'top_up_services'));

-- Step 3: Drop all existing versions of the function to avoid overloading conflicts
-- Drop the old 4-parameter version
DROP FUNCTION IF EXISTS process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT);
-- Drop the new 5-parameter version if it exists
DROP FUNCTION IF EXISTS process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT, VARCHAR);

-- Step 4: Create the new RPC function with transaction_type as optional parameter
-- If transaction_type is not provided, default to 'top_up' for backward compatibility
CREATE OR REPLACE FUNCTION process_top_up_transaction(
    p_student_id VARCHAR(50),
    p_amount DECIMAL(10,2),
    p_processed_by VARCHAR(100),
    p_notes TEXT DEFAULT NULL,
    p_transaction_type VARCHAR(20) DEFAULT 'top_up'
) RETURNS JSON AS $$
DECLARE
    current_balance DECIMAL(10,2);
    new_balance DECIMAL(10,2);
    transaction_id INTEGER;
    student_exists BOOLEAN;
    valid_transaction_type BOOLEAN;
BEGIN
    -- Validate transaction type
    valid_transaction_type := p_transaction_type IN ('top_up', 'top_up_gcash', 'top_up_services');
    IF NOT valid_transaction_type THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Invalid transaction type. Must be: top_up, top_up_gcash, or top_up_services',
            'error', 'INVALID_TRANSACTION_TYPE'
        );
    END IF;
    
    -- Check if student exists
    SELECT EXISTS(SELECT 1 FROM auth_students WHERE student_id = p_student_id) INTO student_exists;
    
    IF NOT student_exists THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Student not found',
            'error', 'STUDENT_NOT_FOUND'
        );
    END IF;
    
    -- Get current balance
    SELECT COALESCE(balance, 0) INTO current_balance
    FROM auth_students 
    WHERE student_id = p_student_id;
    
    -- Calculate new balance
    new_balance := current_balance + p_amount;
    
    -- Start transaction
    BEGIN
        -- Update student balance
        UPDATE auth_students 
        SET balance = new_balance,
            updated_at = NOW()
        WHERE student_id = p_student_id;
        
        -- Insert transaction record
        INSERT INTO top_up_transactions (
            student_id,
            amount,
            previous_balance,
            new_balance,
            transaction_type,
            processed_by,
            notes,
            created_at
        ) VALUES (
            p_student_id,
            p_amount,
            current_balance,
            new_balance,
            p_transaction_type,
            p_processed_by,
            p_notes,
            NOW()
        ) RETURNING id INTO transaction_id;
        
        -- Return success response
        RETURN json_build_object(
            'success', true,
            'message', 'Top-up processed successfully',
            'data', json_build_object(
                'transaction_id', transaction_id,
                'student_id', p_student_id,
                'amount', p_amount,
                'previous_balance', current_balance,
                'new_balance', new_balance,
                'transaction_type', p_transaction_type,
                'processed_by', p_processed_by,
                'created_at', NOW()
            )
        );
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Rollback on error
            RETURN json_build_object(
                'success', false,
                'message', 'Failed to process top-up: ' || SQLERRM,
                'error', 'PROCESSING_ERROR'
            );
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 6: Update the comment to reflect the new transaction types
COMMENT ON COLUMN top_up_transactions.transaction_type IS 'Type of transaction: top_up (admin), top_up_gcash (GCash payment), or top_up_services (service account)';

-- Step 7: Grant execute permissions on the updated function
GRANT EXECUTE ON FUNCTION process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT, VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT, VARCHAR) TO authenticated;

-- =====================================================
-- IMPORTANT NOTES:
-- 1. After running this script, you may need to restart your Supabase connection
--    or wait a few seconds for the function cache to clear
-- 2. The function now accepts an optional 5th parameter (p_transaction_type)
--    If not provided, it defaults to 'top_up' for backward compatibility
-- 3. Valid transaction types: 'top_up', 'top_up_gcash', 'top_up_services'
-- =====================================================
-- END OF UPDATE SCRIPT
-- =====================================================





-- ============================================================================
-- END OF CONSOLIDATED SCHEMA
-- ============================================================================
-- All tables, functions, triggers, and policies have been created
-- ============================================================================
