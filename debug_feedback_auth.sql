-- Debug feedback authentication issues
-- Run this to check the current state and fix issues

-- 1. Check if the feedback table exists and has RLS enabled
SELECT 
    schemaname, 
    tablename, 
    rowsecurity 
FROM pg_tables 
WHERE tablename = 'feedback';

-- 2. Check current policies on feedback table
SELECT 
    policyname, 
    permissive, 
    roles, 
    cmd, 
    qual, 
    with_check
FROM pg_policies 
WHERE tablename = 'feedback';

-- 3. Temporarily disable RLS to test if that's the issue
-- ALTER TABLE public.feedback DISABLE ROW LEVEL SECURITY;

-- 4. Or create a very simple policy that should work
DROP POLICY IF EXISTS "Allow authenticated feedback insert" ON public.feedback;
DROP POLICY IF EXISTS "Allow authenticated feedback select" ON public.feedback;
DROP POLICY IF EXISTS "Allow service account feedback insert" ON public.feedback;
DROP POLICY IF EXISTS "Allow user feedback insert" ON public.feedback;
DROP POLICY IF EXISTS "Allow service account feedback select" ON public.feedback;
DROP POLICY IF EXISTS "Allow user feedback select" ON public.feedback;

-- Create the simplest possible policy
CREATE POLICY "Simple feedback policy" ON public.feedback
    FOR ALL 
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- 5. Check if the user is properly authenticated
-- This will show the current authenticated user's JWT claims
SELECT 
    auth.uid() as user_id,
    auth.jwt() ->> 'username' as username,
    auth.jwt() ->> 'email' as email,
    auth.jwt() ->> 'role' as role;

-- 6. Test insert (run this after applying the simple policy)
-- INSERT INTO public.feedback (user_type, account_username, message) 
-- VALUES ('user', 'test_user', 'Test feedback message');

-- 7. If the above works, then make it more restrictive:
-- DROP POLICY IF EXISTS "Simple feedback policy" ON public.feedback;

-- CREATE POLICY "Restrictive feedback policy" ON public.feedback
--     FOR ALL 
--     TO authenticated
--     USING (true)
--     WITH CHECK (
--         user_type IN ('user', 'service_account') AND
--         account_username IS NOT NULL AND
--         message IS NOT NULL
--     );
