-- Feedback System Schema
-- Table for storing feedback from both users and service accounts

-- Create the feedback table
CREATE TABLE IF NOT EXISTS public.feedback (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('user', 'service_account')),
    account_username VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_feedback_user_type ON public.feedback(user_type);
CREATE INDEX IF NOT EXISTS idx_feedback_created_at ON public.feedback(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_feedback_username ON public.feedback(account_username);

-- Enable RLS
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to avoid conflicts)
DROP POLICY IF EXISTS "Service accounts can insert feedback" ON public.feedback;
DROP POLICY IF EXISTS "Users can insert feedback" ON public.feedback;
DROP POLICY IF EXISTS "Service accounts can view all feedback" ON public.feedback;
DROP POLICY IF EXISTS "Students can view own feedback" ON public.feedback;

-- RLS Policy: Allow service accounts to insert feedback
CREATE POLICY "Service accounts can insert feedback" ON public.feedback
    FOR INSERT 
    TO authenticated
    WITH CHECK (
        user_type = 'service_account'
    );

-- RLS Policy: Allow users to insert feedback
CREATE POLICY "Users can insert feedback" ON public.feedback
    FOR INSERT 
    TO authenticated
    WITH CHECK (
        user_type = 'user'
    );

-- RLS Policy: Allow service accounts to view all feedback (for admin purposes)
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

-- RLS Policy: Allow students to view their own feedback only
CREATE POLICY "Students can view own feedback" ON public.feedback
    FOR SELECT 
    TO authenticated
    USING (
        user_type = 'user' AND 
        account_username = auth.jwt() ->> 'username'
    );

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_feedback_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update updated_at
CREATE TRIGGER update_feedback_updated_at_trigger
    BEFORE UPDATE ON public.feedback
    FOR EACH ROW
    EXECUTE FUNCTION update_feedback_updated_at();

-- Grant necessary permissions
GRANT ALL ON public.feedback TO authenticated;
GRANT USAGE ON SCHEMA public TO authenticated;

-- Insert some sample data for testing (optional)
-- INSERT INTO public.feedback (user_type, account_username, message) VALUES
-- ('service_account', 'test_service', 'This is a test feedback from service account'),
-- ('user', 'test_student', 'This is a test feedback from student');

-- Note: This table integrates with:
-- - auth_students (for user feedback from students)
-- - service_accounts (for service account feedback)
-- Both tables should exist and have proper RLS policies for authentication
