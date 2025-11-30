-- Admin Scanner Assignment System
-- This adds scanner_id column to admin_accounts table and related functions

-- Add scanner_id column to admin_accounts table
ALTER TABLE admin_accounts 
ADD COLUMN IF NOT EXISTS scanner_id VARCHAR(50);

-- Add comment for the new column
COMMENT ON COLUMN admin_accounts.scanner_id IS 'Assigned RFID scanner ID for this admin account (format: EvsuPay1-100)';

-- Create index for better performance
CREATE INDEX IF NOT EXISTS idx_admin_accounts_scanner_id ON admin_accounts(scanner_id);

-- Update the updated_at column when scanner_id changes
CREATE OR REPLACE FUNCTION update_admin_account_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for admin_accounts updated_at
DROP TRIGGER IF EXISTS trigger_admin_accounts_updated_at ON admin_accounts;
CREATE TRIGGER trigger_admin_accounts_updated_at
    BEFORE UPDATE ON admin_accounts
    FOR EACH ROW
    EXECUTE FUNCTION update_admin_account_updated_at();

-- Function to assign scanner to admin account
CREATE OR REPLACE FUNCTION assign_scanner_to_admin(
    p_admin_id INTEGER,
    p_scanner_id VARCHAR(50)
)
RETURNS JSONB AS $$
DECLARE
    v_admin_exists BOOLEAN;
    v_scanner_assigned BOOLEAN;
    v_result JSONB;
BEGIN
    -- Check if admin account exists
    SELECT EXISTS(SELECT 1 FROM admin_accounts WHERE id = p_admin_id) INTO v_admin_exists;
    
    IF NOT v_admin_exists THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Admin account not found',
            'message', 'The specified admin account does not exist'
        );
    END IF;
    
    -- Check if scanner is already assigned to another admin
    SELECT EXISTS(
        SELECT 1 FROM admin_accounts 
        WHERE scanner_id = p_scanner_id AND id != p_admin_id
    ) INTO v_scanner_assigned;
    
    IF v_scanner_assigned THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Scanner already assigned',
            'message', 'This scanner is already assigned to another admin account'
        );
    END IF;
    
    -- Update admin account with scanner assignment
    UPDATE admin_accounts 
    SET scanner_id = p_scanner_id,
        updated_at = NOW()
    WHERE id = p_admin_id;
    
    -- Insert into overall_activity for tracking
    PERFORM insert_overall_activity(
        'admin_scanner_assignment',           -- activity_type
        'system',                            -- activity_category
        NULL,                                -- student_id (not applicable)
        NULL,                                -- user_id (not applicable)
        NULL,                                -- amount (not applicable)
        'admin_accounts',                    -- source_table
        p_admin_id,                          -- source_id
        format('Scanner %s assigned to admin account ID %s', p_scanner_id, p_admin_id), -- description
        jsonb_build_object(
            'admin_id', p_admin_id,
            'scanner_id', p_scanner_id,
            'assignment_type', 'admin_scanner'
        ),                                   -- metadata
        NULL,                                -- service_account_id (not applicable)
        'Admin Panel',                       -- location
        'completed'                          -- status
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Scanner assigned to admin account successfully',
        'data', jsonb_build_object(
            'admin_id', p_admin_id,
            'scanner_id', p_scanner_id
        )
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'message', 'Failed to assign scanner to admin account: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- Function to unassign scanner from admin account
CREATE OR REPLACE FUNCTION unassign_scanner_from_admin(
    p_admin_id INTEGER
)
RETURNS JSONB AS $$
DECLARE
    v_current_scanner VARCHAR(50);
BEGIN
    -- Get current scanner assignment
    SELECT scanner_id INTO v_current_scanner 
    FROM admin_accounts 
    WHERE id = p_admin_id;
    
    IF v_current_scanner IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No scanner assigned',
            'message', 'This admin account does not have a scanner assigned'
        );
    END IF;
    
    -- Remove scanner assignment
    UPDATE admin_accounts 
    SET scanner_id = NULL,
        updated_at = NOW()
    WHERE id = p_admin_id;
    
    -- Insert into overall_activity for tracking
    PERFORM insert_overall_activity(
        'admin_scanner_unassignment',        -- activity_type
        'system',                            -- activity_category
        NULL,                                -- student_id (not applicable)
        NULL,                                -- user_id (not applicable)
        NULL,                                -- amount (not applicable)
        'admin_accounts',                    -- source_table
        p_admin_id,                          -- source_id
        format('Scanner %s unassigned from admin account ID %s', v_current_scanner, p_admin_id), -- description
        jsonb_build_object(
            'admin_id', p_admin_id,
            'scanner_id', v_current_scanner,
            'assignment_type', 'admin_scanner'
        ),                                   -- metadata
        NULL,                                -- service_account_id (not applicable)
        'Admin Panel',                       -- location
        'completed'                          -- status
    );
    
    RETURN jsonb_build_object(
        'success', true,
        'message', 'Scanner unassigned from admin account successfully',
        'data', jsonb_build_object(
            'admin_id', p_admin_id,
            'previous_scanner_id', v_current_scanner
        )
    );
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'message', 'Failed to unassign scanner from admin account: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- Function to get admin accounts with their scanner assignments
CREATE OR REPLACE FUNCTION get_admin_accounts_with_scanners()
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'success', true,
        'data', jsonb_agg(
            jsonb_build_object(
                'id', id,
                'username', username,
                'full_name', full_name,
                'email', email,
                'role', role,
                'is_active', is_active,
                'scanner_id', scanner_id,
                'has_scanner', scanner_id IS NOT NULL,
                'created_at', created_at,
                'updated_at', updated_at
            )
        )
    ) INTO v_result
    FROM admin_accounts
    ORDER BY full_name;
    
    RETURN COALESCE(v_result, jsonb_build_object('success', true, 'data', '[]'::jsonb));
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'message', 'Failed to get admin accounts: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- Function to get available scanners for admin assignment
CREATE OR REPLACE FUNCTION get_available_scanners_for_admin()
RETURNS JSONB AS $$
DECLARE
    v_result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'success', true,
        'data', jsonb_agg(
            jsonb_build_object(
                'scanner_id', scanner_id,
                'is_available', true,
                'assigned_to', 'none'
            )
        )
    ) INTO v_result
    FROM (
        -- Generate scanner IDs from EvsuPay1 to EvsuPay100
        SELECT 'EvsuPay' || generate_series(1, 100) as scanner_id
    ) scanners
    WHERE scanner_id NOT IN (
        -- Exclude scanners already assigned to service accounts
        SELECT COALESCE(scanner_id, '') 
        FROM service_accounts 
        WHERE scanner_id IS NOT NULL AND scanner_id != ''
    )
    AND scanner_id NOT IN (
        -- Exclude scanners already assigned to admin accounts
        SELECT COALESCE(scanner_id, '') 
        FROM admin_accounts 
        WHERE scanner_id IS NOT NULL AND scanner_id != ''
    )
    ORDER BY scanner_id;
    
    RETURN COALESCE(v_result, jsonb_build_object('success', true, 'data', '[]'::jsonb));
    
EXCEPTION
    WHEN OTHERS THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM,
            'message', 'Failed to get available scanners: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions
GRANT EXECUTE ON FUNCTION assign_scanner_to_admin TO authenticated;
GRANT EXECUTE ON FUNCTION unassign_scanner_from_admin TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_accounts_with_scanners TO authenticated;
GRANT EXECUTE ON FUNCTION get_available_scanners_for_admin TO authenticated;

-- Comments for functions
COMMENT ON FUNCTION assign_scanner_to_admin IS 'Assigns a scanner to an admin account with validation and activity tracking';
COMMENT ON FUNCTION unassign_scanner_from_admin IS 'Unassigns a scanner from an admin account with activity tracking';
COMMENT ON FUNCTION get_admin_accounts_with_scanners IS 'Gets all admin accounts with their scanner assignment status';
COMMENT ON FUNCTION get_available_scanners_for_admin IS 'Gets list of scanners available for admin assignment (not assigned to services or other admins)';
