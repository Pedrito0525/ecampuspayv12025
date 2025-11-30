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

