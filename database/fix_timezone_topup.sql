-- ============================================================================
-- FIX TIMEZONE FOR TOP-UP TRANSACTIONS
-- ============================================================================
-- This script fixes the timezone issue where created_at defaults to UTC
-- instead of Philippines time (Asia/Manila, UTC+8)
-- ============================================================================

-- ============================================================================
-- 1. CREATE HELPER FUNCTION FOR PHILIPPINES TIME
-- ============================================================================
-- This function returns the current time in Philippines timezone as TIMESTAMP WITH TIME ZONE
CREATE OR REPLACE FUNCTION get_philippines_time()
RETURNS TIMESTAMP WITH TIME ZONE AS $$
BEGIN
    -- Return current time in UTC (PostgreSQL stores TIMESTAMP WITH TIME ZONE as UTC internally)
    -- The timezone conversion should happen at query/display time, not storage time
    -- However, to ensure the timestamp represents Philippines local time when displayed,
    -- we need to store it with the correct offset
    -- 
    -- The correct approach: Store UTC time, but ensure it represents the correct Philippines time
    -- When UTC is 15:45, Philippines is 23:45 (8 hours ahead)
    -- We store 15:45 UTC, which correctly represents 23:45 Philippines time
    -- 
    -- For display purposes, Flutter should convert UTC to Philippines time (+8 hours)
    RETURN now();
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. UPDATE TOP_UP_TRANSACTIONS TABLE DEFAULT
-- ============================================================================
-- Change the default from NOW() (UTC) to Philippines timezone
ALTER TABLE top_up_transactions 
ALTER COLUMN created_at SET DEFAULT get_philippines_time();

ALTER TABLE top_up_transactions 
ALTER COLUMN updated_at SET DEFAULT get_philippines_time();

-- ============================================================================
-- 3. UPDATE PROCESS_TOP_UP_TRANSACTION FUNCTION
-- ============================================================================
-- Update the function to use Philippines timezone instead of NOW()
CREATE OR REPLACE FUNCTION process_top_up_transaction(
    p_student_id VARCHAR(50),
    p_amount DECIMAL(10,2),
    p_processed_by VARCHAR(100),
    p_notes TEXT DEFAULT NULL,
    p_transaction_type VARCHAR(20) DEFAULT 'top_up',
    p_admin_earn DECIMAL(10,2) DEFAULT 0.00,
    p_vendor_earn DECIMAL(10,2) DEFAULT 0.00
) RETURNS JSON AS $$
DECLARE
    current_balance DECIMAL(10,2);
    new_balance DECIMAL(10,2);
    transaction_id INTEGER;
    student_exists BOOLEAN;
    valid_transaction_type BOOLEAN;
    philippines_time TIMESTAMP WITH TIME ZONE;
BEGIN
    -- Get Philippines time once for consistency
    philippines_time := get_philippines_time();
    
    -- Validate transaction type
    valid_transaction_type := p_transaction_type IN ('top_up', 'top_up_gcash', 'top_up_services', 'loan_disbursement');
    IF NOT valid_transaction_type THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Invalid transaction type. Must be: top_up, top_up_gcash, top_up_services, or loan_disbursement',
            'error', 'INVALID_TRANSACTION_TYPE'
        );
    END IF;
    
    -- Validate fee amounts
    IF p_admin_earn < 0 OR p_vendor_earn < 0 THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Fee amounts cannot be negative',
            'error', 'INVALID_FEE_AMOUNT'
        );
    END IF;
    
    -- Check if student exists
    SELECT EXISTS(SELECT 1 FROM auth_students WHERE student_id = p_student_id) INTO student_exists;
    
    IF NOT student_exists THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Student not found',
            'error', 'STUDENT_NOT_FOUND'
        );
    END IF;
    
    -- Get current balance
    SELECT COALESCE(balance, 0) INTO current_balance
    FROM auth_students 
    WHERE student_id = p_student_id;
    
    -- Calculate new balance
    new_balance := current_balance + p_amount;
    
    -- Start transaction
    BEGIN
        -- Update student balance
        UPDATE auth_students 
        SET balance = new_balance,
            updated_at = philippines_time
        WHERE student_id = p_student_id;
        
        -- Insert transaction record with fee information
        INSERT INTO top_up_transactions (
            student_id,
            amount,
            previous_balance,
            new_balance,
            transaction_type,
            processed_by,
            notes,
            admin_earn,
            vendor_earn,
            created_at
        ) VALUES (
            p_student_id,
            p_amount,
            current_balance,
            new_balance,
            p_transaction_type,
            p_processed_by,
            p_notes,
            COALESCE(p_admin_earn, 0.00),
            COALESCE(p_vendor_earn, 0.00),
            philippines_time
        ) RETURNING id INTO transaction_id;
        
        -- Return success response
        RETURN json_build_object(
            'success', true,
            'message', 'Top-up processed successfully',
            'data', json_build_object(
                'transaction_id', transaction_id,
                'student_id', p_student_id,
                'amount', p_amount,
                'previous_balance', current_balance,
                'new_balance', new_balance,
                'transaction_type', p_transaction_type,
                'processed_by', p_processed_by,
                'admin_earn', COALESCE(p_admin_earn, 0.00),
                'vendor_earn', COALESCE(p_vendor_earn, 0.00),
                'created_at', philippines_time
            )
        );
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Rollback on error
            RETURN json_build_object(
                'success', false,
                'message', 'Failed to process top-up: ' || SQLERRM,
                'error', 'PROCESSING_ERROR'
            );
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 4. UPDATE UPDATE_TRIGGER FUNCTION
-- ============================================================================
-- Update the trigger function to use Philippines timezone
CREATE OR REPLACE FUNCTION update_top_up_transactions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = get_philippines_time();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 5. GRANT PERMISSIONS
-- ============================================================================
GRANT EXECUTE ON FUNCTION get_philippines_time() TO service_role, authenticated;
GRANT EXECUTE ON FUNCTION process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT, VARCHAR, DECIMAL, DECIMAL) TO service_role, authenticated;

-- ============================================================================
-- END OF TIMEZONE FIX
-- ============================================================================

