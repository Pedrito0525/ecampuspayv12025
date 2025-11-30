-- Enable RLS and add policies for existing api_configuration table
-- Run this if the table already exists but RLS is not enabled

-- Enable Row Level Security (RLS)
ALTER TABLE api_configuration ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Admins can read api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Admins can update api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Admins can insert api_configuration" ON api_configuration;
DROP POLICY IF EXISTS "Students can read enabled status" ON api_configuration;

-- Create RLS policies
-- Policy for admins to read configuration
CREATE POLICY "Admins can read api_configuration" ON api_configuration
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth_students 
            WHERE auth_students.id::text = auth.uid()::text
            AND auth_students.role = 'admin'
        )
    );

-- Policy for admins to update configuration
CREATE POLICY "Admins can update api_configuration" ON api_configuration
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth_students 
            WHERE auth_students.id::text = auth.uid()::text
            AND auth_students.role = 'admin'
        )
    );

-- Policy for admins to insert configuration
CREATE POLICY "Admins can insert api_configuration" ON api_configuration
    FOR INSERT
    TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM auth_students 
            WHERE auth_students.id::text = auth.uid()::text
            AND auth_students.role = 'admin'
        )
    );

-- Policy for students to read enabled status only (for top-up checks)
CREATE POLICY "Students can read enabled status" ON api_configuration
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM auth_students 
            WHERE auth_students.id::text = auth.uid()::text
            AND auth_students.role = 'student'
        )
    )
    WITH CHECK (true);
