-- =====================================================
-- Diagnostic Queries for Top-Up Verification Issues
-- =====================================================
-- Run these queries in Supabase SQL Editor to diagnose why
-- requests aren't showing in the admin panel
-- =====================================================

-- ====================================
-- TEST 1: Check if table exists
-- ====================================
SELECT '🔍 TEST 1: Table Existence' AS test;

SELECT 
    tablename AS table_name,
    CASE 
        WHEN tablename = 'top_up_requests' THEN '✅ Table exists'
        ELSE 'Other table'
    END AS status
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'top_up_requests';

-- If no results → Table doesn't exist, create it first

-- ====================================
-- TEST 2: Count total records
-- ====================================
SELECT '🔍 TEST 2: Total Records' AS test;

SELECT 
    COUNT(*) AS total_records,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Data exists'
        ELSE '❌ No data in table'
    END AS status
FROM top_up_requests;

-- ====================================
-- TEST 3: Check pending requests
-- ====================================
SELECT '🔍 TEST 3: Pending Verification Requests' AS test;

SELECT 
    COUNT(*) AS pending_count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ Pending requests found'
        ELSE '❌ No pending requests (check status field)'
    END AS status
FROM top_up_requests
WHERE status = 'Pending Verification';

-- ====================================
-- TEST 4: View all statuses
-- ====================================
SELECT '🔍 TEST 4: All Status Values' AS test;

SELECT 
    status,
    COUNT(*) AS count
FROM top_up_requests
GROUP BY status
ORDER BY count DESC;

-- If you see different status values, update them:
-- UPDATE top_up_requests SET status = 'Pending Verification' WHERE status != 'Pending Verification';

-- ====================================
-- TEST 5: Sample pending requests
-- ====================================
SELECT '🔍 TEST 5: Sample Pending Requests (Raw Data)' AS test;

SELECT 
    id,
    user_id,
    amount,
    status,
    created_at,
    LEFT(screenshot_url, 50) || '...' AS screenshot_preview
FROM top_up_requests
WHERE status = 'Pending Verification'
ORDER BY created_at DESC
LIMIT 5;

-- ====================================
-- TEST 6: Check if students exist in auth_students
-- ====================================
SELECT '🔍 TEST 6: Student ID Matching' AS test;

SELECT 
    tr.id AS request_id,
    tr.user_id,
    tr.amount,
    tr.status,
    CASE 
        WHEN s.student_id IS NOT NULL THEN '✅ Student exists in auth_students'
        ELSE '❌ NO MATCH - Student not found in auth_students'
    END AS student_status,
    s.student_id AS matched_student_id
FROM top_up_requests tr
LEFT JOIN auth_students s ON tr.user_id = s.student_id
WHERE tr.status = 'Pending Verification'
ORDER BY tr.created_at DESC;

-- ====================================
-- TEST 7: Test the exact query used by admin panel
-- ====================================
SELECT '🔍 TEST 7: Admin Panel Query (WITH JOIN)' AS test;

SELECT 
    tr.*,
    s.student_id AS auth_student_id,
    s.name AS student_name,
    s.email AS student_email
FROM top_up_requests tr
INNER JOIN auth_students s ON tr.user_id = s.student_id
WHERE tr.status = 'Pending Verification'
ORDER BY tr.created_at DESC;

-- If this returns 0 rows but TEST 5 shows data:
-- → The INNER JOIN is failing because user_id doesn't match student_id
-- → Fix: Ensure user_id in top_up_requests matches student_id in auth_students

-- ====================================
-- TEST 8: Check RLS policies
-- ====================================
SELECT '🔍 TEST 8: RLS Policies' AS test;

SELECT 
    policyname AS policy_name,
    cmd AS command_type,
    qual AS using_expression,
    with_check AS with_check_expression
FROM pg_policies
WHERE tablename = 'top_up_requests'
ORDER BY policyname;

-- Should see at least 1-2 policies
-- If empty → No policies, run fix_top_up_requests_access.sql

-- ====================================
-- TEST 9: Check table permissions
-- ====================================
SELECT '🔍 TEST 9: Table Permissions' AS test;

SELECT 
    grantee,
    privilege_type
FROM information_schema.table_privileges
WHERE table_name = 'top_up_requests'
  AND grantee IN ('public', 'anon', 'authenticated', 'service_role')
ORDER BY grantee, privilege_type;

-- Should see SELECT, INSERT, UPDATE, DELETE for multiple roles
-- If missing → Run fix_top_up_requests_access.sql

-- ====================================
-- TEST 10: Check if service_role can access
-- ====================================
SELECT '🔍 TEST 10: Service Role Access Test' AS test;

-- This query tests if the current connection can access the table
SELECT 
    COUNT(*) AS accessible_records,
    CASE 
        WHEN COUNT(*) >= 0 THEN '✅ Table is accessible with current permissions'
        ELSE 'Unexpected error'
    END AS status
FROM top_up_requests;

-- ====================================
-- SUMMARY & RECOMMENDATIONS
-- ====================================

SELECT '═══════════════════════════════════════' AS separator;
SELECT 'DIAGNOSTIC SUMMARY' AS title;
SELECT '═══════════════════════════════════════' AS separator;

WITH summary AS (
    SELECT 
        (SELECT COUNT(*) FROM top_up_requests) AS total_records,
        (SELECT COUNT(*) FROM top_up_requests WHERE status = 'Pending Verification') AS pending_records,
        (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'top_up_requests') AS policy_count
)
SELECT 
    total_records,
    pending_records,
    policy_count,
    CASE 
        WHEN total_records = 0 THEN '❌ NO DATA - Submit a test request from student app'
        WHEN pending_records = 0 THEN '⚠️  NO PENDING - Check status values or submit new request'
        WHEN policy_count = 0 THEN '❌ NO POLICIES - Run fix_top_up_requests_access.sql'
        ELSE '✅ DATABASE LOOKS GOOD - Check Flutter console for errors'
    END AS recommendation
FROM summary;

-- ====================================
-- QUICK FIXES
-- ====================================

SELECT '═══════════════════════════════════════' AS separator;
SELECT 'QUICK FIXES' AS title;
SELECT '═══════════════════════════════════════' AS separator;

-- If TEST 3 shows 0 pending but TEST 2 shows data exists:
-- Uncomment and run this:
-- UPDATE top_up_requests SET status = 'Pending Verification';

-- If TEST 6 shows no matches:
-- Check and fix user_id values:
-- SELECT user_id FROM top_up_requests WHERE status = 'Pending Verification';
-- SELECT student_id FROM auth_students LIMIT 10;

-- If TEST 8 shows no policies:
-- Run this file: fix_top_up_requests_access.sql

-- If TEST 9 shows no permissions:
-- Run these commands:
-- GRANT ALL ON top_up_requests TO public, anon, authenticated, service_role;
-- GRANT USAGE, SELECT ON SEQUENCE top_up_requests_id_seq TO public, anon, authenticated, service_role;

SELECT '═══════════════════════════════════════' AS separator;
SELECT 'Copy all results and share if issue persists' AS note;
SELECT '═══════════════════════════════════════' AS separator;

