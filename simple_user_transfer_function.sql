-- Simple User Transfer Function for EVSU Campus Pay
-- This is a simplified version that should work with most Supabase setups

-- First, create the user_transfers table if it doesn't exist
CREATE TABLE IF NOT EXISTS user_transfers (
    id SERIAL PRIMARY KEY,
    sender_student_id VARCHAR(50) NOT NULL,
    recipient_student_id VARCHAR(50) NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    sender_previous_balance DECIMAL(10,2) NOT NULL,
    sender_new_balance DECIMAL(10,2) NOT NULL,
    recipient_previous_balance DECIMAL(10,2) NOT NULL,
    recipient_new_balance DECIMAL(10,2) NOT NULL,
    transaction_type VARCHAR(20) NOT NULL DEFAULT 'transfer',
    status VARCHAR(20) NOT NULL DEFAULT 'completed',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create the transfer function
CREATE OR REPLACE FUNCTION process_user_transfer(
    p_sender_student_id VARCHAR(50),
    p_recipient_student_id VARCHAR(50),
    p_amount DECIMAL(10,2)
) RETURNS JSONB AS $$
DECLARE
    v_sender_balance DECIMAL(10,2);
    v_recipient_balance DECIMAL(10,2);
    v_new_sender_balance DECIMAL(10,2);
    v_new_recipient_balance DECIMAL(10,2);
    v_transfer_id BIGINT;
BEGIN
    -- Validate inputs
    IF p_sender_student_id IS NULL OR p_recipient_student_id IS NULL OR p_amount IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid parameters');
    END IF;

    IF p_sender_student_id = p_recipient_student_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot transfer to yourself');
    END IF;

    IF p_amount <= 0 THEN
        RETURN jsonb_build_object('success', false, 'error', 'Amount must be greater than 0');
    END IF;

    -- Get current balances
    SELECT balance INTO v_sender_balance
    FROM auth_students
    WHERE student_id = p_sender_student_id AND is_active = true;
    
    IF v_sender_balance IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Sender not found');
    END IF;

    SELECT balance INTO v_recipient_balance
    FROM auth_students
    WHERE student_id = p_recipient_student_id AND is_active = true;
    
    IF v_recipient_balance IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Recipient not found');
    END IF;

    -- Check sufficient balance
    IF v_sender_balance < p_amount THEN
        RETURN jsonb_build_object('success', false, 'error', 'Insufficient balance');
    END IF;

    -- Calculate new balances
    v_new_sender_balance := v_sender_balance - p_amount;
    v_new_recipient_balance := v_recipient_balance + p_amount;

    -- Update balances
    UPDATE auth_students 
    SET balance = v_new_sender_balance, updated_at = NOW()
    WHERE student_id = p_sender_student_id;

    UPDATE auth_students 
    SET balance = v_new_recipient_balance, updated_at = NOW()
    WHERE student_id = p_recipient_student_id;

    -- Record the transfer
    INSERT INTO user_transfers (
        sender_student_id, recipient_student_id, amount,
        sender_previous_balance, sender_new_balance,
        recipient_previous_balance, recipient_new_balance,
        transaction_type, status, notes
    ) VALUES (
        p_sender_student_id, p_recipient_student_id, p_amount,
        v_sender_balance, v_new_sender_balance,
        v_recipient_balance, v_new_recipient_balance,
        'transfer', 'completed', 'User transfer'
    ) RETURNING id INTO v_transfer_id;

    -- Return success
    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'message', 'Transfer completed successfully'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', 'Transfer failed: ' || SQLERRM);
END;
$$ LANGUAGE plpgsql;

-- Grant necessary permissions (adjust as needed for your setup)
-- GRANT EXECUTE ON FUNCTION process_user_transfer TO authenticated;
-- GRANT INSERT, SELECT, UPDATE ON user_transfers TO authenticated;
-- GRANT SELECT, UPDATE ON auth_students TO authenticated;

