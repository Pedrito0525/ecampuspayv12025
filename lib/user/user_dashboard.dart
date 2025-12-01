import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
// removed unused: import 'package:http/http.dart' as http;
// removed unused: import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'security_privacy_screen.dart';
import 'withdraw_screen.dart';
import 'loan_application_screen.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../services/encryption_service.dart';
import '../services/inbox_service.dart';
import '../services/notification_service.dart';
import '../services/realtime_notification_service.dart';
import '../services/loan_reminder_service.dart';
import '../login_page.dart';
import 'dart:async'; // Added for StreamSubscription
// removed unused: import '../services/paytaca_invoice_service.dart';
import '../admin/admin_dashboard.dart';
import '../services_school/service_dashboard.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard>
    with WidgetsBindingObserver {
  static const Color evsuRed = Color(0xFFB91C1C);
  int _currentIndex = 0;

  // Maintenance mode subscription
  StreamSubscription<List<Map<String, dynamic>>>? _maintenanceModeSub;
  Timer? _maintenanceCheckTimer;

  // Auto-logout on inactivity
  Timer? _inactivityTimer;
  DateTime? _lastActivityTime;
  bool _isAppInBackground = false;
  DateTime? _backgroundTime;

  List<Widget> get _tabs => [
    _HomeTab(onNavigateToTransactions: () => setState(() => _currentIndex = 2)),
    const _InboxTab(),
    const _TransactionsTab(),
    const _ProfileTab(),
  ];

  /// Get current Philippines time (UTC+8) as ISO 8601 string
  /// This stores the timestamp with +8 hours offset so it represents Philippines local time
  static String _getPhilippinesTimeISO() {
    // Get current time in UTC
    final nowUtc = DateTime.now().toUtc();
    // Add 8 hours to represent Philippines time
    final phTime = nowUtc.add(const Duration(hours: 8));
    // Format as ISO 8601 with explicit timezone offset +08:00
    // This tells the database this is Philippines time, which it will convert to UTC for storage
    return phTime.toIso8601String().replaceFirst('Z', '+08:00');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSession();
    _initializeNotificationSystem();
    _subscribeToMaintenanceMode();
    _startInactivityTimer();
  }

  Future<void> _initializeNotificationSystem() async {
    try {
      print('DEBUG DASHBOARD: Initializing notification system...');

      // Initialize notification types and tables
      print('DEBUG DASHBOARD: Initializing notification types...');
      await NotificationService.initializeNotificationTypes();

      print('DEBUG DASHBOARD: Creating notifications table...');
      await NotificationService.createNotificationsTable();

      // Create loan due date notifications
      print('DEBUG DASHBOARD: Creating loan due notifications...');
      await LoanReminderService.checkAndCreateLoanReminders();

      print('DEBUG DASHBOARD: Notification system initialization completed');
    } catch (e) {
      print('ERROR DASHBOARD: Error initializing notification system: $e');
    }
  }

  void _checkSession() {
    // Check if session exists and is valid
    if (!SessionService.isLoggedIn) {
      // Redirect to login if not logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      });
      return;
    }

    // If logged in but not a student, redirect based on user type
    if (!SessionService.isStudent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (SessionService.isAdmin) {
          // Navigate to admin dashboard if admin
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AdminDashboard()),
          );
        } else if (SessionService.isService) {
          // Navigate to service dashboard if service
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder:
                  (context) => const ServiceDashboard(
                    serviceName: 'Service',
                    serviceType: 'Service',
                  ),
            ),
          );
        } else {
          // Unknown user type, redirect to login
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      });
    }

    // If we reach here, the session is valid - refresh data to sync
    _refreshSessionData();
  }

  Future<void> _refreshSessionData() async {
    // Refresh user data to ensure we have the latest information
    try {
      await SessionService.refreshUserData();
      print('DEBUG: Session refreshed successfully');
    } catch (e) {
      print('DEBUG: Failed to refresh session: $e');
      // If refresh fails, still keep the user logged in with cached data
    }
  }

  /// Subscribe to maintenance mode changes and auto-logout when enabled
  Future<void> _subscribeToMaintenanceMode() async {
    try {
      await SupabaseService.initialize();

      // Cancel existing subscription and timer if any
      await _maintenanceModeSub?.cancel();
      _maintenanceCheckTimer?.cancel();

      // Method 1: Try Realtime subscription
      try {
        _maintenanceModeSub = SupabaseService.client
            .from('system_update_settings')
            .stream(primaryKey: ['id'])
            .eq('id', 1)
            .listen(
              (rows) {
                print(
                  'DEBUG: Maintenance mode stream received ${rows.length} rows',
                );
                if (rows.isNotEmpty) {
                  final settings = rows.first;
                  _checkMaintenanceMode(settings);
                }
              },
              onError: (error) {
                print('ERROR: Maintenance mode subscription error: $error');
              },
            );
        print('DEBUG: Subscribed to maintenance mode changes via Realtime');
      } catch (streamError) {
        print('ERROR: Failed to setup Realtime subscription: $streamError');
      }

      // Method 2: Always start periodic polling as backup (every 10 seconds)
      // This ensures we catch changes even if Realtime doesn't work
      _startMaintenanceModePolling();
    } catch (e) {
      print('ERROR: Failed to subscribe to maintenance mode: $e');
      // Still start polling as fallback
      _startMaintenanceModePolling();
    }
  }

  /// Start periodic polling for maintenance mode (backup method)
  void _startMaintenanceModePolling() {
    _maintenanceCheckTimer?.cancel();
    _maintenanceCheckTimer = Timer.periodic(const Duration(seconds: 10), (
      timer,
    ) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      await _checkMaintenanceModePeriodic();
    });
    print('DEBUG: Started maintenance mode polling (every 10 seconds)');
  }

  /// Periodic check for maintenance mode
  Future<void> _checkMaintenanceModePeriodic() async {
    try {
      final result = await SupabaseService.getSystemUpdateSettings();
      if (result['success'] == true && result['data'] != null) {
        final settings = result['data'] as Map<String, dynamic>;
        _checkMaintenanceMode(settings);
      }
    } catch (e) {
      print('ERROR: Periodic maintenance check failed: $e');
    }
  }

  /// Check maintenance mode settings and logout if needed
  void _checkMaintenanceMode(Map<String, dynamic> settings) {
    final maintenanceMode = settings['maintenance_mode'] == true;
    final disableAllLogins = settings['disable_all_logins'] == true;

    print(
      'DEBUG: Maintenance check - maintenance_mode: $maintenanceMode, disable_all_logins: $disableAllLogins',
    );

    // Logout if either maintenance mode or disable all logins is enabled
    if ((maintenanceMode || disableAllLogins) && mounted) {
      print(
        'DEBUG: Maintenance mode or disable_all_logins detected, logging out user',
      );
      _handleMaintenanceModeLogout();
    }
  }

  /// Handle automatic logout when maintenance mode is enabled
  Future<void> _handleMaintenanceModeLogout() async {
    if (!mounted) return;

    try {
      // Clear session
      await SessionService.forceClearSession();

      // Show logout dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.build_circle, color: evsuRed, size: 28),
                    SizedBox(width: 8),
                    Expanded(child: Text('System Maintenance')),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'The system is currently under maintenance.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'You have been automatically logged out for your security.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Please try again later once maintenance is complete.',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Navigate to login page
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const LoginPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: evsuRed,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      print('ERROR: Failed to handle maintenance mode logout: $e');
      // Still navigate to login even if logout fails
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _maintenanceModeSub?.cancel();
    _maintenanceCheckTimer?.cancel();
    _inactivityTimer?.cancel();
    super.dispose();
  }

  /// Handle app lifecycle changes (paused/resumed)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App went to background
      _isAppInBackground = true;
      _backgroundTime = DateTime.now();
      _inactivityTimer?.cancel();
      print('DEBUG: App went to background, starting background timer');
      _startBackgroundTimer();
    } else if (state == AppLifecycleState.resumed) {
      // App came back to foreground
      _isAppInBackground = false;
      _backgroundTime = null;
      _inactivityTimer?.cancel();
      print('DEBUG: App resumed, resetting activity timer');
      _resetActivityTime();
      _startInactivityTimer();
    }
  }

  /// Start timer to track inactivity (5 minutes)
  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _resetActivityTime();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final timeSinceLastActivity =
          _lastActivityTime != null
              ? now.difference(_lastActivityTime!)
              : const Duration(seconds: 0);

      // 5 minutes = 300 seconds
      if (timeSinceLastActivity.inSeconds >= 300) {
        print('DEBUG: 5 minutes of inactivity detected, logging out');
        timer.cancel();
        _performAutoLogout();
      }
    });
  }

  /// Start timer when app is in background (5 minutes)
  void _startBackgroundTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (!_isAppInBackground || _backgroundTime == null) {
        timer.cancel();
        return;
      }

      final now = DateTime.now();
      final timeInBackground = now.difference(_backgroundTime!);

      // 5 minutes = 300 seconds
      if (timeInBackground.inSeconds >= 300) {
        print('DEBUG: App in background for 5 minutes, logging out');
        timer.cancel();
        _performAutoLogout();
      }
    });
  }

  /// Reset activity time to current time
  void _resetActivityTime() {
    _lastActivityTime = DateTime.now();
  }

  /// Handle user interaction (tap, scroll, etc.)
  void _onUserInteraction() {
    if (!_isAppInBackground) {
      _resetActivityTime();
    }
  }

  /// Perform automatic logout
  Future<void> _performAutoLogout() async {
    if (!mounted) return;

    try {
      // Stop realtime notifications before clearing session
      await RealtimeNotificationService.stopListening();

      // Clear session
      await SessionService.clearSession();

      // Navigate to login page
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print('ERROR: Auto-logout failed: $e');
      // Fallback navigation
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onUserInteraction,
      onPanDown: (_) => _onUserInteraction(),
      onScaleStart: (_) => _onUserInteraction(),
      child: Listener(
        onPointerDown: (_) => _onUserInteraction(),
        onPointerMove: (_) => _onUserInteraction(),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            _onUserInteraction();
            return false;
          },
          child: Scaffold(
            backgroundColor: Colors.grey[50],
            body: _tabs[_currentIndex],
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: evsuRed,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  _onUserInteraction();
                  setState(() => _currentIndex = index);
                },
                type: BottomNavigationBarType.fixed,
                selectedItemColor: Colors.white,
                unselectedItemColor: Colors.white60,
                backgroundColor: evsuRed,
                elevation: 0,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                unselectedLabelStyle: const TextStyle(fontSize: 11),
                items: [
                  BottomNavigationBarItem(
                    icon: Icon(
                      _currentIndex == 0 ? Icons.home : Icons.home_outlined,
                      size: 20,
                    ),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      _currentIndex == 1 ? Icons.mail : Icons.mail_outline,
                      size: 20,
                    ),
                    label: 'Inbox',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      _currentIndex == 2
                          ? Icons.credit_card
                          : Icons.credit_card_outlined,
                      size: 20,
                    ),
                    label: 'Transactions',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      _currentIndex == 3 ? Icons.person : Icons.person_outline,
                      size: 20,
                    ),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final VoidCallback? onNavigateToTransactions;

  const _HomeTab({this.onNavigateToTransactions});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  static const Color evsuRed = Color(0xFFB91C1C);
  static const Color evsuRedDark = Color(0xFF7F1D1D);

  int _selectedTab = 0; // 0 for Wallet, 1 for Borrow
  bool _balanceVisible = true;
  List<Map<String, dynamic>> _cachedActiveLoans = const [];
  bool _isRefreshingActiveLoan = false;

  /// Get current Philippines time (UTC+8) as ISO 8601 string
  /// This stores the timestamp with +8 hours offset so it represents Philippines local time
  static String _getPhilippinesTimeISO() {
    // Get current time in UTC
    final nowUtc = DateTime.now().toUtc();
    // Add 8 hours to represent Philippines time
    final phTime = nowUtc.add(const Duration(hours: 8));
    // Format as ISO 8601 with explicit timezone offset +08:00
    // This tells the database this is Philippines time, which it will convert to UTC for storage
    return phTime.toIso8601String().replaceFirst('Z', '+08:00');
  }

  // Realtime recent transactions for current student
  final List<Map<String, dynamic>> _recentTransactions = [];
  StreamSubscription<List<Map<String, dynamic>>>? _homeTopUpSub;
  StreamSubscription<List<Map<String, dynamic>>>? _homeServiceTxSub;
  StreamSubscription<List<Map<String, dynamic>>>? _homeLoanSub;
  StreamSubscription<List<Map<String, dynamic>>>? _homeActiveLoansSub;
  StreamSubscription<List<Map<String, dynamic>>>? _homeTransferSub;
  Timer? _balanceRefreshTimer;
  Timer? _mergeDebounceTimer;
  String _lastTransactionsHash = '';
  Future<List<Map<String, dynamic>>>? _cachedActiveLoanFuture;
  Future<List<Map<String, dynamic>>>? _cachedStudentLoansFuture;

  @override
  void initState() {
    super.initState();
    _loadRecentTransactions();
    _subscribeRecentTransactions();
    _startBalanceRefreshTimer();
  }

  @override
  void dispose() {
    try {
      _homeTopUpSub?.cancel();
    } catch (_) {}
    try {
      _homeServiceTxSub?.cancel();
    } catch (_) {}
    try {
      _homeLoanSub?.cancel();
    } catch (_) {}
    try {
      _homeActiveLoansSub?.cancel();
    } catch (_) {}
    try {
      _homeTransferSub?.cancel();
    } catch (_) {}
    _balanceRefreshTimer?.cancel();
    _mergeDebounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentTransactions() async {
    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserStudentId;
      print('DEBUG: Loading recent transactions for studentId: "$studentId"');
      if (studentId.isEmpty) {
        print('DEBUG: StudentId is empty, returning');
        return;
      }

      // Fetch last 5 top-ups
      print('DEBUG: Querying top_up_transactions for studentId: "$studentId"');
      final topups = await SupabaseService.client
          .from('top_up_transactions')
          .select(
            'id, student_id, amount, new_balance, created_at, processed_by',
          )
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .limit(5);

      print('DEBUG: Top-up query result: $topups');

      // Debug: Check if any top-up transactions exist at all
      try {
        final allTopups = await SupabaseService.client
            .from('top_up_transactions')
            .select('id, student_id, amount, created_at')
            .limit(10);
        print(
          'DEBUG: Sample of all top_up_transactions in database: $allTopups',
        );
      } catch (e) {
        print('DEBUG: Error querying all top-ups: $e');
      }

      // Debug: Raw SQL query to see exact data for this student
      try {
        final rawResult = await SupabaseService.client.rpc(
          'debug_student_topups',
          params: {'p_student_id': studentId},
        );
        print('DEBUG: Raw SQL result for student "$studentId": $rawResult');
      } catch (e) {
        print('DEBUG: Raw SQL query failed (function might not exist): $e');

        // Alternative: Try direct query with different approaches
        try {
          // Query with exact match
          final exactMatch = await SupabaseService.client
              .from('top_up_transactions')
              .select('*')
              .eq('student_id', studentId);
          print('DEBUG: Exact match query result: $exactMatch');

          // Query with LIKE to check for similar IDs
          final likeMatch = await SupabaseService.client
              .from('top_up_transactions')
              .select('student_id, amount, created_at')
              .like('student_id', '%${studentId}%');
          print('DEBUG: LIKE match query result: $likeMatch');

          // Get all distinct student_ids to see what's actually in the table
          final distinctStudents = await SupabaseService.client
              .from('top_up_transactions')
              .select('student_id')
              .limit(20);
          print(
            'DEBUG: All student_ids in top_up_transactions: $distinctStudents',
          );
        } catch (altError) {
          print('DEBUG: Alternative queries failed: $altError');
        }
      }

      // Fetch last 5 payments (service_transactions) - filter by student_id column
      final payments = await SupabaseService.client
          .from('service_transactions')
          .select('total_amount, created_at, student_id')
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .limit(5);

      // Fetch user transfers (both sent and received) for recent transactions
      List<Map<String, dynamic>> transfers = [];
      try {
        print('DEBUG: Attempting to query user_transfers table...');

        // First, let's check if the table exists by trying a simple query
        final testQuery = await SupabaseService.client
            .from('user_transfers')
            .select('id')
            .limit(1);
        print('DEBUG: user_transfers table test query result: $testQuery');

        // Now try the actual query
        transfers = await SupabaseService.client
            .from('user_transfers')
            .select(
              'id, sender_student_id, recipient_student_id, amount, sender_new_balance, recipient_new_balance, created_at, status',
            )
            .or(
              'sender_student_id.eq.$studentId,recipient_student_id.eq.$studentId',
            )
            .order('created_at', ascending: false)
            .limit(5);

        print(
          'DEBUG: user_transfers query successful, found ${transfers.length} records',
        );
      } catch (e) {
        print('DEBUG: Error querying user_transfers table: $e');
        // Try alternative query without OR condition
        try {
          print('DEBUG: Trying alternative query for user_transfers...');
          transfers = await SupabaseService.client
              .from('user_transfers')
              .select('*')
              .limit(10);
          print('DEBUG: Alternative query found ${transfers.length} records');
        } catch (altError) {
          print('DEBUG: Alternative query also failed: $altError');
          transfers = [];
        }
      }

      print('DEBUG: Recent transactions - studentId: "$studentId"');
      print(
        'DEBUG: Admin top-ups (from top_up_transactions): ${topups.length} rows',
      );
      if (topups.isNotEmpty) {
        print('DEBUG: Top-ups sample: ${topups.first}');
      }
      print(
        'DEBUG: Service payments (from service_transactions): ${payments.length} rows',
      );
      if (payments.isNotEmpty) {
        print('DEBUG: Payments sample: ${payments.first}');
      }
      print('DEBUG: User transfers (recent): ${transfers.length} rows');
      if (transfers.isNotEmpty) {
        print('DEBUG: Transfers sample: ${transfers.first}');
      }

      // Fetch last 5 loan payments
      List<Map<String, dynamic>> loanPayments = [];
      try {
        print('DEBUG: Querying loan_payments for studentId: "$studentId"');
        loanPayments = await SupabaseService.client
            .from('loan_payments')
            .select(
              'id, student_id, payment_amount, remaining_balance, created_at, loan_id',
            )
            .eq('student_id', studentId)
            .order('created_at', ascending: false)
            .limit(5);
        print('DEBUG: Loan payments found: ${loanPayments.length}');
        if (loanPayments.isNotEmpty) {
          print('DEBUG: Loan payments sample: ${loanPayments.first}');
        }
      } catch (e) {
        print('DEBUG: Error querying loan payments: $e');
      }

      final List<Map<String, dynamic>> merged = [];
      for (final t in (topups as List)) {
        merged.add({
          'type': 'top_up',
          'amount': (t['amount'] as num?) ?? 0,
          'created_at':
              t['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          'new_balance': (t['new_balance'] as num?) ?? 0,
        });
      }
      for (final p in (payments as List)) {
        merged.add({
          'type': 'payment',
          'amount': (p['total_amount'] as num?) ?? 0,
          'created_at':
              p['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        });
      }
      for (final transfer in (transfers as List)) {
        final isSent = transfer['sender_student_id'] == studentId;
        merged.add({
          'type': 'transfer',
          'amount': (transfer['amount'] as num?) ?? 0,
          'created_at':
              transfer['created_at']?.toString() ??
              DateTime.now().toIso8601String(),
          'new_balance':
              isSent
                  ? (transfer['sender_new_balance'] as num?) ?? 0
                  : (transfer['recipient_new_balance'] as num?) ?? 0,
          'transfer_direction': isSent ? 'sent' : 'received',
          'sender_student_id': transfer['sender_student_id'],
          'recipient_student_id': transfer['recipient_student_id'],
          'status': transfer['status'],
        });
      }
      for (final lp in (loanPayments as List)) {
        merged.add({
          'type': 'loan_payment',
          'amount': (lp['payment_amount'] as num?) ?? 0,
          'created_at':
              lp['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          'remaining_balance': (lp['remaining_balance'] as num?) ?? 0,
          'loan_id': lp['loan_id'],
        });
      }
      merged.sort(
        (a, b) => DateTime.parse(
          b['created_at'],
        ).compareTo(DateTime.parse(a['created_at'])),
      );

      // Only update if data actually changed to prevent flicker
      final newData = merged.take(10).toList();
      final newHash = _generateTransactionsHash(newData);

      if (newHash != _lastTransactionsHash) {
        _lastTransactionsHash = newHash;
        if (mounted) {
          setState(() {
            _recentTransactions
              ..clear()
              ..addAll(newData);
          });
        }
      }
    } catch (e) {
      print('DEBUG: Error loading recent transactions: $e');
      if (mounted) {
        setState(() {
          _recentTransactions.clear();
          _lastTransactionsHash = '';
        });
      }
    }
  }

  void _subscribeRecentTransactions() {
    final studentId = SessionService.currentUserStudentId;
    if (studentId.isEmpty) return;

    try {
      _homeTopUpSub?.cancel();
    } catch (_) {}
    _homeTopUpSub = SupabaseService.client
        .from('top_up_transactions')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .listen((rows) {
          final additions =
              rows
                  .map(
                    (r) => {
                      'type': 'top_up',
                      'amount': (r['amount'] as num?) ?? 0,
                      'created_at':
                          r['created_at']?.toString() ??
                          DateTime.now().toIso8601String(),
                      'new_balance': (r['new_balance'] as num?) ?? 0,
                    },
                  )
                  .toList();
          _mergeHomeRecent(additions);
          // Refresh balance when top-up is detected
          if (additions.isNotEmpty) {
            _refreshBalance();
          }
        });

    try {
      _homeServiceTxSub?.cancel();
    } catch (_) {}
    _homeServiceTxSub = SupabaseService.client
        .from('service_transactions')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .listen((rows) {
          final additions =
              rows
                  .map(
                    (r) => {
                      'type': 'payment',
                      'amount': (r['total_amount'] as num?) ?? 0,
                      'created_at':
                          r['created_at']?.toString() ??
                          DateTime.now().toIso8601String(),
                    },
                  )
                  .toList();
          _mergeHomeRecent(additions);
        });

    // Subscribe to loan payments for real-time updates
    // Note: Refresh both active loan display AND recent transactions
    try {
      _homeLoanSub?.cancel();
    } catch (_) {}
    _homeLoanSub = SupabaseService.client
        .from('loan_payments')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .listen((rows) {
          if (!mounted) return;
          // Add loan payments to recent transactions
          final additions =
              rows
                  .map(
                    (r) => {
                      'type': 'loan_payment',
                      'amount': (r['payment_amount'] as num?) ?? 0,
                      'created_at':
                          r['created_at']?.toString() ??
                          DateTime.now().toIso8601String(),
                      'remaining_balance':
                          (r['remaining_balance'] as num?) ?? 0,
                      'loan_id': r['loan_id'],
                    },
                  )
                  .toList();
          _mergeHomeRecent(additions);
          // Reset cached future to force refresh of active loan display
          _cachedActiveLoanFuture = null;
          setState(() {});
        });

    // Subscribe to active loan changes so the borrow tab stays in sync
    // Note: Only refresh active loan display, NOT loan history (history only refreshes on loan application)
    try {
      _homeActiveLoansSub?.cancel();
    } catch (_) {}
    _homeActiveLoansSub = SupabaseService.client
        .from('active_loans')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .listen((rows) {
          if (!mounted) return;
          // Reset cached future to force refresh of active loan display only
          _cachedActiveLoanFuture = null;
          setState(() {});
        });

    // Subscribe to user transfers for real-time updates
    try {
      _homeTransferSub?.cancel();
    } catch (_) {}
    _homeTransferSub = SupabaseService.client
        .from('user_transfers')
        .stream(primaryKey: ['id'])
        .listen((rows) {
          // Filter rows to include only transfers involving this student
          final filteredRows =
              rows
                  .where(
                    (row) =>
                        row['sender_student_id'] == studentId ||
                        row['recipient_student_id'] == studentId,
                  )
                  .toList();
          final additions =
              filteredRows.map((r) {
                final isSent = r['sender_student_id'] == studentId;
                return {
                  'type': 'transfer',
                  'amount': (r['amount'] as num?) ?? 0,
                  'created_at':
                      r['created_at']?.toString() ??
                      DateTime.now().toIso8601String(),
                  'new_balance':
                      isSent
                          ? (r['sender_new_balance'] as num?) ?? 0
                          : (r['recipient_new_balance'] as num?) ?? 0,
                  'transfer_direction': isSent ? 'sent' : 'received',
                  'sender_student_id': r['sender_student_id'],
                  'recipient_student_id': r['recipient_student_id'],
                  'status': r['status'],
                };
              }).toList();
          _mergeHomeRecent(additions);
        });
  }

  void _mergeHomeRecent(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return;

    // Debounce updates to prevent flicker from rapid realtime updates
    _mergeDebounceTimer?.cancel();
    _mergeDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      final List<Map<String, dynamic>> merged = List.from(_recentTransactions);
      merged.insertAll(0, items);
      merged.sort(
        (a, b) => DateTime.parse(
          b['created_at'],
        ).compareTo(DateTime.parse(a['created_at'])),
      );

      // Only update if data actually changed
      final newData = merged.take(10).toList();
      final newHash = _generateTransactionsHash(newData);

      if (newHash != _lastTransactionsHash) {
        _lastTransactionsHash = newHash;
        if (mounted) {
          setState(() {
            _recentTransactions
              ..clear()
              ..addAll(newData);
          });
        }
      }
    });
  }

  /// Generate a hash for transactions list to detect changes
  String _generateTransactionsHash(List<Map<String, dynamic>> transactions) {
    if (transactions.isEmpty) return '';
    return transactions
        .map((t) {
          return '${t['type']}_${t['created_at']}_${t['amount']}';
        })
        .join('|');
  }

  /// Start periodic balance refresh timer (every 10 seconds)
  void _startBalanceRefreshTimer() {
    _balanceRefreshTimer?.cancel();
    _balanceRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _refreshBalance();
      } else {
        timer.cancel();
      }
    });
  }

  /// Refresh balance silently (no animation)
  Future<void> _refreshBalance() async {
    try {
      await SessionService.refreshUserData();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('DEBUG: Error refreshing balance: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [evsuRed, evsuRedDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              _buildHeader(),

              // Main Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 255, 252, 243),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Tab Navigation
                      _buildTabNavigation(),

                      // Tab Content
                      Expanded(
                        child:
                            _selectedTab == 0
                                ? _buildWalletContent()
                                : _buildBorrowContent(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Center(
                  child: Text(
                    'E',
                    style: TextStyle(
                      color: evsuRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'HELLO!',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: _showHelpSupportDialog,
                icon: const Icon(Icons.help_outline, color: Colors.white),
                tooltip: 'Help & Support',
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'WELCOME',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            SessionService.currentUserName,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpSupportDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.support_agent, color: evsuRed),
                SizedBox(width: 8),
                Text('Help & Support'),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '1) Top-Up',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Option A: Top-Up via GCash',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Select “Top-Up via GCash”.\n'
                      '• Enter the amount to top up.\n'
                      '• Upload an image proof of the GCash payment (screenshot or receipt).\n'
                      '• The system sends a request to the admin for approval.\n'
                      '• Admin reviews the uploaded payment proof.\n'
                      '• If approved, the amount is added to your e-wallet balance.\n'
                      '• If rejected, you will be notified and your balance remains unchanged.',
                      style: TextStyle(height: 1.35),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Option B: Top-Up via Admin Office',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Go to the admin office station.\n'
                      '• Request top-up and provide the amount to add.\n'
                      '• Admin manually updates your balance.\n'
                      '• Your e-wallet balance reflects the update immediately.',
                      style: TextStyle(height: 1.35),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '2) Withdrawal for Services',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Click “Withdraw” and select the service type (e.g., vendor payment).\n'
                      '• Enter the withdrawal amount.\n'
                      '• Choose a withdrawal method:\n'
                      '    – GCash → provide GCash account number and name.\n'
                      '    – On-Site Cash → request cash at the admin station.\n'
                      '• The system sends your withdrawal request to admin.\n'
                      '• Admin reviews and approves/rejects the request.',
                      style: TextStyle(height: 1.35),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'If approved:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• The amount is deducted from your e-wallet.\n'
                      '• Funds are sent via GCash or made available for on-site collection.',
                      style: TextStyle(height: 1.35),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'If rejected:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• You will be notified, and your balance remains unchanged.',
                      style: TextStyle(height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildTabNavigation() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 0 ? evsuRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow:
                      _selectedTab == 0
                          ? [
                            BoxShadow(
                              color: evsuRed.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                ),
                child: Text(
                  'Wallet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedTab == 0 ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedTab == 1 ? evsuRed : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow:
                      _selectedTab == 1
                          ? [
                            BoxShadow(
                              color: evsuRed.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                          : null,
                ),
                child: Text(
                  'Borrow',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _selectedTab == 1 ? Colors.white : Colors.grey[600],
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Balance Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            margin: const EdgeInsets.only(bottom: 25),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [evsuRed, evsuRedDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: evsuRed.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Available Balance',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    GestureDetector(
                      onTap:
                          () => setState(
                            () => _balanceVisible = !_balanceVisible,
                          ),
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: Icon(
                          _balanceVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  _balanceVisible
                      ? '₱ ${SessionService.currentUserBalance.toStringAsFixed(2)}'
                      : '₱ •••••',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showTransferDialog(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: evsuRed,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: const Text(
                          'Transfer',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => const SecurityPrivacyScreen(),
                            ),
                          ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tap_and_play,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Tap to Pay',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick Actions
          Row(
            children: [
              Expanded(child: _buildTopUpActionCard()),
              const SizedBox(width: 12),
              Expanded(child: _buildWithdrawActionCard()),
            ],
          ),

          const SizedBox(height: 25),

          // Transaction History
          _buildTransactionHistory(),
        ],
      ),
    );
  }

  Widget _buildBorrowContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [evsuRed, evsuRedDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Text('💸', style: TextStyle(fontSize: 35)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Need Quick Cash?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Borrow money instantly and pay later.\nAvailable for verified students with good standing.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 30),

          // Active Loan Display
          _buildActiveLoanDisplay(),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () => _showAvailableLoans(),
            style: ElevatedButton.styleFrom(
              backgroundColor: evsuRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Apply Loan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),

          const SizedBox(height: 30),

          // Loan History
          _buildLoanHistory(),
        ],
      ),
    );
  }

  /// Build Top Up action card with office hours check
  Widget _buildTopUpActionCard() {
    final isAvailable = _isWithinOfficeHours();

    return GestureDetector(
      onTap: () => _showTopUpDialog(),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors:
                      isAvailable
                          ? [evsuRed, evsuRedDark]
                          : [Colors.grey.shade400, Colors.grey.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('💰', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Top Up',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isAvailable ? Colors.black87 : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isAvailable ? 'Add money to your wallet' : 'Available 8AM-5PM',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isAvailable ? Colors.grey[600] : Colors.orange.shade700,
                fontWeight: isAvailable ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build Withdraw action card with office hours check
  Widget _buildWithdrawActionCard() {
    final isAvailable = _isWithinOfficeHours();

    return GestureDetector(
      onTap: () => _navigateToWithdraw(),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors:
                      isAvailable
                          ? [evsuRed, evsuRedDark]
                          : [Colors.grey.shade400, Colors.grey.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('💳', style: TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Withdraw',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isAvailable ? Colors.black87 : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isAvailable ? 'Cash out your balance' : 'Available 8 AM - 5 PM',
              style: TextStyle(
                fontSize: 11,
                color: isAvailable ? Colors.grey[600] : Colors.orange.shade700,
                fontWeight: isAvailable ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required String icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [evsuRed, evsuRedDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionHistory() {
    if (_recentTransactions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 15),
            Text(
              'No recent activity',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final mapped =
        _recentTransactions.map<Map<String, String>>((t) {
          final type = t['type']?.toString() ?? '';
          final isTopUp = (type == 'top_up');
          final isLoanPayment = (type == 'loan_payment');
          final isTransfer = (type == 'transfer');
          final amount = (t['amount'] as num).toDouble();
          final dt =
              DateTime.tryParse(t['created_at']?.toString() ?? '') ??
              DateTime.now();
          final timeStr =
              '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

          String title;
          String icon;
          String amountStr;
          String transactionType;

          if (isTopUp) {
            title = 'Top-up';
            icon = '💰';
            amountStr = '+₱${amount.toStringAsFixed(2)}';
            transactionType = 'income';
          } else if (isLoanPayment) {
            title = 'Loan Payment';
            icon = '💳';
            amountStr = '-₱${amount.toStringAsFixed(2)}';
            transactionType = 'expense';
          } else if (isTransfer) {
            final direction = t['transfer_direction']?.toString() ?? 'sent';
            title = direction == 'sent' ? 'Transfer Sent' : 'Transfer Received';
            icon = direction == 'sent' ? '📤' : '📥';
            amountStr =
                direction == 'sent'
                    ? '-₱${amount.toStringAsFixed(2)}'
                    : '+₱${amount.toStringAsFixed(2)}';
            transactionType = direction == 'sent' ? 'expense' : 'income';
          } else {
            title = 'Payment';
            icon = '🧾';
            amountStr = '-₱${amount.toStringAsFixed(2)}';
            transactionType = 'expense';
          }

          return {
            'title': title,
            'time': timeStr,
            'amount': amountStr,
            'icon': icon,
            'type': transactionType,
          };
        }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              GestureDetector(
                onTap: () => _showAllTransactions(),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: evsuRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...mapped.asMap().entries.map((entry) {
            final index = entry.key;
            final m = entry.value;
            return _buildTransactionItem(
              m,
              key: ValueKey('${m['time']}_${m['amount']}_$index'),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildActiveLoanDisplay() {
    // Cache the future to prevent unnecessary rebuilds
    _cachedActiveLoanFuture ??= _loadActiveLoan();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _cachedActiveLoanFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          _isRefreshingActiveLoan = true;
          // If we have cached data, show it with a subtle "Refreshing…" hint
          if (_cachedActiveLoans.isNotEmpty) {
            final activeLoan = _cachedActiveLoans.first;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 6),
                      Text('Refreshing…', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                _buildActiveLoanCard(activeLoan),
              ],
            );
          } else {
            return Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: evsuRed),
              ),
            );
          }
        } else {
          _isRefreshingActiveLoan = false;
        }

        final activeLoans = snapshot.data ?? [];
        // Update cache on successful load
        _cachedActiveLoans = activeLoans;
        final activeLoan = activeLoans.isNotEmpty ? activeLoans.first : null;

        if (activeLoan == null) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 48,
                  color: Colors.grey,
                ),
                SizedBox(height: 12),
                Text(
                  'No Active Loans',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You can apply for a loan when needed',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return _buildActiveLoanCard(activeLoan);
      },
    );
  }

  Widget _buildActiveLoanCard(Map<String, dynamic> activeLoan) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: evsuRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: evsuRed,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Active Loan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      activeLoan['status'] == 'overdue'
                          ? Colors.red.shade100
                          : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  activeLoan['status'] == 'overdue' ? 'Overdue' : 'Active',
                  style: TextStyle(
                    color:
                        activeLoan['status'] == 'overdue'
                            ? Colors.red.shade700
                            : Colors.orange.shade700,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Loan Details
          _buildLoanDetailRow(
            'Loan Plan',
            activeLoan['loan_plan_name'] ?? 'N/A',
          ),
          _buildLoanDetailRow(
            'Borrowed Amount',
            '₱${(activeLoan['loan_amount'] as num).toStringAsFixed(2)}',
          ),
          _buildLoanDetailRow(
            'Interest',
            '₱${(activeLoan['interest_amount'] as num).toStringAsFixed(2)}',
          ),
          _buildLoanDetailRow(
            'Total Due',
            '₱${(activeLoan['total_amount'] as num).toStringAsFixed(2)}',
          ),
          _buildLoanDetailRow(
            'Due Date',
            _formatDate(
              DateTime.tryParse(activeLoan['due_date']?.toString() ?? '') ??
                  DateTime.now(),
            ),
          ),

          const SizedBox(height: 16),

          // Payment Options
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentOptions(activeLoan),
                  icon: const Icon(Icons.payment, size: 18),
                  label: const Text('Pay Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: evsuRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoanDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadActiveLoan() async {
    await SupabaseService.initialize();
    final studentId = SessionService.currentUserStudentId;

    print('DEBUG: Loading active loans for studentId: "$studentId"');

    if (studentId.isEmpty) {
      print('DEBUG: StudentId is empty, returning empty list');
      return [];
    }

    try {
      // Direct query to active_loans table (avoid noisy RPC errors)
      final directResponse = await SupabaseService.client
          .from('active_loans')
          .select('''
              id,
              student_id,
              loan_amount,
              interest_amount,
              penalty_amount,
              total_amount,
              term_days,
              due_date,
              status,
              created_at,
              paid_at,
              loan_plans!inner(name)
            ''')
          .eq('student_id', studentId)
          .inFilter('status', ['active', 'overdue'])
          .order('created_at', ascending: false);

      if (directResponse.isEmpty) {
        print('DEBUG: No active/overdue loans found via direct query.');
        return [];
      }

      final loans =
          (directResponse as List)
              .map(
                (loan) => {
                  'id': loan['id'],
                  'loan_plan_name': loan['loan_plans']['name'],
                  'loan_amount': loan['loan_amount'],
                  'interest_amount': loan['interest_amount'],
                  'penalty_amount': loan['penalty_amount'],
                  'total_amount': loan['total_amount'],
                  'term_days': loan['term_days'],
                  'due_date': loan['due_date'],
                  'status': loan['status'],
                  'created_at': loan['created_at'],
                  'paid_at': loan['paid_at'],
                  'days_left': _calculateDaysLeft(loan['due_date']),
                },
              )
              .toList();

      return loans;
    } catch (e) {
      print('DEBUG: Direct active_loans query failed: $e');
      return [];
    }
  }

  void _showPaymentOptions(Map<String, dynamic> loan) {
    showDialog(
      context: context,
      builder:
          (context) => _PaymentOptionsDialog(
            loan: loan,
            onPayFull: () => _payLoanFull(loan),
            onPayPartial: (amount) => _payLoanPartial(loan, amount),
          ),
    );
  }

  Future<void> _payLoanFull(Map<String, dynamic> loan) async {
    try {
      final loanId = loan['id'] as int;
      final studentId = SessionService.currentUserStudentId;

      final response = await SupabaseService.client.rpc(
        'pay_off_loan',
        params: {'p_loan_id': loanId, 'p_student_id': studentId},
      );

      if (response == null) {
        _showErrorSnackBar('Failed to process payment');
        return;
      }

      final data = response as Map<String, dynamic>;

      if (data['success'] == true) {
        Navigator.pop(context); // Close dialog
        _showSuccessSnackBar(data['message'] ?? 'Loan paid successfully!');

        // Refresh user data and UI
        await SessionService.refreshUserData();
        // Reset cached futures to force refresh of both active loan display and loan history
        _cachedActiveLoanFuture = null;
        _cachedStudentLoansFuture = null;
        if (mounted) {
          setState(() {}); // Refresh UI
        }
      } else {
        _showErrorSnackBar(data['message'] ?? 'Failed to pay loan');
      }
    } catch (e) {
      final userFriendlyError = _getUserFriendlyError(e);
      _showErrorSnackBar('Error paying loan: $userFriendlyError');
    }
  }

  Future<void> _payLoanPartial(Map<String, dynamic> loan, double amount) async {
    try {
      final loanId = loan['id'] as int;
      final studentId = SessionService.currentUserStudentId;

      final response = await SupabaseService.client.rpc(
        'make_partial_loan_payment',
        params: {
          'p_loan_id': loanId,
          'p_student_id': studentId,
          'p_payment_amount': amount,
        },
      );

      if (response == null) {
        _showErrorSnackBar('Failed to process payment');
        return;
      }

      final data = response as Map<String, dynamic>;

      if (data['success'] == true) {
        Navigator.pop(context); // Close dialog
        _showSuccessSnackBar(
          data['message'] ?? 'Payment processed successfully!',
        );

        // Refresh user data and UI
        await SessionService.refreshUserData();
        // Reset cached futures to force refresh of both active loan display and loan history
        _cachedActiveLoanFuture = null;
        _cachedStudentLoansFuture = null;
        if (mounted) {
          setState(() {}); // Refresh UI
        }
      } else {
        _showErrorSnackBar(data['message'] ?? 'Failed to process payment');
      }
    } catch (e) {
      _showErrorSnackBar('Error processing payment: ${e.toString()}');
    }
  }

  Widget _buildLoanHistory() {
    // Cache the future to prevent unnecessary rebuilds - only refresh when loan is applied or payment is made
    _cachedStudentLoansFuture ??= _loadStudentLoans();

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _cachedStudentLoansFuture,
      key: const ValueKey('loan_history'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: evsuRed),
            ),
          );
        }

        final entries = snapshot.data ?? [];
        final recentEntries = entries.take(5).toList();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Loan History',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _showAllLoans(),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: evsuRed,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Text(
                'Shows active loans, approvals, and payment activity.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              if (recentEntries.isEmpty)
                const Text(
                  'No loan activity yet',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                )
              else
                ...recentEntries.map((entry) {
                  final entryType = entry['entry_type'] as String? ?? 'loan';
                  if (entryType == 'payment') {
                    return _buildLoanPaymentItem(entry);
                  }
                  final loanData =
                      entry['loan'] as Map<String, dynamic>? ?? entry;
                  return _buildLoanItem(loanData);
                }).toList(),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadStudentLoans() async {
    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserStudentId;

      if (studentId.isEmpty) return [];

      final loanPaymentsFuture = SupabaseService.client
          .from('loan_payments')
          .select(
            'id, loan_id, payment_amount, remaining_balance, payment_type, created_at',
          )
          .eq('student_id', studentId)
          .order('created_at', ascending: false);

      final response = await SupabaseService.client.rpc(
        'get_student_loans',
        params: {'p_student_id': studentId},
      );

      final List<dynamic>? loanPaymentsRaw =
          await loanPaymentsFuture as List<dynamic>?;

      final data = response as Map<String, dynamic>? ?? {};
      final rawLoans = data['loans'] as List<dynamic>? ?? [];
      final List<Map<String, dynamic>> loans =
          rawLoans.map((loan) => Map<String, dynamic>.from(loan)).toList();

      final Map<int, Map<String, dynamic>> loanLookup = {};
      final List<Map<String, dynamic>> activityEntries = [];

      for (final loan in loans) {
        final loanIdRaw = loan['id'];
        int? loanId;
        if (loanIdRaw is int) {
          loanId = loanIdRaw;
        } else if (loanIdRaw != null) {
          loanId = int.tryParse(loanIdRaw.toString());
        }
        if (loanId != null) {
          loanLookup[loanId] = loan;
        }

        final status = loan['status']?.toString() ?? '';
        final DateTime timestamp =
            status == 'paid' && loan['paid_at'] != null
                ? _parseDateTime(loan['paid_at'])
                : _parseDateTime(loan['created_at']);

        activityEntries.add({
          'entry_type': 'loan',
          'timestamp': timestamp,
          'loan': loan,
        });
      }

      final List<dynamic> loanPaymentsList = loanPaymentsRaw ?? const [];
      for (final paymentRaw in loanPaymentsList) {
        if (paymentRaw is! Map) continue;
        final payment = Map<String, dynamic>.from(paymentRaw);
        final loanIdRaw = payment['loan_id'];
        int? loanId;
        if (loanIdRaw is int) {
          loanId = loanIdRaw;
        } else if (loanIdRaw != null) {
          loanId = int.tryParse(loanIdRaw.toString());
        }

        activityEntries.add({
          'entry_type': 'payment',
          'timestamp': _parseDateTime(payment['created_at']),
          'payment': payment,
          'linked_loan': loanId != null ? loanLookup[loanId] : null,
        });
      }

      activityEntries.sort((a, b) {
        final aTime =
            a['timestamp'] as DateTime? ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            b['timestamp'] as DateTime? ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return activityEntries;
    } catch (e) {
      print('Error loading student loans: $e');
      return [];
    }
  }

  Widget _buildTransactionItem(Map<String, String> transaction, {Key? key}) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors:
                    transaction['type'] == 'income'
                        ? [Colors.green, Colors.green[700]!]
                        : [Colors.red, Colors.red[700]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                transaction['icon']!,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['title']!,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction['time']!,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            transaction['amount']!,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  transaction['type'] == 'income' ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoanItem(Map<String, dynamic> loan) {
    final status = loan['status'] as String;
    final amount = (loan['total_amount'] as num).toDouble();
    final dueDate =
        DateTime.tryParse(loan['due_date']?.toString() ?? '') ?? DateTime.now();
    final daysLeft = loan['days_left'] as int;
    final isOverdue = daysLeft < 0;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case 'paid':
        statusText = 'Paid';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'overdue':
        statusText = 'Overdue';
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        break;
      case 'active':
      default:
        statusText = isOverdue ? 'Overdue' : 'Active';
        statusColor = isOverdue ? Colors.red : Colors.orange;
        statusIcon = isOverdue ? Icons.warning : Icons.schedule;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor, statusColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(statusIcon, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loan['loan_plan_name'] ?? 'Loan',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status == 'paid'
                      ? 'Paid on ${_formatDate(DateTime.tryParse(loan['paid_at']?.toString() ?? '') ?? DateTime.now())}'
                      : 'Due: ${_formatDate(dueDate)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                if (status == 'active' && !isOverdue)
                  Text(
                    '$daysLeft days left',
                    style: TextStyle(fontSize: 10, color: Colors.orange[600]),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 10,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoanPaymentItem(Map<String, dynamic> entry) {
    final payment =
        (entry['payment'] as Map<String, dynamic>?) ??
        const <String, dynamic>{};
    final linkedLoan = entry['linked_loan'] as Map<String, dynamic>?;
    final DateTime? timestamp = entry['timestamp'] as DateTime?;
    final amountPaid = (payment['payment_amount'] as num?)?.toDouble() ?? 0.0;
    final remainingBalance =
        (payment['remaining_balance'] as num?)?.toDouble() ?? 0.0;
    final rawType =
        payment['payment_type']?.toString().toLowerCase() ?? 'partial';
    final paymentTypeLabel =
        rawType == 'full' ? 'Full payment' : 'Partial payment';
    final planName =
        linkedLoan?['loan_plan_name']?.toString() ??
        'Loan #${payment['loan_id'] ?? '-'}';
    final subtitle =
        timestamp != null
            ? '$paymentTypeLabel • ${_formatDate(timestamp)}'
            : paymentTypeLabel;
    final isCleared = remainingBalance <= 0.0;
    final Color primaryColor = isCleared ? Colors.green : Colors.blue;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.payments, color: Colors.white, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment • $planName',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                Text(
                  isCleared
                      ? 'Loan cleared'
                      : 'Remaining ₱${remainingBalance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isCleared ? Colors.green : Colors.orange[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₱${amountPaid.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  DateTime _parseDateTime(dynamic value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _calculateDaysLeft(dynamic dueDate) {
    if (dueDate == null) return 0;

    final due = DateTime.tryParse(dueDate.toString());
    if (due == null) return 0;

    final now = DateTime.now();
    if (due.isBefore(now)) {
      // Overdue - return negative days
      return -now.difference(due).inDays;
    } else {
      // Not due yet - return positive days
      return due.difference(now).inDays;
    }
  }

  // Dialog methods
  void _showTransferDialog() {
    showDialog(
      context: context,
      builder: (context) => _TransferStudentIdDialog(),
    );
  }

  Future<void> _navigateToWithdraw() async {
    // Check if within office hours
    if (!_isWithinOfficeHours()) {
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      final currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.access_time, color: evsuRed, size: 28),
                  SizedBox(width: 8),
                  Expanded(child: Text('Service Unavailable')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Withdrawal service is only available during office hours:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: evsuRed, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '8:00 AM - 5:00 PM',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: evsuRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Monday to Friday',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Current time: $currentTime (Philippine Time)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please try again during office hours. Thank you!',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: evsuRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const WithdrawScreen()),
    );

    // If withdrawal was successful, refresh the UI
    if (result == true && mounted) {
      setState(() {
        // This will refresh the balance display
      });
    }
  }

  /// Check if current time is within office hours (8am-5pm Philippine time)
  bool _isWithinOfficeHours() {
    // Get current time in Philippine timezone (UTC+8)
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final hour = now.hour;

    // Office hours: 8am (8) to 5pm (17)
    return hour >= 1 && hour < 17;
  }

  /// Shows E-wallet QR-based top-up dialog with amounts from database
  void _showTopUpDialog() async {
    print("DEBUG: _showTopUpDialog called");

    // Check if within office hours
    if (!_isWithinOfficeHours()) {
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      final currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.access_time, color: evsuRed, size: 28),
                  SizedBox(width: 8),
                  Expanded(child: Text('Service Unavailable')),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Top-up service is only available during office hours:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.schedule, color: evsuRed, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        '8:00 AM - 5:00 PM',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: evsuRed,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Monday to Friday',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Current time: $currentTime (Philippine Time)',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Please try again during office hours. Thank you!',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: evsuRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );
      return;
    }

    // Load top-up options from database
    try {
      print("DEBUG: Fetching top-up options from database...");
      print(
        "DEBUG: Using client: ${SupabaseService.client.auth.currentUser?.id}",
      );

      final response = await SupabaseService.client
          .from('top_up_qr')
          .select('*')
          .eq('is_active', true)
          .order('amount', ascending: true);

      print("DEBUG: Response received");
      print("DEBUG: Response type: ${response.runtimeType}");
      print("DEBUG: Response data: $response");

      final topUpOptions = List<Map<String, dynamic>>.from(response);
      print("DEBUG: Parsed ${topUpOptions.length} top-up options");

      if (topUpOptions.isNotEmpty) {
        print("DEBUG: Top-up options found:");
        for (var option in topUpOptions) {
          print(
            "  - Amount: ${option['amount']}, Active: ${option['is_active']}, QR URL: ${option['qr_image_url']}",
          );
        }
      } else {
        print("DEBUG: No top-up options found in database");
      }

      if (topUpOptions.isEmpty) {
        // No options available
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.info_outline, color: evsuRed, size: 28),
                    SizedBox(width: 8),
                    Expanded(child: Text('No Options Available')),
                  ],
                ),
                content: const Text(
                  'There are currently no top-up options available. Please try again later or contact admin.',
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                    child: const Text(
                      'OK',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
        );
        return;
      }

      // Show selection dialog
      Map<String, dynamic>? selectedOption = topUpOptions.first;

      showDialog(
        context: context,
        builder:
            (context) => StatefulBuilder(
              builder:
                  (context, setState) => AlertDialog(
                    insetPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 24,
                    ),
                    scrollable: true,
                    title: const Text('Top Up via E-wallet'),
                    content: Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Select amount to top up:'),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children:
                                  topUpOptions.map((option) {
                                    final isSelected =
                                        selectedOption?['id'] == option['id'];
                                    final amount =
                                        (option['amount'] as num).toDouble();
                                    final description =
                                        option['description']?.toString() ?? '';

                                    return ChoiceChip(
                                      label: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('₱${amount.toStringAsFixed(0)}'),
                                          if (description.isNotEmpty)
                                            Text(
                                              description,
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                        ],
                                      ),
                                      selected: isSelected,
                                      onSelected:
                                          (_) => setState(
                                            () => selectedOption = option,
                                          ),
                                      selectedColor: evsuRed.withOpacity(0.2),
                                      labelStyle: TextStyle(
                                        color:
                                            isSelected
                                                ? evsuRed
                                                : Colors.black87,
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                      ),
                                    );
                                  }).toList(),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'You will be shown a QR code to scan with your e-wallet app (GCash, Maya, etc.).',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          if (selectedOption == null) return;
                          Navigator.pop(context);
                          _showGCashQRDialog(selectedOption!);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: evsuRed,
                        ),
                        child: const Text(
                          'Proceed to Payment',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
            ),
      );
    } catch (e, stackTrace) {
      print('DEBUG: ❌ ERROR loading top-up options');
      print('DEBUG: Error type: ${e.runtimeType}');
      print('DEBUG: Error message: $e');
      print('DEBUG: Stack trace: $stackTrace');

      // Check if it's a permission error
      if (e.toString().contains('permission') ||
          e.toString().contains('policy')) {
        print('DEBUG: ⚠️ PERMISSION/POLICY ERROR DETECTED');
        print(
          'DEBUG: This likely means the RLS policy is not set up correctly',
        );
        print('DEBUG: User needs SELECT permission on top_up_qr table');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading top-up options: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  /// Displays E-wallet QR code and handles proof of payment submission
  void _showGCashQRDialog(Map<String, dynamic> topUpOption) {
    File? proofOfPayment;
    bool isSubmitting = false;

    // Get details from the option
    final amount = (topUpOption['amount'] as num).toDouble();
    final qrImageUrl = topUpOption['qr_image_url']?.toString() ?? '';

    print("DEBUG: _showGCashQRDialog called");
    print("DEBUG: Amount: $amount");
    print("DEBUG: QR Image URL: $qrImageUrl");
    print("DEBUG: Full option data: $topUpOption");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  insetPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  scrollable: true,
                  title: Row(
                    children: [
                      Icon(Icons.qr_code_2, color: evsuRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pay ₱${amount.toStringAsFixed(0)} via E-wallet',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ],
                  ),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Scan this QR code using your e-wallet app:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '(GCash, Maya, etc.)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Display E-wallet QR Code from database
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.2),
                                spreadRadius: 2,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child:
                              qrImageUrl.isNotEmpty
                                  ? Image.network(
                                    qrImageUrl,
                                    width: 250,
                                    height: 250,
                                    fit: BoxFit.contain,
                                    loadingBuilder: (
                                      context,
                                      child,
                                      loadingProgress,
                                    ) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 250,
                                        height: 250,
                                        alignment: Alignment.center,
                                        child: CircularProgressIndicator(
                                          value:
                                              loadingProgress
                                                          .expectedTotalBytes !=
                                                      null
                                                  ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                  : null,
                                          color: evsuRed,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      print("DEBUG: ❌ Failed to load QR image");
                                      print("DEBUG: Error: $error");
                                      print("DEBUG: Stack trace: $stackTrace");
                                      return Container(
                                        width: 250,
                                        height: 250,
                                        alignment: Alignment.center,
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.error_outline,
                                              size: 48,
                                              color: Colors.red,
                                            ),
                                            const SizedBox(height: 8),
                                            const Text(
                                              'Failed to load QR code',
                                              style: TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              error.toString(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  )
                                  : Container(
                                    width: 250,
                                    height: 250,
                                    alignment: Alignment.center,
                                    child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.error_outline,
                                          size: 48,
                                          color: Colors.orange,
                                        ),
                                        SizedBox(height: 8),
                                        Text(
                                          'QR code not available',
                                          style: TextStyle(
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Text(
                          'After payment, upload your GCash receipt:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Upload Proof Button
                        OutlinedButton.icon(
                          onPressed:
                              isSubmitting
                                  ? null
                                  : () async {
                                    final ImagePicker picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(
                                      source: ImageSource.gallery,
                                    );
                                    if (image != null) {
                                      setState(() {
                                        proofOfPayment = File(image.path);
                                      });
                                    }
                                  },
                          icon: Icon(
                            proofOfPayment != null
                                ? Icons.check_circle
                                : Icons.upload_file,
                            color: proofOfPayment != null ? Colors.green : null,
                          ),
                          label: Text(
                            proofOfPayment != null
                                ? 'Receipt Uploaded ✓'
                                : 'Upload Receipt Screenshot',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: BorderSide(
                              color:
                                  proofOfPayment != null
                                      ? Colors.green
                                      : evsuRed,
                              width: 2,
                            ),
                          ),
                        ),
                        if (proofOfPayment != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'File: ${proofOfPayment!.path.split('/').last}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.green,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.amber,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Your request will be verified by admin before credits are added.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          isSubmitting
                              ? null
                              : () async {
                                // Validate that screenshot is provided
                                if (proofOfPayment == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please upload your GCash receipt screenshot',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                setState(() => isSubmitting = true);

                                try {
                                  await _submitTopUpRequest(
                                    amount: amount,
                                    proofFile: proofOfPayment!,
                                  );

                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Top-up request submitted! Awaiting verification.',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to submit: ${e.toString()}',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => isSubmitting = false);
                                  }
                                }
                              },
                      child:
                          isSubmitting
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Text("I've Paid - Submit"),
                    ),
                  ],
                ),
          ),
    );
  }

  /// Submits top-up request to Supabase
  Future<void> _submitTopUpRequest({
    required double amount,
    required File proofFile,
  }) async {
    final studentId = SessionService.currentUserStudentId;

    print('DEBUG: Submitting top-up request for ₱${amount.toStringAsFixed(2)}');

    // Upload screenshot
    final screenshotUrl = await _uploadProofToSupabase(proofFile, studentId);

    if (screenshotUrl == null || screenshotUrl.isEmpty) {
      throw Exception(
        'Failed to upload receipt screenshot. Please check your internet connection and try again.',
      );
    }

    print('DEBUG: Screenshot uploaded successfully: $screenshotUrl');

    // Insert into top_up_requests table
    try {
      // Some schemas use integer for amount; ensure we send an int if required
      final dynamic normalizedAmount =
          amount % 1 == 0 ? amount.toInt() : amount;

      await SupabaseService.client.from('top_up_requests').insert({
        'user_id': studentId,
        'amount': normalizedAmount,
        'screenshot_url': screenshotUrl,
        'status': 'Pending Verification',
        'created_at': _getPhilippinesTimeISO(),
      });

      print(
        'DEBUG: Top-up request submitted successfully for ₱${amount.toStringAsFixed(2)} by user $studentId',
      );
    } catch (e) {
      print('ERROR: Failed to insert into top_up_requests table: $e');
      throw Exception('Failed to save request. Please try again.');
    }
  }

  /// Uploads proof of payment image to Supabase Storage with retry logic
  Future<String?> _uploadProofToSupabase(File file, String studentId) async {
    const maxRetries = 3;
    const bucketName =
        'Proof Payment'; // Match your Supabase bucket name EXACTLY

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print(
          'DEBUG: Upload attempt $attempt of $maxRetries for user: $studentId',
        );
        print('DEBUG: File path: ${file.path}');

        // Check if file exists
        if (!await file.exists()) {
          print('ERROR: File does not exist at path: ${file.path}');
          return null;
        }

        final fileName =
            'topup_${studentId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        print('DEBUG: Generated filename: $fileName');

        final bytes = await file.readAsBytes();
        print('DEBUG: Read ${bytes.length} bytes from file');
        print('DEBUG: Uploading to bucket: "$bucketName"');

        try {
          final uploadResponse = await SupabaseService.client.storage
              .from(bucketName)
              .uploadBinary(fileName, bytes);

          print('DEBUG: Upload successful! Response: $uploadResponse');

          // Get public URL
          final publicUrl = SupabaseService.client.storage
              .from(bucketName)
              .getPublicUrl(fileName);

          print('DEBUG: Generated public URL: $publicUrl');

          if (publicUrl.isEmpty) {
            print('ERROR: Public URL is empty');
            return null;
          }

          return publicUrl; // Success! Return the URL
        } catch (uploadError) {
          print('ERROR: Upload failed on attempt $attempt: $uploadError');

          // Check for specific errors
          if (uploadError.toString().contains('403') ||
              uploadError.toString().contains('Unauthorized') ||
              uploadError.toString().contains('row-level security')) {
            print('ERROR: Permission denied - RLS policy issue');
            print('ERROR: Run FIX_STORAGE_POLICY_NOW.sql in Supabase');
            print('ERROR: Or make bucket "Proof Payment" public');
            return null; // Don't retry on permission errors
          }

          if (uploadError.toString().contains('404') ||
              uploadError.toString().contains('Not found')) {
            print('ERROR: Bucket "$bucketName" not found');
            return null; // Don't retry if bucket doesn't exist
          }

          // For other errors (network, timeout, etc.), retry
          if (attempt < maxRetries) {
            print('DEBUG: Retrying in ${attempt * 2} seconds...');
            await Future.delayed(Duration(seconds: attempt * 2));
            continue; // Retry
          } else {
            print('ERROR: All $maxRetries upload attempts failed');
            return null;
          }
        }
      } catch (e, stackTrace) {
        print('ERROR: Unexpected error on attempt $attempt: $e');
        print('ERROR: Stack trace: $stackTrace');

        if (attempt < maxRetries) {
          print('DEBUG: Retrying in ${attempt * 2} seconds...');
          await Future.delayed(Duration(seconds: attempt * 2));
          continue; // Retry
        } else {
          print('ERROR: All $maxRetries attempts failed');
          return null;
        }
      }
    }

    return null; // All retries exhausted
  }

  // ============================================================================
  // DEPRECATED PAYTACA FUNCTIONS (Replaced with GCash QR Payment)
  // ============================================================================
  // The following functions are commented out as they are no longer used.
  // They have been replaced with the GCash QR payment flow.
  // ============================================================================

  /*
  /// Fetches API configuration from the api_configuration table
  Future<Map<String, dynamic>?> _fetchApiConfiguration() async {
    try {
      await SupabaseService.initialize();
      final response =
          await SupabaseService.client
              .from('api_configuration')
              .select('enabled, xpub_key, wallet_hash')
              .limit(1)
              .maybeSingle();

      if (response != null &&
          response['enabled'] != null &&
          response['xpub_key'] != null &&
          response['wallet_hash'] != null) {
        return {
          'enabled': response['enabled'] as bool,
          'xpub_key': response['xpub_key'].toString(),
          'wallet_hash': response['wallet_hash'].toString(),
        };
      }

      print('WARNING: API configuration not found in database');
      return null;
    } catch (e) {
      print('ERROR: Failed to fetch API configuration: $e');
      return null;
    }
  }

  Future<void> _startPaytacaInvoiceXpub({required num amountPhp}) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final studentId = SessionService.currentUserStudentId;

      // First, insert a record into paytaca_invoices table
      final providerTxId =
          await PaytacaInvoiceService.insertPaytacaInvoiceRecord(
            studentId: studentId,
            amount: amountPhp,
            currency: 'PHP',
          );

      if (providerTxId == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Failed to create invoice record.')),
        );
        return;
      }

      // Fetch API configuration from database
      final apiConfig = await _fetchApiConfiguration();
      if (apiConfig == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to load API configuration. Please try again.',
            ),
          ),
        );
        return;
      }

      // Check if Paytaca is enabled
      final isEnabled = apiConfig['enabled'] as bool;
      if (!isEnabled) {
        _showMaintenanceModal();
        return;
      }

      final xpubKey = apiConfig['xpub_key'] as String;
      final walletHash = apiConfig['wallet_hash'] as String;
      const index = 0; // adjust if you need unique address per invoice

      final invoice = await PaytacaInvoiceService.createInvoiceWithXpub(
        amount: amountPhp,
        xpubKey: xpubKey,
        index: index,
        walletHash: walletHash,
        providerTxId: providerTxId,
        currency: 'PHP',
        memo: 'Wallet top-up',
      );

      if (invoice == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Failed to create Paytaca invoice.')),
        );
        return;
      }

      final url = PaytacaInvoiceService.extractPaymentUrl(invoice);
      if (url == null || url.isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('No Paytaca payment URL found.')),
        );
        return;
      }

      // Extract invoice ID from the response (adjust based on actual Paytaca response structure)
      final invoiceId =
          invoice['id']?.toString() ??
          invoice['invoice_id']?.toString() ??
          providerTxId;

      // Update the paytaca_invoices record with invoice details
      await PaytacaInvoiceService.updatePaytacaInvoiceRecord(
        providerTxId: providerTxId,
        invoiceId: invoiceId,
      );

      // Launch the payment URL
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Paytaca request failed: ' + e.toString())),
      );
    }
  }
  */

  void _showMaintenanceModal() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.build_circle, color: Colors.orange, size: 28),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    'Under Maintenance',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top-up service is currently unavailable.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.start,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Our payment system is temporarily under maintenance. Please try again later or contact support for assistance.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.start,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'We apologize for any inconvenience caused.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.start,
                  ),
                ],
              ),
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _showAvailableLoans() async {
    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserStudentId;

      if (studentId.isEmpty) {
        _showErrorSnackBar('Student ID not found. Please log in again.');
        return;
      }

      // Get available loan plans for student (server-calculated)
      final response = await SupabaseService.client.rpc(
        'get_available_loan_plans',
        params: {'p_student_id': studentId},
      );

      if (response == null) {
        _showErrorSnackBar('Failed to load loan plans');
        return;
      }

      final data = response as Map<String, dynamic>;
      final availablePlans = data['available_plans'] as List<dynamic>;
      final totalTopup = data['total_topup'] as num;

      // Recompute clean total top-up EXCLUDING any loan disbursements
      double cleanTotalTopup = 0.0;
      try {
        final topups = await SupabaseService.client
            .from('top_up_transactions')
            .select('amount, transaction_type, student_id')
            .eq('student_id', studentId);

        for (final row in (topups as List)) {
          final String? txType = row['transaction_type'] as String?;
          // Include only real top-ups (top_up and top_up_gcash); exclude explicit loan disbursements
          if (txType == null ||
              txType == 'top_up' ||
              txType == 'top_up_gcash') {
            cleanTotalTopup += ((row['amount'] as num?)?.toDouble() ?? 0.0);
          }
        }
      } catch (e) {
        // Fallback to server-provided total if schema/column differs
        cleanTotalTopup = totalTopup.toDouble();
      }

      // Adjust eligibility client-side to prevent loan disbursement inflating eligibility
      final List<Map<String, dynamic>> adjustedPlans =
          availablePlans.map((p) {
            final plan = Map<String, dynamic>.from(p as Map);
            final double minTopup = (plan['min_topup'] as num).toDouble();
            final bool serverEligible = (plan['is_eligible'] as bool? ?? false);
            final bool eligibleByCleanTopup = cleanTotalTopup >= minTopup;
            plan['is_eligible'] = serverEligible && eligibleByCleanTopup;
            return plan;
          }).toList();

      if (availablePlans.isEmpty) {
        _showErrorSnackBar('No loan plans available at the moment');
        return;
      }

      showDialog(
        context: context,
        builder:
            (context) => _LoanPlansDialog(
              plans: adjustedPlans,
              totalTopup: cleanTotalTopup,
              onApplyLoan: _applyForLoan,
              onLoanSubmitted: () {
                // Refresh active loans when loan is successfully submitted
                setState(() {
                  _cachedActiveLoanFuture = null;
                });
              },
            ),
      );
    } catch (e) {
      final userFriendlyError = _getUserFriendlyError(e);
      _showErrorSnackBar('Error loading loan plans: $userFriendlyError');
    }
  }

  Future<void> _applyForLoan(int planId) async {
    try {
      final studentId = SessionService.currentUserStudentId;

      final response = await SupabaseService.client.rpc(
        'apply_for_loan',
        params: {'p_student_id': studentId, 'p_loan_plan_id': planId},
      );

      if (response == null) {
        _showErrorSnackBar('Failed to apply for loan');
        return;
      }

      final data = response as Map<String, dynamic>;

      if (data['success'] == true) {
        Navigator.pop(context); // Close dialog
        _showSuccessSnackBar(data['message'] ?? 'Loan applied successfully!');

        // Refresh user data to update balance
        await SessionService.refreshUserData();
        // Reset cached futures to force refresh of both active loan display and loan history
        _cachedActiveLoanFuture = null;
        _cachedStudentLoansFuture = null;
        setState(() {}); // Refresh UI
      } else {
        _showErrorSnackBar(data['message'] ?? 'Failed to apply for loan');
      }
    } catch (e) {
      final userFriendlyError = _getUserFriendlyError(e);
      _showErrorSnackBar('Error applying for loan: $userFriendlyError');
    }
  }

  /// Get user-friendly error message without exposing technical details
  String _getUserFriendlyError(dynamic error) {
    // Check for socket/connection errors
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Check for Supabase client exceptions
    if (error is PostgrestException) {
      // Check if it's a connection error
      final errorString = error.message.toLowerCase();
      if (errorString.contains('connection') ||
          errorString.contains('network') ||
          errorString.contains('timeout') ||
          errorString.contains('socket')) {
        return 'No internet connection. Please check your network and try again.';
      }
      return 'Failed to load data. Please try again later.';
    }

    // Check for other connection-related errors (including string messages)
    final errorString = error.toString().toLowerCase();

    // Check for network-related error messages (including common variations)
    if (errorString.contains('socket') ||
        errorString.contains('socketexception') ||
        errorString.contains('socket exception') ||
        errorString.contains('client exception') ||
        errorString.contains('clientexception') ||
        errorString.contains('client_exception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('connection') ||
        errorString.contains('network') ||
        errorString.contains('timeout') ||
        errorString.contains('no address associated') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection reset')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Remove Supabase URLs from error message
    if (errorString.contains('supabase') ||
        errorString.contains('http://') ||
        errorString.contains('https://')) {
      return 'Unable to connect to server. Please check your internet connection and try again.';
    }

    // Generic error message for other errors
    return 'Failed to load data. Please try again later.';
  }

  void _showErrorSnackBar(String message) {
    // Check if it's a network-related error
    final messageLower = message.toLowerCase();
    if (messageLower.contains('network') ||
        messageLower.contains('connection') ||
        messageLower.contains('internet') ||
        messageLower.contains('timeout') ||
        messageLower.contains('unreachable') ||
        messageLower.contains('socket') ||
        messageLower.contains('failed host lookup') ||
        messageLower.contains('connection refused') ||
        messageLower.contains('connection reset')) {
      // Show responsive modal for network errors
      _showNetworkErrorModal(message);
    } else {
      // Show snackbar for other errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showNetworkErrorModal(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (context) =>
              _buildResponsiveNetworkErrorModal(context, message: message),
    );
  }

  Widget _buildResponsiveNetworkErrorModal(
    BuildContext context, {
    required String message,
  }) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    // Responsive calculations
    final isSmallScreen = screenWidth < 400;
    final isVerySmallScreen = screenWidth < 350;
    final isLandscape = screenHeight < screenWidth;

    // Dynamic sizing based on screen size
    final modalMaxWidth =
        isSmallScreen ? screenWidth * 0.95 : screenWidth * 0.85;
    final modalMaxHeight =
        isLandscape ? screenHeight * 0.8 : screenHeight * 0.6;
    final iconSize =
        isVerySmallScreen
            ? 20.0
            : isSmallScreen
            ? 24.0
            : 28.0;
    final titleFontSize =
        isVerySmallScreen
            ? 16.0
            : isSmallScreen
            ? 18.0
            : 20.0;
    final messageFontSize =
        isVerySmallScreen
            ? 12.0
            : isSmallScreen
            ? 13.0
            : 14.0;
    final buttonFontSize = isVerySmallScreen ? 14.0 : 16.0;
    final horizontalPadding = isSmallScreen ? 16.0 : 24.0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: modalMaxWidth,
          maxHeight: modalMaxHeight,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with background circle
              Container(
                width: isSmallScreen ? 60 : 70,
                height: isSmallScreen ? 60 : 70,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off,
                  color: Colors.orange,
                  size: iconSize,
                ),
              ),

              SizedBox(height: isSmallScreen ? 16 : 20),

              // Title
              Text(
                'No Internet Connection',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: isSmallScreen ? 12 : 16),

              // Message Content
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: messageFontSize,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              SizedBox(height: isSmallScreen ? 20 : 24),

              // Action Buttons
              Row(
                children: [
                  // Retry button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Retry the operation (refresh the current page)
                        setState(() {});
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange,
                        side: BorderSide(color: Colors.orange),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 14,
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
                  SizedBox(width: isSmallScreen ? 12 : 16),

                  // OK button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 14,
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
    );
  }

  void _showAllTransactions() {
    // Navigate to transactions tab
    widget.onNavigateToTransactions?.call();
  }

  void _showAllLoans() {
    // Use cached future - only refreshes when loan is applied
    _cachedStudentLoansFuture ??= _loadStudentLoans();

    showDialog(
      context: context,
      builder:
          (context) => FutureBuilder<List<Map<String, dynamic>>>(
            future: _cachedStudentLoansFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return AlertDialog(
                  title: const Text('Loan History'),
                  content: const SizedBox(
                    height: 100,
                    child: Center(
                      child: CircularProgressIndicator(color: evsuRed),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                );
              }

              final entries = snapshot.data ?? [];

              if (entries.isEmpty) {
                return AlertDialog(
                  title: const Text('Loan History'),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No loan history found',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your loan activity will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                );
              }

              return AlertDialog(
                title: const Text('Complete Loan History'),
                content: SizedBox(
                  width: double.maxFinite,
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final entryType =
                          entry['entry_type'] as String? ?? 'loan';
                      if (entryType == 'payment') {
                        return _buildLoanPaymentItem(entry);
                      }
                      final loanData =
                          entry['loan'] as Map<String, dynamic>? ?? entry;
                      return _buildLoanItem(loanData);
                    },
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              );
            },
          ),
    );
  }
}

class _InboxTab extends StatefulWidget {
  const _InboxTab();

  @override
  State<_InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<_InboxTab> {
  static const Color evsuRed = Color(0xFFB91C1C);

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  StreamSubscription<List<Map<String, dynamic>>>? _inboxSub;
  StreamSubscription<List<Map<String, dynamic>>>? _readStatusSub;
  bool _isMarkAllBusy = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _subscribeToInboxUpdates();
  }

  @override
  void dispose() {
    _inboxSub?.cancel();
    _readStatusSub?.cancel();
    super.dispose();
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkAllBusy) return;
    setState(() {
      _isMarkAllBusy = true;
    });
    try {
      final studentId = SessionService.currentUserStudentId;
      if (studentId.isEmpty) return;
      final ok = await InboxService.markAllAsRead(studentId);
      if (ok) {
        await _loadNotifications();
      }
    } catch (e) {
      print('ERROR: Failed to mark all as read: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isMarkAllBusy = false;
        });
      }
    }
  }

  Future<void> _loadNotifications() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final studentId = SessionService.currentUserStudentId;

      if (studentId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _notifications = [];
          _isLoading = false;
        });
        return;
      }

      // Fetch inbox messages using InboxService (includes read/unread status)
      final messages = await InboxService.fetchInboxMessages(studentId);

      if (!mounted) return;

      setState(() {
        _notifications = messages;
        _isLoading = false;
      });
    } catch (e) {
      print('ERROR: Failed to load inbox messages: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _subscribeToInboxUpdates() async {
    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserStudentId;

      if (studentId.isEmpty) {
        return;
      }

      await _inboxSub?.cancel();
      await _readStatusSub?.cancel();

      _inboxSub = InboxService.subscribeToInbox(studentId).listen(
        (_) => _loadNotifications(),
        onError: (error) {
          print('ERROR: Inbox stream error: $error');
        },
      );

      _readStatusSub = InboxService.subscribeToReadState(studentId).listen(
        (_) => _loadNotifications(),
        onError: (error) {
          print('ERROR: Read status stream error: $error');
        },
      );
    } catch (e) {
      print('ERROR: Failed to subscribe to inbox updates: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredNotifications() {
    List<Map<String, dynamic>> filtered;

    if (_selectedFilter == 'All') {
      filtered = _notifications;
    } else if (_selectedFilter == 'Transfers') {
      filtered =
          _notifications.where((n) {
            final type = n['type']?.toString() ?? '';
            return type == 'transfer_sent' || type == 'transfer_received';
          }).toList();
    } else if (_selectedFilter == 'Top-ups') {
      filtered =
          _notifications.where((n) {
            final type = n['type']?.toString() ?? '';
            return type == 'top_up';
          }).toList();
    } else if (_selectedFilter == 'Transactions') {
      filtered =
          _notifications.where((n) {
            final type = n['type']?.toString() ?? '';
            // Keep payments and related service transactions here
            return type == 'service_payment' ||
                type == 'withdrawal' ||
                type == 'withdrawal_request';
          }).toList();
    } else {
      filtered = _notifications;
    }

    return filtered;
  }

  String _getTimeAgo(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  Color _getNotificationColor(Map<String, dynamic> notification) {
    if (notification['is_urgent'] == true) {
      return Colors.red;
    }

    // Get color based on notification type
    final type = notification['type']?.toString() ?? '';
    switch (type) {
      case 'transaction_success':
      case 'topup_success':
      case 'top_up':
        return Colors.green;
      case 'transfer_sent':
      case 'transfer_received':
        return Colors.blue;
      case 'withdrawal':
        return Colors.red[700]!;
      case 'withdrawal_request':
        // Color based on status
        final status = notification['status']?.toString() ?? '';
        return status == 'Approved' ? Colors.green : Colors.red;
      case 'loan_disbursement':
        return Colors.purple;
      case 'active_loan':
        return Colors.orange;
      case 'loan_payment':
        return Colors.blue;
      case 'loan_due_soon':
      case 'loan_reminder':
        return Colors.orange;
      case 'loan_overdue':
        return Colors.red;
      case 'security_alert':
        return Colors.red;
      case 'system_notification':
        return Colors.grey;
      case 'welcome':
        return Colors.purple;
      default:
        return evsuRed;
    }
  }

  IconData _getNotificationIcon(Map<String, dynamic> notification) {
    // Get icon based on notification type
    final type = notification['type']?.toString() ?? '';
    switch (type) {
      case 'transaction_success':
      case 'topup_success':
      case 'top_up':
        return Icons.check_circle;
      case 'transfer_sent':
        return Icons.send;
      case 'transfer_received':
        return Icons.call_received;
      case 'withdrawal':
        return Icons.account_balance_wallet;
      case 'withdrawal_request':
        // Icon based on status
        final status = notification['status']?.toString() ?? '';
        return status == 'Approved' ? Icons.check_circle : Icons.cancel;
      case 'loan_disbursement':
        return Icons.account_balance;
      case 'active_loan':
        return Icons.credit_card;
      case 'loan_payment':
        return Icons.payment;
      case 'loan_due_soon':
        return Icons.schedule;
      case 'loan_overdue':
        return Icons.warning;
      case 'loan_reminder':
        return Icons.alarm;
      case 'security_alert':
        return Icons.security;
      case 'system_notification':
        return Icons.info;
      case 'welcome':
        return Icons.celebration;
      default:
        // Fallback based on notification type
        if (type.contains('loan')) {
          return Icons.account_balance;
        } else if (type.contains('payment') || type.contains('transfer')) {
          return Icons.payment;
        } else if (type.contains('security')) {
          return Icons.security;
        }
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredNotifications = _getFilteredNotifications();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Inbox',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: evsuRed,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _isMarkAllBusy ? null : _markAllAsRead,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: evsuRed,
                    side: const BorderSide(color: evsuRed),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon:
                      _isMarkAllBusy
                          ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: evsuRed,
                            ),
                          )
                          : const Icon(
                            Icons.mark_email_read_outlined,
                            size: 18,
                          ),
                  label: Text(
                    _isMarkAllBusy ? 'Marking…' : 'Mark all as read',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Spacer between header and filters

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Transfers'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Top-ups'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Transactions'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Notifications list
            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: evsuRed),
                      )
                      : _notifications.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                        itemCount: filteredNotifications.length,
                        itemBuilder: (context, index) {
                          final notification = filteredNotifications[index];
                          return _buildNotificationCard(notification);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = label;
        });
      },
      selectedColor: evsuRed.withOpacity(0.2),
      checkmarkColor: evsuRed,
      labelStyle: TextStyle(
        color: isSelected ? evsuRed : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isUrgent = notification['is_urgent'] == true;
    final isRead = notification['is_read'] == true;

    // Safely parse created_at date and convert to Philippines time (UTC+8)
    DateTime createdAt;
    try {
      final createdAtString = notification['created_at']?.toString();
      if (createdAtString != null && createdAtString.isNotEmpty) {
        // Parse the timestamp from database (stored as UTC)
        final parsed = DateTime.parse(createdAtString);
        // Convert from UTC to Philippines time (UTC+8)
        // Database stores UTC, so we add 8 hours to get local Philippines time
        createdAt =
            parsed.isUtc ? parsed.add(const Duration(hours: 8)) : parsed;
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      print('ERROR: Failed to parse created_at: $e');
      createdAt = DateTime.now();
    }

    final timeAgo = _getTimeAgo(createdAt);
    final notificationColor = _getNotificationColor(notification);
    final notificationIcon = _getNotificationIcon(notification);
    final transactionId =
        notification['transaction_id'] is int
            ? notification['transaction_id'] as int
            : int.tryParse(
              notification['transaction_id']?.toString() ??
                  notification['id']?.toString() ??
                  '',
            );
    final transactionType =
        notification['transaction_type']?.toString() ??
        ''; // base type used for read tracking

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: isUrgent ? 4 : 1,
      color: isUrgent ? Colors.red.withOpacity(0.05) : null,
      child: InkWell(
        onTap: () async {
          // Mark message as read when clicked
          if (transactionId != null && transactionType.isNotEmpty && !isRead) {
            final studentId = SessionService.currentUserStudentId;
            if (studentId.isNotEmpty) {
              try {
                await InboxService.markMessageAsRead(
                  studentId: studentId,
                  transactionId: transactionId,
                  transactionType: transactionType,
                );
                // Reload notifications to update UI
                if (mounted) {
                  _loadNotifications();
                }
              } catch (e) {
                print('ERROR: Failed to mark message as read: $e');
              }
            }
          }
          if (mounted) {
            _showTransactionDetailModal(notification);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Icon with red dot indicator for unread
              Stack(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: notificationColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      notificationIcon,
                      color: notificationColor,
                      size: 20,
                    ),
                  ),
                  // Red dot for unread messages
                  if (!isRead)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'] ?? 'Notification',
                            style: TextStyle(
                              fontWeight:
                                  isRead ? FontWeight.w500 : FontWeight.w600,
                              fontSize: 14,
                              color:
                                  isUrgent
                                      ? Colors.red
                                      : (isRead ? null : Colors.black87),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification['message'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight:
                            isRead ? FontWeight.normal : FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        if (isUrgent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'URGENT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Inbox',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'re all caught up!',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetailModal(Map<String, dynamic> notification) async {
    // Show loading dialog first
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) =>
              const Center(child: CircularProgressIndicator(color: evsuRed)),
    );

    try {
      // Fetch actual transaction data based on notification type
      final transactionData = await _fetchTransactionData(notification);

      // Close loading dialog
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      // Show transaction details modal - Clean design matching home_tab
      final screenSize = MediaQuery.of(context).size;
      final isSmallScreen = screenSize.width < 600;

      showDialog(
        context: context,
        builder:
            (context) => Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 32,
                vertical: isSmallScreen ? 16 : 32,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: screenSize.width * 0.98,
                  maxHeight: screenSize.height * 0.9,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                        decoration: const BoxDecoration(
                          color: Color(0xFFB91C1C),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              transactionData != null
                                  ? _getTransactionTitle(
                                    transactionData['type'],
                                  )
                                  : (notification['title']?.toString() ??
                                      'Notification Details'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              transactionData != null
                                  ? 'Transaction Details'
                                  : 'Message Details',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Transaction Details or Message Details
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child:
                            transactionData != null
                                ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Transaction ID or Transaction Code (for Campus Service Units)
                                    _buildReceiptRow(
                                      _getTransactionIdentifierLabel(
                                        transactionData,
                                      ),
                                      _getTransactionIdentifier(
                                        transactionData,
                                      ),
                                    ),

                                    // Amount
                                    if (_getTransactionAmountFromData(
                                          transactionData,
                                        ) !=
                                        null)
                                      _buildReceiptRow(
                                        'Amount',
                                        '₱${_getTransactionAmountFromData(transactionData)?.toStringAsFixed(2)}',
                                        isAmount: true,
                                      ),

                                    // Date and Time
                                    _buildReceiptRow(
                                      'Date & Time',
                                      _formatDateTime(
                                        transactionData['data']?['created_at'] ??
                                            notification['created_at'],
                                      ),
                                    ),

                                    // Status - use helper methods that handle withdrawal_request status
                                    _buildReceiptRow(
                                      'Status',
                                      _getTransactionStatusForModal(
                                        transactionData,
                                        notification,
                                      ),
                                      statusColor:
                                          _getTransactionStatusColorForModal(
                                            transactionData,
                                            notification,
                                          ),
                                    ),

                                    // Additional transaction-specific details
                                    ..._buildTransactionSpecificDetails(
                                      transactionData,
                                    ),

                                    const SizedBox(height: 20),

                                    // Close button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFB91C1C,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Close',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                                : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Message ID
                                    _buildReceiptRow(
                                      'Message ID',
                                      '#${notification['id']?.toString().padLeft(8, '0') ?? 'N/A'}',
                                    ),

                                    // Message Type
                                    if (notification['type'] != null)
                                      _buildReceiptRow(
                                        'Type',
                                        notification['type']?.toString() ??
                                            'N/A',
                                      ),

                                    // Date and Time
                                    _buildReceiptRow(
                                      'Date & Time',
                                      _formatDateTime(
                                        notification['created_at'],
                                      ),
                                    ),

                                    // Message Content
                                    const SizedBox(height: 12),
                                    Text(
                                      'Message',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        notification['message']?.toString() ??
                                            'No message',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 20),

                                    // Close button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(
                                            0xFFB91C1C,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'Close',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      );
    } catch (e) {
      print('ERROR: Failed to show transaction detail modal: $e');

      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Error'),
                content: Text('Failed to load details: ${e.toString()}'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    }
  }

  Widget _buildReceiptRow(
    String label,
    String value, {
    bool isHeader = false,
    bool isAmount = false,
    Color? statusColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isHeader ? 16 : 14,
                fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
                color: isHeader ? const Color(0xFFB91C1C) : Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isHeader ? 16 : 14,
                fontWeight:
                    isHeader || isAmount ? FontWeight.bold : FontWeight.normal,
                color:
                    statusColor ??
                    (isAmount ? const Color(0xFFB91C1C) : Colors.black87),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return 'N/A';

    try {
      final dateTime = DateTime.parse(dateTimeString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      // Format time in 12-hour format
      final hour12 =
          dateTime.hour > 12
              ? dateTime.hour - 12
              : (dateTime.hour == 0 ? 12 : dateTime.hour);
      final amPm = dateTime.hour >= 12 ? 'PM' : 'AM';
      final time12Hour =
          '${hour12.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $amPm';

      String timeStr;
      // Only show "Just now" if less than 1 minute
      if (difference.inSeconds < 60) {
        timeStr = 'Just now';
      } else if (difference.inDays > 0) {
        timeStr =
            '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
      } else if (difference.inHours > 0) {
        timeStr =
            '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
      } else if (difference.inMinutes > 0) {
        timeStr =
            '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
      } else {
        timeStr = 'Just now';
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year} at $time12Hour ($timeStr)';
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Helper method to get service category from transaction data
  String? _getServiceCategory(Map<String, dynamic>? data) {
    if (data == null) return null;

    try {
      // Check if service_accounts relation exists
      final serviceAccounts = data['service_accounts'];
      if (serviceAccounts != null) {
        if (serviceAccounts is Map) {
          return serviceAccounts['service_category']?.toString();
        } else if (serviceAccounts is List && serviceAccounts.isNotEmpty) {
          return serviceAccounts[0]['service_category']?.toString();
        }
      }

      // Fallback: check direct service_category field
      return data['service_category']?.toString();
    } catch (e) {
      return null;
    }
  }

  // Helper method to get transaction identifier label
  String _getTransactionIdentifierLabel(Map<String, dynamic>? transactionData) {
    if (transactionData == null) return 'Transaction ID';

    final data = transactionData['data'] as Map<String, dynamic>?;
    if (data == null) return 'Transaction ID';

    final serviceCategory = _getServiceCategory(data);
    if (serviceCategory == 'Campus Service Units') {
      return 'Transaction Code';
    }
    return 'Transaction ID';
  }

  // Helper method to get transaction identifier (code or ID)
  String _getTransactionIdentifier(Map<String, dynamic>? transactionData) {
    if (transactionData == null) {
      return 'N/A';
    }

    final data = transactionData['data'] as Map<String, dynamic>?;
    if (data == null) {
      return '#${transactionData['id']?.toString().padLeft(8, '0') ?? 'N/A'}';
    }

    final serviceCategory = _getServiceCategory(data);

    // For Campus Service Units, use transaction_code if available
    if (serviceCategory == 'Campus Service Units') {
      final transactionCode = data['transaction_code']?.toString();
      if (transactionCode != null && transactionCode.isNotEmpty) {
        return transactionCode;
      }
    }

    // For Vendor/Org or if transaction_code is not available, use transaction ID
    final transactionId =
        transactionData['id']?.toString() ?? data['id']?.toString();
    if (transactionId != null) {
      return '#${transactionId.padLeft(8, '0')}';
    }

    return 'N/A';
  }

  // Helper methods for transaction modal
  IconData _getTransactionIcon(String? transactionType) {
    switch (transactionType?.toLowerCase()) {
      case 'top_up':
        return Icons.add_circle;
      case 'loan_disbursement':
        return Icons.account_balance;
      case 'active_loan':
        return Icons.credit_card;
      case 'loan_payment':
        return Icons.payment;
      case 'service_payment':
        return Icons.receipt;
      case 'transfer':
        return Icons.swap_horiz;
      case 'withdrawal':
        return Icons.account_balance_wallet;
      default:
        return Icons.receipt_long;
    }
  }

  String _getTransactionTitle(String? transactionType) {
    switch (transactionType?.toLowerCase()) {
      case 'top_up':
        return 'Account Top-up Receipt';
      case 'loan_disbursement':
        return 'Loan Disbursement Receipt';
      case 'active_loan':
        return 'Active Loan Details';
      case 'loan_payment':
        return 'Loan Payment Receipt';
      case 'service_payment':
        return 'Service Payment Receipt';
      case 'transfer':
        return 'Transfer Receipt';
      case 'withdrawal':
        return 'Withdrawal Receipt';
      case 'withdrawal_request':
        return 'Withdrawal Request Details';
      default:
        return 'Transaction Receipt';
    }
  }

  String _getTransactionStatus(String? transactionType) {
    switch (transactionType?.toLowerCase()) {
      case 'top_up':
      case 'loan_disbursement':
      case 'loan_payment':
      case 'service_payment':
      case 'transfer':
      case 'transfer_sent':
      case 'transfer_received':
      case 'withdrawal':
        return 'Completed';
      case 'active_loan':
        return 'Active';
      case 'withdrawal_request':
        return 'Pending'; // Default, will be overridden by actual data
      default:
        return 'Processed';
    }
  }

  String _getTransactionStatusForModal(
    Map<String, dynamic>? transactionData,
    Map<String, dynamic> notification,
  ) {
    final transactionType = transactionData?['type']?.toString().toLowerCase();

    // For withdrawal_request, get status from data
    if (transactionType == 'withdrawal_request') {
      final data = transactionData?['data'] as Map<String, dynamic>?;
      final status =
          data?['status']?.toString() ??
          notification['status']?.toString() ??
          'Pending';
      return status;
    }

    return _getTransactionStatus(transactionType);
  }

  Color _getTransactionStatusColor(String? transactionType) {
    switch (transactionType?.toLowerCase()) {
      case 'top_up':
      case 'loan_disbursement':
      case 'loan_payment':
      case 'service_payment':
      case 'transfer':
      case 'transfer_sent':
      case 'transfer_received':
      case 'withdrawal':
        return Colors.green[700]!;
      case 'active_loan':
        return Colors.blue[700]!;
      case 'withdrawal_request':
        return Colors.orange; // Default, will be overridden by actual data
      default:
        return Colors.blue[700]!;
    }
  }

  Color _getTransactionStatusColorForModal(
    Map<String, dynamic>? transactionData,
    Map<String, dynamic> notification,
  ) {
    final transactionType = transactionData?['type']?.toString().toLowerCase();

    // For withdrawal_request, get color based on status
    if (transactionType == 'withdrawal_request') {
      final data = transactionData?['data'] as Map<String, dynamic>?;
      final status =
          data?['status']?.toString() ??
          notification['status']?.toString() ??
          'Pending';
      return status == 'Approved' ? Colors.green : Colors.red;
    }

    return _getTransactionStatusColor(transactionType);
  }

  double? _getTransactionAmountFromData(Map<String, dynamic>? transactionData) {
    if (transactionData == null) return null;

    final data = transactionData['data'] as Map<String, dynamic>?;
    if (data == null) return null;

    final transactionType = transactionData['type'] as String?;

    switch (transactionType?.toLowerCase()) {
      case 'top_up':
      case 'loan_disbursement':
        return _safeParseNumber(data['amount']);
      case 'loan_payment':
        return _safeParseNumber(data['payment_amount']);
      case 'service_payment':
        return _safeParseNumber(data['total_amount']);
      case 'transfer':
        return _safeParseNumber(data['amount']);
      case 'withdrawal':
        return _safeParseNumber(data['amount']);
      case 'withdrawal_request':
        return _safeParseNumber(data['amount']);
      case 'active_loan':
        return _safeParseNumber(data['loan_amount']);
      default:
        return null;
    }
  }

  List<Widget> _buildTransactionSpecificDetails(
    Map<String, dynamic>? transactionData,
  ) {
    if (transactionData == null) return [];

    final data = transactionData['data'] as Map<String, dynamic>?;
    if (data == null) return [];

    final transactionType = transactionData['type'] as String?;
    final List<Widget> details = [];

    switch (transactionType?.toLowerCase()) {
      case 'top_up':
        details.add(
          _buildReceiptRow(
            'Top-up Amount',
            '₱${_safeParseNumber(data['amount']).toStringAsFixed(2)}',
          ),
        );
        details.add(
          _buildReceiptRow(
            'New Balance',
            '₱${_safeParseNumber(data['new_balance']).toStringAsFixed(2)}',
          ),
        );
        if (data['processed_by'] != null) {
          details.add(
            _buildReceiptRow('Processed By', data['processed_by'].toString()),
          );
        }
        break;

      case 'loan_disbursement':
        details.add(
          _buildReceiptRow(
            'New Balance',
            '₱${_safeParseNumber(data['new_balance']).toStringAsFixed(2)}',
          ),
        );
        if (data['processed_by'] != null) {
          details.add(
            _buildReceiptRow('Processed By', data['processed_by'].toString()),
          );
        }
        break;

      case 'active_loan':
        details.add(
          _buildReceiptRow(
            'Loan Amount',
            '₱${_safeParseNumber(data['loan_amount']).toStringAsFixed(2)}',
          ),
        );
        details.add(
          _buildReceiptRow(
            'Remaining Balance',
            '₱${_safeParseNumber(data['remaining_balance']).toStringAsFixed(2)}',
          ),
        );
        if (data['loan_plan_id'] != null) {
          details.add(
            _buildReceiptRow('Loan Plan ID', data['loan_plan_id'].toString()),
          );
        }
        break;

      case 'loan_payment':
        details.add(
          _buildReceiptRow(
            'Payment Amount',
            '₱${_safeParseNumber(data['payment_amount']).toStringAsFixed(2)}',
          ),
        );
        details.add(
          _buildReceiptRow(
            'Remaining Balance',
            '₱${_safeParseNumber(data['remaining_balance']).toStringAsFixed(2)}',
          ),
        );
        if (data['loan_id'] != null) {
          details.add(_buildReceiptRow('Loan ID', data['loan_id'].toString()));
        }
        break;

      case 'service_payment':
        // Check if this is a Campus Service Units payment
        final serviceCategory = _getServiceCategory(data);
        final isCampusServiceUnits = serviceCategory == 'Campus Service Units';

        details.add(
          _buildReceiptRow(
            'Total Amount',
            '₱${_safeParseNumber(data['total_amount']).toStringAsFixed(2)}',
          ),
        );

        // Display purpose for Campus Service Units
        if (isCampusServiceUnits &&
            data['purpose'] != null &&
            data['purpose'].toString().isNotEmpty) {
          details.add(
            _buildReceiptRow('Purpose of Payment', data['purpose'].toString()),
          );
        }

        // Display purchased items from service_transactions.items
        final dynamic rawItems = data['items'];
        List<dynamic> itemsList = [];
        if (rawItems is String) {
          try {
            final decoded = jsonDecode(rawItems);
            if (decoded is List) itemsList = decoded;
          } catch (_) {}
        } else if (rawItems is List) {
          itemsList = rawItems;
        }
        if (itemsList.isNotEmpty) {
          details.add(const SizedBox(height: 12));
          details.add(_buildReceiptRow('Items', '${itemsList.length} item(s)'));
          for (final item in itemsList) {
            try {
              final map = (item is Map) ? Map<String, dynamic>.from(item) : {};
              final String name =
                  (map['name'] ?? map['item_name'] ?? 'Item').toString();
              final double qty = _safeParseNumber(
                map['quantity'] ?? map['qty'],
              );
              final double price = _safeParseNumber(
                map['price'] ?? map['unit_price'] ?? map['amount'],
              );
              final double lineTotal =
                  map.containsKey('total')
                      ? _safeParseNumber(map['total'])
                      : (qty > 0 && price > 0 ? qty * price : price);
              details.add(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          qty > 0
                              ? 'x${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)}  •  ₱${lineTotal.toStringAsFixed(2)}'
                              : '₱${lineTotal.toStringAsFixed(2)}',
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          softWrap: true,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } catch (_) {
              // Fallback: show raw item string
              details.add(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    item.toString(),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              );
            }
          }
        }
        break;

      case 'transfer':
        final studentId = SessionService.currentUserStudentId;
        final isSent = data['sender_student_id'] == studentId;

        details.add(
          _buildReceiptRow('Transfer Direction', isSent ? 'Sent' : 'Received'),
        );
        details.add(
          _buildReceiptRow(
            'New Balance',
            '₱${_safeParseNumber(data[isSent ? 'sender_new_balance' : 'recipient_new_balance']).toStringAsFixed(2)}',
          ),
        );
        details.add(
          _buildReceiptRow('Status', data['status']?.toString() ?? 'Completed'),
        );
        break;

      case 'withdrawal':
        details.add(
          _buildReceiptRow(
            'Amount',
            '₱${_safeParseNumber(data['amount']).toStringAsFixed(2)}',
          ),
        );
        details.add(
          _buildReceiptRow(
            'Withdrawal Type',
            data['transaction_type']?.toString() ?? 'Unknown',
          ),
        );

        final metadata = data['metadata'] as Map<String, dynamic>?;
        if (metadata != null && metadata['destination_service_name'] != null) {
          details.add(
            _buildReceiptRow(
              'Destination',
              metadata['destination_service_name'].toString(),
            ),
          );
        } else {
          details.add(_buildReceiptRow('Destination', 'Admin'));
        }
        break;

      case 'withdrawal_request':
        // Display withdrawal request details
        final status = data['status']?.toString() ?? '';
        final transferType = data['transfer_type']?.toString() ?? '';
        final adminNotes = data['admin_notes']?.toString() ?? '';
        final processedBy = data['processed_by']?.toString() ?? 'Admin';
        final processedAt = data['processed_at']?.toString();

        details.add(
          _buildReceiptRow(
            'Request Status',
            status,
            statusColor: status == 'Approved' ? Colors.green : Colors.red,
          ),
        );

        details.add(
          _buildReceiptRow(
            'Withdrawal Amount',
            '₱${_safeParseNumber(data['amount']).toStringAsFixed(2)}',
          ),
        );

        details.add(_buildReceiptRow('Transfer Type', transferType));

        if (transferType == 'Gcash') {
          final gcashNumber = data['gcash_number']?.toString() ?? '';
          final gcashAccountName = data['gcash_account_name']?.toString() ?? '';
          if (gcashNumber.isNotEmpty) {
            details.add(_buildReceiptRow('GCash Number', gcashNumber));
          }
          if (gcashAccountName.isNotEmpty) {
            details.add(
              _buildReceiptRow('GCash Account Name', gcashAccountName),
            );
          }
        }

        if (processedBy.isNotEmpty && processedBy != 'Admin') {
          details.add(_buildReceiptRow('Processed By', processedBy));
        }

        if (processedAt != null && processedAt.isNotEmpty) {
          details.add(
            _buildReceiptRow('Processed At', _formatDateTime(processedAt)),
          );
        }

        // Show admin notes, especially for rejected requests
        if (adminNotes.isNotEmpty) {
          details.add(const SizedBox(height: 12));
          details.add(
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    status == 'Rejected'
                        ? Colors.red.withOpacity(0.1)
                        : Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      status == 'Rejected'
                          ? Colors.red.withOpacity(0.3)
                          : Colors.blue.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        status == 'Rejected'
                            ? Icons.cancel
                            : Icons.info_outline,
                        size: 16,
                        color: status == 'Rejected' ? Colors.red : Colors.blue,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status == 'Rejected'
                            ? 'Rejection Reason'
                            : 'Admin Notes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              status == 'Rejected' ? Colors.red : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    adminNotes,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          );
        }
        break;
    }

    if (details.isNotEmpty) {
      details.insert(0, const SizedBox(height: 16));
    }

    return details;
  }

  // Safe number parsing helper method
  double _safeParseNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  // Fetch actual transaction data based on notification
  Future<Map<String, dynamic>?> _fetchTransactionData(
    Map<String, dynamic> notification,
  ) async {
    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserStudentId;
      final notificationType =
          notification['type']?.toString().toLowerCase() ?? '';
      final notificationId = notification['id'];

      if (studentId.isEmpty) return null;

      // If this is a simple inbox message without transaction data, return null
      // The modal will just show the notification details
      if (notificationType.isEmpty) {
        // For simple inbox messages without type, just show notification details
        return null;
      }

      // Try to extract transaction ID from notification data or message
      String? transactionId;
      if (notification['transaction_id'] != null) {
        transactionId = notification['transaction_id'].toString();
      } else if (notification['action_data'] != null) {
        // Try to parse from action_data if it's a JSON string
        try {
          final actionData = notification['action_data'].toString();
          // Try to extract transaction ID from action_data
          // Look for patterns like: id:123, id="123", id='123', id=123
          // Use a simpler pattern that matches id=123 or id:123 or id="123" etc
          final patterns = [
            RegExp(r'id\s*=\s*(\d+)'),
            RegExp(r'id\s*:\s*(\d+)'),
            RegExp(r'"id"\s*:\s*"?(\d+)"?'),
            RegExp(r"'id'\s*:\s*'?(\d+)'?"),
          ];

          for (final pattern in patterns) {
            final match = pattern.firstMatch(actionData);
            if (match != null && match.groupCount > 0) {
              transactionId = match.group(1);
              break;
            }
          }
        } catch (e) {
          print('ERROR: Failed to parse action_data: $e');
        }
      }

      if (transactionId == null) {
        // Try to parse transaction ID from message
        final message = notification['message']?.toString() ?? '';
        final idMatch = RegExp(r'#(\d+)').firstMatch(message);
        if (idMatch != null) {
          transactionId = idMatch.group(1);
        }
      }

      // Fetch data based on notification type
      switch (notificationType) {
        case 'topup_success':
        case 'transaction_success':
        case 'top_up':
          if (transactionId != null) {
            final result =
                await SupabaseService.client
                    .from('top_up_transactions')
                    .select('*')
                    .eq('id', transactionId)
                    .eq('student_id', studentId)
                    .single();
            return {'type': 'top_up', 'data': result, 'id': transactionId};
          }
          break;

        case 'loan_disbursement':
          if (transactionId != null) {
            final result =
                await SupabaseService.client
                    .from('top_up_transactions')
                    .select('*')
                    .eq('id', transactionId)
                    .eq('student_id', studentId)
                    .eq('transaction_type', 'loan_disbursement')
                    .single();
            return {
              'type': 'loan_disbursement',
              'data': result,
              'id': transactionId,
            };
          }
          break;

        case 'loan_payment':
        case 'loan_reminder':
          if (transactionId != null) {
            final result =
                await SupabaseService.client
                    .from('loan_payments')
                    .select('*')
                    .eq('id', transactionId)
                    .eq('student_id', studentId)
                    .single();
            return {
              'type': 'loan_payment',
              'data': result,
              'id': transactionId,
            };
          }
          break;

        case 'active_loan':
          if (transactionId != null) {
            final result =
                await SupabaseService.client
                    .from('loan_actives')
                    .select('*')
                    .eq('id', transactionId)
                    .eq('student_id', studentId)
                    .single();
            return {'type': 'active_loan', 'data': result, 'id': transactionId};
          }
          break;

        case 'transfer_sent':
        case 'transfer_received':
          if (transactionId != null) {
            final result =
                await SupabaseService.client
                    .from('user_transfers')
                    .select('*')
                    .eq('id', transactionId)
                    .or(
                      'sender_student_id.eq.$studentId,recipient_student_id.eq.$studentId',
                    )
                    .single();
            return {'type': 'transfer', 'data': result, 'id': transactionId};
          }
          break;

        case 'service_payment':
          if (transactionId != null) {
            final result =
                await SupabaseService.client
                    .from('service_transactions')
                    .select(
                      '*, service_accounts!service_transactions_service_account_id_fkey(service_category)',
                    )
                    .eq('id', transactionId)
                    .eq('student_id', studentId)
                    .single();
            return {
              'type': 'service_payment',
              'data': result,
              'id': transactionId,
            };
          }
          break;

        case 'loan_due_soon':
        case 'loan_overdue':
          // For loan reminders, try to get active loan data
          final activeLoans = await SupabaseService.client
              .from('loan_actives')
              .select('*')
              .eq('student_id', studentId)
              .order('created_at', ascending: false)
              .limit(1);
          if (activeLoans.isNotEmpty) {
            return {
              'type': 'active_loan',
              'data': activeLoans.first,
              'id': activeLoans.first['id'].toString(),
            };
          }
          break;

        case 'withdrawal_request':
          // For withdrawal requests, use transaction_id to fetch from withdrawal_requests table
          final requestId =
              notification['transaction_id']?.toString() ??
              notification['request_id']?.toString() ??
              notificationId?.toString();
          if (requestId != null) {
            try {
              final result =
                  await SupabaseService.client
                      .from('withdrawal_requests')
                      .select('*')
                      .eq('id', requestId)
                      .eq('student_id', studentId)
                      .single();
              return {
                'type': 'withdrawal_request',
                'data': result,
                'id': requestId,
              };
            } catch (e) {
              // If fetch fails, return notification data (which already has all the info)
              return {
                'type': 'withdrawal_request',
                'data': notification,
                'id': requestId,
              };
            }
          }
          // If no request_id, return notification data
          return {
            'type': 'withdrawal_request',
            'data': notification,
            'id': notificationId?.toString(),
          };

        case 'withdrawal':
          // For withdrawal transactions, fetch from withdrawal_transactions
          if (transactionId != null) {
            try {
              final result =
                  await SupabaseService.adminClient
                      .from('withdrawal_transactions')
                      .select('*')
                      .eq('id', transactionId)
                      .eq('student_id', studentId)
                      .single();
              return {
                'type': 'withdrawal',
                'data': result,
                'id': transactionId,
              };
            } catch (e) {
              // If fetch fails, return notification data
              return {
                'type': 'withdrawal',
                'data': notification,
                'id': transactionId,
              };
            }
          }
          break;
      }

      // If no specific transaction found, return notification data
      // For loan-related notifications, the data might already be in the notification
      if (notificationType == 'loan_disbursement' ||
          notificationType == 'active_loan' ||
          notificationType == 'loan_payment' ||
          notificationType == 'service_payment' ||
          notificationType == 'top_up' ||
          notificationType == 'withdrawal_request' ||
          notificationType == 'withdrawal') {
        return {
          'type': notificationType,
          'data': notification,
          'id': notificationId?.toString(),
        };
      }

      return {
        'type': notificationType ?? 'unknown',
        'data': notification,
        'id': notificationId?.toString(),
      };
    } catch (e) {
      return {
        'type': notification['type']?.toString() ?? 'unknown',
        'data': notification,
        'id': notification['id']?.toString(),
      };
    }
  }
}

class _TransactionsTab extends StatefulWidget {
  const _TransactionsTab();

  @override
  State<_TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<_TransactionsTab> {
  static const Color evsuRed = Color(0xFFB91C1C);
  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  StreamSubscription<List<Map<String, dynamic>>>? _topUpSub;
  StreamSubscription<List<Map<String, dynamic>>>? _serviceTxSub;
  StreamSubscription<List<Map<String, dynamic>>>? _transferSub;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    try {
      _topUpSub?.cancel();
    } catch (_) {}
    try {
      _serviceTxSub?.cancel();
    } catch (_) {}
    try {
      _transferSub?.cancel();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserStudentId;
      print('DEBUG: Loading transaction history for studentId: "$studentId"');

      // DEBUG: Test loan_payments table specifically
      await _debugLoanPaymentsTable(studentId);

      if (studentId.isEmpty) {
        print('DEBUG: StudentId is empty in transactions tab, returning');
        setState(() {
          _transactions = [];
          _isLoading = false;
        });
        return;
      }

      final List<Map<String, dynamic>> merged = [];

      // 1. Query top-up transactions (include manual and gcash; exclude loan disbursements)
      try {
        print('DEBUG: Querying top_up_transactions for actual top-ups...');
        final topups = await SupabaseService.client
            .from('top_up_transactions')
            .select(
              'id, student_id, amount, new_balance, created_at, processed_by, transaction_type',
            )
            .eq('student_id', studentId)
            .inFilter('transaction_type', [
              'top_up',
              'top_up_gcash',
            ]) // include both manual and gcash
            .order('created_at', ascending: false)
            .limit(100);

        print('DEBUG: Top-up transactions found: ${topups.length}');
        for (final t in (topups as List)) {
          merged.add({
            'id': t['id'],
            'transaction_type':
                'top_up', // normalize gcash/manual into one UI type
            'amount': _safeParseNumber(t['amount']),
            'created_at':
                t['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            'new_balance': _safeParseNumber(t['new_balance']),
            'processed_by': t['processed_by'],
          });
        }
      } catch (e) {
        print('DEBUG: Error querying top-up transactions: $e');
      }

      // 2. Query loan disbursements separately
      try {
        print('DEBUG: Querying loan disbursements...');
        final loanDisbursements = await SupabaseService.client
            .from('top_up_transactions')
            .select(
              'id, student_id, amount, new_balance, created_at, processed_by, transaction_type',
            )
            .eq('student_id', studentId)
            .eq('transaction_type', 'loan_disbursement')
            .order('created_at', ascending: false)
            .limit(100);

        print('DEBUG: Loan disbursements found: ${loanDisbursements.length}');
        for (final ld in (loanDisbursements as List)) {
          merged.add({
            'id': ld['id'],
            'transaction_type': 'loan_disbursement',
            'amount': _safeParseNumber(ld['amount']),
            'created_at':
                ld['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'new_balance': _safeParseNumber(ld['new_balance']),
            'processed_by': ld['processed_by'],
          });
        }
      } catch (e) {
        print('DEBUG: Error querying loan disbursements: $e');
      }

      // 3. Query active loans
      try {
        print('DEBUG: Querying active loans...');
        final activeLoans = await SupabaseService.client
            .from('loan_actives')
            .select(
              'id, student_id, loan_amount, remaining_balance, created_at, loan_plan_id',
            )
            .eq('student_id', studentId)
            .order('created_at', ascending: false)
            .limit(100);

        print('DEBUG: Active loans found: ${activeLoans.length}');
        for (final al in (activeLoans as List)) {
          merged.add({
            'id': al['id'],
            'transaction_type': 'active_loan',
            'amount': _safeParseNumber(al['loan_amount']),
            'created_at':
                al['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'remaining_balance': _safeParseNumber(al['remaining_balance']),
            'loan_plan_id': al['loan_plan_id'],
          });
        }
      } catch (e) {
        print('DEBUG: Error querying active loans: $e');
      }

      // 4. Query loan payments
      try {
        print('DEBUG: Querying loan payments...');
        print('DEBUG: Student ID for loan payments query: "$studentId"');

        final loanPayments = await SupabaseService.client
            .from('loan_payments')
            .select(
              'id, student_id, payment_amount, remaining_balance, created_at, loan_id',
            )
            .eq('student_id', studentId)
            .order('created_at', ascending: false)
            .limit(100);

        print('DEBUG: Raw loan payments query result: ${loanPayments.length}');
        print('DEBUG: Loan payments data type: ${loanPayments.runtimeType}');

        if (loanPayments.isNotEmpty) {
          print('DEBUG: First loan payment sample: ${loanPayments.first}');
        }

        for (final lp in (loanPayments as List)) {
          print(
            'DEBUG: Processing loan payment: ${lp['id']}, amount: ${lp['payment_amount']}, remaining: ${lp['remaining_balance']}',
          );

          final parsedAmount = _safeParseNumber(lp['payment_amount']);
          final parsedBalance = _safeParseNumber(lp['remaining_balance']);

          print(
            'DEBUG: Parsed amount: $parsedAmount, Parsed balance: $parsedBalance',
          );

          final transactionData = {
            'id': lp['id'],
            'transaction_type': 'loan_payment',
            'amount': parsedAmount,
            'created_at':
                lp['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'remaining_balance': parsedBalance,
            'loan_id': lp['loan_id'],
          };

          print('DEBUG: Adding loan payment transaction: $transactionData');
          merged.add(transactionData);
        }

        print(
          'DEBUG: Total loan payments added to merged list: ${merged.where((t) => t['transaction_type'] == 'loan_payment').length}',
        );
      } catch (e) {
        print('DEBUG: Error querying loan payments: $e');
        print('DEBUG: Error type: ${e.runtimeType}');
        print('DEBUG: Stack trace: ${StackTrace.current}');
      }

      // 5. Query service transactions
      try {
        print('DEBUG: Querying service transactions...');
        final payments = await SupabaseService.client
            .from('service_transactions')
            .select('id, total_amount, created_at, student_id')
            .eq('student_id', studentId)
            .order('created_at', ascending: false)
            .limit(100);

        print('DEBUG: Service transactions found: ${payments.length}');
        for (final p in (payments as List)) {
          merged.add({
            'id': p['id'],
            'transaction_type': 'service_payment',
            'amount': _safeParseNumber(p['total_amount']),
            'created_at':
                p['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          });
        }
      } catch (e) {
        print('DEBUG: Error querying service transactions: $e');
      }

      // 6. Query user transfers
      try {
        print('DEBUG: Querying user transfers...');
        final transfers = await SupabaseService.client
            .from('user_transfers')
            .select(
              'id, sender_student_id, recipient_student_id, amount, sender_new_balance, recipient_new_balance, created_at, status',
            )
            .or(
              'sender_student_id.eq.$studentId,recipient_student_id.eq.$studentId',
            )
            .order('created_at', ascending: false)
            .limit(100);

        print('DEBUG: User transfers found: ${transfers.length}');
        for (final transfer in (transfers as List)) {
          final isSent = transfer['sender_student_id'] == studentId;
          merged.add({
            'id': transfer['id'],
            'transaction_type': 'transfer',
            'amount': _safeParseNumber(transfer['amount']),
            'created_at':
                transfer['created_at']?.toString() ??
                DateTime.now().toIso8601String(),
            'new_balance':
                isSent
                    ? _safeParseNumber(transfer['sender_new_balance'])
                    : _safeParseNumber(transfer['recipient_new_balance']),
            'transfer_direction': isSent ? 'sent' : 'received',
            'sender_student_id': transfer['sender_student_id'],
            'recipient_student_id': transfer['recipient_student_id'],
            'status': transfer['status'],
          });
        }
      } catch (e) {
        print('DEBUG: Error querying user transfers: $e');
      }

      // 7. Query withdrawal transactions using adminClient via service function
      try {
        print('DEBUG WITHDRAWAL: Starting withdrawal query...');
        print('DEBUG WITHDRAWAL: Student ID: "$studentId"');
        print(
          'DEBUG WITHDRAWAL: Using getUserWithdrawalHistory service function (with adminClient)',
        );

        final withdrawalResult = await SupabaseService.getUserWithdrawalHistory(
          studentId: studentId,
          limit: 100,
        );

        print(
          'DEBUG WITHDRAWAL: Service function result - success: ${withdrawalResult['success']}',
        );

        if (withdrawalResult['success'] == true) {
          final withdrawalData = withdrawalResult['data'] as List?;
          final withdrawals = withdrawalData ?? [];

          print(
            'DEBUG WITHDRAWAL: Withdrawal transactions found: ${withdrawals.length}',
          );

          if (withdrawals.isEmpty) {
            print('DEBUG WITHDRAWAL: No withdrawals found for this student');
            print(
              'DEBUG WITHDRAWAL: This student has not made any withdrawals yet',
            );
          } else {
            print(
              'DEBUG WITHDRAWAL: Processing ${withdrawals.length} withdrawal records...',
            );
          }

          for (final w in withdrawals) {
            print(
              'DEBUG WITHDRAWAL: Processing withdrawal ID: ${w['id']}, Amount: ${w['amount']}, Type: ${w['transaction_type']}',
            );
            final withdrawalEntry = {
              'id': w['id'],
              'transaction_type': 'withdrawal',
              'amount': _safeParseNumber(w['amount']),
              'created_at':
                  w['created_at']?.toString() ??
                  DateTime.now().toIso8601String(),
              'withdrawal_type': w['transaction_type'],
              'destination_service_id': w['destination_service_id'],
              'metadata': w['metadata'],
            };
            merged.add(withdrawalEntry);
            print(
              'DEBUG WITHDRAWAL: Added withdrawal to merged list: ${withdrawalEntry['id']}',
            );
          }
          print(
            'DEBUG WITHDRAWAL: Total transactions in merged list after withdrawals: ${merged.length}',
          );
        } else {
          print(
            'DEBUG WITHDRAWAL: Service function returned error: ${withdrawalResult['message']}',
          );
          print(
            'DEBUG WITHDRAWAL: Error details: ${withdrawalResult['error']}',
          );
        }
      } catch (e) {
        print('DEBUG WITHDRAWAL: Error querying withdrawal transactions: $e');
        print('DEBUG WITHDRAWAL: Error type: ${e.runtimeType}');
        if (e is Exception) {
          print('DEBUG WITHDRAWAL: Exception details: $e');
        }
      }

      // Sort all transactions by date
      merged.sort(
        (a, b) => DateTime.parse(
          b['created_at'],
        ).compareTo(DateTime.parse(a['created_at'])),
      );

      setState(() {
        _transactions = merged;
        _isLoading = false;
      });

      print('DEBUG: Total transactions loaded: ${merged.length}');

      // Debug: Count transactions by type
      final typeCounts = <String, int>{};
      for (final transaction in merged) {
        final type = transaction['transaction_type'] as String;
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
      print('DEBUG: Transaction type counts: $typeCounts');

      // Debug: Show loan payment transactions specifically
      final loanPayments =
          merged.where((t) => t['transaction_type'] == 'loan_payment').toList();
      print(
        'DEBUG: Loan payment transactions in final list: ${loanPayments.length}',
      );
      for (final lp in loanPayments) {
        print(
          'DEBUG: Loan payment - ID: ${lp['id']}, Amount: ${lp['amount']}, Date: ${lp['created_at']}',
        );
      }
    } catch (e) {
      print('DEBUG: Error loading transactions: $e');
      setState(() {
        _transactions = [];
        _isLoading = false;
      });
    }
  }

  // Safe number parsing helper method
  double _safeParseNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed ?? 0.0;
    }
    return 0.0;
  }

  void _subscribeRealtime() {
    final studentId = SessionService.currentUserStudentId;
    if (studentId.isEmpty) return;

    try {
      _topUpSub?.cancel();
    } catch (_) {}
    _topUpSub = SupabaseService.client
        .from('top_up_transactions')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .listen((rows) {
          final additions =
              rows
                  .map(
                    (r) => {
                      'transaction_type': 'top_up',
                      'amount': (r['amount'] as num?) ?? 0,
                      'created_at':
                          r['created_at']?.toString() ??
                          DateTime.now().toIso8601String(),
                      'new_balance': (r['new_balance'] as num?) ?? 0,
                    },
                  )
                  .toList();
          _mergeAndRefresh(additions);
        });

    try {
      _serviceTxSub?.cancel();
    } catch (_) {}
    _serviceTxSub = SupabaseService.client
        .from('service_transactions')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .listen((rows) {
          final additions =
              rows
                  .map(
                    (r) => {
                      'transaction_type': 'payment',
                      'amount': (r['total_amount'] as num?) ?? 0,
                      'created_at':
                          r['created_at']?.toString() ??
                          DateTime.now().toIso8601String(),
                    },
                  )
                  .toList();
          _mergeAndRefresh(additions);
        });

    // Subscribe to user transfers for real-time updates
    try {
      _transferSub?.cancel();
    } catch (_) {}
    _transferSub = SupabaseService.client
        .from('user_transfers')
        .stream(primaryKey: ['id'])
        .listen((rows) {
          // Filter rows to include only transfers involving this student
          final filteredRows =
              rows
                  .where(
                    (row) =>
                        row['sender_student_id'] == studentId ||
                        row['recipient_student_id'] == studentId,
                  )
                  .toList();
          final additions =
              filteredRows.map((r) {
                final isSent = r['sender_student_id'] == studentId;
                return {
                  'transaction_type': 'transfer',
                  'amount': (r['amount'] as num?) ?? 0,
                  'created_at':
                      r['created_at']?.toString() ??
                      DateTime.now().toIso8601String(),
                  'new_balance':
                      isSent
                          ? (r['sender_new_balance'] as num?) ?? 0
                          : (r['recipient_new_balance'] as num?) ?? 0,
                  'transfer_direction': isSent ? 'sent' : 'received',
                  'sender_student_id': r['sender_student_id'],
                  'recipient_student_id': r['recipient_student_id'],
                  'status': r['status'],
                };
              }).toList();
          _mergeAndRefresh(additions);
        });
  }

  void _mergeAndRefresh(List<Map<String, dynamic>> newItems) {
    if (newItems.isEmpty) return;

    // Check if any new items are top-ups and refresh balance
    final hasTopUp = newItems.any(
      (item) =>
          item['transaction_type'] == 'top_up' ||
          item['transaction_type'] == 'top_up_gcash',
    );

    if (hasTopUp) {
      // Refresh balance when top-up is detected
      SessionService.refreshUserData().then((_) {
        if (mounted) {
          setState(() {});
        }
      });
    }

    final List<Map<String, dynamic>> merged = List.from(_transactions);
    merged.insertAll(0, newItems);
    merged.sort(
      (a, b) => DateTime.parse(
        b['created_at'],
      ).compareTo(DateTime.parse(a['created_at'])),
    );
    setState(() {
      _transactions = merged;
    });
  }

  // Public method to refresh transactions (can be called externally)
  Future<void> refreshTransactions() async {
    await _loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Transaction History',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: evsuRed,
                  ),
                ),
                IconButton(
                  onPressed: _loadTransactions,
                  icon: const Icon(Icons.refresh, color: evsuRed),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Filter tabs
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _selectedFilter == 'All',
                      onTap: () => setState(() => _selectedFilter = 'All'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Top-ups',
                      isSelected: _selectedFilter == 'Top-ups',
                      onTap: () => setState(() => _selectedFilter = 'Top-ups'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Withdrawals',
                      isSelected: _selectedFilter == 'Withdrawals',
                      onTap:
                          () => setState(() => _selectedFilter = 'Withdrawals'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Loans',
                      isSelected: _selectedFilter == 'Loans',
                      onTap: () => setState(() => _selectedFilter = 'Loans'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Payments',
                      isSelected: _selectedFilter == 'Payments',
                      onTap: () => setState(() => _selectedFilter = 'Payments'),
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Transfers',
                      isSelected: _selectedFilter == 'Transfers',
                      onTap:
                          () => setState(() => _selectedFilter = 'Transfers'),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child:
                  _isLoading
                      ? const Center(
                        child: CircularProgressIndicator(color: evsuRed),
                      )
                      : _transactions.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                        itemCount: _getFilteredTransactions().length,
                        itemBuilder: (context, index) {
                          final transaction = _getFilteredTransactions()[index];
                          return _buildTransactionCard(transaction);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // DEBUG: Comprehensive loan_payments table debugging
  Future<void> _debugLoanPaymentsTable(String studentId) async {
    print('\n=== DEBUG LOAN PAYMENTS TABLE START ===');
    print('DEBUG: Student ID: "$studentId"');

    try {
      // Test 1: Check if table exists and is accessible
      print('DEBUG: Testing table accessibility...');
      await SupabaseService.client
          .from('loan_payments')
          .select('count')
          .limit(1);
      print('DEBUG: Table accessibility test passed');

      // Test 2: Get total count of loan payments
      print('DEBUG: Getting total count of loan payments...');
      final countResult = await SupabaseService.client
          .from('loan_payments')
          .select('*');
      print('DEBUG: Total loan payments in table: ${countResult.length}');

      // Test 3: Get all loan payments for this student
      print('DEBUG: Getting all loan payments for student "$studentId"...');
      final allPayments = await SupabaseService.client
          .from('loan_payments')
          .select('*')
          .eq('student_id', studentId);
      print('DEBUG: Loan payments for this student: ${allPayments.length}');

      if (allPayments.isNotEmpty) {
        print('DEBUG: Sample loan payment data:');
        for (int i = 0; i < allPayments.length && i < 3; i++) {
          final payment = allPayments[i];
          print('DEBUG: Payment ${i + 1}:');
          print('  - ID: ${payment['id']}');
          print('  - Student ID: ${payment['student_id']}');
          print(
            '  - Payment Amount: ${payment['payment_amount']} (type: ${payment['payment_amount'].runtimeType})',
          );
          print(
            '  - Remaining Balance: ${payment['remaining_balance']} (type: ${payment['remaining_balance'].runtimeType})',
          );
          print('  - Created At: ${payment['created_at']}');
          print('  - Loan ID: ${payment['loan_id']}');
        }
      } else {
        print('DEBUG: No loan payments found for student "$studentId"');

        // Test 4: Check if there are any loan payments at all
        print(
          'DEBUG: Checking if there are any loan payments in the entire table...',
        );
        final anyPayments = await SupabaseService.client
            .from('loan_payments')
            .select('id, student_id, payment_amount, created_at')
            .limit(5);
        print('DEBUG: Any loan payments in table: ${anyPayments.length}');
        if (anyPayments.isNotEmpty) {
          print('DEBUG: Sample loan payments from entire table:');
          for (final payment in anyPayments) {
            print(
              '  - ID: ${payment['id']}, Student: ${payment['student_id']}, Amount: ${payment['payment_amount']}',
            );
          }
        }
      }

      // Test 5: Check table schema
      print('DEBUG: Checking table schema...');
      try {
        await SupabaseService.client.from('loan_payments').select('*').limit(0);
        print('DEBUG: Schema test passed - table exists');
      } catch (e) {
        print('DEBUG: Schema test failed: $e');
      }
    } catch (e) {
      print('DEBUG: Error during loan_payments debugging: $e');
      print('DEBUG: Error type: ${e.runtimeType}');

      // Test alternative queries
      try {
        print('DEBUG: Trying alternative query...');
        await SupabaseService.client
            .from('loan_payments')
            .select('id')
            .limit(1);
        print('DEBUG: Alternative query successful');
      } catch (altError) {
        print('DEBUG: Alternative query also failed: $altError');
      }
    }

    print('=== DEBUG LOAN PAYMENTS TABLE END ===\n');
  }

  List<Map<String, dynamic>> _getFilteredTransactions() {
    print('DEBUG FILTER: Current filter: $_selectedFilter');
    print('DEBUG FILTER: Total transactions: ${_transactions.length}');

    if (_selectedFilter == 'All') {
      print('DEBUG FILTER: Showing all transactions');
      // Count transaction types
      final typeCounts = <String, int>{};
      for (final t in _transactions) {
        final type = t['transaction_type'] as String;
        typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      }
      print('DEBUG FILTER: Transaction types in All: $typeCounts');
      return _transactions;
    } else if (_selectedFilter == 'Top-ups') {
      return _transactions
          .where((t) => t['transaction_type'] == 'top_up')
          .toList();
    } else if (_selectedFilter == 'Withdrawals') {
      print('DEBUG FILTER: Filtering for withdrawals...');
      final filtered =
          _transactions.where((t) {
            final type = t['transaction_type'];
            print(
              'DEBUG FILTER: Checking transaction type: "$type" (is withdrawal: ${type == 'withdrawal'})',
            );
            return type == 'withdrawal';
          }).toList();
      print(
        'DEBUG FILTER: Withdrawals filter applied - found ${filtered.length} transactions',
      );
      if (filtered.isNotEmpty) {
        for (final w in filtered) {
          print(
            'DEBUG FILTER: Withdrawal - ID: ${w['id']}, Amount: ${w['amount']}, Type: ${w['withdrawal_type']}',
          );
        }
      } else {
        print('DEBUG FILTER: No withdrawal transactions found in filter');
      }
      return filtered;
    } else if (_selectedFilter == 'Loans') {
      final filtered =
          _transactions
              .where(
                (t) =>
                    t['transaction_type'] == 'loan_disbursement' ||
                    t['transaction_type'] == 'active_loan' ||
                    t['transaction_type'] == 'loan_payment',
              )
              .toList();
      print(
        'DEBUG FILTER: Loans filter applied - found ${filtered.length} transactions',
      );
      for (final t in filtered) {
        print(
          'DEBUG FILTER: ${t['transaction_type']} - ID: ${t['id']}, Amount: ${t['amount']}',
        );
      }
      return filtered;
    } else if (_selectedFilter == 'Payments') {
      return _transactions
          .where((t) => t['transaction_type'] == 'service_payment')
          .toList();
    } else if (_selectedFilter == 'Transfers') {
      return _transactions
          .where((t) => t['transaction_type'] == 'transfer')
          .toList();
    }
    return _transactions;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No transactions found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transaction history will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final transactionType = transaction['transaction_type'] as String;
    print('DEBUG CARD: Building card for transaction type: "$transactionType"');
    final amount = _safeParseNumber(transaction['amount']);
    final createdAt = DateTime.parse(transaction['created_at']);
    final formattedDate =
        '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    final formattedTime =
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    // Determine transaction details based on type
    String title;
    String subtitle;
    IconData icon;
    List<Color> gradientColors;
    String amountPrefix;
    Color amountColor;
    String? balanceText;

    switch (transactionType) {
      case 'top_up':
        title = 'Account Top-up';
        subtitle = 'Balance credited';
        icon = Icons.add;
        gradientColors = [Colors.green, Colors.green[700]!];
        amountPrefix = '+';
        amountColor = Colors.green;
        balanceText =
            '₱${_safeParseNumber(transaction['new_balance']).toStringAsFixed(2)}';
        break;

      case 'loan_disbursement':
        title = 'Loan Disbursement';
        subtitle = 'Loan amount credited';
        icon = Icons.account_balance;
        gradientColors = [Colors.purple, Colors.purple[700]!];
        amountPrefix = '+';
        amountColor = Colors.purple;
        balanceText =
            '₱${_safeParseNumber(transaction['new_balance']).toStringAsFixed(2)}';
        break;

      case 'active_loan':
        title = 'Active Loan';
        subtitle = 'Outstanding loan';
        icon = Icons.credit_card;
        gradientColors = [Colors.orange, Colors.orange[700]!];
        amountPrefix = '';
        amountColor = Colors.orange;
        balanceText =
            'Remaining: ₱${_safeParseNumber(transaction['remaining_balance']).toStringAsFixed(2)}';
        break;

      case 'loan_payment':
        title = 'Loan Payment';
        subtitle = 'Payment made';
        icon = Icons.payment;
        gradientColors = [Colors.blue, Colors.blue[700]!];
        amountPrefix = '-';
        amountColor = Colors.blue;
        balanceText =
            'Remaining: ₱${_safeParseNumber(transaction['remaining_balance']).toStringAsFixed(2)}';
        break;

      case 'service_payment':
        title = 'Service Payment';
        subtitle = 'Payment processed';
        icon = Icons.remove;
        gradientColors = [evsuRed, const Color(0xFF7F1D1D)];
        amountPrefix = '-';
        amountColor = evsuRed;
        break;

      case 'transfer':
        final transferDirection = transaction['transfer_direction'] as String?;
        final isSent = transferDirection == 'sent';
        title = isSent ? 'Money Sent' : 'Money Received';
        subtitle = isSent ? 'Transfer to friend' : 'Transfer from friend';
        icon = isSent ? Icons.send : Icons.call_received;
        gradientColors =
            isSent
                ? [Colors.orange, Colors.orange[700]!]
                : [Colors.blue, Colors.blue[700]!];
        amountPrefix = isSent ? '-' : '+';
        amountColor = isSent ? Colors.orange : Colors.blue;
        balanceText =
            '₱${_safeParseNumber(transaction['new_balance']).toStringAsFixed(2)}';
        break;

      case 'withdrawal':
        print('DEBUG CARD: Rendering withdrawal card');
        final withdrawalType = transaction['withdrawal_type'] as String?;
        final metadata = transaction['metadata'] as Map<String, dynamic>?;
        print(
          'DEBUG CARD: Withdrawal type: $withdrawalType, Metadata: $metadata',
        );

        if (withdrawalType == 'Withdraw to Service') {
          final serviceName =
              metadata?['destination_service_name']?.toString() ?? 'Service';
          print('DEBUG CARD: Service withdrawal to: $serviceName');
          title = 'Withdrawal';
          subtitle = 'To $serviceName';
          icon = Icons.account_balance_wallet;
          gradientColors = [Colors.purple, Colors.purple[700]!];
        } else {
          print('DEBUG CARD: Admin withdrawal');
          title = 'Withdrawal';
          subtitle = 'Cash out to Admin';
          icon = Icons.account_balance_wallet;
          gradientColors = [Colors.red[700]!, Colors.red[900]!];
        }
        amountPrefix = '-';
        amountColor = Colors.red[700]!;
        break;

      default:
        title = 'Transaction';
        subtitle = 'Transaction processed';
        icon = Icons.payment;
        gradientColors = [Colors.grey, Colors.grey[700]!];
        amountPrefix = '-';
        amountColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(child: Icon(icon, color: Colors.white, size: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '$formattedDate $formattedTime',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${amountPrefix}₱${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
                if (balanceText != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    balanceText,
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB91C1C) : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  static const Color evsuRed = Color(0xFFB91C1C);

  double totalSpent = 0.0;
  double thisMonthSpent = 0.0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSpendingData();
  }

  Future<void> _loadSpendingData() async {
    try {
      final studentId = SessionService.currentUserStudentId;
      if (studentId.isEmpty) return;

      // Get current month start date
      final now = DateTime.now();
      final currentMonthStart = DateTime(now.year, now.month, 1);

      // Fetch all service transactions for total spent
      final allTransactions = await SupabaseService.client
          .from('service_transactions')
          .select('total_amount, created_at')
          .eq('student_id', studentId);

      // Fetch this month's transactions
      final thisMonthTransactions = await SupabaseService.client
          .from('service_transactions')
          .select('total_amount, created_at')
          .eq('student_id', studentId)
          .gte('created_at', currentMonthStart.toIso8601String());

      // Calculate totals
      double total = 0.0;
      for (final transaction in allTransactions) {
        final amount = (transaction['total_amount'] as num?)?.toDouble() ?? 0.0;
        total += amount;
      }

      double monthTotal = 0.0;
      for (final transaction in thisMonthTransactions) {
        final amount = (transaction['total_amount'] as num?)?.toDouble() ?? 0.0;
        monthTotal += amount;
      }

      if (mounted) {
        setState(() {
          totalSpent = total;
          thisMonthSpent = monthTotal;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading spending data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [evsuRed, Color(0xFF7F1D1D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    SessionService.currentUserName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Student ID: ${SessionService.currentUserStudentId}',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Course: ${SessionService.currentUserCourse}',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Text(
                      'Verified Student',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Stats
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    title: 'Total Spent',
                    value:
                        isLoading
                            ? 'Loading...'
                            : '₱${totalSpent.toStringAsFixed(2)}',
                    icon: Icons.trending_down,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    title: 'This Month',
                    value:
                        isLoading
                            ? 'Loading...'
                            : '₱${thisMonthSpent.toStringAsFixed(2)}',
                    icon: Icons.calendar_month,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Menu Items
            _buildMenuSection('Account', [
              _MenuItem(
                icon: Icons.security,
                title: 'Security & Privacy',
                subtitle: 'Manage your account security',
                onTap:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SecurityPrivacyScreen(),
                      ),
                    ),
              ),
            ]),

            const SizedBox(height: 20),

            _buildMenuSection('Preferences', [
              _MenuItem(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Configure alert preferences',
                onTap: () => _showNotificationSettingsDialog(context),
              ),
            ]),

            const SizedBox(height: 20),

            _buildMenuSection('Support', [
              _MenuItem(
                icon: Icons.help_outline,
                title: 'Help & Support',
                subtitle: 'Get help with your account',
                onTap: () => _showHelpAndSupportDialog(context),
              ),
              _MenuItem(
                icon: Icons.feedback_outlined,
                title: 'Send Feedback',
                subtitle: 'Share your experience',
                onTap: () => _showFeedbackDialog(context),
              ),
              _MenuItem(
                icon: Icons.info_outline,
                title: 'About eCampusPay',
                subtitle: 'Version 1.0.0',
                onTap: () => _showComingSoon(context),
              ),
            ]),

            const SizedBox(height: 32),

            // Logout Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showLogoutDialog(context),
                icon: const Icon(Icons.logout),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _showHelpAndSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: const [
                Icon(Icons.support_agent, color: evsuRed),
                SizedBox(width: 8),
                Text('Help & Support'),
              ],
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '1) Top-Up',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Option A: Top-Up via GCash',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Select “Top-Up via GCash”.\n'
                      '• Enter the amount to top up.\n'
                      '• Upload an image proof of the GCash payment (screenshot or receipt).\n'
                      '• The system sends a request to the admin for approval.\n'
                      '• Admin reviews the uploaded payment proof.\n'
                      '• If approved, the amount is added to your e-wallet balance.\n'
                      '• If rejected, you will be notified and your balance remains unchanged.',
                      style: TextStyle(height: 1.35),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Option B: Top-Up via Admin Office',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• Go to the admin office station.\n'
                      '• Request top-up and provide the amount to add.\n'
                      '• Admin manually updates your balance.\n'
                      '• Your e-wallet balance reflects the update immediately.',
                      style: TextStyle(height: 1.35),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '2) Withdrawal for Services',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Click “Withdraw” and select the service type (e.g., vendor payment).\n'
                      '• Enter the withdrawal amount.\n'
                      '• Choose a withdrawal method:\n'
                      '    – GCash → provide GCash account number and name.\n'
                      '    – On-Site Cash → request cash at the admin station.\n'
                      '• The system sends your withdrawal request to admin.\n'
                      '• Admin reviews and approves/rejects the request.',
                      style: TextStyle(height: 1.35),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'If approved:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• The amount is deducted from your e-wallet.\n'
                      '• Funds are sent via GCash or made available for on-site collection.',
                      style: TextStyle(height: 1.35),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'If rejected:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '• You will be notified, and your balance remains unchanged.',
                      style: TextStyle(height: 1.35),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 20), const Spacer()]),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildMenuSection(String title, List<_MenuItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            children: items.map((item) => _buildMenuItem(item)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: evsuRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(item.icon, color: evsuRed, size: 20),
      ),
      title: Text(
        item.title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      subtitle:
          item.subtitle != null
              ? Text(
                item.subtitle!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              )
              : null,
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey,
      ),
      onTap: item.onTap,
    );
  }

  void _showFeedbackDialog(BuildContext context) {
    final feedbackController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Send Feedback'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'We value your feedback! Please share your thoughts, suggestions, or report any issues you\'ve encountered.',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: feedbackController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Your feedback',
                            hintText: 'Tell us what you think...',
                            border: OutlineInputBorder(),
                            alignLabelWithHint: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your feedback will help us improve the system.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          isSubmitting
                              ? null
                              : () async {
                                final message = feedbackController.text.trim();
                                if (message.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter your feedback',
                                      ),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  return;
                                }

                                setState(() {
                                  isSubmitting = true;
                                });

                                try {
                                  final studentId =
                                      SessionService.currentUserStudentId;
                                  if (studentId.isEmpty) {
                                    throw Exception('Student ID not found');
                                  }

                                  final result =
                                      await SupabaseService.submitFeedback(
                                        userType: 'user',
                                        accountUsername: studentId,
                                        message: message,
                                      );

                                  if (result['success'] == true) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Thank you! Your feedback has been submitted successfully.',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    throw Exception(
                                      result['message'] ??
                                          'Failed to submit feedback',
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to submit feedback: $e',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                } finally {
                                  setState(() {
                                    isSubmitting = false;
                                  });
                                }
                              },
                      child:
                          isSubmitting
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Send Feedback'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showComingSoon(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('About Ecampuspay'),
            content: const Text(
              'eCampusPay is a campus-based e-wallet system that allows students to make payments using their school ID. Students can pay for campus services easily and securely with just a tap.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    // Store the original context to use for navigation after dialog closes
    final navigatorContext = context;

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    // Close the dialog first
                    Navigator.pop(dialogContext);

                    // Stop realtime notifications before clearing session
                    await RealtimeNotificationService.stopListening();

                    await SessionService.clearSession();

                    // Navigate to login page using root navigator to avoid context conflicts
                    Navigator.of(
                      navigatorContext,
                      rootNavigator: true,
                    ).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  } catch (e) {
                    print('Logout error: $e');
                    // Fallback navigation using root navigator
                    Navigator.of(
                      navigatorContext,
                      rootNavigator: true,
                    ).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _showKycInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('KYC Information'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your personal information is verified and managed by the administrator (KYC).',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                _buildKycRow('Name', SessionService.currentUserName),
                _buildKycRow('Student ID', SessionService.currentUserStudentId),
                _buildKycRow('Course', SessionService.currentUserCourse),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildKycRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNotificationSettingsDialog(BuildContext context) async {
    bool isSaving = false;
    bool enabled = await _getNotificationsEnabled();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Notification Settings'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Allow the app to send local notifications for transactions and updates.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Enable notifications'),
                          Switch(
                            value: enabled,
                            onChanged: (val) async {
                              setState(() => isSaving = true);
                              try {
                                await _setNotificationsEnabled(val);
                                enabled = val;
                                if (enabled) {
                                  await RealtimeNotificationService.initialize();
                                } else {
                                  await RealtimeNotificationService.stopListening();
                                }
                              } finally {
                                setState(() => isSaving = false);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (isSaving)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<bool> _getNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notifications_enabled') ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', enabled);
    } catch (_) {}
  }
}

class _MenuItem {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });
}

class _LoanPlansDialog extends StatelessWidget {
  final List<dynamic> plans;
  final double totalTopup;
  final Function(int) onApplyLoan;
  final VoidCallback? onLoanSubmitted;

  const _LoanPlansDialog({
    required this.plans,
    required this.totalTopup,
    required this.onApplyLoan,
    this.onLoanSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFB91C1C),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Available Loan Plans',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top-up info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your total top-up: ₱${totalTopup.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Loan plans
                    ...plans
                        .map((plan) => _buildLoanPlanCard(context, plan))
                        .toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanPlanCard(BuildContext context, Map<String, dynamic> plan) {
    final isEligible = plan['is_eligible'] as bool;
    final amount = (plan['amount'] as num).toDouble();
    final termDays = plan['term_days'] as int;
    final interestRate = (plan['interest_rate'] as num).toDouble();
    final totalRepayable = (plan['total_repayable'] as num).toDouble();
    final minTopup = (plan['min_topup'] as num).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan['name'] as String,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isEligible
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isEligible ? 'Eligible' : 'Not Eligible',
                    style: TextStyle(
                      color:
                          isEligible
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Amount',
                    '₱${amount.toStringAsFixed(2)}',
                  ),
                ),
                Expanded(child: _buildInfoItem('Term', '$termDays days')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Interest',
                    '${interestRate.toStringAsFixed(1)}%',
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Total Due',
                    '₱${totalRepayable.toStringAsFixed(2)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildInfoItem(
              'Min. Top-up Required',
              '₱${minTopup.toStringAsFixed(0)}',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    isEligible
                        ? () {
                          Navigator.pop(context); // Close dialog
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => LoanApplicationScreen(
                                    loanPlan: plan,
                                    onLoanSubmitted: onLoanSubmitted,
                                  ),
                            ),
                          ).then((_) async {
                            // Refresh loan data when returning from application screen
                            await SessionService.refreshUserData();
                            // Refresh active loans display via callback
                            onLoanSubmitted?.call();
                          });
                        }
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isEligible ? const Color(0xFFB91C1C) : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  isEligible ? 'Apply for this Loan' : 'Not Eligible',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            if (!isEligible) ...[
              const SizedBox(height: 8),
              Text(
                'You need at least ₱${minTopup.toStringAsFixed(0)} in total top-ups to apply for this loan.',
                style: TextStyle(fontSize: 12, color: Colors.red.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _showLoanAgreementDialog(
    BuildContext context, {
    required Map<String, dynamic> plan,
    required VoidCallback onConfirm,
  }) {
    bool agreed = false;
    final amount = (plan['amount'] as num?)?.toDouble() ?? 0.0;
    final interestRate = (plan['interest_rate'] as num?)?.toDouble() ?? 0.0;
    final totalRepayable =
        (plan['total_repayable'] as num?)?.toDouble() ??
        (amount + (amount * interestRate / 100));
    final termDays = (plan['term_days'] as num?)?.toInt();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: 500,
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Loan Agreement',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plan['name'] != null
                              ? plan['name'].toString()
                              : 'Selected Loan Plan',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Loan Amount: ₱${amount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Interest/Fee: ${interestRate.toStringAsFixed(1)}% (shown before you confirm)',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total Repayable: ₱${totalRepayable.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (termDays != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Repayment Term: $termDays days',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'By applying for a loan in eCampusPay, you agree to the following:\n\n'
                                  '• The loan amount will be added to your eCampusPay balance.\n'
                                  '• You must repay the loan on or before the due date shown.\n'
                                  '• Repayment includes the loan amount plus the interest/fee (shown before you confirm).\n'
                                  '• If you do not pay on time, your account may be restricted until payment is completed.\n'
                                  '• Only one active loan is allowed at a time.\n'
                                  '• The admin may adjust loan rules (amount, interest, or repayment days) when needed.\n\n'
                                  'Note: eCampusPay is a campus payment system, not a bank. Borrow responsibly.',
                                  style: TextStyle(fontSize: 13, height: 1.4),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Checkbox(
                                      value: agreed,
                                      onChanged:
                                          (v) => setState(
                                            () => agreed = v == true,
                                          ),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'I have read and agree to the Loan Terms and Conditions.',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    agreed
                                        ? () {
                                          Navigator.pop(context);
                                          onConfirm();
                                        }
                                        : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB91C1C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: const Text(
                                  'Apply Loan',
                                  style: TextStyle(fontWeight: FontWeight.w600),
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
}

class _PaymentOptionsDialog extends StatefulWidget {
  final Map<String, dynamic> loan;
  final VoidCallback onPayFull;
  final Function(double) onPayPartial;

  const _PaymentOptionsDialog({
    required this.loan,
    required this.onPayFull,
    required this.onPayPartial,
  });

  @override
  State<_PaymentOptionsDialog> createState() => _PaymentOptionsDialogState();
}

class _PaymentOptionsDialogState extends State<_PaymentOptionsDialog> {
  final TextEditingController _amountController = TextEditingController();
  bool _isPartialPayment = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = (widget.loan['total_amount'] as num).toDouble();
    final currentBalance = SessionService.currentUserBalance;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFB91C1C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.payment,
                    color: Color(0xFFB91C1C),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Payment Options',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Loan Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    'Total Due',
                    '₱${totalAmount.toStringAsFixed(2)}',
                  ),
                  _buildSummaryRow(
                    'Your Balance',
                    '₱${currentBalance.toStringAsFixed(2)}',
                  ),
                  const Divider(height: 16),
                  _buildSummaryRow(
                    'Can Pay Full',
                    currentBalance >= totalAmount ? 'Yes' : 'No',
                    valueColor:
                        currentBalance >= totalAmount
                            ? Colors.green
                            : Colors.red,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Payment Type Selection
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isPartialPayment = false),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            !_isPartialPayment
                                ? const Color(0xFFB91C1C)
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              !_isPartialPayment
                                  ? const Color(0xFFB91C1C)
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        'Pay Full',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              !_isPartialPayment
                                  ? Colors.white
                                  : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isPartialPayment = true),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            _isPartialPayment
                                ? const Color(0xFFB91C1C)
                                : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _isPartialPayment
                                  ? const Color(0xFFB91C1C)
                                  : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        'Pay Partial',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color:
                              _isPartialPayment
                                  ? Colors.white
                                  : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_isPartialPayment) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount to Pay',
                  hintText: 'Enter amount (₱)',
                  prefixText: '₱',
                  border: const OutlineInputBorder(),
                  errorText: _getAmountError(),
                ),
                onChanged: (value) => setState(() {}),
              ),
            ],

            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _canProceed() ? _handlePayment : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB91C1C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _isPartialPayment ? 'Pay Partial' : 'Pay Full',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String? _getAmountError() {
    if (!_isPartialPayment) return null;

    final amountText = _amountController.text;
    if (amountText.isEmpty) return null;

    final amount = double.tryParse(amountText);
    if (amount == null) return 'Invalid amount';

    final totalAmount = (widget.loan['total_amount'] as num).toDouble();
    final currentBalance = SessionService.currentUserBalance;

    if (amount <= 0) return 'Amount must be greater than 0';
    if (amount > totalAmount) return 'Amount cannot exceed total due';
    if (amount > currentBalance) return 'Insufficient balance';

    return null;
  }

  bool _canProceed() {
    if (!_isPartialPayment) {
      final totalAmount = (widget.loan['total_amount'] as num).toDouble();
      final currentBalance = SessionService.currentUserBalance;
      return currentBalance >= totalAmount;
    }

    return _getAmountError() == null && _amountController.text.isNotEmpty;
  }

  void _handlePayment() {
    if (_isPartialPayment) {
      final amount = double.tryParse(_amountController.text);
      if (amount != null) {
        widget.onPayPartial(amount);
      }
    } else {
      widget.onPayFull();
    }
  }
}

// Transfer Dialog Classes
class _TransferStudentIdDialog extends StatefulWidget {
  @override
  _TransferStudentIdDialogState createState() =>
      _TransferStudentIdDialogState();
}

class _TransferStudentIdDialogState extends State<_TransferStudentIdDialog> {
  final _studentIdController = TextEditingController();
  bool _isValidating = false;
  String? _recipientName;
  String? _recipientCourse;
  String? _validationError;

  @override
  void dispose() {
    _studentIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.person_add,
            color: const Color(0xFFB91C1C),
            size: isSmallScreen ? 20 : 24,
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Text(
              'Transfer Money',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the Student ID of the recipient:',
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            TextField(
              controller: _studentIdController,
              decoration: InputDecoration(
                labelText: 'Student ID',
                hintText: 'e.g., EVSU2024001',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.person),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  _validateStudentId(value.trim());
                } else {
                  setState(() {
                    _recipientName = null;
                    _recipientCourse = null;
                    _validationError = null;
                  });
                }
              },
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            if (_isValidating)
              Row(
                children: [
                  SizedBox(
                    width: isSmallScreen ? 14 : 16,
                    height: isSmallScreen ? 14 : 16,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Text(
                    'Validating...',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            if (_validationError != null)
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade600,
                      size: isSmallScreen ? 14 : 16,
                    ),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: isSmallScreen ? 11 : 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_recipientName != null)
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.green.shade600,
                          size: isSmallScreen ? 14 : 16,
                        ),
                        SizedBox(width: isSmallScreen ? 6 : 8),
                        Text(
                          'Recipient Found:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 11 : 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallScreen ? 4 : 6),
                    Text(
                      'Name: $_recipientName',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    if (_recipientCourse != null)
                      Text(
                        'Course: $_recipientCourse',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actionsPadding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      actions: [
        if (isSmallScreen)
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _recipientName != null && !_isValidating
                          ? () {
                            Navigator.pop(context);
                            _showAmountDialog(
                              context,
                              _studentIdController.text.trim(),
                              _recipientName!,
                            );
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed:
                      _recipientName != null && !_isValidating
                          ? () {
                            Navigator.pop(context);
                            _showAmountDialog(
                              context,
                              _studentIdController.text.trim(),
                              _recipientName!,
                            );
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _validateStudentId(String studentId) async {
    if (studentId == SessionService.currentUserStudentId) {
      setState(() {
        _validationError = 'Cannot transfer to yourself';
        _recipientName = null;
        _recipientCourse = null;
      });
      return;
    }

    setState(() {
      _isValidating = true;
      _validationError = null;
      _recipientName = null;
      _recipientCourse = null;
    });

    try {
      await SupabaseService.initialize();

      // Look up student in auth_students table
      final response =
          await SupabaseService.client
              .from('auth_students')
              .select('student_id, name, course')
              .eq('student_id', studentId)
              .eq('is_active', true)
              .maybeSingle();

      if (response == null) {
        setState(() {
          _validationError = 'Student ID not found or inactive';
          _recipientName = null;
          _recipientCourse = null;
        });
      } else {
        // Decrypt the student name and course
        String decryptedName = response['name']?.toString() ?? 'Unknown';
        String decryptedCourse = response['course']?.toString() ?? '';

        try {
          // Check if the name looks encrypted and decrypt it
          if (EncryptionService.looksLikeEncryptedData(decryptedName)) {
            decryptedName = EncryptionService.decryptData(decryptedName);
          }

          // Check if the course looks encrypted and decrypt it
          if (EncryptionService.looksLikeEncryptedData(decryptedCourse)) {
            decryptedCourse = EncryptionService.decryptData(decryptedCourse);
          }
        } catch (e) {
          print('Failed to decrypt student data: $e');
          // Keep the original values if decryption fails
        }

        setState(() {
          _recipientName = decryptedName;
          _recipientCourse =
              decryptedCourse.isNotEmpty ? decryptedCourse : null;
          _validationError = null;
        });
      }
    } catch (e) {
      setState(() {
        _validationError = 'Error validating student ID: $e';
        _recipientName = null;
        _recipientCourse = null;
      });
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }
}

class _AmountDialog extends StatefulWidget {
  final String recipientStudentId;
  final String recipientName;

  const _AmountDialog({
    required this.recipientStudentId,
    required this.recipientName,
  });

  @override
  _AmountDialogState createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _amountController = TextEditingController();
  double? _currentBalance;
  bool _isLoadingBalance = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentBalance() async {
    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserStudentId;

      final response =
          await SupabaseService.client
              .from('auth_students')
              .select('balance')
              .eq('student_id', studentId)
              .single();

      setState(() {
        _currentBalance = (response['balance'] as num?)?.toDouble() ?? 0.0;
        _isLoadingBalance = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingBalance = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.attach_money,
            color: const Color(0xFFB91C1C),
            size: isSmallScreen ? 20 : 24,
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Text(
              'Transfer Amount',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transferring to:',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    widget.recipientName,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 4 : 6),
                  Text(
                    'Student ID: ${widget.recipientStudentId}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            if (_isLoadingBalance)
              Row(
                children: [
                  SizedBox(
                    width: isSmallScreen ? 14 : 16,
                    height: isSmallScreen ? 14 : 16,
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Text(
                    'Loading balance...',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              )
            else
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFB91C1C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFB91C1C).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet,
                      color: const Color(0xFFB91C1C),
                      size: isSmallScreen ? 16 : 18,
                    ),
                    SizedBox(width: isSmallScreen ? 6 : 8),
                    Text(
                      'Your balance: ₱${_currentBalance?.toStringAsFixed(2) ?? '0.00'}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 13 : 14,
                        color: const Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount to Transfer',
                hintText: '0.00',
                prefixText: '₱',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.attach_money),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
              ),
              onChanged: (value) {
                setState(() {});
              },
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              'Quick Amount:',
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            Wrap(
              spacing: isSmallScreen ? 6 : 8,
              runSpacing: isSmallScreen ? 6 : 8,
              children: [
                _buildQuickAmountButton(50, isSmallScreen),
                _buildQuickAmountButton(100, isSmallScreen),
                _buildQuickAmountButton(200, isSmallScreen),
                _buildQuickAmountButton(500, isSmallScreen),
              ],
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            if (_amountController.text.isNotEmpty)
              _buildValidationMessage(isSmallScreen),
          ],
        ),
      ),
      actionsPadding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      actions: [
        if (isSmallScreen)
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canTransfer() ? _proceedToSummary : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _canTransfer() ? _proceedToSummary : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildQuickAmountButton(double amount, bool isSmallScreen) {
    final isSelected = _amountController.text == amount.toString();
    return GestureDetector(
      onTap: () {
        _amountController.text = amount.toString();
        setState(() {});
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isSmallScreen ? 10 : 12,
          vertical: isSmallScreen ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFB91C1C) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          '₱${amount.toStringAsFixed(0)}',
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: isSmallScreen ? 11 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildValidationMessage(bool isSmallScreen) {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade600,
              size: isSmallScreen ? 14 : 16,
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            Expanded(
              child: Text(
                'Please enter a valid amount',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: isSmallScreen ? 11 : 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_currentBalance != null && amount > _currentBalance!) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          border: Border.all(color: Colors.red.shade200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade600,
              size: isSmallScreen ? 14 : 16,
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            Expanded(
              child: Text(
                'Insufficient balance',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: isSmallScreen ? 11 : 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_currentBalance != null && amount > _currentBalance! - 0.01) {
      return Container(
        padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          border: Border.all(color: Colors.orange.shade200),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_outlined,
              color: Colors.orange.shade600,
              size: isSmallScreen ? 14 : 16,
            ),
            SizedBox(width: isSmallScreen ? 6 : 8),
            Expanded(
              child: Text(
                'Warning: This will leave minimal balance',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: isSmallScreen ? 11 : 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline,
            color: Colors.green.shade600,
            size: isSmallScreen ? 14 : 16,
          ),
          SizedBox(width: isSmallScreen ? 6 : 8),
          Expanded(
            child: Text(
              'Amount is valid',
              style: TextStyle(
                color: Colors.green.shade700,
                fontSize: isSmallScreen ? 11 : 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _canTransfer() {
    final amount = double.tryParse(_amountController.text);
    return amount != null &&
        amount > 0 &&
        _currentBalance != null &&
        amount <= _currentBalance!;
  }

  void _proceedToSummary() {
    final amount = double.parse(_amountController.text);
    Navigator.pop(context);
    _showTransferSummaryDialog(
      widget.recipientStudentId,
      widget.recipientName,
      amount,
    );
  }

  void _showTransferSummaryDialog(
    String recipientStudentId,
    String recipientName,
    double amount,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => _TransferSummaryDialog(
            recipientStudentId: recipientStudentId,
            recipientName: recipientName,
            amount: amount,
            currentBalance: _currentBalance!,
          ),
    );
  }
}

class _TransferSummaryDialog extends StatefulWidget {
  final String recipientStudentId;
  final String recipientName;
  final double amount;
  final double currentBalance;

  const _TransferSummaryDialog({
    required this.recipientStudentId,
    required this.recipientName,
    required this.amount,
    required this.currentBalance,
  });

  @override
  _TransferSummaryDialogState createState() => _TransferSummaryDialogState();
}

class _TransferSummaryDialogState extends State<_TransferSummaryDialog> {
  bool _isProcessing = false;

  /// Get current Philippines time (UTC+8) as ISO 8601 string
  /// This stores the timestamp with +8 hours offset so it represents Philippines local time
  static String _getPhilippinesTimeISO() {
    // Get current time in UTC
    final nowUtc = DateTime.now().toUtc();
    // Add 8 hours to represent Philippines time
    final phTime = nowUtc.add(const Duration(hours: 8));
    // Format as ISO 8601 with explicit timezone offset +08:00
    // This tells the database this is Philippines time, which it will convert to UTC for storage
    return phTime.toIso8601String().replaceFirst('Z', '+08:00');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.receipt_long,
            color: const Color(0xFFB91C1C),
            size: isSmallScreen ? 20 : 24,
          ),
          SizedBox(width: isSmallScreen ? 8 : 12),
          Expanded(
            child: Text(
              'Transfer Summary',
              style: TextStyle(
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.grey.shade50, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please review your transfer details:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isSmallScreen ? 14 : 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  _buildSummaryRow(
                    'Recipient:',
                    widget.recipientName,
                    isSmallScreen: isSmallScreen,
                  ),
                  _buildSummaryRow(
                    'Student ID:',
                    widget.recipientStudentId,
                    isSmallScreen: isSmallScreen,
                  ),
                  const Divider(height: 20),
                  _buildSummaryRow(
                    'Amount:',
                    '₱${widget.amount.toStringAsFixed(2)}',
                    isSmallScreen: isSmallScreen,
                    isAmount: true,
                  ),
                  _buildSummaryRow(
                    'Current Balance:',
                    '₱${widget.currentBalance.toStringAsFixed(2)}',
                    isSmallScreen: isSmallScreen,
                  ),
                  _buildSummaryRow(
                    'New Balance:',
                    '₱${(widget.currentBalance - widget.amount).toStringAsFixed(2)}',
                    isSmallScreen: isSmallScreen,
                    isNewBalance: true,
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade600,
                    size: isSmallScreen ? 16 : 18,
                  ),
                  SizedBox(width: isSmallScreen ? 6 : 8),
                  Expanded(
                    child: Text(
                      'This transaction will be recorded in your transaction history.',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actionsPadding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      actions: [
        if (isSmallScreen)
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isProcessing
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text(
                            'Confirm Transfer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed:
                      _isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed:
                      _isProcessing ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _processTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB91C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      _isProcessing
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                          : const Text(
                            'Confirm Transfer',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isSmallScreen = false,
    bool isAmount = false,
    bool isNewBalance = false,
  }) {
    Color valueColor = Colors.black87;
    if (isAmount) {
      valueColor = const Color(0xFFB91C1C);
    } else if (isNewBalance) {
      valueColor = Colors.green.shade700;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 3 : 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Flexible(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isSmallScreen ? 13 : 14,
                color: valueColor,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processTransfer() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      await SupabaseService.initialize();
      final senderStudentId = SessionService.currentUserStudentId;

      // Try using the database function first
      try {
        final result = await SupabaseService.client.rpc(
          'process_user_transfer',
          params: {
            'p_sender_student_id': senderStudentId,
            'p_recipient_student_id': widget.recipientStudentId,
            'p_amount': widget.amount,
          },
        );

        if (result != null) {
          final data = result as Map<String, dynamic>;

          if (data['success'] == true) {
            // Close all dialogs first
            Navigator.pop(context);

            // Show success message immediately
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Successfully transferred ₱${widget.amount.toStringAsFixed(2)} to ${widget.recipientName}',
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 4),
                ),
              );
            }

            // Refresh user data
            await SessionService.refreshUserData();

            // Force refresh the entire dashboard
            if (mounted) {
              // Trigger a rebuild of the entire dashboard
              setState(() {});

              // Also refresh the transactions tab if it exists
              // This will be handled by the parent widget's setState
            }
            return;
          } else {
            throw Exception(
              data['message'] ?? data['error'] ?? 'Transfer failed',
            );
          }
        }
      } catch (rpcError) {
        print('RPC function failed, trying manual transfer: $rpcError');
        // Fall through to manual implementation
      }

      // Fallback: Manual transfer implementation
      await _processTransferManually(senderStudentId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transfer failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processTransferManually(String senderStudentId) async {
    // Get current balances with retry logic
    Map<String, dynamic>? senderResponse;
    Map<String, dynamic>? recipientResponse;

    try {
      senderResponse =
          await SupabaseService.client
              .from('auth_students')
              .select('balance')
              .eq('student_id', senderStudentId)
              .eq('is_active', true)
              .single();

      recipientResponse =
          await SupabaseService.client
              .from('auth_students')
              .select('balance')
              .eq('student_id', widget.recipientStudentId)
              .eq('is_active', true)
              .single();
    } catch (e) {
      throw Exception('Failed to fetch user balances: $e');
    }

    final senderBalance =
        (senderResponse['balance'] as num?)?.toDouble() ?? 0.0;
    final recipientBalance =
        (recipientResponse['balance'] as num?)?.toDouble() ?? 0.0;

    // Check if sender has sufficient balance
    if (senderBalance < widget.amount) {
      throw Exception(
        'Insufficient balance. Available: ₱${senderBalance.toStringAsFixed(2)}, Required: ₱${widget.amount.toStringAsFixed(2)}',
      );
    }

    // Calculate new balances
    final newSenderBalance = senderBalance - widget.amount;
    final newRecipientBalance = recipientBalance + widget.amount;

    try {
      // Update sender balance using atomic increment/decrement
      final senderUpdateResult =
          await SupabaseService.client
              .from('auth_students')
              .update({
                'balance': newSenderBalance,
                'updated_at': _getPhilippinesTimeISO(),
              })
              .eq('student_id', senderStudentId)
              .eq('balance', senderBalance) // Ensure balance hasn't changed
              .select();

      if (senderUpdateResult.isEmpty) {
        throw Exception(
          'Sender balance was modified by another transaction. Please try again.',
        );
      }

      // Update recipient balance
      await SupabaseService.client
          .from('auth_students')
          .update({
            'balance': newRecipientBalance,
            'updated_at': _getPhilippinesTimeISO(),
          })
          .eq('student_id', widget.recipientStudentId);

      // Create transfer record (if table exists)
      try {
        await SupabaseService.client.from('user_transfers').insert({
          'sender_student_id': senderStudentId,
          'recipient_student_id': widget.recipientStudentId,
          'amount': widget.amount,
          'sender_previous_balance': senderBalance,
          'sender_new_balance': newSenderBalance,
          'recipient_previous_balance': recipientBalance,
          'recipient_new_balance': newRecipientBalance,
          'transaction_type': 'transfer',
          'status': 'completed',
          'notes': 'User-to-user transfer',
          'created_at': _getPhilippinesTimeISO(),
        });
        print(
          'DEBUG: Transfer record created successfully in user_transfers table',
        );
      } catch (transferRecordError) {
        print(
          'Could not create transfer record (table might not exist): $transferRecordError',
        );

        // Fallback: Try to create a simple record in a different table or store locally
        try {
          // Try to insert into a generic transactions table if it exists
          await SupabaseService.client.from('transactions').insert({
            'student_id': senderStudentId,
            'type': 'transfer_out',
            'amount': widget.amount,
            'description': 'Transfer to ${widget.recipientStudentId}',
            'balance_after': newSenderBalance,
            'created_at': _getPhilippinesTimeISO(),
          });

          await SupabaseService.client.from('transactions').insert({
            'student_id': widget.recipientStudentId,
            'type': 'transfer_in',
            'amount': widget.amount,
            'description': 'Transfer from $senderStudentId',
            'balance_after': newRecipientBalance,
            'created_at': _getPhilippinesTimeISO(),
          });

          print('DEBUG: Transfer recorded in fallback transactions table');
        } catch (fallbackError) {
          print(
            'DEBUG: Fallback transfer recording also failed: $fallbackError',
          );
          // Continue anyway - the main transfer is successful
        }
      }

      // Create notifications for both sender and recipient
      try {
        // Notification for sender
        await NotificationService.createNotification(
          studentId: senderStudentId,
          type: 'transfer_sent',
          title: 'Transfer Sent',
          message:
              'You sent ₱${widget.amount.toStringAsFixed(2)} to ${widget.recipientName}',
          actionData: 'transfer_id:${DateTime.now().millisecondsSinceEpoch}',
        );

        // Notification for recipient
        await NotificationService.createNotification(
          studentId: widget.recipientStudentId,
          type: 'transfer_received',
          title: 'Transfer Received',
          message:
              'You received ₱${widget.amount.toStringAsFixed(2)} from ${SessionService.currentUserData?['name'] ?? 'User'}',
          actionData: 'transfer_id:${DateTime.now().millisecondsSinceEpoch}',
        );
      } catch (notificationError) {
        print('Error creating transfer notifications: $notificationError');
        // Don't fail the transfer if notifications fail
      }

      // Close all dialogs first
      Navigator.pop(context);

      // Show success message immediately
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully transferred ₱${widget.amount.toStringAsFixed(2)} to ${widget.recipientName}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Refresh user data
      await SessionService.refreshUserData();

      // Force refresh the entire dashboard
      if (mounted) {
        // Trigger a rebuild of the entire dashboard
        setState(() {});

        // This will refresh all tabs including transactions
        print('DEBUG: Dashboard refreshed after transfer completion');
      }
    } catch (e) {
      // If we failed to update sender balance, we need to try to revert recipient balance
      if (e.toString().contains('Sender balance was modified')) {
        try {
          await SupabaseService.client
              .from('auth_students')
              .update({
                'balance': recipientBalance, // Revert recipient balance
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('student_id', widget.recipientStudentId);
        } catch (revertError) {
          print('Failed to revert recipient balance: $revertError');
        }
      }
      throw e;
    }
  }
}

// Helper function to show amount dialog
void _showAmountDialog(
  BuildContext context,
  String studentId,
  String recipientName,
) {
  showDialog(
    context: context,
    builder:
        (context) => _AmountDialog(
          recipientStudentId: studentId,
          recipientName: recipientName,
        ),
  );
}
