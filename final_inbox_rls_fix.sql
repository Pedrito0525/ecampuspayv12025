-- Final fix for inbox RLS policies - allows all operations
-- This completely removes restrictions to ensure notifications work

-- 1. Drop ALL existing policies
DROP POLICY IF EXISTS "Users can view their own notifications" ON user_notifications;
DROP POLICY IF EXISTS "Users can insert their own notifications" ON user_notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON user_notifications;
DROP POLICY IF EXISTS "Service role full access" ON user_notifications;
DROP POLICY IF EXISTS "authenticated_view_all_notifications" ON user_notifications;
DROP POLICY IF EXISTS "authenticated_insert_all_notifications" ON user_notifications;
DROP POLICY IF EXISTS "authenticated_update_all_notifications" ON user_notifications;
DROP POLICY IF EXISTS "service_role_full_access_notifications" ON user_notifications;
DROP POLICY IF EXISTS "anon_insert_notifications" ON user_notifications;
DROP POLICY IF EXISTS "view_all_notifications" ON user_notifications;
DROP POLICY IF EXISTS "insert_all_notifications" ON user_notifications;
DROP POLICY IF EXISTS "update_all_notifications" ON user_notifications;
DROP POLICY IF EXISTS "service_role_full_access" ON user_notifications;
DROP POLICY IF EXISTS "anon_insert_all" ON user_notifications;

-- 2. Disable RLS temporarily
ALTER TABLE user_notifications DISABLE ROW LEVEL SECURITY;

-- 3. Grant full permissions to all roles
GRANT ALL ON user_notifications TO service_role;
GRANT ALL ON user_notifications TO authenticated;
GRANT ALL ON user_notifications TO anon;

-- 4. Re-enable RLS but with NO policies (completely open)
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

-- 5. Create completely open policies that allow everything
CREATE POLICY "open_select_policy" ON user_notifications FOR SELECT USING (true);
CREATE POLICY "open_insert_policy" ON user_notifications FOR INSERT WITH CHECK (true);
CREATE POLICY "open_update_policy" ON user_notifications FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "open_delete_policy" ON user_notifications FOR DELETE USING (true);

-- 6. Verify the fix worked
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd
FROM pg_policies 
WHERE tablename = 'user_notifications'
ORDER BY policyname;

-- 7. Test insert (replace 'TEST_STUDENT_ID' with actual student ID)
-- INSERT INTO user_notifications (student_id, type, title, message, is_read) 
-- VALUES ('TEST_STUDENT_ID', 'test', 'Test Notification', 'This should work now', false);
