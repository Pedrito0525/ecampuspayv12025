# Timezone Fix for Top-Up Transactions

## Problem
Manual top-up transactions were showing dates that were 9 hours late because the database was using `NOW()` which returns UTC time instead of Philippines time (Asia/Manila, UTC+8).

## Solution
Created a helper function `get_philippines_time()` that returns the current time in Philippines timezone, and updated:
1. The `top_up_transactions` table default for `created_at` and `updated_at` columns
2. The `process_top_up_transaction()` database function
3. The `update_top_up_transactions_updated_at()` trigger function

## Files Changed

### 1. `fix_timezone_topup.sql` (NEW)
   - Migration script to fix existing database
   - Creates `get_philippines_time()` helper function
   - Updates table defaults
   - Updates `process_top_up_transaction()` function
   - Updates trigger function

### 2. `top_up_transactions_schema.sql`
   - Updated to include `get_philippines_time()` function
   - Updated table defaults to use Philippines timezone
   - Updated trigger function

## How to Apply

### For Existing Databases:
Run the migration script in Supabase SQL Editor:
```sql
-- Run: final_ecampuspay/database/fix_timezone_topup.sql
```

### For New Databases:
The updated `top_up_transactions_schema.sql` already includes the fix, so no additional steps are needed.

## Technical Details

The `get_philippines_time()` function works as follows:
1. `now()` returns current UTC time as `TIMESTAMP WITH TIME ZONE`
2. `AT TIME ZONE 'Asia/Manila'` converts it to Philippines local time (returns `TIMESTAMP WITHOUT TIME ZONE`)
3. `AT TIME ZONE 'Asia/Manila'` again tells PostgreSQL this timestamp is in Asia/Manila timezone and converts it back to `TIMESTAMP WITH TIME ZONE` (stored as UTC internally)

This ensures that:
- The time is stored correctly in the database (as UTC internally)
- When queried and displayed, it shows the correct Philippines local time
- All new transactions will use Philippines timezone by default

## Verification

After applying the fix, verify by:
1. Creating a new manual top-up transaction
2. Checking the `created_at` timestamp in the database
3. The time should now reflect Philippines local time (UTC+8), not UTC

## Notes

- The Flutter code (`_getPhilippinesTimeISO()`) already handles timezone correctly for manual inserts
- The main issue was in the database function `process_top_up_transaction()` which was using `NOW()` (UTC)
- This fix ensures consistency across all top-up transaction creation methods

