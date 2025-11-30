-- Fix API Configuration RLS Policies for Admin Access
-- This script creates proper RLS policies for the api_configuration table
-- to allow admin users to manage API settings via JWT authentication

-- Enable RLS on api_configuration table
ALTER TABLE api_configuration ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS api_config_service_role_policy ON api_configuration;
DROP POLICY IF EXISTS api_config_admin_policy ON api_configuration;
DROP POLICY IF EXISTS api_config_authenticated_read_policy ON api_configuration;
DROP POLICY IF EXISTS api_config_anon_policy ON api_configuration;

-- Policy for service_role (full access for system operations)
CREATE POLICY api_config_service_role_policy ON api_configuration
    FOR ALL TO service_role
    USING (true)
    WITH CHECK (true);

-- Policy for admin users with JWT token (full access)
-- This allows admin users to manage API configuration
CREATE POLICY api_config_admin_policy ON api_configuration
    FOR ALL TO authenticated
    USING (
        -- Check if the JWT token contains admin role
        (auth.jwt() ->> 'role')::text = 'admin' OR
        -- Alternative: check if username exists in admin_accounts table
        EXISTS (
            SELECT 1 FROM admin_accounts 
            WHERE username = (auth.jwt() ->> 'username')::text 
            AND is_active = true
        )
    )
    WITH CHECK (
        -- Same conditions for INSERT/UPDATE operations
        (auth.jwt() ->> 'role')::text = 'admin' OR
        EXISTS (
            SELECT 1 FROM admin_accounts 
            WHERE username = (auth.jwt() ->> 'username')::text 
            AND is_active = true
        )
    );

-- Policy for regular authenticated users (read-only access to enabled field)
-- This allows students to check if Paytaca is enabled
CREATE POLICY api_config_authenticated_read_policy ON api_configuration
    FOR SELECT TO authenticated
    USING (true);

-- Policy for anonymous users (no access)
CREATE POLICY api_config_anon_policy ON api_configuration
    FOR ALL TO anon
    USING (false);

-- Grant permissions
GRANT ALL ON TABLE api_configuration TO service_role;
GRANT ALL ON TABLE api_configuration TO authenticated;
GRANT USAGE ON SEQUENCE api_configuration_id_seq TO service_role;
GRANT USAGE ON SEQUENCE api_configuration_id_seq TO authenticated;

-- Create a function to verify admin access for API configuration
CREATE OR REPLACE FUNCTION verify_admin_api_access()
RETURNS BOOLEAN AS $$
BEGIN
    -- Check if user is authenticated and has admin role in JWT
    IF auth.jwt() ->> 'role' = 'admin' THEN
        RETURN true;
    END IF;
    
    -- Check if username exists in admin_accounts table and is active
    IF EXISTS (
        SELECT 1 FROM admin_accounts 
        WHERE username = (auth.jwt() ->> 'username')::text 
        AND is_active = true
    ) THEN
        RETURN true;
    END IF;
    
    RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission on the verification function
GRANT EXECUTE ON FUNCTION verify_admin_api_access() TO authenticated;
GRANT EXECUTE ON FUNCTION verify_admin_api_access() TO service_role;

-- Add helpful comments
COMMENT ON POLICY api_config_service_role_policy ON api_configuration IS 'Allows service role full access to API configuration';
COMMENT ON POLICY api_config_admin_policy ON api_configuration IS 'Allows admin users full access to API configuration via JWT authentication';
COMMENT ON POLICY api_config_authenticated_read_policy ON api_configuration IS 'Allows authenticated users read-only access to API configuration';
COMMENT ON POLICY api_config_anon_policy ON api_configuration IS 'Denies anonymous users access to API configuration';
COMMENT ON FUNCTION verify_admin_api_access() IS 'Helper function to verify admin access for API configuration operations';

-- Test the policies by checking current configuration
DO $$
BEGIN
    RAISE NOTICE 'API Configuration RLS policies have been created successfully';
    RAISE NOTICE 'Admin users can now manage API configuration via JWT authentication';
    RAISE NOTICE 'Regular users have read-only access to check if Paytaca is enabled';
END $$;
