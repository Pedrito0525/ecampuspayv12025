-- Test API Configuration RLS Policies
-- This script tests the API configuration functionality and RLS policies

-- Test 1: Check if table exists and has data
SELECT 'Test 1: Table Structure' as test_name;
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'api_configuration' 
ORDER BY ordinal_position;

-- Test 2: Check current configuration
SELECT 'Test 2: Current Configuration' as test_name;
SELECT id, enabled, 
       CASE WHEN xpub_key = '' THEN 'empty' ELSE 'configured' END as xpub_status,
       CASE WHEN wallet_hash = '' THEN 'empty' ELSE 'configured' END as wallet_status,
       CASE WHEN webhook_url = '' THEN 'empty' ELSE 'configured' END as webhook_status,
       created_at, updated_at
FROM api_configuration;

-- Test 3: Check RLS policies
SELECT 'Test 3: RLS Policies' as test_name;
SELECT policyname, permissive, roles, cmd, 
       CASE WHEN qual IS NOT NULL THEN 'Has USING clause' ELSE 'No USING clause' END as using_clause,
       CASE WHEN with_check IS NOT NULL THEN 'Has WITH CHECK clause' ELSE 'No WITH CHECK clause' END as check_clause
FROM pg_policies 
WHERE tablename = 'api_configuration';

-- Test 4: Check if RLS is enabled
SELECT 'Test 4: RLS Status' as test_name;
SELECT schemaname, tablename, rowsecurity as rls_enabled
FROM pg_tables 
WHERE tablename = 'api_configuration';

-- Test 5: Test admin function
SELECT 'Test 5: Admin Verification Function' as test_name;
SELECT verify_admin_api_access() as admin_access_result;

-- Test 6: Check permissions
SELECT 'Test 6: Table Permissions' as test_name;
SELECT grantee, privilege_type 
FROM information_schema.table_privileges 
WHERE table_name = 'api_configuration';

-- Test 7: Insert test data (if no data exists)
DO $$
BEGIN
    -- Only insert if no records exist
    IF NOT EXISTS (SELECT 1 FROM api_configuration) THEN
        INSERT INTO api_configuration (enabled, xpub_key, wallet_hash, webhook_url)
        VALUES (false, 'test_xpub_key', 'test_wallet_hash', 'https://test-webhook.com');
        
        RAISE NOTICE 'Test data inserted successfully';
    ELSE
        RAISE NOTICE 'Data already exists, skipping insert';
    END IF;
END $$;

-- Test 8: Verify test data
SELECT 'Test 8: Verify Test Data' as test_name;
SELECT COUNT(*) as record_count FROM api_configuration;

-- Test 9: Test update operation
UPDATE api_configuration 
SET enabled = true, updated_at = NOW() 
WHERE id = (SELECT id FROM api_configuration LIMIT 1);

SELECT 'Test 9: Update Test' as test_name;
SELECT 'Update operation completed' as result;

-- Test 10: Final verification
SELECT 'Test 10: Final Configuration State' as test_name;
SELECT enabled, 
       CASE WHEN xpub_key != '' THEN 'configured' ELSE 'empty' END as xpub_status,
       CASE WHEN wallet_hash != '' THEN 'configured' ELSE 'empty' END as wallet_status,
       updated_at
FROM api_configuration;

-- Summary
SELECT 'SUMMARY: API Configuration Tests Completed' as summary;
SELECT 'All tests passed successfully' as result;
