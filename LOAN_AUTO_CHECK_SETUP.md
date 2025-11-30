# Loan Auto-Checking System Setup Guide

This guide explains how to set up the automatic loan checking system with OCR scanning.

## Overview

The auto loan checking system allows students to apply for loans by uploading an enrollment screenshot. The system automatically:
1. Scans the image using Google ML Kit OCR
2. Extracts enrollment data (name, status, AY, semester, subjects)
3. Validates eligibility automatically
4. Approves or rejects the loan application

## Prerequisites

1. Flutter SDK installed
2. Supabase project set up
3. Google ML Kit configured in your Flutter project

## Setup Steps

### 1. Install Dependencies

Run the following command to install the new dependencies:

```bash
flutter pub get
```

The new dependency added:
- `google_mlkit_text_recognition: ^0.11.0` - For OCR text recognition

### 2. Create Supabase Storage Bucket

1. Go to your Supabase dashboard
2. Navigate to Storage
3. Create a new bucket named: `loan_proof_image`
4. Set the bucket to **Public** (or configure appropriate policies)
5. Configure RLS policies if needed

**Bucket Configuration:**
- Name: `loan_proof_image`
- Public: Yes (or configure policies)
- File size limit: 10MB (recommended)
- Allowed MIME types: `image/jpeg`, `image/png`

### 3. Run Database Migrations

Execute the SQL file to create the necessary tables and functions:

```bash
# In Supabase SQL Editor, run:
```

Copy and paste the contents of `loan_applications_schema.sql` into the Supabase SQL Editor and execute it.

This will create:
- `loan_applications` table with OCR fields
- `get_current_academic_year_semester()` function
- `apply_for_loan_with_auto_approval()` function
- RLS policies for security

### 4. Configure System Settings (Optional)

If you have a `system_settings` table, add these entries:

```sql
INSERT INTO system_settings (key, value) VALUES
('current_academic_year', '2024-2025'),
('current_semester', '1st Semester')
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
```

If you don't have a `system_settings` table, the system will use default values:
- Academic Year: `2024-2025`
- Semester: `1st Semester`

### 5. Android Configuration

For Android, add the following to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.CAMERA" />
```

### 6. iOS Configuration

For iOS, add the following to `ios/Runner/Info.plist`:

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>We need access to your photo library to upload enrollment screenshots</string>
<key>NSCameraUsageDescription</key>
<string>We need access to your camera to take enrollment screenshots</string>
```

## How It Works

### Flow Overview

1. **Student selects a Loan Plan**
   - Student chooses from available loan plans
   - Loan Application screen opens

2. **Loan Agreement Confirmation**
   - Student reviews terms & conditions
   - Student checks "I Agree to the Loan Terms"
   - Upload button becomes enabled

3. **Upload Enrollment Screenshot**
   - Student selects image from gallery
   - Image is displayed for preview

4. **OCR Scanning**
   - Student clicks "Scan Image"
   - Google ML Kit extracts text from image
   - System extracts: Name, Status, AY, Semester, Subjects, Date, Confidence

5. **Eligibility Auto-Check**
   - All conditions must be TRUE:
     - A. Status must be "Officially Enrolled"
     - B. AY & Semester must match system's current AY/SEM
     - C. OCR name must match user profile name
     - D. Subject list must not be empty
     - E. OCR text must be readable (confidence >= 50%)
   - If any fail → auto-reject

6. **Auto Decision**
   - If all conditions TRUE → Auto Approve
     - Loan marked approved
     - Loan amount added to student balance
   - If any condition FALSE → Auto Reject
     - Save rejection reason

7. **Save Data to Database**
   - Store all OCR extracted values
   - Store uploaded image URL (in Supabase bucket)
   - Store decision + reason
   - Store timestamp

## Database Schema

### loan_applications Table

```sql
CREATE TABLE loan_applications (
    id SERIAL PRIMARY KEY,
    student_id VARCHAR(50) NOT NULL,
    loan_plan_id INTEGER NOT NULL REFERENCES loan_plans(id),
    
    -- OCR Extracted Data
    ocr_name VARCHAR(255),
    ocr_status VARCHAR(100),
    ocr_academic_year VARCHAR(50),
    ocr_semester VARCHAR(50),
    ocr_subjects TEXT,
    ocr_date VARCHAR(50),
    ocr_confidence DECIMAL(5,2),
    ocr_raw_text TEXT,
    
    -- Uploaded Image
    upload_image_url TEXT,
    
    -- Auto-Check Results
    decision VARCHAR(20) NOT NULL CHECK (decision IN ('pending', 'approved', 'rejected')),
    rejection_reason TEXT,
    
    -- System Fields
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);
```

## Testing

### Test the OCR Extraction

1. Take a screenshot of a student portal enrollment page
2. Ensure it contains:
   - Student name
   - Enrollment status ("Officially Enrolled")
   - Academic Year (e.g., "2024-2025")
   - Semester (e.g., "1st Semester")
   - List of subjects/courses

3. Upload the image in the loan application screen
4. Click "Scan Image"
5. Verify OCR results are extracted correctly

### Test Eligibility Checks

1. Test with valid enrollment screenshot → Should auto-approve
2. Test with old semester → Should reject with reason
3. Test with wrong name → Should reject with reason
4. Test with unclear image → Should reject with reason

## Troubleshooting

### OCR Not Extracting Text

- Ensure image is clear and readable
- Check that image contains text (not just images)
- Verify Google ML Kit is properly configured
- Check device permissions for storage access

### Image Upload Fails

- Verify Supabase bucket exists: `loan_proof_image`
- Check bucket permissions and RLS policies
- Ensure image file size is within limits
- Check network connectivity

### Eligibility Check Fails Unexpectedly

- Verify system settings for current AY/Semester
- Check that student profile name matches OCR name (case-insensitive)
- Ensure enrollment status contains "Officially Enrolled"
- Verify OCR confidence is above 50%

### Database Errors

- Ensure `loan_applications` table exists
- Verify RLS policies are correctly set
- Check that functions are created: `get_current_academic_year_semester()` and `apply_for_loan_with_auto_approval()`

## Security Notes

1. **RLS Policies**: The `loan_applications` table has RLS enabled. Students can only:
   - Read their own applications
   - Insert their own applications
   - Admins can read all applications

2. **Image Storage**: Images are stored in Supabase storage with proper access controls.

3. **Data Validation**: All OCR data is validated before approval to prevent fraud.

## Future Enhancements

- Add manual review option for edge cases
- Improve OCR extraction accuracy with better pattern matching
- Add support for multiple image formats
- Add admin dashboard to view all loan applications
- Add email notifications for approval/rejection

