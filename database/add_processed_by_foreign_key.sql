-- =====================================================
-- Add Foreign Key for top_up_transactions.processed_by
-- =====================================================
-- This script adds a foreign key constraint to link
-- top_up_transactions.processed_by to service_accounts.username
-- =====================================================

-- Step 1: Check if foreign key already exists and drop it if it does
DO $$
BEGIN
    -- Drop the foreign key if it exists
    IF EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'top_up_transactions_processed_by_fkey'
        AND table_name = 'top_up_transactions'
    ) THEN
        ALTER TABLE top_up_transactions 
        DROP CONSTRAINT top_up_transactions_processed_by_fkey;
    END IF;
END $$;

-- Step 2: Add foreign key constraint
-- Note: This will only work if processed_by values match existing usernames
-- For existing data that doesn't match, we'll need to handle that separately
ALTER TABLE top_up_transactions
ADD CONSTRAINT top_up_transactions_processed_by_fkey
FOREIGN KEY (processed_by) 
REFERENCES service_accounts(username)
ON DELETE SET NULL
ON UPDATE CASCADE;

-- Step 3: Create index for better join performance
CREATE INDEX IF NOT EXISTS idx_top_up_transactions_processed_by_username 
ON top_up_transactions(processed_by);

-- =====================================================
-- IMPORTANT NOTES:
-- 1. This foreign key assumes processed_by contains service account usernames
-- 2. If you have existing data with service names or admin names in processed_by,
--    you'll need to update those records first
-- 3. The foreign key allows NULL values, so admin-processed transactions
--    (which might use admin usernames) won't break
-- =====================================================
-- END OF SCRIPT
-- =====================================================

