-- =====================================================
-- Top-Up Verification System - Setup Verification Script
-- =====================================================
-- Run this script to verify your top-up verification system is set up correctly
-- =====================================================

-- Check 1: Verify top_up_requests table exists
SELECT 
    'top_up_requests table' AS check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'top_up_requests'
        ) THEN '✅ PASS - Table exists'
        ELSE '❌ FAIL - Table does not exist'
    END AS status;

-- Check 2: Verify top_up_requests table structure
SELECT 
    'top_up_requests columns' AS check_name,
    CASE 
        WHEN (
            SELECT COUNT(*) 
            FROM information_schema.columns 
            WHERE table_name = 'top_up_requests' 
            AND column_name IN ('id', 'user_id', 'amount', 'screenshot_url', 'status', 'created_at', 'processed_at', 'processed_by', 'notes')
        ) >= 9 THEN '✅ PASS - All required columns present'
        ELSE '❌ FAIL - Missing required columns'
    END AS status;

-- Check 3: Verify top_up_transactions table exists
SELECT 
    'top_up_transactions table' AS check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.tables 
            WHERE table_name = 'top_up_transactions'
        ) THEN '✅ PASS - Table exists'
        ELSE '❌ FAIL - Table does not exist'
    END AS status;

-- Check 4: Verify RLS is enabled on top_up_requests
SELECT 
    'RLS on top_up_requests' AS check_name,
    CASE 
        WHEN (
            SELECT relrowsecurity 
            FROM pg_class 
            WHERE relname = 'top_up_requests'
        ) THEN '✅ PASS - RLS is enabled'
        ELSE '❌ FAIL - RLS is not enabled'
    END AS status;

-- Check 5: Verify policies exist
SELECT 
    'RLS Policies' AS check_name,
    CASE 
        WHEN (
            SELECT COUNT(*) 
            FROM pg_policies 
            WHERE tablename = 'top_up_requests'
        ) >= 4 THEN '✅ PASS - Policies are configured'
        ELSE '❌ FAIL - Policies missing or incomplete'
    END AS status;

-- Check 6: List all policies on top_up_requests
SELECT 
    '📋 Policy Details:' AS info,
    policyname AS policy_name,
    cmd AS command_type,
    permissive AS is_permissive
FROM pg_policies
WHERE tablename = 'top_up_requests'
ORDER BY policyname;

-- Check 7: Verify indexes exist
SELECT 
    'Indexes on top_up_requests' AS check_name,
    CASE 
        WHEN (
            SELECT COUNT(*) 
            FROM pg_indexes 
            WHERE tablename = 'top_up_requests'
        ) >= 3 THEN '✅ PASS - Indexes are created'
        ELSE '⚠️  WARNING - Some indexes may be missing'
    END AS status;

-- Check 8: List all indexes
SELECT 
    '📋 Index Details:' AS info,
    indexname AS index_name,
    indexdef AS index_definition
FROM pg_indexes
WHERE tablename = 'top_up_requests'
ORDER BY indexname;

-- Check 9: Count pending requests (sample query admin would use)
SELECT 
    '📊 Pending Requests Count' AS metric,
    COUNT(*) AS count,
    CASE 
        WHEN COUNT(*) > 0 THEN '✅ You have pending requests to review'
        ELSE '✅ No pending requests'
    END AS status
FROM top_up_requests
WHERE status = 'Pending Verification';

-- Check 10: Verify auth_students table has balance column
SELECT 
    'auth_students.balance column' AS check_name,
    CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM information_schema.columns 
            WHERE table_name = 'auth_students' 
            AND column_name = 'balance'
        ) THEN '✅ PASS - Balance column exists'
        ELSE '❌ FAIL - Balance column missing'
    END AS status;

-- =====================================================
-- Summary Report
-- =====================================================

SELECT 
    '═══════════════════════════════════════' AS separator,
    'SETUP VERIFICATION SUMMARY' AS title,
    '═══════════════════════════════════════' AS separator2;

-- Final verification check
WITH checks AS (
    SELECT COUNT(*) as total_checks,
           SUM(CASE 
               WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'top_up_requests')
               AND EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'top_up_transactions')
               AND (SELECT relrowsecurity FROM pg_class WHERE relname = 'top_up_requests')
               AND (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'top_up_requests') >= 4
               THEN 1 ELSE 0 
           END) as passed_checks
)
SELECT 
    'System Status' AS check_type,
    CASE 
        WHEN passed_checks = total_checks THEN '🎉 ALL CHECKS PASSED - System is ready!'
        ELSE '⚠️  SOME CHECKS FAILED - Review errors above'
    END AS final_status
FROM checks;

-- =====================================================
-- Sample Queries for Testing
-- =====================================================

-- View all pending requests (admin query)
-- SELECT * FROM top_up_requests WHERE status = 'Pending Verification' ORDER BY created_at DESC;

-- View recent transactions
-- SELECT * FROM top_up_transactions ORDER BY created_at DESC LIMIT 10;

-- View a specific student's balance
-- SELECT student_id, balance FROM auth_students WHERE student_id = 'YOUR_STUDENT_ID';

-- =====================================================
-- Next Steps
-- =====================================================

/*
If all checks passed:
✅ Your system is ready to use!
✅ Login to admin panel and test the verification tab

If some checks failed:
1. Review the error messages above
2. Run the setup scripts:
   - top_up_requests_admin_policy.sql
   - top_up_transactions_schema.sql
3. Verify Supabase Storage bucket "Proof Payment" exists
4. Re-run this verification script

For detailed documentation, see:
📖 TOPUP_VERIFICATION_SYSTEM.md
*/

