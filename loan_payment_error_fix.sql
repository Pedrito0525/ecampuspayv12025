-- MINIMAL FIX: Address the service_transactions error in loan payments
-- This ensures loan payments work without triggering transaction history errors

-- 1. Fix pay_off_loan function (simplified version)
CREATE OR REPLACE FUNCTION pay_off_loan(
    p_loan_id INTEGER,
    p_student_id VARCHAR(50)
)
RETURNS JSON AS $$
DECLARE
    loan_record RECORD;
    current_balance DECIMAL(10,2);
    remaining_balance DECIMAL(10,2);
BEGIN
    -- Get loan details
    SELECT * INTO loan_record
    FROM active_loans 
    WHERE id = p_loan_id AND student_id = p_student_id AND status IN ('active', 'overdue');
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Loan not found',
            'message', 'Loan not found or already paid'
        );
    END IF;
    
    -- Use current total_amount as remaining balance
    remaining_balance := loan_record.total_amount;
    
    -- Check if student has sufficient balance
    SELECT balance INTO current_balance
    FROM auth_students 
    WHERE student_id = p_student_id;
    
    IF current_balance < remaining_balance THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'message', 'You need ₱' || remaining_balance || ' to pay off this loan'
        );
    END IF;
    
    -- Deduct remaining balance from student balance
    UPDATE auth_students 
    SET balance = balance - remaining_balance,
        updated_at = NOW()
    WHERE student_id = p_student_id;
    
    -- Mark loan as paid
    UPDATE active_loans 
    SET status = 'paid',
        paid_at = NOW(),
        updated_at = NOW()
    WHERE id = p_loan_id;
    
    -- Record final payment
    INSERT INTO loan_payments (
        loan_id, student_id, payment_amount, payment_type, remaining_balance
    ) VALUES (
        p_loan_id, p_student_id, remaining_balance, 'full', 0
    );
    
    RETURN json_build_object(
        'success', true,
        'message', 'Loan paid successfully',
        'loan_id', p_loan_id,
        'amount_paid', remaining_balance
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION pay_off_loan(INTEGER, VARCHAR) TO authenticated, service_role;
