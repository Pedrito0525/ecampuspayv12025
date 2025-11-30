-- =====================================================
-- EVSU Campus Pay - Service Payment Processing Function
-- =====================================================
-- This function processes service payments atomically:
-- 1. Deducts amount from student balance
-- 2. Adds amount to service account balance
-- 3. Creates service transaction record
-- =====================================================

-- Drop existing function(s) to avoid ambiguity errors
-- This handles cases where multiple versions exist with different signatures
-- Drop all possible overloads of process_service_payment
DO $$ 
DECLARE
    r RECORD;
BEGIN
    -- Find all functions named process_service_payment and drop them
    FOR r IN 
        SELECT oid::regprocedure as func_signature
        FROM pg_proc
        WHERE proname = 'process_service_payment'
    LOOP
        EXECUTE 'DROP FUNCTION IF EXISTS ' || r.func_signature || ' CASCADE';
    END LOOP;
END $$;

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
    v_service_category TEXT;
    v_result JSONB;
    v_final_transaction_code TEXT;
    v_sequence_number INTEGER;
    v_transaction_csu_id BIGINT;
    v_effective_main_service_id INTEGER;
    v_is_campus_service BOOLEAN := false;
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
        SELECT balance, main_service_id, operational_type, service_category
        INTO v_service_balance, v_main_service_id, v_operational_type, v_service_category
        FROM service_accounts
        WHERE id = p_service_account_id AND is_active = true;
        
        IF v_service_balance IS NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Service account not found or inactive'
            );
        END IF;
        
        -- Normalize service category for Campus Service Units detection
        IF v_service_category IS NOT NULL THEN
            v_is_campus_service :=
                lower(v_service_category) LIKE 'campus service%' OR
                lower(v_service_category) = 'csu';
        END IF;

        v_effective_main_service_id :=
            COALESCE(v_main_service_id, p_service_account_id);

        -- For Campus Service Units, we'll create transaction_csu record after inserting service_transaction
        -- The transaction_code will be set to the transaction_csu.id
        -- For other services, use provided transaction code or NULL
        IF NOT v_is_campus_service THEN
            v_final_transaction_code := p_transaction_code;
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
        -- For Campus Service Units, transaction_code will be set after creating transaction_csu
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
            v_effective_main_service_id,
            p_student_id,
            p_items,
            p_amount,
            p_purpose,
            v_final_transaction_code, -- NULL for CSU (will be set from transaction_csu.id), or provided code for others
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
        
        -- For Campus Service Units (main and sub accounts), create transaction_csu record and update transaction_code
        -- Sub accounts will continue the sequence from the main account (shared sequence)
        -- Vendor/Org service categories do NOT get transaction_code
        IF v_is_campus_service AND (p_transaction_code IS NULL OR p_transaction_code = '') THEN
            -- Get next sequence number atomically
            -- The function uses main_service_id for sub accounts to continue the main account's sequence
            -- For main accounts, it uses the service_account_id itself
            v_sequence_number := get_next_csu_sequence_number(p_service_account_id);
            
            -- Insert into transaction_csu and get the generated id
            INSERT INTO transaction_csu (
                service_transactions_id,
                sequence_number
            ) VALUES (
                v_transaction_id,
                v_sequence_number
            ) RETURNING id INTO v_transaction_csu_id;
            
            -- Build formatted transaction code EVSU-OCC: <sequence_number>
            v_final_transaction_code := 'EVSU-OCC: ' ||
                LPAD(v_sequence_number::TEXT, 6, '0');

            -- Update service_transaction with formatted transaction code
            UPDATE service_transactions
            SET transaction_code = v_final_transaction_code
            WHERE id = v_transaction_id;
        END IF;
        
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

-- Comments
COMMENT ON FUNCTION process_service_payment IS 'Processes service payments atomically: deducts from student, adds to service, creates transaction record';
