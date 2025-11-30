-- =====================================================
-- Add fee columns to top_up_transactions table
-- =====================================================
-- This script adds vendor_earn and admin_earn columns
-- to track fees from top-up transactions
-- =====================================================

-- Step 1: Add vendor_earn and admin_earn columns
ALTER TABLE top_up_transactions 
ADD COLUMN IF NOT EXISTS vendor_earn DECIMAL(10,2) DEFAULT 0.00 CHECK (vendor_earn >= 0),
ADD COLUMN IF NOT EXISTS admin_earn DECIMAL(10,2) DEFAULT 0.00 CHECK (admin_earn >= 0);

-- Step 2: Update existing records to have 0.00 for fee columns (if any exist)
UPDATE top_up_transactions 
SET vendor_earn = 0.00, admin_earn = 0.00 
WHERE vendor_earn IS NULL OR admin_earn IS NULL;

-- Step 3: Drop the old function versions to avoid conflicts
DROP FUNCTION IF EXISTS process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT);
DROP FUNCTION IF EXISTS process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT, VARCHAR);

-- Step 4: Create updated function with fee parameters
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
            updated_at = NOW()
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
                'admin_earn', COALESCE(p_admin_earn, 0.00),
                'vendor_earn', COALESCE(p_vendor_earn, 0.00),
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

-- Step 5: Grant execute permissions on the updated function
GRANT EXECUTE ON FUNCTION process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT, VARCHAR, DECIMAL, DECIMAL) TO service_role;
GRANT EXECUTE ON FUNCTION process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT, VARCHAR, DECIMAL, DECIMAL) TO authenticated;

-- Step 6: Add comments to the new columns
COMMENT ON COLUMN top_up_transactions.vendor_earn IS 'Fee amount earned by vendor/service provider (if applicable)';
COMMENT ON COLUMN top_up_transactions.admin_earn IS 'Fee amount earned by admin/platform from the top-up transaction';

-- Step 7: Update the get_recent_top_up_transactions function to include fee columns
CREATE OR REPLACE FUNCTION get_recent_top_up_transactions(
    p_limit INTEGER DEFAULT 20
) RETURNS JSON AS $$
DECLARE
    transactions JSON;
BEGIN
    -- Get recent transactions with student names and fee information
    SELECT json_agg(
        json_build_object(
            'id', t.id,
            'student_id', t.student_id,
            'student_name', COALESCE(s.name, 'Unknown Student'),
            'amount', t.amount,
            'previous_balance', t.previous_balance,
            'new_balance', t.new_balance,
            'transaction_type', t.transaction_type,
            'processed_by', t.processed_by,
            'notes', t.notes,
            'admin_earn', COALESCE(t.admin_earn, 0.00),
            'vendor_earn', COALESCE(t.vendor_earn, 0.00),
            'created_at', t.created_at
        )
    ) INTO transactions
    FROM (
        SELECT *
        FROM top_up_transactions 
        ORDER BY created_at DESC
        LIMIT p_limit
    ) t
    LEFT JOIN auth_students s ON t.student_id = s.student_id;
    
    RETURN json_build_object(
        'success', true,
        'data', COALESCE(transactions, '[]'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- IMPORTANT NOTES:
-- 1. Run this script in Supabase SQL Editor
-- 2. The function now accepts optional admin_earn and vendor_earn parameters
-- 3. For manual admin top-ups, pass the calculated admin_earn fee
-- 4. For GCash/other payment methods, set fees as needed
-- =====================================================
-- END OF MIGRATION SCRIPT
-- =====================================================

