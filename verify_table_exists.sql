-- =====================================================
-- Verify top_up_requests Table Exists and is Accessible
-- =====================================================
-- Run this in Supabase SQL Editor to check table status
-- =====================================================

\echo '═══════════════════════════════════════'
\echo 'STEP 1: Check if table exists'
\echo '═══════════════════════════════════════'

SELECT 
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Table EXISTS'
        ELSE '❌ Table DOES NOT EXIST'
    END AS status,
    COUNT(*) AS table_count
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'top_up_requests';

-- Show table details
SELECT 
    schemaname AS schema,
    tablename AS table_name,
    tableowner AS owner
FROM pg_tables
WHERE tablename = 'top_up_requests';

\echo ''
\echo '═══════════════════════════════════════'
\echo 'STEP 2: Check table structure'
\echo '═══════════════════════════════════════'

SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns
WHERE table_schema = 'public' 
  AND table_name = 'top_up_requests'
ORDER BY ordinal_position;

\echo ''
\echo '═══════════════════════════════════════'
\echo 'STEP 3: Check RLS status'
\echo '═══════════════════════════════════════'

SELECT 
    schemaname,
    tablename,
    CASE 
        WHEN rowsecurity = true THEN '✅ RLS ENABLED'
        ELSE '⚠️ RLS DISABLED'
    END AS rls_status
FROM pg_tables
WHERE tablename = 'top_up_requests';

\echo ''
\echo '═══════════════════════════════════════'
\echo 'STEP 4: List all policies'
\echo '═══════════════════════════════════════'

SELECT 
    policyname AS policy_name,
    cmd AS command_type,
    roles AS for_roles,
    CASE 
        WHEN qual IS NOT NULL THEN 'Has USING clause'
        ELSE 'No USING clause (true)'
    END AS using_clause,
    CASE 
        WHEN with_check IS NOT NULL THEN 'Has WITH CHECK clause'
        ELSE 'No WITH CHECK clause (true)'
    END AS with_check_clause
FROM pg_policies
WHERE tablename = 'top_up_requests'
ORDER BY policyname;

\echo ''
\echo '═══════════════════════════════════════'
\echo 'STEP 5: Check permissions'
\echo '═══════════════════════════════════════'

SELECT 
    grantee,
    string_agg(privilege_type, ', ') AS privileges
FROM information_schema.table_privileges
WHERE table_schema = 'public' 
  AND table_name = 'top_up_requests'
  AND grantee IN ('public', 'anon', 'authenticated', 'service_role')
GROUP BY grantee
ORDER BY grantee;

\echo ''
\echo '═══════════════════════════════════════'
\echo 'STEP 6: Test data access'
\echo '═══════════════════════════════════════'

-- Try to count records
DO $$
DECLARE
    record_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO record_count FROM top_up_requests;
    RAISE NOTICE '✅ Can access table! Total records: %', record_count;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '❌ Cannot access table: %', SQLERRM;
END $$;

-- Show sample data (if any exists)
SELECT 
    id,
    user_id,
    amount,
    status,
    created_at
FROM top_up_requests
LIMIT 5;

\echo ''
\echo '═══════════════════════════════════════'
\echo 'STEP 7: Check foreign key constraints'
\echo '═══════════════════════════════════════'

SELECT
    tc.constraint_name,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
    AND tc.table_schema = kcu.table_schema
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
    AND ccu.table_schema = tc.table_schema
WHERE tc.constraint_type = 'FOREIGN KEY'
    AND tc.table_name = 'top_up_requests';

\echo ''
\echo '═══════════════════════════════════════'
\echo 'DIAGNOSTIC SUMMARY'
\echo '═══════════════════════════════════════'
\echo ''
\echo 'If table EXISTS but Flutter app shows "TABLE NOT FOUND":'
\echo '1. Check that SUPABASE_SERVICE_ROLE_KEY is set in .env file'
\echo '2. Verify the service_role key is correct (from Supabase Settings > API)'
\echo '3. Hot restart the Flutter app (not just hot reload)'
\echo '4. Check that RLS policies allow service_role access'
\echo ''
\echo 'If table DOES NOT EXIST:'
\echo '1. Run: create_top_up_requests_table.sql'
\echo '2. Verify creation succeeded'
\echo '3. Run this script again to confirm'
\echo ''
\echo 'If RLS is blocking access:'
\echo '1. Run: fix_top_up_requests_access.sql'
\echo '2. Verify policies were created'
\echo '3. Test again'
\echo ''

