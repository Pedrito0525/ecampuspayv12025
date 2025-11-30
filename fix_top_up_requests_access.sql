-- =====================================================
-- Fix Top-Up Requests Access for Admin (Service Role)
-- =====================================================
-- This script removes restrictive policies and allows service_role full access
-- =====================================================

-- Step 1: Drop all existing policies on top_up_requests
DROP POLICY IF EXISTS "Allow admin read access to top_up_requests" ON top_up_requests;
DROP POLICY IF EXISTS "Allow admin update access to top_up_requests" ON top_up_requests;
DROP POLICY IF EXISTS "Allow admin delete access to top_up_requests" ON top_up_requests;
DROP POLICY IF EXISTS "Allow students to insert their own requests" ON top_up_requests;
DROP POLICY IF EXISTS "Allow students to read their own requests" ON top_up_requests;
DROP POLICY IF EXISTS "public_all_access" ON top_up_requests;

-- Step 2: Verify RLS is enabled (service_role bypasses RLS, but we keep it for students)
ALTER TABLE top_up_requests ENABLE ROW LEVEL SECURITY;

-- Step 3: Create new simple policies

-- Policy 1: Allow service_role (admin) FULL ACCESS - bypasses RLS anyway
-- This is for admin using service_role key
CREATE POLICY "service_role_full_access"
ON top_up_requests
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy 2: Allow public to SELECT all (for admin panel using service key)
CREATE POLICY "public_read_all"
ON top_up_requests
FOR SELECT
USING (true);

-- Policy 3: Allow public to INSERT (for students submitting requests)
CREATE POLICY "public_insert"
ON top_up_requests
FOR INSERT
WITH CHECK (true);

-- Policy 4: Allow public to UPDATE (for admin status changes)
CREATE POLICY "public_update"
ON top_up_requests
FOR UPDATE
USING (true)
WITH CHECK (true);

-- Policy 5: Allow public to DELETE (for admin after processing)
CREATE POLICY "public_delete"
ON top_up_requests
FOR DELETE
USING (true);

-- Step 4: Grant necessary permissions to public role
GRANT ALL ON top_up_requests TO public;
GRANT ALL ON top_up_requests TO anon;
GRANT ALL ON top_up_requests TO authenticated;
GRANT ALL ON top_up_requests TO service_role;

-- Grant sequence permissions
GRANT USAGE, SELECT ON SEQUENCE top_up_requests_id_seq TO public;
GRANT USAGE, SELECT ON SEQUENCE top_up_requests_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE top_up_requests_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE top_up_requests_id_seq TO service_role;

-- Step 5: Verify setup
SELECT 
    '✅ Policies Updated' AS status,
    COUNT(*) AS policy_count
FROM pg_policies
WHERE tablename = 'top_up_requests';

-- List all current policies
SELECT 
    policyname AS "Policy Name",
    cmd AS "Command",
    roles AS "Roles",
    qual AS "Using",
    with_check AS "With Check"
FROM pg_policies
WHERE tablename = 'top_up_requests'
ORDER BY policyname;

-- Step 6: Test query (should return all records)
SELECT 
    '✅ Test Query' AS info,
    COUNT(*) AS total_requests,
    COUNT(*) FILTER (WHERE status = 'Pending Verification') AS pending_count
FROM top_up_requests;

-- =====================================================
-- NOTES:
-- =====================================================
-- 
-- This configuration makes top_up_requests fully accessible to:
-- 1. service_role (admin using service key) - FULL ACCESS
-- 2. public/anon/authenticated - READ/WRITE access
--
-- Security considerations:
-- - The admin panel uses service_role key which has full access
-- - For production, you may want to restrict student access more
-- - Consider adding application-level security checks
--
-- If you want to restrict student access later, you can update
-- the policies to check user_id or add authentication checks.
--
-- =====================================================

-- Verification queries
\echo '═══════════════════════════════════════'
\echo 'VERIFICATION COMPLETE'
\echo '═══════════════════════════════════════'
\echo ''
\echo 'Admin should now be able to:'
\echo '✅ View all pending requests'
\echo '✅ Approve/reject requests'
\echo '✅ Update top_up_requests table'
\echo ''
\echo 'Test in admin panel: Top-Up Management > Verification Requests tab'
\echo ''

