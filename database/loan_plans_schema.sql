-- ============================================================================
-- LOAN_PLANS TABLE SCHEMA
-- ============================================================================
-- This file creates the loan_plans table for admin-defined loan products
-- ============================================================================

-- ============================================================================
-- 1. CREATE LOAN_PLANS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS loan_plans (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    term_days INTEGER NOT NULL CHECK (term_days > 0),
    interest_rate DECIMAL(5,2) NOT NULL CHECK (interest_rate >= 0),
    penalty_rate DECIMAL(5,2) NOT NULL CHECK (penalty_rate >= 0),
    min_topup DECIMAL(10,2) NOT NULL CHECK (min_topup >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- 2. CREATE INDEXES
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_loan_plans_status ON loan_plans(status);
CREATE INDEX IF NOT EXISTS idx_loan_plans_created_at ON loan_plans(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_loan_plans_name ON loan_plans(name);

-- ============================================================================
-- 3. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_loan_plans_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. CREATE TRIGGERS
-- ============================================================================
DROP TRIGGER IF EXISTS update_loan_plans_updated_at ON loan_plans;
CREATE TRIGGER update_loan_plans_updated_at
    BEFORE UPDATE ON loan_plans
    FOR EACH ROW
    EXECUTE FUNCTION update_loan_plans_updated_at();

-- ============================================================================
-- 5. ENABLE RLS
-- ============================================================================
ALTER TABLE loan_plans ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 6. CREATE RLS POLICIES
-- ============================================================================

-- Service role has full access
DROP POLICY IF EXISTS "Service role full access loan_plans" ON loan_plans;
CREATE POLICY "Service role full access loan_plans"
ON loan_plans
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Authenticated users can read active loan plans
DROP POLICY IF EXISTS "Authenticated can read active loan_plans" ON loan_plans;
CREATE POLICY "Authenticated can read active loan_plans"
ON loan_plans
FOR SELECT
TO authenticated
USING (status = 'active');

-- ============================================================================
-- 7. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON loan_plans TO service_role;
GRANT SELECT ON loan_plans TO authenticated;
GRANT USAGE ON SEQUENCE loan_plans_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF LOAN_PLANS SCHEMA
-- ============================================================================

