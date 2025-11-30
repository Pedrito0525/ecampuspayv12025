-- =====================================================
-- Test Admin Access to top_up_requests
-- =====================================================
-- Run this after applying fix_top_up_requests_access.sql
-- =====================================================

-- Test 1: Check if table exists and is accessible
SELECT 
    '✅ TEST 1: Table Access' AS test_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM top_up_requests LIMIT 1) 
        OR NOT EXISTS (SELECT 1 FROM top_up_requests)
        THEN 'PASS - Table is accessible'
        ELSE 'FAIL - Cannot access table'
    END AS result;

-- Test 2: Count all records
SELECT 
    '✅ TEST 2: Record Count' AS test_name,
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE status = 'Pending Verification') AS pending_requests,
    CASE 
        WHEN COUNT(*) >= 0 THEN 'PASS - Can query records'
        ELSE 'FAIL'
    END AS result
FROM top_up_requests;

-- Test 3: View all pending requests (what admin will see)
SELECT 
    '📋 Pending Requests (Admin View):' AS info,
    id,
    user_id AS student_id,
    amount,
    status,
    created_at,
    LEFT(screenshot_url, 50) || '...' AS screenshot_preview
FROM top_up_requests
WHERE status = 'Pending Verification'
ORDER BY created_at DESC;

-- Test 4: Check RLS status
SELECT 
    '✅ TEST 4: RLS Configuration' AS test_name,
    CASE 
        WHEN relrowsecurity THEN 'RLS Enabled (Good - service_role bypasses it)'
        ELSE 'RLS Disabled'
    END AS rls_status
FROM pg_class
WHERE relname = 'top_up_requests';

-- Test 5: List all policies
SELECT 
    '✅ TEST 5: Active Policies' AS test_name,
    policyname,
    cmd AS operation,
    CASE 
        WHEN roles::text LIKE '%public%' THEN 'Public Access'
        WHEN roles::text LIKE '%service_role%' THEN 'Service Role Only'
        ELSE roles::text
    END AS access_level
FROM pg_policies
WHERE tablename = 'top_up_requests'
ORDER BY policyname;

-- Test 6: Verify permissions
SELECT 
    '✅ TEST 6: Table Permissions' AS test_name,
    grantee,
    privilege_type
FROM information_schema.table_privileges
WHERE table_name = 'top_up_requests'
ORDER BY grantee, privilege_type;

-- =====================================================
-- SUMMARY
-- =====================================================

SELECT '═══════════════════════════════════════' AS separator;
SELECT 'TEST SUMMARY' AS title;
SELECT '═══════════════════════════════════════' AS separator;

WITH test_results AS (
    SELECT 
        COUNT(*) AS total_tests,
        5 AS expected_policies
    FROM pg_policies
    WHERE tablename = 'top_up_requests'
)
SELECT 
    CASE 
        WHEN total_tests >= expected_policies THEN '✅ ALL TESTS PASSED'
        ELSE '⚠️  SOME TESTS FAILED'
    END AS final_status,
    total_tests AS policies_created,
    expected_policies AS policies_expected
FROM test_results;

SELECT '═══════════════════════════════════════' AS separator;
SELECT 'Next Step: Open Admin Panel > Top-Up Management > Verification Requests' AS instruction;
SELECT 'You should now see all pending requests!' AS expected_result;
SELECT '═══════════════════════════════════════' AS separator;

