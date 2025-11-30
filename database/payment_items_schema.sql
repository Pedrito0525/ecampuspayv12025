-- ============================================================================
-- PAYMENT_ITEMS TABLE SCHEMA
-- ============================================================================
-- This file creates the payment_items table for catalog of sellable items
-- ============================================================================

-- ============================================================================
-- 1. CREATE PAYMENT_ITEMS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS payment_items (
    id BIGSERIAL PRIMARY KEY,
    service_account_id BIGINT NOT NULL REFERENCES service_accounts(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    category TEXT NOT NULL,
    base_price DECIMAL(12,2) NOT NULL CHECK (base_price >= 0),
    has_sizes BOOLEAN NOT NULL DEFAULT false,
    size_options JSONB,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_payment_items_service_account_id ON payment_items(service_account_id);
CREATE INDEX IF NOT EXISTS idx_payment_items_is_active ON payment_items(is_active);
CREATE INDEX IF NOT EXISTS idx_payment_items_category ON payment_items(category);
CREATE INDEX IF NOT EXISTS idx_payment_items_created_at ON payment_items(created_at DESC);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_payment_items_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_payment_items_updated_at ON payment_items;
CREATE TRIGGER update_payment_items_updated_at
    BEFORE UPDATE ON payment_items
    FOR EACH ROW
    EXECUTE FUNCTION update_payment_items_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE payment_items ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access payment_items" ON payment_items;
CREATE POLICY "Service role full access payment_items"
ON payment_items
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated users can read active items
DROP POLICY IF EXISTS "Authenticated can read active payment_items" ON payment_items;
CREATE POLICY "Authenticated can read active payment_items"
ON payment_items
FOR SELECT
TO authenticated
USING (is_active = true);

-- Authenticated users can manage items (for service accounts)
DROP POLICY IF EXISTS "Authenticated can manage payment_items" ON payment_items;
CREATE POLICY "Authenticated can manage payment_items"
ON payment_items
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON payment_items TO service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON payment_items TO authenticated;
GRANT USAGE ON SEQUENCE payment_items_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF PAYMENT_ITEMS SCHEMA
-- ============================================================================

