-- ============================================================================
-- ADD TRANSACTION_CODE AND PURPOSE COLUMNS TO SERVICE_TRANSACTIONS TABLE
-- ============================================================================
-- This migration adds transaction_code and purpose columns to service_transactions
-- for Campus Service Units payment flow
-- ============================================================================

-- Add transaction_code column
ALTER TABLE service_transactions
ADD COLUMN IF NOT EXISTS transaction_code VARCHAR(50);

-- Add purpose column
ALTER TABLE service_transactions
ADD COLUMN IF NOT EXISTS purpose TEXT;

-- Add comments to explain the columns
COMMENT ON COLUMN service_transactions.transaction_code IS 'Transaction code in format EVSU-OCC : 000001 for Campus Service Units';
COMMENT ON COLUMN service_transactions.purpose IS 'Purpose of payment entered by user for Campus Service Units transactions';

-- Create index on transaction_code for faster lookups
CREATE INDEX IF NOT EXISTS idx_service_transactions_transaction_code ON service_transactions(transaction_code) WHERE transaction_code IS NOT NULL;

-- ============================================================================
-- FUNCTION TO GENERATE EVSU-OCC TRANSACTION CODE
-- ============================================================================
-- This function generates sequential transaction codes for Campus Service Units
-- Format: EVSU-OCC : 000001, EVSU-OCC : 000002, etc.
-- The sequence starts from 000001 for the first Campus Service Unit transaction
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_evsu_occ_transaction_code(
    p_service_account_id INTEGER
) RETURNS TEXT AS $$
DECLARE
    v_code VARCHAR(50);
    v_sequence_number INTEGER;
BEGIN
    -- Get next sequence number atomically using the helper function
    v_sequence_number := get_next_csu_sequence_number(p_service_account_id);
    
    -- Format: EVSU-OCC : 000001 (6-digit padding)
    -- Note: This function is kept for backward compatibility
    -- The actual transaction_code will be the transaction_csu.id
    v_code := 'EVSU-OCC : ' || LPAD(v_sequence_number::TEXT, 6, '0');
    
    RETURN v_code;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION generate_evsu_occ_transaction_code(INTEGER) TO service_role;
GRANT EXECUTE ON FUNCTION generate_evsu_occ_transaction_code(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_evsu_occ_transaction_code(INTEGER) TO anon;

-- Add comment
COMMENT ON FUNCTION generate_evsu_occ_transaction_code IS 'Generates sequential EVSU-OCC transaction codes for Campus Service Units';

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. transaction_code is nullable to allow flexibility for other service types
-- 2. purpose is nullable - only required for Campus Service Units
-- 3. The transaction code generation function ensures sequential numbering
-- 4. Format: EVSU-OCC : 000001, EVSU-OCC : 000002, etc.
-- 5. Sequence starts from 000001 for the first transaction of each Campus Service Unit
-- ============================================================================

