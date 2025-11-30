# Username Remember Feature (Simplified)

## Overview

This feature allows **all users** (students, admins, and service accounts) to save their **last username** locally on their device for quick login. **No passwords are stored** - only the last used username is saved for convenience.

**Works for:**

- ✅ **Student accounts** (e.g., `2022-21211`)
- ✅ **Admin accounts**
- ✅ **Service accounts**

## How It Works

### First Login

1. User enters username and password normally
2. After successful login, the username is **automatically saved** locally on the device
3. Next time the app opens, the saved username will be pre-filled

### Subsequent Logins

1. App shows the last username pre-filled in the text field
2. User only needs to enter their password
3. A "Switch Account" button appears below the username field
4. Login proceeds as normal

## Features

### 1. **Auto-Fill Last Username**

- Last logged in username is automatically shown
- User just needs to type password
- Saves time on repeated logins
- Perfect for personal devices

### 2. **Switch Account Button**

- Appears only when there's a saved username
- Located below the username field
- Click to switch to a different account

### 3. **Confirmation Dialog**

- Shows: "Are you sure you want to switch to a different account?"
- Two options: "Cancel" or "Switch"
- If confirmed:
  - Clears the saved username
  - Empties username and password fields
  - Allows user to enter a new username

## User Flow Examples

### Example 1: Regular User (Personal Phone)

```
Day 1:
- Opens app → empty username field
- Enters "2024-12345" + password → Login
- Username "2024-12345" saved automatically

Day 2:
- Opens app → sees "2024-12345" pre-filled
- Just enters password → Login
- Fast and convenient!
```

### Example 2: Switching Accounts

```
Scenario: Friend wants to login on your phone

You:
- See your username "2024-12345" pre-filled
- Click "Switch Account" button
- Confirmation: "Are you sure to switch account?"
- Click "Switch"

Friend:
- Username field now empty
- Enters their username "2024-67890" + password
- Login successful
- Their username "2024-67890" is now saved

Next time you use the app:
- Will see "2024-67890" pre-filled
- Click "Switch Account" to use yours again
```

### Example 3: Shared Device (Library/Computer Lab)

```
Student A:
- Logs in → username saved
- After logout, Student B opens app
- Sees Student A's username
- Clicks "Switch Account"
- Enters own credentials

Note: For public/shared devices, consider adding a
"Don't save username" checkbox in the future.
```

## Storage Details

### What is Stored

- **Only the last username** (replaces previous one)
- Stored locally using `SharedPreferences`
- Key: `last_used_username`

### What is NOT Stored

- ❌ **Passwords** - You must enter password every time
- ❌ Multiple usernames/accounts
- ❌ Session tokens
- ❌ Any personal data

### Where is it Stored

- Stored locally on the device using `SharedPreferences`
- Data stays on the device only
- Not synced to any server or database
- Cleared when app is uninstalled

## Technical Details

### Files Created/Modified

1. **`lib/services/username_storage_service.dart`** (New)

   - Simple service for username storage
   - Methods: `saveUsername()`, `getLastUsedUsername()`, `clearUsername()`

2. **`lib/login_page.dart`** (Modified)
   - Pre-fills last username on load
   - Auto-saves username after successful login
   - "Switch Account" button with confirmation dialog

### Key Methods

```dart
// Save a username after successful login
await UsernameStorageService.saveUsername(studentId);

// Get last used username
String? lastUsername = await UsernameStorageService.getLastUsedUsername();

// Clear saved username (when switching)
await UsernameStorageService.clearUsername();
```

### Code Changes

**UsernameStorageService:**

- Simplified to store only ONE username
- No list management
- Clean and simple API

**LoginPage:**

- Removed dropdown complexity
- Simple text field with pre-filled value
- "Switch Account" button (conditional)
- Confirmation dialog before clearing
- **Saves username for all account types** (students, admins, services)

## Security Considerations

✅ **Safe:**

- Only stores username (not password)
- Works for all account types (students, admins, services)
- Username is typically not sensitive (like student ID)
- User must authenticate with password every time
- Local storage only (device-specific)

✅ **Best Practices:**

- Password required for every login
- No auto-login functionality
- Session tokens managed separately
- Clear feedback when switching accounts
- "Switch Account" feature for shared devices

⚠️ **For Shared Devices:**

- Last user's username will be visible
- Other users can click "Switch Account"
- Consider adding "Public Device Mode" in settings

## UI Design

### Username Section Layout

```
Username
┌─────────────────────────────┐
│ 👤 2024-12345              │  ← Pre-filled
└─────────────────────────────┘
                [⇄ Switch Account]  ← Small button (right-aligned)
```

### Switch Confirmation Dialog

```
╔═══════════════════════════════╗
║  ⇄  Switch Account?           ║
╠═══════════════════════════════╣
║ Are you sure you want to      ║
║ switch to a different account?║
║ This will clear the saved     ║
║ username.                     ║
╠═══════════════════════════════╣
║        [Cancel]  [Switch]     ║
╚═══════════════════════════════╝
```

## Testing Checklist

- [x] First login saves username automatically (all account types)
- [x] Subsequent logins show saved username pre-filled
- [x] "Switch Account" button only shows when username is saved
- [x] Dialog confirms before switching
- [x] Clearing username empties fields
- [x] New login saves new username (replaces old)
- [x] **Student logins** save username ✅
- [x] **Admin logins** save username ✅
- [x] **Service logins** save username ✅
- [x] No linter errors
- [x] UI is clean and responsive

## Future Enhancements (Optional)

1. **"Remember Me" Checkbox**

   - Option to disable auto-save per login
   - Useful for public devices

2. **Public Device Mode**

   - Setting to never save usernames
   - For computer labs/kiosks

3. **Last Login Timestamp**

   - Show "Last logged in: 2 hours ago"
   - Helps user verify correct account

4. **Biometric Login**

   - After username is saved, allow fingerprint/face ID
   - Still store no password, just authenticate faster

5. **Profile Picture**
   - Small avatar next to saved username
   - Visual confirmation of account
