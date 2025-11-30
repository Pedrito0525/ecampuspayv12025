-- Test script to verify RLS policies are working correctly
-- Run this after applying the RLS migration

-- Test 1: Check if RLS is enabled
SELECT schemaname, tablename, rowsecurity 
FROM pg_tables 
WHERE tablename = 'api_configuration';

-- Test 2: Check existing policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies 
WHERE tablename = 'api_configuration';

-- Test 3: Verify table structure
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns 
WHERE table_name = 'api_configuration'
ORDER BY ordinal_position;

-- Test 4: Check if default record exists
SELECT id, enabled, 
       CASE WHEN xpub_key = '' THEN 'Empty' ELSE 'Has Value' END as xpub_status,
       CASE WHEN wallet_hash = '' THEN 'Empty' ELSE 'Has Value' END as wallet_status,
       CASE WHEN webhook_url = '' THEN 'Empty' ELSE 'Has Value' END as webhook_status,
       created_at, updated_at
FROM api_configuration;

-- Test 5: Verify index exists
SELECT indexname, indexdef 
FROM pg_indexes 
WHERE tablename = 'api_configuration';
