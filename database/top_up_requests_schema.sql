-- ============================================================================
-- TOP_UP_REQUESTS TABLE SCHEMA
-- ============================================================================
-- This file creates the top_up_requests table for student top-up requests
-- ============================================================================

-- ============================================================================
-- 1. CREATE TOP_UP_REQUESTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS top_up_requests (
    id BIGSERIAL PRIMARY KEY,
    user_id VARCHAR(50) NOT NULL REFERENCES auth_students(student_id),
    amount INTEGER NOT NULL CHECK (amount > 0),
    screenshot_url TEXT NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Pending Verification' CHECK (
        status IN ('Pending Verification', 'Approved', 'Rejected')
    ),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    processed_by TEXT,
    notes TEXT
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_top_up_requests_user_id ON top_up_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_top_up_requests_status ON top_up_requests(status);
CREATE INDEX IF NOT EXISTS idx_top_up_requests_created_at ON top_up_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_top_up_requests_processed_at ON top_up_requests(processed_at) WHERE processed_at IS NOT NULL;

-- ============================================================================
-- 3. ENABLE RLS
-- ============================================================================
ALTER TABLE top_up_requests ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 4. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access top_up_requests" ON top_up_requests;
CREATE POLICY "Service role full access top_up_requests"
ON top_up_requests
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Students can read and insert their own requests
DROP POLICY IF EXISTS "Students can manage own top_up_requests" ON top_up_requests;
CREATE POLICY "Students can manage own top_up_requests"
ON top_up_requests
FOR ALL
TO authenticated
USING (
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE auth_students.student_id = top_up_requests.user_id
        AND auth_students.auth_user_id = auth.uid()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM auth_students
        WHERE auth_students.student_id = top_up_requests.user_id
        AND auth_students.auth_user_id = auth.uid()
    )
);

-- ============================================================================
-- 5. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON top_up_requests TO service_role;
GRANT SELECT, INSERT, UPDATE ON top_up_requests TO authenticated;
GRANT USAGE ON SEQUENCE top_up_requests_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF TOP_UP_REQUESTS SCHEMA
-- ============================================================================

