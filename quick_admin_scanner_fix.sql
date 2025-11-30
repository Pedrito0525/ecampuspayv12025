-- Quick fix to ensure admin_accounts table has scanner_id column
-- Run this if the admin scanner assignment is still loading

-- Add scanner_id column if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'admin_accounts' 
        AND column_name = 'scanner_id'
    ) THEN
        ALTER TABLE admin_accounts ADD COLUMN scanner_id VARCHAR(50);
        RAISE NOTICE 'Added scanner_id column to admin_accounts table';
    ELSE
        RAISE NOTICE 'scanner_id column already exists in admin_accounts table';
    END IF;
END $$;

-- Create index if it doesn't exist
CREATE INDEX IF NOT EXISTS idx_admin_accounts_scanner_id ON admin_accounts(scanner_id);

-- Test query to check if admin accounts can be loaded
SELECT 
    id,
    username,
    full_name,
    email,
    role,
    is_active,
    scanner_id,
    created_at,
    updated_at
FROM admin_accounts
ORDER BY full_name
LIMIT 5;

-- Check if there are any admin accounts
SELECT COUNT(*) as admin_count FROM admin_accounts;
