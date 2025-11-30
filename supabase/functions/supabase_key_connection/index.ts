import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-ecampuspay-secret",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get the secret from request header or body
    const secretHeader = req.headers.get("x-ecampuspay-secret");
    const body = await req.json().catch(() => ({}));
    const secretBody = body.secret || body.app_secret;

    const providedSecret = secretHeader || secretBody;

    // Get expected secret from environment variable
    const expectedSecret = Deno.env.get("ECAMPUSPAY_SECRET");

    // Validate secret
    if (!expectedSecret) {
      console.error("ECAMPUSPAY_SECRET not configured in Edge Function");
      return new Response(
        JSON.stringify({
          success: false,
          error: "Server configuration error",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!providedSecret || providedSecret !== expectedSecret) {
      console.error("Invalid secret provided");
      return new Response(
        JSON.stringify({
          success: false,
          error: "Unauthorized access",
        }),
        {
          status: 401,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Get Supabase keys from environment variables
    // Note: Using APP_ prefix because Supabase doesn't allow secrets starting with SUPABASE_
    const supabaseUrl = Deno.env.get("APP_SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("APP_ANON_KEY");
    const supabaseServiceRoleKey = Deno.env.get("APP_SERVICE_ROLE_KEY");

    // Validate all required keys are present
    if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
      console.error("Missing Supabase configuration in environment");
      console.error(
        "Required secrets: APP_SUPABASE_URL, APP_ANON_KEY, APP_SERVICE_ROLE_KEY"
      );
      return new Response(
        JSON.stringify({
          success: false,
          error:
            "Server configuration incomplete. Please set APP_SUPABASE_URL, APP_ANON_KEY, and APP_SERVICE_ROLE_KEY secrets.",
        }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Return the keys
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          supabaseUrl: supabaseUrl,
          supabaseAnonKey: supabaseAnonKey,
          supabaseServiceRoleKey: supabaseServiceRoleKey,
        },
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error in supabase_key_connection:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message || "Internal server error",
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
