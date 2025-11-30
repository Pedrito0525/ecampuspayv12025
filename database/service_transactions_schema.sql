-- ============================================================================
-- SERVICE_TRANSACTIONS TABLE SCHEMA
-- ============================================================================
-- This file creates the service_transactions table for recording service sales
-- ============================================================================

-- ============================================================================
-- 1. CREATE SERVICE_TRANSACTIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS service_transactions (
    id BIGSERIAL PRIMARY KEY,
    service_account_id BIGINT NOT NULL REFERENCES service_accounts(id) ON DELETE RESTRICT,
    main_service_id BIGINT REFERENCES service_accounts(id) ON DELETE SET NULL,
    student_id VARCHAR(50) REFERENCES auth_students(student_id),
    items JSONB NOT NULL,
    total_amount DECIMAL(14,2) NOT NULL CHECK (total_amount >= 0),
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_service_transactions_service_account_id ON service_transactions(service_account_id);
CREATE INDEX IF NOT EXISTS idx_service_transactions_main_service_id ON service_transactions(main_service_id);
CREATE INDEX IF NOT EXISTS idx_service_transactions_student_id ON service_transactions(student_id) WHERE student_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_service_transactions_created_at ON service_transactions(created_at DESC);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to get service transactions (paginated)
CREATE OR REPLACE FUNCTION get_service_transactions(
    p_service_account_id BIGINT DEFAULT NULL,
    p_student_id VARCHAR(50) DEFAULT NULL,
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS JSON AS $$
DECLARE
    transactions JSON;
    total_count INTEGER;
BEGIN
    -- Build dynamic query based on filters
    IF p_service_account_id IS NOT NULL AND p_student_id IS NOT NULL THEN
        SELECT COUNT(*) INTO total_count
        FROM service_transactions
        WHERE service_account_id = p_service_account_id AND student_id = p_student_id;
        
        SELECT json_agg(
            json_build_object(
                'id', id,
                'service_account_id', service_account_id,
                'main_service_id', main_service_id,
                'student_id', student_id,
                'items', items,
                'total_amount', total_amount,
                'metadata', metadata,
                'created_at', created_at
            )
        ) INTO transactions
        FROM service_transactions
        WHERE service_account_id = p_service_account_id AND student_id = p_student_id
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset;
    ELSIF p_service_account_id IS NOT NULL THEN
        SELECT COUNT(*) INTO total_count
        FROM service_transactions
        WHERE service_account_id = p_service_account_id;
        
        SELECT json_agg(
            json_build_object(
                'id', id,
                'service_account_id', service_account_id,
                'main_service_id', main_service_id,
                'student_id', student_id,
                'items', items,
                'total_amount', total_amount,
                'metadata', metadata,
                'created_at', created_at
            )
        ) INTO transactions
        FROM service_transactions
        WHERE service_account_id = p_service_account_id
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset;
    ELSIF p_student_id IS NOT NULL THEN
        SELECT COUNT(*) INTO total_count
        FROM service_transactions
        WHERE student_id = p_student_id;
        
        SELECT json_agg(
            json_build_object(
                'id', id,
                'service_account_id', service_account_id,
                'main_service_id', main_service_id,
                'student_id', student_id,
                'items', items,
                'total_amount', total_amount,
                'metadata', metadata,
                'created_at', created_at
            )
        ) INTO transactions
        FROM service_transactions
        WHERE student_id = p_student_id
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset;
    ELSE
        SELECT COUNT(*) INTO total_count FROM service_transactions;
        
        SELECT json_agg(
            json_build_object(
                'id', id,
                'service_account_id', service_account_id,
                'main_service_id', main_service_id,
                'student_id', student_id,
                'items', items,
                'total_amount', total_amount,
                'metadata', metadata,
                'created_at', created_at
            )
        ) INTO transactions
        FROM service_transactions
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset;
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'data', COALESCE(transactions, '[]'::json),
        'total', total_count,
        'limit', p_limit,
        'offset', p_offset
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. ENABLE RLS
-- ============================================================================
ALTER TABLE service_transactions ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 5. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access service_transactions" ON service_transactions;
CREATE POLICY "Service role full access service_transactions"
ON service_transactions
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated users can insert transactions
DROP POLICY IF EXISTS "Authenticated can insert service_transactions" ON service_transactions;
CREATE POLICY "Authenticated can insert service_transactions"
ON service_transactions
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Authenticated users can read transactions
DROP POLICY IF EXISTS "Authenticated can read service_transactions" ON service_transactions;
CREATE POLICY "Authenticated can read service_transactions"
ON service_transactions
FOR SELECT
TO authenticated
USING (true);

-- ============================================================================
-- 6. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON service_transactions TO service_role;
GRANT SELECT, INSERT ON service_transactions TO authenticated;
GRANT USAGE ON SEQUENCE service_transactions_id_seq TO service_role, authenticated;
GRANT EXECUTE ON FUNCTION get_service_transactions(BIGINT, VARCHAR, INTEGER, INTEGER) TO authenticated, service_role;

-- ============================================================================
-- END OF SERVICE_TRANSACTIONS SCHEMA
-- ============================================================================

