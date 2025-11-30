-- ============================================================================
-- LOAN_PAYMENTS TABLE SCHEMA
-- ============================================================================
-- This file creates the loan_payments table for tracking loan payments
-- ============================================================================

-- ============================================================================
-- 1. CREATE LOAN_PAYMENTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS loan_payments (
    id SERIAL PRIMARY KEY,
    loan_id INTEGER NOT NULL REFERENCES active_loans(id),
    student_id VARCHAR(50) NOT NULL REFERENCES auth_students(student_id),
    payment_amount DECIMAL(10,2) NOT NULL CHECK (payment_amount > 0),
    payment_type VARCHAR(20) NOT NULL DEFAULT 'full' CHECK (payment_type IN ('full', 'partial')),
    remaining_balance DECIMAL(10,2) NOT NULL CHECK (remaining_balance >= 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_loan_payments_loan_id ON loan_payments(loan_id);
CREATE INDEX IF NOT EXISTS idx_loan_payments_student_id ON loan_payments(student_id);
CREATE INDEX IF NOT EXISTS idx_loan_payments_created_at ON loan_payments(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_loan_payments_payment_type ON loan_payments(payment_type);

-- ============================================================================
-- 3. ENABLE RLS
-- ============================================================================
ALTER TABLE loan_payments ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 4. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access loan_payments" ON loan_payments;
CREATE POLICY "Service role full access loan_payments"
ON loan_payments
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Students can read their own loan payments
DROP POLICY IF EXISTS "Students can read own loan_payments" ON loan_payments;
CREATE POLICY "Students can read own loan_payments"
ON loan_payments
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE auth_students.student_id = loan_payments.student_id
        AND auth_students.auth_user_id = auth.uid()
    )
);

-- ============================================================================
-- 5. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON loan_payments TO service_role;
GRANT SELECT ON loan_payments TO authenticated;
GRANT INSERT ON loan_payments TO authenticated;
GRANT USAGE ON SEQUENCE loan_payments_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF LOAN_PAYMENTS SCHEMA
-- ============================================================================

