import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'username_storage_service.dart';
import 'encryption_service.dart';

/// Service to manage user activity alerts for recent transactions
class ActivityAlertService {
  static const String _lastAlertCheckKey = 'last_alert_check';
  static const String _notifiedTransactionsKey = 'notified_transactions';
  static const Duration _alertWindow = Duration(
    minutes: 30,
  ); // Check last 30 minutes

  /// Check for recent activity and return alert data if found
  static Future<Map<String, dynamic>> checkRecentActivity() async {
    try {
      // Get the saved username from UsernameStorageService
      final savedUsername = await UsernameStorageService.getLastUsedUsername();
      if (savedUsername == null || savedUsername.isEmpty) {
        return {'hasAlert': false, 'message': 'No saved username found'};
      }

      print(
        'DEBUG ActivityAlertService: Checking activity for saved username: $savedUsername',
      );

      // Try to determine user type and get user data based on saved username
      final userTypeResult = await _determineUserTypeAndGetData(savedUsername);
      if (!userTypeResult['success']) {
        return {'hasAlert': false, 'message': userTypeResult['message']};
      }

      final userType = userTypeResult['userType'];
      final userData = userTypeResult['userData'];

      // Check different tables based on user type
      if (userType == 'student') {
        return await _checkStudentActivity(userData);
      } else if (userType == 'service') {
        return await _checkServiceActivity(userData);
      }

      return {'hasAlert': false, 'message': 'Unsupported user type'};
    } catch (e) {
      print('DEBUG ActivityAlertService: Error checking activity: $e');
      return {'hasAlert': false, 'message': 'Error checking activity: $e'};
    }
  }

  /// Determine user type and get user data from saved username
  static Future<Map<String, dynamic>> _determineUserTypeAndGetData(
    String username,
  ) async {
    try {
      // First, try to find in auth_students table (student_id field)
      final studentResponse =
          await SupabaseService.client
              .from('auth_students')
              .select('*')
              .eq('student_id', username)
              .maybeSingle();

      if (studentResponse != null) {
        print('DEBUG ActivityAlertService: Found student with ID: $username');
        // Decrypt the student data since it's encrypted in the database
        final decryptedData = EncryptionService.decryptUserData(
          studentResponse,
        );
        return {
          'success': true,
          'userType': 'student',
          'userData': decryptedData,
        };
      }

      // If not found in auth_students, try service_accounts table (username field)
      final serviceResponse =
          await SupabaseService.client
              .from('service_accounts')
              .select('*')
              .eq('username', username)
              .maybeSingle();

      if (serviceResponse != null) {
        print(
          'DEBUG ActivityAlertService: Found service with username: $username',
        );
        return {
          'success': true,
          'userType': 'service',
          'userData': serviceResponse,
        };
      }

      // If not found in either table, try admin_accounts table
      final adminResponse =
          await SupabaseService.client
              .from('admin_accounts')
              .select('*')
              .eq('username', username)
              .maybeSingle();

      if (adminResponse != null) {
        print(
          'DEBUG ActivityAlertService: Found admin with username: $username',
        );
        return {
          'success': true,
          'userType': 'admin',
          'userData': adminResponse,
        };
      }

      return {
        'success': false,
        'message': 'User not found in any table with username: $username',
      };
    } catch (e) {
      print('DEBUG ActivityAlertService: Error determining user type: $e');
      return {'success': false, 'message': 'Error determining user type: $e'};
    }
  }

  /// Check for recent student activity (user_transfers table)
  static Future<Map<String, dynamic>> _checkStudentActivity(
    Map<String, dynamic> userData,
  ) async {
    try {
      final studentId = userData['student_id']?.toString();
      if (studentId == null || studentId.isEmpty) {
        return {'hasAlert': false, 'message': 'No student ID found'};
      }

      final cutoffTime = DateTime.now().subtract(_alertWindow);
      print(
        'DEBUG ActivityAlertService: Checking student activity since $cutoffTime',
      );

      // Check for recent transfers TO this student (money received)
      final receivedTransfers = await SupabaseService.client
          .from('user_transfers')
          .select('*')
          .eq('recipient_student_id', studentId)
          .gte('created_at', cutoffTime.toIso8601String())
          .order('created_at', ascending: false)
          .limit(5);

      // Check for recent transfers FROM this student (money sent)
      final sentTransfers = await SupabaseService.client
          .from('user_transfers')
          .select('*')
          .eq('sender_student_id', studentId)
          .gte('created_at', cutoffTime.toIso8601String())
          .order('created_at', ascending: false)
          .limit(5);

      // Filter out already notified transactions
      final notifiedIds = await _getNotifiedTransactionIds();
      final newReceivedTransfers =
          receivedTransfers
              .where(
                (transfer) => !notifiedIds.contains(transfer['id'].toString()),
              )
              .toList();
      final newSentTransfers =
          sentTransfers
              .where(
                (transfer) => !notifiedIds.contains(transfer['id'].toString()),
              )
              .toList();

      if (newReceivedTransfers.isNotEmpty) {
        final latestTransfer = newReceivedTransfers.first;
        return {
          'hasAlert': true,
          'type': 'transfer_received',
          'title': 'Money Received! 💰',
          'message':
              'You received ₱${latestTransfer['amount']} from ${latestTransfer['sender_name'] ?? 'Unknown'}',
          'timestamp': latestTransfer['created_at'],
          'transactionId': latestTransfer['id'].toString(),
          'amount': latestTransfer['amount'],
          'from': latestTransfer['sender_name'] ?? 'Unknown',
        };
      }

      if (newSentTransfers.isNotEmpty) {
        final latestTransfer = newSentTransfers.first;
        return {
          'hasAlert': true,
          'type': 'transfer_sent',
          'title': 'Transfer Completed ✅',
          'message':
              'You sent ₱${latestTransfer['amount']} to ${latestTransfer['recipient_name'] ?? 'Unknown'}',
          'timestamp': latestTransfer['created_at'],
          'transactionId': latestTransfer['id'].toString(),
          'amount': latestTransfer['amount'],
          'to': latestTransfer['recipient_name'] ?? 'Unknown',
        };
      }

      return {'hasAlert': false, 'message': 'No recent student activity'};
    } catch (e) {
      print('DEBUG ActivityAlertService: Error checking student activity: $e');
      return {
        'hasAlert': false,
        'message': 'Error checking student activity: $e',
      };
    }
  }

  /// Check for recent service activity (service_transactions table)
  static Future<Map<String, dynamic>> _checkServiceActivity(
    Map<String, dynamic> userData,
  ) async {
    try {
      final serviceId = userData['service_id']?.toString();
      if (serviceId == null || serviceId.isEmpty) {
        return {'hasAlert': false, 'message': 'No service ID found'};
      }

      final cutoffTime = DateTime.now().subtract(_alertWindow);
      print(
        'DEBUG ActivityAlertService: Checking service activity since $cutoffTime',
      );

      // Check for recent service transactions
      final recentTransactions = await SupabaseService.client
          .from('service_transactions')
          .select('*')
          .eq('service_account_id', serviceId)
          .gte('created_at', cutoffTime.toIso8601String())
          .order('created_at', ascending: false)
          .limit(5);

      // Filter out already notified transactions
      final notifiedIds = await _getNotifiedTransactionIds();
      final newTransactions =
          recentTransactions
              .where(
                (transaction) =>
                    !notifiedIds.contains(transaction['id'].toString()),
              )
              .toList();

      if (newTransactions.isNotEmpty) {
        final latestTransaction = newTransactions.first;
        final studentName =
            latestTransaction['student_name'] ?? 'Unknown Student';
        final amount = latestTransaction['amount'] ?? 0.0;

        return {
          'hasAlert': true,
          'type': 'service_transaction',
          'title': 'New Payment Received! 💳',
          'message':
              '$studentName paid ₱${amount.toStringAsFixed(2)} for ${latestTransaction['item_name'] ?? 'services'}',
          'timestamp': latestTransaction['created_at'],
          'transactionId': latestTransaction['id'].toString(),
          'amount': amount,
          'studentName': studentName,
          'itemName': latestTransaction['item_name'] ?? 'services',
        };
      }

      return {'hasAlert': false, 'message': 'No recent service activity'};
    } catch (e) {
      print('DEBUG ActivityAlertService: Error checking service activity: $e');
      return {
        'hasAlert': false,
        'message': 'Error checking service activity: $e',
      };
    }
  }

  /// Mark a transaction as notified to prevent duplicate alerts
  static Future<void> markAsNotified(String transactionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notifiedIds = await _getNotifiedTransactionIds();
      notifiedIds.add(transactionId);

      // Keep only last 100 notified IDs to prevent storage bloat
      if (notifiedIds.length > 100) {
        notifiedIds.removeRange(0, notifiedIds.length - 100);
      }

      await prefs.setStringList(_notifiedTransactionsKey, notifiedIds);
      print(
        'DEBUG ActivityAlertService: Marked transaction $transactionId as notified',
      );
    } catch (e) {
      print(
        'DEBUG ActivityAlertService: Error marking transaction as notified: $e',
      );
    }
  }

  /// Get list of already notified transaction IDs
  static Future<List<String>> _getNotifiedTransactionIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_notifiedTransactionsKey) ?? [];
    } catch (e) {
      print(
        'DEBUG ActivityAlertService: Error getting notified transaction IDs: $e',
      );
      return [];
    }
  }

  /// Update last alert check timestamp
  static Future<void> updateLastAlertCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lastAlertCheckKey,
        DateTime.now().toIso8601String(),
      );
    } catch (e) {
      print('DEBUG ActivityAlertService: Error updating last alert check: $e');
    }
  }

  /// Get last alert check timestamp
  static Future<DateTime?> getLastAlertCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getString(_lastAlertCheckKey);
      return timestamp != null ? DateTime.parse(timestamp) : null;
    } catch (e) {
      print('DEBUG ActivityAlertService: Error getting last alert check: $e');
      return null;
    }
  }

  /// Clear all notification tracking (useful for testing or reset)
  static Future<void> clearNotificationTracking() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_notifiedTransactionsKey);
      await prefs.remove(_lastAlertCheckKey);
      print('DEBUG ActivityAlertService: Cleared all notification tracking');
    } catch (e) {
      print(
        'DEBUG ActivityAlertService: Error clearing notification tracking: $e',
      );
    }
  }
}
