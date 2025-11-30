-- ============================================================================
-- ACTIVE_LOANS TABLE SCHEMA
-- ============================================================================
-- This file creates the active_loans table for student loan applications
-- ============================================================================

-- ============================================================================
-- 1. CREATE ACTIVE_LOANS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS active_loans (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL REFERENCES auth_students(student_id),
    loan_plan_id INTEGER NOT NULL REFERENCES loan_plans(id),
    loan_amount DECIMAL(10,2) NOT NULL CHECK (loan_amount > 0),
    interest_amount DECIMAL(10,2) NOT NULL CHECK (interest_amount >= 0),
    penalty_amount DECIMAL(10,2) DEFAULT 0 CHECK (penalty_amount >= 0),
    total_amount DECIMAL(10,2) NOT NULL CHECK (total_amount > 0),
    term_days INTEGER NOT NULL CHECK (term_days > 0),
    due_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paid', 'overdue')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    paid_at TIMESTAMP WITH TIME ZONE
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_active_loans_student_id ON active_loans(student_id);
CREATE INDEX IF NOT EXISTS idx_active_loans_status ON active_loans(status);
CREATE INDEX IF NOT EXISTS idx_active_loans_due_date ON active_loans(due_date);
CREATE INDEX IF NOT EXISTS idx_active_loans_loan_plan_id ON active_loans(loan_plan_id);
CREATE INDEX IF NOT EXISTS idx_active_loans_created_at ON active_loans(created_at DESC);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_active_loans_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_active_loans_updated_at ON active_loans;
CREATE TRIGGER update_active_loans_updated_at
    BEFORE UPDATE ON active_loans
    FOR EACH ROW
    EXECUTE FUNCTION update_active_loans_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE active_loans ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access active_loans" ON active_loans;
CREATE POLICY "Service role full access active_loans"
ON active_loans
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Students can read their own loans
DROP POLICY IF EXISTS "Students can read own active_loans" ON active_loans;
CREATE POLICY "Students can read own active_loans"
ON active_loans
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE auth_students.student_id = active_loans.student_id
        AND auth_students.auth_user_id = auth.uid()
    )
);

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON active_loans TO service_role;
GRANT SELECT ON active_loans TO authenticated;
GRANT INSERT ON active_loans TO authenticated;
GRANT USAGE ON SEQUENCE active_loans_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF ACTIVE_LOANS SCHEMA
-- ============================================================================

