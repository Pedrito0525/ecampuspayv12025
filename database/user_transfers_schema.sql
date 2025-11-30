-- ============================================================================
-- USER_TRANSFERS TABLE SCHEMA
-- ============================================================================
-- This file creates the user_transfers table for money transfers between users
-- ============================================================================

-- ============================================================================
-- 1. CREATE USER_TRANSFERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_transfers (
    id SERIAL PRIMARY KEY,
    sender_student_id VARCHAR(50) NOT NULL REFERENCES auth_students(student_id),
    recipient_student_id VARCHAR(50) NOT NULL REFERENCES auth_students(student_id),
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    sender_previous_balance DECIMAL(10,2) NOT NULL CHECK (sender_previous_balance >= 0),
    sender_new_balance DECIMAL(10,2) NOT NULL CHECK (sender_new_balance >= 0),
    recipient_previous_balance DECIMAL(10,2) NOT NULL CHECK (recipient_previous_balance >= 0),
    recipient_new_balance DECIMAL(10,2) NOT NULL CHECK (recipient_new_balance >= 0),
    transaction_type VARCHAR(20) NOT NULL DEFAULT 'transfer' CHECK (transaction_type = 'transfer'),
    status VARCHAR(20) NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'failed', 'pending')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT check_no_self_transfer CHECK (sender_student_id != recipient_student_id),
    CONSTRAINT check_sender_balance_calculation CHECK (sender_new_balance = sender_previous_balance - amount),
    CONSTRAINT check_recipient_balance_calculation CHECK (recipient_new_balance = recipient_previous_balance + amount)
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_user_transfers_sender_student_id ON user_transfers(sender_student_id);
CREATE INDEX IF NOT EXISTS idx_user_transfers_recipient_student_id ON user_transfers(recipient_student_id);
CREATE INDEX IF NOT EXISTS idx_user_transfers_created_at ON user_transfers(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_transfers_status ON user_transfers(status);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_user_transfers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_user_transfers_updated_at ON user_transfers;
CREATE TRIGGER update_user_transfers_updated_at
    BEFORE UPDATE ON user_transfers
    FOR EACH ROW
    EXECUTE FUNCTION update_user_transfers_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE user_transfers ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access user_transfers" ON user_transfers;
CREATE POLICY "Service role full access user_transfers"
ON user_transfers
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Students can read transfers where they are sender or recipient
DROP POLICY IF EXISTS "Students can read own user_transfers" ON user_transfers;
CREATE POLICY "Students can read own user_transfers"
ON user_transfers
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE (auth_students.student_id = user_transfers.sender_student_id 
               OR auth_students.student_id = user_transfers.recipient_student_id)
        AND auth_students.auth_user_id = auth.uid()
    )
);

-- Students can insert transfers (as sender)
DROP POLICY IF EXISTS "Students can insert user_transfers" ON user_transfers;
CREATE POLICY "Students can insert user_transfers"
ON user_transfers
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE auth_students.student_id = user_transfers.sender_student_id
        AND auth_students.auth_user_id = auth.uid()
    )
);

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON user_transfers TO service_role;
GRANT SELECT, INSERT ON user_transfers TO authenticated;
GRANT USAGE ON SEQUENCE user_transfers_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF USER_TRANSFERS SCHEMA
-- ============================================================================

