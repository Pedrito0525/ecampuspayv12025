import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage locally stored username (no password)
/// Saves only the last logged in username for convenience
class UsernameStorageService {
  static const String _lastUsedUsernameKey = 'last_used_username';

  /// Get the last used username
  static Future<String?> getLastUsedUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString(_lastUsedUsernameKey);
      print('DEBUG: Retrieved saved username: $username');
      return username;
    } catch (e) {
      print('Error getting last used username: $e');
      return null;
    }
  }

  /// Save a username (replaces previous one)
  static Future<bool> saveUsername(String username) async {
    try {
      final trimmedUsername = username.trim();
      if (trimmedUsername.isEmpty) {
        print('DEBUG: Username is empty, not saving');
        return false;
      }

      print(
        'DEBUG: Saving username: "$trimmedUsername" (length: ${trimmedUsername.length})',
      );
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.setString(
        _lastUsedUsernameKey,
        trimmedUsername,
      );
      print('DEBUG: Username saved successfully: $result');

      // Verify the save by reading it back
      final savedUsername = await prefs.getString(_lastUsedUsernameKey);
      print('DEBUG: Verification - saved username is now: "$savedUsername"');

      return result;
    } catch (e) {
      print('Error saving username: $e');
      return false;
    }
  }

  /// Clear saved username
  static Future<bool> clearUsername() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastUsedUsernameKey);
      return true;
    } catch (e) {
      print('Error clearing username: $e');
      return false;
    }
  }
}
