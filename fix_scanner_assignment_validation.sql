-- =====================================================
-- Fix Scanner Assignment Validation
-- =====================================================
-- This fixes the assign_scanner_to_service function to properly check
-- if a scanner is already assigned to either an admin account or service account
-- =====================================================

-- Update the assign_scanner_to_service function to check both admin_accounts and service_accounts
CREATE OR REPLACE FUNCTION assign_scanner_to_service(
    scanner_device_id VARCHAR(50),
    service_account_id INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
    scanner_exists BOOLEAN;
    service_exists BOOLEAN;
    scanner_assigned_to_admin BOOLEAN;
    scanner_assigned_to_service BOOLEAN;
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
    
    -- Check if scanner is already assigned to an admin account
    SELECT EXISTS(
        SELECT 1 FROM admin_accounts 
        WHERE scanner_id = scanner_device_id 
        AND scanner_id IS NOT NULL 
        AND scanner_id != ''
    ) INTO scanner_assigned_to_admin;
    
    -- Check if scanner is already assigned to a different service account
    SELECT EXISTS(
        SELECT 1 FROM service_accounts 
        WHERE scanner_id = scanner_device_id 
        AND id != service_account_id
        AND scanner_id IS NOT NULL 
        AND scanner_id != ''
    ) INTO scanner_assigned_to_service;
    
    -- Scanner is already assigned if it's assigned to admin or another service
    scanner_already_assigned := scanner_assigned_to_admin OR scanner_assigned_to_service;
    
    IF scanner_already_assigned THEN
        IF scanner_assigned_to_admin THEN
            RAISE EXCEPTION 'Scanner % is already assigned to an admin account', scanner_device_id;
        ELSE
            RAISE EXCEPTION 'Scanner % is already assigned to another service account', scanner_device_id;
        END IF;
    END IF;
    
    -- Clear any existing scanner_id from the service account if it has a different scanner
    UPDATE service_accounts 
    SET scanner_id = NULL,
        updated_at = NOW()
    WHERE id = service_account_id 
    AND scanner_id IS NOT NULL 
    AND scanner_id != scanner_device_id;
    
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION assign_scanner_to_service(VARCHAR, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION assign_scanner_to_service(VARCHAR, INTEGER) TO authenticated;

-- =====================================================
-- END OF FIX
-- =====================================================

