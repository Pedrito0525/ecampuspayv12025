# Debug Guide - Top-Up Verification Not Showing

## 🔍 How to Debug

### Step 1: Open Flutter Console

When you run the app and navigate to the **Verification Requests** tab, watch the Flutter console/terminal for debug messages.

---

## 📋 Debug Message Guide

### ✅ **SUCCESS Pattern** (Everything works)

```
🚀 DEBUG: TopUpTab initState() called
🔍 DEBUG: Loading pending verification requests...
🔍 DEBUG: Starting _loadPendingRequests()...
🔍 DEBUG: Initializing SupabaseService...
✅ DEBUG: SupabaseService initialized successfully
🔍 DEBUG: Attempting to fetch raw top_up_requests (without join)...
✅ DEBUG: Raw query successful! Found 3 total records
🔍 DEBUG: Fetching pending requests (status = "Pending Verification")...
✅ DEBUG: Found 3 requests with status "Pending Verification"
🔍 DEBUG: Attempting to join with auth_students table...
✅ DEBUG: Query with join successful! Found 3 records
🔍 DEBUG: Processing request 1/3
   - Request ID: 1
   - User ID: EVSU-2024-001
   - Amount: 100
   - Status: Pending Verification
   ✅ Decrypted name: John Doe
   ✅ Added request to list
✅ DEBUG: Processed 3 requests successfully
✅ DEBUG: State updated! UI should now show 3 requests
```

**Result:** Requests will display in the UI ✅

---

## ❌ **FAILURE Patterns** (What went wrong)

### Pattern 1: Permission Denied

```
🔍 DEBUG: Attempting to fetch raw top_up_requests (without join)...
❌ DEBUG: Raw query FAILED: permission denied for table top_up_requests
❌ DEBUG: This means admin cannot access top_up_requests table at all!
❌ DEBUG: Run fix_top_up_requests_access.sql in Supabase
```

**Problem:** Admin doesn't have access to `top_up_requests` table

**Solution:**
1. Open **Supabase SQL Editor**
2. Run the file: **`fix_top_up_requests_access.sql`**
3. Restart the Flutter app
4. Check console again

---

### Pattern 2: No Pending Requests Found

```
✅ DEBUG: Raw query successful! Found 5 total records
🔍 DEBUG: Fetching pending requests (status = "Pending Verification")...
✅ DEBUG: Found 0 requests with status "Pending Verification"
⚠️  DEBUG: No pending requests found! Check if:
   1. Data exists in database with status = "Pending Verification"
   2. Status field is exactly "Pending Verification" (case-sensitive)
```

**Problem:** No records with status = "Pending Verification"

**Solution:**
Check your database:
```sql
-- See all records and their statuses
SELECT id, user_id, amount, status FROM top_up_requests;

-- Update status if wrong
UPDATE top_up_requests 
SET status = 'Pending Verification' 
WHERE status != 'Pending Verification';
```

---

### Pattern 3: Join Failed (No matching students)

```
✅ DEBUG: Found 3 requests with status "Pending Verification"
🔍 DEBUG: Attempting to join with auth_students table...
✅ DEBUG: Query with join successful! Found 0 records
```

**Problem:** The `user_id` in `top_up_requests` doesn't match any `student_id` in `auth_students`

**Solution:**
```sql
-- Check if student IDs match
SELECT 
    tr.user_id,
    CASE 
        WHEN s.student_id IS NOT NULL THEN '✅ Match found'
        ELSE '❌ No match - Student not in auth_students'
    END AS status
FROM top_up_requests tr
LEFT JOIN auth_students s ON tr.user_id = s.student_id
WHERE tr.status = 'Pending Verification';
```

If no matches found:
- Verify `user_id` in `top_up_requests` is correct
- Make sure students exist in `auth_students` table
- Check for extra spaces or case differences

---

### Pattern 4: Table Not Found

```
❌ DEBUG: ERROR in _loadPendingRequests:
   Error: relation "public.top_up_requests" does not exist
❌ DEBUG: TABLE NOT FOUND - top_up_requests table may not exist
```

**Problem:** `top_up_requests` table doesn't exist

**Solution:**
Create the table:
```sql
CREATE TABLE top_up_requests (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,
    amount INTEGER NOT NULL,
    screenshot_url TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Pending Verification',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    processed_by TEXT,
    notes TEXT
);

-- Add indexes
CREATE INDEX idx_top_up_requests_status ON top_up_requests(status);
CREATE INDEX idx_top_up_requests_user_id ON top_up_requests(user_id);
CREATE INDEX idx_top_up_requests_created_at ON top_up_requests(created_at DESC);
```

---

### Pattern 5: Decryption Failed

```
✅ DEBUG: Found 3 records
🔍 DEBUG: Processing request 1/3
   - Student data found: {student_id: EVSU-2024-001, name: encrypted_string_here}
   - Attempting to decrypt name...
   ❌ Failed to decrypt student name: Decryption error
```

**Problem:** Name decryption failed (not a critical error)

**Result:** Will show student name as "Unknown Student" or show encrypted data

**Note:** This doesn't prevent requests from displaying, just affects the name shown.

---

## 🔧 Quick Tests

### Test 1: Check if table is accessible
```sql
SELECT COUNT(*) FROM top_up_requests;
```

If this fails → Run `fix_top_up_requests_access.sql`

### Test 2: Check for pending requests
```sql
SELECT * FROM top_up_requests WHERE status = 'Pending Verification';
```

If empty → No pending requests (submit one from student app)

### Test 3: Check join
```sql
SELECT 
    tr.*,
    s.student_id,
    s.name,
    s.email
FROM top_up_requests tr
INNER JOIN auth_students s ON tr.user_id = s.student_id
WHERE tr.status = 'Pending Verification';
```

If empty → User IDs don't match

---

## 📱 Steps to Test

1. **Hot Restart** your Flutter app (not just hot reload)
2. Login as **Admin**
3. Navigate to **Top-Up Management** → **Verification Requests** tab
4. **Watch the console** for debug messages
5. **Copy the console output** and check against patterns above

---

## 🎯 Most Common Issues & Fixes

### Issue 1: Permission Denied
**Fix:** Run `fix_top_up_requests_access.sql`

### Issue 2: No data showing but console shows success
**Possible causes:**
- Flutter state not updating → Hot restart the app
- UI rendering issue → Check if `_pendingRequests.length` is printed correctly
- Tab not switching properly → Click the tab again

### Issue 3: "Unknown Student" showing
**Fix:** Check if student exists in `auth_students`:
```sql
SELECT student_id, name FROM auth_students WHERE student_id = 'YOUR_STUDENT_ID';
```

---

## 📞 Share Debug Output

After following the steps above, if it still doesn't work:

1. **Copy the entire console output** starting from:
   ```
   🚀 DEBUG: TopUpTab initState() called
   ```

2. **Share the output** so we can see exactly what's happening

3. **Also share this SQL query result**:
   ```sql
   SELECT id, user_id, amount, status, created_at 
   FROM top_up_requests 
   LIMIT 5;
   ```

---

## ✅ Success Indicators

You'll know it's working when you see:

1. ✅ No error messages in console
2. ✅ "Found X requests with status 'Pending Verification'" where X > 0
3. ✅ "State updated! UI should now show X requests"
4. ✅ Request cards visible in the Verification Requests tab

---

**Debug version updated:** November 6, 2024

