import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

/// Supabase configuration class that fetches configuration from Edge Function
///
/// This class fetches Supabase keys securely from a Supabase Edge Function
/// instead of storing them in the client app, improving security.
class SupabaseConfig {
  // Cache for fetched keys
  static String? _cachedSupabaseUrl;
  static String? _cachedSupabaseAnonKey;
  static String? _cachedSupabaseServiceKey;
  static bool _isInitialized = false;
  static bool _isInitializing = false;

  // Supabase project reference (public information, used to build Edge Function URL)
  // This should be set to your Supabase project reference (the part before .supabase.co)
  // Can also be loaded from .env if SUPABASE_URL is still present, otherwise use this constant
  static String get _supabaseProjectRef {
    // Try to extract from SUPABASE_URL in .env if available
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    if (supabaseUrl != null && supabaseUrl.isNotEmpty) {
      final uri = Uri.tryParse(supabaseUrl);
      if (uri != null && uri.host.contains('.supabase.co')) {
        final parts = uri.host.split('.');
        if (parts.isNotEmpty) {
          final projectRef = parts[0];
          print(
            'DEBUG SupabaseConfig: Extracted project reference from .env: $projectRef',
          );
          return projectRef;
        }
      }
    }
    // Fallback to constant (update this with your actual project reference)
    // You can find this in your Supabase Dashboard → Settings → General → Reference ID
    print(
      'WARNING SupabaseConfig: Using hardcoded project reference. Consider adding SUPABASE_URL to .env',
    );
    return 'weesdfhgwyuozivhedhej';
  }

  // Initialize by fetching keys from Edge Function
  // Call this in main() before runApp()
  static Future<void> initialize() async {
    if (_isInitialized) {
      return; // Already initialized
    }

    if (_isInitializing) {
      // Wait for ongoing initialization to complete
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return;
    }

    _isInitializing = true;

    try {
      // Load .env file for ECAMPUSPAY_SECRET only
      await dotenv.load(fileName: ".env");

      // Get app secret for authentication
      final appSecret = dotenv.env['ECAMPUSPAY_SECRET'];
      if (appSecret == null || appSecret.isEmpty) {
        throw StateError(
          'Missing required env: ECAMPUSPAY_SECRET (needed to authenticate with Edge Function)',
        );
      }

      // Get optional anon key for JWT authentication (if JWT verification is enabled)
      final anonKeyForJWT = dotenv.env['SUPABASE_ANON_KEY'];

      // Get project reference (auto-detect from .env or use fallback)
      final projectRef = _supabaseProjectRef;

      // Build Edge Function URL
      final edgeFunctionUrl =
          'https://$projectRef.supabase.co/functions/v1/supabase_key_connection';

      print('═══════════════════════════════════════════════════════════');
      print('🔍 DEBUG: Supabase Configuration Initialization');
      print('═══════════════════════════════════════════════════════════');
      print('📍 Project Reference: $projectRef');
      print('🌐 Edge Function URL: $edgeFunctionUrl');
      print(
        '🔑 ECAMPUSPAY_SECRET: ${appSecret.isNotEmpty ? "✓ Set (${appSecret.length} chars)" : "✗ Missing"}',
      );
      // Show first and last 3 chars of secret for debugging (masked for security)
      if (appSecret.isNotEmpty) {
        final maskedSecret =
            appSecret.length > 6
                ? '${appSecret.substring(0, 3)}...${appSecret.substring(appSecret.length - 3)}'
                : '***';
        print('   └─ Value: $maskedSecret (first 3 + last 3 chars shown)');
      }
      // Note: JWT authentication is optional. ECAMPUSPAY_SECRET provides sufficient security.
      if (anonKeyForJWT != null && anonKeyForJWT.isNotEmpty) {
        print('🔐 SUPABASE_ANON_KEY: ✓ Set (optional, for JWT authentication)');
        print('   └─ JWT verification can be enabled or disabled');
      } else {
        print('🔐 SUPABASE_ANON_KEY: ✓ Not required (recommended setup)');
        print(
          '   └─ Using ECAMPUSPAY_SECRET only - JWT verification should be DISABLED',
        );
      }
      print('───────────────────────────────────────────────────────────');

      // Step 1: Check Edge Function accessibility
      print('📡 Step 1: Checking Edge Function accessibility...');
      http.Response response;
      try {
        // Build headers - include JWT if anon key is available
        final headers = <String, String>{
          'Content-Type': 'application/json',
          'x-ecampuspay-secret': appSecret,
        };

        // Add JWT Authorization header if anon key is available (optional, for JWT verification)
        if (anonKeyForJWT != null && anonKeyForJWT.isNotEmpty) {
          headers['Authorization'] = 'Bearer $anonKeyForJWT';
          headers['apikey'] =
              anonKeyForJWT; // Also include apikey header for Supabase
          print('   └─ JWT headers included (if JWT verification is enabled)');
        } else {
          print(
            '   └─ Using ECAMPUSPAY_SECRET authentication only (JWT disabled)',
          );
        }

        response = await http
            .post(
              Uri.parse(edgeFunctionUrl),
              headers: headers,
              body: jsonEncode({'secret': appSecret}),
            )
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                print(
                  '❌ Step 1 FAILED: Edge Function request timed out after 10 seconds',
                );
                throw TimeoutException(
                  'Failed to fetch Supabase keys: Edge Function request timed out. '
                  'Please ensure the Edge Function is deployed and accessible at: $edgeFunctionUrl',
                );
              },
            );

        print('✓ Step 1 PASSED: Edge Function is accessible');
        print('  └─ HTTP Status Code: ${response.statusCode}');
      } catch (e) {
        if (e is TimeoutException) {
          rethrow;
        }
        print('❌ Step 1 FAILED: Cannot reach Edge Function');
        print('  └─ Error: $e');
        print('───────────────────────────────────────────────────────────');
        print('💡 Troubleshooting:');
        print('   1. Verify Edge Function is deployed:');
        print('      supabase functions deploy supabase_key_connection');
        print('   2. Check if project reference "$projectRef" is correct');
        print('      Current project reference: $projectRef');
        print('      Edge Function URL: $edgeFunctionUrl');
        if (dotenv.env['SUPABASE_URL'] == null ||
            dotenv.env['SUPABASE_URL']!.isEmpty) {
          print('   3. ⚠️  SUPABASE_URL not found in .env file');
          print('      Add this line to final_ecampuspay/.env to auto-detect:');
          print('      SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co');
          print(
            '      (Replace YOUR_PROJECT_REF with your actual project reference)',
          );
        }
        print('   4. Verify internet connection');
        print(
          '   5. Check Supabase Dashboard → Settings → General → Reference ID',
        );
        print('═══════════════════════════════════════════════════════════');
        rethrow;
      }

      // Step 2: Validate response status
      print('───────────────────────────────────────────────────────────');
      print('📋 Step 2: Validating Edge Function response...');
      if (response.statusCode != 200) {
        String errorMessage = 'Unknown error';
        Map<String, dynamic>? errorBody;
        try {
          errorBody = jsonDecode(response.body) as Map<String, dynamic>;
          errorMessage = errorBody['error']?.toString() ?? errorMessage;
        } catch (_) {
          errorMessage =
              response.body.isNotEmpty
                  ? response.body
                  : 'No error message in response';
        }

        print('❌ Step 2 FAILED: Edge Function returned error');
        print('  └─ HTTP Status: ${response.statusCode}');
        print('  └─ Error Message: $errorMessage');
        print('  └─ Response Body: ${response.body}');
        print('───────────────────────────────────────────────────────────');
        print('💡 Possible Issues:');
        if (response.statusCode == 401) {
          print('   🔒 AUTHENTICATION FAILED (401 Unauthorized)');
          print('   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

          // Check if JWT verification might be the issue
          if (anonKeyForJWT == null || anonKeyForJWT.isEmpty) {
            print('   ⚠️  JWT Verification is likely ENABLED in Edge Function');
            print('      but SUPABASE_ANON_KEY is not set in .env');
            print('');
            print('   ✅ RECOMMENDED SOLUTION: Disable JWT Verification');
            print(
              '      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
            );
            print('      1. Go to Supabase Dashboard');
            print(
              '      2. Navigate to: Edge Functions → supabase_key_connection → Settings',
            );
            print('      3. Find "Verify JWT with legacy secret"');
            print('      4. Turn it OFF (disable)');
            print('      5. ECAMPUSPAY_SECRET provides sufficient security');
            print(
              '      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━',
            );
            print('');
            print(
              '   💡 Alternative: Add SUPABASE_ANON_KEY to .env (if you want JWT enabled)',
            );
            print('      Add this line to final_ecampuspay/.env:');
            print('      SUPABASE_ANON_KEY=your-anon-key-here');
            print('      (Get it from Supabase Dashboard → Settings → API)');
            print('');
          }

          print('   ❌ ECAMPUSPAY_SECRET mismatch detected!');
          print('');
          print('   🔍 Debugging Info:');
          final maskedSecret =
              appSecret.length > 6
                  ? '${appSecret.substring(0, 3)}...${appSecret.substring(appSecret.length - 3)}'
                  : '***';
          print('      • Secret sent from app: $maskedSecret');
          print('      • Secret length: ${appSecret.length} chars');
          if (anonKeyForJWT != null && anonKeyForJWT.isNotEmpty) {
            print('      • JWT Auth: ✓ Enabled (using SUPABASE_ANON_KEY)');
          } else {
            print(
              '      • JWT Auth: ✗ Disabled (no SUPABASE_ANON_KEY in .env)',
            );
          }
          print('');
          print('   ✅ Fix Steps:');
          print('      1. Check final_ecampuspay/.env file contains:');
          print('         ECAMPUSPAY_SECRET=EvsupayCampus');
          if (anonKeyForJWT == null || anonKeyForJWT.isEmpty) {
            print('         SUPABASE_ANON_KEY=your-anon-key (if JWT enabled)');
          }
          print('         (Exact match, case-sensitive, no extra spaces)');
          print('');
          print('      2. Go to Supabase Dashboard → Edge Functions → Secrets');
          print('         Find "ECAMPUSPAY_SECRET" and verify value is:');
          print('         EvsupayCampus');
          print('         (Must match exactly, case-sensitive)');
          print('');
          print('      3. Check Edge Function JWT Verification setting:');
          print(
            '         Dashboard → Edge Functions → supabase_key_connection → Settings',
          );
          print('         If "Verify JWT with legacy secret" is ON:');
          print('         - Add SUPABASE_ANON_KEY to .env file');
          print('         - Or disable JWT verification (recommended)');
          print('');
          print('      4. Common issues:');
          print('         • Extra spaces before/after the value');
          print('         • Case mismatch (EvsupayCampus vs Evsupaycampus)');
          print('         • Typos in the secret value');
          print('         • Secret not set in Supabase Dashboard');
          print('         • JWT verification enabled but no anon key provided');
          print('');
          print('      5. After fixing, redeploy Edge Function:');
          print('         supabase functions deploy supabase_key_connection');
        } else if (response.statusCode == 500) {
          print('   • Edge Function configuration error');
          print('     - Check Edge Function logs in Supabase Dashboard');
          print('     - Verify all required secrets are set:');
          print('       - APP_SUPABASE_URL');
          print('       - APP_ANON_KEY');
          print('       - APP_SERVICE_ROLE_KEY');
          print('       - ECAMPUSPAY_SECRET');
        }
        print('═══════════════════════════════════════════════════════════');

        throw StateError(
          'Failed to fetch Supabase keys from Edge Function (Status ${response.statusCode}): $errorMessage. '
          'Please ensure:\n'
          '1. Edge Function is deployed: supabase functions deploy supabase_key_connection\n'
          '2. Edge Function secrets are configured in Supabase Dashboard:\n'
          '   - APP_SUPABASE_URL\n'
          '   - APP_ANON_KEY\n'
          '   - APP_SERVICE_ROLE_KEY\n'
          '   - ECAMPUSPAY_SECRET\n'
          '3. ECAMPUSPAY_SECRET in .env matches the secret in Edge Function',
        );
      }
      print('✓ Step 2 PASSED: Edge Function responded successfully');

      // Step 3: Parse response data
      print('───────────────────────────────────────────────────────────');
      print('📦 Step 3: Parsing Edge Function response...');
      Map<String, dynamic> responseData;
      try {
        responseData = jsonDecode(response.body) as Map<String, dynamic>;
        print('✓ Step 3 PASSED: Response parsed successfully');
      } catch (e) {
        print('❌ Step 3 FAILED: Invalid JSON response');
        print('  └─ Error: $e');
        print(
          '  └─ Response body: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}...',
        );
        print('═══════════════════════════════════════════════════════════');
        throw StateError('Invalid response from Edge Function: $e');
      }

      if (responseData['success'] != true) {
        final errorMsg = responseData['error'] ?? 'Unknown error';
        print('❌ Step 3 FAILED: Edge Function returned error in response');
        print('  └─ Error: $errorMsg');
        print('═══════════════════════════════════════════════════════════');
        throw StateError(
          'Failed to fetch Supabase keys: $errorMsg. '
          'Please check Edge Function logs and configuration.',
        );
      }

      // Step 4: Validate secrets are present in response
      print('───────────────────────────────────────────────────────────');
      print('🔐 Step 4: Validating secrets from Edge Function...');
      final data = responseData['data'] as Map<String, dynamic>?;

      if (data == null) {
        print('❌ Step 4 FAILED: Response data is missing');
        print('═══════════════════════════════════════════════════════════');
        throw StateError('No data received from Edge Function');
      }

      // Check each secret individually
      final supabaseUrlRaw = data['supabaseUrl']?.toString();
      final supabaseAnonKeyRaw = data['supabaseAnonKey']?.toString();
      final supabaseServiceKeyRaw = data['supabaseServiceRoleKey']?.toString();

      print('  Checking APP_SUPABASE_URL...');
      if (supabaseUrlRaw == null || supabaseUrlRaw.isEmpty) {
        print('  ❌ APP_SUPABASE_URL: Missing or empty');
        throw StateError(
          'APP_SUPABASE_URL secret is missing in Edge Function. '
          'Please set it in Supabase Dashboard → Edge Functions → Secrets',
        );
      }
      print('  ✓ APP_SUPABASE_URL: Present (${supabaseUrlRaw.length} chars)');

      print('  Checking APP_ANON_KEY...');
      if (supabaseAnonKeyRaw == null || supabaseAnonKeyRaw.isEmpty) {
        print('  ❌ APP_ANON_KEY: Missing or empty');
        throw StateError(
          'APP_ANON_KEY secret is missing in Edge Function. '
          'Please set it in Supabase Dashboard → Edge Functions → Secrets',
        );
      }
      print('  ✓ APP_ANON_KEY: Present (${supabaseAnonKeyRaw.length} chars)');

      print('  Checking APP_SERVICE_ROLE_KEY...');
      if (supabaseServiceKeyRaw == null || supabaseServiceKeyRaw.isEmpty) {
        print('  ❌ APP_SERVICE_ROLE_KEY: Missing or empty');
        throw StateError(
          'APP_SERVICE_ROLE_KEY secret is missing in Edge Function. '
          'Please set it in Supabase Dashboard → Edge Functions → Secrets',
        );
      }
      print(
        '  ✓ APP_SERVICE_ROLE_KEY: Present (${supabaseServiceKeyRaw.length} chars)',
      );

      // Cache the fetched keys
      _cachedSupabaseUrl = _ensureHttps(supabaseUrlRaw);
      _cachedSupabaseAnonKey = supabaseAnonKeyRaw;
      _cachedSupabaseServiceKey = supabaseServiceKeyRaw;

      print('✓ Step 4 PASSED: All secrets validated and cached');
      print('───────────────────────────────────────────────────────────');

      _isInitialized = true;
      print(
        '✅ ALL STEPS PASSED: Supabase configuration initialized successfully',
      );
      print('═══════════════════════════════════════════════════════════');
    } on TimeoutException {
      rethrow;
    } on StateError {
      rethrow;
    } catch (e) {
      print('ERROR SupabaseConfig: Failed to initialize: $e');
      final projectRef = _supabaseProjectRef;
      final edgeFunctionUrl =
          'https://$projectRef.supabase.co/functions/v1/supabase_key_connection';

      String errorDetails = '';
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('No address associated with hostname')) {
        errorDetails =
            '\n\n⚠️ HOST LOOKUP FAILED - Possible issues:\n'
            '1. Project reference "$projectRef" may be incorrect\n'
            '2. Add SUPABASE_URL to .env file to auto-detect project reference\n'
            '3. Or update the hardcoded project reference in supabase_config.dart\n'
            '4. Verify your Supabase project reference in Dashboard → Settings → General\n';
      }

      throw StateError(
        'Failed to initialize Supabase configuration: $e\n'
        '$errorDetails'
        'Please ensure:\n'
        '1. Edge Function "supabase_key_connection" is deployed:\n'
        '   supabase functions deploy supabase_key_connection\n'
        '2. Edge Function is accessible at: $edgeFunctionUrl\n'
        '3. All required secrets are set in Supabase Dashboard → Edge Functions → Secrets:\n'
        '   - APP_SUPABASE_URL\n'
        '   - APP_ANON_KEY\n'
        '   - APP_SERVICE_ROLE_KEY\n'
        '   - ECAMPUSPAY_SECRET\n'
        '4. ECAMPUSPAY_SECRET in .env file is correct\n'
        '5. Project reference is correct (currently using: $projectRef)',
      );
    } finally {
      _isInitializing = false;
    }
  }

  // Supabase configuration from Edge Function
  static String get supabaseUrl {
    if (_cachedSupabaseUrl == null) {
      throw StateError(
        'Supabase not initialized. Call SupabaseConfig.initialize() first.',
      );
    }
    return _cachedSupabaseUrl!;
  }

  static String get supabaseAnonKey {
    if (_cachedSupabaseAnonKey == null) {
      throw StateError(
        'Supabase not initialized. Call SupabaseConfig.initialize() first.',
      );
    }
    return _cachedSupabaseAnonKey!;
  }

  // Service role key for admin operations (bypasses RLS)
  static String get supabaseServiceKey {
    if (_cachedSupabaseServiceKey == null) {
      throw StateError(
        'Supabase not initialized. Call SupabaseConfig.initialize() first.',
      );
    }
    return _cachedSupabaseServiceKey!;
  }

  // Custom app secret (still from .env, needed for Edge Function auth)
  static String get ecampusPaySecret {
    final value = dotenv.env['ECAMPUSPAY_SECRET'];
    if (value == null || value.isEmpty) {
      throw StateError('Missing required env: ECAMPUSPAY_SECRET');
    }
    return value;
  }

  // Table names (these can remain as constants since they don't contain secrets)
  static const String studentInfoTable =
      'student_info'; // For CSV import and autofill
  static const String authStudentsTable =
      'auth_students'; // For authentication registration
  static const String idReplacementTable =
      'id_replacement'; // For tracking RFID card replacements

  // Helper method to validate that required environment variables are loaded
  static bool get isEnvironmentLoaded => dotenv.isInitialized;

  // Ensure Supabase URL uses HTTPS and has a proper scheme
  static String _ensureHttps(String url) {
    var normalized = url.trim();
    if (normalized.isEmpty) return normalized;

    // Add scheme if missing
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://' + normalized;
    }

    // Force https
    if (normalized.startsWith('http://')) {
      normalized = normalized.replaceFirst('http://', 'https://');
    }

    // Remove trailing slash for consistency
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    return normalized;
  }
}
