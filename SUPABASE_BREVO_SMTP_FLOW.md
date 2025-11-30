# SUPABASE + BREVO SMTP — FUNCTION FLOW (PURE LOGIC)

## Overview

This document describes the complete email confirmation flow when using Supabase Authentication with Brevo (formerly Sendinblue) SMTP for email delivery.

## Function Flow

### Step 1: Admin Submits Signup Request
- Admin creates a new user account through the admin dashboard
- User registration data (email, password, student ID, etc.) is submitted
- The application calls `SupabaseService.registerStudent()` or similar registration method

### Step 2: Supabase Receives Request and Creates Unconfirmed User
- Supabase Auth receives the signup request via `client.auth.signUp()`
- A new user record is created in Supabase's `auth.users` table
- User status is set to **unconfirmed** (email not yet verified)
- User cannot fully access the system until email is confirmed

### Step 3: Supabase Generates Confirmation Token and Link
- Supabase automatically generates a unique confirmation token
- A confirmation link is constructed: `{SITE_URL}/auth/v1/verify?token={TOKEN}&type=signup`
- The token is cryptographically secure and time-limited (typically expires in 24 hours)

### Step 4: Supabase Retrieves Configured Email Template
- Supabase checks for a custom email template in the dashboard
- If no custom template exists, uses the default confirmation email template
- Template location: **Supabase Dashboard** → **Authentication** → **Email Templates** → **Confirm signup**

### Step 5: Supabase Injects Confirmation Link into Template
- Supabase replaces template variables with actual values:
  - `{{ .ConfirmationURL }}` → Full confirmation link with token
  - `{{ .Email }}` → User's email address
  - `{{ .Token }}` → Raw confirmation token (if needed)
- The email content is now complete and ready to send

### Step 6: Supabase Sends Email to Brevo via SMTP
- Supabase uses configured SMTP settings to connect to Brevo
- Email is sent via SMTP protocol to Brevo's mail servers
- SMTP configuration is set in: **Supabase Dashboard** → **Project Settings** → **Auth** → **SMTP Settings**

### Step 7: Brevo Receives and Delivers Email
- Brevo receives the email via SMTP
- Brevo processes the email (spam checking, validation, etc.)
- Brevo delivers the email to the user's inbox
- Email appears in user's inbox with subject line from template

### Step 8: User Opens Email and Clicks Confirmation Link
- User receives email in their inbox
- User opens the email and sees the confirmation message
- User clicks the confirmation link/button in the email
- Browser/app navigates to the confirmation URL

### Step 9: Supabase Receives Confirmation Request
- The confirmation link makes a request to Supabase Auth API
- Supabase extracts the token from the URL parameters
- Supabase validates the token (checks expiration, format, etc.)

### Step 10: Supabase Validates Token and Confirms Account
- Token validation occurs:
  - Token exists and is valid
  - Token hasn't expired
  - Token matches the user record
- If valid, Supabase updates the user record:
  - Sets `email_confirmed_at` timestamp
  - Changes user status from unconfirmed to confirmed

### Step 11: Supabase Updates User Record to Confirmed
- User record in `auth.users` table is updated:
  ```sql
  UPDATE auth.users 
  SET email_confirmed_at = NOW(), 
      updated_at = NOW()
  WHERE id = {user_id}
  ```
- User can now fully access the system

### Step 12: User Can Now Fully Access System
- User account is fully activated
- User can log in with their credentials
- All features requiring email verification are now accessible

---

## Configuration Guide

### Prerequisites
1. Brevo account (free tier available)
2. Supabase project with Auth enabled
3. Admin access to Supabase Dashboard

### Step 1: Configure Brevo SMTP Settings

#### 1.1 Get Brevo SMTP Credentials
1. Log in to your [Brevo account](https://www.brevo.com/)
2. Go to **Settings** → **SMTP & API**
3. Note down your SMTP credentials:
   - **SMTP Server**: `smtp-relay.brevo.com`
   - **Port**: `587` (TLS) or `465` (SSL)
   - **Username**: Your Brevo SMTP login email
   - **Password**: Your Brevo SMTP key (not your account password)

#### 1.2 Configure Supabase SMTP Settings
1. Go to **Supabase Dashboard** → Your Project
2. Navigate to **Project Settings** → **Auth**
3. Scroll down to **SMTP Settings**
4. Enable **Enable Custom SMTP**
5. Fill in the SMTP configuration:
   ```
   Host: smtp-relay.brevo.com
   Port: 587
   Username: [Your Brevo SMTP Username]
   Password: [Your Brevo SMTP Key]
   Sender email: noreply@evsu.edu.ph (or your verified domain)
   Sender name: EVSU CampusPay
   ```
6. Click **Save**

### Step 2: Configure Email Templates

#### 2.1 Customize Confirmation Email Template
1. Go to **Supabase Dashboard** → **Authentication** → **Email Templates**
2. Select **Confirm signup** template
3. Replace with custom template:

```html
<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="text-align: center; margin-bottom: 30px;">
    <h1 style="color: #B01212; margin: 0;">EVSU CampusPay</h1>
    <p style="color: #666; margin: 5px 0;">Eastern Visayas State University</p>
  </div>

  <div style="background-color: #f8f9fa; padding: 30px; border-radius: 8px; margin: 20px 0;">
    <h2 style="color: #333; margin-top: 0;">Welcome to EVSU CampusPay!</h2>
    <p>Dear {{ .Email }},</p>
    <p>
      Thank you for registering with EVSU CampusPay. To complete your registration and activate your account, 
      please confirm your email address by clicking the button below.
    </p>

    <div style="text-align: center; margin: 30px 0;">
      <a href="{{ .ConfirmationURL }}" 
         style="background-color: #B01212; color: white; padding: 15px 30px; 
                text-decoration: none; border-radius: 5px; display: inline-block; 
                font-weight: bold;">
        Confirm Email Address
      </a>
    </div>

    <p style="color: #666; font-size: 14px;">
      Or copy and paste this link into your browser:<br>
      <a href="{{ .ConfirmationURL }}" style="color: #B01212; word-break: break-all;">
        {{ .ConfirmationURL }}
      </a>
    </p>

    <div style="background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; 
                border-radius: 4px; margin: 20px 0;">
      <p style="margin: 0; color: #856404;">
        <strong>Security Notice:</strong> This confirmation link will expire in 24 hours. 
        If you did not create an account, please ignore this email.
      </p>
    </div>
  </div>

  <div style="text-align: center; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
    <p style="color: #666; font-size: 12px; margin: 0;">
      This is an automated message from EVSU CampusPay.<br>
      Please do not reply to this email.
    </p>
    <p style="color: #666; font-size: 12px; margin: 5px 0 0 0;">
      Eastern Visayas State University | EVSU CampusPay Team
    </p>
  </div>
</div>
```

4. Click **Save**

### Step 3: Configure Site URL

1. Go to **Supabase Dashboard** → **Project Settings** → **Auth**
2. Set **Site URL** to your application's URL:
   ```
   https://your-app-domain.com
   ```
   Or for development:
   ```
   http://localhost:3000
   ```
3. Add **Redirect URLs** if needed:
   ```
   https://your-app-domain.com/auth/callback
   ```

### Step 4: Test the Flow

#### 4.1 Test User Registration
1. Use your admin dashboard to create a test user
2. Check that the user receives a confirmation email
3. Verify email is delivered via Brevo (check Brevo dashboard for delivery status)

#### 4.2 Test Email Confirmation
1. Click the confirmation link in the test email
2. Verify user account is confirmed in Supabase Dashboard
3. Verify user can now log in successfully

---

## Code Implementation

### Current Implementation

The current codebase already implements Step 1 (Admin signup request) in `supabase_service.dart`:

```1073:1082:final_ecampuspay/lib/services/supabase_service.dart
      final authResponse = await client.auth.signUp(
        email: email.toLowerCase(),
        password: password,
        data: {
          'student_id': studentId,
          'name': name,
          'course': course,
          'rfid_id': rfidId,
        },
      );
```

### How It Works with Brevo SMTP

Once Brevo SMTP is configured in Supabase Dashboard:
- Steps 2-6 happen automatically when `signUp()` is called
- Supabase handles token generation, template injection, and SMTP sending
- No code changes needed in the Flutter application
- The confirmation email will be delivered via Brevo instead of Supabase's default email service

### Email Confirmation Check

The codebase already checks for email confirmation before allowing login:

```267:279:final_ecampuspay/lib/services/session_service.dart
      // Step 1.5: Check if email is confirmed before attempting login
      try {
        final adminUser = await SupabaseService.adminClient.auth.admin
            .getUserById(authUserId);

        // Check if email is confirmed
        if (adminUser.user?.emailConfirmedAt == null) {
          return {
            'success': false,
            'message':
                'Please confirm your email before logging in. Check your inbox for the confirmation email.',
          };
        }
      } catch (adminError) {
        // If we can't check email confirmation status, log it but continue with login attempt
        // The login will fail with appropriate error if email is not confirmed
        print('DEBUG: Could not check email confirmation status: $adminError');
      }
```

---

## Troubleshooting

### Email Not Being Sent
1. **Check Brevo SMTP Settings**: Verify credentials in Supabase Dashboard
2. **Check Brevo Dashboard**: Look for failed delivery attempts
3. **Verify Sender Email**: Ensure sender email is verified in Brevo
4. **Check Spam Folder**: Emails might be filtered as spam

### Confirmation Link Not Working
1. **Check Site URL**: Verify Site URL is correct in Supabase settings
2. **Check Token Expiration**: Tokens expire after 24 hours by default
3. **Verify Redirect URLs**: Ensure redirect URLs are whitelisted

### Email Template Not Rendering
1. **Check Template Syntax**: Ensure Go template syntax is correct (`{{ .Variable }}`)
2. **Test Template**: Use Supabase's "Send test email" feature
3. **Check HTML**: Ensure HTML is valid and properly formatted

---

## Benefits of Using Brevo SMTP

1. **Better Deliverability**: Brevo has high email delivery rates
2. **Email Analytics**: Track opens, clicks, and bounces
3. **Custom Branding**: Use your own domain for sending emails
4. **Scalability**: Handle high email volumes reliably
5. **Cost-Effective**: Free tier available for low volumes

---

## Security Considerations

1. **SMTP Credentials**: Never commit SMTP credentials to version control
2. **Token Security**: Confirmation tokens are cryptographically secure
3. **Expiration**: Tokens expire after 24 hours for security
4. **HTTPS**: Always use HTTPS for confirmation links in production
5. **Domain Verification**: Verify your sending domain in Brevo to prevent spoofing

---

## Additional Resources

- [Supabase Auth Documentation](https://supabase.com/docs/guides/auth)
- [Brevo SMTP Documentation](https://developers.brevo.com/docs/send-emails-with-smtp)
- [Supabase Email Templates Guide](https://supabase.com/docs/guides/auth/auth-email-templates)




