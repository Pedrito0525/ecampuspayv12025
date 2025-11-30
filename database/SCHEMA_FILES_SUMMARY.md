# Database Schema Files Summary

This document lists all SQL schema files in the `database` folder and their purposes.

## Core System Tables

1. **system_update_settings_schema.sql**
   - Singleton table for app maintenance and update settings
   - Functions: `get_system_update_settings()`, `update_system_update_settings()`

2. **admin_accounts_schema.sql**
   - Admin user accounts with authentication
   - Functions: `authenticate_admin()`, `update_admin_accounts_updated_at()`
   - Includes scanner_id and Supabase auth integration

3. **admin_activity_log_schema.sql**
   - Logs admin actions and activities
   - Functions: `log_admin_activity()`, `get_admin_activity_logs()`

## Student Tables

4. **auth_students_schema.sql**
   - Main student authentication and profile table
   - Functions: `get_student_balance()`, `update_student_balance()`, `check_student_active()`, `get_student_info()`

5. **student_info_schema.sql**
   - Student information for CSV import and autofill
   - Functions: `search_student_info()`, `search_student_info_by_email()`, `bulk_insert_student_info()`, `get_all_student_info()`

## Service Tables

6. **service_accounts_schema.sql**
   - Service accounts with main/sub hierarchy support
   - Includes scanner assignment and commission rates

7. **service_transactions_schema.sql**
   - Records of service sales transactions
   - Functions: `get_service_transactions()`

8. **payment_items_schema.sql**
   - Catalog of sellable items per service account
   - Supports size options and categories

## Loan Tables

9. **loan_plans_schema.sql**
   - Admin-defined loan products
   - Includes interest rates, penalty rates, and terms

10. **active_loans_schema.sql**
    - Student loan applications and status
    - Tracks loan amounts, interest, penalties, and due dates

11. **loan_payments_schema.sql**
    - Records of loan payments (full and partial)
    - Tracks remaining balances

12. **loan_applications_schema.sql**
    - Loan applications with OCR-extracted enrollment data
    - Includes auto-approval/rejection logic

## Transaction Tables

13. **top_up_transactions_schema.sql**
    - Records of top-up transactions
    - Supports multiple transaction types (top_up, top_up_gcash, top_up_services, loan_disbursement)

14. **top_up_requests_schema.sql**
    - Student top-up requests with screenshot verification
    - Tracks approval/rejection status

15. **user_transfers_schema.sql**
    - Money transfers between students
    - Includes balance calculations and validation

16. **withdrawal_transactions_table.sql**
    - Service account withdrawal transactions
    - Tracks transfers between services

17. **withdrawal_requests_table.sql** (create_withdrawal_requests_table.sql)
    - Student withdrawal requests
    - Tracks GCash transfers and processing

18. **create_service_withdrawal_requests_table.sql**
    - Service account withdrawal requests
    - Similar to student withdrawal requests but for services

## Utility Tables

19. **feedback_schema.sql**
    - Feedback from users and service accounts
    - Supports both user types

20. **api_configuration_schema.sql**
    - Singleton table for API settings
    - Functions: `get_api_configuration()`

21. **scanner_devices_schema.sql**
    - RFID Bluetooth scanner device management
    - Tracks device status and assignments
    - Note: `scanner_assignments` is a VIEW (not a separate table)

22. **read_inbox_schema.sql**
    - Tracks read/unread status of transactions
    - Functions: `mark_transaction_as_read()`, `get_unread_transaction_count()`

23. **create_id_replacement_table.sql**
    - ID replacement requests and tracking
    - Links old and new RFID IDs

## Configuration Tables

24. **create_commission_settings_table.sql**
    - Commission rate settings for vendors and admin

25. **create_staff_permissions_table.sql**
    - Staff permission management

26. **add_topup_fee_columns.sql**
    - Additional columns for top-up fee tracking

## Migration Files

27. **add_processed_by_foreign_key.sql**
    - Adds foreign key constraints for processed_by fields

28. **remove_processed_by_foreign_key.sql**
    - Removes foreign key constraints (if needed)

29. **update_top_up_transactions_for_services.sql**
    - Updates top_up_transactions for service account support

## Notes

- All schema files follow a consistent structure:
  1. Table creation with constraints
  2. Indexes for performance
  3. Functions for common operations
  4. Triggers for automatic updates
  5. RLS (Row Level Security) policies
  6. Permissions grants

- Views are created within related schema files (e.g., `scanner_assignments` view in scanner_devices schema)

- Singleton tables (system_update_settings, api_configuration) use `id = 1` constraint

- All tables include `created_at` and `updated_at` timestamps with automatic triggers

