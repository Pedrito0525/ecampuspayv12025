-- =====================================================
-- Top-Up Requests Admin Access Policies
-- =====================================================
-- This file creates RLS policies for admin access to top_up_requests table
-- Admin accounts can read, update, and delete pending top-up requests
-- =====================================================

-- Enable Row Level Security on top_up_requests table
ALTER TABLE top_up_requests ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow admin read access to top_up_requests" ON top_up_requests;
DROP POLICY IF EXISTS "Allow admin update access to top_up_requests" ON top_up_requests;
DROP POLICY IF EXISTS "Allow admin delete access to top_up_requests" ON top_up_requests;
DROP POLICY IF EXISTS "Allow students to insert their own requests" ON top_up_requests;
DROP POLICY IF EXISTS "Allow students to read their own requests" ON top_up_requests;

-- =====================================================
-- ADMIN POLICIES (using service_role key)
-- =====================================================

-- Policy: Admin can read all top-up requests
-- This allows admins using service_role key to view all pending requests
CREATE POLICY "Allow admin read access to top_up_requests"
ON top_up_requests
FOR SELECT
TO authenticated
USING (true);  -- Service role bypasses RLS, but we define this for authenticated admins

-- Policy: Admin can update top-up requests (e.g., change status)
CREATE POLICY "Allow admin update access to top_up_requests"
ON top_up_requests
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- Policy: Admin can delete top-up requests (after approval/rejection)
CREATE POLICY "Allow admin delete access to top_up_requests"
ON top_up_requests
FOR DELETE
TO authenticated
USING (true);

-- =====================================================
-- STUDENT POLICIES
-- =====================================================

-- Policy: Students can insert their own top-up requests
CREATE POLICY "Allow students to insert their own requests"
ON top_up_requests
FOR INSERT
TO authenticated
WITH CHECK (true);  -- Students can insert requests

-- Policy: Students can read their own top-up requests
CREATE POLICY "Allow students to read their own requests"
ON top_up_requests
FOR SELECT
TO authenticated
USING (user_id = current_setting('request.jwt.claims', true)::json->>'student_id');

-- =====================================================
-- NOTES
-- =====================================================
-- 
-- The admin access uses the service_role key which bypasses RLS entirely.
-- The policies above are defined for completeness and for authenticated admin users.
-- 
-- In the Flutter app, we use:
-- - SupabaseService.adminClient (with service_role key) for admin operations
-- - SupabaseService.client (with anon key) for student operations
-- 
-- The service_role key should NEVER be exposed in the client app.
-- It should only be used in admin panels with proper authentication.
-- 
-- Security considerations:
-- 1. Ensure the admin panel requires login before accessing admin features
-- 2. Keep the service_role key secure and never commit it to public repositories
-- 3. Consider adding additional checks in the application layer for admin verification
-- 4. Audit all admin actions by logging processed_by field
-- 
-- =====================================================

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON top_up_requests TO authenticated;
GRANT USAGE ON SEQUENCE top_up_requests_id_seq TO authenticated;

-- Create index on status for faster queries
CREATE INDEX IF NOT EXISTS idx_top_up_requests_status ON top_up_requests(status);
CREATE INDEX IF NOT EXISTS idx_top_up_requests_user_id ON top_up_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_top_up_requests_created_at ON top_up_requests(created_at DESC);

-- Verify the policies are created
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
WHERE tablename = 'top_up_requests'
ORDER BY policyname;


