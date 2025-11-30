-- Test script to verify admin_accounts table and RLS setup
-- Run this to diagnose the issue

-- 1. Check if table exists
SELECT 
    schemaname, 
    tablename, 
    rowsecurity,
    hasindexes,
    hasrules,
    hastriggers
FROM pg_tables 
WHERE tablename = 'admin_accounts';

-- 2. Check table structure
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'admin_accounts' 
ORDER BY ordinal_position;

-- 3. Check RLS policies
SELECT 
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'admin_accounts';

-- 4. Check table permissions
SELECT 
    grantee,
    privilege_type,
    is_grantable
FROM information_schema.table_privileges 
WHERE table_name = 'admin_accounts';

-- 5. Try to count records (this will show if RLS is blocking)
SELECT COUNT(*) as total_admin_accounts FROM admin_accounts;

-- 6. Try to select a few records
SELECT 
    id,
    username,
    full_name,
    role,
    is_active,
    scanner_id
FROM admin_accounts
LIMIT 3;

-- 7. Check if there are any admin accounts at all (bypass RLS if possible)
-- This might work even with RLS enabled
SELECT 
    'admin_accounts' as table_name,
    COUNT(*) as record_count
FROM admin_accounts;

-- 8. Check current user and role
SELECT 
    current_user as current_user,
    current_role as current_role,
    session_user as session_user;

-- 9. Check if we're authenticated
SELECT auth.uid() as current_user_id;
