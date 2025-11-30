-- =====================================================
-- EVSU Campus Pay - Scanner Function Conflict Fix
-- =====================================================
-- This file fixes the function overloading conflict
-- Run this in your Supabase SQL editor
-- =====================================================

-- Drop all existing conflicting functions
DROP FUNCTION IF EXISTS assign_scanner_to_service(VARCHAR, INTEGER);
DROP FUNCTION IF EXISTS assign_scanner_to_service(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS unassign_scanner_from_service(VARCHAR);
DROP FUNCTION IF EXISTS unassign_scanner_from_service(INTEGER);

-- Create the correct function with VARCHAR, INTEGER signature
CREATE OR REPLACE FUNCTION assign_scanner_to_service(
    scanner_device_id VARCHAR(50),
    service_account_id INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
    scanner_exists BOOLEAN;
    service_exists BOOLEAN;
    scanner_already_assigned BOOLEAN;
BEGIN
    -- Check if scanner exists, if not create it
    SELECT EXISTS(SELECT 1 FROM scanner_devices WHERE scanner_id = scanner_device_id) INTO scanner_exists;
    
    IF NOT scanner_exists THEN
        -- Create the scanner if it doesn't exist
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

-- Create the correct unassign function with VARCHAR signature
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION assign_scanner_to_service(VARCHAR, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION assign_scanner_to_service(VARCHAR, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION unassign_scanner_from_service(VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION unassign_scanner_from_service(VARCHAR) TO authenticated;

-- =====================================================
-- END OF FUNCTION CONFLICT FIX
-- =====================================================
