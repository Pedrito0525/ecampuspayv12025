# Onboarding Flow Documentation

## Overview

This document explains the onboarding flow in the eCampusPay app.

## Flow Diagram

### First Time App Install/Launch

```
App Start (main.dart)
    ↓
SplashScreen (3 seconds animation)
    ↓
Check onboarding status (SharedPreferences)
    ↓
Onboarding NOT completed? → OnboardingScreen (6 pages)
    ↓
User clicks "Get Started" or "Skip"
    ↓
Mark onboarding as completed (save to SharedPreferences)
    ↓
Navigate to LoginPage
```

### Subsequent App Launches

```
App Start (main.dart)
    ↓
SplashScreen (3 seconds animation)
    ↓
Check onboarding status (SharedPreferences)
    ↓
Onboarding completed? → LoginPage (skip onboarding)
```

## Files Involved

1. **lib/main.dart**

   - Entry point of the app
   - Starts with SplashScreen

2. **lib/splash/splash_screen.dart**

   - Shows splash animation for 3 seconds
   - Clears any existing session
   - Checks onboarding completion status
   - Routes to OnboardingScreen or LoginPage

3. **lib/onboarding/onboarding_screen.dart**

   - Shows 6 onboarding pages
   - Marks onboarding as completed when user finishes
   - Navigates to LoginPage

4. **lib/utils/onboarding_utils.dart**

   - Manages onboarding state using SharedPreferences
   - Key: 'onboarding_completed'
   - Default value: false (show onboarding)

5. **lib/login_page.dart**
   - Main login screen
   - Contains debug button to reset onboarding (when \_showDebugButtons = true)

## Testing the Onboarding Flow

### Method 1: Reset from Debug Button (Development)

1. Open `lib/login_page.dart`
2. Set `_showDebugButtons = true` (line 22)
3. Run the app
4. Login to reach the dashboard
5. Logout to return to login page
6. Click "Reset Onboarding (Debug)" button
7. Restart the app to see onboarding screen

### Method 2: Clear App Data (Production Testing)

1. Go to device Settings → Apps → eCampusPay
2. Click "Storage"
3. Click "Clear Data" or "Clear Storage"
4. Restart the app
5. Onboarding screen should appear

### Method 3: Uninstall and Reinstall

1. Uninstall the app completely
2. Reinstall the app
3. Launch the app
4. Onboarding screen should appear

## Debug Logging

The app includes detailed debug logging for the onboarding flow:

- `DEBUG: Onboarding completed status: <true/false>` - Shows current status
- `DEBUG: Onboarding NOT completed, navigating to OnboardingScreen` - First install flow
- `DEBUG: Onboarding already completed, navigating to LoginPage` - Returning user flow
- `DEBUG: Starting onboarding completion...` - User completing onboarding
- `DEBUG: Onboarding marked as completed` - Successfully saved
- `DEBUG: Onboarding completion verified: <true/false>` - Verification after save

## Implementation Details

### Storage Key

- Key: `'onboarding_completed'`
- Storage: SharedPreferences (local device storage)
- Type: Boolean
- Default: `false` (not completed)

### Error Handling

- All onboarding operations include try-catch blocks
- On error, defaults to showing onboarding (safer approach)
- Navigation includes mounted checks to prevent errors

### Changes Made (Latest Update)

1. **SplashScreen improvements:**

   - Added proper error handling
   - Added await for navigation calls
   - Added mounted checks before navigation
   - Added fallback to onboarding on error

2. **OnboardingScreen improvements:**

   - Added error handling in completion flow
   - Added verification after marking complete
   - Added mounted checks
   - Added await for navigation

3. **OnboardingUtils improvements:**
   - Added try-catch error handling
   - Returns boolean from markOnboardingCompleted()
   - Defaults to false (show onboarding) on errors
   - Better logging

## Expected Behavior

✅ **First Install:** Splash → Onboarding → Login
✅ **Subsequent Opens:** Splash → Login (skip onboarding)
✅ **After Reset:** Splash → Onboarding → Login

## Troubleshooting

If onboarding doesn't show on first install:

1. Check debug logs for onboarding status
2. Verify SharedPreferences is working correctly
3. Clear app data and try again
4. Check for errors in console

If onboarding shows every time:

1. Check if onboarding is being marked as completed
2. Verify SharedPreferences save is working
3. Check debug logs for verification status

## Debug Mode

To enable debug buttons in LoginPage:

```dart
// lib/login_page.dart (line 22)
const bool _showDebugButtons = true;  // Set to true
```

This will show:

- "Clear Session (Debug)" - Clears current session
- "Reset Onboarding (Debug)" - Resets onboarding to show it again
