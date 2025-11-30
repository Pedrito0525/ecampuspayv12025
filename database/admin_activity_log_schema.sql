-- ============================================================================
-- ADMIN_ACTIVITY_LOG TABLE SCHEMA
-- ============================================================================
-- This file creates the admin_activity_log table for tracking admin actions
-- ============================================================================

-- ============================================================================
-- 1. CREATE ADMIN_ACTIVITY_LOG TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS admin_activity_log (
    id BIGSERIAL PRIMARY KEY,
    admin_username VARCHAR(50) NOT NULL,
    action TEXT NOT NULL,
    description TEXT,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_admin_username ON admin_activity_log(admin_username);
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_timestamp ON admin_activity_log(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_action ON admin_activity_log(action);
CREATE INDEX IF NOT EXISTS idx_admin_activity_log_created_at ON admin_activity_log(created_at DESC);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to log admin activity
CREATE OR REPLACE FUNCTION log_admin_activity(
    p_admin_username VARCHAR(50),
    p_action TEXT,
    p_description TEXT DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    log_id BIGINT;
BEGIN
    INSERT INTO admin_activity_log (admin_username, action, description)
    VALUES (p_admin_username, p_action, p_description)
    RETURNING id INTO log_id;
    
    RETURN json_build_object(
        'success', true,
        'log_id', log_id,
        'message', 'Activity logged successfully'
    );
EXCEPTION
    WHEN OTHERS THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Failed to log activity: ' || SQLERRM
        );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get admin activity logs (paginated)
CREATE OR REPLACE FUNCTION get_admin_activity_logs(
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0,
    p_admin_username VARCHAR(50) DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    logs JSON;
    total_count INTEGER;
BEGIN
    -- Get total count
    IF p_admin_username IS NULL THEN
        SELECT COUNT(*) INTO total_count FROM admin_activity_log;
    ELSE
        SELECT COUNT(*) INTO total_count
        FROM admin_activity_log
        WHERE admin_username = p_admin_username;
    END IF;
    
    -- Get paginated results
    IF p_admin_username IS NULL THEN
        SELECT json_agg(
            json_build_object(
                'id', id,
                'admin_username', admin_username,
                'action', action,
                'description', description,
                'timestamp', timestamp,
                'created_at', created_at
            )
        ) INTO logs
        FROM admin_activity_log
        ORDER BY timestamp DESC
        LIMIT p_limit
        OFFSET p_offset;
    ELSE
        SELECT json_agg(
            json_build_object(
                'id', id,
                'admin_username', admin_username,
                'action', action,
                'description', description,
                'timestamp', timestamp,
                'created_at', created_at
            )
        ) INTO logs
        FROM admin_activity_log
        WHERE admin_username = p_admin_username
        ORDER BY timestamp DESC
        LIMIT p_limit
        OFFSET p_offset;
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'data', COALESCE(logs, '[]'::json),
        'total', total_count,
        'limit', p_limit,
        'offset', p_offset
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. ENABLE RLS
-- ============================================================================
ALTER TABLE admin_activity_log ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 5. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access admin_activity_log" ON admin_activity_log;
CREATE POLICY "Service role full access admin_activity_log"
ON admin_activity_log
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated users can read (for admin dashboard)
DROP POLICY IF EXISTS "Authenticated can read admin_activity_log" ON admin_activity_log;
CREATE POLICY "Authenticated can read admin_activity_log"
ON admin_activity_log
FOR SELECT
TO authenticated
USING (true);

-- ============================================================================
-- 6. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON admin_activity_log TO service_role;
GRANT SELECT ON admin_activity_log TO authenticated;
GRANT INSERT ON admin_activity_log TO authenticated;
GRANT USAGE ON SEQUENCE admin_activity_log_id_seq TO service_role, authenticated;
GRANT EXECUTE ON FUNCTION log_admin_activity(VARCHAR, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_admin_activity_logs(INTEGER, INTEGER, VARCHAR) TO authenticated, service_role;

-- ============================================================================
-- END OF ADMIN_ACTIVITY_LOG SCHEMA
-- ============================================================================

