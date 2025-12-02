import 'package:flutter/material.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'forgot_password_page.dart';
import 'user/user_dashboard.dart';
import 'admin/admin_dashboard.dart';
import 'services_school/service_dashboard.dart';
import 'services/session_service.dart';
import 'services/supabase_service.dart';
import 'services/username_storage_service.dart';
import 'services/activity_alert_service.dart';
import 'services/realtime_notification_service.dart';
import 'widgets/activity_alert_widget.dart';
import 'utils/onboarding_utils.dart';

// ============================================================================
// DEBUG CONFIGURATION
// ============================================================================
// To show/hide debug buttons on login page:
// - Set _showDebugButtons to true to display debug buttons
// - Set _showDebugButtons to false to hide debug buttons
// ============================================================================
const bool _showDebugButtons = false;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController studentIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;
  bool isLoading = false;
  bool hasInternetConnection = true;
  bool _showFloatingError = false;
  String _floatingErrorMessage = '';
  IconData _floatingErrorIcon = Icons.error;
  String _floatingErrorTitle = '';
  Color _floatingErrorColor = Colors.red;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // Username storage related
  String? _savedUsername;

  // Activity alert related (reserved for future use)
  // Map<String, dynamic>? _pendingAlert;
  // bool _showActivityAlert = false;

  @override
  void initState() {
    super.initState();
    print('DEBUG: LoginPage initState called');
    _initializeLoginPage();
  }

  /// Initialize login page components in proper order
  Future<void> _initializeLoginPage() async {
    // First check existing session
    await _checkExistingSession();

    // Then load saved username (after session is cleared if needed)
    await _loadSavedUsername();

    // Finally setup connectivity monitoring
    _checkInitialConnectivity();
    _subscribeToConnectivityChanges();
  }

  /// Load saved username from local storage
  Future<void> _loadSavedUsername() async {
    print('DEBUG: Loading saved username...');
    final lastUsername = await UsernameStorageService.getLastUsedUsername();
    print('DEBUG: Last username retrieved: $lastUsername');

    if (mounted && lastUsername != null && lastUsername.isNotEmpty) {
      print('DEBUG: Setting username in UI: $lastUsername');
      setState(() {
        _savedUsername = lastUsername;
        studentIdController.text = lastUsername;
      });
      print('DEBUG: Username set in UI successfully');
    } else {
      print('DEBUG: No saved username found or widget not mounted');
    }
  }

  /// Check initial connectivity status
  Future<void> _checkInitialConnectivity() async {
    try {
      final hasInternet = await _checkInternetConnection();
      if (mounted) {
        setState(() {
          hasInternetConnection = hasInternet;
        });
      }
    } catch (e) {
      print('DEBUG: Initial connectivity check failed: $e');
      if (mounted) {
        setState(() {
          hasInternetConnection = false;
        });
      }
    }
  }

  @override
  void dispose() {
    studentIdController.dispose();
    passwordController.dispose();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  /// Check if user is already logged in
  Future<void> _checkExistingSession() async {
    await SessionService.initialize();

    // Only clear session if user is actually logged in, otherwise preserve username
    if (SessionService.isLoggedIn) {
      print('DEBUG: Found existing session, clearing it for fresh login');
      await SessionService.forceClearSession();
    } else {
      print('DEBUG: No existing session found, preserving saved username');
    }

    // Disable auto-login for now to ensure login page is always shown
    // if (SessionService.isLoggedIn) {
    //   // Verify the session is still valid by checking if user data exists
    //   if (SessionService.currentUserData != null &&
    //       SessionService.currentUserData!.isNotEmpty) {
    //     _navigateToDashboard();
    //   } else {
    //     // Clear invalid session
    //     await SessionService.clearSession();
    //   }
    // }
  }

  void _subscribeToConnectivityChanges() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) async {
      final ConnectivityResult latest =
          results.isNotEmpty ? results.last : ConnectivityResult.none;
      bool isOnline = latest != ConnectivityResult.none;
      if (isOnline) {
        // Double-check actual reachability
        final reachable = await _checkInternetConnection();
        if (!mounted) return;
        setState(() {
          hasInternetConnection = reachable;
          if (reachable) {
            _showFloatingError = false;
          }
        });
      } else {
        if (!mounted) return;
        setState(() {
          hasInternetConnection = false;
        });
        _showFloatingErrorModal(
          Icons.wifi_off,
          'No Internet Connection',
          'Please check your network connection and try again.',
          Colors.orange,
        );
      }
    });
  }

  /// Check internet connectivity with actual server test
  Future<bool> _checkInternetConnection() async {
    try {
      final connectivityResult = await Connectivity().checkConnectivity();

      if (connectivityResult == ConnectivityResult.none) {
        return false;
      }

      // Additional check to ensure we can actually reach the Supabase server
      // by trying to make a simple request to test connectivity
      try {
        await SupabaseService.initialize();
        // Try a simple query that should work if server is reachable
        await SupabaseService.client
            .from('auth_students')
            .select('student_id')
            .limit(1);
        return true;
      } catch (e) {
        print('DEBUG: Server connectivity test failed: $e');
        return false;
      }
    } catch (e) {
      print('DEBUG: Connectivity check failed: $e');
      return false;
    }
  }

  Future<void> _login() async {
    if (isLoading) return;

    String studentId = studentIdController.text.trim();
    String password = passwordController.text.trim();

    if (studentId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter both Username and Password'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Check internet connectivity first
      print('DEBUG: Checking internet connectivity before login...');
      final hasInternet = await _checkInternetConnection();
      print('DEBUG: Internet connectivity result: $hasInternet');

      if (!hasInternet) {
        print('DEBUG: No internet connection, showing error dialog');
        _showErrorDialog(
          'No internet connection detected. Please check your network connection and try again.',
        );
        return;
      }

      print('DEBUG: Internet connection OK, proceeding with authentication...');
      // Check system update settings to possibly block logins (admins exempt)
      final sysResp = await SupabaseService.getSystemUpdateSettings();
      final sys = (sysResp['data'] ?? {}) as Map;

      final bool maintenance = sys['maintenance_mode'] == true;
      final bool forceUpdate = sys['force_update_mode'] == true;
      final bool disableAll = sys['disable_all_logins'] == true;

      if (disableAll || maintenance || forceUpdate) {
        // Allow admins to proceed; block others here before hitting auth
        final adminProbe = await SupabaseService.authenticateAdmin(
          username: studentId,
          password: password,
        );
        if (!(adminProbe['success'] == true)) {
          String reason =
              disableAll
                  ? 'The system is temporarily locked down.'
                  : maintenance
                  ? 'The system is under maintenance.'
                  : 'A new version is required before login.';
          _showErrorDialog('$reason Please try again later.');
          return;
        }
      }

      // First, try to authenticate as student
      final studentResult = await SessionService.loginWithStudentId(
        studentId: studentId,
        password: password,
      );

      if (studentResult['success']) {
        // Save username locally for future logins
        await UsernameStorageService.saveUsername(studentId);
        _navigateToDashboard();
        return;
      }

      // Check if the error is about email confirmation - show dialog with resend option
      final studentErrorMessage = studentResult['message']?.toString() ?? '';
      if (studentErrorMessage.toLowerCase().contains('confirm your email') ||
          studentErrorMessage.toLowerCase().contains('email confirmation')) {
        // Get email from student ID to resend confirmation
        await _showEmailConfirmationDialog(studentId);
        return;
      }

      // If student authentication fails, try admin authentication (preserve case)
      final adminResult = await SupabaseService.authenticateAdmin(
        username: studentId,
        password: password,
      );

      if (adminResult['success']) {
        // Save username locally for future logins
        await UsernameStorageService.saveUsername(studentId);
        await _handleAdminLogin(adminResult['data']);
        return;
      }

      // Check if admin account is deactivated
      final adminMessage = adminResult['message']?.toString() ?? '';
      if (adminMessage.toLowerCase().contains('deactivated') ||
          adminMessage.toLowerCase().contains('account is deactivated')) {
        _showErrorDialog(
          'Your account has been deactivated. Contact admin to activate your account.',
        );
        return;
      }

      // Next, try service account authentication (case-insensitive)
      print(
        'DEBUG: Attempting service account authentication with: ${studentId.toLowerCase()}',
      );
      final serviceResult = await SupabaseService.authenticateServiceAccount(
        username: studentId.toLowerCase(),
        password: password,
      );

      if (serviceResult['success']) {
        print('DEBUG: Service account authentication successful!');
        final serviceData = serviceResult['data'];
        final serviceCategory = serviceData['service_category'];
        print('DEBUG: Service category: $serviceCategory');

        // Save username locally for future logins (use lowercase for service accounts)
        final saveResult = await UsernameStorageService.saveUsername(
          studentId.toLowerCase(),
        );
        print(
          'DEBUG: Service username save result: $saveResult for category: $serviceCategory',
        );
        await _handleServiceLogin(serviceData);
        return;
      } else {
        print(
          'DEBUG: Service account authentication failed: ${serviceResult['message']}',
        );

        // Check if the error is about email confirmation - show dialog with resend option
        final serviceErrorMessage = serviceResult['message']?.toString() ?? '';
        if (serviceErrorMessage.toLowerCase().contains('confirm your email') ||
            serviceErrorMessage.toLowerCase().contains('email confirmation') ||
            serviceErrorMessage.toLowerCase().contains('email not confirmed')) {
          // Get email from service result or service account
          final serviceEmail = serviceResult['email']?.toString();
          if (serviceEmail != null && serviceEmail.isNotEmpty) {
            await _showServiceEmailConfirmationDialog(serviceEmail);
          } else {
            _showErrorDialog(
              'Please confirm your email before logging in. Check your inbox for the confirmation email.',
            );
          }
          return;
        }

        // Check if account is deactivated and show specific error message
        if (serviceResult['is_deactivated'] == true) {
          _showErrorDialog(
            serviceResult['message'] ??
                'Your account is deactivated. Contact admin to reactivate your account.',
          );
          return;
        }
      }

      // If all authentication methods fail, check if it's a network issue first
      // Re-check connectivity in case it changed during login attempt
      final stillHasInternet = await _checkInternetConnection();
      if (!stillHasInternet) {
        _showErrorDialog(
          'No internet connection detected. Please check your network connection and try again.',
        );
      } else {
        _showErrorDialog(
          'Invalid username or password. Please check your credentials.',
        );
      }
    } catch (e) {
      // Handle different types of errors
      String errorMessage;
      String errorString = e.toString().toLowerCase();

      if (errorString.contains('network') ||
          errorString.contains('connection') ||
          errorString.contains('timeout') ||
          errorString.contains('unreachable') ||
          errorString.contains('no internet') ||
          errorString.contains('socket') ||
          errorString.contains('failed host lookup') ||
          errorString.contains('connection refused') ||
          errorString.contains('connection reset')) {
        errorMessage =
            'No internet connection detected. Please check your network connection and try again.';
      } else {
        errorMessage = 'An error occurred during login. Please try again.';
      }

      _showErrorDialog(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _handleAdminLogin(Map<String, dynamic>? adminData) async {
    // Use admin data from database or fallback to default
    final adminInfo =
        adminData ??
        {
          'id': null,
          'username': 'Admin',
          'full_name': 'System Administrator',
          'email': 'admin@evsu.edu.ph',
          'role': 'admin',
        };

    // Save admin session (include id for permission checks)
    await SessionService.saveSession({
      'id': adminInfo['id'], // Include admin ID for permission checks
      'student_id': adminInfo['username'] ?? 'Admin',
      'name': adminInfo['full_name'] ?? 'System Administrator',
      'email': adminInfo['email'] ?? 'admin@evsu.edu.ph',
      'course': 'Administration',
      'balance': 0.0,
      'role': adminInfo['role'] ?? 'admin',
    }, 'admin');

    _navigateToDashboard();
  }

  Future<void> _handleServiceLogin(Map<String, dynamic> serviceData) async {
    // Save service session with required fields
    await SessionService.saveSession({
      'service_id': serviceData['id'].toString(),
      'service_name': serviceData['service_name'] ?? 'Service',
      'service_category': serviceData['service_category'] ?? 'General',
      'operational_type': serviceData['operational_type'] ?? 'Main',
      'main_service_id': serviceData['main_service_id']?.toString() ?? '',
      'balance': serviceData['balance']?.toString() ?? '0.0',
      'commission_rate': serviceData['commission_rate']?.toString() ?? '0.0',
      'contact_person': serviceData['contact_person'] ?? '',
      'email': serviceData['email'] ?? '',
      'phone': serviceData['phone'] ?? '',
      'username': serviceData['username'] ?? '',
    }, 'service');

    _navigateToDashboard();
  }

  void _navigateToDashboard() async {
    if (!mounted) return;

    // Check for recent activity alerts before navigating
    await _checkForActivityAlerts();

    // Start realtime notifications for students only
    if (SessionService.isStudent) {
      // Restart listening to realtime notifications after login
      await RealtimeNotificationService.restartListening();

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const UserDashboard()),
      );
    } else if (SessionService.isAdmin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
      );
    } else if (SessionService.isService) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => const ServiceDashboard(
                serviceName: 'Main Campus Cafeteria',
                serviceType: 'Canteen',
              ),
        ),
      );
    }
  }

  /// Check for recent activity and show alert if found
  Future<void> _checkForActivityAlerts() async {
    try {
      // Only check if user has internet connection
      if (!hasInternetConnection) {
        print('DEBUG: No internet connection, skipping activity alert check');
        return;
      }

      print('DEBUG: Checking for recent activity alerts...');
      final alertResult = await ActivityAlertService.checkRecentActivity();

      if (alertResult['hasAlert'] == true && mounted) {
        print('DEBUG: Found activity alert: ${alertResult['title']}');

        // Show the alert before navigating
        _showActivityAlertDialog(alertResult);

        // Mark as notified to prevent duplicate alerts
        if (alertResult['transactionId'] != null) {
          await ActivityAlertService.markAsNotified(
            alertResult['transactionId'],
          );
        }
      } else {
        print('DEBUG: No recent activity alerts found');
      }
    } catch (e) {
      print('DEBUG: Error checking activity alerts: $e');
      // Don't block navigation if alert check fails
    }
  }

  /// Show activity alert dialog
  void _showActivityAlertDialog(Map<String, dynamic> alertData) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: EdgeInsets.zero,
            content: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ActivityAlertWidget(
                alertData: alertData,
                onDismiss: () => Navigator.of(context).pop(),
                onTap: () {
                  Navigator.of(context).pop();
                  // Could navigate to transaction details here
                },
                isDismissible: true,
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(20),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Continue'),
              ),
            ],
          ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    // Determine icon and title based on message content
    IconData icon;
    String title;
    Color iconColor;

    if (message.toLowerCase().contains('internet') ||
        message.toLowerCase().contains('connection') ||
        message.toLowerCase().contains('network')) {
      icon = Icons.wifi_off;
      title = 'No Internet Connection';
      iconColor = Colors.orange;
    } else {
      icon = Icons.error;
      title = 'Login Failed';
      iconColor = Colors.red;
    }

    // Show floating modal instead of full dialog
    _showFloatingErrorModal(icon, title, message, iconColor);
  }

  void _showFloatingErrorModal(
    IconData icon,
    String title,
    String message,
    Color iconColor,
  ) {
    setState(() {
      _floatingErrorIcon = icon;
      _floatingErrorTitle = title;
      _floatingErrorMessage = message;
      _floatingErrorColor = iconColor;
      _showFloatingError = true;
    });

    // Auto-hide after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showFloatingError = false;
        });
      }
    });
  }

  void _hideFloatingError() {
    setState(() {
      _showFloatingError = false;
    });
  }

  /// Show email confirmation dialog for service accounts with option to resend confirmation email
  Future<void> _showServiceEmailConfirmationDialog(String email) async {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        const Color evsuRed = Color(0xFFB01212);
        bool isResending = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.email_outlined, color: evsuRed, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Email Not Confirmed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please confirm your email address before logging in. Check your inbox for the confirmation email.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.email,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            email,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'If you didn\'t receive the email or the link has expired, you can request a new confirmation email.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isResending ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      isResending
                          ? null
                          : () async {
                            setDialogState(() {
                              isResending = true;
                            });

                            try {
                              final result =
                                  await SupabaseService.resendEmailConfirmation(
                                    email: email,
                                  );

                              if (mounted) {
                                Navigator.of(context).pop();

                                if (result['success']) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              result['message'] ??
                                                  'Confirmation email sent successfully!',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              result['message'] ??
                                                  'Failed to send confirmation email.',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Error sending confirmation email: ${e.toString()}',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: evsuRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon:
                      isResending
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.refresh, size: 18),
                  label: Text(
                    isResending ? 'Sending...' : 'Resend Email',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Show email confirmation dialog with option to resend confirmation email
  Future<void> _showEmailConfirmationDialog(String studentId) async {
    if (!mounted) return;

    // Get user email from student ID
    String? userEmail;
    try {
      final userResult = await SupabaseService.getUserByStudentId(studentId);
      if (userResult['success'] && userResult['data'] != null) {
        userEmail = userResult['data']['email']?.toString();
      }
    } catch (e) {
      print('DEBUG: Error getting user email: $e');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        const Color evsuRed = Color(0xFFB01212);
        bool isResending = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.email_outlined, color: evsuRed, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Email Not Confirmed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Please confirm your email address before logging in. Check your inbox for the confirmation email.',
                    style: TextStyle(fontSize: 14),
                  ),
                  if (userEmail != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              userEmail,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'If you didn\'t receive the email or the link has expired, you can request a new confirmation email.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                      isResending ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      isResending
                          ? null
                          : () async {
                            if (userEmail == null || userEmail.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Unable to get email address. Please contact support.',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              isResending = true;
                            });

                            try {
                              final result =
                                  await SupabaseService.resendEmailConfirmation(
                                    email: userEmail,
                                  );

                              if (mounted) {
                                Navigator.of(context).pop();

                                if (result['success']) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              result['message'] ??
                                                  'Confirmation email sent successfully!',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              result['message'] ??
                                                  'Failed to send confirmation email.',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            } catch (e) {
                              if (mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.error_outline,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Error sending confirmation email: ${e.toString()}',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.red,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: evsuRed,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon:
                      isResending
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.refresh, size: 18),
                  label: Text(
                    isResending ? 'Sending...' : 'Resend Email',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildUsernameSection(Color evsuRed) {
    // Determine if field should be read-only
    final bool isReadOnly =
        _savedUsername != null &&
        _savedUsername!.isNotEmpty &&
        studentIdController.text == _savedUsername;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Username label
        Text(
          'Username',
          style: TextStyle(
            fontSize: 14,
            color: evsuRed.withValues(alpha: 0.9),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        // Username text field
        TextField(
          controller: studentIdController,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.next,
          readOnly:
              isReadOnly, // Make field read-only when saved username is present
          onChanged: (value) {
            // Only allow editing when field is not read-only
            if (!isReadOnly &&
                _savedUsername != null &&
                value != _savedUsername) {
              setState(() {
                _savedUsername =
                    null; // Clear saved username when manually edited
              });
            }
          },
          decoration: InputDecoration(
            hintText: 'Enter your Username',
            prefixIcon: Icon(Icons.person, color: evsuRed),
            // Remove the clear button - only Switch Account button should clear
            suffixIcon: null,
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: evsuRed, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: isReadOnly ? evsuRed.withOpacity(0.5) : evsuRed,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            // Add visual indication when field is read-only
            filled: isReadOnly,
            fillColor: isReadOnly ? evsuRed.withOpacity(0.05) : null,
          ),
        ),

        // Switch Account button (only show if there's a saved username and it matches current input)
        if (_savedUsername != null &&
            _savedUsername!.isNotEmpty &&
            studentIdController.text == _savedUsername)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _showSwitchAccountDialog,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(Icons.swap_horiz, size: 16, color: evsuRed),
                label: Text(
                  'Switch Account',
                  style: TextStyle(
                    color: evsuRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Show confirmation dialog for switching account
  void _showSwitchAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        const Color evsuRed = Color(0xFFB01212);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.swap_horiz, color: evsuRed, size: 24),
              const SizedBox(width: 12),
              const Text(
                'Switch Account?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          content: const Text(
            'Are you sure you want to switch to a different account? This will clear the saved username and allow you to login with a different account.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            // Cancel button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),

            // Confirm button
            ElevatedButton(
              onPressed: () async {
                // Clear saved username
                await UsernameStorageService.clearUsername();

                // Clear text fields
                setState(() {
                  _savedUsername = null;
                  studentIdController.clear();
                  passwordController.clear();
                });

                // Close dialog
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: evsuRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Switch',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFloatingErrorModal() {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Responsive calculations
    final isSmallScreen = screenWidth < 400;
    final isVerySmallScreen = screenWidth < 350;

    // Dynamic sizing
    final modalWidth = isSmallScreen ? screenWidth * 0.9 : screenWidth * 0.8;
    final iconSize =
        isVerySmallScreen
            ? 16.0
            : isSmallScreen
            ? 20.0
            : 24.0;
    final titleFontSize =
        isVerySmallScreen
            ? 14.0
            : isSmallScreen
            ? 16.0
            : 18.0;
    final messageFontSize =
        isVerySmallScreen
            ? 11.0
            : isSmallScreen
            ? 12.0
            : 13.0;
    final buttonFontSize = isVerySmallScreen ? 12.0 : 14.0;

    return Positioned(
      top: screenHeight * 0.35,
      left: (screenWidth - modalWidth) / 2,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: modalWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _floatingErrorColor.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon and close button
                Row(
                  children: [
                    Container(
                      width: isSmallScreen ? 32 : 36,
                      height: isSmallScreen ? 32 : 36,
                      decoration: BoxDecoration(
                        color: _floatingErrorColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _floatingErrorIcon,
                        color: _floatingErrorColor,
                        size: iconSize,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 12 : 16),
                    Expanded(
                      child: Text(
                        _floatingErrorTitle,
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: _hideFloatingError,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: isSmallScreen ? 18 : 20,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isSmallScreen ? 12 : 16),

                // Message
                Text(
                  _floatingErrorMessage,
                  style: TextStyle(
                    fontSize: messageFontSize,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                SizedBox(height: isSmallScreen ? 16 : 20),

                // Action buttons
                Row(
                  children: [
                    // Retry button for internet issues
                    if (_floatingErrorTitle.toLowerCase().contains(
                          'internet',
                        ) ||
                        _floatingErrorTitle.toLowerCase().contains(
                          'connection',
                        )) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _hideFloatingError();
                            _login();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _floatingErrorColor,
                            side: BorderSide(color: _floatingErrorColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallScreen ? 8 : 10,
                            ),
                          ),
                          child: Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 12),
                    ],

                    // OK button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _hideFloatingError,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _floatingErrorColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 8 : 10,
                          ),
                          elevation: 2,
                        ),
                        child: Text(
                          'OK',
                          style: TextStyle(
                            fontSize: buttonFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingOfflineBanner() {
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final isWideScreen = screenWidth > 400;
    final isVerySmallScreen = screenWidth < 320;
    final double maxCardWidth = screenWidth >= 600 ? 520 : screenWidth - 32;

    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: Material(
          color: Colors.transparent,
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: maxCardWidth,
            decoration: BoxDecoration(
              color: Colors.orange[50],
              border: Border.all(color: Colors.orange[300]!),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child:
                isWideScreen
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off,
                          color: Colors.orange[700],
                          size: (screenWidth * 0.055).clamp(20.0, 28.0),
                        ),
                        SizedBox(width: (screenWidth * 0.03).clamp(8.0, 16.0)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'No Internet Connection',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: (screenWidth * 0.035).clamp(
                                    14.0,
                                    18.0,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                                softWrap: true,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Please check your network settings.',
                                style: TextStyle(
                                  color: Colors.orange[600],
                                  fontSize: (screenWidth * 0.03).clamp(
                                    12.0,
                                    16.0,
                                  ),
                                  fontWeight: FontWeight.w500,
                                ),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: (screenWidth * 0.03).clamp(8.0, 16.0)),
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 100),
                          child: ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                hasInternetConnection = false;
                              });
                              final hasInternet =
                                  await _checkInternetConnection();
                              if (!mounted) return;
                              setState(() {
                                hasInternetConnection = hasInternet;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Retry',
                              style: TextStyle(
                                fontSize: (screenWidth * 0.03).clamp(
                                  12.0,
                                  16.0,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ),
                      ],
                    )
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.wifi_off,
                              color: Colors.orange[700],
                              size: (screenWidth * 0.06).clamp(18.0, 24.0),
                            ),
                            SizedBox(width: screenWidth * 0.025),
                            Expanded(
                              child: Text(
                                'No Internet Connection',
                                style: TextStyle(
                                  color: Colors.orange[700],
                                  fontSize: (isVerySmallScreen
                                          ? screenWidth * 0.035
                                          : screenWidth * 0.032)
                                      .clamp(13.0, 16.0),
                                  fontWeight: FontWeight.w600,
                                ),
                                softWrap: true,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenWidth * 0.025),
                        Text(
                          'Please check your network settings.',
                          style: TextStyle(
                            color: Colors.orange[600],
                            fontSize: (isVerySmallScreen
                                    ? screenWidth * 0.03
                                    : screenWidth * 0.028)
                                .clamp(11.0, 14.0),
                            fontWeight: FontWeight.w500,
                          ),
                          softWrap: true,
                          maxLines: 3,
                        ),
                        SizedBox(height: screenWidth * 0.03),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () async {
                              setState(() {
                                hasInternetConnection = false;
                              });
                              final hasInternet =
                                  await _checkInternetConnection();
                              if (!mounted) return;
                              setState(() {
                                hasInternetConnection = hasInternet;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[700],
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: (screenWidth * 0.025).clamp(
                                  8.0,
                                  14.0,
                                ),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Retry Connection',
                              style: TextStyle(
                                fontSize: (isVerySmallScreen
                                        ? screenWidth * 0.03
                                        : screenWidth * 0.028)
                                    .clamp(12.0, 14.0),
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.fade,
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color evsuRed = Color(0xFFB01212); // deep red to match EVSU look

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Decorative top header with downward curve
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: _DownArcClipper(curveDepth: 32),
              child: Container(height: 88, color: evsuRed),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 96, 24, 16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo + App Name
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/letter_e.png',
                          width: 64,
                          height: 64,
                        ),
                        const Text(
                          'campuspay',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: evsuRed,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 45),

                    // (Removed in-flow banner; now rendered as floating overlay)

                    // Username section (with saved usernames support)
                    _buildUsernameSection(evsuRed),

                    const SizedBox(height: 36),

                    // Password
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 14,
                          color: evsuRed.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passwordController,
                      obscureText: !isPasswordVisible,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Enter your Password',
                        prefixIcon: const Icon(Icons.lock, color: evsuRed),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: evsuRed,
                          ),
                          onPressed: () {
                            setState(
                              () => isPasswordVisible = !isPasswordVisible,
                            );
                          },
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: evsuRed,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: evsuRed),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // Navigate to design-only ForgotPasswordPage (no logic yet)
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordPage(),
                            ),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final double screenWidth =
                                MediaQuery.of(context).size.width;
                            final bool isVerySmall = screenWidth < 320;
                            return Text(
                              'Forgot password?',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: evsuRed,
                                fontWeight: FontWeight.w600,
                                fontSize: isVerySmall ? 12 : 14,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Login Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: evsuRed,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed:
                            (isLoading || !hasInternetConnection)
                                ? null
                                : _login,
                        child:
                            isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Debug buttons - only show if debug mode is enabled
                    if (_showDebugButtons) ...[
                      // Debug: Clear Session Button (for development)
                      if (SessionService.isLoggedIn)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 16),
                          child: OutlinedButton(
                            onPressed: () async {
                              await SessionService.forceClearSession();
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Session force cleared. Please login again.',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.orange),
                              foregroundColor: Colors.orange,
                            ),
                            child: const Text('Clear Session (Debug)'),
                          ),
                        ),

                      // Debug: Reset Onboarding Button (for testing)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await OnboardingUtils.resetOnboardingForTesting();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Onboarding reset! Restart app to see onboarding.',
                                ),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.green),
                            foregroundColor: Colors.green,
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reset Onboarding (Debug)'),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
          // Floating offline banner that overlaps content without shifting layout
          if (!hasInternetConnection) _buildFloatingOfflineBanner(),
          // Modal barrier + Floating Error Modal on top of everything
          if (_showFloatingError) ...[
            // Blocks interaction behind and dims background
            ModalBarrier(dismissible: false, color: Colors.black54),
            _buildFloatingErrorModal(),
          ],
        ],
      ),
    );
  }
}

class _DownArcClipper extends CustomClipper<Path> {
  _DownArcClipper({required this.curveDepth});

  final double curveDepth;

  @override
  Path getClip(Size size) {
    final Path path = Path();
    // Start at top-left
    path.lineTo(0, size.height - curveDepth);
    // Draw a downward-facing arc across the bottom of the header
    path.quadraticBezierTo(
      size.width / 2,
      size.height + curveDepth,
      size.width,
      size.height - curveDepth,
    );
    // Right edge up to top-right
    path.lineTo(size.width, 0);
    // Close back to origin
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_DownArcClipper oldClipper) {
    return oldClipper.curveDepth != curveDepth;
  }
}
