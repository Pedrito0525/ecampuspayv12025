-- =====================================================
-- SCANNER UNASSIGN FUNCTION FIX
-- =====================================================
-- Fix for ambiguous column reference in unassign_scanner_from_service function

-- Drop the existing function
DROP FUNCTION IF EXISTS unassign_scanner_from_service(VARCHAR);

-- Recreate the function with fixed variable naming
CREATE OR REPLACE FUNCTION unassign_scanner_from_service(
    scanner_device_id VARCHAR(50)
) RETURNS BOOLEAN AS $$
DECLARE
    scanner_exists BOOLEAN;
    current_service_id INTEGER;  -- Renamed from assigned_service_id to avoid conflict
BEGIN
    -- Check if scanner exists
    SELECT EXISTS(SELECT 1 FROM scanner_devices WHERE scanner_id = scanner_device_id) INTO scanner_exists;
    IF NOT scanner_exists THEN
        RAISE EXCEPTION 'Scanner % not found', scanner_device_id;
    END IF;
    
    -- Get assigned service ID (using table.column syntax to avoid ambiguity)
    SELECT scanner_devices.assigned_service_id INTO current_service_id
    FROM scanner_devices 
    WHERE scanner_devices.scanner_id = scanner_device_id;
    
    -- Check if scanner is actually assigned
    IF current_service_id IS NULL THEN
        RAISE EXCEPTION 'Scanner % is not currently assigned to any service', scanner_device_id;
    END IF;
    
    -- Update scanner_devices table to unassign
    UPDATE scanner_devices 
    SET 
        assigned_service_id = NULL,
        status = 'Available',
        updated_at = NOW()
    WHERE scanner_id = scanner_device_id;
    
    -- Update service_accounts table to remove scanner reference
    UPDATE service_accounts 
    SET scanner_id = NULL 
    WHERE id = current_service_id;
    
    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Error unassigning scanner: %', SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION unassign_scanner_from_service(VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION unassign_scanner_from_service(VARCHAR) TO authenticated;

-- =====================================================
-- VERIFICATION QUERIES
-- =====================================================
-- Test the function (uncomment to test)
-- SELECT unassign_scanner_from_service('EvsuPay1');

-- Check scanner status
-- SELECT scanner_id, status, assigned_service_id FROM scanner_devices WHERE scanner_id = 'EvsuPay1';

-- Check service scanner assignment
-- SELECT id, service_name, scanner_id FROM service_accounts WHERE scanner_id = 'EvsuPay1';
