# Top-up Service Troubleshooting Guide

This guide helps resolve issues where the top-up service shows "currently unavailable" even when the API configuration is enabled.

## Problem Symptoms

- Top-up button shows "Under Maintenance" modal
- API configuration shows `enabled = true` in database
- Students cannot access top-up functionality

## Root Causes & Solutions

### 1. RLS Policy Issues

**Problem**: Row Level Security policies are blocking student access to the `api_configuration` table.

**Solution**: Run the student access fix script:

```sql
-- Execute this in Supabase SQL editor
\i fix_api_configuration_student_access.sql
```

This script:

- Creates permissive policies for both `authenticated` and `anon` roles
- Allows students to read the `enabled` field
- Provides fallback access methods

### 2. Authentication Issues

**Problem**: Students are not properly authenticated or are using `anon` role instead of `authenticated`.

**Debug Steps**:

1. Check the debug logs in the app console
2. Look for messages like:
   ```
   DEBUG: Current user: null
   DEBUG: Auth state: not authenticated
   ```

**Solution**: Ensure students are properly logged in through the authentication system.

### 3. Database Connection Issues

**Problem**: The API configuration table doesn't exist or has no data.

**Check**: Run this query in Supabase SQL editor:

```sql
SELECT * FROM api_configuration;
```

**Solution**: If no data exists, insert default configuration:

```sql
INSERT INTO api_configuration (enabled, xpub_key, wallet_hash, webhook_url)
VALUES (true, 'your_xpub_key', 'your_wallet_hash', 'your_webhook_url');
```

## Debugging Steps

### Step 1: Check Debug Logs

The updated code now provides detailed debug information. Look for these messages in your app console:

```
DEBUG: _showTopUpDialog called
DEBUG: Checking Paytaca enabled status...
DEBUG: Current user: [user_id]
DEBUG: Auth state: authenticated/not authenticated
DEBUG: API configuration query response: [response]
DEBUG: Paytaca enabled status: true/false
```

### Step 2: Test Database Access

Run this test query in Supabase SQL editor:

```sql
-- Test if the table is accessible
SELECT enabled FROM api_configuration LIMIT 1;

-- Test with different roles
SET ROLE authenticated;
SELECT enabled FROM api_configuration LIMIT 1;

SET ROLE anon;
SELECT enabled FROM api_configuration LIMIT 1;
```

### Step 3: Check RLS Policies

Verify the policies exist and are working:

```sql
-- List all policies on api_configuration table
SELECT policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'api_configuration';
```

### Step 4: Verify Table Permissions

Check if roles have proper permissions:

```sql
-- Check table permissions
SELECT grantee, privilege_type
FROM information_schema.table_privileges
WHERE table_name = 'api_configuration';
```

## Updated Code Features

### Enhanced Debugging

The `isPaytacaEnabled()` method now includes:

- Detailed debug logging
- Fallback to admin client if regular client fails
- Better error reporting

### Dual Access Method

The system now tries two approaches:

1. **Primary**: Use regular client (for authenticated students)
2. **Fallback**: Use admin client (if regular client fails due to RLS)

## Quick Fix Commands

### 1. Reset RLS Policies

```sql
-- Drop all existing policies
DROP POLICY IF EXISTS api_config_service_role_policy ON api_configuration;
DROP POLICY IF EXISTS api_config_admin_policy ON api_configuration;
DROP POLICY IF EXISTS api_config_authenticated_read_policy ON api_configuration;
DROP POLICY IF EXISTS api_config_anon_policy ON api_configuration;
DROP POLICY IF EXISTS api_config_anon_read_policy ON api_configuration;
DROP POLICY IF EXISTS api_config_anon_select_policy ON api_configuration;

-- Recreate with proper permissions
\i fix_api_configuration_student_access.sql
```

### 2. Grant Permissions

```sql
-- Ensure all roles have SELECT permission
GRANT SELECT ON TABLE api_configuration TO authenticated;
GRANT SELECT ON TABLE api_configuration TO anon;
GRANT ALL ON TABLE api_configuration TO service_role;
```

### 3. Test Configuration

```sql
-- Verify configuration exists and is enabled
SELECT id, enabled,
       CASE WHEN xpub_key = '' THEN 'empty' ELSE 'configured' END as xpub_status,
       CASE WHEN wallet_hash = '' THEN 'empty' ELSE 'configured' END as wallet_status
FROM api_configuration;
```

## Expected Behavior After Fix

1. **Students can access top-up**: The top-up dialog should appear when `enabled = true`
2. **Debug logs show success**: Console should show "Paytaca enabled status: true"
3. **No maintenance modal**: Students should not see the maintenance modal when enabled

## Testing Checklist

- [ ] Run `fix_api_configuration_student_access.sql`
- [ ] Check debug logs in app console
- [ ] Verify `api_configuration.enabled = true` in database
- [ ] Test top-up button as a student user
- [ ] Confirm top-up dialog appears (not maintenance modal)
- [ ] Test with different user roles (student, admin)

## Common Error Messages

| Error                           | Cause                       | Solution                              |
| ------------------------------- | --------------------------- | ------------------------------------- |
| "Permission denied"             | RLS policy blocking access  | Run student access fix script         |
| "No API configuration found"    | Table empty or inaccessible | Insert configuration data             |
| "Auth state: not authenticated" | Student not logged in       | Ensure proper authentication          |
| "Regular client query failed"   | RLS issues                  | System will try admin client fallback |

## Files Modified

1. `lib/services/supabase_service.dart` - Enhanced `isPaytacaEnabled()` with debugging and fallback
2. `lib/user/user_dashboard.dart` - Added debug logging to `_showTopUpDialog()`
3. `fix_api_configuration_student_access.sql` - New script to fix student access issues

## Next Steps

1. **Deploy the fix**: Run the student access SQL script
2. **Test thoroughly**: Try top-up with student account
3. **Monitor logs**: Check debug output for any remaining issues
4. **Clean up**: Remove debug logs once everything works
