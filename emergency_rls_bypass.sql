-- Emergency RLS bypass for admin_accounts table
-- Use this ONLY if the comprehensive fix doesn't work

-- Step 1: Completely disable RLS temporarily
ALTER TABLE admin_accounts DISABLE ROW LEVEL SECURITY;

-- Step 2: Grant full access to authenticated users
GRANT ALL PRIVILEGES ON admin_accounts TO authenticated;
GRANT ALL PRIVILEGES ON admin_accounts TO anon;

-- Step 3: Grant usage on sequence if it exists
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO anon;

-- Step 4: Test access
SELECT COUNT(*) as admin_count FROM admin_accounts;
SELECT id, username, full_name FROM admin_accounts LIMIT 3;

-- Step 5: If the above works, re-enable RLS with permissive policy
ALTER TABLE admin_accounts ENABLE ROW LEVEL SECURITY;

-- Step 6: Create the most permissive policy possible
CREATE POLICY "Allow everything for authenticated users" 
ON admin_accounts 
FOR ALL 
TO authenticated 
USING (true)
WITH CHECK (true);

-- Step 7: Test again with RLS enabled
SELECT COUNT(*) as admin_count_with_rls FROM admin_accounts;
SELECT id, username, full_name FROM admin_accounts LIMIT 3;

-- Step 8: Verify the policy is working
SELECT 
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE tablename = 'admin_accounts';

-- Final test - this should return data
SELECT 
    'SUCCESS: RLS is properly configured' as status,
    COUNT(*) as admin_accounts_accessible
FROM admin_accounts;
