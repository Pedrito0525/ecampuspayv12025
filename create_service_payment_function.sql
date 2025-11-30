-- Run this SQL in your Supabase SQL Editor to create the process_service_payment function

CREATE OR REPLACE FUNCTION process_service_payment(
    p_user_id INTEGER,
    p_service_account_id INTEGER,
    p_amount DECIMAL(10,2),
    p_items JSONB,
    p_student_id TEXT DEFAULT NULL,
    p_purpose TEXT DEFAULT NULL,
    p_transaction_code TEXT DEFAULT NULL
) RETURNS JSONB AS $$
DECLARE
    v_user_balance DECIMAL(10,2);
    v_service_balance DECIMAL(10,2);
    v_new_user_balance DECIMAL(10,2);
    v_new_service_balance DECIMAL(10,2);
    v_transaction_id BIGINT;
    v_main_service_id INTEGER;
    v_operational_type TEXT;
    v_result JSONB;
BEGIN
    -- Start transaction
    BEGIN
        -- Get current user balance
        SELECT balance INTO v_user_balance
        FROM auth_students
        WHERE id = p_user_id;
        
        IF v_user_balance IS NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'User not found'
            );
        END IF;
        
        -- Check if user has sufficient balance
        IF v_user_balance < p_amount THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Insufficient balance'
            );
        END IF;
        
        -- Get service account info
        SELECT balance, main_service_id, operational_type 
        INTO v_service_balance, v_main_service_id, v_operational_type
        FROM service_accounts
        WHERE id = p_service_account_id AND is_active = true;
        
        IF v_service_balance IS NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Service account not found or inactive'
            );
        END IF;
        
        -- Calculate new balances
        v_new_user_balance := v_user_balance - p_amount;
        v_new_service_balance := v_service_balance + p_amount;
        
        -- Update user balance
        UPDATE auth_students 
        SET balance = v_new_user_balance,
            updated_at = NOW()
        WHERE id = p_user_id;
        
        -- Update service account balance
        UPDATE service_accounts 
        SET balance = v_new_service_balance,
            updated_at = NOW()
        WHERE id = p_service_account_id;
        
        -- Create service transaction record
        INSERT INTO service_transactions (
            service_account_id,
            main_service_id,
            student_id,
            items,
            total_amount,
            purpose,
            transaction_code,
            metadata
        ) VALUES (
            p_service_account_id,
            CASE 
                WHEN v_operational_type = 'Sub' THEN COALESCE(v_main_service_id, p_service_account_id)
                ELSE p_service_account_id
            END,
            p_student_id,
            p_items,
            p_amount,
            p_purpose,
            p_transaction_code,
            jsonb_build_object(
                'user_id', p_user_id,
                'previous_user_balance', v_user_balance,
                'new_user_balance', v_new_user_balance,
                'previous_service_balance', v_service_balance,
                'new_service_balance', v_new_service_balance,
                'payment_method', 'RFID',
                'processed_at', NOW()
            )
        ) RETURNING id INTO v_transaction_id;
        
        -- Return success result
        v_result := jsonb_build_object(
            'success', true,
            'transaction_id', v_transaction_id,
            'user_id', p_user_id,
            'service_account_id', p_service_account_id,
            'amount', p_amount,
            'previous_user_balance', v_user_balance,
            'new_user_balance', v_new_user_balance,
            'previous_service_balance', v_service_balance,
            'new_service_balance', v_new_service_balance
        );
        
        RETURN v_result;
        
    EXCEPTION WHEN OTHERS THEN
        -- Rollback transaction on error
        RAISE;
        RETURN jsonb_build_object(
            'success', false,
            'error', SQLERRM
        );
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant permissions
GRANT EXECUTE ON FUNCTION process_service_payment(INTEGER, INTEGER, DECIMAL, JSONB, TEXT, TEXT, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION process_service_payment(INTEGER, INTEGER, DECIMAL, JSONB, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION process_service_payment(INTEGER, INTEGER, DECIMAL, JSONB, TEXT, TEXT, TEXT) TO anon;
