-- FINAL FIX: Loan Functions to resolve GROUP BY clause error
-- This replaces the problematic get_student_loans function and adds get_active_student_loans

-- 1. Fix the get_student_loans function (removes GROUP BY issue)
CREATE OR REPLACE FUNCTION get_student_loans(p_student_id VARCHAR(50))
RETURNS JSON AS $$
DECLARE
    loans JSON;
BEGIN
    WITH student_loans AS (
        SELECT 
            al.id,
            al.loan_plan_id,
            al.loan_amount,
            al.interest_amount,
            al.penalty_amount,
            al.total_amount,
            al.term_days,
            al.due_date,
            al.status,
            al.created_at,
            al.paid_at,
            lp.name as loan_plan_name,
            CASE 
                WHEN al.status = 'paid' THEN 0
                WHEN al.due_date < NOW() THEN EXTRACT(DAY FROM NOW() - al.due_date)::INTEGER
                ELSE EXTRACT(DAY FROM al.due_date - NOW())::INTEGER
            END as days_left
        FROM active_loans al
        JOIN loan_plans lp ON al.loan_plan_id = lp.id
        WHERE al.student_id = p_student_id
        ORDER BY al.created_at DESC
    )
    SELECT json_agg(
        json_build_object(
            'id', id,
            'loan_plan_name', loan_plan_name,
            'loan_amount', loan_amount,
            'interest_amount', interest_amount,
            'penalty_amount', penalty_amount,
            'total_amount', total_amount,
            'term_days', term_days,
            'due_date', due_date,
            'status', status,
            'created_at', created_at,
            'paid_at', paid_at,
            'days_left', days_left
        )
    ) INTO loans
    FROM student_loans;
    
    RETURN json_build_object(
        'student_id', p_student_id,
        'loans', COALESCE(loans, '[]'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Add get_active_student_loans function (for active loans only)
CREATE OR REPLACE FUNCTION get_active_student_loans(p_student_id VARCHAR(50))
RETURNS JSON AS $$
DECLARE
    loans JSON;
BEGIN
    SELECT json_agg(
        json_build_object(
            'id', al.id,
            'loan_plan_name', lp.name,
            'loan_amount', al.loan_amount,
            'interest_amount', al.interest_amount,
            'penalty_amount', al.penalty_amount,
            'total_amount', al.total_amount,
            'term_days', al.term_days,
            'due_date', al.due_date,
            'status', al.status,
            'created_at', al.created_at,
            'paid_at', al.paid_at,
            'days_left', CASE 
                WHEN al.due_date < NOW() THEN EXTRACT(DAY FROM NOW() - al.due_date)::INTEGER
                ELSE EXTRACT(DAY FROM al.due_date - NOW())::INTEGER
            END
        )
    ) INTO loans
    FROM active_loans al
    JOIN loan_plans lp ON al.loan_plan_id = lp.id
    WHERE al.student_id = p_student_id 
    AND al.status IN ('active', 'overdue')
    ORDER BY al.created_at DESC;
    
    RETURN json_build_object(
        'student_id', p_student_id,
        'active_loans', COALESCE(loans, '[]'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Add partial payment function
CREATE OR REPLACE FUNCTION make_partial_loan_payment(
    p_loan_id INTEGER,
    p_student_id VARCHAR(50),
    p_payment_amount DECIMAL(10,2)
)
RETURNS JSON AS $$
DECLARE
    loan_record RECORD;
    current_balance DECIMAL(10,2);
    new_remaining_balance DECIMAL(10,2);
BEGIN
    IF p_payment_amount <= 0 THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Invalid amount',
            'message', 'Payment amount must be greater than 0'
        );
    END IF;
    
    SELECT * INTO loan_record
    FROM active_loans 
    WHERE id = p_loan_id AND student_id = p_student_id AND status = 'active';
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Loan not found',
            'message', 'Loan not found or already paid'
        );
    END IF;
    
    IF p_payment_amount > loan_record.total_amount THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Amount too high',
            'message', 'Payment amount cannot exceed total loan amount of ₱' || loan_record.total_amount
        );
    END IF;
    
    SELECT balance INTO current_balance
    FROM auth_students 
    WHERE student_id = p_student_id;
    
    IF current_balance < p_payment_amount THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'message', 'You need ₱' || p_payment_amount || ' to make this payment'
        );
    END IF;
    
    new_remaining_balance := loan_record.total_amount - p_payment_amount;
    
    UPDATE auth_students 
    SET balance = balance - p_payment_amount,
        updated_at = NOW()
    WHERE student_id = p_student_id;
    
    UPDATE active_loans 
    SET total_amount = new_remaining_balance,
        updated_at = NOW(),
        status = CASE 
            WHEN new_remaining_balance <= 0 THEN 'paid'
            ELSE 'active'
        END,
        paid_at = CASE 
            WHEN new_remaining_balance <= 0 THEN NOW()
            ELSE paid_at
        END
    WHERE id = p_loan_id;
    
    INSERT INTO loan_payments (
        loan_id, student_id, payment_amount, payment_type, remaining_balance
    ) VALUES (
        p_loan_id, p_student_id, p_payment_amount, 
        CASE WHEN new_remaining_balance <= 0 THEN 'full' ELSE 'partial' END,
        GREATEST(new_remaining_balance, 0)
    );
    
    RETURN json_build_object(
        'success', true,
        'message', CASE 
            WHEN new_remaining_balance <= 0 THEN 'Loan paid in full successfully!'
            ELSE 'Partial payment of ₱' || p_payment_amount || ' processed successfully'
        END,
        'loan_id', p_loan_id,
        'payment_amount', p_payment_amount,
        'remaining_balance', GREATEST(new_remaining_balance, 0),
        'is_fully_paid', new_remaining_balance <= 0
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_student_loans(VARCHAR) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_active_student_loans(VARCHAR) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION make_partial_loan_payment(INTEGER, VARCHAR, DECIMAL) TO authenticated, service_role;
