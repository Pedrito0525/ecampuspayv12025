-- Fix feedback table RLS policies - Version 2
-- More permissive approach to allow feedback submission

-- Drop ALL existing policies on feedback table
DROP POLICY IF EXISTS "Service accounts can insert feedback" ON public.feedback;
DROP POLICY IF EXISTS "Users can insert feedback" ON public.feedback;
DROP POLICY IF EXISTS "Service accounts can view all feedback" ON public.feedback;
DROP POLICY IF EXISTS "Students can view own feedback" ON public.feedback;
DROP POLICY IF EXISTS "Allow feedback insert" ON public.feedback;

-- Create a single, simple INSERT policy that allows any authenticated user
CREATE POLICY "Allow authenticated feedback insert" ON public.feedback
    FOR INSERT 
    TO authenticated
    WITH CHECK (true);

-- Create a simple SELECT policy that allows users to see all feedback
-- (We can make this more restrictive later if needed)
CREATE POLICY "Allow authenticated feedback select" ON public.feedback
    FOR SELECT 
    TO authenticated
    USING (true);

-- Alternative approach: Create separate policies for each user type
-- Uncomment these if you want more granular control:

-- CREATE POLICY "Allow service account feedback insert" ON public.feedback
--     FOR INSERT 
--     TO authenticated
--     WITH CHECK (user_type = 'service_account');

-- CREATE POLICY "Allow user feedback insert" ON public.feedback
--     FOR INSERT 
--     TO authenticated
--     WITH CHECK (user_type = 'user');

-- CREATE POLICY "Allow service account feedback select" ON public.feedback
--     FOR SELECT 
--     TO authenticated
--     USING (
--         user_type = 'service_account' OR
--         EXISTS (
--             SELECT 1 FROM public.service_accounts 
--             WHERE username = auth.jwt() ->> 'username' 
--             AND is_active = true
--         )
--     );

-- CREATE POLICY "Allow user feedback select" ON public.feedback
--     FOR SELECT 
--     TO authenticated
--     USING (user_type = 'user');

-- Grant permissions
GRANT ALL ON public.feedback TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Test the policies
-- You can run this to verify the policies work:
-- INSERT INTO public.feedback (user_type, account_username, message) 
-- VALUES ('user', 'test_user', 'Test feedback message');
