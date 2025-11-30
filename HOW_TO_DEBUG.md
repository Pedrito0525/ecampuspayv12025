# How to Debug: Requests Not Showing

## 🚀 Quick Steps

### Step 1: Run Database Diagnostic (2 minutes)

1. Open **Supabase Dashboard** → **SQL Editor**
2. Copy and paste entire file: **`diagnose_top_up_requests.sql`**
3. Click **Run**
4. **Copy all the results** (you'll share this if needed)

**Look for:**
- ✅ "Table exists"
- ✅ "Pending requests found"
- ✅ "Student exists in auth_students"

---

### Step 2: Check Flutter Console (2 minutes)

1. **Hot Restart** your Flutter app (full restart, not hot reload)
2. Login as **Admin**
3. Navigate to: **Top-Up Management** → **Verification Requests** tab
4. **Watch the console output**

---

## 📋 What to Look For in Console

### ✅ **If you see this = SUCCESS**

```
🔍 DEBUG: Attempting to fetch raw top_up_requests (without join)...
✅ DEBUG: Raw query successful! Found 3 total records
✅ DEBUG: Found 3 requests with status "Pending Verification"
✅ DEBUG: Query with join successful! Found 3 records
✅ DEBUG: State updated! UI should now show 3 requests
```

**Result:** Requests should appear in the UI

---

### ❌ **If you see this = PERMISSION ERROR**

```
❌ DEBUG: Raw query FAILED: permission denied for table top_up_requests
❌ DEBUG: This means admin cannot access top_up_requests table at all!
```

**FIX:**
1. Run `fix_top_up_requests_access.sql` in Supabase
2. Restart Flutter app
3. Try again

---

### ⚠️ **If you see this = NO DATA**

```
✅ DEBUG: Raw query successful! Found 0 total records
```
**OR**
```
✅ DEBUG: Found 0 requests with status "Pending Verification"
```

**FIX:**
- Submit a test request from the **student app** first
- Or run this in Supabase SQL Editor:
```sql
-- Check if data exists
SELECT * FROM top_up_requests;

-- Update status if wrong
UPDATE top_up_requests SET status = 'Pending Verification';
```

---

### ⚠️ **If you see this = JOIN FAILED**

```
✅ DEBUG: Found 3 requests with status "Pending Verification"
🔍 DEBUG: Attempting to join with auth_students table...
✅ DEBUG: Query with join successful! Found 0 records
```

**Problem:** `user_id` in `top_up_requests` doesn't match `student_id` in `auth_students`

**FIX:**
Run this in Supabase:
```sql
-- Check for mismatches
SELECT 
    tr.user_id AS request_user_id,
    s.student_id AS auth_student_id,
    CASE 
        WHEN s.student_id IS NULL THEN '❌ NO MATCH'
        ELSE '✅ MATCH'
    END AS status
FROM top_up_requests tr
LEFT JOIN auth_students s ON tr.user_id = s.student_id;
```

If you see "NO MATCH", the user IDs don't match. Check:
- Are there spaces in the ID?
- Is the case correct?
- Does the student exist in `auth_students`?

---

## 🔧 Most Common Fixes

### Fix 1: Run Access Policy Script

```bash
# In Supabase SQL Editor:
1. Open file: fix_top_up_requests_access.sql
2. Run the entire file
3. Restart Flutter app
```

### Fix 2: Verify Data Exists

```sql
-- Run in Supabase SQL Editor
SELECT 
    id,
    user_id,
    amount,
    status,
    created_at
FROM top_up_requests
ORDER BY created_at DESC
LIMIT 5;
```

If empty → Submit a test request from student app

### Fix 3: Check Status Field

```sql
-- See all status values
SELECT status, COUNT(*) FROM top_up_requests GROUP BY status;

-- Fix if wrong
UPDATE top_up_requests SET status = 'Pending Verification';
```

---

## 📸 Share Debug Info

If still not working, share:

1. **Console output** from Flutter (copy from `🚀 DEBUG: TopUpTab initState()` onwards)
2. **SQL diagnostic results** (from `diagnose_top_up_requests.sql`)
3. **Screenshot** of the Verification Requests tab

---

## ✅ Success Checklist

- [ ] Ran `fix_top_up_requests_access.sql` in Supabase
- [ ] Verified data exists in `top_up_requests` table
- [ ] Console shows "Raw query successful! Found X records" where X > 0
- [ ] Console shows "Found X requests with status 'Pending Verification'" where X > 0
- [ ] Console shows "Query with join successful! Found X records" where X > 0
- [ ] Console shows "State updated! UI should now show X requests"
- [ ] Requests visible in Verification Requests tab

---

## 📞 Next Steps

1. **Hot restart** the app
2. **Navigate to** Verification Requests tab
3. **Check console** for debug messages
4. **Run diagnostic SQL** in Supabase
5. **Share results** if still not working

---

**Files to use:**
- 📄 `fix_top_up_requests_access.sql` - Fix permissions
- 📄 `diagnose_top_up_requests.sql` - Database diagnostic
- 📄 `DEBUG_TOPUP_VERIFICATION.md` - Detailed debug guide
- 📄 `HOW_TO_DEBUG.md` - This file (quick reference)

**Last Updated:** November 6, 2024

