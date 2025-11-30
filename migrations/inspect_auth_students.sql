-- Inspect the auth_students table structure
-- Run this to see what columns actually exist

-- Check table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'auth_students'
ORDER BY ordinal_position;

-- Check if there's a role column or similar
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'auth_students' 
AND column_name LIKE '%role%';

-- Check sample data to understand the structure
SELECT * FROM auth_students LIMIT 3;
