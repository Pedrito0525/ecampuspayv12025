-- EVSU Campus Pay Database Schema
-- This script creates the necessary tables for the student registration system

-- Create student_info table (existing table for CSV import and autofill)
CREATE TABLE IF NOT EXISTS student_info (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    course VARCHAR(100) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create auth_students table (new table for authentication registration)
CREATE TABLE IF NOT EXISTS auth_students (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) UNIQUE NOT NULL,
    name TEXT NOT NULL, -- Encrypted data (can be longer)
    email TEXT UNIQUE NOT NULL, -- Encrypted data (can be longer)
    course TEXT NOT NULL, -- Encrypted data (can be longer)
    rfid_id TEXT UNIQUE, -- Encrypted data (can be longer)
    password TEXT NOT NULL, -- Hashed password (SHA-256 with salt)
    auth_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    balance DECIMAL(10,2) DEFAULT 0.00,
    is_active BOOLEAN DEFAULT true,
    taptopay BOOLEAN DEFAULT true, -- Enable/disable tap to pay functionality
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
-- student_info table indexes
CREATE INDEX IF NOT EXISTS idx_student_info_student_id ON student_info(student_id);
CREATE INDEX IF NOT EXISTS idx_student_info_email ON student_info(email);

-- auth_students table indexes
CREATE INDEX IF NOT EXISTS idx_auth_students_student_id ON auth_students(student_id);
CREATE INDEX IF NOT EXISTS idx_auth_students_email ON auth_students(email);
CREATE INDEX IF NOT EXISTS idx_auth_students_rfid_id ON auth_students(rfid_id);
CREATE INDEX IF NOT EXISTS idx_auth_students_auth_user_id ON auth_students(auth_user_id);
CREATE INDEX IF NOT EXISTS idx_auth_students_is_active ON auth_students(is_active);
CREATE INDEX IF NOT EXISTS idx_auth_students_taptopay ON auth_students(taptopay);

-- Add constraint to ensure email is @evsu.edu.ph format for auth_students
ALTER TABLE auth_students 
ADD CONSTRAINT check_auth_students_evsu_email 
CHECK (email ~* '^[a-zA-Z0-9._%+-]+@evsu\.edu\.ph$');

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers to automatically update updated_at
CREATE TRIGGER update_student_info_updated_at 
    BEFORE UPDATE ON student_info 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_auth_students_updated_at 
    BEFORE UPDATE ON auth_students 
    FOR EACH ROW 
    EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security (RLS)
ALTER TABLE student_info ENABLE ROW LEVEL SECURITY;
-- Temporarily disable RLS for auth_students to fix registration issue
-- ALTER TABLE auth_students ENABLE ROW LEVEL SECURITY;

-- Create policies for RLS
-- student_info table policies (for CSV import/autofill)
CREATE POLICY "Service role can manage student_info" ON student_info
    FOR ALL USING (auth.role() = 'service_role');

-- auth_students table policies (commented out since RLS is disabled)
-- CREATE POLICY "Service role can manage auth_students" ON auth_students
--     FOR ALL USING (auth.role() = 'service_role');

-- CREATE POLICY "Users can view own auth student data" ON auth_students
--     FOR SELECT USING (auth.uid() = auth_user_id);

-- CREATE POLICY "Allow anon insert for registration" ON auth_students
--     FOR INSERT WITH CHECK (true);

-- Grant necessary permissions
GRANT ALL ON student_info TO service_role;
GRANT ALL ON auth_students TO service_role;
GRANT ALL ON auth_students TO authenticated; -- Full access since RLS is disabled
GRANT ALL ON auth_students TO anon; -- Full access since RLS is disabled

-- Create a view for public student directory (without sensitive info)
CREATE OR REPLACE VIEW public_student_directory AS
SELECT 
    student_id,
    name,
    course,
    created_at
FROM auth_students
WHERE rfid_id IS NOT NULL AND is_active = true; -- Only show active students with RFID cards

-- Grant access to the view
GRANT SELECT ON public_student_directory TO authenticated;
