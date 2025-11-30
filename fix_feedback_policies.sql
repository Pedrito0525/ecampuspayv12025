-- Fix feedback table RLS policies
-- This script updates the existing policies to allow feedback submission

-- Drop existing restrictive policies
DROP POLICY IF EXISTS "Service accounts can insert feedback" ON public.feedback;
DROP POLICY IF EXISTS "Users can insert feedback" ON public.feedback;
DROP POLICY IF EXISTS "Service accounts can view all feedback" ON public.feedback;
DROP POLICY IF EXISTS "Students can view own feedback" ON public.feedback;

-- Create new, less restrictive INSERT policies
-- Allow any authenticated user to insert feedback with proper user_type
CREATE POLICY "Allow feedback insert" ON public.feedback
    FOR INSERT 
    TO authenticated
    WITH CHECK (
        user_type IN ('user', 'service_account') AND
        account_username IS NOT NULL AND
        message IS NOT NULL AND
        message != ''
    );

-- Allow service accounts to view all feedback (for admin purposes)
CREATE POLICY "Service accounts can view all feedback" ON public.feedback
    FOR SELECT 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.service_accounts 
            WHERE username = auth.jwt() ->> 'username' 
            AND is_active = true
        )
    );

-- Allow students to view their own feedback only
CREATE POLICY "Students can view own feedback" ON public.feedback
    FOR SELECT 
    TO authenticated
    USING (
        user_type = 'user' AND 
        account_username = auth.jwt() ->> 'username'
    );

-- Grant necessary permissions
GRANT ALL ON public.feedback TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;
