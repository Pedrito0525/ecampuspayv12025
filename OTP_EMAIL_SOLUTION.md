# OTP Email Sending Solution

## Problem

Supabase Auth's `resetPasswordForEmail` sends a password reset link, not an OTP code. We need to send actual OTP codes via email.

## Current Implementation

The system now:

1. ✅ Generates 6-digit OTP codes
2. ✅ Stores OTP in `password_reset_otp` table with encrypted email
3. ✅ Verifies OTP codes correctly
4. ✅ Resets passwords after OTP verification
5. ⚠️ **Simulates email sending** (logs OTP to console for development)

## Production Email Solutions

### Option 1: Supabase Edge Function (Recommended)

Create a Supabase Edge Function to send emails:

#### 1. Create Edge Function

```bash
supabase functions new send-otp-email
```

#### 2. Edge Function Code (`supabase/functions/send-otp-email/index.ts`)

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, otp_code } = await req.json();

    // Send email using your preferred email service
    // Example with Resend (recommended)
    const emailResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${Deno.env.get("RESEND_API_KEY")}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: "EVSU CampusPay <noreply@evsu.edu.ph>",
        to: [email],
        subject: "EVSU CampusPay - Password Reset Verification Code",
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #B01212;">EVSU CampusPay</h2>
            <p>Dear EVSU Student,</p>
            <p>You have requested to reset your password for your EVSU CampusPay account.</p>
            <div style="background-color: #f5f5f5; padding: 20px; text-align: center; margin: 20px 0;">
              <h1 style="color: #B01212; font-size: 32px; margin: 0;">${otp_code}</h1>
            </div>
            <p>This code will expire in 5 minutes.</p>
            <p>If you did not request this password reset, please ignore this email.</p>
            <p>Best regards,<br>EVSU CampusPay Team</p>
          </div>
        `,
      }),
    });

    if (!emailResponse.ok) {
      throw new Error("Failed to send email");
    }

    return new Response(
      JSON.stringify({ success: true, message: "OTP email sent successfully" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
```

#### 3. Update SupabaseService

Uncomment the Edge Function code in `_sendOTPEmail` method:

```dart
final response = await client.functions.invoke(
  'send-otp-email',
  body: {
    'email': email,
    'otp_code': otpCode,
  },
);

if (response.status != 200) {
  throw Exception('Failed to send OTP email via Edge Function');
}
```

### Option 2: Third-Party Email Services

#### SendGrid Integration

```dart
static Future<void> _sendOTPEmail(String email, String otpCode) async {
  final response = await http.post(
    Uri.parse('https://api.sendgrid.com/v3/mail/send'),
    headers: {
      'Authorization': 'Bearer ${YourSendGridApiKey}',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'personalizations': [
        {
          'to': [{'email': email}],
          'subject': 'EVSU CampusPay - Password Reset Verification Code',
        }
      ],
      'from': {'email': 'noreply@evsu.edu.ph', 'name': 'EVSU CampusPay'},
      'content': [
        {
          'type': 'text/html',
          'value': '''
            <div style="font-family: Arial, sans-serif;">
              <h2>EVSU CampusPay - Password Reset</h2>
              <p>Your verification code is: <strong>${otpCode}</strong></p>
              <p>This code expires in 5 minutes.</p>
            </div>
          ''',
        }
      ],
    }),
  );

  if (response.statusCode != 202) {
    throw Exception('Failed to send email via SendGrid');
  }
}
```

#### Mailgun Integration

```dart
static Future<void> _sendOTPEmail(String email, String otpCode) async {
  final response = await http.post(
    Uri.parse('https://api.mailgun.net/v3/${YourMailgunDomain}/messages'),
    headers: {
      'Authorization': 'Basic ${base64Encode(utf8.encode('api:${YourMailgunApiKey}'))}',
    },
    body: {
      'from': 'EVSU CampusPay <noreply@evsu.edu.ph>',
      'to': email,
      'subject': 'EVSU CampusPay - Password Reset Verification Code',
      'html': '''
        <div style="font-family: Arial, sans-serif;">
          <h2>EVSU CampusPay - Password Reset</h2>
          <p>Your verification code is: <strong>${otpCode}</strong></p>
          <p>This code expires in 5 minutes.</p>
        </div>
      ''',
    },
  );

  if (response.statusCode != 200) {
    throw Exception('Failed to send email via Mailgun');
  }
}
```

### Option 3: SMTP Email Sending

Add `mailer` package to `pubspec.yaml`:

```yaml
dependencies:
  mailer: ^6.1.4
```

```dart
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

static Future<void> _sendOTPEmail(String email, String otpCode) async {
  final smtpServer = SmtpServer(
    'smtp.gmail.com',
    port: 587,
    username: 'your-email@gmail.com',
    password: 'your-app-password',
    allowInsecure: false,
    ignoreBadCertificate: true,
  );

  final message = Message()
    ..from = Address('your-email@gmail.com', 'EVSU CampusPay')
    ..recipients.add(email)
    ..subject = 'EVSU CampusPay - Password Reset Verification Code'
    ..html = '''
      <div style="font-family: Arial, sans-serif;">
        <h2>EVSU CampusPay - Password Reset</h2>
        <p>Your verification code is: <strong>${otpCode}</strong></p>
        <p>This code expires in 5 minutes.</p>
      </div>
    ''';

  try {
    await send(message, smtpServer);
  } catch (e) {
    throw Exception('Failed to send email: $e');
  }
}
```

## Testing the Current Implementation

### Development Testing

1. Enter a valid EVSU email address
2. Click "Get OTP Code"
3. Check the console/logs for the OTP code
4. Enter the OTP code in the app
5. Complete the password reset

### Console Output Example

```
============================================================
📧 OTP EMAIL SIMULATION
============================================================
To: john.doe@evsu.edu.ph
Subject: EVSU CampusPay - Password Reset Verification Code

Dear EVSU Student,

You have requested to reset your password for your EVSU CampusPay account.

Your verification code is: 123456

This code will expire in 5 minutes.

If you did not request this password reset, please ignore this email.

Best regards,
EVSU CampusPay Team
============================================================
```

## Production Deployment Steps

1. **Choose Email Service**: Select one of the options above
2. **Set Up Credentials**: Add API keys to environment variables
3. **Update Code**: Replace the simulation code with actual email sending
4. **Test**: Verify emails are being sent and received
5. **Monitor**: Set up email delivery monitoring

## Security Considerations

- ✅ OTP codes expire in 5 minutes
- ✅ OTP codes are single-use
- ✅ Email addresses are encrypted in database
- ✅ Rate limiting can be implemented
- ✅ Email templates should be professional
- ✅ Consider adding CAPTCHA for additional security

## Next Steps

1. **Immediate**: Use console logs for development testing
2. **Short-term**: Implement Supabase Edge Function with email service
3. **Long-term**: Add email delivery monitoring and analytics
4. **Enhancement**: Add SMS OTP as backup option

The system is fully functional - you just need to implement the actual email sending service of your choice!
