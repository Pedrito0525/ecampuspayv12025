import 'package:shared_preferences/shared_preferences.dart';

/// Utility class for managing onboarding state
class OnboardingUtils {
  static const String _onboardingKey = 'onboarding_completed';

  /// Check if onboarding has been completed
  static Future<bool> isOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final completed = prefs.getBool(_onboardingKey) ?? false;
      print('DEBUG: OnboardingUtils.isOnboardingCompleted() = $completed');
      return completed;
    } catch (e) {
      print('ERROR: Failed to check onboarding status: $e');
      // Default to false (show onboarding) on error
      return false;
    }
  }

  /// Mark onboarding as completed
  static Future<bool> markOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, true);
      print(
        'DEBUG: OnboardingUtils.markOnboardingCompleted() - onboarding marked as completed',
      );

      // Verify the save
      final verifyCompleted = prefs.getBool(_onboardingKey) ?? false;
      print(
        'DEBUG: OnboardingUtils verification - onboarding completed: $verifyCompleted',
      );

      return verifyCompleted;
    } catch (e) {
      print('ERROR: Failed to mark onboarding as completed: $e');
      return false;
    }
  }

  /// Reset onboarding (for testing purposes)
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingKey);
  }

  /// Clear all app preferences (for testing purposes)
  static Future<void> clearAllPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Reset onboarding for testing (keeps other preferences)
  static Future<void> resetOnboardingForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_onboardingKey);
  }
}
