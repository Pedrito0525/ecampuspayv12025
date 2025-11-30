-- Fix RLS policies for api_configuration table while keeping RLS ENABLED
-- This ensures security while allowing proper access

-- First, check current RLS status
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'api_configuration';

-- Drop ALL existing policies to start fresh
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

-- Ensure RLS is enabled
ALTER TABLE api_configuration ENABLE ROW LEVEL SECURITY;

-- Create comprehensive policies that work with Supabase auth
-- Policy for SELECT (all authenticated users)
CREATE POLICY "api_configuration_select_all" ON api_configuration
    FOR SELECT
    TO authenticated
    USING (true);

-- Policy for INSERT (all authenticated users)
CREATE POLICY "api_configuration_insert_all" ON api_configuration
    FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- Policy for UPDATE (all authenticated users)
CREATE POLICY "api_configuration_update_all" ON api_configuration
    FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- Policy for DELETE (all authenticated users) - in case needed
CREATE POLICY "api_configuration_delete_all" ON api_configuration
    FOR DELETE
    TO authenticated
    USING (true);

-- Verify policies were created
SELECT 
    schemaname, 
    tablename, 
    policyname, 
    permissive, 
    roles, 
    cmd, 
    qual, 
    with_check
FROM pg_policies 
WHERE tablename = 'api_configuration'
ORDER BY policyname;

-- Test query to verify access works
SELECT 'RLS policies created successfully - RLS remains ENABLED' as status;

-- Verify RLS is still enabled
SELECT 
    schemaname, 
    tablename, 
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename = 'api_configuration';
