-- Function to handle partial loan payments
-- This function allows students to make partial payments on their loans

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
    result JSON;
BEGIN
    -- Validate payment amount
    IF p_payment_amount <= 0 THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Invalid amount',
            'message', 'Payment amount must be greater than 0'
        );
    END IF;
    
    -- Get loan details
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
    
    -- Check if payment amount exceeds total amount
    IF p_payment_amount > loan_record.total_amount THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Amount too high',
            'message', 'Payment amount cannot exceed total loan amount of ₱' || loan_record.total_amount
        );
    END IF;
    
    -- Check if student has sufficient balance
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
    
    -- Calculate new remaining balance
    new_remaining_balance := loan_record.total_amount - p_payment_amount;
    
    -- Deduct payment amount from student balance
    UPDATE auth_students 
    SET balance = balance - p_payment_amount,
        updated_at = NOW()
    WHERE student_id = p_student_id;
    
    -- Update loan details
    UPDATE active_loans 
    SET total_amount = new_remaining_balance,
        updated_at = NOW(),
        -- If fully paid, mark as paid
        status = CASE 
            WHEN new_remaining_balance <= 0 THEN 'paid'
            ELSE 'active'
        END,
        paid_at = CASE 
            WHEN new_remaining_balance <= 0 THEN NOW()
            ELSE paid_at
        END
    WHERE id = p_loan_id;
    
    -- Record payment
    INSERT INTO loan_payments (
        loan_id, student_id, payment_amount, payment_type, remaining_balance
    ) VALUES (
        p_loan_id, p_student_id, p_payment_amount, 
        CASE WHEN new_remaining_balance <= 0 THEN 'full' ELSE 'partial' END,
        GREATEST(new_remaining_balance, 0)
    );
    
    -- Return success response
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
GRANT EXECUTE ON FUNCTION make_partial_loan_payment(INTEGER, VARCHAR, DECIMAL) TO authenticated, service_role;

-- Add comment
COMMENT ON FUNCTION make_partial_loan_payment(INTEGER, VARCHAR, DECIMAL) IS 'Handles partial loan payments and updates loan balance accordingly';
