-- =====================================================
-- EVSU Campus Pay - Scanner Devices Schema
-- =====================================================
-- This file contains the complete scanner_devices table schema
-- and related components for RFID Bluetooth scanner management
-- =====================================================

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

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_scanner_devices_scanner_id ON scanner_devices(scanner_id);
CREATE INDEX IF NOT EXISTS idx_scanner_devices_device_type ON scanner_devices(device_type);
CREATE INDEX IF NOT EXISTS idx_scanner_devices_status ON scanner_devices(status);
CREATE INDEX IF NOT EXISTS idx_scanner_devices_assigned_service_id ON scanner_devices(assigned_service_id);
CREATE INDEX IF NOT EXISTS idx_scanner_devices_serial_number ON scanner_devices(serial_number);

-- Constraints
ALTER TABLE scanner_devices 
ADD CONSTRAINT check_device_type 
CHECK (device_type = 'RFID_Bluetooth_Scanner');

ALTER TABLE scanner_devices 
ADD CONSTRAINT check_status 
CHECK (status IN ('Available', 'Assigned', 'Maintenance'));

ALTER TABLE scanner_devices 
ADD CONSTRAINT check_scanner_id_format 
CHECK (scanner_id ~ '^EvsuPay[0-9]+$');

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Drop existing conflicting functions first
DROP FUNCTION IF EXISTS assign_scanner_to_service(VARCHAR, INTEGER);
DROP FUNCTION IF EXISTS assign_scanner_to_service(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS unassign_scanner_from_service(VARCHAR);
DROP FUNCTION IF EXISTS unassign_scanner_from_service(INTEGER);

-- Function to assign scanner to service (VARCHAR, INTEGER signature)
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

-- Function to unassign scanner from service (VARCHAR signature)
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for updated_at
CREATE TRIGGER update_scanner_devices_updated_at 
    BEFORE UPDATE ON scanner_devices 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- View for scanner assignments
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

-- Enable RLS
ALTER TABLE scanner_devices ENABLE ROW LEVEL SECURITY;

-- Drop existing policies first
DROP POLICY IF EXISTS "service_role_full_access_scanner_devices" ON scanner_devices;
DROP POLICY IF EXISTS "authenticated_full_access_scanner_devices" ON scanner_devices;
DROP POLICY IF EXISTS "anon_read_available_scanners" ON scanner_devices;

-- RLS Policies (more permissive)
CREATE POLICY "service_role_scanner_full_access" ON scanner_devices
    FOR ALL USING (auth.role() = 'service_role') WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "authenticated_scanner_full_access" ON scanner_devices
    FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "anon_scanner_read_available" ON scanner_devices
    FOR SELECT USING (auth.role() = 'anon' AND status = 'Available');

-- Permissions
GRANT ALL ON scanner_devices TO service_role;
GRANT ALL ON scanner_devices TO authenticated;
GRANT SELECT ON scanner_devices TO anon;
GRANT SELECT ON scanner_assignments TO service_role;
GRANT SELECT ON scanner_assignments TO authenticated;
GRANT SELECT ON scanner_assignments TO anon;
GRANT EXECUTE ON FUNCTION assign_scanner_to_service(VARCHAR, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION assign_scanner_to_service(VARCHAR, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION unassign_scanner_from_service(VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION unassign_scanner_from_service(VARCHAR) TO authenticated;

-- Comments
COMMENT ON TABLE scanner_devices IS 'RFID Bluetooth scanner devices table for EvsuPay1-100 scanner management';
COMMENT ON COLUMN scanner_devices.scanner_id IS 'Unique scanner identifier (EvsuPay1, EvsuPay2, etc.)';
COMMENT ON COLUMN scanner_devices.device_type IS 'Type of device (only RFID_Bluetooth_Scanner)';
COMMENT ON COLUMN scanner_devices.status IS 'Current status: Available, Assigned, or Maintenance';
COMMENT ON COLUMN scanner_devices.assigned_service_id IS 'ID of service this scanner is assigned to (NULL if available)';

-- =====================================================
-- INSERT SAMPLE DATA (EvsuPay1-100)
-- =====================================================
DO $$
BEGIN
    -- Insert EvsuPay1-100 scanners if they don't exist
    FOR i IN 1..100 LOOP
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
-- END OF SCANNER DEVICES SCHEMA
-- =====================================================
