-- =====================================================
-- EVSU Campus Pay - User Transfer System
-- =====================================================
-- This file creates the user_transfers table and related functions
-- for handling money transfers between users
-- =====================================================

-- =====================================================
-- 1. USER TRANSFERS TABLE
-- =====================================================

-- Create user_transfers table
CREATE TABLE IF NOT EXISTS user_transfers (
    id SERIAL PRIMARY KEY,
    sender_student_id VARCHAR(50) NOT NULL,
    recipient_student_id VARCHAR(50) NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    sender_previous_balance DECIMAL(10,2) NOT NULL CHECK (sender_previous_balance >= 0),
    sender_new_balance DECIMAL(10,2) NOT NULL CHECK (sender_new_balance >= 0),
    recipient_previous_balance DECIMAL(10,2) NOT NULL CHECK (recipient_previous_balance >= 0),
    recipient_new_balance DECIMAL(10,2) NOT NULL CHECK (recipient_new_balance >= 0),
    transaction_type VARCHAR(20) NOT NULL DEFAULT 'transfer' CHECK (transaction_type = 'transfer'),
    status VARCHAR(20) NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'failed', 'pending')),
    notes TEXT, -- Optional notes about the transaction
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- =====================================================
-- 2. INDEXES FOR PERFORMANCE
-- =====================================================

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_user_transfers_sender_student_id ON user_transfers(sender_student_id);
CREATE INDEX IF NOT EXISTS idx_user_transfers_recipient_student_id ON user_transfers(recipient_student_id);
CREATE INDEX IF NOT EXISTS idx_user_transfers_created_at ON user_transfers(created_at);
CREATE INDEX IF NOT EXISTS idx_user_transfers_transaction_type ON user_transfers(transaction_type);
CREATE INDEX IF NOT EXISTS idx_user_transfers_status ON user_transfers(status);

-- =====================================================
-- 3. CONSTRAINTS
-- =====================================================

-- Add constraint to ensure sender cannot transfer to themselves
ALTER TABLE user_transfers 
ADD CONSTRAINT check_no_self_transfer 
CHECK (sender_student_id != recipient_student_id);

-- Add constraint to ensure correct balance calculations
ALTER TABLE user_transfers 
ADD CONSTRAINT check_sender_balance_calculation 
CHECK (sender_new_balance = sender_previous_balance - amount);

-- Add constraint to ensure correct recipient balance calculations
ALTER TABLE user_transfers 
ADD CONSTRAINT check_recipient_balance_calculation 
CHECK (recipient_new_balance = recipient_previous_balance + amount);

-- =====================================================
-- 4. TRANSFER PROCESSING FUNCTION
-- =====================================================

-- Create function to process user transfers
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
    v_result JSONB;
BEGIN
    -- Start transaction
    BEGIN
        -- Validate input parameters
        IF p_sender_student_id IS NULL OR p_recipient_student_id IS NULL OR p_amount IS NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Invalid input parameters'
            );
        END IF;

        -- Check if sender and recipient are different
        IF p_sender_student_id = p_recipient_student_id THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Cannot transfer to yourself'
            );
        END IF;

        -- Validate amount
        IF p_amount <= 0 THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Transfer amount must be greater than 0'
            );
        END IF;

        -- Get sender current balance
        SELECT balance INTO v_sender_balance
        FROM auth_students
        WHERE student_id = p_sender_student_id AND is_active = true;
        
        IF v_sender_balance IS NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Sender not found or inactive'
            );
        END IF;
        
        -- Check if sender has sufficient balance
        IF v_sender_balance < p_amount THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Insufficient balance'
            );
        END IF;
        
        -- Get recipient current balance
        SELECT balance INTO v_recipient_balance
        FROM auth_students
        WHERE student_id = p_recipient_student_id AND is_active = true;
        
        IF v_recipient_balance IS NULL THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Recipient not found or inactive'
            );
        END IF;
        
        -- Calculate new balances
        v_new_sender_balance := v_sender_balance - p_amount;
        v_new_recipient_balance := v_recipient_balance + p_amount;
        
        -- Update sender balance
        UPDATE auth_students 
        SET balance = v_new_sender_balance,
            updated_at = NOW()
        WHERE student_id = p_sender_student_id;
        
        -- Update recipient balance
        UPDATE auth_students 
        SET balance = v_new_recipient_balance,
            updated_at = NOW()
        WHERE student_id = p_recipient_student_id;
        
        -- Create transfer record
        INSERT INTO user_transfers (
            sender_student_id,
            recipient_student_id,
            amount,
            sender_previous_balance,
            sender_new_balance,
            recipient_previous_balance,
            recipient_new_balance,
            transaction_type,
            status,
            notes
        ) VALUES (
            p_sender_student_id,
            p_recipient_student_id,
            p_amount,
            v_sender_balance,
            v_new_sender_balance,
            v_recipient_balance,
            v_new_recipient_balance,
            'transfer',
            'completed',
            'User-to-user transfer'
        ) RETURNING id INTO v_transfer_id;
        
        -- Return success result
        v_result := jsonb_build_object(
            'success', true,
            'transfer_id', v_transfer_id,
            'sender_student_id', p_sender_student_id,
            'recipient_student_id', p_recipient_student_id,
            'amount', p_amount,
            'sender_previous_balance', v_sender_balance,
            'sender_new_balance', v_new_sender_balance,
            'recipient_previous_balance', v_recipient_balance,
            'recipient_new_balance', v_new_recipient_balance,
            'message', 'Transfer completed successfully'
        );
        
        RETURN v_result;
        
    EXCEPTION WHEN OTHERS THEN
        -- Rollback transaction on error
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Transfer failed: ' || SQLERRM
        );
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. HELPER FUNCTIONS
-- =====================================================

-- Function to get transfer history for a user
CREATE OR REPLACE FUNCTION get_user_transfer_history(
    p_student_id VARCHAR(50),
    p_limit INTEGER DEFAULT 50
) RETURNS JSONB AS $$
DECLARE
    v_transfers JSONB;
BEGIN
    SELECT jsonb_agg(
        jsonb_build_object(
            'id', ut.id,
            'sender_student_id', ut.sender_student_id,
            'recipient_student_id', ut.recipient_student_id,
            'amount', ut.amount,
            'sender_previous_balance', ut.sender_previous_balance,
            'sender_new_balance', ut.sender_new_balance,
            'recipient_previous_balance', ut.recipient_previous_balance,
            'recipient_new_balance', ut.recipient_new_balance,
            'transaction_type', ut.transaction_type,
            'status', ut.status,
            'notes', ut.notes,
            'created_at', ut.created_at,
            'is_sent', (ut.sender_student_id = p_student_id),
            'is_received', (ut.recipient_student_id = p_student_id)
        )
    ) INTO v_transfers
    FROM user_transfers ut
    WHERE ut.sender_student_id = p_student_id OR ut.recipient_student_id = p_student_id
    ORDER BY ut.created_at DESC
    LIMIT p_limit;

    RETURN jsonb_build_object(
        'success', true,
        'transfers', COALESCE(v_transfers, '[]'::jsonb),
        'count', jsonb_array_length(COALESCE(v_transfers, '[]'::jsonb))
    );
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. TRIGGERS
-- =====================================================

-- Update timestamp trigger
CREATE OR REPLACE FUNCTION update_user_transfers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_user_transfers_updated_at
    BEFORE UPDATE ON user_transfers
    FOR EACH ROW
    EXECUTE FUNCTION update_user_transfers_updated_at();

-- =====================================================
-- 7. ROW LEVEL SECURITY (RLS)
-- =====================================================

-- Enable RLS on user_transfers table
ALTER TABLE user_transfers ENABLE ROW LEVEL SECURITY;

-- Policy to allow users to view their own transfers
CREATE POLICY "Users can view their own transfers" ON user_transfers
    FOR SELECT USING (
        sender_student_id = current_setting('app.current_student_id', true) OR
        recipient_student_id = current_setting('app.current_student_id', true)
    );

-- Policy to allow authenticated users to insert transfers (handled by function)
CREATE POLICY "Authenticated users can create transfers" ON user_transfers
    FOR INSERT WITH CHECK (true);

-- =====================================================
-- 8. COMMENTS
-- =====================================================

COMMENT ON TABLE user_transfers IS 'Records of money transfers between users';
COMMENT ON COLUMN user_transfers.sender_student_id IS 'Student ID of the person sending money';
COMMENT ON COLUMN user_transfers.recipient_student_id IS 'Student ID of the person receiving money';
COMMENT ON COLUMN user_transfers.amount IS 'Amount being transferred';
COMMENT ON COLUMN user_transfers.sender_previous_balance IS 'Sender balance before transfer';
COMMENT ON COLUMN user_transfers.sender_new_balance IS 'Sender balance after transfer';
COMMENT ON COLUMN user_transfers.recipient_previous_balance IS 'Recipient balance before transfer';
COMMENT ON COLUMN user_transfers.recipient_new_balance IS 'Recipient balance after transfer';
COMMENT ON COLUMN user_transfers.transaction_type IS 'Type of transaction (always transfer)';
COMMENT ON COLUMN user_transfers.status IS 'Status of the transfer (completed, failed, pending)';
COMMENT ON COLUMN user_transfers.notes IS 'Optional notes about the transfer';

COMMENT ON FUNCTION process_user_transfer IS 'Processes a money transfer between two users';
COMMENT ON FUNCTION get_user_transfer_history IS 'Retrieves transfer history for a specific user';

