-- Update loan eligibility functions to only count top_up and top_up_gcash transactions
-- This ensures loan eligibility is based only on actual top-up transactions, not loan disbursements

-- 1. Update check_loan_eligibility function
CREATE OR REPLACE FUNCTION check_loan_eligibility(p_student_id VARCHAR(50))
RETURNS JSON AS $$
DECLARE
    total_topup DECIMAL(10,2);
    active_loan_count INTEGER;
    result JSON;
BEGIN
    -- Get total top-up amount for student (only top_up and top_up_gcash)
    SELECT COALESCE(SUM(amount), 0) INTO total_topup
    FROM top_up_transactions 
    WHERE student_id = p_student_id
    AND transaction_type IN ('top_up', 'top_up_gcash');
    
    -- Check if student has any active unpaid loans
    SELECT COUNT(*) INTO active_loan_count
    FROM active_loans 
    WHERE student_id = p_student_id 
    AND status = 'active';
    
    -- Build result
    result := json_build_object(
        'student_id', p_student_id,
        'total_topup', total_topup,
        'has_active_loan', active_loan_count > 0,
        'active_loan_count', active_loan_count,
        'is_eligible', active_loan_count = 0
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Update get_available_loan_plans function
CREATE OR REPLACE FUNCTION get_available_loan_plans(p_student_id VARCHAR(50))
RETURNS JSON AS $$
DECLARE
    total_topup DECIMAL(10,2);
    plans JSON;
BEGIN
    -- Get student's total top-up amount (only top_up and top_up_gcash)
    SELECT COALESCE(SUM(amount), 0) INTO total_topup
    FROM top_up_transactions 
    WHERE student_id = p_student_id
    AND transaction_type IN ('top_up', 'top_up_gcash');
    
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

-- 3. Update apply_for_loan function
CREATE OR REPLACE FUNCTION apply_for_loan(
    p_student_id VARCHAR(50),
    p_loan_plan_id INTEGER
)
RETURNS JSON AS $$
DECLARE
    plan_record RECORD;
    total_topup DECIMAL(10,2);
    active_loan_count INTEGER;
    new_loan_id INTEGER;
    due_date TIMESTAMP WITH TIME ZONE;
    interest_amount DECIMAL(10,2);
    total_amount DECIMAL(10,2);
    result JSON;
BEGIN
    -- Check if student exists
    IF NOT EXISTS (SELECT 1 FROM auth_students WHERE student_id = p_student_id) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Student not found',
            'message', 'Student ID does not exist'
        );
    END IF;
    
    -- Get loan plan details
    SELECT * INTO plan_record
    FROM loan_plans 
    WHERE id = p_loan_plan_id AND status = 'active';
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Loan plan not found',
            'message', 'Selected loan plan is not available'
        );
    END IF;
    
    -- Check eligibility (only top_up and top_up_gcash)
    SELECT COALESCE(SUM(amount), 0) INTO total_topup
    FROM top_up_transactions 
    WHERE student_id = p_student_id
    AND transaction_type IN ('top_up', 'top_up_gcash');
    
    IF total_topup < plan_record.min_topup THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Insufficient top-up',
            'message', 'You need at least ₱' || plan_record.min_topup || ' in total top-ups to apply for this loan'
        );
    END IF;
    
    -- Check if student has active loans
    SELECT COUNT(*) INTO active_loan_count
    FROM active_loans 
    WHERE student_id = p_student_id AND status = 'active';
    
    IF active_loan_count > 0 THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Active loan exists',
            'message', 'You already have an active loan. Please pay it off first.'
        );
    END IF;
    
    -- Calculate loan details
    interest_amount := plan_record.amount * plan_record.interest_rate / 100;
    total_amount := plan_record.amount + interest_amount;
    due_date := NOW() + (plan_record.term_days || ' days')::INTERVAL;
    
    -- Create the loan
    INSERT INTO active_loans (
        student_id, loan_plan_id, loan_amount, interest_amount, 
        penalty_amount, total_amount, term_days, due_date, status
    ) VALUES (
        p_student_id, p_loan_plan_id, plan_record.amount, interest_amount,
        0, total_amount, plan_record.term_days, due_date, 'active'
    ) RETURNING id INTO new_loan_id;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Loan applied successfully',
        'loan_id', new_loan_id,
        'loan_amount', plan_record.amount,
        'total_amount', total_amount,
        'due_date', due_date
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

