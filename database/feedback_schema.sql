-- ============================================================================
-- FEEDBACK TABLE SCHEMA
-- ============================================================================
-- This file creates the feedback table for storing feedback from users and services
-- ============================================================================

-- ============================================================================
-- 1. CREATE FEEDBACK TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS feedback (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('user', 'service_account')),
    account_username VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_feedback_user_type ON feedback(user_type);
CREATE INDEX IF NOT EXISTS idx_feedback_created_at ON feedback(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_username ON feedback(account_username);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_feedback_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_feedback_updated_at_trigger ON feedback;
CREATE TRIGGER update_feedback_updated_at_trigger
    BEFORE UPDATE ON feedback
    FOR EACH ROW
    EXECUTE FUNCTION update_feedback_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access feedback" ON feedback;
CREATE POLICY "Service role full access feedback"
ON feedback
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Service accounts can insert and view all feedback
DROP POLICY IF EXISTS "Service accounts can manage feedback" ON feedback;
CREATE POLICY "Service accounts can manage feedback"
ON feedback
FOR ALL
TO authenticated
USING (
    user_type = 'service_account' OR
    EXISTS (
        SELECT 1 FROM service_accounts
        WHERE username = account_username
        AND is_active = true
    )
)
WITH CHECK (
    user_type = 'service_account' OR
    EXISTS (
        SELECT 1 FROM service_accounts
        WHERE username = account_username
        AND is_active = true
    )
);

-- Users can insert and view their own feedback
DROP POLICY IF EXISTS "Users can manage own feedback" ON feedback;
CREATE POLICY "Users can manage own feedback"
ON feedback
FOR ALL
TO authenticated
USING (
    user_type = 'user' AND
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE student_id = account_username
        AND auth_user_id = auth.uid()
    )
)
WITH CHECK (
    user_type = 'user' AND
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE student_id = account_username
        AND auth_user_id = auth.uid()
    )
);

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON feedback TO service_role;
GRANT SELECT, INSERT ON feedback TO authenticated;

-- ============================================================================
-- END OF FEEDBACK SCHEMA
-- ============================================================================

