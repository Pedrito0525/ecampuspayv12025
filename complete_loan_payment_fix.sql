-- COMPLETE FIX: Loan Payment System
-- This fixes all loan payment issues including partial payments and remaining balance handling

-- 1. Fix pay_off_loan function to handle remaining balance properly
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
    
    -- Calculate remaining balance (current total_amount after any partial payments)
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

-- 2. Fix make_partial_loan_payment function
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
    WHERE id = p_loan_id AND student_id = p_student_id AND status IN ('active', 'overdue');
    
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
    
    -- Deduct payment amount from student balance
    UPDATE auth_students 
    SET balance = balance - p_payment_amount,
        updated_at = NOW()
    WHERE student_id = p_student_id;
    
    -- Update loan details
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
    
    -- Record payment
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

-- 3. Add a function to get current loan balance (for UI display)
CREATE OR REPLACE FUNCTION get_loan_remaining_balance(
    p_loan_id INTEGER,
    p_student_id VARCHAR(50)
)
RETURNS JSON AS $$
DECLARE
    loan_record RECORD;
    remaining_balance DECIMAL(10,2);
BEGIN
    SELECT * INTO loan_record
    FROM active_loans 
    WHERE id = p_loan_id AND student_id = p_student_id AND status IN ('active', 'overdue');
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Loan not found',
            'message', 'Loan not found'
        );
    END IF;
    
    remaining_balance := loan_record.total_amount;
    
    RETURN json_build_object(
        'success', true,
        'loan_id', p_loan_id,
        'remaining_balance', remaining_balance,
        'loan_amount', loan_record.loan_amount,
        'interest_amount', loan_record.interest_amount,
        'status', loan_record.status
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION pay_off_loan(INTEGER, VARCHAR) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION make_partial_loan_payment(INTEGER, VARCHAR, DECIMAL) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_loan_remaining_balance(INTEGER, VARCHAR) TO authenticated, service_role;

-- Add comments
COMMENT ON FUNCTION pay_off_loan(INTEGER, VARCHAR) IS 'Pays off the remaining balance of a loan, handling partial payments correctly';
COMMENT ON FUNCTION make_partial_loan_payment(INTEGER, VARCHAR, DECIMAL) IS 'Handles partial loan payments and updates loan balance accordingly';
COMMENT ON FUNCTION get_loan_remaining_balance(INTEGER, VARCHAR) IS 'Gets the current remaining balance for a loan';
