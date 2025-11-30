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

