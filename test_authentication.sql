-- Test authentication and user context
-- This helps diagnose authentication issues

-- 1. Check current user context
SELECT 
    'User Context' as test_type,
    current_user as current_user,
    current_role as current_role,
    session_user as session_user,
    user as user;

-- 2. Check authentication status
SELECT 
    'Auth Status' as test_type,
    auth.uid() as auth_uid,
    auth.role() as auth_role,
    auth.email() as auth_email;

-- 3. Check if we're in an authenticated session
SELECT 
    'Session Info' as test_type,
    CASE 
        WHEN auth.uid() IS NOT NULL THEN 'Authenticated User'
        ELSE 'Not Authenticated or Anonymous'
    END as auth_status;

-- 4. Test basic table access without RLS
-- First disable RLS temporarily
ALTER TABLE admin_accounts DISABLE ROW LEVEL SECURITY;

-- Grant basic permissions
GRANT SELECT ON admin_accounts TO public;

-- Test access
SELECT 
    'Basic Access Test' as test_type,
    COUNT(*) as admin_count,
    CASE WHEN COUNT(*) > 0 THEN 'Table accessible' ELSE 'Table not accessible' END as status
FROM admin_accounts;

-- Re-enable RLS
ALTER TABLE admin_accounts ENABLE ROW LEVEL SECURITY;

-- 5. Check what roles exist
SELECT 
    'Available Roles' as test_type,
    rolname as role_name,
    rolsuper as is_superuser,
    rolinherit as can_inherit
FROM pg_roles 
WHERE rolname IN ('authenticated', 'anon', 'public', 'service_role')
ORDER BY rolname;

-- 6. Check table ownership
SELECT 
    'Table Ownership' as test_type,
    schemaname,
    tablename,
    tableowner
FROM pg_tables 
WHERE tablename = 'admin_accounts';

-- 7. Check current database and schema
SELECT 
    'Database Info' as test_type,
    current_database() as database_name,
    current_schema() as schema_name,
    version() as postgres_version;
