# ID Replacement Implementation

## Overview

This document describes the implementation of the RFID card replacement flow for the eCampusPay system.

## Flow Description

### 1. User Input

- Admin navigates to **User Management > ID Replacement**
- Admin enters the **Student ID**

### 2. Student Verification

- System checks the `auth_students` table for the Student ID
- **If Student ID exists:**
  - Auto-fills the Student Name field
  - Displays the current RFID card number
  - Proceeds to next step
- **If Student ID does not exist:**
  - Displays alert: "Student Not Registered"
  - Stops the process
  - Admin must verify the Student ID or register the student first

### 3. RFID Card Scanning

- After successful verification, admin scans the **new RFID card**
- System receives the new RFID ID number
- System validates that the new RFID is not already registered
- **If RFID exists:** Shows warning but allows replacement (admin discretion)

### 4. Database Update

- System updates the `rfid_id` in `auth_students` table:
  ```sql
  UPDATE auth_students
  SET rfid_id = [encrypted_new_rfid], updated_at = [current_timestamp]
  WHERE student_id = [encrypted_input_id]
  ```

### 5. Confirmation

- Displays success message: "RFID card successfully replaced!"
- Shows both old and new RFID card numbers
- Clears the form for next replacement

## Technical Implementation

### Frontend (Flutter)

**File:** `final_ecampuspay/lib/admin/user_management_tab.dart`

#### New State Variables

```dart
// Form controllers for ID replacement
final TextEditingController _replacementStudentIdController
final TextEditingController _replacementStudentNameController
final TextEditingController _replacementRfidController

// ID Replacement state
bool _isLoadingReplacementData
String? _currentRfidId  // Store the current RFID ID before replacement
```

#### Key Methods

1. **`_onReplacementStudentIdChanged(String studentId)`**

   - Triggered when admin enters Student ID
   - Fetches student data from database
   - Auto-fills Student Name and displays current RFID
   - Shows "Student Not Registered" alert if not found

2. **`_buildReplacementRFIDCardField()`**

   - Builds the new RFID card input field
   - Includes scan button and scanner status indicator
   - Handles Bluetooth connection status

3. **`_performRFIDReplacement()`**

   - Validates all required fields
   - Shows confirmation dialog with old/new RFID comparison
   - Calls SupabaseService to update database
   - Displays success or error message

4. **`_scanRFIDCardForReplacement()`**

   - Initiates RFID scanning for replacement
   - Uses ESP32 Bluetooth service
   - Handles timeouts and errors

5. **`_clearReplacementForm()`**
   - Clears all replacement form fields
   - Resets state variables

#### RFID Scanner Integration

- Updated RFID data stream listener to detect replacement form (`_selectedFunction == 1`)
- Automatically populates `_replacementRfidController` when in replacement mode
- Shows appropriate warning if RFID already exists

### Backend (Supabase Service)

**File:** `final_ecampuspay/lib/services/supabase_service.dart`

#### New Methods

1. **`getStudentByStudentId(String studentId)`**

   - Fetches student data from `auth_students` table
   - Encrypts student_id for database query
   - Decrypts returned data for display
   - Returns student info including current RFID

2. **`replaceRFIDCard({required String studentId, required String newRfidId})`**
   - Validates that new RFID is not already registered
   - Encrypts both student_id and new rfid_id
   - Updates `auth_students` table with new RFID
   - Returns success/error status

## Security Features

1. **Data Encryption**

   - All student_id values are encrypted before database queries
   - All rfid_id values are encrypted before storage
   - Uses `EncryptionService.encryptUserData()` and `decryptUserData()`

2. **RFID Validation**

   - Checks if new RFID is already registered
   - Prevents duplicate RFID assignments
   - Shows warnings for existing RFIDs

3. **Authentication**
   - Uses admin client for database updates
   - Only accessible from admin panel
   - Requires authenticated admin session

## User Interface

### Form Layout

```
┌─────────────────────────────────────┐
│ Replace RFID Card                   │
├─────────────────────────────────────┤
│ Student ID: [________] 🔍           │
│   (auto-lookup on entry)            │
│                                     │
│ Student Name: [____Filled____]      │
│   (auto-filled, read-only)          │
│                                     │
│ ┌───────────────────────────────┐  │
│ │ Current RFID Card              │  │
│ │ 📇 AB12CD34EF56                │  │
│ └───────────────────────────────┘  │
│                                     │
│ New RFID Card Number:               │
│ [____________________]              │
│ [🔵 Scan New School ID Card]       │
│                                     │
│ Scanner: ✅ Connected               │
│                                     │
│ [Replace RFID Card]  [Clear]       │
└─────────────────────────────────────┘
```

### Success Dialog

```
┌─────────────────────────────────────┐
│ ✅ Success                          │
├─────────────────────────────────────┤
│ RFID card successfully replaced!    │
│                                     │
│ Student: Juan Dela Cruz             │
│ Student ID: 2022-30600              │
│                                     │
│ Old RFID: AB12CD34EF56              │
│ New RFID: 12AB34CD56EF              │
│                                     │
│                          [OK]       │
└─────────────────────────────────────┘
```

## Error Handling

1. **Student Not Found**

   - Shows alert dialog with orange warning icon
   - Message: "The entered Student ID is not registered in the system"
   - Suggests verifying Student ID or registering first

2. **RFID Already Exists**

   - Shows error dialog with red error icon
   - Message: "The new RFID ID is already registered to another student"
   - Prevents replacement to avoid conflicts

3. **Network/Database Errors**

   - Shows error dialog with technical details
   - Allows retry
   - Maintains form data

4. **Scanner Connection Issues**
   - Disables scan button when not connected
   - Shows scanner status indicator
   - Provides connection instructions

## Testing Checklist

- [ ] Student ID lookup with valid ID
- [ ] Student ID lookup with invalid ID
- [ ] RFID scanning functionality
- [ ] RFID validation (duplicate check)
- [ ] Database update with encrypted data
- [ ] Success message display
- [ ] Error handling for all scenarios
- [ ] Form clearing after successful replacement
- [ ] Scanner connection status updates
- [ ] Bluetooth permissions handling

## Database Schema

### auth_students Table

```sql
CREATE TABLE auth_students (
  auth_user_id UUID PRIMARY KEY REFERENCES auth.users,
  student_id TEXT UNIQUE NOT NULL,  -- Encrypted
  name TEXT NOT NULL,               -- Encrypted
  email TEXT UNIQUE NOT NULL,       -- Encrypted
  course TEXT,                      -- Encrypted
  rfid_id TEXT UNIQUE,              -- Encrypted
  balance DECIMAL(10,2) DEFAULT 0.00,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

## Future Enhancements

1. **RFID History Tracking**

   - Create `rfid_replacement_history` table
   - Log all RFID changes with timestamp and admin user

2. **Batch Replacement**

   - Allow CSV upload for multiple replacements
   - Generate replacement reports

3. **Email Notifications**

   - Send email to student when RFID is replaced
   - Include instructions for using new card

4. **Audit Trail**
   - Track which admin performed the replacement
   - Include reason for replacement
   - Generate audit reports

## Notes

- All RFID data is encrypted at rest
- Student ID must exist in database before replacement
- Old RFID is permanently replaced (not deactivated)
- Scanner must be connected before scanning
- Form auto-fills student name for convenience
- Clear button resets entire form
