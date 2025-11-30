-- ================================================================
-- WITHDRAWAL TRANSACTIONS TABLE
-- ================================================================
-- This table tracks all withdrawal transactions from users and service accounts
-- Users can withdraw to Admin or to Service accounts
-- Service accounts can only withdraw to Admin
-- ================================================================

-- Create the withdrawal_transactions table
CREATE TABLE IF NOT EXISTS public.withdrawal_transactions (
    id BIGSERIAL PRIMARY KEY,
    student_id TEXT,  -- NULL for service withdrawals
    service_account_id INTEGER,  -- NULL for user withdrawals
    amount DECIMAL(10, 2) NOT NULL CHECK (amount > 0),
    transaction_type TEXT NOT NULL,  -- 'Withdraw to Admin', 'Withdraw to Service', 'Service Withdraw to Admin'
    destination_service_id INTEGER,  -- NULL if withdrawing to admin
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT check_has_student_or_service CHECK (
        (student_id IS NOT NULL AND service_account_id IS NULL) OR
        (student_id IS NULL AND service_account_id IS NOT NULL)
    ),
    CONSTRAINT valid_transaction_type CHECK (
        transaction_type IN ('Withdraw to Admin', 'Withdraw to Service', 'Service Withdraw to Admin')
    )
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_withdrawal_transactions_student_id ON public.withdrawal_transactions(student_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_transactions_service_account_id ON public.withdrawal_transactions(service_account_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_transactions_created_at ON public.withdrawal_transactions(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_withdrawal_transactions_transaction_type ON public.withdrawal_transactions(transaction_type);

-- Enable Row Level Security
ALTER TABLE public.withdrawal_transactions ENABLE ROW LEVEL SECURITY;

-- ================================================================
-- RLS POLICIES
-- ================================================================

-- Policy 1: Allow users to view their own withdrawal transactions
DROP POLICY IF EXISTS "Users can view own withdrawals" ON public.withdrawal_transactions;
CREATE POLICY "Users can view own withdrawals" 
ON public.withdrawal_transactions
FOR SELECT
USING (
    student_id IS NOT NULL AND 
    student_id = current_setting('request.jwt.claims', true)::json->>'student_id'
);

-- Policy 2: Allow service accounts to view their own withdrawal transactions
DROP POLICY IF EXISTS "Service accounts can view own withdrawals" ON public.withdrawal_transactions;
CREATE POLICY "Service accounts can view own withdrawals" 
ON public.withdrawal_transactions
FOR SELECT
USING (
    service_account_id IS NOT NULL AND 
    service_account_id::text = current_setting('request.jwt.claims', true)::json->>'service_id'
);

-- Policy 3: Allow authenticated users to insert their own withdrawal transactions
DROP POLICY IF EXISTS "Users can insert own withdrawals" ON public.withdrawal_transactions;
CREATE POLICY "Users can insert own withdrawals" 
ON public.withdrawal_transactions
FOR INSERT
WITH CHECK (
    student_id IS NOT NULL AND 
    student_id = current_setting('request.jwt.claims', true)::json->>'student_id'
);

-- Policy 4: Allow service accounts to insert their own withdrawal transactions
DROP POLICY IF EXISTS "Service accounts can insert own withdrawals" ON public.withdrawal_transactions;
CREATE POLICY "Service accounts can insert own withdrawals" 
ON public.withdrawal_transactions
FOR INSERT
WITH CHECK (
    service_account_id IS NOT NULL AND 
    service_account_id::text = current_setting('request.jwt.claims', true)::json->>'service_id'
);

-- Policy 5: Allow service role (backend/admin) full access
DROP POLICY IF EXISTS "Service role has full access" ON public.withdrawal_transactions;
CREATE POLICY "Service role has full access" 
ON public.withdrawal_transactions
FOR ALL
USING (true)
WITH CHECK (true);

-- ================================================================
-- GRANT PERMISSIONS
-- ================================================================

-- Grant permissions to authenticated users
GRANT SELECT, INSERT ON public.withdrawal_transactions TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE withdrawal_transactions_id_seq TO authenticated;

-- Grant full permissions to service role (for admin operations)
GRANT ALL ON public.withdrawal_transactions TO service_role;
GRANT ALL ON SEQUENCE withdrawal_transactions_id_seq TO service_role;

-- Grant select to anon (read-only public access if needed)
GRANT SELECT ON public.withdrawal_transactions TO anon;

-- ================================================================
-- COMMENTS
-- ================================================================

COMMENT ON TABLE public.withdrawal_transactions IS 'Stores all withdrawal transactions from users and service accounts';
COMMENT ON COLUMN public.withdrawal_transactions.student_id IS 'Student ID for user withdrawals (NULL for service withdrawals)';
COMMENT ON COLUMN public.withdrawal_transactions.service_account_id IS 'Service account ID for service withdrawals (NULL for user withdrawals)';
COMMENT ON COLUMN public.withdrawal_transactions.amount IS 'Withdrawal amount in PHP';
COMMENT ON COLUMN public.withdrawal_transactions.transaction_type IS 'Type: Withdraw to Admin, Withdraw to Service, or Service Withdraw to Admin';
COMMENT ON COLUMN public.withdrawal_transactions.destination_service_id IS 'Target service ID when withdrawing to a service (NULL for admin withdrawals)';
COMMENT ON COLUMN public.withdrawal_transactions.metadata IS 'Additional transaction metadata in JSON format';
COMMENT ON COLUMN public.withdrawal_transactions.created_at IS 'Timestamp when withdrawal was created';

-- ================================================================
-- VERIFICATION QUERY
-- ================================================================
-- Run this to verify the table was created successfully:
-- SELECT * FROM public.withdrawal_transactions LIMIT 1;

-- ================================================================
-- SAMPLE INSERT (for testing)
-- ================================================================
-- User withdrawal to admin:
-- INSERT INTO public.withdrawal_transactions (student_id, amount, transaction_type, metadata)
-- VALUES ('2021-12345', 500.00, 'Withdraw to Admin', '{"destination_type": "admin"}'::jsonb);

-- User withdrawal to service:
-- INSERT INTO public.withdrawal_transactions (student_id, amount, transaction_type, destination_service_id, metadata)
-- VALUES ('2021-12345', 200.00, 'Withdraw to Service', 1, '{"destination_type": "service", "destination_service_name": "Canteen"}'::jsonb);

-- Service withdrawal to admin:
-- INSERT INTO public.withdrawal_transactions (service_account_id, amount, transaction_type, metadata)
-- VALUES (1, 1000.00, 'Service Withdraw to Admin', '{"destination_type": "admin", "service_name": "Canteen"}'::jsonb);

