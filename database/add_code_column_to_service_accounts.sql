-- ============================================================================
-- ADD CODE COLUMN TO SERVICE_ACCOUNTS TABLE
-- ============================================================================
-- This migration adds a 'code' column to service_accounts table
-- Default value: 'EVSU-OCC' for Campus Service Units category
-- This code will be used in service_transactions for reference/transaction code
-- ============================================================================

-- Add code column to service_accounts table
ALTER TABLE service_accounts
ADD COLUMN IF NOT EXISTS code VARCHAR(50);

-- Add comment to explain the column purpose
COMMENT ON COLUMN service_accounts.code IS 'Service code used for transaction references. Default: EVSU-OCC for Campus Service Units';

-- Update existing Campus Service Units records to have EVSU-OCC code
UPDATE service_accounts
SET code = 'EVSU-OCC'
WHERE service_category = 'Campus Service Units' 
  AND (code IS NULL OR code = '');

-- Create index on code column for faster lookups
CREATE INDEX IF NOT EXISTS idx_service_accounts_code ON service_accounts(code);

-- Optional: Add a function to automatically set code when service_category is Campus Service Units
-- This can be used as a trigger or default value logic
CREATE OR REPLACE FUNCTION set_service_code()
RETURNS TRIGGER AS $$
BEGIN
  -- Auto-set code to EVSU-OCC for Campus Service Units if not provided
  IF NEW.service_category = 'Campus Service Units' AND (NEW.code IS NULL OR NEW.code = '') THEN
    NEW.code := 'EVSU-OCC';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to auto-set code before insert or update
DROP TRIGGER IF EXISTS trigger_set_service_code ON service_accounts;
CREATE TRIGGER trigger_set_service_code
  BEFORE INSERT OR UPDATE ON service_accounts
  FOR EACH ROW
  EXECUTE FUNCTION set_service_code();

-- ============================================================================
-- NOTES:
-- ============================================================================
-- 1. The code column is nullable to allow flexibility for other service categories
-- 2. Campus Service Units will automatically get 'EVSU-OCC' code
-- 3. Other service categories can have their own codes or remain NULL
-- 4. The trigger ensures code is set automatically during insert/update
-- 5. This code can be referenced in service_transactions table for transaction codes
-- ============================================================================

