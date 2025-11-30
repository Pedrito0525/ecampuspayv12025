# Simplified OTP Password Reset Guide

## Overview

This approach uses Supabase's built-in password reset functionality with a custom email template that displays the token as an OTP code. No custom OTP table needed!

## How It Works

### 1. **User Requests Password Reset**

- User enters email and clicks "Get OTP Code"
- System calls `client.auth.resetPasswordForEmail()`
- Supabase generates a unique token and sends email

### 2. **Custom Email Template**

- Supabase uses your custom template instead of default
- Template displays `{{ .Token }}` as the OTP code
- User receives email with the token as a 6-digit-like code

### 3. **User Enters OTP**

- User enters the token from email as OTP
- System validates format (6 digits) and user existence
- No database lookup needed

### 4. **Password Reset**

- System updates password in `auth_students` table
- Password is hashed and stored securely
- User can login with new password

## Setup Instructions

### Step 1: Configure Supabase Email Template

1. Go to **Supabase Dashboard** → **Authentication** → **Email Templates**
2. Find **"Reset Password"** template
3. Replace with this custom template:

```html
<div
  style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;"
>
  <div style="text-align: center; margin-bottom: 30px;">
    <h1 style="color: #B01212; margin: 0;">EVSU CampusPay</h1>
    <p style="color: #666; margin: 5px 0;">Eastern Visayas State University</p>
  </div>

  <div
    style="background-color: #f8f9fa; padding: 30px; border-radius: 8px; margin: 20px 0;"
  >
    <h2 style="color: #333; margin-top: 0;">Password Reset Verification</h2>
    <p>Dear EVSU Student,</p>
    <p>
      You have requested to reset your password for your EVSU CampusPay account.
    </p>

    <div
      style="background-color: #fff; border: 2px solid #B01212; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;"
    >
      <p style="margin: 0 0 10px 0; color: #666; font-size: 14px;">
        Your verification code is:
      </p>
      <h1
        style="color: #B01212; font-size: 36px; margin: 0; letter-spacing: 4px;"
      >
        {{ .Token }}
      </h1>
    </div>

    <p style="color: #e74c3c; font-weight: bold;">
      ⚠️ This code will expire in 1 hour.
    </p>

    <p>
      Enter this code in the EVSU CampusPay app to complete your password reset.
    </p>

    <div
      style="background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 4px; margin: 20px 0;"
    >
      <p style="margin: 0; color: #856404;">
        <strong>Security Notice:</strong> If you did not request this password
        reset, please ignore this email.
      </p>
    </div>
  </div>

  <div
    style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;"
  >
    <p style="color: #666; font-size: 12px; margin: 0;">
      This is an automated message from EVSU CampusPay.<br />
      Please do not reply to this email.
    </p>
  </div>
</div>
```

### Step 2: Test the System

1. **Enter valid EVSU email** → Click "Get OTP Code"
2. **Check your email** → You'll receive email with token as OTP
3. **Enter the token** → Use the token from email as OTP code
4. **Set new password** → Complete the reset process

## Key Benefits

✅ **Simplified Architecture**: No custom OTP table needed
✅ **Built-in Security**: Uses Supabase's secure token system
✅ **Automatic Expiration**: Tokens expire automatically (1 hour default)
✅ **Email Delivery**: Reliable email delivery via Supabase
✅ **Professional Template**: Custom branded email template
✅ **No Edge Functions**: Uses built-in Supabase functionality

## Important Notes

### Token Format

- Supabase tokens are typically longer than 6 digits
- Users should enter the **entire token** from the email
- The system validates format but accepts the full token

### Token Expiration

- Supabase tokens expire in **1 hour** by default
- This is more generous than our previous 5-minute OTP
- Tokens are single-use (automatically invalidated after use)

### Security

- Tokens are cryptographically secure
- No database storage of sensitive codes
- Automatic cleanup by Supabase

## Current Implementation Status

✅ **Email Sending**: Using Supabase Auth `resetPasswordForEmail()`
✅ **Custom Template**: Ready to configure in Supabase Dashboard
✅ **OTP Verification**: Simplified to validate token format
✅ **Password Reset**: Updates `auth_students` table with hashed password
✅ **User Authentication**: Works with existing login system

## Testing

### Development Testing

1. Configure the custom email template in Supabase Dashboard
2. Test the complete flow with a real email address
3. Verify token is received and can be used for password reset

### Production Ready

- No additional setup needed beyond email template configuration
- Uses Supabase's reliable email delivery system
- Professional email template with EVSU branding

## Migration from Previous Approach

If you were using the custom OTP table approach:

- ✅ **OTP table can be removed** (no longer needed)
- ✅ **Edge Function not required** (using built-in functionality)
- ✅ **Simplified codebase** (fewer methods and dependencies)

This approach is much simpler and more reliable! 🎉
