-- Add service_name column to payment_items table
-- This column tracks who created the payment item (main account name or sub account name)
-- Only applies to Campus Service Units (Main and Sub accounts)

-- Add the column
ALTER TABLE payment_items 
ADD COLUMN IF NOT EXISTS service_name VARCHAR(255);

-- Add comment to explain the column
COMMENT ON COLUMN payment_items.service_name IS 'Name of the service account that created this payment item. For Campus Service Units: tracks main account name or sub account name (e.g., "Cashier", "IGP", "Registrar"). For Vendor/Organization: NULL.';

-- Create index for better query performance when filtering by service_name
CREATE INDEX IF NOT EXISTS idx_payment_items_service_name 
ON payment_items(service_name);

-- Update existing records: set service_name based on service_account_id
-- For existing items, we'll set service_name to the service_name from service_accounts table
UPDATE payment_items pi
SET service_name = sa.service_name
FROM service_accounts sa
WHERE pi.service_account_id = sa.id
  AND pi.service_name IS NULL
  AND sa.service_category = 'Campus Service Units';

-- For items that don't have a matching service_account or are not Campus Service Units,
-- leave service_name as NULL (these are likely Vendor/Organization items)

