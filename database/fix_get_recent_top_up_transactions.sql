-- ============================================================================
-- QUICK FIX: Update get_recent_top_up_transactions function
-- ============================================================================
-- This fixes the SQL error: column "t.created_at" must appear in the GROUP BY clause
-- The issue was using ORDER BY with json_agg aggregate function
-- ============================================================================

CREATE OR REPLACE FUNCTION get_recent_top_up_transactions(
    p_limit INTEGER DEFAULT 20
) RETURNS JSON AS $$
DECLARE
    transactions JSON;
BEGIN
    -- Get recent transactions with student names
    -- Use subquery to order first, then aggregate to avoid GROUP BY issues
    SELECT json_agg(
        json_build_object(
            'id', t.id,
            'student_id', t.student_id,
            'student_name', COALESCE(s.name, 'Unknown Student'),
            'amount', t.amount,
            'previous_balance', t.previous_balance,
            'new_balance', t.new_balance,
            'transaction_type', t.transaction_type,
            'processed_by', t.processed_by,
            'notes', t.notes,
            'admin_earn', COALESCE(t.admin_earn, 0.00),
            'vendor_earn', COALESCE(t.vendor_earn, 0.00),
            'created_at', t.created_at
        )
    ) INTO transactions
    FROM (
        SELECT *
        FROM top_up_transactions
        ORDER BY created_at DESC
        LIMIT p_limit
    ) t
    LEFT JOIN auth_students s ON t.student_id = s.student_id;
    
    RETURN json_build_object(
        'success', true,
        'data', COALESCE(transactions, '[]'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_recent_top_up_transactions(INTEGER) TO service_role, authenticated;

