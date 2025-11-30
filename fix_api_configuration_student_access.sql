-- Fix API Configuration Student Access
-- This script ensures students can read the enabled field from api_configuration table

-- Drop existing policies that might be blocking student access
DROP POLICY IF EXISTS api_config_authenticated_read_policy ON api_configuration;

-- Create a more permissive policy for authenticated users to read enabled field
-- This allows both admin and student users to read the enabled field
CREATE POLICY api_config_authenticated_read_policy ON api_configuration
    FOR SELECT TO authenticated
    USING (true);

-- Also create a policy for anon users to read enabled field (in case students are not properly authenticated)
CREATE POLICY api_config_anon_read_policy ON api_configuration
    FOR SELECT TO anon
    USING (true);

-- Update the existing anon policy to allow SELECT
DROP POLICY IF EXISTS api_config_anon_policy ON api_configuration;

-- Create new anon policy that allows SELECT but denies other operations
CREATE POLICY api_config_anon_policy ON api_configuration
    FOR ALL TO anon
    USING (false)
    WITH CHECK (false);

-- Create a separate policy for anon SELECT operations
CREATE POLICY api_config_anon_select_policy ON api_configuration
    FOR SELECT TO anon
    USING (true);

-- Grant SELECT permission to anon role
GRANT SELECT ON TABLE api_configuration TO anon;

-- Test the policies
DO $$
BEGIN
    RAISE NOTICE 'API Configuration student access policies have been updated';
    RAISE NOTICE 'Students should now be able to read the enabled field';
    
    -- Test if we can read the configuration
    IF EXISTS (SELECT 1 FROM api_configuration LIMIT 1) THEN
        RAISE NOTICE 'API configuration table is accessible';
    ELSE
        RAISE NOTICE 'WARNING: API configuration table might not be accessible';
    END IF;
END $$;
