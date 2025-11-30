# Complete Database Schema - Single File

## 📄 File: `complete_database_schema.sql`

This file contains **ALL** database tables, functions, triggers, and RLS policies consolidated into a single SQL file for easy copy-paste execution.

## 📊 What's Included

### Tables (27 total):
1. `system_update_settings` - App maintenance and update settings
2. `admin_accounts` - Admin user accounts
3. `admin_activity_log` - Admin activity logging
4. `student_info` - Student information for CSV import
5. `auth_students` - Student authentication and profiles
6. `service_accounts` - Service accounts with hierarchy
7. `payment_items` - Sellable items catalog
8. `service_transactions` - Service sales transactions
9. `loan_plans` - Loan product definitions
10. `active_loans` - Student loan applications
11. `loan_payments` - Loan payment tracking
12. `loan_applications` - Loan applications with OCR data
13. `top_up_transactions` - Top-up transaction records
14. `top_up_requests` - Top-up request management
15. `user_transfers` - Student-to-student transfers
16. `withdrawal_transactions` - Withdrawal transaction records
17. `withdrawal_requests` - Student withdrawal requests
18. `service_withdrawal_requests` - Service withdrawal requests
19. `feedback` - User and service feedback
20. `api_configuration` - API settings
21. `scanner_devices` - RFID scanner management
22. `read_inbox` - Transaction read/unread tracking
23. `id_replacement` - RFID card replacement tracking
24. `commission_settings` - Commission rate settings
25. `staff_permissions` - Staff permission management

### Features:
- ✅ All table definitions with constraints
- ✅ All indexes for performance
- ✅ All functions (helper functions, RPC functions)
- ✅ All triggers (for automatic `updated_at` timestamps)
- ✅ All RLS (Row Level Security) policies
- ✅ All permissions grants
- ✅ Storage policies for `loan_proof_image` bucket

## 🚀 How to Use

### Option 1: Supabase SQL Editor (Recommended)
1. Open your Supabase Dashboard
2. Go to **SQL Editor**
3. Click **New Query**
4. Open `complete_database_schema.sql` in a text editor
5. Copy the **entire** file content
6. Paste into the SQL Editor
7. Click **Run** or press `Ctrl+Enter`
8. Wait for execution to complete (may take 1-2 minutes)

### Option 2: Command Line (psql)
```bash
psql -h your-db-host.supabase.co -U postgres -d postgres -f complete_database_schema.sql
```

## ⚠️ Important Notes

1. **Execution Order**: The file is organized so tables are created before foreign keys are referenced
2. **Idempotent**: Uses `CREATE TABLE IF NOT EXISTS` and `DROP POLICY IF EXISTS` - safe to run multiple times
3. **Extensions**: Requires `pgcrypto` extension (automatically enabled in the script)
4. **Storage Bucket**: The `loan_proof_image` storage bucket must be created manually in Supabase Dashboard → Storage before running the script
5. **No Data Loss**: This script creates tables and policies but does NOT delete existing data

## 📋 Verification

After running the script, verify creation:

```sql
-- Check all tables exist
SELECT tablename 
FROM pg_tables 
WHERE schemaname = 'public' 
ORDER BY tablename;

-- Check all functions exist
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
ORDER BY routine_name;

-- Check RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
AND rowsecurity = true;
```

## 🔧 Troubleshooting

### Error: "relation already exists"
- This is normal if tables already exist
- The script uses `IF NOT EXISTS` clauses
- You can safely ignore these warnings

### Error: "policy already exists"
- Policies are dropped before creation
- If you see this error, the script will handle it automatically

### Error: "extension pgcrypto does not exist"
- Contact Supabase support to enable the extension
- Or run manually: `CREATE EXTENSION pgcrypto;`

## 📝 File Size
- **Size**: ~172 KB
- **Lines**: ~4,300 lines
- **Execution Time**: ~1-2 minutes (depending on database performance)

## ✅ Success Indicators

After successful execution, you should see:
- All tables created
- All functions created
- All policies created
- No critical errors (warnings about existing objects are OK)

---

**Generated**: Automatically combined from individual schema files  
**Last Updated**: Check file header for generation timestamp

