# Database Migrations

This directory contains SQL migration scripts for the eCampusPay database.

## Migration Files

### 1. `create_api_configuration_simple.sql` ⭐ **RECOMMENDED**

Creates the `api_configuration` table without RLS for basic functionality.

- **Use this first** to get the system working
- No RLS policies (accessible to all authenticated users)
- Safe to run without knowing table structures

### 2. `create_api_configuration_table.sql`

Creates the `api_configuration` table (currently without RLS).

- Run this if you want the full table with comments
- RLS policies will be added later

### 3. `inspect_auth_students.sql`

Inspect the `auth_students` table structure to understand available columns.

- Run this to see what columns exist
- Helps determine how to implement RLS policies

### 4. `enable_rls_api_configuration_simple.sql` ⭐ **RECOMMENDED FOR RLS**

Enables RLS with permissive policies for all authenticated users.

- **Use this to enable RLS** without knowing table structures
- Allows all authenticated users to read/write configuration
- Temporary solution for immediate functionality

### 5. `enable_rls_api_configuration_secure.sql`

Enables RLS with role-based policies (requires auth_students table inspection).

- **Use this for production** after inspecting auth_students table
- Restricts access based on user roles (admin/student)
- More secure but requires correct table structure

### 6. `fix_rls_policies_keep_enabled.sql` ⭐ **RECOMMENDED RLS FIX**

Fixes RLS policies while keeping RLS ENABLED for security.

- **Use this to fix RLS policies without disabling security**
- Keeps RLS enabled with proper policies
- Comprehensive policy coverage (SELECT, INSERT, UPDATE, DELETE)
- Includes verification queries

### 7. `fix_rls_auth_based.sql` ⭐ **ALTERNATIVE RLS FIX**

Fixes RLS policies using Supabase auth context.

- **Use this if the above doesn't work**
- Uses auth.uid() for better Supabase compatibility
- More specific authentication checks
- Keeps RLS enabled

### 8. `fix_rls_api_configuration.sql` ⭐ **FOR RLS ISSUES**

Fixes RLS policies by recreating them from scratch.

- **Use this if RLS policies aren't working**
- Disables and re-enables RLS with fresh policies
- Includes verification queries

### 9. `disable_rls_api_configuration.sql` ⭐ **EMERGENCY FIX**

Completely disables RLS for the api_configuration table.

- **Use this if RLS continues to cause issues**
- Allows all operations without RLS restrictions
- Quick fix for immediate functionality

### 10. `enable_rls_api_configuration.sql`

Original RLS file (currently disabled due to table structure issues).

- **Don't run this yet** until we understand the auth_students table
- Will be updated once we know the correct column names

## How to Run Migrations

### Option 1: Quick Setup (Recommended for immediate functionality)

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Copy and paste `create_api_configuration_simple.sql` and run it
4. Copy and paste `enable_rls_api_configuration_simple.sql` and run it

### Option 1B: Fix RLS Policies (Keep RLS Enabled) ⭐ **RECOMMENDED**

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Copy and paste `fix_rls_policies_keep_enabled.sql` and run it

### Option 1C: Alternative RLS Fix (Auth-based)

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Copy and paste `fix_rls_auth_based.sql` and run it

### Option 1D: Emergency Fix (Disable RLS) - Last Resort

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Copy and paste `disable_rls_api_configuration.sql` and run it

### Option 2: Secure Setup (For production)

1. Go to your Supabase project dashboard
2. Navigate to SQL Editor
3. Run `inspect_auth_students.sql` to check table structure
4. Copy and paste `create_api_configuration_simple.sql` and run it
5. Copy and paste `enable_rls_api_configuration_secure.sql` and run it

### Option 3: Supabase CLI

```bash
supabase db reset
# or
supabase db push
```

### Option 4: Direct SQL Execution

Execute the SQL directly in your database management tool.

## Current Status

✅ **Working**: Basic table creation without RLS
✅ **Working**: Simple RLS policies (permissive for all authenticated users)
⚠️ **Pending**: Secure RLS policies (waiting for table structure analysis)

## Next Steps

1. **Run the simple migration** to get basic functionality
2. **Inspect auth_students table** to understand structure
3. **Add RLS policies** once we know the correct column names

## Security Notes

- Currently: All authenticated users can access the configuration
- Future: RLS will restrict access based on user roles
- Sensitive fields (`xpub_key`, `wallet_hash`) should be protected
