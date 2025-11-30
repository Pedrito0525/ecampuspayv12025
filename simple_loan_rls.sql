-- Simplest possible RLS policies for loan system
-- This should definitely work

-- Disable RLS first
ALTER TABLE loan_plans DISABLE ROW LEVEL SECURITY;
ALTER TABLE active_loans DISABLE ROW LEVEL SECURITY;
ALTER TABLE loan_payments DISABLE ROW LEVEL SECURITY;

-- Drop any existing policies
DROP POLICY IF EXISTS "loan_plans_authenticated_all" ON loan_plans;
DROP POLICY IF EXISTS "active_loans_authenticated_all" ON active_loans;
DROP POLICY IF EXISTS "loan_payments_authenticated_all" ON loan_payments;
DROP POLICY IF EXISTS "loan_plans_service_all" ON loan_plans;
DROP POLICY IF EXISTS "active_loans_service_all" ON active_loans;
DROP POLICY IF EXISTS "loan_payments_service_all" ON loan_payments;

-- Re-enable RLS
ALTER TABLE loan_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE active_loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_payments ENABLE ROW LEVEL SECURITY;

-- Create the most basic policies possible
-- These should work without any issues

-- For loan_plans - allow everything for authenticated users
CREATE POLICY "loan_plans_policy" ON loan_plans 
FOR ALL TO authenticated 
USING (true) 
WITH CHECK (true);

-- For active_loans - allow everything for authenticated users
CREATE POLICY "active_loans_policy" ON active_loans 
FOR ALL TO authenticated 
USING (true) 
WITH CHECK (true);

-- For loan_payments - allow everything for authenticated users
CREATE POLICY "loan_payments_policy" ON loan_payments 
FOR ALL TO authenticated 
USING (true) 
WITH CHECK (true);
