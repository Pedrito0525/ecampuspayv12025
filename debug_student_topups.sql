-- Debug function to help troubleshoot top-up transaction queries
-- This function will help identify why student top-ups are not showing

CREATE OR REPLACE FUNCTION debug_student_topups(p_student_id VARCHAR(50))
RETURNS JSON AS $$
DECLARE
    exact_matches JSON;
    similar_matches JSON;
    all_students JSON;
    table_exists BOOLEAN;
BEGIN
    -- Check if table exists
    SELECT EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'top_up_transactions'
    ) INTO table_exists;
    
    IF NOT table_exists THEN
        RETURN json_build_object(
            'error', 'top_up_transactions table does not exist',
            'student_id_searched', p_student_id
        );
    END IF;
    
    -- Get exact matches
    SELECT json_agg(
        json_build_object(
            'id', id,
            'student_id', student_id,
            'amount', amount,
            'previous_balance', previous_balance,
            'new_balance', new_balance,
            'processed_by', processed_by,
            'notes', notes,
            'created_at', created_at
        )
    ) INTO exact_matches
    FROM top_up_transactions 
    WHERE student_id = p_student_id;
    
    -- Get similar matches (case insensitive, with trimming)
    SELECT json_agg(
        json_build_object(
            'id', id,
            'student_id', student_id,
            'amount', amount,
            'created_at', created_at
        )
    ) INTO similar_matches
    FROM top_up_transactions 
    WHERE TRIM(LOWER(student_id)) = TRIM(LOWER(p_student_id))
    OR student_id LIKE '%' || p_student_id || '%'
    OR p_student_id LIKE '%' || student_id || '%';
    
    -- Get all distinct student_ids in the table
    SELECT json_agg(DISTINCT student_id) INTO all_students
    FROM top_up_transactions
    LIMIT 50;
    
    RETURN json_build_object(
        'searched_student_id', p_student_id,
        'exact_matches', COALESCE(exact_matches, '[]'::json),
        'similar_matches', COALESCE(similar_matches, '[]'::json),
        'all_student_ids_in_table', COALESCE(all_students, '[]'::json),
        'table_exists', table_exists,
        'total_records_in_table', (SELECT COUNT(*) FROM top_up_transactions)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION debug_student_topups(VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION debug_student_topups(VARCHAR) TO authenticated;
