-- Fix the get_available_loan_plans function to resolve GROUP BY error
-- Run this to update the function

CREATE OR REPLACE FUNCTION get_available_loan_plans(p_student_id VARCHAR(50))
RETURNS JSON AS $$
DECLARE
    total_topup DECIMAL(10,2);
    plans JSON;
BEGIN
    -- Get student's total top-up amount
    SELECT COALESCE(SUM(amount), 0) INTO total_topup
    FROM top_up_transactions 
    WHERE student_id = p_student_id;
    
    -- Get loan plans that student is eligible for using a subquery to avoid GROUP BY issues
    WITH loan_plans_with_eligibility AS (
        SELECT 
            lp.id,
            lp.name,
            lp.amount,
            lp.term_days,
            lp.interest_rate,
            lp.penalty_rate,
            lp.min_topup,
            (lp.amount + (lp.amount * lp.interest_rate / 100)) as total_repayable,
            (total_topup >= lp.min_topup) as is_eligible
        FROM loan_plans lp
        WHERE lp.status = 'active'
        ORDER BY lp.amount ASC
    )
    SELECT json_agg(
        json_build_object(
            'id', id,
            'name', name,
            'amount', amount,
            'term_days', term_days,
            'interest_rate', interest_rate,
            'penalty_rate', penalty_rate,
            'min_topup', min_topup,
            'total_repayable', total_repayable,
            'is_eligible', is_eligible
        )
    ) INTO plans
    FROM loan_plans_with_eligibility;
    
    RETURN json_build_object(
        'student_id', p_student_id,
        'total_topup', total_topup,
        'available_plans', COALESCE(plans, '[]'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
