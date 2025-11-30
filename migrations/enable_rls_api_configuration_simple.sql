-- Enable RLS and add simple policies for api_configuration table
-- This version works without knowing the exact auth_students table structure

-- Enable RLS on the table
ALTER TABLE api_configuration ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist to prevent errors on re-run
DROP POLICY IF EXISTS "Allow all authenticated users to read api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Allow all authenticated users to update api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Allow all authenticated users to insert api_configuration" ON api_configuration;

-- Create simple RLS policies that allow all authenticated users
-- This is a temporary solution until we understand the auth_students table structure

-- Policy for reading configuration (all authenticated users)
CREATE POLICY "Allow all authenticated users to read api_configuration" ON api_configuration
    FOR SELECT
    TO authenticated
    USING (true);

-- Policy for updating configuration (all authenticated users)
CREATE POLICY "Allow all authenticated users to update api_configuration" ON api_configuration
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Policy for inserting configuration (all authenticated users)
CREATE POLICY "Allow all authenticated users to insert api_configuration" ON api_configuration
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Add comment explaining the temporary nature
COMMENT ON TABLE api_configuration IS 'Stores Paytaca API configuration settings for the application. RLS policies are currently permissive for all authenticated users.';
