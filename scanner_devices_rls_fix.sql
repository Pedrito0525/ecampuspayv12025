-- =====================================================
-- EVSU Campus Pay - Scanner Devices RLS Fix
-- =====================================================
-- This file fixes the Row Level Security policies for scanner_devices
-- to allow proper insertion and assignment functionality
-- =====================================================

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "service_role_full_access_scanner_devices" ON scanner_devices;
DROP POLICY IF EXISTS "authenticated_full_access_scanner_devices" ON scanner_devices;
DROP POLICY IF EXISTS "anon_read_available_scanners" ON scanner_devices;

-- Create more permissive policies for scanner_devices
-- Allow service_role full access
CREATE POLICY "service_role_scanner_full_access" ON scanner_devices
    FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

-- Allow authenticated users full access
CREATE POLICY "authenticated_scanner_full_access" ON scanner_devices
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- Allow anon users to read available scanners only
CREATE POLICY "anon_scanner_read_available" ON scanner_devices
    FOR SELECT USING (auth.role() = 'anon' AND status = 'Available');

-- Alternative: If you want to disable RLS temporarily for testing
-- ALTER TABLE scanner_devices DISABLE ROW LEVEL SECURITY;

-- =====================================================
-- ADDITIONAL FIXES FOR SCANNER ASSIGNMENT
-- =====================================================

-- Update the assign_scanner_to_service function to handle RLS better
CREATE OR REPLACE FUNCTION assign_scanner_to_service(
    scanner_device_id VARCHAR(50),
    service_account_id INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
    scanner_exists BOOLEAN;
    service_exists BOOLEAN;
    scanner_already_assigned BOOLEAN;
    scanner_record RECORD;
BEGIN
    -- Check if scanner exists
    SELECT EXISTS(SELECT 1 FROM scanner_devices WHERE scanner_id = scanner_device_id) INTO scanner_exists;
    
    -- If scanner doesn't exist, create it
    IF NOT scanner_exists THEN
        INSERT INTO scanner_devices (
            scanner_id,
            device_name,
            device_type,
            model,
            serial_number,
            status,
            notes
        ) VALUES (
            scanner_device_id,
            'RFID Bluetooth Scanner ' || REPLACE(scanner_device_id, 'EvsuPay', ''),
            'RFID_Bluetooth_Scanner',
            'ESP32 RFID',
            'ESP' || LPAD(REPLACE(scanner_device_id, 'EvsuPay', ''), 3, '0'),
            'Available',
            'Ready for assignment'
        );
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update the unassign_scanner_from_service function
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
    
    -- Get assigned service ID
    SELECT assigned_service_id INTO assigned_service_id
    FROM scanner_devices 
    WHERE scanner_id = scanner_device_id;
    
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- GRANT ADDITIONAL PERMISSIONS
-- =====================================================

-- Grant additional permissions for scanner operations
GRANT USAGE ON SEQUENCE scanner_devices_id_seq TO service_role;
GRANT USAGE ON SEQUENCE scanner_devices_id_seq TO authenticated;

-- Ensure the functions have proper permissions
GRANT EXECUTE ON FUNCTION assign_scanner_to_service(VARCHAR, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION assign_scanner_to_service(VARCHAR, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION unassign_scanner_from_service(VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION unassign_scanner_from_service(VARCHAR) TO authenticated;

-- =====================================================
-- TEST DATA INSERTION (Optional)
-- =====================================================

-- Insert test scanners if they don't exist
DO $$
BEGIN
    FOR i IN 1..5 LOOP
        INSERT INTO scanner_devices (
            scanner_id,
            device_name,
            device_type,
            model,
            serial_number,
            status,
            notes
        ) VALUES (
            'EvsuPay' || i,
            'RFID Bluetooth Scanner ' || i,
            'RFID_Bluetooth_Scanner',
            'ESP32 RFID',
            'ESP' || LPAD(i::text, 3, '0'),
            'Available',
            'Ready for assignment'
        ) ON CONFLICT (scanner_id) DO NOTHING;
    END LOOP;
END $$;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================

-- Check if policies are working
-- SELECT * FROM scanner_devices LIMIT 5;

-- Test the assignment function
-- SELECT assign_scanner_to_service('EvsuPay1', 1);

-- =====================================================
-- END OF RLS FIX
-- =====================================================
