import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

/// Service for managing admin notifications using Flutter Local Notifications
/// and Supabase Realtime subscriptions with polling fallback.
///
/// This service:
/// 1. Initializes Flutter Local Notifications for admin
/// 2. Subscribes to INSERT events on top_up_requests and withdrawal_requests
/// 3. Falls back to polling if Realtime doesn't work
/// 4. Shows notifications when new pending requests are created
/// 5. Tracks processed request IDs to avoid duplicate notifications
class AdminNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static bool _notificationsEnabled = true;

  // Realtime stream subscriptions
  static StreamSubscription<List<Map<String, dynamic>>>?
  _topUpRequestsSubscription;
  static StreamSubscription<List<Map<String, dynamic>>>?
  _withdrawalRequestsSubscription;

  // Polling timers (fallback if Realtime doesn't work)
  static Timer? _topUpPollingTimer;
  static Timer? _withdrawalPollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 10);

  // Track processed request IDs to avoid duplicate notifications
  // These are cleared when subscriptions are restarted
  static final Set<String> _processedTopUpRequestIds = {};
  static final Set<String> _processedWithdrawalRequestIds = {};

  // Track subscription start time to only notify for new records
  static DateTime? _subscriptionStartTime;

  // Track if Realtime is working
  static bool _realtimeWorking = false;

  // Track last check time for polling
  static DateTime? _lastTopUpCheck;
  static DateTime? _lastWithdrawalCheck;

  /// Initialize the admin notification service
  /// This should be called when admin dashboard opens
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('🔔 DEBUG: AdminNotificationService already initialized');
      return;
    }

    try {
      print('🔔 DEBUG: Initializing AdminNotificationService...');

      // Initialize Flutter Local Notifications
      await _initializeLocalNotifications();

      // Initialize Supabase if not already initialized
      await SupabaseService.initialize();
      // Removed automatic test notification to avoid non-actionable alerts for admins.
      // Use AdminNotificationService.showAdminNotification or manual testers if needed.

      _isInitialized = true;
      print('🔔 DEBUG: AdminNotificationService initialized successfully');
    } catch (e, stackTrace) {
      print('❌ ERROR: Failed to initialize AdminNotificationService: $e');
      print('❌ ERROR: Stack trace: $stackTrace');
    }
  }

  /// Returns whether admin notifications are enabled
  static bool getNotificationsEnabled() {
    return _notificationsEnabled;
  }

  /// Enable or disable admin notifications.
  /// When enabling, starts listeners; when disabling, stops them.
  static Future<void> setNotificationsEnabled(bool enabled) async {
    if (_notificationsEnabled == enabled) return;
    _notificationsEnabled = enabled;
    print('🔔 DEBUG: Admin notifications enabled = $enabled');
    if (enabled) {
      await startListening();
    } else {
      await stopListening();
    }
  }

  /// Initialize Flutter Local Notifications plugin
  static Future<void> _initializeLocalNotifications() async {
    try {
      // Android initialization settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization settings
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
            requestAlertPermission: true,
            requestBadgePermission: true,
            requestSoundPermission: true,
          );

      // Initialization settings
      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize the plugin
      final bool? initialized = await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTapped,
      );

      if (initialized == true) {
        print('DEBUG: Admin local notifications initialized successfully');

        // Request permissions for Android 13+
        await _requestAndroidPermissions();
      } else {
        print(
          'WARNING: Admin local notifications initialization returned false',
        );
      }
    } catch (e) {
      print('ERROR: Failed to initialize admin local notifications: $e');
    }
  }

  /// Request Android notification permissions (Android 13+)
  static Future<void> _requestAndroidPermissions() async {
    try {
      final androidPlugin =
          _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        final bool? granted =
            await androidPlugin.requestNotificationsPermission();
        print('DEBUG: Admin Android notification permission granted: $granted');
      }
    } catch (e) {
      print('ERROR: Failed to request Android permissions: $e');
      // Continue even if permission request fails - notifications might still work
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('DEBUG: Admin notification tapped: ${response.payload}');
    // You can navigate to specific pages based on payload here
    // For now, we'll just log it
  }

  /// Start listening to top_up_requests table
  static Future<void> startListeningToTopUpRequests() async {
    try {
      print('🔔 DEBUG: Starting to listen to top_up_requests...');
      if (!_notificationsEnabled) {
        print(
          '🔔 DEBUG: Notifications disabled; will not start top_up_requests listener.',
        );
        return;
      }

      // Cancel existing subscription if any
      await _topUpRequestsSubscription?.cancel();
      _topUpPollingTimer?.cancel();

      // Note: subscription start time is set in startListening() method
      // If called individually, set it here
      if (_subscriptionStartTime == null) {
        _subscriptionStartTime = DateTime.now();
      }

      // Clear processed IDs when starting new subscription
      _processedTopUpRequestIds.clear();
      _lastTopUpCheck = DateTime.now();

      final client = SupabaseService.client;

      // Try Realtime subscription first
      try {
        print(
          '🔔 DEBUG: Attempting Realtime subscription for top_up_requests...',
        );
        _topUpRequestsSubscription = client
            .from('top_up_requests')
            .stream(primaryKey: ['id'])
            .eq('status', 'Pending Verification')
            .listen(
              (rows) {
                print(
                  '🔔 DEBUG: Realtime stream received ${rows.length} top-up requests',
                );
                _realtimeWorking = true;

                int newRequestsCount = 0;
                for (final row in rows) {
                  final id = row['id']?.toString();
                  final status = row['status']?.toString();
                  final amount = row['amount'];

                  // Only process if we haven't seen this ID before
                  // and if status is 'Pending Verification'
                  if (id != null && status == 'Pending Verification') {
                    if (!_processedTopUpRequestIds.contains(id)) {
                      _processedTopUpRequestIds.add(id);
                      newRequestsCount++;
                      print(
                        '🔔 DEBUG: ✅ NEW top-up request detected via Realtime: ID=$id, Amount=$amount',
                      );
                      // Handle async without blocking the stream
                      _handleTopUpRequest(row);
                    } else {
                      print(
                        '🔔 DEBUG: ⏭️  Skipping already processed top-up request: ID=$id',
                      );
                    }
                  } else {
                    if (status != 'Pending Verification') {
                      print(
                        '🔔 DEBUG: ⚠️  Request ID=$id has status "$status" (expected "Pending Verification"), skipping',
                      );
                    }
                  }
                }

                if (newRequestsCount > 0) {
                  print(
                    '🔔 DEBUG: ✅ Processed $newRequestsCount new top-up request(s) via Realtime',
                  );
                }
              },
              onError: (error) {
                print(
                  '❌ ERROR: Top-up requests Realtime subscription error: $error',
                );
                _realtimeWorking = false;
                // Fall back to polling if Realtime fails
                _startTopUpPolling();
              },
              onDone: () {
                print('⚠️ WARNING: Top-up requests Realtime stream closed');
                _realtimeWorking = false;
                // Fall back to polling if stream closes
                _startTopUpPolling();
              },
            );

        print('🔔 DEBUG: ✅ Realtime subscription started for top_up_requests');

        // Also start polling as a backup (checks less frequently)
        // Polling will run in parallel to catch any requests Realtime might miss
        print('🔔 DEBUG: Starting polling as backup for top_up_requests...');
        _startTopUpPolling();
      } catch (realtimeError, realtimeStackTrace) {
        print('❌ ERROR: Realtime subscription failed: $realtimeError');
        print('❌ ERROR: Realtime stack trace: $realtimeStackTrace');
        print('🔄 DEBUG: Falling back to polling only for top_up_requests...');
        _realtimeWorking = false;
        _startTopUpPolling();
      }
    } catch (e, stackTrace) {
      print('❌ ERROR: Failed to start listening to top_up_requests: $e');
      print('❌ ERROR: Stack trace: $stackTrace');
      print('🔄 DEBUG: Falling back to polling only for top_up_requests...');
      // Fall back to polling
      _startTopUpPolling();
    }
  }

  /// Start polling for top-up requests (fallback if Realtime doesn't work)
  static void _startTopUpPolling() {
    _topUpPollingTimer?.cancel();
    print(
      '🔔 DEBUG: Starting polling for top-up requests (every ${_pollingInterval.inSeconds}s)',
    );
    print('🔔 DEBUG: Polling will check for status = "Pending Verification"');
    if (!_notificationsEnabled) {
      print('🔔 DEBUG: Notifications disabled; skipping top-up polling start.');
      return;
    }

    // Do initial poll immediately (with a small delay to ensure initialization is complete)
    Future.delayed(const Duration(seconds: 2), () {
      print('🔔 DEBUG: Running initial poll for top-up requests...');
      _pollTopUpRequests();
    });

    _topUpPollingTimer = Timer.periodic(_pollingInterval, (timer) async {
      try {
        print('🔔 DEBUG: Periodic poll triggered for top-up requests');
        await _pollTopUpRequests();
      } catch (e, stackTrace) {
        print('❌ ERROR: Polling error for top-up requests: $e');
        print('❌ ERROR: Stack trace: $stackTrace');
      }
    });

    print('🔔 DEBUG: ✅ Top-up polling timer started');
  }

  /// Poll for new top-up requests
  static Future<void> _pollTopUpRequests() async {
    try {
      print('🔔 DEBUG: Polling for new top-up requests...');
      if (!_notificationsEnabled) {
        print('🔔 DEBUG: Notifications disabled; skipping top-up poll.');
        return;
      }
      print(
        '🔔 DEBUG: Processed IDs count: ${_processedTopUpRequestIds.length}',
      );
      final client = SupabaseService.client;

      // First, test if we can query the table at all
      try {
        final testQuery = await client
            .from('top_up_requests')
            .select('id')
            .limit(1);
        print(
          '🔔 DEBUG: ✅ Can query top_up_requests table (found ${testQuery.length} rows in test)',
        );
      } catch (testError) {
        print('❌ ERROR: Cannot query top_up_requests table: $testError');
        print(
          '❌ ERROR: This might be an RLS policy issue. Check database permissions.',
        );
        return;
      }

      final response = await client
          .from('top_up_requests')
          .select('id, status, amount, created_at')
          .eq('status', 'Pending Verification')
          .order('created_at', ascending: false)
          .limit(50);

      print('🔔 DEBUG: Poll found ${response.length} pending top-up requests');

      if (response.isEmpty) {
        print('🔔 DEBUG: No pending top-up requests found in database');
        _lastTopUpCheck = DateTime.now();
        return;
      }

      // Log all found requests for debugging
      print('🔔 DEBUG: Found requests:');
      for (final row in response) {
        final id = row['id']?.toString();
        final status = row['status']?.toString();
        final amount = row['amount'];
        print(
          '🔔 DEBUG:   - ID: $id, Status: $status, Amount: $amount, Processed: ${_processedTopUpRequestIds.contains(id)}',
        );
      }

      // Process new requests
      int newRequestsCount = 0;
      for (final row in response) {
        final id = row['id']?.toString();
        final status = row['status']?.toString();

        if (id != null && status == 'Pending Verification') {
          if (!_processedTopUpRequestIds.contains(id)) {
            _processedTopUpRequestIds.add(id);
            newRequestsCount++;
            print(
              '🔔 DEBUG: ✅ NEW top-up request detected via polling: ID=$id, Amount=${row['amount']}',
            );
            _handleTopUpRequest(row);
          } else {
            print(
              '🔔 DEBUG: ⏭️  Skipping already processed top-up request: ID=$id',
            );
          }
        } else {
          if (id == null) {
            print('🔔 DEBUG: ⚠️  Request has null ID, skipping');
          } else if (status != 'Pending Verification') {
            print(
              '🔔 DEBUG: ⚠️  Request ID=$id has status "$status" (expected "Pending Verification"), skipping',
            );
          }
        }
      }

      if (newRequestsCount > 0) {
        print('🔔 DEBUG: ✅ Processed $newRequestsCount new top-up request(s)');
      } else {
        print('🔔 DEBUG: No new top-up requests to process');
      }

      _lastTopUpCheck = DateTime.now();
    } catch (e, stackTrace) {
      print('❌ ERROR: Failed to poll top-up requests: $e');
      print('❌ ERROR: Stack trace: $stackTrace');
    }
  }

  /// Start listening to withdrawal_requests table
  static Future<void> startListeningToWithdrawalRequests() async {
    try {
      print('🔔 DEBUG: Starting to listen to withdrawal_requests...');
      if (!_notificationsEnabled) {
        print(
          '🔔 DEBUG: Notifications disabled; will not start withdrawal_requests listener.',
        );
        return;
      }

      // Cancel existing subscription if any
      await _withdrawalRequestsSubscription?.cancel();
      _withdrawalPollingTimer?.cancel();

      // Note: subscription start time is set in startListening() method
      // If called individually, set it here
      if (_subscriptionStartTime == null) {
        _subscriptionStartTime = DateTime.now();
      }

      // Clear processed IDs when starting new subscription
      _processedWithdrawalRequestIds.clear();
      _lastWithdrawalCheck = DateTime.now();

      final client = SupabaseService.client;

      // Try Realtime subscription first
      try {
        print(
          '🔔 DEBUG: Attempting Realtime subscription for withdrawal_requests...',
        );
        _withdrawalRequestsSubscription = client
            .from('withdrawal_requests')
            .stream(primaryKey: ['id'])
            .eq('status', 'Pending')
            .listen(
              (rows) {
                print(
                  '🔔 DEBUG: Realtime stream received ${rows.length} withdrawal requests',
                );
                _realtimeWorking = true;

                for (final row in rows) {
                  final id = row['id']?.toString();
                  final status = row['status']?.toString();

                  // Only process if we haven't seen this ID before
                  // and if status is 'Pending' (exact match as per database schema)
                  if (id != null &&
                      !_processedWithdrawalRequestIds.contains(id) &&
                      status == 'Pending') {
                    _processedWithdrawalRequestIds.add(id);
                    print(
                      '🔔 DEBUG: ✅ New withdrawal request detected via Realtime: $id',
                    );
                    // Handle async without blocking the stream
                    _handleWithdrawalRequest(row);
                  }
                }
              },
              onError: (error) {
                print(
                  '❌ ERROR: Withdrawal requests Realtime subscription error: $error',
                );
                _realtimeWorking = false;
                // Fall back to polling if Realtime fails
                _startWithdrawalPolling();
              },
              onDone: () {
                print('⚠️ WARNING: Withdrawal requests Realtime stream closed');
                _realtimeWorking = false;
                // Fall back to polling if stream closes
                _startWithdrawalPolling();
              },
            );

        print(
          '🔔 DEBUG: ✅ Realtime subscription started for withdrawal_requests',
        );

        // Also start polling as a backup (checks less frequently)
        _startWithdrawalPolling();
      } catch (realtimeError) {
        print('❌ ERROR: Realtime subscription failed: $realtimeError');
        print('🔄 DEBUG: Falling back to polling for withdrawal_requests...');
        _realtimeWorking = false;
        _startWithdrawalPolling();
      }
    } catch (e, stackTrace) {
      print('❌ ERROR: Failed to start listening to withdrawal_requests: $e');
      print('❌ ERROR: Stack trace: $stackTrace');
      // Fall back to polling
      _startWithdrawalPolling();
    }
  }

  /// Start polling for withdrawal requests (fallback if Realtime doesn't work)
  static void _startWithdrawalPolling() {
    _withdrawalPollingTimer?.cancel();
    print(
      '🔔 DEBUG: Starting polling for withdrawal requests (every ${_pollingInterval.inSeconds}s)',
    );
    if (!_notificationsEnabled) {
      print(
        '🔔 DEBUG: Notifications disabled; skipping withdrawal polling start.',
      );
      return;
    }

    _withdrawalPollingTimer = Timer.periodic(_pollingInterval, (timer) async {
      try {
        await _pollWithdrawalRequests();
      } catch (e) {
        print('❌ ERROR: Polling error for withdrawal requests: $e');
      }
    });

    // Do initial poll immediately
    _pollWithdrawalRequests();
  }

  /// Poll for new withdrawal requests
  static Future<void> _pollWithdrawalRequests() async {
    try {
      print('🔔 DEBUG: Polling for new withdrawal requests...');
      if (!_notificationsEnabled) {
        print('🔔 DEBUG: Notifications disabled; skipping withdrawal poll.');
        return;
      }
      final client = SupabaseService.client;

      final response = await client
          .from('withdrawal_requests')
          .select('id, status, amount, created_at')
          .eq('status', 'Pending')
          .order('created_at', ascending: false)
          .limit(50);

      print(
        '🔔 DEBUG: Poll found ${response.length} pending withdrawal requests',
      );

      // Process new requests
      for (final row in response) {
        final id = row['id']?.toString();
        final status = row['status']?.toString();

        if (id != null &&
            !_processedWithdrawalRequestIds.contains(id) &&
            status == 'Pending') {
          _processedWithdrawalRequestIds.add(id);
          print('🔔 DEBUG: ✅ New withdrawal request detected via polling: $id');
          _handleWithdrawalRequest(row);
        }
      }

      _lastWithdrawalCheck = DateTime.now();
    } catch (e) {
      print('❌ ERROR: Failed to poll withdrawal requests: $e');
    }
  }

  /// Handle new top-up request
  static Future<void> _handleTopUpRequest(Map<String, dynamic> request) async {
    try {
      final id = request['id']?.toString() ?? 'Unknown';
      final amount = (request['amount'] as num?)?.toDouble() ?? 0.0;

      print(
        '🔔 DEBUG: Handling top-up request notification: ID=$id, Amount=₱${amount.toStringAsFixed(2)}',
      );

      await showAdminNotification(
        title: 'New Top-Up Request',
        body:
            'A student has requested a top-up of ₱${amount.toStringAsFixed(2)}. Please review the request.',
        payload: 'top_up_request:$id',
      );

      print(
        '🔔 DEBUG: ✅ Top-up notification sent successfully for request ID=$id',
      );
    } catch (e, stackTrace) {
      print('❌ ERROR: Failed to handle top-up request: $e');
      print('❌ ERROR: Stack trace: $stackTrace');
    }
  }

  /// Handle new withdrawal request
  static Future<void> _handleWithdrawalRequest(
    Map<String, dynamic> request,
  ) async {
    try {
      final amount = (request['amount'] as num?)?.toDouble() ?? 0.0;

      await showAdminNotification(
        title: 'New Withdrawal Request',
        body:
            'A student has submitted a withdrawal request of ₱${amount.toStringAsFixed(2)}. Approval is needed.',
        payload: 'withdrawal_request:${request['id']}',
      );
    } catch (e) {
      print('ERROR: Failed to handle withdrawal request: $e');
    }
  }

  /// Show a notification to the admin
  /// This is a shared helper function that can be used by both tabs
  static Future<void> showAdminNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      if (!_notificationsEnabled) {
        print(
          '🔔 DEBUG: Notifications disabled; not showing admin notification: $title',
        );
        return;
      }
      // Android notification details
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'admin_notifications',
            'Admin Notifications',
            channelDescription: 'Notifications for admin about new requests',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            enableVibration: true,
            playSound: true,
          );

      // iOS notification details
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      // Notification details
      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // Generate a unique notification ID based on timestamp
      final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;

      // Show the notification
      await _notificationsPlugin.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );

      print('🔔 DEBUG: ✅ Admin notification shown: $title - $body');
    } catch (e, stackTrace) {
      print('❌ ERROR: Failed to show admin notification: $e');
      print('❌ ERROR: Stack trace: $stackTrace');
      // Check if it's a permission error
      if (e.toString().contains('permission') ||
          e.toString().contains('Permission')) {
        print(
          '⚠️ WARNING: Notification permissions might not be granted. Please check app settings.',
        );
      }
    }
  }

  /// Stop listening to all subscriptions
  static Future<void> stopListening() async {
    try {
      print('🔔 DEBUG: Stopping all admin notification listeners...');
      await _topUpRequestsSubscription?.cancel();
      await _withdrawalRequestsSubscription?.cancel();
      _topUpPollingTimer?.cancel();
      _withdrawalPollingTimer?.cancel();
      _topUpRequestsSubscription = null;
      _withdrawalRequestsSubscription = null;
      _topUpPollingTimer = null;
      _withdrawalPollingTimer = null;
      print('🔔 DEBUG: Stopped listening to admin notifications');
    } catch (e) {
      print('❌ ERROR: Failed to stop listening: $e');
    }
  }

  /// Stop listening to top-up requests only
  static Future<void> stopListeningToTopUpRequests() async {
    try {
      await _topUpRequestsSubscription?.cancel();
      _topUpRequestsSubscription = null;
      print('DEBUG: Stopped listening to top_up_requests');
    } catch (e) {
      print('ERROR: Failed to stop listening to top_up_requests: $e');
    }
  }

  /// Stop listening to withdrawal requests only
  static Future<void> stopListeningToWithdrawalRequests() async {
    try {
      await _withdrawalRequestsSubscription?.cancel();
      _withdrawalRequestsSubscription = null;
      print('DEBUG: Stopped listening to withdrawal_requests');
    } catch (e) {
      print('ERROR: Failed to stop listening to withdrawal_requests: $e');
    }
  }

  /// Start listening to all admin notifications (both top-up and withdrawal requests)
  /// This should be called when admin dashboard opens
  static Future<void> startListening() async {
    try {
      // Initialize if not already done
      await initialize();

      // Set subscription start time once before starting both subscriptions
      // This ensures both use the same timestamp for filtering old records
      _subscriptionStartTime = DateTime.now();

      // Clear processed IDs
      _processedTopUpRequestIds.clear();
      _processedWithdrawalRequestIds.clear();

      // Start both subscriptions
      await startListeningToTopUpRequests();
      await startListeningToWithdrawalRequests();

      print('🔔 DEBUG: ✅ Started listening to all admin notifications');
      print('🔔 DEBUG: Realtime status: $_realtimeWorking');
      print(
        '🔔 DEBUG: Polling fallback: Active (every ${_pollingInterval.inSeconds}s)',
      );
    } catch (e, stackTrace) {
      print('❌ ERROR: Failed to start listening to admin notifications: $e');
      print('❌ ERROR: Stack trace: $stackTrace');
    }
  }

  /// Restart listening (useful when re-initializing)
  static Future<void> restartListening() async {
    try {
      await stopListening();
      await startListening();
      print('🔔 DEBUG: Restarted listening to admin notifications');
    } catch (e, stackTrace) {
      print('❌ ERROR: Failed to restart listening to admin notifications: $e');
      print('❌ ERROR: Stack trace: $stackTrace');
    }
  }

  /// Get current status of notification service
  static Map<String, dynamic> getStatus() {
    return {
      'initialized': _isInitialized,
      'realtime_working': _realtimeWorking,
      'top_up_processed_count': _processedTopUpRequestIds.length,
      'withdrawal_processed_count': _processedWithdrawalRequestIds.length,
      'polling_active':
          _topUpPollingTimer?.isActive == true ||
          _withdrawalPollingTimer?.isActive == true,
      'last_top_up_check': _lastTopUpCheck?.toIso8601String(),
      'last_withdrawal_check': _lastWithdrawalCheck?.toIso8601String(),
    };
  }

  /// Manually trigger a poll check (for testing/debugging)
  static Future<void> manualPollCheck() async {
    print('🔔 DEBUG: Manual poll check triggered');
    await _pollTopUpRequests();
    await _pollWithdrawalRequests();
  }

  /// Clear processed IDs (for testing - allows re-notification of existing requests)
  static void clearProcessedIds() {
    print('🔔 DEBUG: Clearing processed request IDs');
    _processedTopUpRequestIds.clear();
    _processedWithdrawalRequestIds.clear();
    print(
      '🔔 DEBUG: Processed IDs cleared. Next poll will check all requests.',
    );
  }
}
