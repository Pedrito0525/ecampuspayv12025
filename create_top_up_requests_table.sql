-- =====================================================
-- Create top_up_requests Table for GCash Verification
-- =====================================================
-- This script creates the table to store student top-up requests
-- that need admin verification
-- =====================================================

-- Create the table
CREATE TABLE IF NOT EXISTS public.top_up_requests (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    amount INTEGER NOT NULL CHECK (amount IN (100, 200, 500)),
    screenshot_url TEXT NOT NULL,
    gcash_reference TEXT,
    status TEXT NOT NULL DEFAULT 'Pending Verification' CHECK (status IN ('Pending Verification', 'Approved', 'Rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    processed_by TEXT,
    admin_notes TEXT,
    CONSTRAINT fk_user_id FOREIGN KEY (user_id) REFERENCES public.auth_students(student_id) ON DELETE CASCADE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_top_up_requests_user_id ON public.top_up_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_top_up_requests_status ON public.top_up_requests(status);
CREATE INDEX IF NOT EXISTS idx_top_up_requests_created_at ON public.top_up_requests(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.top_up_requests ENABLE ROW LEVEL SECURITY;

-- Drop existing policies
DROP POLICY IF EXISTS "Allow admin read access to top_up_requests" ON public.top_up_requests;
DROP POLICY IF EXISTS "Allow admin update access to top_up_requests" ON public.top_up_requests;
DROP POLICY IF EXISTS "Allow admin delete access to top_up_requests" ON public.top_up_requests;
DROP POLICY IF EXISTS "Allow students to insert their own requests" ON public.top_up_requests;
DROP POLICY IF EXISTS "Allow students to read their own requests" ON public.top_up_requests;
DROP POLICY IF EXISTS "public_all_access" ON public.top_up_requests;
DROP POLICY IF EXISTS "service_role_full_access" ON public.top_up_requests;
DROP POLICY IF EXISTS "public_read_all" ON public.top_up_requests;
DROP POLICY IF EXISTS "public_insert" ON public.top_up_requests;
DROP POLICY IF EXISTS "public_update" ON public.top_up_requests;
DROP POLICY IF EXISTS "public_delete" ON public.top_up_requests;

-- Policy 1: Allow service_role (admin) FULL ACCESS
CREATE POLICY "service_role_full_access"
ON public.top_up_requests
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy 2: Allow public to SELECT all (for admin panel using service key)
CREATE POLICY "public_read_all"
ON public.top_up_requests
FOR SELECT
USING (true);

-- Policy 3: Allow public to INSERT (for students submitting requests)
CREATE POLICY "public_insert"
ON public.top_up_requests
FOR INSERT
WITH CHECK (true);

-- Policy 4: Allow public to UPDATE (for admin status changes)
CREATE POLICY "public_update"
ON public.top_up_requests
FOR UPDATE
USING (true)
WITH CHECK (true);

-- Policy 5: Allow public to DELETE (for admin after processing)
CREATE POLICY "public_delete"
ON public.top_up_requests
FOR DELETE
USING (true);

-- Grant permissions to all roles
GRANT ALL ON public.top_up_requests TO public;
GRANT ALL ON public.top_up_requests TO anon;
GRANT ALL ON public.top_up_requests TO authenticated;
GRANT ALL ON public.top_up_requests TO service_role;

-- Grant sequence permissions
GRANT USAGE, SELECT ON SEQUENCE public.top_up_requests_id_seq TO public;
GRANT USAGE, SELECT ON SEQUENCE public.top_up_requests_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE public.top_up_requests_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.top_up_requests_id_seq TO service_role;

-- Verify table was created
SELECT 
    '✅ Table Created Successfully' AS status,
    tablename AS table_name,
    schemaname AS schema_name
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'top_up_requests';

-- List all policies
SELECT 
    '✅ Policies Created' AS status,
    policyname AS "Policy Name",
    cmd AS "Command"
FROM pg_policies
WHERE tablename = 'top_up_requests'
ORDER BY policyname;

-- Insert test data (optional - comment out if not needed)
-- INSERT INTO public.top_up_requests (user_id, amount, screenshot_url, gcash_reference) VALUES
-- ('EVSU-2024-001', 100, 'https://example.com/proof1.jpg', 'GC12345678'),
-- ('EVSU-2024-002', 200, 'https://example.com/proof2.jpg', 'GC87654321');

-- Verify test data (if inserted)
-- SELECT * FROM public.top_up_requests;

-- =====================================================
-- NOTES:
-- =====================================================
-- 
-- This table stores top-up requests from students that need
-- admin verification before being processed.
--
-- Fields:
-- - id: Auto-increment primary key
-- - user_id: Student ID (foreign key to auth_students)
-- - amount: Top-up amount (100, 200, or 500 only)
-- - screenshot_url: URL to proof of payment screenshot in Supabase Storage
-- - gcash_reference: GCash reference number entered by student
-- - status: 'Pending Verification', 'Approved', or 'Rejected'
-- - created_at: When request was submitted
-- - processed_at: When admin processed the request
-- - processed_by: Admin username who processed it
-- - admin_notes: Optional notes from admin
--
-- The admin can:
-- 1. View all pending requests
-- 2. See proof of payment and reference number
-- 3. Approve (adds balance, moves to top_up_transactions, deletes request)
-- 4. Reject (deletes request with optional reason)
--
-- =====================================================

\echo '═══════════════════════════════════════'
\echo 'TABLE CREATION COMPLETE'
\echo '═══════════════════════════════════════'
\echo ''
\echo 'Next steps:'
\echo '1. Verify table exists in Supabase Dashboard'
\echo '2. Test by hot-restarting your Flutter app'
\echo '3. Go to Admin Panel > Top-Up Management > Verification Requests'
\echo '4. Check console for debug messages'
\echo ''
\echo 'If you want to test with sample data, uncomment the INSERT statement above'
\echo ''

