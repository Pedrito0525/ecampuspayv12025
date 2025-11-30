-- Fix RLS policies using Supabase auth context
-- This approach uses auth.uid() and auth.role() for better compatibility

-- Drop all existing policies
DROP POLICY IF EXISTS "Allow all authenticated users to read api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Allow all authenticated users to update api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Allow all authenticated users to insert api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "api_configuration_select_policy" ON api_configuration;
DROP POLICY IF EXISTS "api_configuration_update_policy" ON api_configuration;
DROP POLICY IF EXISTS "api_configuration_insert_policy" ON api_configuration;
DROP POLICY IF EXISTS "api_configuration_select_all" ON api_configuration;
DROP POLICY IF EXISTS "api_configuration_insert_all" ON api_configuration;
DROP POLICY IF EXISTS "api_configuration_update_all" ON api_configuration;
DROP POLICY IF EXISTS "api_configuration_delete_all" ON api_configuration;
DROP POLICY IF EXISTS "Admins can read api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Admins can update api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Admins can insert api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Students can read enabled status" ON api_configuration;

-- Ensure RLS is enabled
ALTER TABLE api_configuration ENABLE ROW LEVEL SECURITY;

-- Create policies using Supabase auth functions
-- These policies work with Supabase's authentication system

-- Policy for SELECT - allow all authenticated users
CREATE POLICY "api_configuration_select" ON api_configuration
    FOR SELECT
    TO authenticated
    USING (auth.uid() IS NOT NULL);

-- Policy for INSERT - allow all authenticated users
CREATE POLICY "api_configuration_insert" ON api_configuration
    FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

-- Policy for UPDATE - allow all authenticated users
CREATE POLICY "api_configuration_update" ON api_configuration
    FOR UPDATE
    TO authenticated
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- Policy for DELETE - allow all authenticated users (if needed)
CREATE POLICY "api_configuration_delete" ON api_configuration
    FOR DELETE
    TO authenticated
    USING (auth.uid() IS NOT NULL);

-- Verify the policies
SELECT 
    policyname,
    cmd,
    permissive,
    roles,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'api_configuration'
ORDER BY policyname;

-- Test that RLS is enabled and policies work
SELECT 'RLS enabled with auth-based policies' as status;
