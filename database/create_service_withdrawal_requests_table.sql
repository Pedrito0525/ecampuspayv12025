-- =====================================================
-- Create service_withdrawal_requests Table for Admin Approval
-- =====================================================
-- This script creates the table to store service account withdrawal requests
-- that need admin verification and approval
-- =====================================================

-- Create the table
CREATE TABLE IF NOT EXISTS public.service_withdrawal_requests (
    id BIGSERIAL PRIMARY KEY,
    service_account_id INTEGER NOT NULL,
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Approved', 'Rejected')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    processed_by TEXT,
    admin_notes TEXT,
    CONSTRAINT fk_service_account_id FOREIGN KEY (service_account_id) REFERENCES public.service_accounts(id) ON DELETE CASCADE
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_service_withdrawal_requests_service_account_id ON public.service_withdrawal_requests(service_account_id);
CREATE INDEX IF NOT EXISTS idx_service_withdrawal_requests_status ON public.service_withdrawal_requests(status);
CREATE INDEX IF NOT EXISTS idx_service_withdrawal_requests_created_at ON public.service_withdrawal_requests(created_at DESC);

-- Enable Row Level Security
ALTER TABLE public.service_withdrawal_requests ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Allow admin read access to service_withdrawal_requests" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "Allow admin update access to service_withdrawal_requests" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "Allow admin delete access to service_withdrawal_requests" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "Allow services to insert their own requests" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "Allow services to read their own requests" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "public_all_access" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "service_role_full_access" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "public_read_all" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "public_insert" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "public_update" ON public.service_withdrawal_requests;
DROP POLICY IF EXISTS "public_delete" ON public.service_withdrawal_requests;

-- Policy 1: Allow service_role (admin) FULL ACCESS
CREATE POLICY "service_role_full_access"
ON public.service_withdrawal_requests
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy 2: Allow public to SELECT all (for admin panel using service key)
CREATE POLICY "public_read_all"
ON public.service_withdrawal_requests
FOR SELECT
USING (true);

-- Policy 3: Allow public to INSERT (for service accounts submitting requests)
CREATE POLICY "public_insert"
ON public.service_withdrawal_requests
FOR INSERT
WITH CHECK (true);

-- Policy 4: Allow public to UPDATE (for admin status changes)
CREATE POLICY "public_update"
ON public.service_withdrawal_requests
FOR UPDATE
USING (true)
WITH CHECK (true);

-- Policy 5: Allow public to DELETE (for admin after processing)
CREATE POLICY "public_delete"
ON public.service_withdrawal_requests
FOR DELETE
USING (true);

-- Grant permissions to all roles
GRANT ALL ON public.service_withdrawal_requests TO public;
GRANT ALL ON public.service_withdrawal_requests TO anon;
GRANT ALL ON public.service_withdrawal_requests TO authenticated;
GRANT ALL ON public.service_withdrawal_requests TO service_role;

-- Grant sequence permissions
GRANT USAGE, SELECT ON SEQUENCE public.service_withdrawal_requests_id_seq TO public;
GRANT USAGE, SELECT ON SEQUENCE public.service_withdrawal_requests_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE public.service_withdrawal_requests_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.service_withdrawal_requests_id_seq TO service_role;

-- Verify table was created
SELECT 
    '✅ Table Created Successfully' AS status,
    tablename AS table_name,
    schemaname AS schema_name
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'service_withdrawal_requests';

-- List all policies
SELECT 
    '✅ Policies Created' AS status,
    policyname AS "Policy Name",
    cmd AS "Command"
FROM pg_policies
WHERE tablename = 'service_withdrawal_requests'
ORDER BY policyname;

-- =====================================================
-- NOTES:
-- =====================================================
-- 
-- This table stores withdrawal requests from service accounts that need
-- admin verification before being processed.
--
-- Fields:
-- - id: Auto-increment primary key
-- - service_account_id: Service account ID (foreign key to service_accounts)
-- - amount: Withdrawal amount (must be > 0)
-- - status: 'Pending', 'Approved', or 'Rejected'
-- - created_at: When request was submitted
-- - processed_at: When admin processed the request
-- - processed_by: Admin username who processed it
-- - admin_notes: Optional notes from admin
--
-- The admin can:
-- 1. View all pending requests
-- 2. See withdrawal details (amount, service name)
-- 3. Approve (deducts balance, creates withdrawal_transaction, updates status)
-- 4. Reject (updates status with optional reason, no balance change)
--
-- Service accounts can:
-- 1. Submit withdrawal requests
-- 2. View their withdrawal request history with status
-- 3. See pending, approved, or rejected requests
--
-- =====================================================

\echo '═══════════════════════════════════════'
\echo 'Service Withdrawal Requests Table Created'
\echo '═══════════════════════════════════════'












