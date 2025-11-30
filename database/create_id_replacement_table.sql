-- Create id_replacement table to track RFID card replacements
CREATE TABLE IF NOT EXISTS public.id_replacement (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL,
    student_name VARCHAR(255) NOT NULL,
    old_rfid_id VARCHAR(255),
    new_rfid_id VARCHAR(255) NOT NULL,
    issue_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on student_id for faster queries
CREATE INDEX IF NOT EXISTS idx_id_replacement_student_id ON public.id_replacement(student_id);

-- Create index on issue_date for sorting recent replacements
CREATE INDEX IF NOT EXISTS idx_id_replacement_issue_date ON public.id_replacement(issue_date DESC);

-- Enable Row Level Security
ALTER TABLE public.id_replacement ENABLE ROW LEVEL SECURITY;

-- Policy: Allow service_role (admin) FULL ACCESS
DROP POLICY IF EXISTS "service_role_full_access" ON public.id_replacement;
CREATE POLICY "service_role_full_access"
    ON public.id_replacement
    FOR ALL
    TO service_role
    USING (true)
    WITH CHECK (true);

-- Policy: Allow admins to read all id_replacement records
DROP POLICY IF EXISTS "Allow admins to read id_replacement" ON public.id_replacement;
CREATE POLICY "Allow admins to read id_replacement" ON public.id_replacement
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.admin_accounts
            WHERE public.admin_accounts.email = (SELECT email FROM auth.users WHERE id = auth.uid())
        )
    );

-- Policy: Allow admins to insert id_replacement records
DROP POLICY IF EXISTS "Allow admins to insert id_replacement" ON public.id_replacement;
CREATE POLICY "Allow admins to insert id_replacement" ON public.id_replacement
    FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.admin_accounts
            WHERE public.admin_accounts.email = (SELECT email FROM auth.users WHERE id = auth.uid())
        )
    );

-- Grant full access to service_role (admin operations)
GRANT ALL ON public.id_replacement TO service_role;

-- Add comment to table
COMMENT ON TABLE public.id_replacement IS 'Tracks RFID card replacements with old and new RFID IDs, student info, and issue date';

