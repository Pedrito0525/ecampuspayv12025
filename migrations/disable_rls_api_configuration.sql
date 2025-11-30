-- Disable RLS for api_configuration table
-- Use this if RLS policies continue to cause issues

-- Disable RLS completely
ALTER TABLE api_configuration DISABLE ROW LEVEL SECURITY;

-- Drop all existing policies
DROP POLICY IF EXISTS "Allow all authenticated users to read api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Allow all authenticated users to update api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Allow all authenticated users to insert api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "api_configuration_select_policy" ON api_configuration;
DROP POLICY IF EXISTS "api_configuration_update_policy" ON api_configuration;
DROP POLICY IF EXISTS "api_configuration_insert_policy" ON api_configuration;
DROP POLICY IF EXISTS "Admins can read api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Admins can update api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Admins can insert api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Students can read enabled status" ON api_configuration;

-- Verify RLS is disabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'api_configuration';

-- Add comment
COMMENT ON TABLE api_configuration IS 'Stores Paytaca API configuration settings for the application. RLS is disabled for simplicity.';
