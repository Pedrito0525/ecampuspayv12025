-- Test script for top-up transactions schema
-- Run this after executing top_up_transactions_schema.sql

-- Test 1: Check if the table exists
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'top_up_transactions' 
ORDER BY ordinal_position;

-- Test 2: Check if functions exist
SELECT routine_name, routine_type 
FROM information_schema.routines 
WHERE routine_name IN (
    'process_top_up_transaction',
    'get_student_top_up_history', 
    'get_recent_top_up_transactions'
);

-- Test 3: Check RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies 
WHERE tablename = 'top_up_transactions';

-- Test 4: Test the process_top_up_transaction function with a sample student
-- (Replace 'EVSU-2024-001' with an actual student_id from your auth_students table)
-- SELECT process_top_up_transaction(
--     'EVSU-2024-001'::VARCHAR,
--     100.00::DECIMAL,
--     'test_admin'::VARCHAR,
--     'Test transaction'::TEXT
-- );

-- Test 5: Check if indexes were created
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'top_up_transactions';

-- Test 6: Verify constraints
SELECT conname, contype, consrc
FROM pg_constraint 
WHERE conrelid = 'top_up_transactions'::regclass;
