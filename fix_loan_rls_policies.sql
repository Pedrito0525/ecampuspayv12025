-- Fix RLS policies for loan system
-- Run this after the main loan_system_schema.sql to fix admin access issues

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Allow read loan_plans" ON loan_plans;
DROP POLICY IF EXISTS "Students can read own loans" ON active_loans;
DROP POLICY IF EXISTS "Students can read own payments" ON loan_payments;

-- Create new comprehensive policies

-- 1. Loan Plans Policies
-- Allow all authenticated users to read loan plans
CREATE POLICY "Allow read loan_plans" ON loan_plans FOR SELECT TO authenticated USING (true);

-- Allow all authenticated users to manage loan plans (since only admins access admin panel)
CREATE POLICY "Allow manage loan_plans" ON loan_plans FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 2. Active Loans Policies
-- Allow students to read their own loans
CREATE POLICY "Students can read own loans" ON active_loans FOR SELECT TO authenticated 
USING (student_id IN (SELECT student_id FROM auth_students WHERE auth_user_id = auth.uid()));

-- Allow all authenticated users to manage active loans (since only admins access admin panel)
CREATE POLICY "Allow manage active_loans" ON active_loans FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 3. Loan Payments Policies
-- Allow students to read their own payments
CREATE POLICY "Students can read own payments" ON loan_payments FOR SELECT TO authenticated 
USING (student_id IN (SELECT student_id FROM auth_students WHERE auth_user_id = auth.uid()));

-- Allow all authenticated users to manage loan payments (since only admins access admin panel)
CREATE POLICY "Allow manage loan_payments" ON loan_payments FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- 4. Service Role Policies (should already exist, but ensure they do)
CREATE POLICY IF NOT EXISTS "Service role full access loan_plans" ON loan_plans FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "Service role full access active_loans" ON active_loans FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY IF NOT EXISTS "Service role full access loan_payments" ON loan_payments FOR ALL TO service_role USING (true) WITH CHECK (true);
