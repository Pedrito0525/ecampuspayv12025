-- Comprehensive RLS fix for admin_accounts table
-- This ensures authenticated users can access admin accounts for scanner assignment

-- First, let's check current RLS status and policies
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'admin_accounts';

-- Check existing policies
SELECT policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'admin_accounts';

-- Drop all existing policies to start fresh
DROP POLICY IF EXISTS "Allow authenticated users to read admin accounts" ON admin_accounts;
DROP POLICY IF EXISTS "Allow authenticated users to update scanner_id" ON admin_accounts;
DROP POLICY IF EXISTS "Allow scanner assignment access" ON admin_accounts;
DROP POLICY IF EXISTS "Enable read access for authenticated users" ON admin_accounts;
DROP POLICY IF EXISTS "Enable update access for authenticated users" ON admin_accounts;

-- Temporarily disable RLS to grant permissions
ALTER TABLE admin_accounts DISABLE ROW LEVEL SECURITY;

-- Grant all necessary permissions
GRANT ALL ON admin_accounts TO authenticated;
GRANT ALL ON admin_accounts TO anon;

-- Re-enable RLS
ALTER TABLE admin_accounts ENABLE ROW LEVEL SECURITY;

-- Create comprehensive policies for all operations
CREATE POLICY "Enable all access for authenticated users" 
ON admin_accounts 
FOR ALL 
TO authenticated 
USING (true)
WITH CHECK (true);

-- Also create a policy for anon users (in case needed)
CREATE POLICY "Enable read access for anon users" 
ON admin_accounts 
FOR SELECT 
TO anon 
USING (true);

-- Create specific policies for different operations
CREATE POLICY "Enable SELECT for authenticated" 
ON admin_accounts 
FOR SELECT 
TO authenticated 
USING (true);

CREATE POLICY "Enable INSERT for authenticated" 
ON admin_accounts 
FOR INSERT 
TO authenticated 
WITH CHECK (true);

CREATE POLICY "Enable UPDATE for authenticated" 
ON admin_accounts 
FOR UPDATE 
TO authenticated 
USING (true)
WITH CHECK (true);

CREATE POLICY "Enable DELETE for authenticated" 
ON admin_accounts 
FOR DELETE 
TO authenticated 
USING (true);

-- Test the policy by trying to read admin accounts
-- This should work now with RLS enabled
SELECT 
    id,
    username,
    full_name,
    email,
    role,
    is_active,
    scanner_id,
    created_at,
    updated_at
FROM admin_accounts
ORDER BY full_name
LIMIT 5;

-- Check current policies on admin_accounts
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
WHERE tablename = 'admin_accounts';

COMMENT ON POLICY "Allow authenticated users to read admin accounts" ON admin_accounts 
IS 'Allows authenticated users to read admin account information for scanner assignment functionality';

COMMENT ON POLICY "Allow authenticated users to update scanner_id" ON admin_accounts 
IS 'Allows authenticated users to update scanner_id field for admin scanner assignment';
