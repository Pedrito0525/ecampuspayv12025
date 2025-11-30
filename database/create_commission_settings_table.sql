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

