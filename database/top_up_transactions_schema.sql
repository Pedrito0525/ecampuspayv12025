-- ============================================================================
-- TOP_UP_TRANSACTIONS TABLE SCHEMA
-- ============================================================================
-- This file creates the top_up_transactions table for tracking top-up history
-- ============================================================================

-- ============================================================================
-- 0. CREATE HELPER FUNCTION FOR PHILIPPINES TIME (PLAIN TIMESTAMP)
-- ============================================================================
-- This function returns the current Philippines time as TIMESTAMP WITHOUT TIME ZONE
-- It stores PH local time exactly as it is, with no timezone conversion
CREATE OR REPLACE FUNCTION get_philippines_time_plain()
RETURNS TIMESTAMP WITHOUT TIME ZONE AS $$
BEGIN
    -- Convert current UTC time to Philippines (Asia/Manila) timezone
    -- and return as plain timestamp (no timezone info)
    -- This ensures the timestamp stored is exactly the PH local time
    -- 
    -- Explanation:
    -- now() returns TIMESTAMP WITH TIME ZONE in UTC (e.g., 2025-11-23 06:45:00+00)
    -- AT TIME ZONE 'Asia/Manila' converts UTC to Manila local time (e.g., 2025-11-23 14:45:00)
    -- This returns TIMESTAMP WITHOUT TIME ZONE which is exactly what we want
    RETURN (now() AT TIME ZONE 'Asia/Manila')::TIMESTAMP WITHOUT TIME ZONE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 1. CREATE TOP_UP_TRANSACTIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS top_up_transactions (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL REFERENCES auth_students(student_id),
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    previous_balance DECIMAL(10,2) NOT NULL CHECK (previous_balance >= 0),
    new_balance DECIMAL(10,2) NOT NULL CHECK (new_balance >= 0),
    transaction_type VARCHAR(50) NOT NULL DEFAULT 'top_up' CHECK (
        transaction_type IN ('top_up', 'top_up_gcash', 'top_up_services', 'loan_disbursement')
    ),
    processed_by VARCHAR(100),
    notes TEXT,
    admin_earn DECIMAL(10,2) DEFAULT 0.00 CHECK (admin_earn >= 0),
    created_at TIMESTAMP WITHOUT TIME ZONE DEFAULT get_philippines_time_plain(),
    updated_at TIMESTAMP WITHOUT TIME ZONE DEFAULT get_philippines_time_plain(),
    
    -- Constraint to ensure balance calculation is correct
    CONSTRAINT check_balance_calculation CHECK (new_balance = previous_balance + amount)
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_top_up_transactions_student_id ON top_up_transactions(student_id);
CREATE INDEX IF NOT EXISTS idx_top_up_transactions_created_at ON top_up_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_top_up_transactions_transaction_type ON top_up_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_top_up_transactions_processed_by ON top_up_transactions(processed_by) WHERE processed_by IS NOT NULL;

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_top_up_transactions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = get_philippines_time_plain();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_top_up_transactions_updated_at ON top_up_transactions;
CREATE TRIGGER update_top_up_transactions_updated_at
    BEFORE UPDATE ON top_up_transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_top_up_transactions_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE top_up_transactions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access top_up_transactions" ON top_up_transactions;
CREATE POLICY "Service role full access top_up_transactions"
ON top_up_transactions
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Students can read their own transactions
DROP POLICY IF EXISTS "Students can read own top_up_transactions" ON top_up_transactions;
CREATE POLICY "Students can read own top_up_transactions"
ON top_up_transactions
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE auth_students.student_id = top_up_transactions.student_id
        AND auth_students.auth_user_id = auth.uid()
    )
);

-- Authenticated users can insert (for admin processing)
DROP POLICY IF EXISTS "Authenticated can insert top_up_transactions" ON top_up_transactions;
CREATE POLICY "Authenticated can insert top_up_transactions"
ON top_up_transactions
FOR INSERT
TO authenticated
WITH CHECK (true);

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON top_up_transactions TO service_role;
GRANT SELECT, INSERT ON top_up_transactions TO authenticated;
GRANT USAGE ON SEQUENCE top_up_transactions_id_seq TO service_role, authenticated;
GRANT EXECUTE ON FUNCTION get_philippines_time_plain() TO service_role, authenticated;

-- ============================================================================
-- END OF TOP_UP_TRANSACTIONS SCHEMA
-- ============================================================================

