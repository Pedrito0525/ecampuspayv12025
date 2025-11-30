# Top-Up Fee Feature Documentation

## Overview
This feature adds a configurable percentage-based fee system for manual admin top-ups. Admins can set a fee percentage (default 1%) that is calculated and recorded for each top-up transaction.

## Changes Made

### 1. Database Migration
**File:** `database/add_topup_fee_columns.sql`

- Added `vendor_earn` and `admin_earn` columns to `top_up_transactions` table
- Updated `process_top_up_transaction()` function to accept fee parameters
- Updated `get_recent_top_up_transactions()` function to include fee information

**To apply:**
```sql
-- Run this SQL script in Supabase SQL Editor
\i database/add_topup_fee_columns.sql
```

### 2. Flutter UI Updates
**File:** `lib/admin/topup_tab.dart`

- Added fee percentage input field (default: 1.0%)
- Added real-time fee calculation display
- Updated confirmation dialog to show fee amount
- Updated success dialog to display admin earnings
- Modified `_updateUserBalance()` to accept and pass `adminEarn` parameter

## How It Works

### Fee Calculation
- **Formula:** `adminEarn = topUpAmount × (feePercentage / 100)`
- **Example:** 
  - Top-up amount: ₱100.00
  - Fee percentage: 1.0%
  - Admin earn: ₱1.00

### User Flow
1. Admin enters student ID and top-up amount
2. Admin can adjust fee percentage (default: 1.0%)
3. System calculates and displays fee amount in real-time
4. Confirmation dialog shows:
   - Current balance
   - Top-up amount
   - Admin fee (with percentage)
   - New balance
5. After processing, success dialog displays:
   - Previous balance
   - Top-up amount
   - Admin fee earned
   - New balance

## Database Schema

### New Columns in `top_up_transactions`
- `vendor_earn` DECIMAL(10,2) - Fee earned by vendor/service provider
- `admin_earn` DECIMAL(10,2) - Fee earned by admin/platform

### Updated Function Signature
```sql
process_top_up_transaction(
    p_student_id VARCHAR(50),
    p_amount DECIMAL(10,2),
    p_processed_by VARCHAR(100),
    p_notes TEXT DEFAULT NULL,
    p_transaction_type VARCHAR(20) DEFAULT 'top_up',
    p_admin_earn DECIMAL(10,2) DEFAULT 0.00,
    p_vendor_earn DECIMAL(10,2) DEFAULT 0.00
)
```

## Usage Notes

1. **Default Fee:** The fee percentage defaults to 1.0% but can be changed by the admin
2. **Fee Display:** The fee amount is calculated and displayed in real-time as the admin types
3. **Manual Top-Ups Only:** This fee system applies only to manual admin top-ups
4. **GCash Top-Ups:** GCash verification requests don't use this fee system (they have their own flow)
5. **Vendor Earn:** Currently set to 0.00 for manual top-ups, but can be used for future features

## Testing Checklist

- [ ] Run SQL migration script in Supabase
- [ ] Verify fee percentage input field appears (default 1.0%)
- [ ] Test fee calculation with different percentages
- [ ] Verify confirmation dialog shows fee correctly
- [ ] Process a test top-up and verify `admin_earn` is saved in database
- [ ] Check success dialog displays admin fee correctly
- [ ] Verify recent top-ups list shows fee information

## Future Enhancements

- Add fee percentage configuration in admin settings
- Add fee reporting/analytics dashboard
- Support different fee rates for different transaction types
- Add vendor fee support for service provider transactions

