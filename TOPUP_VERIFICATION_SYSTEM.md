# Top-Up Verification System - Admin Panel

## Overview

The Top-Up Management system now includes **two tabs** for comprehensive top-up handling:

1. **Manual Top-Up** - Direct balance additions by admin
2. **Verification Requests** - Review and approve/reject student GCash payment requests

---

## 🎯 Features

### Tab 1: Manual Top-Up (Existing Feature)
- Search students by School ID
- Add credits directly to student accounts
- Quick amount buttons (₱50, ₱100, ₱150, ₱200, ₱500)
- Real-time user validation
- Transaction history display

### Tab 2: Verification Requests (NEW)
- View all pending GCash payment requests
- Display proof of payment screenshots
- Student information summary
- Approve/Reject requests with confirmation
- Automatic balance update upon approval
- Transaction recording in `top_up_transactions` table

---

## 📋 User Flow - Verification Tab

### 1. View Pending Requests

The Verification tab displays all pending top-up requests submitted by students via GCash QR payment.

Each request card shows:
- ✅ Student name and ID
- ✅ Top-up amount (₱50, ₱100, ₱200, ₱500)
- ✅ Submission date and time
- ✅ Proof of payment screenshot (preview)
- ✅ Current status: "Pending Verification"

### 2. Open Request Details

**Tap on a request card** to view full details:
- Full-size proof of payment image
- Complete student information
- Transaction metadata

### 3. Review Proof of Payment

Admin manually reviews:
- Screenshot clarity and authenticity
- Payment amount matches requested amount
- Transaction appears legitimate

**Note:** The system currently relies on screenshot verification. Future enhancements could include reference number cross-checking.

### 4. Decision Point

#### ✅ **APPROVE**
1. Admin clicks **"Approve"** button
2. Confirmation dialog shows:
   - Student details
   - Amount to be added
   - Warning about irreversible action
3. Admin confirms approval
4. System processes:
   - Fetches current student balance
   - Calculates new balance
   - Updates `auth_students.balance`
   - Inserts record into `top_up_transactions`
   - Deletes request from `top_up_requests`
   - Refreshes both pending requests and recent transactions
5. Success message displayed with balance details

#### ❌ **REJECT**
1. Admin clicks **"Reject"** button
2. Dialog prompts for rejection reason (optional)
3. Admin confirms rejection
4. System processes:
   - Deletes request from `top_up_requests` table
   - No balance change
   - Refreshes pending requests list
5. Success message displayed

---

## 🗄️ Database Schema

### Table: `top_up_requests`

Stores pending verification requests from students.

```sql
CREATE TABLE top_up_requests (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL,                    -- Student ID
    amount INTEGER NOT NULL,                   -- Top-up amount
    screenshot_url TEXT NOT NULL,              -- Proof of payment image URL
    status TEXT NOT NULL DEFAULT 'Pending Verification',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    processed_by TEXT,                         -- Admin who processed it
    notes TEXT                                 -- Optional notes
);
```

### Table: `top_up_transactions`

Records all successful top-up transactions (both manual and verified).

```sql
CREATE TABLE top_up_transactions (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    previous_balance DECIMAL(10,2) NOT NULL,
    new_balance DECIMAL(10,2) NOT NULL,
    transaction_type VARCHAR(20) NOT NULL DEFAULT 'top_up',
    processed_by VARCHAR(100) NOT NULL,        -- 'admin' for panel actions
    notes TEXT,                                -- Includes request ID reference
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

### Supabase Storage Bucket: `Proof Payment`

Stores uploaded proof of payment screenshots from students.

**Configuration:**
- Bucket name: `Proof Payment` (with space)
- Public access: Enabled (for admin viewing)
- File format: PNG/JPEG images

---

## 🔐 Security & Permissions

### Row Level Security (RLS) Policies

The system uses **service_role key** for admin operations, which bypasses RLS. However, policies are defined for authenticated users:

#### Admin Policies (via service_role key):
```sql
-- Read all requests
CREATE POLICY "Allow admin read access to top_up_requests"
ON top_up_requests FOR SELECT TO authenticated USING (true);

-- Update requests (change status)
CREATE POLICY "Allow admin update access to top_up_requests"
ON top_up_requests FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

-- Delete requests (after processing)
CREATE POLICY "Allow admin delete access to top_up_requests"
ON top_up_requests FOR DELETE TO authenticated USING (true);
```

#### Student Policies:
```sql
-- Students can insert their own requests
CREATE POLICY "Allow students to insert their own requests"
ON top_up_requests FOR INSERT TO authenticated WITH CHECK (true);

-- Students can read their own requests
CREATE POLICY "Allow students to read their own requests"
ON top_up_requests FOR SELECT TO authenticated 
USING (user_id = current_setting('request.jwt.claims', true)::json->>'student_id');
```

### Security Best Practices

⚠️ **IMPORTANT:**
1. ✅ Service role key is used in admin panel only (never exposed to students)
2. ✅ Admin panel requires authentication before access
3. ✅ All transactions are logged with `processed_by` field
4. ✅ Student names are encrypted in database using `EncryptionService`
5. ✅ Balance updates are atomic (within transactions)

---

## 🚀 Setup Instructions

### 1. Run SQL Script

Execute the admin policy script in your Supabase SQL Editor:

```bash
# In Supabase Dashboard > SQL Editor
# Run: final_ecampuspay/top_up_requests_admin_policy.sql
```

This will:
- Enable RLS on `top_up_requests`
- Create admin access policies
- Create student access policies
- Add necessary indexes
- Grant permissions

### 2. Verify Table Structure

Ensure `top_up_requests` table exists with the correct schema. If not, create it:

```sql
CREATE TABLE IF NOT EXISTS top_up_requests (
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
```

### 3. Verify Storage Bucket

Check that the `Proof Payment` bucket exists:
1. Go to Supabase Dashboard → Storage
2. Verify bucket: `Proof Payment` exists
3. Ensure it's set to **Public** for admin viewing
4. Configure CORS if needed

### 4. Test the System

#### Test Student Flow:
1. Login as a student
2. Go to Dashboard → Top Up
3. Select amount (₱100)
4. Upload proof of payment screenshot
5. Submit request
6. Verify request appears in `top_up_requests` table

#### Test Admin Flow:
1. Login as admin
2. Go to Admin Panel → Top-Up Management
3. Switch to "Verification Requests" tab
4. Should see the pending request
5. Click "Approve" and confirm
6. Verify:
   - Student balance updated in `auth_students`
   - Transaction recorded in `top_up_transactions`
   - Request removed from `top_up_requests`

---

## 🎨 UI Components

### Request Card Layout

```
┌──────────────────────────────────────────────┐
│ 🔶 Orange header with student info           │
│    Avatar | Name              | Amount Badge  │
│           | ID: XXXX-XX-XXX   |               │
├──────────────────────────────────────────────┤
│ 📅 Submitted: DD/MM/YYYY at HH:MM            │
│                                               │
│ ┌──────────────────────────────────────────┐ │
│ │                                           │ │
│ │        Proof of Payment Image             │ │
│ │           (Tap to enlarge)                │ │
│ │                                           │ │
│ └──────────────────────────────────────────┘ │
│                                               │
│ [ ❌ Reject ]          [ ✅ Approve ]         │
└──────────────────────────────────────────────┘
```

### Color Scheme

- **Primary Red**: `#B91C1C` (EVSU Red)
- **Pending**: Orange shades (`Colors.orange.shade50/100/200`)
- **Approved**: Green (`Colors.green`)
- **Rejected**: Red (`Colors.red`)
- **Loading**: EVSU Red spinner

---

## 🧪 Testing Checklist

### Verification Tab
- [ ] Tab switches correctly between Manual Top-Up and Verification
- [ ] Pending requests load on tab switch
- [ ] Request cards display correctly with all information
- [ ] Proof of payment images load and display
- [ ] Tap to enlarge image works
- [ ] Approve confirmation dialog shows correct details
- [ ] Approve process updates balance correctly
- [ ] Transaction is recorded in `top_up_transactions`
- [ ] Request is deleted from `top_up_requests` after approval
- [ ] Reject confirmation dialog appears
- [ ] Reject process deletes request without balance change
- [ ] Refresh button works
- [ ] Pull-to-refresh works
- [ ] Empty state shows when no pending requests
- [ ] Error handling works (network issues, etc.)
- [ ] Student name decryption works correctly

### Manual Top-Up Tab
- [ ] Existing functionality remains unchanged
- [ ] Search by School ID works
- [ ] Amount input and quick buttons work
- [ ] Confirm and process top-up works
- [ ] Recent transactions display correctly

---

## 🔧 Troubleshooting

### Issue: Requests not loading

**Possible causes:**
1. RLS policies not applied correctly
2. Service role key not configured
3. Table doesn't exist or has wrong schema

**Solution:**
```sql
-- Verify policies exist
SELECT * FROM pg_policies WHERE tablename = 'top_up_requests';

-- Check if admin can query
SELECT * FROM top_up_requests LIMIT 1;
```

### Issue: Images not displaying

**Possible causes:**
1. Storage bucket is private
2. CORS not configured
3. Invalid image URLs

**Solution:**
1. Make bucket public or configure RLS policies
2. Add CORS configuration in Supabase Storage settings
3. Verify screenshot_url values in database

### Issue: Student names showing encrypted

**Possible causes:**
1. EncryptionService not initialized
2. Decryption key mismatch
3. Data not encrypted properly

**Solution:**
- Check `EncryptionService.initialize()` is called
- Verify encryption keys match between insert and read
- Check `auth_students` table encryption

### Issue: Balance not updating after approval

**Possible causes:**
1. Transaction rollback due to error
2. Wrong student_id
3. Database constraints failing

**Solution:**
```sql
-- Check if balance was updated
SELECT student_id, balance, updated_at 
FROM auth_students 
WHERE student_id = 'STUDENT_ID_HERE';

-- Check if transaction was recorded
SELECT * FROM top_up_transactions 
WHERE student_id = 'STUDENT_ID_HERE' 
ORDER BY created_at DESC LIMIT 5;
```

---

## 📝 Future Enhancements

### Planned Features:
1. ✨ **Reference Number Verification**
   - Add `reference_number` field to `top_up_requests`
   - Integrate with GCash API for auto-verification
   - Display reference number in request card

2. ✨ **Admin Activity Log**
   - Track all approve/reject actions
   - Display admin username instead of generic "admin"
   - Export activity logs

3. ✨ **Batch Processing**
   - Select multiple requests
   - Bulk approve/reject
   - Performance optimization

4. ✨ **Notification System**
   - Notify students when request is approved/rejected
   - Push notifications via FCM
   - In-app notification center

5. ✨ **Analytics Dashboard**
   - Track approval rates
   - Average processing time
   - Top-up trends and statistics

6. ✨ **Request History**
   - Show approved/rejected requests
   - Filter by date range
   - Export to CSV

---

## 📞 Support

For issues or questions:
1. Check the troubleshooting section
2. Review Supabase logs in the dashboard
3. Inspect Flutter console for error messages
4. Verify database schema matches documentation

---

## 📄 File Structure

```
final_ecampuspay/
├── lib/
│   └── admin/
│       └── topup_tab.dart                      # Main admin top-up interface (2 tabs)
├── top_up_requests_admin_policy.sql            # RLS policies for admin access
├── top_up_transactions_schema.sql              # Transaction table schema
└── TOPUP_VERIFICATION_SYSTEM.md                # This documentation
```

---

**Last Updated:** November 6, 2024  
**Version:** 2.0 - Two-Tab System with Verification

