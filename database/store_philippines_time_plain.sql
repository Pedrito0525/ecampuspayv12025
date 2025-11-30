-- ============================================================================
-- STORE PHILIPPINES TIME AS PLAIN TIMESTAMP (NO TIMEZONE)
-- ============================================================================
-- This script changes the approach to store timestamps as plain TIMESTAMP
-- (without timezone) in Philippines local time exactly as they are.
-- No UTC conversion, no timezone math - just store PH time directly.
-- ============================================================================

-- ============================================================================
-- 1. CREATE FUNCTION THAT RETURNS PHILIPPINES TIME AS PLAIN TIMESTAMP
-- ============================================================================
-- This function returns the current Philippines time as TIMESTAMP WITHOUT TIME ZONE
-- It converts server time to Asia/Manila timezone and returns it as plain timestamp
CREATE OR REPLACE FUNCTION get_philippines_time_plain()
RETURNS TIMESTAMP WITHOUT TIME ZONE AS $$
BEGIN
    -- Convert current UTC time to Philippines (Asia/Manila) timezone
    -- and return as plain timestamp (no timezone info)
    -- This ensures the timestamp stored is exactly the PH local time
    -- 
    -- Explanation:
    -- now() returns TIMESTAMP WITH TIME ZONE in UTC (e.g., 2025-11-23 06:45:00+00)
    -- AT TIME ZONE 'Asia/Manila' converts UTC to Manila local time (e.g., 2025-11-23 14:45:00)
    -- This returns TIMESTAMP WITHOUT TIME ZONE which is exactly what we want
    RETURN (now() AT TIME ZONE 'Asia/Manila')::TIMESTAMP WITHOUT TIME ZONE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 2. DROP VIEWS THAT DEPEND ON THE COLUMNS
-- ============================================================================
-- Drop the view first since it depends on created_at column
DROP VIEW IF EXISTS top_up_transaction_summary CASCADE;

-- ============================================================================
-- 3. ALTER TOP_UP_TRANSACTIONS TABLE TO USE PLAIN TIMESTAMP
-- ============================================================================
-- Change created_at and updated_at from TIMESTAMP WITH TIME ZONE to TIMESTAMP WITHOUT TIME ZONE
-- This stores the exact PH time without any timezone conversion
-- The USING clause automatically converts existing UTC timestamps to PH time

-- Alter column types to TIMESTAMP WITHOUT TIME ZONE
-- This converts existing UTC timestamps to Philippines local time
-- For TIMESTAMP WITH TIME ZONE columns, AT TIME ZONE 'Asia/Manila' directly converts UTC to Manila time
ALTER TABLE top_up_transactions 
ALTER COLUMN created_at TYPE TIMESTAMP WITHOUT TIME ZONE 
USING (created_at AT TIME ZONE 'Asia/Manila')::TIMESTAMP WITHOUT TIME ZONE;

ALTER TABLE top_up_transactions 
ALTER COLUMN updated_at TYPE TIMESTAMP WITHOUT TIME ZONE 
USING (updated_at AT TIME ZONE 'Asia/Manila')::TIMESTAMP WITHOUT TIME ZONE;

-- Set defaults to use PH time function
ALTER TABLE top_up_transactions 
ALTER COLUMN created_at SET DEFAULT get_philippines_time_plain();

ALTER TABLE top_up_transactions 
ALTER COLUMN updated_at SET DEFAULT get_philippines_time_plain();

-- ============================================================================
-- 4. RECREATE THE VIEW
-- ============================================================================
-- Recreate the view with the updated column types
CREATE OR REPLACE VIEW top_up_transaction_summary AS
SELECT 
    t.id,
    t.student_id,
    s.name as student_name,
    t.amount,
    t.previous_balance,
    t.new_balance,
    t.transaction_type,
    t.processed_by,
    t.notes,
    t.created_at
FROM top_up_transactions t
LEFT JOIN auth_students s ON t.student_id = s.student_id
ORDER BY t.created_at DESC;

-- Grant access to the recreated view
GRANT SELECT ON top_up_transaction_summary TO service_role;
GRANT SELECT ON top_up_transaction_summary TO authenticated;

-- ============================================================================
-- 5. UPDATE PROCESS_TOP_UP_TRANSACTION FUNCTION
-- ============================================================================
-- Update the function to use plain PH time instead of timezone-aware timestamp
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
    philippines_time TIMESTAMP WITHOUT TIME ZONE;
BEGIN
    -- Get Philippines time as plain timestamp
    philippines_time := get_philippines_time_plain();
    
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
        -- Update student balance (auth_students.updated_at should also use PH time if it exists)
        UPDATE auth_students 
        SET balance = new_balance
        WHERE student_id = p_student_id;
        
        -- Insert transaction record with PH time
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
-- 6. UPDATE UPDATE_TRIGGER FUNCTION
-- ============================================================================
-- Update the trigger function to use plain PH time
CREATE OR REPLACE FUNCTION update_top_up_transactions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = get_philippines_time_plain();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 7. UPDATE GET_RECENT_TOP_UP_TRANSACTIONS FUNCTION
-- ============================================================================
-- Ensure this function returns plain timestamps correctly
CREATE OR REPLACE FUNCTION get_recent_top_up_transactions(
    p_limit INTEGER DEFAULT 20
) RETURNS JSON AS $$
DECLARE
    transactions JSON;
BEGIN
    -- Get recent transactions with student names
    -- Use subquery to order first, then aggregate to avoid GROUP BY issues
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

-- ============================================================================
-- 8. GRANT PERMISSIONS
-- ============================================================================
GRANT EXECUTE ON FUNCTION get_philippines_time_plain() TO service_role, authenticated;
GRANT EXECUTE ON FUNCTION process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT, VARCHAR, DECIMAL, DECIMAL) TO service_role, authenticated;
GRANT EXECUTE ON FUNCTION get_recent_top_up_transactions(INTEGER) TO service_role, authenticated;

-- ============================================================================
-- END OF MIGRATION
-- ============================================================================
-- After running this script:
-- 1. Database stores timestamps as plain TIMESTAMP (e.g., 2025-11-23 14:30:00)
-- 2. All timestamps are in Philippines local time
-- 3. Flutter app should display timestamps directly without conversion
-- ============================================================================

