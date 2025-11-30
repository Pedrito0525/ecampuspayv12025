-- Loan System Database Schema
-- This file creates the necessary tables and functions for the loan management system

-- 1. Loan Plans Table (Admin-defined loan products)
CREATE TABLE IF NOT EXISTS loan_plans (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    amount DECIMAL(10,2) NOT NULL CHECK (amount > 0),
    term_days INTEGER NOT NULL CHECK (term_days > 0),
    interest_rate DECIMAL(5,2) NOT NULL CHECK (interest_rate >= 0),
    penalty_rate DECIMAL(5,2) NOT NULL CHECK (penalty_rate >= 0),
    min_topup DECIMAL(10,2) NOT NULL CHECK (min_topup >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Active Loans Table (Student loan applications and status)
CREATE TABLE IF NOT EXISTS active_loans (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL,
    loan_plan_id INTEGER NOT NULL REFERENCES loan_plans(id),
    loan_amount DECIMAL(10,2) NOT NULL,
    interest_amount DECIMAL(10,2) NOT NULL,
    penalty_amount DECIMAL(10,2) DEFAULT 0,
    total_amount DECIMAL(10,2) NOT NULL,
    term_days INTEGER NOT NULL,
    due_date TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paid', 'overdue')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    paid_at TIMESTAMP WITH TIME ZONE NULL
);

-- 3. Loan Payments Table (Track loan payments)
CREATE TABLE IF NOT EXISTS loan_payments (
    id SERIAL PRIMARY KEY,
    loan_id INTEGER NOT NULL REFERENCES active_loans(id),
    student_id VARCHAR(50) NOT NULL,
    payment_amount DECIMAL(10,2) NOT NULL,
    payment_type VARCHAR(20) NOT NULL DEFAULT 'full' CHECK (payment_type IN ('full', 'partial')),
    remaining_balance DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_active_loans_student_id ON active_loans(student_id);
CREATE INDEX IF NOT EXISTS idx_active_loans_status ON active_loans(status);
CREATE INDEX IF NOT EXISTS idx_active_loans_due_date ON active_loans(due_date);
CREATE INDEX IF NOT EXISTS idx_loan_plans_status ON loan_plans(status);
CREATE INDEX IF NOT EXISTS idx_loan_payments_loan_id ON loan_payments(loan_id);

-- 5. Function to check student loan eligibility
CREATE OR REPLACE FUNCTION check_loan_eligibility(p_student_id VARCHAR(50))
RETURNS JSON AS $$
DECLARE
    total_topup DECIMAL(10,2);
    active_loan_count INTEGER;
    result JSON;
BEGIN
    -- Get total top-up amount for student
    SELECT COALESCE(SUM(amount), 0) INTO total_topup
    FROM top_up_transactions 
    WHERE student_id = p_student_id;
    
    -- Check if student has any active unpaid loans
    SELECT COUNT(*) INTO active_loan_count
    FROM active_loans 
    WHERE student_id = p_student_id 
    AND status = 'active';
    
    -- Build result
    result := json_build_object(
        'student_id', p_student_id,
        'total_topup', total_topup,
        'has_active_loan', active_loan_count > 0,
        'active_loan_count', active_loan_count,
        'is_eligible', active_loan_count = 0
    );
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. Function to get available loan plans for student
CREATE OR REPLACE FUNCTION get_available_loan_plans(p_student_id VARCHAR(50))
RETURNS JSON AS $$
DECLARE
    total_topup DECIMAL(10,2);
    plans JSON;
BEGIN
    -- Get student's total top-up amount
    SELECT COALESCE(SUM(amount), 0) INTO total_topup
    FROM top_up_transactions 
    WHERE student_id = p_student_id;
    
    -- Get loan plans that student is eligible for using a subquery to avoid GROUP BY issues
    WITH loan_plans_with_eligibility AS (
        SELECT 
            lp.id,
            lp.name,
            lp.amount,
            lp.term_days,
            lp.interest_rate,
            lp.penalty_rate,
            lp.min_topup,
            (lp.amount + (lp.amount * lp.interest_rate / 100)) as total_repayable,
            (total_topup >= lp.min_topup) as is_eligible
        FROM loan_plans lp
        WHERE lp.status = 'active'
        ORDER BY lp.amount ASC
    )
    SELECT json_agg(
        json_build_object(
            'id', id,
            'name', name,
            'amount', amount,
            'term_days', term_days,
            'interest_rate', interest_rate,
            'penalty_rate', penalty_rate,
            'min_topup', min_topup,
            'total_repayable', total_repayable,
            'is_eligible', is_eligible
        )
    ) INTO plans
    FROM loan_plans_with_eligibility;
    
    RETURN json_build_object(
        'student_id', p_student_id,
        'total_topup', total_topup,
        'available_plans', COALESCE(plans, '[]'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. Function to apply for a loan
CREATE OR REPLACE FUNCTION apply_for_loan(
    p_student_id VARCHAR(50),
    p_loan_plan_id INTEGER
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
    
    -- Check eligibility
    SELECT COALESCE(SUM(amount), 0) INTO total_topup
    FROM top_up_transactions 
    WHERE student_id = p_student_id;
    
    IF total_topup < plan_record.min_topup THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Insufficient top-up',
            'message', 'You need at least ₱' || plan_record.min_topup || ' in total top-ups to apply for this loan'
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
    
    RETURN json_build_object(
        'success', true,
        'message', 'Loan applied successfully',
        'loan_id', new_loan_id,
        'loan_amount', plan_record.amount,
        'total_amount', total_amount,
        'due_date', due_date
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Function to pay off a loan
CREATE OR REPLACE FUNCTION pay_off_loan(
    p_loan_id INTEGER,
    p_student_id VARCHAR(50)
)
RETURNS JSON AS $$
DECLARE
    loan_record RECORD;
    current_balance DECIMAL(10,2);
    payment_amount DECIMAL(10,2);
    result JSON;
BEGIN
    -- Get loan details
    SELECT * INTO loan_record
    FROM active_loans 
    WHERE id = p_loan_id AND student_id = p_student_id AND status = 'active';
    
    IF NOT FOUND THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Loan not found',
            'message', 'Loan not found or already paid'
        );
    END IF;
    
    -- Check if student has sufficient balance
    SELECT balance INTO current_balance
    FROM auth_students 
    WHERE student_id = p_student_id;
    
    IF current_balance < loan_record.total_amount THEN
        RETURN json_build_object(
            'success', false,
            'error', 'Insufficient balance',
            'message', 'You need ₱' || loan_record.total_amount || ' to pay off this loan'
        );
    END IF;
    
    -- Deduct loan amount from student balance
    UPDATE auth_students 
    SET balance = balance - loan_record.total_amount,
        updated_at = NOW()
    WHERE student_id = p_student_id;
    
    -- Mark loan as paid
    UPDATE active_loans 
    SET status = 'paid',
        paid_at = NOW(),
        updated_at = NOW()
    WHERE id = p_loan_id;
    
    -- Record payment
    INSERT INTO loan_payments (
        loan_id, student_id, payment_amount, payment_type, remaining_balance
    ) VALUES (
        p_loan_id, p_student_id, loan_record.total_amount, 'full', 0
    );
    
    RETURN json_build_object(
        'success', true,
        'message', 'Loan paid successfully',
        'loan_id', p_loan_id,
        'amount_paid', loan_record.total_amount
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 9. Function to get student's loan history
CREATE OR REPLACE FUNCTION get_student_loans(p_student_id VARCHAR(50))
RETURNS JSON AS $$
DECLARE
    loans JSON;
BEGIN
    SELECT json_agg(
        json_build_object(
            'id', al.id,
            'loan_plan_name', lp.name,
            'loan_amount', al.loan_amount,
            'interest_amount', al.interest_amount,
            'penalty_amount', al.penalty_amount,
            'total_amount', al.total_amount,
            'term_days', al.term_days,
            'due_date', al.due_date,
            'status', al.status,
            'created_at', al.created_at,
            'paid_at', al.paid_at,
            'days_left', CASE 
                WHEN al.status = 'paid' THEN 0
                WHEN al.due_date < NOW() THEN EXTRACT(DAY FROM NOW() - al.due_date)::INTEGER
                ELSE EXTRACT(DAY FROM al.due_date - NOW())::INTEGER
            END
        )
    ) INTO loans
    FROM active_loans al
    JOIN loan_plans lp ON al.loan_plan_id = lp.id
    WHERE al.student_id = p_student_id
    ORDER BY al.created_at DESC;
    
    RETURN json_build_object(
        'student_id', p_student_id,
        'loans', COALESCE(loans, '[]'::json)
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 10. Function to update loan statuses (mark overdue loans)
CREATE OR REPLACE FUNCTION update_loan_statuses()
RETURNS INTEGER AS $$
DECLARE
    updated_count INTEGER;
BEGIN
    -- Mark overdue loans
    UPDATE active_loans 
    SET status = 'overdue',
        updated_at = NOW()
    WHERE status = 'active' 
    AND due_date < NOW();
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    RETURN updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 11. Grant permissions
GRANT EXECUTE ON FUNCTION check_loan_eligibility(VARCHAR) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_available_loan_plans(VARCHAR) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION apply_for_loan(VARCHAR, INTEGER) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION pay_off_loan(INTEGER, VARCHAR) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_student_loans(VARCHAR) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION update_loan_statuses() TO authenticated, service_role;

-- 12. Insert sample loan plans
INSERT INTO loan_plans (name, amount, term_days, interest_rate, penalty_rate, min_topup, status) VALUES
('Quick Cash - ₱500', 500.00, 7, 1.5, 0.5, 300.00, 'active'),
('Standard Loan - ₱1000', 1000.00, 14, 2.0, 0.5, 600.00, 'active'),
('Extended Loan - ₱1500', 1500.00, 21, 2.5, 0.5, 1000.00, 'active'),
('Premium Loan - ₱2000', 2000.00, 30, 3.0, 0.5, 1500.00, 'active')
ON CONFLICT DO NOTHING;

-- 13. Create RLS policies
ALTER TABLE loan_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE active_loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE loan_payments ENABLE ROW LEVEL SECURITY;

-- Allow all authenticated users to read loan plans
CREATE POLICY "Allow read loan_plans" ON loan_plans FOR SELECT TO authenticated USING (true);

-- Allow all authenticated users to manage loan plans (since only admins access admin panel)
CREATE POLICY "Allow manage loan_plans" ON loan_plans FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Allow students to read their own loans
CREATE POLICY "Students can read own loans" ON active_loans FOR SELECT TO authenticated 
USING (student_id IN (SELECT student_id FROM auth_students WHERE auth_user_id = auth.uid()));

-- Allow all authenticated users to manage active loans (since only admins access admin panel)
CREATE POLICY "Allow manage active_loans" ON active_loans FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Allow students to read their own payments
CREATE POLICY "Students can read own payments" ON loan_payments FOR SELECT TO authenticated 
USING (student_id IN (SELECT student_id FROM auth_students WHERE auth_user_id = auth.uid()));

-- Allow all authenticated users to manage loan payments (since only admins access admin panel)
CREATE POLICY "Allow manage loan_payments" ON loan_payments FOR ALL TO authenticated USING (true) WITH CHECK (true);

-- Allow service role full access
CREATE POLICY "Service role full access loan_plans" ON loan_plans FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access active_loans" ON active_loans FOR ALL TO service_role USING (true) WITH CHECK (true);
CREATE POLICY "Service role full access loan_payments" ON loan_payments FOR ALL TO service_role USING (true) WITH CHECK (true);
