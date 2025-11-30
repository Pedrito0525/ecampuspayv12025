import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'session_service.dart';
import 'username_storage_service.dart';

/// Service for managing real-time notifications using Flutter Local Notifications
/// and Supabase Realtime subscriptions.
///
/// This service:
/// 1. Checks for saved student_id from SessionService or UsernameStorageService
/// 2. Initializes Flutter Local Notifications
/// 3. Subscribes to INSERT events on top_up_transactions, service_transactions, user_transfers, withdrawal_requests
/// 4. Matches student_id and shows notifications when matches are found
/// 5. Continues listening while app is running
/// 6. Stops when app is closed
class RealtimeNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;
  static bool _isListening = false;
  static String? _currentStudentId;

  // Realtime stream subscriptions
  static StreamSubscription<List<Map<String, dynamic>>>? _topUpSubscription;
  static StreamSubscription<List<Map<String, dynamic>>>? _serviceTxSubscription;
  static StreamSubscription<List<Map<String, dynamic>>>?
  _userTransferSubscription;
  static StreamSubscription<List<Map<String, dynamic>>>?
  _withdrawalRequestSubscription;

  // Track processed transaction IDs to avoid duplicate notifications
  // These are cleared when subscriptions are restarted
  static final Set<String> _processedTopUpIds = {};
  static final Set<String> _processedServiceTxIds = {};
  static final Set<String> _processedTransferIds = {};
  static final Set<String> _processedWithdrawalRequestIds = {};

  // Track subscription start time to only notify for new records
  static DateTime? _subscriptionStartTime;

  /// Read the user's notification preference from local storage.
  static Future<bool> _isNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('notifications_enabled') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Initialize the notification service
  /// This should be called on app launch
  static Future<void> initialize() async {
    if (_isInitialized) {
      print('DEBUG: RealtimeNotificationService already initialized');
      return;
    }

    try {
      // Respect user preference: if disabled, do not initialize/listen
      final enabled = await _isNotificationsEnabled();
      if (!enabled) {
        print(
          'DEBUG: Notifications disabled by user. Skipping initialization.',
        );
        _isInitialized = true; // Mark initialized to avoid repeated attempts
        return;
      }

      // Initialize Flutter Local Notifications
      await _initializeLocalNotifications();

      // Initialize Supabase if not already initialized
      await SupabaseService.initialize();

      _isInitialized = true;
      print('DEBUG: RealtimeNotificationService initialized successfully');

      // Try to start listening if student_id is available
      await startListening();
    } catch (e) {
      print('ERROR: Failed to initialize RealtimeNotificationService: $e');
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
        print('DEBUG: Local notifications initialized successfully');

        // Request permissions for Android 13+
        await _requestAndroidPermissions();
      } else {
        print('WARNING: Local notifications initialization returned false');
      }
    } catch (e) {
      print('ERROR: Failed to initialize local notifications: $e');
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
        print('DEBUG: Android notification permission granted: $granted');
      }
    } catch (e) {
      print('ERROR: Failed to request Android permissions: $e');
      // Continue even if permission request fails - notifications might still work
    }
  }

  /// Handle notification tap
  static void _onNotificationTapped(NotificationResponse response) {
    print('DEBUG: Notification tapped: ${response.payload}');
    // You can navigate to specific pages based on payload here
    // For now, we'll just log it
  }

  /// Start listening to Supabase Realtime events
  /// This method checks for student_id from SessionService or UsernameStorageService
  static Future<void> startListening() async {
    if (_isListening) {
      print('DEBUG: Already listening to realtime events');
      return;
    }

    try {
      // Respect user preference
      final enabled = await _isNotificationsEnabled();
      if (!enabled) {
        print('DEBUG: Notifications disabled by user. Not starting listener.');
        return;
      }

      // Step 1: Get student_id from SessionService (if logged in)
      String? studentId = SessionService.currentUserStudentId;

      // Step 2: If not found, try to get from UsernameStorageService (saved username)
      if (studentId.isEmpty) {
        final savedUsername =
            await UsernameStorageService.getLastUsedUsername();
        if (savedUsername != null && savedUsername.isNotEmpty) {
          // If we have a saved username, we can use it
          // However, we need to verify if the user is logged in
          // For notifications, we'll only listen if user is logged in
          print(
            'DEBUG: Found saved username but user not logged in. Not starting notifications.',
          );
          return;
        }
      }

      // Step 3: If still no student_id, don't start listening
      if (studentId.isEmpty) {
        print(
          'DEBUG: No student_id found. Cannot start realtime notifications.',
        );
        return;
      }

      // Step 4: Store current student_id
      _currentStudentId = studentId;
      print(
        'DEBUG: Starting realtime notifications for student_id: $studentId',
      );

      // Step 5: Subscribe to realtime events
      await _subscribeToRealtimeEvents(studentId);

      _isListening = true;
      print('DEBUG: Successfully started listening to realtime events');
    } catch (e) {
      print('ERROR: Failed to start listening to realtime events: $e');
    }
  }

  /// Subscribe to Supabase Realtime events for the three tables
  /// Uses Supabase stream API which is built on Realtime
  static Future<void> _subscribeToRealtimeEvents(String studentId) async {
    try {
      // Double-check preference before subscribing
      final enabled = await _isNotificationsEnabled();
      if (!enabled) {
        print('DEBUG: Notifications disabled by user. Skipping subscriptions.');
        return;
      }

      final client = SupabaseService.client;

      // Record subscription start time to avoid notifying for old records
      _subscriptionStartTime = DateTime.now();

      // Clear processed IDs when starting new subscription
      _processedTopUpIds.clear();
      _processedServiceTxIds.clear();
      _processedTransferIds.clear();
      _processedWithdrawalRequestIds.clear();

      // Subscribe to top_up_transactions
      try {
        _topUpSubscription?.cancel();
      } catch (_) {}

      _topUpSubscription = client
          .from('top_up_transactions')
          .stream(primaryKey: ['id'])
          .eq('student_id', studentId)
          .listen(
            (rows) {
              for (final row in rows) {
                final id = row['id']?.toString();
                final createdAt = row['created_at']?.toString();

                // Only process if we haven't seen this ID before
                // and if it was created after subscription start (to avoid initial load duplicates)
                if (id != null && !_processedTopUpIds.contains(id)) {
                  // Check if record is new (created after subscription start)
                  if (_subscriptionStartTime != null && createdAt != null) {
                    try {
                      final recordTime = DateTime.parse(createdAt);
                      // Only notify for records created after subscription start
                      // Allow 5 second buffer for clock skew
                      if (recordTime.isBefore(
                        _subscriptionStartTime!.subtract(
                          const Duration(seconds: 5),
                        ),
                      )) {
                        _processedTopUpIds.add(id);
                        continue; // Skip old records
                      }
                    } catch (_) {
                      // If parsing fails, process anyway
                    }
                  }

                  _processedTopUpIds.add(id);
                  print('DEBUG: New top-up transaction detected: $id');
                  // Handle async without blocking the stream
                  _handleTopUpTransaction(row);
                }
              }
            },
            onError: (error) {
              print('ERROR: Top-up subscription error: $error');
            },
          );

      // Subscribe to service_transactions
      try {
        _serviceTxSubscription?.cancel();
      } catch (_) {}

      _serviceTxSubscription = client
          .from('service_transactions')
          .stream(primaryKey: ['id'])
          .eq('student_id', studentId)
          .listen(
            (rows) {
              for (final row in rows) {
                final id = row['id']?.toString();
                final createdAt = row['created_at']?.toString();

                if (id != null && !_processedServiceTxIds.contains(id)) {
                  // Check if record is new
                  if (_subscriptionStartTime != null && createdAt != null) {
                    try {
                      final recordTime = DateTime.parse(createdAt);
                      if (recordTime.isBefore(
                        _subscriptionStartTime!.subtract(
                          const Duration(seconds: 5),
                        ),
                      )) {
                        _processedServiceTxIds.add(id);
                        continue;
                      }
                    } catch (_) {
                      // If parsing fails, process anyway
                    }
                  }

                  _processedServiceTxIds.add(id);
                  print('DEBUG: New service transaction detected: $id');
                  // Handle async without blocking the stream
                  _handleServiceTransaction(row);
                }
              }
            },
            onError: (error) {
              print('ERROR: Service transaction subscription error: $error');
            },
          );

      // Subscribe to user_transfers (filter in callback since we need both sender and recipient)
      try {
        _userTransferSubscription?.cancel();
      } catch (_) {}

      _userTransferSubscription = client
          .from('user_transfers')
          .stream(primaryKey: ['id'])
          .listen(
            (rows) {
              for (final row in rows) {
                final senderId = row['sender_student_id']?.toString();
                final recipientId = row['recipient_student_id']?.toString();
                final id = row['id']?.toString();
                final createdAt = row['created_at']?.toString();

                // Check if this transfer involves the current student
                if ((senderId == studentId || recipientId == studentId) &&
                    id != null &&
                    !_processedTransferIds.contains(id)) {
                  // Check if record is new
                  if (_subscriptionStartTime != null && createdAt != null) {
                    try {
                      final recordTime = DateTime.parse(createdAt);
                      if (recordTime.isBefore(
                        _subscriptionStartTime!.subtract(
                          const Duration(seconds: 5),
                        ),
                      )) {
                        _processedTransferIds.add(id);
                        continue;
                      }
                    } catch (_) {
                      // If parsing fails, process anyway
                    }
                  }

                  _processedTransferIds.add(id);
                  print('DEBUG: New user transfer detected: $id');
                  // Handle async without blocking the stream
                  _handleUserTransfer(row, studentId);
                }
              }
            },
            onError: (error) {
              print('ERROR: User transfer subscription error: $error');
            },
          );

      // Subscribe to withdrawal_requests
      try {
        _withdrawalRequestSubscription?.cancel();
      } catch (_) {}

      _withdrawalRequestSubscription = client
          .from('withdrawal_requests')
          .stream(primaryKey: ['id'])
          .eq('student_id', studentId)
          .listen(
            (rows) {
              for (final row in rows) {
                final id = row['id']?.toString();
                final createdAt = row['created_at']?.toString();

                if (id != null &&
                    !_processedWithdrawalRequestIds.contains(id)) {
                  // Check if record is new
                  if (_subscriptionStartTime != null && createdAt != null) {
                    try {
                      final recordTime = DateTime.parse(createdAt);
                      if (recordTime.isBefore(
                        _subscriptionStartTime!.subtract(
                          const Duration(seconds: 5),
                        ),
                      )) {
                        _processedWithdrawalRequestIds.add(id);
                        continue;
                      }
                    } catch (_) {
                      // If parsing fails, process anyway
                    }
                  }

                  // Check if within 10-minute window for notification
                  if (createdAt != null) {
                    try {
                      final recordTime = DateTime.parse(createdAt);
                      final now = DateTime.now();
                      final tenMinutesAgo = now.subtract(
                        const Duration(minutes: 10),
                      );

                      // Only notify if created within last 10 minutes
                      if (recordTime.isBefore(tenMinutesAgo)) {
                        _processedWithdrawalRequestIds.add(id);
                        continue; // Skip old records (outside 10-minute window)
                      }
                    } catch (_) {
                      // If parsing fails, process anyway
                    }
                  }

                  _processedWithdrawalRequestIds.add(id);
                  print('DEBUG: New withdrawal request detected: $id');
                  // Handle async without blocking the stream
                  _handleWithdrawalRequest(row);
                }
              }
            },
            onError: (error) {
              print('ERROR: Withdrawal request subscription error: $error');
            },
          );

      print('DEBUG: Subscribed to all realtime streams');
    } catch (e) {
      print('ERROR: Failed to subscribe to realtime events: $e');
    }
  }

  /// Handle top-up transaction notification
  static void _handleTopUpTransaction(Map<String, dynamic> transaction) async {
    try {
      // Check if transaction is already read before showing notification
      if (_currentStudentId != null) {
        final isRead = await _isTransactionRead(
          studentId: _currentStudentId!,
          transactionType: 'top_up',
          transactionId: transaction['id'],
        );

        if (isRead) {
          print(
            'DEBUG: Top-up transaction ${transaction['id']} already read, skipping notification',
          );
          return;
        }
      }

      final amount = transaction['amount']?.toString() ?? '0';
      final message = '💰 You received a new top-up transaction of ₱$amount';

      _showNotification(
        id: _generateNotificationId('topup', transaction['id']),
        title: 'Top-up Received',
        body: message,
        payload: 'topup:${transaction['id']}',
      );
    } catch (e) {
      print('ERROR: Failed to handle top-up transaction: $e');
    }
  }

  /// Handle service transaction notification
  static void _handleServiceTransaction(
    Map<String, dynamic> transaction,
  ) async {
    try {
      // Check if transaction is already read before showing notification
      if (_currentStudentId != null) {
        final isRead = await _isTransactionRead(
          studentId: _currentStudentId!,
          transactionType: 'service_payment',
          transactionId: transaction['id'],
        );

        if (isRead) {
          print(
            'DEBUG: Service transaction ${transaction['id']} already read, skipping notification',
          );
          return;
        }
      }

      final amount = transaction['total_amount']?.toString() ?? '0';
      final serviceName = transaction['service_name']?.toString() ?? 'service';
      final message =
          '🛠️ A service transaction of ₱$amount has been processed at $serviceName';

      _showNotification(
        id: _generateNotificationId('service', transaction['id']),
        title: 'Service Transaction',
        body: message,
        payload: 'service:${transaction['id']}',
      );
    } catch (e) {
      print('ERROR: Failed to handle service transaction: $e');
    }
  }

  /// Handle user transfer notification
  static void _handleUserTransfer(
    Map<String, dynamic> transfer,
    String studentId,
  ) async {
    try {
      // Check if transaction is already read before showing notification
      final isRead = await _isTransactionRead(
        studentId: studentId,
        transactionType: 'transfer',
        transactionId: transfer['id'],
      );

      if (isRead) {
        print(
          'DEBUG: Transfer transaction ${transfer['id']} already read, skipping notification',
        );
        return;
      }

      final amount = transfer['amount']?.toString() ?? '0';
      final senderId = transfer['sender_student_id']?.toString();
      final recipientId = transfer['recipient_student_id']?.toString();
      final isSent = senderId == studentId;

      // Only notify for transfers received (not for transfers sent by the owner)
      if (isSent) {
        print(
          'DEBUG: Transfer ${transfer['id']} was sent by current user. Suppressing notification.',
        );
        return;
      }

      String title;
      String message;

      if (isSent) {
        title = 'Transfer Sent';
        message = '🔁 You sent ₱$amount to user $recipientId';
      } else {
        title = 'Transfer Received';
        message =
            '🔁 You received a fund transfer of ₱$amount from user $senderId';
      }

      _showNotification(
        id: _generateNotificationId('transfer', transfer['id']),
        title: title,
        body: message,
        payload: 'transfer:${transfer['id']}',
      );
    } catch (e) {
      print('ERROR: Failed to handle user transfer: $e');
    }
  }

  /// Handle withdrawal request notification
  static void _handleWithdrawalRequest(Map<String, dynamic> request) async {
    try {
      // Check if transaction is already read before showing notification
      if (_currentStudentId != null) {
        final isRead = await _isTransactionRead(
          studentId: _currentStudentId!,
          transactionType: 'withdrawal_request',
          transactionId: request['id'],
        );

        if (isRead) {
          print(
            'DEBUG: Withdrawal request ${request['id']} already read, skipping notification',
          );
          return;
        }
      }

      // Check if within 10-minute window
      final createdAt = request['created_at']?.toString();
      if (createdAt != null) {
        try {
          final recordTime = DateTime.parse(createdAt);
          final now = DateTime.now();
          final tenMinutesAgo = now.subtract(const Duration(minutes: 10));

          // Only notify if created within last 10 minutes
          if (recordTime.isBefore(tenMinutesAgo)) {
            print(
              'DEBUG: Withdrawal request ${request['id']} is older than 10 minutes, skipping notification',
            );
            return;
          }
        } catch (_) {
          // If parsing fails, continue with notification
        }
      }

      final amount = request['amount']?.toString() ?? '0';
      final status = request['status']?.toString() ?? 'Pending';
      final transferType = request['transfer_type']?.toString() ?? '';
      final processedBy = request['processed_by']?.toString();
      final adminNotes = request['admin_notes']?.toString();

      String title;
      String message;

      if (status == 'Approved') {
        title = 'Withdrawal Approved';
        message = '✅ Your withdrawal request of ₱$amount has been approved.';
        if (processedBy != null && processedBy.isNotEmpty) {
          message += ' Processed by $processedBy.';
        }
      } else if (status == 'Rejected') {
        title = 'Withdrawal Rejected';
        message = '❌ Your withdrawal request of ₱$amount has been rejected.';
        if (adminNotes != null && adminNotes.isNotEmpty) {
          message += ' Reason: $adminNotes';
        }
      } else {
        // Pending status
        title = 'Withdrawal Request Submitted';
        message =
            '⏳ Your withdrawal request of ₱$amount via $transferType is pending approval.';
      }

      _showNotification(
        id: _generateNotificationId('withdrawal_request', request['id']),
        title: title,
        body: message,
        payload: 'withdrawal_request:${request['id']}',
      );
    } catch (e) {
      print('ERROR: Failed to handle withdrawal request: $e');
    }
  }

  /// Show a local notification
  static Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      // Respect user preference at display time as well
      final enabled = await _isNotificationsEnabled();
      if (!enabled) {
        print(
          'DEBUG: Notifications disabled by user. Suppressing local notification.',
        );
        return;
      }

      // Android notification details
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'realtime_notifications',
            'Realtime Transaction Notifications',
            channelDescription:
                'Notifications for real-time transaction updates',
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

      // Show the notification
      await _notificationsPlugin.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );

      print('DEBUG: Notification shown: $title - $body');
    } catch (e) {
      print('ERROR: Failed to show notification: $e');
    }
  }

  /// Check if a transaction is already marked as read in read_inbox
  static Future<bool> _isTransactionRead({
    required String studentId,
    required String transactionType,
    required dynamic transactionId,
  }) async {
    try {
      if (studentId.isEmpty || transactionId == null) {
        return false;
      }

      await SupabaseService.initialize();
      final client = SupabaseService.client;

      final transactionIdInt =
          transactionId is int
              ? transactionId
              : int.tryParse(transactionId.toString());

      if (transactionIdInt == null) {
        return false;
      }

      final result =
          await client
              .from('read_inbox')
              .select('id')
              .eq('student_id', studentId)
              .eq('transaction_type', transactionType)
              .eq('transaction_id', transactionIdInt)
              .maybeSingle();

      return result != null;
    } catch (e) {
      print('ERROR: Failed to check if transaction is read: $e');
      // If check fails, allow notification to proceed (fail open)
      return false;
    }
  }

  /// Generate a unique notification ID from table name and record ID
  static int _generateNotificationId(String table, dynamic recordId) {
    // Combine table name and record ID to create a unique ID
    final String combined = '$table${recordId.toString()}';
    // Use hash code (taking absolute value to ensure positive)
    return combined.hashCode.abs() % 2147483647; // Max int value
  }

  /// Stop listening to realtime events
  /// This should be called when the app is closed or user logs out
  static Future<void> stopListening() async {
    if (!_isListening) {
      print('DEBUG: Not listening, nothing to stop');
      return;
    }

    try {
      // Cancel all stream subscriptions
      await _topUpSubscription?.cancel();
      await _serviceTxSubscription?.cancel();
      await _userTransferSubscription?.cancel();
      await _withdrawalRequestSubscription?.cancel();

      // Clear subscription references
      _topUpSubscription = null;
      _serviceTxSubscription = null;
      _userTransferSubscription = null;
      _withdrawalRequestSubscription = null;

      _isListening = false;
      _currentStudentId = null;

      print('DEBUG: Stopped listening to realtime events');
    } catch (e) {
      print('ERROR: Failed to stop listening to realtime events: $e');
      // Force clear state even if cancellation fails
      _isListening = false;
      _currentStudentId = null;
    }
  }

  /// Restart listening (useful when student_id changes, e.g., after login)
  static Future<void> restartListening() async {
    print('DEBUG: Restarting realtime notifications...');
    final enabled = await _isNotificationsEnabled();
    if (!enabled) {
      // If disabled, ensure we are not listening
      await stopListening();
      print('DEBUG: Notifications disabled by user. Listener stopped.');
      return;
    }
    await stopListening();
    await startListening();
  }

  /// Check if service is currently listening
  static bool get isListening => _isListening;

  /// Get current student ID being monitored
  static String? get currentStudentId => _currentStudentId;
}
