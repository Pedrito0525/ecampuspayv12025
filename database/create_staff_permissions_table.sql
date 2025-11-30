-- =====================================================
-- STAFF PERMISSIONS TABLE
-- =====================================================
-- Stores tab permissions for admin staff accounts (moderator role)

-- =====================================================
-- 1. CREATE STAFF_PERMISSIONS TABLE
-- =====================================================
CREATE TABLE IF NOT EXISTS public.staff_permissions (
    id SERIAL PRIMARY KEY,
    staff_id INTEGER NOT NULL REFERENCES admin_accounts(id) ON DELETE CASCADE,
    dashboard BOOLEAN NOT NULL DEFAULT false,
    reports BOOLEAN NOT NULL DEFAULT false,
    transactions BOOLEAN NOT NULL DEFAULT false,
    topup BOOLEAN NOT NULL DEFAULT false,
    withdrawal_requests BOOLEAN NOT NULL DEFAULT false,
    settings BOOLEAN NOT NULL DEFAULT false,
    user_management BOOLEAN NOT NULL DEFAULT false,
    service_ports BOOLEAN NOT NULL DEFAULT false,
    admin_management BOOLEAN NOT NULL DEFAULT false,
    loaning BOOLEAN NOT NULL DEFAULT false,
    feedback BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Manila'),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Manila'),
    UNIQUE(staff_id)
);

-- =====================================================
-- 2. CREATE INDEXES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_staff_permissions_staff_id ON public.staff_permissions(staff_id);

-- =====================================================
-- 3. ENABLE ROW LEVEL SECURITY
-- =====================================================
ALTER TABLE public.staff_permissions ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- 4. CREATE RLS POLICIES
-- =====================================================
-- Policy for authenticated users (admins) to read and update permissions
DROP POLICY IF EXISTS "Allow authenticated read/update staff permissions" ON public.staff_permissions;
CREATE POLICY "Allow authenticated read/update staff permissions" ON public.staff_permissions
FOR ALL USING (auth.role() = 'authenticated') WITH CHECK (auth.role() = 'authenticated');

-- =====================================================
-- 5. CREATE FUNCTIONS
-- =====================================================

-- Function to get staff permissions
CREATE OR REPLACE FUNCTION public.get_staff_permissions(p_staff_id INTEGER)
RETURNS JSON AS $$
DECLARE
    permissions_data JSON;
BEGIN
    SELECT json_build_object(
        'id', id,
        'staff_id', staff_id,
        'dashboard', dashboard,
        'reports', reports,
        'transactions', transactions,
        'topup', topup,
        'withdrawal_requests', withdrawal_requests,
        'settings', settings,
        'user_management', user_management,
        'service_ports', service_ports,
        'admin_management', admin_management,
        'loaning', loaning,
        'feedback', feedback,
        'created_at', created_at,
        'updated_at', updated_at
    )
    INTO permissions_data
    FROM public.staff_permissions
    WHERE staff_id = p_staff_id;

    IF permissions_data IS NULL THEN
        -- Return default permissions (all false) if not found
        RETURN json_build_object(
            'id', NULL,
            'staff_id', p_staff_id,
            'dashboard', false,
            'reports', false,
            'transactions', false,
            'topup', false,
            'withdrawal_requests', false,
            'settings', false,
            'user_management', false,
            'service_ports', false,
            'admin_management', false,
            'loaning', false,
            'feedback', false,
            'created_at', NULL,
            'updated_at', NULL
        );
    END IF;

    RETURN json_build_object('success', true, 'data', permissions_data);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update staff permissions
CREATE OR REPLACE FUNCTION public.update_staff_permissions(
    p_staff_id INTEGER,
    p_dashboard BOOLEAN DEFAULT false,
    p_reports BOOLEAN DEFAULT false,
    p_transactions BOOLEAN DEFAULT false,
    p_topup BOOLEAN DEFAULT false,
    p_withdrawal_requests BOOLEAN DEFAULT false,
    p_settings BOOLEAN DEFAULT false,
    p_user_management BOOLEAN DEFAULT false,
    p_service_ports BOOLEAN DEFAULT false,
    p_admin_management BOOLEAN DEFAULT false,
    p_loaning BOOLEAN DEFAULT false,
    p_feedback BOOLEAN DEFAULT false
)
RETURNS JSON AS $$
DECLARE
    updated_permissions JSON;
BEGIN
    -- Use INSERT ... ON CONFLICT to handle both insert and update
    INSERT INTO public.staff_permissions (
        staff_id,
        dashboard,
        reports,
        transactions,
        topup,
        withdrawal_requests,
        settings,
        user_management,
        service_ports,
        admin_management,
        loaning,
        feedback,
        updated_at
    ) VALUES (
        p_staff_id,
        p_dashboard,
        p_reports,
        p_transactions,
        p_topup,
        p_withdrawal_requests,
        p_settings,
        p_user_management,
        p_service_ports,
        p_admin_management,
        p_loaning,
        p_feedback,
        (now() AT TIME ZONE 'Asia/Manila')
    )
    ON CONFLICT (staff_id) DO UPDATE SET
        dashboard = EXCLUDED.dashboard,
        reports = EXCLUDED.reports,
        transactions = EXCLUDED.transactions,
        topup = EXCLUDED.topup,
        withdrawal_requests = EXCLUDED.withdrawal_requests,
        settings = EXCLUDED.settings,
        user_management = EXCLUDED.user_management,
        service_ports = EXCLUDED.service_ports,
        admin_management = EXCLUDED.admin_management,
        loaning = EXCLUDED.loaning,
        feedback = EXCLUDED.feedback,
        updated_at = EXCLUDED.updated_at
    RETURNING json_build_object(
        'id', id,
        'staff_id', staff_id,
        'dashboard', dashboard,
        'reports', reports,
        'transactions', transactions,
        'topup', topup,
        'withdrawal_requests', withdrawal_requests,
        'settings', settings,
        'user_management', user_management,
        'service_ports', service_ports,
        'admin_management', admin_management,
        'loaning', loaning,
        'feedback', feedback,
        'updated_at', updated_at
    ) INTO updated_permissions;

    RETURN json_build_object(
        'success', true,
        'data', updated_permissions,
        'message', 'Staff permissions updated successfully'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get all staff permissions (for admin view)
CREATE OR REPLACE FUNCTION public.get_all_staff_permissions()
RETURNS JSON AS $$
DECLARE
    permissions_array JSON[];
    perm_record RECORD;
BEGIN
    permissions_array := ARRAY[]::JSON[];

    FOR perm_record IN
        SELECT 
            sp.*,
            aa.username,
            aa.full_name,
            aa.email
        FROM public.staff_permissions sp
        INNER JOIN public.admin_accounts aa ON sp.staff_id = aa.id
        WHERE aa.role = 'moderator'
        ORDER BY aa.full_name
    LOOP
        permissions_array := array_append(permissions_array, json_build_object(
            'id', perm_record.id,
            'staff_id', perm_record.staff_id,
            'username', perm_record.username,
            'full_name', perm_record.full_name,
            'email', perm_record.email,
            'dashboard', perm_record.dashboard,
            'reports', perm_record.reports,
            'transactions', perm_record.transactions,
            'topup', perm_record.topup,
            'withdrawal_requests', perm_record.withdrawal_requests,
            'settings', perm_record.settings,
            'user_management', perm_record.user_management,
            'service_ports', perm_record.service_ports,
            'admin_management', perm_record.admin_management,
            'loaning', perm_record.loaning,
            'feedback', perm_record.feedback,
            'updated_at', perm_record.updated_at
        ));
    END LOOP;

    RETURN json_build_object(
        'success', true,
        'data', permissions_array
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

