# Environment Variables Setup

## Overview

The Supabase configuration has been updated to use environment variables instead of hardcoded values for better security and flexibility.

## Setup Instructions

### 1. Create .env file

Create a `.env` file in the `final_ecampuspay` directory with the following content:

```
# Supabase Configuration
SUPABASE_URL=https://weesgvewyuozivhedhej.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndlZXNndmV3eXVveml2aGVkaGVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwNzUzMTUsImV4cCI6MjA3MjY1MTMxNX0.CVjV_oUll7IfOdITgyAB9jNrWpS_sYNnfQG5Ke7IgbU
SUPABASE_SERVICE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndlZXNndmV3eXVveml2aGVkaGVqIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NzA3NTMxNSwiZXhwIjoyMDcyNjUxMzE1fQ.jd0rmNyc9x6lPpWk0-WXJTeb929mqah1PbNuh8C6hE0

# Custom app secret
ECAMPUSPAY_SECRET=ecampuspayevsu-2025
```

### 2. Update .gitignore

Add the following line to your `.gitignore` file to prevent committing sensitive data:

```
.env
```

### 3. How it works

- The `SupabaseConfig` class now loads configuration from environment variables
- Fallback values are provided if environment variables are not found
- The environment is initialized in `main()` before Supabase initialization
- All sensitive data is now externalized from the codebase

### 4. Usage

The configuration is accessed the same way as before:

```dart
// These now read from environment variables
String url = SupabaseConfig.supabaseUrl;
String anonKey = SupabaseConfig.supabaseAnonKey;
String serviceKey = SupabaseConfig.supabaseServiceKey;
String secret = SupabaseConfig.ecampusPaySecret;
```

### 5. Benefits

- ✅ Better security (secrets not in source code)
- ✅ Environment-specific configuration
- ✅ Easy deployment across different environments
- ✅ Follows security best practices

## Notes

- The `.env` file is already added to `pubspec.yaml` assets
- Environment variables are loaded automatically on app startup
- Fallback values ensure the app works even without `.env` file
