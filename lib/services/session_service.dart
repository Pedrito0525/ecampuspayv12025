import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import '../config/supabase_config.dart';
import 'encryption_service.dart';

class SessionService {
  static const String _userDataKey = 'user_data';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _userTypeKey = 'user_type';

  // Current user data
  static Map<String, dynamic>? _currentUserData;
  static String? _currentUserType;

  /// Initialize session service
  static Future<void> initialize() async {
    await SupabaseService.initialize();
    await _loadStoredSession();
  }

  /// Load stored session from SharedPreferences
  static Future<void> _loadStoredSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

      if (isLoggedIn) {
        final userDataString = prefs.getString(_userDataKey);
        final userType = prefs.getString(_userTypeKey);

        if (userDataString != null && userType != null) {
          _currentUserData = Map<String, dynamic>.from(
            Uri.splitQueryString(userDataString),
          );
          _currentUserType = userType;
        }
      }
    } catch (e) {
      print('Error loading stored session: $e');
    }
  }

  /// Save session to SharedPreferences
  static Future<void> saveSession(
    Map<String, dynamic> userData,
    String userType,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_isLoggedInKey, true);
      await prefs.setString(_userTypeKey, userType);

      // Convert user data to query string format for storage
      final userDataString = userData.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
      await prefs.setString(_userDataKey, userDataString);

      _currentUserData = userData;
      _currentUserType = userType;
    } catch (e) {
      print('Error saving session: $e');
    }
  }

  /// Clear session
  static Future<void> clearSession() async {
    try {
      // Clear local variables first
      _currentUserData = null;
      _currentUserType = null;

      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userDataKey);
      await prefs.remove(_userTypeKey);

      // Sign out from Supabase
      await SupabaseService.client.auth.signOut();

      print('Session cleared successfully');
    } catch (e) {
      print('Error clearing session: $e');
      // Even if there's an error, clear local data
      _currentUserData = null;
      _currentUserType = null;
    }
  }

  /// Force clear all session data (more aggressive)
  static Future<void> forceClearSession() async {
    try {
      print('DEBUG: Starting force clear session...');

      // Clear local variables
      _currentUserData = null;
      _currentUserType = null;

      // Get SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Save the username before clearing (if it exists)
      final savedUsername = prefs.getString('last_used_username');
      print('DEBUG: Found saved username before clear: $savedUsername');

      // Clear all SharedPreferences data
      await prefs.clear();
      print('DEBUG: SharedPreferences cleared');

      // Restore the saved username
      if (savedUsername != null && savedUsername.isNotEmpty) {
        await prefs.setString('last_used_username', savedUsername);
        print('DEBUG: Restored saved username: $savedUsername');

        // Verify the restore
        final restoredUsername = prefs.getString('last_used_username');
        print(
          'DEBUG: Verification - restored username is now: $restoredUsername',
        );
      } else {
        print('DEBUG: No username to restore');
      }

      // Sign out from Supabase
      await SupabaseService.client.auth.signOut();

      print('DEBUG: Session force cleared successfully');
    } catch (e) {
      print('Error force clearing session: $e');
      // Even if there's an error, clear local data
      _currentUserData = null;
      _currentUserType = null;
    }
  }

  /// Clear session on app termination (preserves username)
  static Future<void> clearSessionOnAppClose() async {
    try {
      print('DEBUG: Clearing session on app close...');

      // Clear local variables
      _currentUserData = null;
      _currentUserType = null;

      // Get SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Save the username before clearing session data
      final savedUsername = prefs.getString('last_used_username');
      print('DEBUG: Preserving username: $savedUsername');

      // Clear only session-related data, preserve username
      await prefs.remove(_isLoggedInKey);
      await prefs.remove(_userDataKey);
      await prefs.remove(_userTypeKey);

      // Sign out from Supabase
      await SupabaseService.client.auth.signOut();

      print('DEBUG: Session cleared on app close, username preserved');
    } catch (e) {
      print('Error clearing session on app close: $e');
      // Even if there's an error, clear local data
      _currentUserData = null;
      _currentUserType = null;
    }
  }

  /// Check if user is logged in
  static bool get isLoggedIn {
    return _currentUserData != null && _currentUserType != null;
  }

  /// Get current user data
  static Map<String, dynamic>? get currentUserData => _currentUserData;

  /// Get current user type
  static String? get currentUserType => _currentUserType;

  /// Login with email and password
  static Future<Map<String, dynamic>> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in with Supabase Auth
      final response = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        return {
          'success': false,
          'message': 'Login failed. Please check your credentials.',
        };
      }

      // Get user data from auth_students table
      final userDataResult = await _getUserDataFromAuthStudents(
        response.user!.id,
      );

      if (!userDataResult['success']) {
        await SupabaseService.client.auth.signOut();
        return {
          'success': false,
          'message': 'User data not found. Please contact support.',
        };
      }

      final userData = userDataResult['data'];

      // Save session
      await saveSession(userData, 'student');

      return {
        'success': true,
        'data': userData,
        'message': 'Login successful!',
      };
    } catch (e) {
      return {'success': false, 'message': 'Login failed: ${e.toString()}'};
    }
  }

  /// Login with student ID and password using Supabase Auth
  /// Uses auth.users for authentication and auth_students for user details/balance
  static Future<Map<String, dynamic>> loginWithStudentId({
    required String studentId,
    required String password,
  }) async {
    try {
      // Step 1: Look up the user in auth_students table by student_id to get email and auth_user_id
      final userLookupResult = await _getUserByStudentIdFromAuthStudents(
        studentId,
      );

      if (!userLookupResult['success']) {
        return {
          'success': false,
          'message': 'Student ID not found. Please check your credentials.',
        };
      }

      final userData = userLookupResult['data'];
      final email = userData['email']?.toString();
      final authUserId = userData['auth_user_id']?.toString();

      // Validate that we have the required data
      if (email == null || email.isEmpty) {
        return {
          'success': false,
          'message': 'User email not found. Please contact support.',
        };
      }

      if (authUserId == null || authUserId.isEmpty) {
        return {
          'success': false,
          'message':
              'User authentication ID not found. Please contact support.',
        };
      }

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

      // Step 2: Authenticate with Supabase Auth using email and password
      final authResponse = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        return {
          'success': false,
          'message': 'Invalid password. Please check your credentials.',
        };
      }

      // Step 3: Verify that the authenticated user's ID matches the auth_user_id from auth_students
      if (authResponse.user!.id != authUserId) {
        // Sign out if IDs don't match (security check)
        await SupabaseService.client.auth.signOut();
        return {
          'success': false,
          'message':
              'Authentication verification failed. Please contact support.',
        };
      }

      // Step 4: Get full user data from auth_students table (including balance)
      final fullUserDataResult = await _getUserDataFromAuthStudents(authUserId);

      if (!fullUserDataResult['success']) {
        await SupabaseService.client.auth.signOut();
        return {
          'success': false,
          'message': 'User data not found. Please contact support.',
        };
      }

      final fullUserData = fullUserDataResult['data'];

      // Step 5: Save session with complete user data from auth_students
      await saveSession(fullUserData, 'student');

      return {
        'success': true,
        'data': fullUserData,
        'message': 'Login successful!',
      };
    } catch (e) {
      // Handle specific Supabase Auth errors
      String errorMessage = 'Login failed: ${e.toString()}';

      if (e.toString().contains('Invalid login credentials') ||
          e.toString().contains('invalid_credentials') ||
          e.toString().contains('Invalid password')) {
        errorMessage = 'Invalid password. Please check your credentials.';
      } else if (e.toString().contains('Email not confirmed') ||
          e.toString().contains('email_not_confirmed')) {
        errorMessage =
            'Please confirm your email before logging in. Check your inbox for the confirmation email.';
      } else if (e.toString().contains('User not found') ||
          e.toString().contains('user_not_found')) {
        errorMessage = 'Student ID not found. Please check your credentials.';
      }

      // Ensure we're signed out on error
      try {
        await SupabaseService.client.auth.signOut();
      } catch (_) {
        // Ignore sign out errors
      }

      return {'success': false, 'message': errorMessage};
    }
  }

  /// Direct login using student ID and password (alternative approach)
  static Future<Map<String, dynamic>> loginWithStudentIdDirect({
    required String studentId,
    required String password,
  }) async {
    try {
      // Look up the user in auth.users table by student_id in user_metadata
      final response =
          await SupabaseService.client
              .from('auth.users')
              .select('id, email, user_metadata')
              .eq('user_metadata->student_id', studentId)
              .maybeSingle();

      if (response == null) {
        return {
          'success': false,
          'message': 'Student ID not found. Please check your credentials.',
        };
      }

      final email = response['email'];

      // Authenticate with Supabase Auth
      final authResponse = await SupabaseService.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        return {
          'success': false,
          'message': 'Invalid credentials. Please check your password.',
        };
      }

      // Get user data from auth_students table
      final userDataResult = await _getUserDataFromAuthStudents(
        authResponse.user!.id,
      );

      if (!userDataResult['success']) {
        await SupabaseService.client.auth.signOut();
        return {
          'success': false,
          'message': 'User data not found. Please contact support.',
        };
      }

      final userData = userDataResult['data'];

      // Save session
      await saveSession(userData, 'student');

      return {
        'success': true,
        'data': userData,
        'message': 'Login successful!',
      };
    } catch (e) {
      return {'success': false, 'message': 'Login failed: ${e.toString()}'};
    }
  }

  /// Get user data from auth_students table
  /// Returns decrypted user data including balance and auth_user_id
  static Future<Map<String, dynamic>> _getUserDataFromAuthStudents(
    String authUserId,
  ) async {
    try {
      final response =
          await SupabaseService.client
              .from(SupabaseConfig.authStudentsTable)
              .select()
              .eq('auth_user_id', authUserId)
              .maybeSingle();

      if (response == null) {
        return {'success': false, 'message': 'User data not found'};
      }

      // Decrypt sensitive data (name, email, course, rfid_id)
      // Non-encrypted fields (balance, auth_user_id, student_id, etc.) are preserved
      final decryptedData = EncryptionService.decryptUserData(response);

      // Ensure balance and auth_user_id are included (they're not encrypted, so should be preserved)
      // But let's explicitly add them to be safe
      final userData = {
        ...decryptedData,
        'balance': response['balance'] ?? 0.0,
        'auth_user_id': response['auth_user_id'],
        'student_id': response['student_id'], // student_id is not encrypted
        'is_active': response['is_active'] ?? true,
        'taptopay': response['taptopay'] ?? true,
      };

      return {'success': true, 'data': userData};
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get user data: ${e.toString()}',
      };
    }
  }

  /// Get user by student ID from auth_students table
  /// Returns decrypted user data including auth_user_id and email for authentication
  static Future<Map<String, dynamic>> _getUserByStudentIdFromAuthStudents(
    String studentId,
  ) async {
    try {
      // Query auth_students table by student_id (student_id is stored as plain text)
      final response =
          await SupabaseService.client
              .from(SupabaseConfig.authStudentsTable)
              .select('*')
              .eq('student_id', studentId)
              .maybeSingle();

      if (response == null) {
        return {
          'success': false,
          'message': 'Student ID not found in auth_students',
        };
      }

      // Decrypt sensitive data (name, email, course, rfid_id)
      // Non-encrypted fields (auth_user_id, balance, student_id, etc.) are preserved
      final decryptedData = EncryptionService.decryptUserData(response);

      // Ensure auth_user_id and other non-encrypted fields are explicitly included
      final userData = {
        ...decryptedData,
        'auth_user_id': response['auth_user_id'],
        'student_id': response['student_id'], // student_id is not encrypted
        'balance': response['balance'] ?? 0.0,
        'is_active': response['is_active'] ?? true,
        'taptopay': response['taptopay'] ?? true,
      };

      return {'success': true, 'data': userData};
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get user: ${e.toString()}',
      };
    }
  }

  /// Get current user balance
  static double get currentUserBalance {
    if (_currentUserData != null) {
      return double.tryParse(_currentUserData!['balance'].toString()) ?? 0.0;
    }
    return 0.0;
  }

  /// Get current user name (should already be decrypted)
  static String get currentUserName {
    if (_currentUserData != null) {
      try {
        final name = _currentUserData!['name']?.toString() ?? 'Unknown User';
        return name;
      } catch (e) {
        print('Error getting user name: $e');
        return 'Unknown User';
      }
    }
    return 'Unknown User';
  }

  /// Get current user student ID (should already be decrypted)
  static String get currentUserStudentId {
    if (_currentUserData != null) {
      try {
        final studentId = _currentUserData!['student_id']?.toString() ?? '';
        return studentId;
      } catch (e) {
        print('Error getting student ID: $e');
        return '';
      }
    }
    return '';
  }

  /// Get current user course (should already be decrypted)
  static String get currentUserCourse {
    if (_currentUserData != null) {
      try {
        final course = _currentUserData!['course']?.toString() ?? '';

        // Check if the course is still encrypted (contains base64 characters)
        if (course.length > 20 &&
            (course.contains('=') || course.length % 4 == 0)) {
          // If it looks like encrypted data, show a placeholder
          return 'Student Course';
        }

        return course;
      } catch (e) {
        print('Error getting course: $e');
        return '';
      }
    }
    return '';
  }

  /// Update user balance (for transactions)
  static Future<void> updateUserBalance(double newBalance) async {
    if (_currentUserData != null) {
      _currentUserData!['balance'] = newBalance;
      await saveSession(_currentUserData!, _currentUserType!);
    }
  }

  /// Refresh user data from database
  static Future<void> refreshUserData() async {
    if (_currentUserData != null && _currentUserType == 'student') {
      final authUserId = _currentUserData!['auth_user_id'];
      final userDataResult = await _getUserDataFromAuthStudents(authUserId);

      if (userDataResult['success']) {
        await saveSession(userDataResult['data'], 'student');
      }
    }
  }

  /// Check if current user is admin
  static bool get isAdmin {
    return _currentUserType == 'admin';
  }

  /// Check if current user is service
  static bool get isService {
    return _currentUserType == 'service';
  }

  /// Check if current user is student
  static bool get isStudent {
    return _currentUserType == 'student';
  }

  /// Check if current admin user is staff/moderator
  static bool get isAdminStaff {
    if (!isAdmin || _currentUserData == null) {
      return false;
    }
    final role = _currentUserData!['role']?.toString().toLowerCase() ?? '';
    return role == 'moderator' || role == 'staff';
  }

  /// Get current admin role (admin, moderator, staff)
  static String get adminRole {
    if (!isAdmin || _currentUserData == null) {
      return 'admin';
    }
    return _currentUserData!['role']?.toString().toLowerCase() ?? 'admin';
  }
}
