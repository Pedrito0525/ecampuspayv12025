// Supabase Edge Function for sending OTP emails
// Save this as: supabase/functions/send-otp-email/index.ts

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

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

    // Validate input
    if (!email || !otp_code) {
      throw new Error("Email and OTP code are required");
    }

    // Send email using Resend (recommended) or your preferred service
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
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
            <div style="text-align: center; margin-bottom: 30px;">
              <h1 style="color: #B01212; margin: 0;">EVSU CampusPay</h1>
              <p style="color: #666; margin: 5px 0;">Eastern Visayas State University</p>
            </div>
            
            <div style="background-color: #f8f9fa; padding: 30px; border-radius: 8px; margin: 20px 0;">
              <h2 style="color: #333; margin-top: 0;">Password Reset Verification</h2>
              <p>Dear EVSU Student,</p>
              <p>You have requested to reset your password for your EVSU CampusPay account.</p>
              
              <div style="background-color: #fff; border: 2px solid #B01212; padding: 20px; text-align: center; margin: 20px 0; border-radius: 8px;">
                <p style="margin: 0 0 10px 0; color: #666; font-size: 14px;">Your verification code is:</p>
                <h1 style="color: #B01212; font-size: 36px; margin: 0; letter-spacing: 4px;">${otp_code}</h1>
              </div>
              
              <p style="color: #e74c3c; font-weight: bold;">⚠️ This code will expire in 5 minutes.</p>
              
              <p>Enter this code in the EVSU CampusPay app to complete your password reset.</p>
              
              <div style="background-color: #fff3cd; border: 1px solid #ffeaa7; padding: 15px; border-radius: 4px; margin: 20px 0;">
                <p style="margin: 0; color: #856404;"><strong>Security Notice:</strong> If you did not request this password reset, please ignore this email and contact support if you have concerns.</p>
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
        `,
      }),
    });

    if (!emailResponse.ok) {
      const errorText = await emailResponse.text();
      console.error("Email service error:", errorText);
      throw new Error("Failed to send email");
    }

    const result = await emailResponse.json();
    console.log("Email sent successfully:", result);

    return new Response(
      JSON.stringify({
        success: true,
        message: "OTP email sent successfully",
        email_id: result.id,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Error sending OTP email:", error);

    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      }),
      {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});

// Alternative email service integrations:

// For SendGrid:
/*
const emailResponse = await fetch('https://api.sendgrid.com/v3/mail/send', {
  method: 'POST',
  headers: {
    'Authorization': `Bearer ${Deno.env.get('SENDGRID_API_KEY')}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({
    personalizations: [{
      to: [{ email }],
      subject: 'EVSU CampusPay - Password Reset Verification Code',
    }],
    from: { email: 'noreply@evsu.edu.ph', name: 'EVSU CampusPay' },
    content: [{
      type: 'text/html',
      value: htmlTemplate
    }],
  }),
})
*/

// For Mailgun:
/*
const emailResponse = await fetch(`https://api.mailgun.net/v3/${Deno.env.get('MAILGUN_DOMAIN')}/messages`, {
  method: 'POST',
  headers: {
    'Authorization': `Basic ${btoa(`api:${Deno.env.get('MAILGUN_API_KEY')}`)}`,
  },
  body: new URLSearchParams({
    from: 'EVSU CampusPay <noreply@evsu.edu.ph>',
    to: email,
    subject: 'EVSU CampusPay - Password Reset Verification Code',
    html: htmlTemplate,
  }),
})
*/
