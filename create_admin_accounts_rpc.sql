-- Create RPC function to bypass RLS for admin accounts
-- This function will work even with strict RLS policies

-- Drop function if it exists
DROP FUNCTION IF EXISTS get_admin_accounts_with_scanners();

-- Create the RPC function with SECURITY DEFINER (runs with creator's privileges)
CREATE OR REPLACE FUNCTION get_admin_accounts_with_scanners()
RETURNS TABLE (
    id INTEGER,
    username TEXT,
    full_name TEXT,
    email TEXT,
    role TEXT,
    is_active BOOLEAN,
    scanner_id TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER -- This makes it run with the function creator's privileges
SET search_path = public
AS $$
BEGIN
    -- This function bypasses RLS because of SECURITY DEFINER
    RETURN QUERY
    SELECT 
        aa.id,
        aa.username,
        aa.full_name,
        aa.email,
        aa.role,
        aa.is_active,
        aa.scanner_id,
        aa.created_at,
        aa.updated_at
    FROM admin_accounts aa
    ORDER BY aa.full_name;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_admin_accounts_with_scanners() TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_accounts_with_scanners() TO anon;
GRANT EXECUTE ON FUNCTION get_admin_accounts_with_scanners() TO public;

-- Test the function
SELECT 'Testing RPC function' as test;
SELECT * FROM get_admin_accounts_with_scanners() LIMIT 3;

-- Create a simpler version that returns JSON
DROP FUNCTION IF EXISTS get_admin_accounts_simple();

CREATE OR REPLACE FUNCTION get_admin_accounts_simple()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_agg(
        json_build_object(
            'id', id,
            'username', username,
            'full_name', full_name,
            'email', email,
            'role', role,
            'is_active', is_active,
            'scanner_id', scanner_id,
            'created_at', created_at,
            'updated_at', updated_at
        )
    ) INTO result
    FROM admin_accounts
    ORDER BY full_name;
    
    RETURN COALESCE(result, '[]'::json);
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_admin_accounts_simple() TO authenticated;
GRANT EXECUTE ON FUNCTION get_admin_accounts_simple() TO anon;
GRANT EXECUTE ON FUNCTION get_admin_accounts_simple() TO public;

-- Test the simple function
SELECT 'Testing simple RPC function' as test;
SELECT get_admin_accounts_simple();

-- Verify functions exist
SELECT 
    'Created Functions' as info,
    routine_name,
    routine_type,
    security_type
FROM information_schema.routines 
WHERE routine_name IN ('get_admin_accounts_with_scanners', 'get_admin_accounts_simple')
AND routine_schema = 'public';
