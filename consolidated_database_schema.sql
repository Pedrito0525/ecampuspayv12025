-- =====================================================
-- EVSU Campus Pay - Consolidated Database Schema
-- =====================================================
-- This file contains all essential SQL queries for the EVSU Campus Pay system
-- Generated from analysis of all SQL files in the project
-- =====================================================

-- =====================================================
-- 1. MAIN DATABASE SCHEMA
-- =====================================================

-- Create student_info table (for CSV import and autofill)
CREATE TABLE IF NOT EXISTS student_info (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    course VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create auth_students table (for authentication registration)
CREATE TABLE IF NOT EXISTS auth_students (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) UNIQUE NOT NULL,
    name TEXT NOT NULL, -- Encrypted data
    email TEXT UNIQUE NOT NULL, -- Encrypted data
    course TEXT NOT NULL, -- Encrypted data
    rfid_id TEXT UNIQUE, -- Encrypted data
    password TEXT NOT NULL, -- Hashed password (SHA-256 with salt)
    auth_user_id UUID, -- References auth.users(id) but no FK constraint
    balance DECIMAL(10,2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT true,
    taptopay BOOLEAN DEFAULT true, -- Enable/disable tap to pay functionality
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create service_accounts table (for service management)
CREATE TABLE IF NOT EXISTS service_accounts (
    id SERIAL PRIMARY KEY,
    service_name VARCHAR(255) NOT NULL,
    service_category VARCHAR(100) NOT NULL, -- 'School Org', 'Vendor', 'Campus Service Units'
    operational_type VARCHAR(20) NOT NULL, -- 'Main' or 'Sub'
    main_service_id INTEGER REFERENCES service_accounts(id) ON DELETE CASCADE, -- NULL for main accounts
    contact_person VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL, -- Hashed password
    balance DECIMAL(10,2) DEFAULT 0.00, -- Only for main accounts
    is_active BOOLEAN DEFAULT true,
    scanner_id VARCHAR(100) UNIQUE, -- Assigned scanner ID
    commission_rate DECIMAL(5,2) DEFAULT 0.00, -- Commission percentage
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create scanner_devices table (for RFID Bluetooth scanner management)
CREATE TABLE IF NOT EXISTS scanner_devices (
    id SERIAL PRIMARY KEY,
    scanner_id VARCHAR(50) UNIQUE NOT NULL, -- EvsuPay1, EvsuPay2, etc.
    device_name VARCHAR(255) NOT NULL, -- RFID Bluetooth Scanner 1, etc.
    device_type VARCHAR(50) DEFAULT 'RFID_Bluetooth_Scanner', -- Only RFID Bluetooth scanners
    model VARCHAR(100) DEFAULT 'ESP32 RFID',
    serial_number VARCHAR(100) UNIQUE NOT NULL, -- ESP001, ESP002, etc.
    status VARCHAR(20) DEFAULT 'Available', -- Available, Assigned, Maintenance
    notes TEXT,
    assigned_service_id INTEGER REFERENCES service_accounts(id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 2. INDEXES FOR PERFORMANCE
-- =====================================================

-- student_info table indexes
CREATE INDEX IF NOT EXISTS idx_student_info_student_id ON student_info(student_id);
CREATE INDEX IF NOT EXISTS idx_student_info_email ON student_info(email);

-- auth_students table indexes
CREATE INDEX IF NOT EXISTS idx_auth_students_student_id ON auth_students(student_id);
CREATE INDEX IF NOT EXISTS idx_auth_students_email ON auth_students(email);
CREATE INDEX IF NOT EXISTS idx_auth_students_rfid_id ON auth_students(rfid_id);
CREATE INDEX IF NOT EXISTS idx_auth_students_auth_user_id ON auth_students(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_auth_students_is_active ON auth_students(is_active);
CREATE INDEX IF NOT EXISTS idx_auth_students_taptopay ON auth_students(taptopay);

-- service_accounts table indexes
CREATE INDEX IF NOT EXISTS idx_service_accounts_service_name ON service_accounts(service_name);
CREATE INDEX IF NOT EXISTS idx_service_accounts_operational_type ON service_accounts(operational_type);
CREATE INDEX IF NOT EXISTS idx_service_accounts_main_service_id ON service_accounts(main_service_id);
CREATE INDEX IF NOT EXISTS idx_service_accounts_username ON service_accounts(username);
CREATE INDEX IF NOT EXISTS idx_service_accounts_scanner_id ON service_accounts(scanner_id);
CREATE INDEX IF NOT EXISTS idx_service_accounts_is_active ON service_accounts(is_active);

-- scanner_devices table indexes
CREATE INDEX IF NOT EXISTS idx_scanner_devices_scanner_id ON scanner_devices(scanner_id);
CREATE INDEX IF NOT EXISTS idx_scanner_devices_device_type ON scanner_devices(device_type);
CREATE INDEX IF NOT EXISTS idx_scanner_devices_status ON scanner_devices(status);
CREATE INDEX IF NOT EXISTS idx_scanner_devices_assigned_service_id ON scanner_devices(assigned_service_id);
CREATE INDEX IF NOT EXISTS idx_scanner_devices_serial_number ON scanner_devices(serial_number);

-- =====================================================
-- 3. CONSTRAINTS
-- =====================================================

-- Add constraint to ensure sub accounts have a main service
ALTER TABLE service_accounts 
ADD CONSTRAINT check_sub_account_has_main 
CHECK (
    (operational_type = 'Main' AND main_service_id IS NULL) OR 
    (operational_type = 'Sub' AND main_service_id IS NOT NULL)
);

-- Add constraint to ensure sub accounts don't have balance
ALTER TABLE service_accounts 
ADD CONSTRAINT check_sub_account_no_balance 
CHECK (
    (operational_type = 'Main') OR 
    (operational_type = 'Sub' AND balance = 0.00)
);

-- Add constraint for auth_user_id format validation
ALTER TABLE auth_students 
ADD CONSTRAINT auth_students_auth_user_id_check 
CHECK (auth_user_id IS NOT NULL AND auth_user_id::text ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

-- scanner_devices table constraints
ALTER TABLE scanner_devices 
ADD CONSTRAINT check_device_type 
CHECK (device_type = 'RFID_Bluetooth_Scanner');

ALTER TABLE scanner_devices 
ADD CONSTRAINT check_status 
CHECK (status IN ('Available', 'Assigned', 'Maintenance'));

ALTER TABLE scanner_devices 
ADD CONSTRAINT check_scanner_id_format 
CHECK (scanner_id ~ '^EvsuPay[0-9]+$');

-- =====================================================
-- 4. FUNCTIONS
-- =====================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Function to delete auth users
CREATE OR REPLACE FUNCTION delete_auth_user(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  -- Delete from auth.users table
  DELETE FROM auth.users WHERE id = user_id;
  
  -- Return true if a row was deleted
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to transfer sub account balance to main account
CREATE OR REPLACE FUNCTION transfer_sub_account_balance(
    sub_account_id INTEGER,
    amount DECIMAL(10,2)
) RETURNS BOOLEAN AS $$
DECLARE
    main_account_id INTEGER;
    current_main_balance DECIMAL(10,2);
BEGIN
    -- Get the main account ID for this sub account
    SELECT main_service_id INTO main_account_id
    FROM service_accounts 
    WHERE id = sub_account_id AND operational_type = 'Sub';
    
    IF main_account_id IS NULL THEN
        RAISE EXCEPTION 'Sub account not found or not a sub account';
    END IF;
    
    -- Get current main account balance
    SELECT balance INTO current_main_balance
    FROM service_accounts 
    WHERE id = main_account_id;
    
    -- Update main account balance
    UPDATE service_accounts 
    SET balance = current_main_balance + amount,
        updated_at = NOW()
    WHERE id = main_account_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to get total balance for main account (including sub accounts)
CREATE OR REPLACE FUNCTION get_main_account_total_balance(main_account_id INTEGER)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    main_balance DECIMAL(10,2);
    sub_balance DECIMAL(10,2);
BEGIN
    -- Get main account balance
    SELECT COALESCE(balance, 0) INTO main_balance
    FROM service_accounts 
    WHERE id = main_account_id AND operational_type = 'Main';
    
    -- Get total from sub accounts
    SELECT COALESCE(SUM(balance), 0) INTO sub_balance
    FROM service_accounts 
    WHERE main_service_id = main_account_id AND operational_type = 'Sub';
    
    RETURN COALESCE(main_balance, 0) + COALESCE(sub_balance, 0);
END;
$$ LANGUAGE plpgsql;

-- Function to assign scanner to service
CREATE OR REPLACE FUNCTION assign_scanner_to_service(
    scanner_device_id VARCHAR(50),
    service_account_id INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
    scanner_exists BOOLEAN;
    service_exists BOOLEAN;
    scanner_already_assigned BOOLEAN;
BEGIN
    -- Check if scanner exists
    SELECT EXISTS(SELECT 1 FROM scanner_devices WHERE scanner_id = scanner_device_id) INTO scanner_exists;
    IF NOT scanner_exists THEN
        RAISE EXCEPTION 'Scanner % not found', scanner_device_id;
    END IF;
    
    -- Check if service exists
    SELECT EXISTS(SELECT 1 FROM service_accounts WHERE id = service_account_id) INTO service_exists;
    IF NOT service_exists THEN
        RAISE EXCEPTION 'Service account % not found', service_account_id;
    END IF;
    
    -- Check if scanner is already assigned
    SELECT EXISTS(SELECT 1 FROM scanner_devices WHERE scanner_id = scanner_device_id AND status = 'Assigned') INTO scanner_already_assigned;
    IF scanner_already_assigned THEN
        RAISE EXCEPTION 'Scanner % is already assigned to another service', scanner_device_id;
    END IF;
    
    -- Update scanner status and assignment
    UPDATE scanner_devices 
    SET status = 'Assigned',
        assigned_service_id = service_account_id,
        updated_at = NOW()
    WHERE scanner_id = scanner_device_id;
    
    -- Update service account with scanner_id
    UPDATE service_accounts 
    SET scanner_id = scanner_device_id,
        updated_at = NOW()
    WHERE id = service_account_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Function to unassign scanner from service
CREATE OR REPLACE FUNCTION unassign_scanner_from_service(
    scanner_device_id VARCHAR(50)
) RETURNS BOOLEAN AS $$
DECLARE
    scanner_exists BOOLEAN;
    assigned_service_id INTEGER;
BEGIN
    -- Check if scanner exists
    SELECT EXISTS(SELECT 1 FROM scanner_devices WHERE scanner_id = scanner_device_id) INTO scanner_exists;
    IF NOT scanner_exists THEN
        RAISE EXCEPTION 'Scanner % not found', scanner_device_id;
    END IF;
    
    -- Get assigned service ID (using table.column syntax to avoid ambiguity)
    SELECT scanner_devices.assigned_service_id INTO assigned_service_id
    FROM scanner_devices 
    WHERE scanner_devices.scanner_id = scanner_device_id;
    
    -- Update scanner status
    UPDATE scanner_devices 
    SET status = 'Available',
        assigned_service_id = NULL,
        updated_at = NOW()
    WHERE scanner_id = scanner_device_id;
    
    -- Clear scanner_id from service account
    IF assigned_service_id IS NOT NULL THEN
        UPDATE service_accounts 
        SET scanner_id = NULL,
            updated_at = NOW()
        WHERE id = assigned_service_id;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. TRIGGERS
-- =====================================================

-- Create triggers to automatically update updated_at
CREATE TRIGGER update_student_info_updated_at 
    BEFORE UPDATE ON student_info 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_auth_students_updated_at 
    BEFORE UPDATE ON auth_students 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_service_accounts_updated_at 
    BEFORE UPDATE ON service_accounts 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_scanner_devices_updated_at 
    BEFORE UPDATE ON scanner_devices 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 6. VIEWS
-- =====================================================

-- Create a view for public student directory (without sensitive info)
CREATE OR REPLACE VIEW public_student_directory AS
SELECT 
    student_id,
    name,
    course,
    created_at
FROM auth_students
WHERE rfid_id IS NOT NULL AND is_active = true; -- Only show active students with RFID cards

-- Create a view for service hierarchy
CREATE OR REPLACE VIEW service_hierarchy AS
SELECT 
    sa.id,
    sa.service_name,
    sa.service_category,
    sa.operational_type,
    sa.main_service_id,
    main_sa.service_name as main_service_name,
    sa.contact_person,
    sa.email,
    sa.phone,
    sa.username,
    sa.balance,
    sa.is_active,
    sa.scanner_id,
    sa.commission_rate,
    sa.created_at,
    sa.updated_at
FROM service_accounts sa
LEFT JOIN service_accounts main_sa ON sa.main_service_id = main_sa.id
ORDER BY sa.operational_type, sa.service_name;

-- Create a view for scanner assignments
CREATE OR REPLACE VIEW scanner_assignments AS
SELECT 
    sd.id as scanner_device_id,
    sd.scanner_id,
    sd.device_name,
    sd.device_type,
    sd.model,
    sd.serial_number,
    sd.status,
    sd.notes,
    sd.assigned_service_id,
    sa.service_name as assigned_service_name,
    sa.service_category as assigned_service_category,
    sa.operational_type as assigned_service_type,
    sd.created_at as scanner_created_at,
    sd.updated_at as scanner_updated_at
FROM scanner_devices sd
LEFT JOIN service_accounts sa ON sd.assigned_service_id = sa.id
ORDER BY sd.scanner_id;

-- =====================================================
-- 7. ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on tables
ALTER TABLE student_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE auth_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE scanner_devices ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 8. RLS POLICIES
-- =====================================================

-- student_info table policies (for CSV import/autofill)
CREATE POLICY "Service role can manage student_info" ON student_info
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow all operations on student_info" ON student_info
    FOR ALL USING (true) WITH CHECK (true);

-- auth_students table policies
CREATE POLICY "Service role can do everything on auth_students" ON auth_students
FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "Allow all operations on auth_students" ON auth_students
    FOR ALL USING (true) WITH CHECK (true);

-- service_accounts table policies
CREATE POLICY "service_role_full_access" ON service_accounts
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "authenticated_full_access" ON service_accounts
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "anon_read_active" ON service_accounts
    FOR SELECT USING (auth.role() = 'anon' AND is_active = true);

-- scanner_devices table policies
CREATE POLICY "service_role_full_access_scanner_devices" ON scanner_devices
    FOR ALL USING (auth.role() = 'service_role');

CREATE POLICY "authenticated_full_access_scanner_devices" ON scanner_devices
    FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "anon_read_available_scanners" ON scanner_devices
    FOR SELECT USING (auth.role() = 'anon' AND status = 'Available');

-- =====================================================
-- 9. PERMISSIONS
-- =====================================================

-- Grant permissions on tables
GRANT ALL ON student_info TO service_role;
GRANT ALL ON student_info TO authenticated;
GRANT ALL ON student_info TO anon;

GRANT ALL ON auth_students TO service_role;
GRANT ALL ON auth_students TO authenticated;
GRANT ALL ON auth_students TO anon;

GRANT ALL ON service_accounts TO service_role;
GRANT ALL ON service_accounts TO authenticated;
GRANT SELECT ON service_accounts TO anon;

GRANT ALL ON scanner_devices TO service_role;
GRANT ALL ON scanner_devices TO authenticated;
GRANT SELECT ON scanner_devices TO anon;

-- Grant permissions on views
GRANT SELECT ON public_student_directory TO authenticated;
GRANT SELECT ON service_hierarchy TO service_role;
GRANT SELECT ON service_hierarchy TO authenticated;
GRANT SELECT ON service_hierarchy TO anon;
GRANT SELECT ON scanner_assignments TO service_role;
GRANT SELECT ON scanner_assignments TO authenticated;
GRANT SELECT ON scanner_assignments TO anon;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION delete_auth_user(UUID) TO service_role;
GRANT EXECUTE ON FUNCTION transfer_sub_account_balance(INTEGER, DECIMAL) TO service_role;
GRANT EXECUTE ON FUNCTION transfer_sub_account_balance(INTEGER, DECIMAL) TO authenticated;
GRANT EXECUTE ON FUNCTION get_main_account_total_balance(INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION get_main_account_total_balance(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION assign_scanner_to_service(VARCHAR, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION assign_scanner_to_service(VARCHAR, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION unassign_scanner_from_service(VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION unassign_scanner_from_service(VARCHAR) TO authenticated;

-- =====================================================
-- 10. COMMENTS
-- =====================================================

-- Add comments to tables
COMMENT ON TABLE student_info IS 'Student information table for CSV import and autofill functionality';
COMMENT ON TABLE auth_students IS 'Student authentication table with encrypted data and RFID support';
COMMENT ON TABLE service_accounts IS 'Service accounts table with main/sub hierarchy support';
COMMENT ON TABLE scanner_devices IS 'RFID Bluetooth scanner devices table for EvsuPay1-100 scanner management';

-- Add comments to columns
COMMENT ON COLUMN auth_students.taptopay IS 'Enable/disable tap to pay functionality for RFID payments';
COMMENT ON COLUMN service_accounts.operational_type IS 'Main or Sub account type';
COMMENT ON COLUMN service_accounts.main_service_id IS 'Reference to main account for sub accounts';
COMMENT ON COLUMN scanner_devices.scanner_id IS 'Unique scanner identifier (EvsuPay1, EvsuPay2, etc.)';
COMMENT ON COLUMN scanner_devices.device_type IS 'Type of device (only RFID_Bluetooth_Scanner)';
COMMENT ON COLUMN scanner_devices.status IS 'Current status: Available, Assigned, or Maintenance';
COMMENT ON COLUMN scanner_devices.assigned_service_id IS 'ID of service this scanner is assigned to (NULL if available)';

-- =====================================================
-- 11. ENABLE EXTENSIONS
-- =====================================================
-- Enable pgcrypto extension for password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- =====================================================
-- 12. ADMIN ACCOUNTS TABLE
-- =====================================================
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
    notes TEXT
);

-- =====================================================
-- 12. ADMIN ACCOUNTS INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_admin_accounts_username ON admin_accounts(username);
CREATE INDEX IF NOT EXISTS idx_admin_accounts_email ON admin_accounts(email);
CREATE INDEX IF NOT EXISTS idx_admin_accounts_role ON admin_accounts(role);
CREATE INDEX IF NOT EXISTS idx_admin_accounts_is_active ON admin_accounts(is_active);
CREATE INDEX IF NOT EXISTS idx_admin_accounts_last_login ON admin_accounts(last_login);

-- =====================================================
-- 13. ADMIN ACCOUNTS TRIGGERS
-- =====================================================
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
-- 14. ADMIN ACCOUNTS FUNCTIONS
-- =====================================================

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
-- 15. ADMIN ACCOUNTS RLS AND PERMISSIONS
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

-- Grant permissions
GRANT ALL ON TABLE admin_accounts TO service_role;
GRANT SELECT ON TABLE admin_accounts TO authenticated;
GRANT USAGE ON SEQUENCE admin_accounts_id_seq TO service_role;
GRANT USAGE ON SEQUENCE admin_accounts_id_seq TO authenticated;
GRANT EXECUTE ON FUNCTION authenticate_admin(VARCHAR, VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION authenticate_admin(VARCHAR, VARCHAR) TO authenticated;
GRANT EXECUTE ON FUNCTION update_admin_credentials(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION update_admin_credentials(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO authenticated;

-- =====================================================
-- 16. INSERT DEFAULT ADMIN ACCOUNT
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
) ON CONFLICT (username) DO NOTHING;

-- =====================================================
-- 17. ADMIN ACCOUNTS COMMENTS
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
-- END OF CONSOLIDATED SCHEMA
-- =====================================================
create table if not exists public.system_update_settings (
  id integer primary key default 1,
  maintenance_mode boolean not null default false,
  force_update_mode boolean not null default false,
  disable_all_logins boolean not null default false,
  updated_by text,
  updated_at timestamptz default now()
);
insert into public.system_update_settings (id) values (1) on conflict (id) do nothing;
alter table public.system_update_settings enable row level security;
drop policy if exists "Allow read to all" on public.system_update_settings;
create policy "Allow read to all" on public.system_update_settings for select using (true);
drop policy if exists "Allow update via service key" on public.system_update_settings;
create policy "Allow update via service key" on public.system_update_settings for all to authenticated using (true) with check (true);