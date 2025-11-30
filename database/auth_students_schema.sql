-- ============================================================================
-- AUTH_STUDENTS TABLE SCHEMA
-- ============================================================================
-- This file creates the auth_students table with all necessary components:
-- - Table structure with constraints
-- - Indexes for performance
-- - Functions for common operations
-- - Row Level Security (RLS) policies
-- - Triggers for automatic updates
-- ============================================================================

-- ============================================================================
-- 1. DROP EXISTING OBJECTS (IF NEEDED)
-- ============================================================================
-- Uncomment these if you need to recreate everything from scratch
-- DROP TRIGGER IF EXISTS update_auth_students_updated_at ON auth_students;
-- DROP FUNCTION IF EXISTS update_auth_students_updated_at();
-- DROP POLICY IF EXISTS "Service role can do everything on auth_students" ON auth_students;
-- DROP POLICY IF EXISTS "Students can view own data" ON auth_students;
-- DROP POLICY IF EXISTS "Students can update own data" ON auth_students;
-- DROP POLICY IF EXISTS "Allow authenticated insert for registration" ON auth_students;
-- DROP TABLE IF EXISTS auth_students CASCADE;

-- ============================================================================
-- 2. CREATE AUTH_STUDENTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS auth_students (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) UNIQUE NOT NULL,
    name TEXT NOT NULL, -- Encrypted data (can be longer)
    email TEXT UNIQUE NOT NULL, -- Encrypted data (can be longer)
    course TEXT NOT NULL, -- Encrypted data (can be longer)
    rfid_id TEXT UNIQUE, -- Encrypted data (can be longer)
    password TEXT NOT NULL, -- Hashed password (SHA-256 with salt)
    auth_user_id UUID, -- References auth.users(id) but no FK constraint to avoid circular dependencies
    balance DECIMAL(10,2) DEFAULT 0.00 CHECK (balance >= 0),
    is_active BOOLEAN DEFAULT true,
    taptopay BOOLEAN DEFAULT true, -- Enable/disable tap to pay functionality
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT auth_students_student_id_unique UNIQUE (student_id),
    CONSTRAINT auth_students_email_unique UNIQUE (email),
    CONSTRAINT auth_students_rfid_id_unique UNIQUE (rfid_id),
    CONSTRAINT auth_students_balance_non_negative CHECK (balance >= 0)
);

-- ============================================================================
-- 3. CREATE INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_auth_students_student_id ON auth_students(student_id);
CREATE INDEX IF NOT EXISTS idx_auth_students_email ON auth_students(email);
CREATE INDEX IF NOT EXISTS idx_auth_students_rfid_id ON auth_students(rfid_id) WHERE rfid_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_auth_students_auth_user_id ON auth_students(auth_user_id) WHERE auth_user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_auth_students_is_active ON auth_students(is_active);
CREATE INDEX IF NOT EXISTS idx_auth_students_taptopay ON auth_students(taptopay);
CREATE INDEX IF NOT EXISTS idx_auth_students_created_at ON auth_students(created_at);
CREATE INDEX IF NOT EXISTS idx_auth_students_updated_at ON auth_students(updated_at);

-- ============================================================================
-- 4. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp automatically
CREATE OR REPLACE FUNCTION update_auth_students_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to get student balance
CREATE OR REPLACE FUNCTION get_student_balance(p_student_id VARCHAR(50))
RETURNS DECIMAL(10,2) AS $$
DECLARE
    student_balance DECIMAL(10,2);
BEGIN
    SELECT balance INTO student_balance
    FROM auth_students
    WHERE student_id = p_student_id AND is_active = true;
    
    RETURN COALESCE(student_balance, 0.00);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update student balance (with validation)
CREATE OR REPLACE FUNCTION update_student_balance(
    p_student_id VARCHAR(50),
    p_amount DECIMAL(10,2)
)
RETURNS JSON AS $$
DECLARE
    current_balance DECIMAL(10,2);
    new_balance DECIMAL(10,2);
BEGIN
    -- Get current balance
    SELECT balance INTO current_balance
    FROM auth_students
    WHERE student_id = p_student_id AND is_active = true;
    
    IF current_balance IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Student not found or inactive'
        );
    END IF;
    
    -- Calculate new balance
    new_balance := current_balance + p_amount;
    
    -- Check if balance would be negative
    IF new_balance < 0 THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Insufficient balance',
            'current_balance', current_balance,
            'requested_amount', p_amount
        );
    END IF;
    
    -- Update balance
    UPDATE auth_students
    SET balance = new_balance,
        updated_at = NOW()
    WHERE student_id = p_student_id;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Balance updated successfully',
        'previous_balance', current_balance,
        'new_balance', new_balance,
        'amount_changed', p_amount
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to check if student exists and is active
CREATE OR REPLACE FUNCTION check_student_active(p_student_id VARCHAR(50))
RETURNS BOOLEAN AS $$
DECLARE
    is_student_active BOOLEAN;
BEGIN
    SELECT is_active INTO is_student_active
    FROM auth_students
    WHERE student_id = p_student_id;
    
    RETURN COALESCE(is_student_active, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get student info by student_id (for admin use)
CREATE OR REPLACE FUNCTION get_student_info(p_student_id VARCHAR(50))
RETURNS JSON AS $$
DECLARE
    student_record RECORD;
BEGIN
    SELECT 
        id,
        student_id,
        name,
        email,
        course,
        rfid_id,
        balance,
        is_active,
        taptopay,
        created_at,
        updated_at
    INTO student_record
    FROM auth_students
    WHERE student_id = p_student_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Student not found'
        );
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'data', json_build_object(
            'id', student_record.id,
            'student_id', student_record.student_id,
            'name', student_record.name,
            'email', student_record.email,
            'course', student_record.course,
            'rfid_id', student_record.rfid_id,
            'balance', student_record.balance,
            'is_active', student_record.is_active,
            'taptopay', student_record.taptopay,
            'created_at', student_record.created_at,
            'updated_at', student_record.updated_at
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 5. CREATE TRIGGERS
-- ============================================================================

-- Trigger to automatically update updated_at timestamp
CREATE TRIGGER update_auth_students_updated_at
    BEFORE UPDATE ON auth_students
    FOR EACH ROW
    EXECUTE FUNCTION update_auth_students_updated_at();

-- ============================================================================
-- 6. ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================================================
ALTER TABLE auth_students ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 7. CREATE RLS POLICIES
-- ============================================================================

-- Policy: Service role has full access
DROP POLICY IF EXISTS "Service role can do everything on auth_students" ON auth_students;
CREATE POLICY "Service role can do everything on auth_students"
ON auth_students
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy: Students can view their own data
DROP POLICY IF EXISTS "Students can view own data" ON auth_students;
CREATE POLICY "Students can view own data"
ON auth_students
FOR SELECT
TO authenticated
USING (auth_user_id = auth.uid());

-- Policy: Students can update their own data (limited fields)
-- Note: In practice, students should only update via service role functions
-- This policy allows minimal updates but prevents critical field changes
DROP POLICY IF EXISTS "Students can update own data" ON auth_students;
CREATE POLICY "Students can update own data"
ON auth_students
FOR UPDATE
TO authenticated
USING (auth_user_id = auth.uid())
WITH CHECK (
    auth_user_id = auth.uid()
    -- Ensure critical fields remain unchanged
    AND NEW.student_id = OLD.student_id
    AND NEW.email = OLD.email
    AND NEW.password = OLD.password
    AND NEW.balance = OLD.balance
);

-- Policy: Allow authenticated users to insert (for registration)
DROP POLICY IF EXISTS "Allow authenticated insert for registration" ON auth_students;
CREATE POLICY "Allow authenticated insert for registration"
ON auth_students
FOR INSERT
TO authenticated
WITH CHECK (true);

-- ============================================================================
-- 8. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON auth_students TO service_role;
GRANT SELECT, INSERT, UPDATE ON auth_students TO authenticated;
GRANT USAGE ON SEQUENCE auth_students_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF AUTH_STUDENTS SCHEMA
-- ============================================================================

