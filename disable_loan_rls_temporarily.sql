-- Temporarily disable RLS for loan tables to test functionality
-- This allows all authenticated users to manage loan data

-- Disable RLS on loan tables
ALTER TABLE loan_plans DISABLE ROW LEVEL SECURITY;
ALTER TABLE active_loans DISABLE ROW LEVEL SECURITY;
ALTER TABLE loan_payments DISABLE ROW LEVEL SECURITY;

-- Drop all existing policies to avoid conflicts
DROP POLICY IF EXISTS "Allow read loan_plans" ON loan_plans;
DROP POLICY IF EXISTS "Allow manage loan_plans" ON loan_plans;
DROP POLICY IF EXISTS "Admins can manage loan_plans" ON loan_plans;
DROP POLICY IF EXISTS "Students can read own loans" ON active_loans;
DROP POLICY IF EXISTS "Allow manage active_loans" ON active_loans;
DROP POLICY IF EXISTS "Admins can manage active_loans" ON active_loans;
DROP POLICY IF EXISTS "Students can read own payments" ON loan_payments;
DROP POLICY IF EXISTS "Allow manage loan_payments" ON loan_payments;
DROP POLICY IF EXISTS "Admins can manage loan_payments" ON loan_payments;
DROP POLICY IF EXISTS "Service role full access loan_plans" ON loan_plans;
DROP POLICY IF EXISTS "Service role full access active_loans" ON active_loans;
DROP POLICY IF EXISTS "Service role full access loan_payments" ON loan_payments;

-- Now all authenticated users can manage loan data without RLS restrictions
-- This is temporary for testing - you can re