-- Loan Applications Table with OCR Auto-Checking
-- This table stores loan applications with OCR-extracted enrollment data
--
-- IMPORTANT: Before running this script, ensure you have created a Supabase Storage bucket
-- named 'loan_proof_image' in your Supabase dashboard (Storage section).
-- The bucket should be set to Public or have appropriate RLS policies configured.

CREATE TABLE IF NOT EXISTS loan_applications (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL,
    loan_plan_id INTEGER NOT NULL REFERENCES loan_plans(id),
    
    -- OCR Extracted Data
    ocr_name VARCHAR(255),
    ocr_status VARCHAR(100),
    ocr_academic_year VARCHAR(50),
    ocr_semester VARCHAR(50),
    ocr_subjects TEXT, -- JSON array or comma-separated list
    ocr_date VARCHAR(50),
    ocr_confidence DECIMAL(5,2),
    ocr_raw_text TEXT, -- Full OCR text for debugging
    
    -- Uploaded Image
    upload_image_url TEXT, -- URL to Supabase storage bucket
    
    -- Auto-Check Results
    decision VARCHAR(20) NOT NULL CHECK (decision IN ('pending', 'approved', 'rejected')),
    rejection_reason TEXT,
    
    -- System Fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_loan_applications_student_id ON loan_applications(student_id);
CREATE INDEX IF NOT EXISTS idx_loan_applications_loan_plan_id ON loan_applications(loan_plan_id);
CREATE INDEX IF NOT EXISTS idx_loan_applications_decision ON loan_applications(decision);
CREATE INDEX IF NOT EXISTS idx_loan_applications_created_at ON loan_applications(created_at);

-- Enable RLS
ALTER TABLE loan_applications ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Students can read their own loan applications
-- Note: This policy allows authenticated users to read applications where student_id exists in auth_students
CREATE POLICY "Students can read own loan applications" ON loan_applications 
FOR SELECT TO authenticated 
USING (
  -- Allow if student_id exists in auth_students table
  EXISTS (
    SELECT 1 FROM auth_students 
    WHERE auth_students.student_id = loan_applications.student_id
  )
);

-- Students can insert their own loan applications
-- Note: This policy allows authenticated users to insert applications where student_id exists in auth_students
CREATE POLICY "Students can insert own loan applications" ON loan_applications 
FOR INSERT TO authenticated 
WITH CHECK (
  -- Allow if student_id exists in auth_students table
  EXISTS (
    SELECT 1 FROM auth_students 
    WHERE auth_students.student_id = loan_applications.student_id
  )
);

-- Admins can read all loan applications (via service_role or authenticated with admin check)
-- Note: Adjust this policy based on your admin_accounts table structure
CREATE POLICY "Admins can read all loan applications" ON loan_applications 
FOR SELECT TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM admin_accounts 
        WHERE is_active = true
        -- If admin_accounts has auth_user_id, uncomment the line below:
        -- AND auth_user_id = auth.uid()
    )
);

-- Service role has full access
CREATE POLICY "Service role full access loan_applications" ON loan_applications 
FOR ALL TO service_role 
USING (true) WITH CHECK (true);

-- Function to get current academic year and semester from system settings
-- This assumes you have a system_settings table, or you can modify to use a different source
CREATE OR REPLACE FUNCTION get_current_academic_year_semester()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    -- Try to get from system_settings table if it exists
    -- Otherwise, return default values (you may need to adjust this based on your system)
    BEGIN
        SELECT json_build_object(
            'academic_year', COALESCE((SELECT value FROM system_settings WHERE key = 'current_academic_year'), '2024-2025'),
            'semester', COALESCE((SELECT value FROM system_settings WHERE key = 'current_semester'), '1st Semester')
        ) INTO result;
    EXCEPTION WHEN OTHERS THEN
        -- Fallback if system_settings doesn't exist
        result := json_build_object(
            'academic_year', '2024-2025',
            'semester', '1st Semester'
        );
    END;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_current_academic_year_semester() TO authenticated, service_role;

-- Function to apply for loan with auto-approval (for approved OCR applications)
CREATE OR REPLACE FUNCTION apply_for_loan_with_auto_approval(
    p_student_id VARCHAR(50),
    p_loan_plan_id INTEGER,
    p_application_id INTEGER DEFAULT NULL
)
RETURNS JSON AS $$
DECLARE
    plan_record RECORD;
    total_topup DECIMAL(10,2);
    active_loan_count INTEGER;
    new_loan_id INTEGER;
    due_date TIMESTAMP WITH TIME ZONE;
    interest_amount DECIMAL(10,2);
    total_amount DECIMAL(10,2);
    result JSON;
BEGIN
    -- Check if student exists
    IF NOT EXISTS (SELECT 1 FROM auth_students WHERE student_id = p_student_id) THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Student not found',
            'message', 'Student ID does not exist'
        );
    END IF;
    
    -- Get loan plan details
    SELECT * INTO plan_record
    FROM loan_plans 
    WHERE id = p_loan_plan_id AND status = 'active';
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Loan plan not found',
            'message', 'Selected loan plan is not available'
        );
    END IF;
    
    -- Check if student has active loans
    SELECT COUNT(*) INTO active_loan_count
    FROM active_loans 
    WHERE student_id = p_student_id AND status = 'active';
    
    IF active_loan_count > 0 THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Active loan exists',
            'message', 'You already have an active loan. Please pay it off first.'
        );
    END IF;
    
    -- Calculate loan details
    interest_amount := plan_record.amount * plan_record.interest_rate / 100;
    total_amount := plan_record.amount + interest_amount;
    due_date := NOW() + (plan_record.term_days || ' days')::INTERVAL;
    
    -- Create the loan
    INSERT INTO active_loans (
        student_id, loan_plan_id, loan_amount, interest_amount, 
        penalty_amount, total_amount, term_days, due_date, status
    ) VALUES (
        p_student_id, p_loan_plan_id, plan_record.amount, interest_amount,
        0, total_amount, plan_record.term_days, due_date, 'active'
    ) RETURNING id INTO new_loan_id;
    
    -- Add loan amount to student balance
    UPDATE auth_students 
    SET balance = balance + plan_record.amount,
        updated_at = NOW()
    WHERE student_id = p_student_id;
    
    -- Update loan application status if application_id provided
    IF p_application_id IS NOT NULL THEN
        UPDATE loan_applications
        SET decision = 'approved',
            updated_at = NOW()
        WHERE id = p_application_id;
    END IF;
    
    RETURN json_build_object(
        'success', true,
        'message', 'Loan applied and approved successfully',
        'loan_id', new_loan_id,
        'loan_amount', plan_record.amount,
        'total_amount', total_amount,
        'due_date', due_date
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION apply_for_loan_with_auto_approval(VARCHAR, INTEGER, INTEGER) TO authenticated, service_role;

-- ============================================================================
-- Storage Policies for "loan_proof_image" Bucket
-- ============================================================================
-- IMPORTANT: Before running these policies, ensure the bucket "loan_proof_image" 
-- exists in Supabase Storage (Dashboard → Storage → Create bucket)

-- Policy 1: Allow authenticated students to INSERT (upload) files to loan_proof_image bucket
-- This allows any authenticated user to upload (simpler and more reliable)
-- Drop policy if it exists first
DROP POLICY IF EXISTS "Students can upload loan proof images" ON storage.objects;
CREATE POLICY "Students can upload loan proof images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'loan_proof_image');

-- Policy 2: Allow authenticated students to SELECT (view) files from loan_proof_image bucket
-- This allows any authenticated user to view (simpler and more reliable)
DROP POLICY IF EXISTS "Students can view loan proof images" ON storage.objects;
CREATE POLICY "Students can view loan proof images"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'loan_proof_image');

-- Policy 3: Allow admins to SELECT (view) all files in loan_proof_image bucket
DROP POLICY IF EXISTS "Admins can view all loan proof images" ON storage.objects;
CREATE POLICY "Admins can view all loan proof images"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'loan_proof_image'
  AND EXISTS (
    SELECT 1 FROM admin_accounts 
    WHERE is_active = true
    -- If admin_accounts has auth_user_id, uncomment the line below:
    -- AND auth_user_id = auth.uid()
  )
);

-- Policy 4: Service role has full access
DROP POLICY IF EXISTS "Service role full access loan_proof_image" ON storage.objects;
CREATE POLICY "Service role full access loan_proof_image"
ON storage.objects
FOR ALL
TO service_role
USING (bucket_id = 'loan_proof_image')
WITH CHECK (bucket_id = 'loan_proof_image');

-- ============================================================================
-- ALTERNATIVE: Simple Policies (if the above don't work)
-- ============================================================================
-- If the above policies are too restrictive, use these simpler ones:
-- These allow any authenticated user to upload/view files in the bucket

/*
-- Drop existing policies first if needed
DROP POLICY IF EXISTS "Students can upload loan proof images" ON storage.objects;
DROP POLICY IF EXISTS "Students can view loan proof images" ON storage.objects;
DROP POLICY IF EXISTS "Admins can view all loan proof images" ON storage.objects;
DROP POLICY IF EXISTS "Service role full access loan_proof_image" ON storage.objects;

-- Simple INSERT policy (any authenticated user can upload)
CREATE POLICY "Allow authenticated uploads to loan_proof_image"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'loan_proof_image');

-- Simple SELECT policy (any authenticated user can view)
CREATE POLICY "Allow authenticated reads from loan_proof_image"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'loan_proof_image');
*/
