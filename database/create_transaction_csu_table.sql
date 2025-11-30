-- ============================================================================
-- CREATE TRANSACTION_CSU TABLE
-- ============================================================================
-- This table tracks Campus Service Units transaction codes
-- Each row represents a sequential transaction code for EVSU-OCC
-- The transaction_code in service_transactions will reference this table's id
-- ============================================================================

-- Create transaction_csu table
CREATE TABLE IF NOT EXISTS transaction_csu (
    id BIGSERIAL PRIMARY KEY,
    service_transactions_id BIGINT NOT NULL REFERENCES service_transactions(id) ON DELETE CASCADE,
    sequence_number INTEGER NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    
    -- Ensure one transaction_csu record per service_transaction
    CONSTRAINT unique_service_transaction UNIQUE (service_transactions_id),
    
    -- Ensure sequence numbers are positive
    CONSTRAINT positive_sequence_number CHECK (sequence_number > 0)
);

-- Create index on service_transactions_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_transaction_csu_service_transactions_id 
ON transaction_csu(service_transactions_id);

-- Create index on sequence_number for faster queries
CREATE INDEX IF NOT EXISTS idx_transaction_csu_sequence_number 
ON transaction_csu(sequence_number);

-- Add comment to table
COMMENT ON TABLE transaction_csu IS 'Tracks Campus Service Units transaction codes with sequential numbering';

-- Add comments to columns
COMMENT ON COLUMN transaction_csu.id IS 'Primary key - used as transaction_code in service_transactions';
COMMENT ON COLUMN transaction_csu.service_transactions_id IS 'Foreign key to service_transactions table';
COMMENT ON COLUMN transaction_csu.sequence_number IS 'Sequential number for EVSU-OCC transactions (000001, 000002, etc.)';

-- ============================================================================
-- ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================================================

-- Enable RLS on transaction_csu table
ALTER TABLE transaction_csu ENABLE ROW LEVEL SECURITY;

-- Policy: Allow service_role to do everything
CREATE POLICY "Service role can manage transaction_csu"
ON transaction_csu
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy: Allow authenticated users to read transaction_csu
CREATE POLICY "Authenticated users can read transaction_csu"
ON transaction_csu
FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert transaction_csu
CREATE POLICY "Authenticated users can insert transaction_csu"
ON transaction_csu
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow anon role to insert transaction_csu (for RPC functions)
CREATE POLICY "Anon can insert transaction_csu"
ON transaction_csu
FOR INSERT
TO anon
WITH CHECK (true);

-- ============================================================================
-- FUNCTION TO GET NEXT SEQUENCE NUMBER FOR CAMPUS SERVICE UNITS
-- ============================================================================
-- This function atomically gets the next sequence number for a service account
-- ============================================================================

CREATE OR REPLACE FUNCTION get_next_csu_sequence_number(
    p_service_account_id INTEGER
) RETURNS INTEGER AS $$
DECLARE
    v_next_sequence INTEGER;
    v_main_service_id INTEGER;
    v_target_service_id INTEGER;
BEGIN
    -- Get the main service ID from the service account
    -- For sub accounts: main_service_id will be the main account ID
    -- For main accounts: main_service_id will be NULL
    SELECT main_service_id INTO v_main_service_id
    FROM service_accounts
    WHERE id = p_service_account_id;
    
    -- Determine target service ID for sequence numbering:
    --   - For sub accounts: use main_service_id (to continue main account's sequence)
    --   - For main accounts: use p_service_account_id (the main account itself)
    v_target_service_id := COALESCE(v_main_service_id, p_service_account_id);
    
    -- Use advisory lock to prevent concurrent access (lock on target service ID)
    PERFORM pg_advisory_xact_lock(v_target_service_id);
    
    -- Get the maximum sequence number for transactions belonging to the target main service
    -- This ensures sub accounts continue the sequence from the main account
    -- Filter by main_service_id in service_transactions (which is set to the main account ID for both main and sub)
    SELECT COALESCE(MAX(tc.sequence_number), 0) + 1 INTO v_next_sequence
    FROM transaction_csu tc
    INNER JOIN service_transactions st ON tc.service_transactions_id = st.id
    WHERE st.main_service_id = v_target_service_id;
    
    RETURN v_next_sequence;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_next_csu_sequence_number(INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION get_next_csu_sequence_number(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_next_csu_sequence_number(INTEGER) TO anon;

-- Add comment
COMMENT ON FUNCTION get_next_csu_sequence_number IS 'Atomically gets the next sequence number for Campus Service Units transactions';

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. transaction_csu.id is used as the transaction_code in service_transactions
-- 2. sequence_number tracks the sequential order (000001, 000002, etc.)
-- 3. Each service_transaction can have only one transaction_csu record
-- 4. RLS policies allow service_role, authenticated, and anon to insert
-- 5. The function uses advisory locks to prevent race conditions
-- ============================================================================

