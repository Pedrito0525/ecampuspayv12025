# Supabase Auth Custom Email Template for OTP

## Overview

This approach uses Supabase's built-in email system with a customized template to send OTP codes instead of password reset links.

## Step 1: Configure Supabase Dashboard

### 1.1 Access Email Templates

1. Go to your **Supabase Dashboard**
2. Navigate to **Authentication** → **Email Templates**
3. Find the **"Reset Password"** template

### 1.2 Replace Default Template

Replace the default HTML with this custom template:

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
      ⚠️ This code will expire in 5 minutes.
    </p>

    <p>
      Enter this code in the EVSU CampusPay app to complete your password reset.
    </p>

    <div
      style="background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 4px; margin: 20px 0;"
    >
      <p style="margin: 0; color: #856404;">
        <strong>Security Notice:</strong> If you did not request this password
        reset, please ignore this email and contact support if you have
        concerns.
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
    <p style="color: #666; font-size: 12px; margin: 5px 0 0 0;">
      Eastern Visayas State University | EVSU CampusPay Team
    </p>
  </div>
</div>
```

### 1.3 Key Template Variables

- `{{ .Token }}` - This will contain your OTP code (6-digit number)
- `{{ .ConfirmationURL }}` - Available but not used in this template
- `{{ .Email }}` - Available if you want to personalize

## Step 2: How It Works

### 2.1 Flow Explanation

1. **User requests OTP** → `sendPasswordResetOTP()` is called
2. **OTP is generated** → 6-digit code created and stored in `password_reset_otp` table
3. **Supabase Auth is called** → `resetPasswordForEmail()` triggers email sending
4. **Custom template is used** → Supabase uses your custom template instead of default
5. **OTP is displayed** → `{{ .Token }}` shows the 6-digit OTP code
6. **User receives email** → Professional-looking email with OTP code

### 2.2 Important Notes

- **`{{ .Token }}`** in Supabase Auth templates contains a **random token**, not your OTP
- **We need to modify the approach** to use your actual OTP code

## Step 3: Modified Approach (Recommended)

Since `{{ .Token }}` doesn't contain our custom OTP, we need a different approach:

### 3.1 Option A: Use Edge Function (Better)

Keep using the Edge Function approach with the custom email template from the Edge Function.

### 3.2 Option B: Hybrid Approach

1. Send email via Supabase Auth (for delivery reliability)
2. Store OTP in database
3. User enters OTP from database (not from email)

### 3.3 Option C: Custom Template with Database Lookup

Modify the template to include instructions to check the app for the OTP:

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
        Your verification code has been generated
      </p>
      <h1 style="color: #B01212; font-size: 24px; margin: 0;">
        Check your EVSU CampusPay app
      </h1>
    </div>

    <p style="color: #e74c3c; font-weight: bold;">
      ⚠️ The verification code will expire in 5 minutes.
    </p>

    <p>
      Return to the EVSU CampusPay app and enter the verification code to
      complete your password reset.
    </p>

    <div
      style="background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 4px; margin: 20px 0;"
    >
      <p style="margin: 0; color: #856404;">
        <strong>Security Notice:</strong> If you did not request this password
        reset, please ignore this email and contact support if you have
        concerns.
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
    <p style="color: #666; font-size: 12px; margin: 5px 0 0 0;">
      Eastern Visayas State University | EVSU CampusPay Team
    </p>
  </div>
</div>
```

## Step 4: Testing

### 4.1 Development Testing

1. Enter valid EVSU email
2. Click "Get OTP Code"
3. Check console for OTP code
4. Use OTP in app (ignore email for now)

### 4.2 Production Testing

1. Set up custom email template in Supabase Dashboard
2. Test email delivery
3. Verify template rendering
4. Test OTP verification flow

## Step 5: Current Implementation Status

✅ **OTP Generation**: Working
✅ **Database Storage**: Working with encrypted emails
✅ **OTP Verification**: Working
✅ **Password Reset**: Working
✅ **Email Simulation**: Working (console logs)
🔄 **Email Template**: Ready to configure in Supabase Dashboard

## Recommendations

### For Development

- Keep using console logs for OTP codes
- Test the full flow without relying on email delivery

### For Production

1. **Best Option**: Use Supabase Edge Function with proper email service (SendGrid, Mailgun, etc.)
2. **Alternative**: Use the hybrid approach with custom Supabase template
3. **Fallback**: Keep console logging as backup for testing

The current implementation is fully functional - you can test the complete OTP flow using the console logs while setting up the email delivery system.
