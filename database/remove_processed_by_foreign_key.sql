-- =====================================================
-- Remove Foreign Key for top_up_transactions.processed_by
-- =====================================================
-- This script removes the foreign key constraint because
-- processed_by can contain admin names, service account usernames,
-- or system identifiers, not just service account usernames.
-- =====================================================

-- Step 1: Drop the foreign key constraint if it exists
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
        
        RAISE NOTICE 'Foreign key constraint top_up_transactions_processed_by_fkey dropped successfully';
    ELSE
        RAISE NOTICE 'Foreign key constraint top_up_transactions_processed_by_fkey does not exist';
    END IF;
END $$;

-- Step 2: Keep the index for performance (even without the foreign key)
-- The index is still useful for filtering and joining
CREATE INDEX IF NOT EXISTS idx_top_up_transactions_processed_by_username 
ON top_up_transactions(processed_by);

-- =====================================================
-- IMPORTANT NOTES:
-- 1. processed_by can contain:
--    - Service account usernames (for service account top-ups: transaction_type = 'top_up_services')
--    - Admin names/usernames (for admin top-ups: transaction_type = 'top_up' or 'top_up_gcash')
--      Examples: "Admin (GCash Verification)", "admin", etc.
--    - System identifiers (for system-generated top-ups)
-- 2. Application-level logic should be used to look up service account
--    information when displaying transaction details:
--    - For transaction_type = 'top_up_services': Look up service_accounts by username
--    - For transaction_type = 'top_up' or 'top_up_gcash': Display processed_by as-is (admin name)
-- 3. The index is kept for query performance even without the foreign key
-- =====================================================
-- END OF SCRIPT
-- =====================================================
