-- Dashboard Statistics Functions for eCampusPay Admin

-- Function to get today's transaction total
CREATE OR REPLACE FUNCTION get_today_transaction_total()
RETURNS JSON AS $$
DECLARE
    today_total NUMERIC;
BEGIN
    -- Get total amount from top_up_transactions for today
    SELECT COALESCE(SUM(amount), 0) INTO today_total
    FROM top_up_transactions 
    WHERE DATE(created_at) = CURRENT_DATE;
    
    RETURN json_build_object(
        'success', true,
        'total', today_total
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get count of active users today
CREATE OR REPLACE FUNCTION get_active_users_today()
RETURNS JSON AS $$
DECLARE
    active_count INTEGER;
BEGIN
    -- Count users who have logged in today (this is a simplified version)
    -- In a real implementation, you might track login sessions
    SELECT COUNT(*) INTO active_count
    FROM auth_students 
    WHERE is_active = true
    AND DATE(updated_at) = CURRENT_DATE;
    
    RETURN json_build_object(
        'success', true,
        'count', active_count
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get dashboard statistics (combined)
CREATE OR REPLACE FUNCTION get_dashboard_stats()
RETURNS JSON AS $$
DECLARE
    total_users INTEGER;
    active_users_today INTEGER;
    today_transactions NUMERIC;
    total_services INTEGER;
    recent_transactions JSON;
BEGIN
    -- Get total users
    SELECT COUNT(*) INTO total_users
    FROM auth_students 
    WHERE is_active = true;
    
    -- Get active users today
    SELECT COUNT(*) INTO active_users_today
    FROM auth_students 
    WHERE is_active = true
    AND DATE(updated_at) = CURRENT_DATE;
    
    -- Get today's transaction total
    SELECT COALESCE(SUM(amount), 0) INTO today_transactions
    FROM top_up_transactions 
    WHERE DATE(created_at) = CURRENT_DATE;
    
    -- Get total service accounts
    SELECT COUNT(*) INTO total_services
    FROM service_accounts;
    
    -- Get recent transactions
    SELECT json_agg(
        json_build_object(
            'id', t.id,
            'student_id', t.student_id,
            'amount', t.amount,
            'transaction_type', t.transaction_type,
            'created_at', t.created_at
        )
    ) INTO recent_transactions
    FROM (
        SELECT *
        FROM top_up_transactions 
        ORDER BY created_at DESC
        LIMIT 5
    ) t;
    
    RETURN json_build_object(
        'success', true,
        'data', json_build_object(
            'total_users', total_users,
            'active_users_today', active_users_today,
            'today_transactions', today_transactions,
            'total_services', total_services,
            'recent_transactions', COALESCE(recent_transactions, '[]'::json)
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION get_today_transaction_total() TO authenticated;
GRANT EXECUTE ON FUNCTION get_active_users_today() TO authenticated;
GRANT EXECUTE ON FUNCTION get_dashboard_stats() TO authenticated;

-- Grant execute permissions to service_role (for admin operations)
GRANT EXECUTE ON FUNCTION get_today_transaction_total() TO service_role;
GRANT EXECUTE ON FUNCTION get_active_users_today() TO service_role;
GRANT EXECUTE ON FUNCTION get_dashboard_stats() TO service_role;
