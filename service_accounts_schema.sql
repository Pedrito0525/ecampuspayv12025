-- Service Accounts Database Schema
-- This script creates the service_accounts table with main/sub hierarchy support

-- Create service_accounts table
CREATE TABLE IF NOT EXISTS service_accounts (
    id SERIAL PRIMARY KEY,
    service_name VARCHAR(255) NOT NULL,
    service_category VARCHAR(100) NOT NULL, -- 'School Org', 'Vendor', 'Campus Service Units'
    operational_type VARCHAR(20) NOT NULL, -- 'Main' or 'Sub'
    main_service_id INTEGER REFERENCES service_accounts(id) ON DELETE CASCADE, -- NULL for main accounts
    contact_person VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(50),
    username VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL, -- Hashed password
    balance DECIMAL(10,2) DEFAULT 0.00, -- Only for main accounts
    is_active BOOLEAN DEFAULT true,
    scanner_id VARCHAR(100) UNIQUE, -- Assigned scanner ID
    commission_rate DECIMAL(5,2) DEFAULT 0.00, -- Commission percentage
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_service_accounts_service_name ON service_accounts(service_name);
CREATE INDEX IF NOT EXISTS idx_service_accounts_operational_type ON service_accounts(operational_type);
CREATE INDEX IF NOT EXISTS idx_service_accounts_main_service_id ON service_accounts(main_service_id);
CREATE INDEX IF NOT EXISTS idx_service_accounts_username ON service_accounts(username);
CREATE INDEX IF NOT EXISTS idx_service_accounts_scanner_id ON service_accounts(scanner_id);
CREATE INDEX IF NOT EXISTS idx_service_accounts_is_active ON service_accounts(is_active);

-- Add constraint to ensure sub accounts have a main service
ALTER TABLE service_accounts 
ADD CONSTRAINT check_sub_account_has_main 
CHECK (
    (operational_type = 'Main' AND main_service_id IS NULL) OR 
    (operational_type = 'Sub' AND main_service_id IS NOT NULL)
);

-- Add constraint to ensure sub accounts don't have balance
ALTER TABLE service_accounts 
ADD CONSTRAINT check_sub_account_no_balance 
CHECK (
    (operational_type = 'Main') OR 
    (operational_type = 'Sub' AND balance = 0.00)
);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_service_accounts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_service_accounts_updated_at 
    BEFORE UPDATE ON service_accounts 
    FOR EACH ROW 
    EXECUTE FUNCTION update_service_accounts_updated_at();

-- Grant necessary permissions
GRANT ALL ON service_accounts TO service_role;
GRANT ALL ON service_accounts TO authenticated;
GRANT ALL ON service_accounts TO anon;

-- Create a view for service hierarchy
CREATE OR REPLACE VIEW service_hierarchy AS
SELECT 
    sa.id,
    sa.service_name,
    sa.service_category,
    sa.operational_type,
    sa.main_service_id,
    main_sa.service_name as main_service_name,
    sa.contact_person,
    sa.email,
    sa.phone,
    sa.username,
    sa.balance,
    sa.is_active,
    sa.scanner_id,
    sa.commission_rate,
    sa.created_at,
    sa.updated_at
FROM service_accounts sa
LEFT JOIN service_accounts main_sa ON sa.main_service_id = main_sa.id
ORDER BY sa.operational_type, sa.service_name;

-- Create function to transfer sub account balance to main account
CREATE OR REPLACE FUNCTION transfer_sub_account_balance(
    sub_account_id INTEGER,
    amount DECIMAL(10,2)
) RETURNS BOOLEAN AS $$
DECLARE
    main_account_id INTEGER;
    current_main_balance DECIMAL(10,2);
BEGIN
    -- Get the main account ID for this sub account
    SELECT main_service_id INTO main_account_id
    FROM service_accounts 
    WHERE id = sub_account_id AND operational_type = 'Sub';
    
    IF main_account_id IS NULL THEN
        RAISE EXCEPTION 'Sub account not found or not a sub account';
    END IF;
    
    -- Get current main account balance
    SELECT balance INTO current_main_balance
    FROM service_accounts 
    WHERE id = main_account_id;
    
    -- Update main account balance
    UPDATE service_accounts 
    SET balance = current_main_balance + amount,
        updated_at = NOW()
    WHERE id = main_account_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Create function to get total balance for main account (including sub accounts)
CREATE OR REPLACE FUNCTION get_main_account_total_balance(main_account_id INTEGER)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    main_balance DECIMAL(10,2);
    sub_balance DECIMAL(10,2);
BEGIN
    -- Get main account balance
    SELECT COALESCE(balance, 0) INTO main_balance
    FROM service_accounts 
    WHERE id = main_account_id AND operational_type = 'Main';
    
    -- Get total from sub accounts (this would be calculated from transactions)
    -- For now, return just the main balance
    -- In a real implementation, you'd sum up all sub account transactions
    SELECT COALESCE(SUM(balance), 0) INTO sub_balance
    FROM service_accounts 
    WHERE main_service_id = main_account_id AND operational_type = 'Sub';
    
    RETURN COALESCE(main_balance, 0) + COALESCE(sub_balance, 0);
END;
$$ LANGUAGE plpgsql;
