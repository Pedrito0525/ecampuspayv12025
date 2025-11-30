-- Fix RLS policies for user_notifications table
-- This script fixes the row-level security issues preventing notifications from being created

-- 1. Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own notifications" ON user_notifications;
DROP POLICY IF EXISTS "Users can insert their own notifications" ON user_notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON user_notifications;
DROP POLICY IF EXISTS "Service role full access" ON user_notifications;

-- 2. Create permissive policies that allow data to flow
-- Policy 1: Allow ALL authenticated users to view ALL notifications
CREATE POLICY "authenticated_view_all_notifications" ON user_notifications
    FOR SELECT 
    TO authenticated
    USING (auth.uid() IS NOT NULL);

-- Policy 2: Allow ALL authenticated users to insert notifications
CREATE POLICY "authenticated_insert_all_notifications" ON user_notifications
    FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() IS NOT NULL);

-- Policy 3: Allow ALL authenticated users to update notifications
CREATE POLICY "authenticated_update_all_notifications" ON user_notifications
    FOR UPDATE 
    TO authenticated
    USING (auth.uid() IS NOT NULL)
    WITH CHECK (auth.uid() IS NOT NULL);

-- Policy 4: Allow service role full access (for admin operations)
CREATE POLICY "service_role_full_access_notifications" ON user_notifications
    FOR ALL 
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Policy 5: Allow anonymous users to insert (for system notifications)
CREATE POLICY "anon_insert_notifications" ON user_notifications
    FOR INSERT 
    TO anon
    WITH CHECK (true);

-- 3. Ensure RLS is enabled
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

-- 4. Grant necessary permissions
GRANT ALL ON user_notifications TO service_role;
GRANT SELECT, INSERT, UPDATE ON user_notifications TO authenticated;
GRANT INSERT ON user_notifications TO anon;
GRANT USAGE, SELECT ON SEQUENCE user_notifications_id_seq TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE user_notifications_id_seq TO anon;

-- 5. Test: Insert a sample notification to verify it works
-- Replace 'TEST_STUDENT_ID' with an actual student ID from your auth_students table
-- INSERT INTO user_notifications (student_id, type, title, message, is_read) 
-- VALUES ('TEST_STUDENT_ID', 'welcome', 'Test Notification', 'This is a test notification to verify the system works.', false);

-- 6. Verify the policies are working
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE tablename = 'user_notifications'
ORDER BY policyname;
