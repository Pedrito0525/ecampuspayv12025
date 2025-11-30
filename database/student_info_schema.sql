-- ============================================================================
-- STUDENT_INFO TABLE SCHEMA
-- ============================================================================
-- This file creates the student_info table with all necessary components:
-- - Table structure with constraints
-- - Indexes for performance
-- - Functions for common operations
-- - Row Level Security (RLS) policies
-- - Triggers for automatic updates
-- ============================================================================
-- NOTE: student_info is used for CSV import and autofill during registration
-- It contains unencrypted data for quick lookup
-- ============================================================================

-- ============================================================================
-- 1. DROP EXISTING OBJECTS (IF NEEDED)
-- ============================================================================
-- Uncomment these if you need to recreate everything from scratch
-- DROP TRIGGER IF EXISTS update_student_info_updated_at ON student_info;
-- DROP FUNCTION IF EXISTS update_student_info_updated_at();
-- DROP POLICY IF EXISTS "Service role can manage student_info" ON student_info;
-- DROP POLICY IF EXISTS "Allow all operations on student_info" ON student_info;
-- DROP TABLE IF EXISTS student_info CASCADE;

-- ============================================================================
-- 2. CREATE STUDENT_INFO TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS student_info (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    course VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT student_info_student_id_unique UNIQUE (student_id),
    CONSTRAINT student_info_email_unique UNIQUE (email),
    CONSTRAINT student_info_email_format CHECK (email ~* '^[a-zA-Z0-9._%+-]+@evsu\.edu\.ph$')
);

-- ============================================================================
-- 3. CREATE INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_student_info_student_id ON student_info(student_id);
CREATE INDEX IF NOT EXISTS idx_student_info_email ON student_info(email);
CREATE INDEX IF NOT EXISTS idx_student_info_course ON student_info(course);
CREATE INDEX IF NOT EXISTS idx_student_info_created_at ON student_info(created_at);
CREATE INDEX IF NOT EXISTS idx_student_info_updated_at ON student_info(updated_at);

-- ============================================================================
-- 4. CREATE FUNCTIONS
-- ============================================================================

-- Function to update updated_at timestamp automatically
CREATE OR REPLACE FUNCTION update_student_info_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to search student info by student_id
CREATE OR REPLACE FUNCTION search_student_info(p_student_id VARCHAR(50))
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
        created_at,
        updated_at
    INTO student_record
    FROM student_info
    WHERE student_id = p_student_id;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Student info not found'
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
            'created_at', student_record.created_at,
            'updated_at', student_record.updated_at
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to search student info by email
CREATE OR REPLACE FUNCTION search_student_info_by_email(p_email VARCHAR(255))
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
        created_at,
        updated_at
    INTO student_record
    FROM student_info
    WHERE email = p_email;
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'message', 'Student info not found'
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
            'created_at', student_record.created_at,
            'updated_at', student_record.updated_at
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to bulk insert student info (for CSV import)
CREATE OR REPLACE FUNCTION bulk_insert_student_info(
    p_students JSON
)
RETURNS JSON AS $$
DECLARE
    student_item JSON;
    inserted_count INTEGER := 0;
    skipped_count INTEGER := 0;
    error_count INTEGER := 0;
    errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
    -- Loop through each student in the JSON array
    FOR student_item IN SELECT * FROM json_array_elements(p_students)
    LOOP
        BEGIN
            INSERT INTO student_info (student_id, name, email, course)
            VALUES (
                student_item->>'student_id',
                student_item->>'name',
                student_item->>'email',
                student_item->>'course'
            )
            ON CONFLICT (student_id) DO UPDATE
            SET
                name = EXCLUDED.name,
                email = EXCLUDED.email,
                course = EXCLUDED.course,
                updated_at = NOW();
            
            inserted_count := inserted_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                error_count := error_count + 1;
                errors := array_append(
                    errors,
                    format('Student ID %s: %s', 
                        COALESCE(student_item->>'student_id', 'unknown'),
                        SQLERRM
                    )
                );
        END;
    END LOOP;
    
    RETURN json_build_object(
        'success', true,
        'inserted', inserted_count,
        'skipped', skipped_count,
        'errors', error_count,
        'error_messages', errors
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all student info (paginated)
CREATE OR REPLACE FUNCTION get_all_student_info(
    p_limit INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0,
    p_search_term VARCHAR(255) DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    students JSON;
    total_count INTEGER;
BEGIN
    -- Get total count
    IF p_search_term IS NULL THEN
        SELECT COUNT(*) INTO total_count FROM student_info;
    ELSE
        SELECT COUNT(*) INTO total_count
        FROM student_info
        WHERE 
            student_id ILIKE '%' || p_search_term || '%'
            OR name ILIKE '%' || p_search_term || '%'
            OR email ILIKE '%' || p_search_term || '%'
            OR course ILIKE '%' || p_search_term || '%';
    END IF;
    
    -- Get paginated results
    IF p_search_term IS NULL THEN
        SELECT json_agg(
            json_build_object(
                'id', id,
                'student_id', student_id,
                'name', name,
                'email', email,
                'course', course,
                'created_at', created_at,
                'updated_at', updated_at
            )
        ) INTO students
        FROM student_info
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset;
    ELSE
        SELECT json_agg(
            json_build_object(
                'id', id,
                'student_id', student_id,
                'name', name,
                'email', email,
                'course', course,
                'created_at', created_at,
                'updated_at', updated_at
            )
        ) INTO students
        FROM student_info
        WHERE 
            student_id ILIKE '%' || p_search_term || '%'
            OR name ILIKE '%' || p_search_term || '%'
            OR email ILIKE '%' || p_search_term || '%'
            OR course ILIKE '%' || p_search_term || '%'
        ORDER BY created_at DESC
        LIMIT p_limit
        OFFSET p_offset;
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'data', COALESCE(students, '[]'::json),
        'total', total_count,
        'limit', p_limit,
        'offset', p_offset
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- 5. CREATE TRIGGERS
-- ============================================================================

-- Trigger to automatically update updated_at timestamp
CREATE TRIGGER update_student_info_updated_at
    BEFORE UPDATE ON student_info
    FOR EACH ROW
    EXECUTE FUNCTION update_student_info_updated_at();

-- ============================================================================
-- 6. ENABLE ROW LEVEL SECURITY (RLS)
-- ============================================================================
ALTER TABLE student_info ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 7. CREATE RLS POLICIES
-- ============================================================================

-- Policy: Service role has full access
DROP POLICY IF EXISTS "Service role can manage student_info" ON student_info;
CREATE POLICY "Service role can manage student_info"
ON student_info
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- Policy: Allow authenticated users to read (for autofill during registration)
DROP POLICY IF EXISTS "Allow authenticated read on student_info" ON student_info;
CREATE POLICY "Allow authenticated read on student_info"
ON student_info
FOR SELECT
TO authenticated
USING (true);

-- Policy: Allow authenticated users to insert (for CSV import)
DROP POLICY IF EXISTS "Allow authenticated insert on student_info" ON student_info;
CREATE POLICY "Allow authenticated insert on student_info"
ON student_info
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Policy: Allow authenticated users to update (for data updates)
DROP POLICY IF EXISTS "Allow authenticated update on student_info" ON student_info;
CREATE POLICY "Allow authenticated update on student_info"
ON student_info
FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- ============================================================================
-- 8. GRANT PERMISSIONS
-- ============================================================================
GRANT ALL ON student_info TO service_role;
GRANT SELECT, INSERT, UPDATE ON student_info TO authenticated;
GRANT USAGE ON SEQUENCE student_info_id_seq TO service_role, authenticated;

-- ============================================================================
-- END OF STUDENT_INFO SCHEMA
-- ============================================================================

