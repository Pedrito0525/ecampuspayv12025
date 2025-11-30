# Quick Start Guide - Top-Up Verification System

## 🚀 Get Started in 3 Steps

### Step 1: Run Database Setup (5 minutes)

Open your **Supabase SQL Editor** and run these scripts in order:

#### 1.1 Create/Verify Top-Up Requests Table
```sql
-- If table doesn't exist, create it
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

#### 1.2 Apply Admin Policies
Run the entire file: `top_up_requests_admin_policy.sql`

This will:
- ✅ Enable Row Level Security
- ✅ Create admin access policies
- ✅ Create student access policies
- ✅ Add necessary indexes

#### 1.3 Verify Setup
Run the verification script: `verify_topup_setup.sql`

Expected output: **"🎉 ALL CHECKS PASSED - System is ready!"**

---

### Step 2: Verify Storage Bucket (2 minutes)

1. Go to **Supabase Dashboard** → **Storage**
2. Check if bucket **"Proof Payment"** exists
3. If not, create it:
   - Name: `Proof Payment` (with space)
   - Public: ✅ Enabled (for admin viewing)
4. Verify bucket is accessible

---

### Step 3: Test the System (5 minutes)

#### Test as Student:
1. Login as a student account
2. Go to **Dashboard** → **Top Up** button
3. Select amount: **₱100**
4. Upload a screenshot (any image for testing)
5. Click **"I've Paid - Submit"**
6. Verify success message appears

#### Test as Admin:
1. Login to **Admin Panel**
2. Navigate to **Top-Up Management**
3. Switch to **"Verification Requests"** tab
4. You should see the pending request from Step 1
5. Click on the request to view details
6. Click **"Approve"** → **Confirm**
7. Verify success message with updated balance

#### Verify Results:
```sql
-- Check student balance was updated
SELECT student_id, balance FROM auth_students 
WHERE student_id = 'YOUR_STUDENT_ID';

-- Check transaction was recorded
SELECT * FROM top_up_transactions 
WHERE student_id = 'YOUR_STUDENT_ID' 
ORDER BY created_at DESC LIMIT 1;

-- Check request was removed
SELECT * FROM top_up_requests 
WHERE user_id = 'YOUR_STUDENT_ID';
-- Should return 0 rows
```

---

## ✅ Success Checklist

- [ ] Database tables exist (`top_up_requests`, `top_up_transactions`)
- [ ] RLS policies are enabled and configured
- [ ] Storage bucket "Proof Payment" exists and is public
- [ ] Admin panel shows two tabs: "Manual Top-Up" and "Verification Requests"
- [ ] Students can submit top-up requests with screenshots
- [ ] Admins can see pending requests in Verification tab
- [ ] Admins can view proof of payment images
- [ ] Approve button updates balance and records transaction
- [ ] Reject button removes request without balance change
- [ ] No errors in Flutter console during testing

---

## 🎯 What You Can Do Now

### As Admin:

**Manual Top-Up Tab:**
- Search students by School ID
- Add credits directly to accounts
- Use quick amount buttons
- View recent transaction history

**Verification Requests Tab:**
- View all pending GCash payment requests
- See student name, ID, and requested amount
- Review proof of payment screenshots
- Approve requests to add credits
- Reject invalid requests with optional reason
- Refresh list to see new requests

### As Student:
- Submit top-up requests via GCash QR
- Upload proof of payment screenshots
- Wait for admin verification
- Receive balance update upon approval

---

## 📱 UI Navigation

```
Admin Panel
└── Top-Up Management
    ├── Tab 1: Manual Top-Up
    │   ├── Search by School ID
    │   ├── Enter Amount
    │   ├── Quick Amount Buttons
    │   ├── User Info Display
    │   └── Recent Transactions
    │
    └── Tab 2: Verification Requests ← NEW!
        ├── Pending Requests List
        │   ├── Request Card 1
        │   │   ├── Student Info
        │   │   ├── Amount Badge
        │   │   ├── Screenshot Preview
        │   │   └── [Reject] [Approve]
        │   ├── Request Card 2
        │   └── ...
        │
        └── Pull to Refresh
```

---

## 🐛 Common Issues & Fixes

### Issue: "No pending requests" but students submitted

**Fix:**
```sql
-- Check if requests exist
SELECT * FROM top_up_requests;

-- Check RLS policies
SELECT * FROM pg_policies WHERE tablename = 'top_up_requests';
```

### Issue: Images not loading

**Fix:**
1. Verify bucket is public
2. Check screenshot_url in database contains valid URLs
3. Test URL directly in browser

### Issue: Approve button does nothing

**Fix:**
- Check Flutter console for errors
- Verify service_role key is configured in `supabase_config.dart`
- Check if `auth_students` table has balance column

---

## 📞 Need Help?

1. **Review Documentation**: `TOPUP_VERIFICATION_SYSTEM.md`
2. **Check Troubleshooting**: See full documentation for detailed solutions
3. **Verify Setup**: Run `verify_topup_setup.sql` again
4. **Check Logs**: Review Supabase logs and Flutter console

---

## 🎉 You're All Set!

Your Top-Up Verification System is now ready. Admin can now:
- ✅ Review student payment requests
- ✅ Verify proof of payment screenshots
- ✅ Approve/reject requests with one click
- ✅ Track all transactions automatically

Students can:
- ✅ Submit GCash payment requests
- ✅ Upload proof of payment
- ✅ Receive instant balance updates upon approval

---

**Enjoy using the new verification system! 🚀**

For detailed documentation, see: `TOPUP_VERIFICATION_SYSTEM.md`

