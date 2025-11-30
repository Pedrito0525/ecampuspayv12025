# PowerShell script to combine all SQL schema files into one
$outputFile = "complete_database_schema.sql"
$files = @(
    "system_update_settings_schema.sql",
    "admin_accounts_schema.sql",
    "admin_activity_log_schema.sql",
    "student_info_schema.sql",
    "auth_students_schema.sql",
    "service_accounts_schema.sql",
    "payment_items_schema.sql",
    "service_transactions_schema.sql",
    "loan_plans_schema.sql",
    "active_loans_schema.sql",
    "loan_payments_schema.sql",
    "loan_applications_schema.sql",
    "top_up_transactions_schema.sql",
    "top_up_requests_schema.sql",
    "user_transfers_schema.sql",
    "withdrawal_transactions_table.sql",
    "create_withdrawal_requests_table.sql",
    "create_service_withdrawal_requests_table.sql",
    "feedback_schema.sql",
    "api_configuration_schema.sql",
    "scanner_devices_schema.sql",
    "read_inbox_schema.sql",
    "create_id_replacement_table.sql",
    "create_commission_settings_table.sql",
    "create_staff_permissions_table.sql",
    "add_topup_fee_columns.sql",
    "update_top_up_transactions_for_services.sql"
)

$header = @"
-- ============================================================================
-- COMPLETE DATABASE SCHEMA - ALL TABLES, FUNCTIONS, AND POLICIES
-- ============================================================================
-- This file contains all database schemas consolidated into one file
-- Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
-- 
-- INSTRUCTIONS:
-- 1. Copy this entire file
-- 2. Paste into Supabase SQL Editor
-- 3. Run the script
-- 4. All tables, functions, triggers, and policies will be created
-- ============================================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

"@

$header | Out-File -FilePath $outputFile -Encoding UTF8

foreach ($file in $files) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw
        $sectionHeader = @"

-- ============================================================================
-- FILE: $file
-- ============================================================================

"@
        $sectionHeader | Out-File -FilePath $outputFile -Append -Encoding UTF8
        $content | Out-File -FilePath $outputFile -Append -Encoding UTF8
        "`n" | Out-File -FilePath $outputFile -Append -Encoding UTF8
    }
}

$footer = @"

-- ============================================================================
-- END OF CONSOLIDATED SCHEMA
-- ============================================================================
-- All tables, functions, triggers, and policies have been created
-- ============================================================================
"@

$footer | Out-File -FilePath $outputFile -Append -Encoding UTF8

Write-Host "Combined schema file created: $outputFile"

