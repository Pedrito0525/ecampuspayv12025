# API Configuration RLS Fix

This document explains the fixes applied to enable proper admin access to the API configuration table with Row Level Security (RLS) policies.

## Problem

The API configuration screen was failing because:

1. The `api_configuration` table had RLS enabled but no proper policies
2. Admin users couldn't access the table for CRUD operations
3. The SupabaseService methods were using the regular client instead of admin client

## Solution

### 1. Database RLS Policies

Created comprehensive RLS policies in `fix_api_configuration_rls.sql`:

- **Service Role Policy**: Full access for system operations
- **Admin Policy**: Full access for authenticated admin users via JWT tokens
- **Authenticated Read Policy**: Read-only access for regular users (students)
- **Anonymous Policy**: No access for anonymous users

### 2. Updated SupabaseService Methods

Modified the following methods in `supabase_service.dart`:

#### `getApiConfiguration()`

- Now uses `adminClient` to bypass RLS for admin operations
- Allows admin users to fetch complete API configuration

#### `saveApiConfiguration()`

- Now uses `adminClient` to bypass RLS for admin operations
- Allows admin users to insert/update API configuration

#### `isPaytacaEnabled()`

- Still uses regular `client` (correct behavior)
- Allows students to check if Paytaca is enabled

## Database Setup

### 1. Run the RLS Fix Script

Execute the SQL script to create proper policies:

```sql
-- Run this in your Supabase SQL editor
\i fix_api_configuration_rls.sql
```

### 2. Verify Policies

Check that policies are created correctly:

```sql
-- List all policies on api_configuration table
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'api_configuration';
```

## Admin Authentication

The system supports admin access through JWT tokens in two ways:

### Method 1: Role-based JWT

```json
{
  "role": "admin",
  "username": "admin_username"
}
```

### Method 2: Admin Account Verification

The system checks if the username in the JWT exists in the `admin_accounts` table and is active.

## Usage

### For Admin Users

- Admin users can now access the API Configuration screen
- Full CRUD operations are available (Create, Read, Update, Delete)
- All API configuration fields are accessible

### For Students

- Students can only check if Paytaca is enabled via `isPaytacaEnabled()`
- No access to sensitive API keys or configuration details

## Security Features

1. **RLS Protection**: Row Level Security prevents unauthorized access
2. **Admin Client**: Uses service key for admin operations (bypasses RLS)
3. **JWT Verification**: Validates admin credentials through JWT tokens
4. **Role-based Access**: Different permissions for different user types

## Testing

### 1. Test Admin Access

1. Login as admin user
2. Navigate to API Configuration screen
3. Verify you can:
   - View current configuration
   - Update configuration
   - Save changes
   - Reset configuration

### 2. Test Student Access

1. Login as student user
2. Navigate to top-up functionality
3. Verify you can check if Paytaca is enabled
4. Verify you cannot access admin configuration

### 3. Test Database Policies

```sql
-- Test admin access (should work)
SELECT * FROM api_configuration;

-- Test as student (should only see enabled field)
SET ROLE authenticated;
SELECT enabled FROM api_configuration;
```

## Troubleshooting

### Common Issues

1. **"Permission denied" errors**

   - Ensure RLS policies are properly created
   - Verify admin user has correct JWT token
   - Check if admin account is active

2. **Configuration not saving**

   - Verify admin client is being used
   - Check Supabase service key configuration
   - Ensure proper error handling in logs

3. **Students can't check Paytaca status**
   - Verify authenticated read policy is working
   - Check if `isPaytacaEnabled()` method is using regular client

### Debug Steps

1. Check Supabase logs for RLS policy violations
2. Verify JWT token contains correct admin claims
3. Test database queries directly in Supabase SQL editor
4. Check application logs for authentication errors

## Files Modified

1. `fix_api_configuration_rls.sql` - Database RLS policies
2. `lib/services/supabase_service.dart` - Updated API configuration methods
3. `lib/user/user_dashboard.dart` - Updated to use database values instead of hardcoded keys

## Next Steps

1. Deploy the RLS fix script to production
2. Test admin functionality thoroughly
3. Monitor logs for any authentication issues
4. Update documentation for admin users

## Security Considerations

- Admin operations use service key (bypass RLS) - ensure proper admin authentication
- Regular users have limited read access only
- All admin operations are logged for audit purposes
- JWT tokens should have appropriate expiration times
