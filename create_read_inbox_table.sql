-- Read Inbox Tracking Schema (without inbox table)
-- This script creates the read_inbox table and helper functions/policies
-- for tracking read/unread status across transaction tables.

-- =====================================================
-- 1. CREATE READ_INBOX TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS read_inbox (
    id BIGSERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL,
    transaction_type VARCHAR(50) NOT NULL,
    transaction_id BIGINT NOT NULL,
    read_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- A student can only mark a specific transaction once
    UNIQUE(student_id, transaction_type, transaction_id)
);

-- =====================================================
-- 2. CREATE INDEXES FOR PERFORMANCE
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_read_inbox_student_id ON read_inbox(student_id);
CREATE INDEX IF NOT EXISTS idx_read_inbox_transaction_type ON read_inbox(transaction_type);
CREATE INDEX IF NOT EXISTS idx_read_inbox_transaction_id ON read_inbox(transaction_id);
CREATE INDEX IF NOT EXISTS idx_read_inbox_read_at ON read_inbox(read_at);

-- =====================================================
-- 3. ENABLE ROW LEVEL SECURITY (RLS)
-- =====================================================

ALTER TABLE read_inbox ENABLE ROW LEVEL SECURITY;

-- Remove existing policies if they exist (idempotent)
DROP POLICY IF EXISTS "Users can view their read transactions" ON read_inbox;
DROP POLICY IF EXISTS "Users can insert their read transactions" ON read_inbox;
DROP POLICY IF EXISTS "Users can delete their read transactions" ON read_inbox;
DROP POLICY IF EXISTS "Service role full access to read_inbox" ON read_inbox;
DROP POLICY IF EXISTS "Anonymous can insert read_inbox" ON read_inbox;

-- =====================================================
-- 4. CREATE RLS POLICIES
-- =====================================================

-- Policy: Users can SELECT records they own
CREATE POLICY "Users can view their read transactions" ON read_inbox
    FOR SELECT
    TO authenticated
    USING (
        auth.uid() IS NOT NULL AND student_id = (
            SELECT student_id FROM auth_students
            WHERE auth_user_id = auth.uid() AND is_active = true
        )
    );

-- Policy: Users can INSERT read markers for their own transactions
CREATE POLICY "Users can insert their read transactions" ON read_inbox
    FOR INSERT
    TO authenticated
    WITH CHECK (
        auth.uid() IS NOT NULL AND student_id = (
            SELECT student_id FROM auth_students
            WHERE auth_user_id = auth.uid() AND is_active = true
        )
    );

-- Optional: Users may delete their read markers (e.g., to re-mark as unread)
CREATE POLICY "Users can delete their read transactions" ON read_inbox
    FOR DELETE
    TO authenticated
    USING (
        auth.uid() IS NOT NULL AND student_id = (
            SELECT student_id FROM auth_students
            WHERE auth_user_id = auth.uid() AND is_active = true
        )
    );

-- Service role full access
CREATE POLICY "Service role full access to read_inbox" ON read_inbox
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Optional: Allow anon inserts if system functions run as anon
CREATE POLICY "Anonymous can insert read_inbox" ON read_inbox
    FOR INSERT
    TO anon
    WITH CHECK (true);

-- =====================================================
-- 5. GRANT PERMISSIONS
-- =====================================================

GRANT SELECT, INSERT, DELETE ON read_inbox TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE read_inbox_id_seq TO authenticated;
GRANT ALL ON read_inbox TO service_role;
GRANT INSERT ON read_inbox TO anon;
GRANT USAGE, SELECT ON SEQUENCE read_inbox_id_seq TO anon;

-- =====================================================
-- 6. HELPER FUNCTION: mark transaction as read
-- =====================================================

CREATE OR REPLACE FUNCTION mark_transaction_as_read(
    p_student_id VARCHAR(50),
    p_transaction_type VARCHAR(50),
    p_transaction_id BIGINT
)
RETURNS BOOLEAN AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- Insert (or update timestamp) for the read transaction
    INSERT INTO read_inbox (student_id, transaction_type, transaction_id, read_at)
    VALUES (p_student_id, p_transaction_type, p_transaction_id, NOW())
    ON CONFLICT (student_id, transaction_type, transaction_id) DO UPDATE
    SET read_at = EXCLUDED.read_at;

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION mark_transaction_as_read TO authenticated;
GRANT EXECUTE ON FUNCTION mark_transaction_as_read TO anon;

-- =====================================================
-- 7. HELPER FUNCTION: get unread count
-- =====================================================

CREATE OR REPLACE FUNCTION get_unread_transaction_count(p_student_id VARCHAR(50))
RETURNS INTEGER AS $$
DECLARE
    v_top_up INTEGER;
    v_service INTEGER;
    v_transfer INTEGER;
    v_read INTEGER;
BEGIN
    -- Count transactions from each source table
    SELECT COUNT(*) INTO v_top_up
    FROM top_up_transactions
    WHERE student_id = p_student_id;

    SELECT COUNT(*) INTO v_service
    FROM service_transactions
    WHERE student_id = p_student_id;

    SELECT COUNT(*) INTO v_transfer
    FROM user_transfers
    WHERE sender_student_id = p_student_id OR recipient_student_id = p_student_id;

    SELECT COUNT(*) INTO v_read
    FROM read_inbox
    WHERE student_id = p_student_id;

    RETURN (v_top_up + v_service + v_transfer) - v_read;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION get_unread_transaction_count TO authenticated;

-- =====================================================
-- 8. VERIFICATION QUERIES
-- =====================================================

-- Verify table creation and row counts
SELECT 'read_inbox table' AS table_name, COUNT(*) AS row_count FROM read_inbox;

-- View RLS policies for sanity check
SELECT schemaname, tablename, policyname, permissive, roles, cmd
FROM pg_policies
WHERE tablename = 'read_inbox'
ORDER BY policyname;
