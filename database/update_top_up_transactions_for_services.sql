-- =====================================================
-- Update top_up_transactions table to support top_up_services
-- =====================================================
-- This script updates the transaction_type constraint to allow
-- 'top_up', 'top_up_gcash', and 'top_up_services'
-- =====================================================

-- Step 1: Drop the existing CHECK constraint
ALTER TABLE top_up_transactions 
DROP CONSTRAINT IF EXISTS top_up_transactions_transaction_type_check;

-- Step 2: Add new CHECK constraint that allows multiple transaction types
ALTER TABLE top_up_transactions
ADD CONSTRAINT top_up_transactions_transaction_type_check 
CHECK (transaction_type IN ('top_up', 'top_up_gcash', 'top_up_services'));

-- Step 3: Drop all existing versions of the function to avoid overloading conflicts
-- Drop the old 4-parameter version
DROP FUNCTION IF EXISTS process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT);
-- Drop the new 5-parameter version if it exists
DROP FUNCTION IF EXISTS process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT, VARCHAR);

-- Step 4: Create the new RPC function with transaction_type as optional parameter
-- If transaction_type is not provided, default to 'top_up' for backward compatibility
CREATE OR REPLACE FUNCTION process_top_up_transaction(
    p_student_id VARCHAR(50),
    p_amount DECIMAL(10,2),
    p_processed_by VARCHAR(100),
    p_notes TEXT DEFAULT NULL,
    p_transaction_type VARCHAR(20) DEFAULT 'top_up'
) RETURNS JSON AS $$
DECLARE
    current_balance DECIMAL(10,2);
    new_balance DECIMAL(10,2);
    transaction_id INTEGER;
    student_exists BOOLEAN;
    valid_transaction_type BOOLEAN;
BEGIN
    -- Validate transaction type
    valid_transaction_type := p_transaction_type IN ('top_up', 'top_up_gcash', 'top_up_services');
    IF NOT valid_transaction_type THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Invalid transaction type. Must be: top_up, top_up_gcash, or top_up_services',
            'error', 'INVALID_TRANSACTION_TYPE'
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
            updated_at = NOW()
        WHERE student_id = p_student_id;
        
        -- Insert transaction record
        INSERT INTO top_up_transactions (
            student_id,
            amount,
            previous_balance,
            new_balance,
            transaction_type,
            processed_by,
            notes,
            created_at
        ) VALUES (
            p_student_id,
            p_amount,
            current_balance,
            new_balance,
            p_transaction_type,
            p_processed_by,
            p_notes,
            NOW()
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
                'created_at', NOW()
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

-- Step 6: Update the comment to reflect the new transaction types
COMMENT ON COLUMN top_up_transactions.transaction_type IS 'Type of transaction: top_up (admin), top_up_gcash (GCash payment), or top_up_services (service account)';

-- Step 7: Grant execute permissions on the updated function
GRANT EXECUTE ON FUNCTION process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT, VARCHAR) TO service_role;
GRANT EXECUTE ON FUNCTION process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT, VARCHAR) TO authenticated;

-- =====================================================
-- IMPORTANT NOTES:
-- 1. After running this script, you may need to restart your Supabase connection
--    or wait a few seconds for the function cache to clear
-- 2. The function now accepts an optional 5th parameter (p_transaction_type)
--    If not provided, it defaults to 'top_up' for backward compatibility
-- 3. Valid transaction types: 'top_up', 'top_up_gcash', 'top_up_services'
-- =====================================================
-- END OF UPDATE SCRIPT
-- =====================================================

