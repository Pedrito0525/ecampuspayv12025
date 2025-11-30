-- Fix feedback table RLS policies - Allow unauthenticated access
-- This allows feedback submission even without authentication

-- Drop ALL existing policies on feedback table
DROP POLICY IF EXISTS "Service accounts can insert feedback" ON public.feedback;
DROP POLICY IF EXISTS "Users can insert feedback" ON public.feedback;
DROP POLICY IF EXISTS "Service accounts can view all feedback" ON public.feedback;
DROP POLICY IF EXISTS "Students can view own feedback" ON public.feedback;
DROP POLICY IF EXISTS "Allow feedback insert" ON public.feedback;
DROP POLICY IF EXISTS "Allow authenticated feedback insert" ON public.feedback;
DROP POLICY IF EXISTS "Allow authenticated feedback select" ON public.feedback;
DROP POLICY IF EXISTS "Simple feedback policy" ON public.feedback;
DROP POLICY IF EXISTS "Restrictive feedback policy" ON public.feedback;

-- Create a policy that allows ANYONE to insert feedback (even unauthenticated)
CREATE POLICY "Allow anyone to insert feedback" ON public.feedback
    FOR INSERT 
    TO public
    WITH CHECK (
        user_type IN ('user', 'service_account') AND
        account_username IS NOT NULL AND
        message IS NOT NULL AND
        message != ''
    );

-- Create a policy that allows anyone to select feedback
CREATE POLICY "Allow anyone to view feedback" ON public.feedback
    FOR SELECT 
    TO public
    USING (true);

-- Grant permissions to public role (allows unauthenticated access)
GRANT ALL ON public.feedback TO public;
GRANT ALL ON public.feedback TO authenticated;
GRANT USAGE ON SCHEMA public TO public;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Test the policies
-- You can run this to verify the policies work:
-- INSERT INTO public.feedback (user_type, account_username, message) 
-- VALUES ('user', 'test_user', 'Test feedback message');

-- If you want to be more restrictive later, you can replace the above with:
-- CREATE POLICY "Allow authenticated users to insert feedback" ON public.feedback
--     FOR INSERT 
--     TO authenticated
--     WITH CHECK (
--         user_type IN ('user', 'service_account') AND
--         account_username IS NOT NULL AND
--         message IS NOT NULL AND
--         message != ''
--     );
