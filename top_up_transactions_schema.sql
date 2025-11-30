-- =====================================================
-- EVSU Campus Pay - Top-Up Transactions Schema
-- =====================================================
-- This file creates the top_up_transactions table and related functions
-- for tracking top-up history and updating user balances
-- =====================================================

-- =====================================================
-- 1. TOP-UP TRANSACTIONS TABLE
-- =====================================================

-- Create top_up_transactions table
CREATE TABLE IF NOT EXISTS top_up_transactions (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    previous_balance DECIMAL(10,2) NOT NULL CHECK (previous_balance >= 0),
    new_balance DECIMAL(10,2) NOT NULL CHECK (new_balance >= 0),
    transaction_type VARCHAR(20) NOT NULL DEFAULT 'top_up' CHECK (transaction_type = 'top_up'),
    processed_by VARCHAR(100) NOT NULL, -- Admin username or system
    notes TEXT, -- Optional notes about the transaction
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 2. INDEXES FOR PERFORMANCE
-- =====================================================

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_top_up_transactions_student_id ON top_up_transactions(student_id);
CREATE INDEX IF NOT EXISTS idx_top_up_transactions_created_at ON top_up_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_top_up_transactions_transaction_type ON top_up_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_top_up_transactions_processed_by ON top_up_transactions(processed_by);

-- =====================================================
-- 3. CONSTRAINTS
-- =====================================================

-- Add constraint to ensure new_balance = previous_balance + amount
ALTER TABLE top_up_transactions 
ADD CONSTRAINT check_balance_calculation 
CHECK (new_balance = previous_balance + amount);

-- =====================================================
-- 4. FUNCTIONS
-- =====================================================

-- Function to process top-up transaction and update user balance
CREATE OR REPLACE FUNCTION process_top_up_transaction(
    p_student_id VARCHAR(50),
    p_amount DECIMAL(10,2),
    p_processed_by VARCHAR(100),
    p_notes TEXT DEFAULT NULL
) RETURNS JSON AS $$
DECLARE
    current_balance DECIMAL(10,2);
    new_balance DECIMAL(10,2);
    transaction_id INTEGER;
    student_exists BOOLEAN;
BEGIN
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
            'top_up',
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

-- Function to get top-up transaction history for a student
CREATE OR REPLACE FUNCTION get_student_top_up_history(
    p_student_id VARCHAR(50),
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
) RETURNS JSON AS $$
DECLARE
    transactions JSON;
    total_count INTEGER;
BEGIN
    -- Get total count
    SELECT COUNT(*) INTO total_count
    FROM top_up_transactions 
    WHERE student_id = p_student_id;
    
    -- Get transactions
    SELECT json_agg(
        json_build_object(
            'id', id,
            'student_id', student_id,
            'amount', amount,
            'previous_balance', previous_balance,
            'new_balance', new_balance,
            'transaction_type', transaction_type,
            'processed_by', processed_by,
            'notes', notes,
            'created_at', created_at
        )
    ) INTO transactions
    FROM (
        SELECT *
        FROM top_up_transactions 
        WHERE student_id = p_student_id
        ORDER BY created_at DESC
        LIMIT p_limit OFFSET p_offset
    ) t;
    
    RETURN json_build_object(
        'success', true,
        'data', COALESCE(transactions, '[]'::json),
        'pagination', json_build_object(
            'total', total_count,
            'limit', p_limit,
            'offset', p_offset,
            'has_more', (p_offset + p_limit) < total_count
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get recent top-up transactions (for admin dashboard)
CREATE OR REPLACE FUNCTION get_recent_top_up_transactions(
    p_limit INTEGER DEFAULT 20
) RETURNS JSON AS $$
DECLARE
    transactions JSON;
BEGIN
    -- Get recent transactions with student names
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
-- 5. TRIGGERS
-- =====================================================

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_top_up_transactions_updated_at 
    BEFORE UPDATE ON top_up_transactions 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- 6. ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on top_up_transactions table
ALTER TABLE top_up_transactions ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 7. RLS POLICIES
-- =====================================================

-- Policy for service_role (full access)
CREATE POLICY "Service role can manage top_up_transactions" ON top_up_transactions
    FOR ALL TO service_role
    USING (true)
    WITH CHECK (true);

-- Policy for authenticated users (read own transactions)
CREATE POLICY "Users can view own top_up_transactions" ON top_up_transactions
    FOR SELECT TO authenticated
    USING (
        student_id IN (
            SELECT student_id 
            FROM auth_students 
            WHERE auth_user_id = auth.uid()
        )
    );

-- Note: Admin access is handled through service_role, not through RLS policies
-- since admin accounts are separate from Supabase auth system

-- =====================================================
-- 8. PERMISSIONS
-- =====================================================

-- Grant permissions on table
GRANT ALL ON top_up_transactions TO service_role;
GRANT SELECT ON top_up_transactions TO authenticated;
GRANT USAGE ON SEQUENCE top_up_transactions_id_seq TO service_role;
GRANT USAGE ON SEQUENCE top_up_transactions_id_seq TO authenticated;

-- Grant execute permissions on functions
GRANT EXECUTE ON FUNCTION process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION process_top_up_transaction(VARCHAR, DECIMAL, VARCHAR, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION get_student_top_up_history(VARCHAR, INTEGER, INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION get_student_top_up_history(VARCHAR, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_recent_top_up_transactions(INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION get_recent_top_up_transactions(INTEGER) TO authenticated;

-- =====================================================
-- 9. COMMENTS
-- =====================================================

-- Add comments to table and columns
COMMENT ON TABLE top_up_transactions IS 'Transaction history for student top-ups';
COMMENT ON COLUMN top_up_transactions.student_id IS 'Student ID who received the top-up';
COMMENT ON COLUMN top_up_transactions.amount IS 'Amount added to student balance';
COMMENT ON COLUMN top_up_transactions.previous_balance IS 'Student balance before top-up';
COMMENT ON COLUMN top_up_transactions.new_balance IS 'Student balance after top-up';
COMMENT ON COLUMN top_up_transactions.transaction_type IS 'Type of transaction (always top_up)';
COMMENT ON COLUMN top_up_transactions.processed_by IS 'Admin or system that processed the top-up';
COMMENT ON COLUMN top_up_transactions.notes IS 'Optional notes about the transaction';

-- =====================================================
-- 10. VIEWS
-- =====================================================

-- Create a view for top-up transaction summary
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

-- Grant access to the view
GRANT SELECT ON top_up_transaction_summary TO service_role;
GRANT SELECT ON top_up_transaction_summary TO authenticated;

-- =====================================================
-- END OF TOP-UP TRANSACTIONS SCHEMA
-- =====================================================
