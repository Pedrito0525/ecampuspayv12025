import 'supabase_service.dart';

class NotificationService {
  static const String _notificationsTable = 'user_notifications';

  /// Create notification types table and insert default types
  static Future<void> initializeNotificationTypes() async {
    try {
      await SupabaseService.initialize();

      // Create notification types table if not exists
      await SupabaseService.client.rpc('create_notification_types_table');

      // Insert default notification types
      await SupabaseService.client.rpc('insert_default_notification_types');
    } catch (e) {
      print('Error initializing notification types: $e');
    }
  }

  /// Create user notifications table
  static Future<void> createNotificationsTable() async {
    try {
      await SupabaseService.initialize();

      await SupabaseService.client.rpc('create_user_notifications_table');
    } catch (e) {
      print('Error creating notifications table: $e');
    }
  }

  /// Get all notifications for a user (including real transaction and loan data)
  static Future<List<Map<String, dynamic>>> getUserNotifications(
    String studentId,
  ) async {
    try {
      await SupabaseService.initialize();

      print('DEBUG: Fetching notifications for student: $studentId');

      final List<Map<String, dynamic>> allNotifications = [];

      // 1. Get notifications from user_notifications table
      try {
        final response = await SupabaseService.client
            .from(_notificationsTable)
            .select('*')
            .eq('student_id', studentId)
            .order('created_at', ascending: false);

        final dbNotifications = List<Map<String, dynamic>>.from(response);
        print('DEBUG: Found ${dbNotifications.length} database notifications');
        allNotifications.addAll(dbNotifications);
      } catch (e) {
        print('DEBUG: Could not fetch database notifications: $e');
      }

      // 2. Get recent service transactions (payments)
      try {
        final serviceTransactions = await SupabaseService.client
            .from('service_transactions')
            .select('*')
            .eq('student_id', studentId)
            .order('created_at', ascending: false)
            .limit(10);

        for (final transaction in serviceTransactions) {
          allNotifications.add({
            'id': 'service_${transaction['id']}',
            'student_id': studentId,
            'type': 'payment_success',
            'title': 'Payment Completed',
            'message':
                'Payment of ₱${transaction['total_amount']} at ${transaction['service_name'] ?? 'service'} was successful',
            'is_urgent': false,
            'is_read': false,
            'created_at': transaction['created_at'],
            'source': 'service_transactions',
          });
        }
        print(
          'DEBUG: Added ${serviceTransactions.length} service transaction notifications',
        );
      } catch (e) {
        print('DEBUG: Could not fetch service transactions: $e');
      }

      // 3. Get recent top-up transactions
      try {
        final topUpTransactions = await SupabaseService.client
            .from('top_up_transactions')
            .select('*')
            .eq('student_id', studentId)
            .order('created_at', ascending: false)
            .limit(5);

        for (final transaction in topUpTransactions) {
          allNotifications.add({
            'id': 'topup_${transaction['id']}',
            'student_id': studentId,
            'type': 'transaction_success',
            'title': 'Top-up Successful',
            'message':
                'Your account has been topped up with ₱${transaction['amount']}',
            'is_urgent': false,
            'is_read': false,
            'created_at': transaction['created_at'],
            'source': 'top_up_transactions',
          });
        }
        print(
          'DEBUG: Added ${topUpTransactions.length} top-up transaction notifications',
        );
      } catch (e) {
        print('DEBUG: Could not fetch top-up transactions: $e');
      }

      // 4. Get recent user transfers
      try {
        final transfers = await SupabaseService.client
            .from('user_transfers')
            .select('*')
            .or(
              'sender_student_id.eq.$studentId,recipient_student_id.eq.$studentId',
            )
            .order('created_at', ascending: false)
            .limit(10);

        for (final transfer in transfers) {
          final isSent = transfer['sender_student_id'] == studentId;
          allNotifications.add({
            'id': 'transfer_${transfer['id']}',
            'student_id': studentId,
            'type': isSent ? 'transfer_sent' : 'transfer_received',
            'title': isSent ? 'Transfer Sent' : 'Transfer Received',
            'message':
                isSent
                    ? 'You sent ₱${transfer['amount']} to user ${transfer['recipient_student_id']}'
                    : 'You received ₱${transfer['amount']} from user ${transfer['sender_student_id']}',
            'is_urgent': false,
            'is_read': false,
            'created_at': transfer['created_at'],
            'source': 'user_transfers',
          });
        }
        print('DEBUG: Added ${transfers.length} transfer notifications');
      } catch (e) {
        print('DEBUG: Could not fetch transfers: $e');
      }

      // 5. Get active loans and their due dates
      try {
        final activeLoans = await SupabaseService.client
            .from('active_loans')
            .select('''
              *,
              loan_plans (
                name
              )
            ''')
            .eq('student_id', studentId)
            .eq('status', 'active')
            .order('due_date', ascending: true);

        for (final loan in activeLoans) {
          final dueDate = DateTime.parse(loan['due_date']);
          final now = DateTime.now();
          final daysUntilDue = dueDate.difference(now).inDays;

          String title;
          String message;
          String type;
          bool isUrgent = false;

          if (daysUntilDue < 0) {
            title = 'Loan Overdue!';
            message =
                'Your loan of ₱${loan['loan_amount']} is ${-daysUntilDue} days overdue. Please pay immediately.';
            type = 'loan_overdue';
            isUrgent = true;
          } else if (daysUntilDue <= 3) {
            title = 'Loan Due Soon';
            message =
                'Your loan of ₱${loan['loan_amount']} is due in $daysUntilDue days.';
            type = 'loan_due_soon';
            isUrgent = daysUntilDue <= 1;
          } else if (daysUntilDue <= 7) {
            title = 'Loan Reminder';
            message =
                'Your loan of ₱${loan['loan_amount']} is due in $daysUntilDue days.';
            type = 'loan_reminder';
          } else {
            continue; // Skip loans due far in the future
          }

          allNotifications.add({
            'id': 'loan_${loan['id']}',
            'student_id': studentId,
            'type': type,
            'title': title,
            'message': message,
            'is_urgent': isUrgent,
            'is_read': false,
            'created_at': loan['created_at'],
            'source': 'active_loans',
          });
        }
        print('DEBUG: Added ${activeLoans.length} loan notifications');
      } catch (e) {
        print('DEBUG: Could not fetch active loans: $e');
      }

      // Sort all notifications by created_at
      allNotifications.sort((a, b) {
        final aTime = DateTime.parse(
          a['created_at'] ?? DateTime.now().toIso8601String(),
        );
        final bTime = DateTime.parse(
          b['created_at'] ?? DateTime.now().toIso8601String(),
        );
        return bTime.compareTo(aTime);
      });

      print('DEBUG: Total notifications found: ${allNotifications.length}');
      return allNotifications;
    } catch (e) {
      print('ERROR: Failed to get user notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  static Future<bool> markAsRead(int notificationId) async {
    try {
      await SupabaseService.initialize();

      await SupabaseService.client
          .from(_notificationsTable)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificationId);

      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read for a user
  static Future<bool> markAllAsRead(String studentId) async {
    try {
      await SupabaseService.initialize();

      await SupabaseService.client
          .from(_notificationsTable)
          .update({
            'is_read': true,
            'read_at': DateTime.now().toIso8601String(),
          })
          .eq('student_id', studentId)
          .eq('is_read', false);

      return true;
    } catch (e) {
      print('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Create a notification
  static Future<bool> createNotification({
    required String studentId,
    required String type,
    required String title,
    required String message,
    String? actionData,
    bool isUrgent = false,
  }) async {
    try {
      await SupabaseService.initialize();

      print(
        'DEBUG: Creating notification for student: $studentId, type: $type',
      );

      final result =
          await SupabaseService.client.from(_notificationsTable).insert({
            'student_id': studentId,
            'type': type,
            'title': title,
            'message': message,
            'action_data': actionData,
            'is_urgent': isUrgent,
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          }).select();

      print('DEBUG: Notification created successfully: $result');
      return true;
    } catch (e) {
      print('ERROR: Failed to create notification: $e');
      print('DEBUG: Student ID: $studentId, Type: $type, Title: $title');

      // Try to create the tables if they don't exist
      try {
        await createNotificationsTable();
        await initializeNotificationTypes();
        print('DEBUG: Tables created, retrying notification creation...');

        // Retry once after creating tables
        final result =
            await SupabaseService.client.from(_notificationsTable).insert({
              'student_id': studentId,
              'type': type,
              'title': title,
              'message': message,
              'action_data': actionData,
              'is_urgent': isUrgent,
              'is_read': false,
              'created_at': DateTime.now().toIso8601String(),
            }).select();

        print('DEBUG: Notification created on retry: $result');
        return true;
      } catch (retryError) {
        print(
          'ERROR: Failed to create notification even after retry: $retryError',
        );
        return false;
      }
    }
  }

  /// Create transaction notifications
  static Future<void> createTransactionNotifications({
    required String studentId,
    required String transactionType,
    required Map<String, dynamic> transactionData,
  }) async {
    String title;
    String message;
    String type;

    switch (transactionType) {
      case 'top_up':
        title = 'Top-up Successful';
        message =
            'Your account has been topped up with ₱${transactionData['amount']}';
        type = 'transaction_success';
        break;
      case 'payment':
        title = 'Payment Completed';
        message =
            'Payment of ₱${transactionData['amount']} at ${transactionData['service_name'] ?? 'service'} was successful';
        type = 'payment_success';
        break;
      case 'transfer_sent':
        title = 'Transfer Sent';
        message =
            'You sent ₱${transactionData['amount']} to ${transactionData['recipient_name'] ?? 'user'}';
        type = 'transfer_sent';
        break;
      case 'transfer_received':
        title = 'Transfer Received';
        message =
            'You received ₱${transactionData['amount']} from ${transactionData['sender_name'] ?? 'user'}';
        type = 'transfer_received';
        break;
      default:
        title = 'Transaction Completed';
        message = 'Your transaction has been processed successfully';
        type = 'transaction_success';
    }

    await createNotification(
      studentId: studentId,
      type: type,
      title: title,
      message: message,
      actionData: transactionData.toString(),
    );
  }

  /// Create loan due date notifications
  static Future<void> createLoanDueNotifications() async {
    try {
      await SupabaseService.initialize();

      // Get all active loans that are due soon or overdue
      final response = await SupabaseService.client
          .from('active_loans')
          .select('''
            *,
            loan_plans (
              name
            )
          ''')
          .eq('status', 'active');

      final loans = List<Map<String, dynamic>>.from(response);

      for (final loan in loans) {
        final dueDate = DateTime.parse(loan['due_date']);
        final now = DateTime.now();
        final daysUntilDue = dueDate.difference(now).inDays;

        String title;
        String message;
        String type;
        bool isUrgent = false;

        if (daysUntilDue < 0) {
          // Overdue
          title = 'Loan Overdue!';
          message =
              'Your loan of ₱${loan['loan_amount']} is ${-daysUntilDue} days overdue. Please pay immediately.';
          type = 'loan_overdue';
          isUrgent = true;
        } else if (daysUntilDue <= 3) {
          // Due soon
          title = 'Loan Due Soon';
          message =
              'Your loan of ₱${loan['loan_amount']} is due in $daysUntilDue days.';
          type = 'loan_due_soon';
          isUrgent = daysUntilDue <= 1;
        } else if (daysUntilDue <= 7) {
          // Due in a week
          title = 'Loan Reminder';
          message =
              'Your loan of ₱${loan['loan_amount']} is due in $daysUntilDue days.';
          type = 'loan_reminder';
        } else {
          continue; // Don't create notifications for loans due far in the future
        }

        // Check if notification already exists for this loan and time period
        final existingNotification =
            await SupabaseService.client
                .from(_notificationsTable)
                .select('id')
                .eq('student_id', loan['student_id'])
                .eq('type', type)
                .eq('action_data', 'loan_id:${loan['id']}')
                .maybeSingle();

        if (existingNotification == null) {
          await createNotification(
            studentId: loan['student_id'],
            type: type,
            title: title,
            message: message,
            actionData: 'loan_id:${loan['id']}',
            isUrgent: isUrgent,
          );
        }
      }
    } catch (e) {
      print('Error creating loan due notifications: $e');
    }
  }

  /// Get unread notification count (counts all notifications as "unread" since they're real-time data)
  static Future<int> getUnreadCount(String studentId) async {
    try {
      // Since we're now showing real transaction data, we'll count all notifications as "unread"
      // to show the notification badge. In a real app, you might want to track read status differently.
      final notifications = await getUserNotifications(studentId);

      // Count notifications that are marked as unread or are urgent
      int unreadCount = 0;
      for (final notification in notifications) {
        if (notification['is_read'] == false ||
            notification['is_urgent'] == true) {
          unreadCount++;
        }
      }

      print(
        'DEBUG: Unread count: $unreadCount out of ${notifications.length} total notifications',
      );
      return unreadCount;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Delete old notifications (older than 30 days)
  static Future<void> cleanupOldNotifications() async {
    try {
      await SupabaseService.initialize();

      final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

      await SupabaseService.client
          .from(_notificationsTable)
          .delete()
          .lt('created_at', thirtyDaysAgo.toIso8601String());
    } catch (e) {
      print('Error cleaning up old notifications: $e');
    }
  }

  /// Subscribe to real-time notifications
  static Stream<List<Map<String, dynamic>>> subscribeToNotifications(
    String studentId,
  ) {
    return SupabaseService.client
        .from(_notificationsTable)
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId)
        .order('created_at', ascending: false);
  }

  /// Create test notifications for development/demo purposes
  static Future<void> createTestNotifications(String studentId) async {
    try {
      print('DEBUG: Creating test notifications for student: $studentId');
      await SupabaseService.initialize();

      // Create a few test notifications
      final testNotifications = [
        {
          'student_id': studentId,
          'type': 'welcome',
          'title': 'Welcome to eCampusPay!',
          'message':
              'Thank you for joining the eCampusPay system. You can now manage your campus payments easily.',
          'is_urgent': false,
          'is_read': false,
          'created_at':
              DateTime.now()
                  .subtract(const Duration(hours: 2))
                  .toIso8601String(),
        },
        {
          'student_id': studentId,
          'type': 'system_notification',
          'title': 'System Maintenance',
          'message':
              'Scheduled maintenance will occur tonight from 11 PM to 1 AM. Some features may be temporarily unavailable.',
          'is_urgent': false,
          'is_read': false,
          'created_at':
              DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .toIso8601String(),
        },
        {
          'student_id': studentId,
          'type': 'loan_reminder',
          'title': 'Loan Reminder',
          'message':
              'Your loan of ₱5,000 is due in 5 days. Please ensure you have sufficient balance.',
          'is_urgent': false,
          'is_read': false,
          'created_at':
              DateTime.now()
                  .subtract(const Duration(minutes: 30))
                  .toIso8601String(),
        },
      ];

      print(
        'DEBUG: Inserting ${testNotifications.length} test notifications...',
      );

      for (int i = 0; i < testNotifications.length; i++) {
        final notification = testNotifications[i];
        print(
          'DEBUG: Inserting notification ${i + 1}: ${notification['title']}',
        );

        final result =
            await SupabaseService.client
                .from(_notificationsTable)
                .insert(notification)
                .select();

        print('DEBUG: Notification ${i + 1} inserted successfully: $result');
      }

      print(
        'DEBUG: Successfully created ${testNotifications.length} test notifications',
      );
    } catch (e) {
      print('ERROR: Failed to create test notifications: $e');
      print('DEBUG: Student ID was: $studentId');
    }
  }
}
