import 'supabase_service.dart';
import 'notification_service.dart';

class LoanReminderService {
  /// Check and create loan due date notifications
  static Future<void> checkAndCreateLoanReminders() async {
    try {
      await SupabaseService.initialize();

      // Call the SQL function to create loan due notifications
      final response = await SupabaseService.client.rpc(
        'create_loan_due_notifications',
      );

      final notificationCount = response as int? ?? 0;

      if (notificationCount > 0) {
        print('Created $notificationCount loan due notifications');
      }
    } catch (e) {
      print('Error creating loan due notifications: $e');
    }
  }

  /// Get upcoming loan due dates for a student
  static Future<List<Map<String, dynamic>>> getUpcomingLoanDueDates(
    String studentId,
  ) async {
    try {
      await SupabaseService.initialize();

      final response = await SupabaseService.client
          .from('active_loans')
          .select('''
            *,
            loan_plans (
              name
            )
          ''')
          .eq('student_id', studentId)
          .eq('status', 'active')
          .order('due_date');

      final loans = List<Map<String, dynamic>>.from(response);

      // Filter loans that are due within the next 30 days
      final now = DateTime.now();
      final thirtyDaysFromNow = now.add(const Duration(days: 30));

      return loans.where((loan) {
        final dueDate = DateTime.parse(loan['due_date']);
        return dueDate.isBefore(thirtyDaysFromNow);
      }).toList();
    } catch (e) {
      print('Error getting upcoming loan due dates: $e');
      return [];
    }
  }

  /// Create a manual loan reminder notification
  static Future<void> createManualLoanReminder({
    required String studentId,
    required String loanId,
    required String title,
    required String message,
    bool isUrgent = false,
  }) async {
    await NotificationService.createNotification(
      studentId: studentId,
      type: isUrgent ? 'loan_overdue' : 'loan_reminder',
      title: title,
      message: message,
      actionData: 'loan_id:$loanId',
      isUrgent: isUrgent,
    );
  }

  /// Schedule loan reminder notifications (call this periodically)
  static Future<void> scheduleLoanReminders() async {
    try {
      await checkAndCreateLoanReminders();

      // Also cleanup old notifications
      await NotificationService.cleanupOldNotifications();
    } catch (e) {
      print('Error scheduling loan reminders: $e');
    }
  }

  /// Get loan notification statistics
  static Future<Map<String, int>> getLoanNotificationStats() async {
    try {
      await SupabaseService.initialize();

      // Get count of overdue loans
      final overdueResponse = await SupabaseService.client
          .from('active_loans')
          .select('id')
          .eq('status', 'active')
          .lt('due_date', DateTime.now().toIso8601String());

      final overdueCount = overdueResponse.length;

      // Get count of loans due in next 7 days
      final sevenDaysFromNow = DateTime.now().add(const Duration(days: 7));
      final dueSoonResponse = await SupabaseService.client
          .from('active_loans')
          .select('id')
          .eq('status', 'active')
          .gte('due_date', DateTime.now().toIso8601String())
          .lte('due_date', sevenDaysFromNow.toIso8601String());

      final dueSoonCount = dueSoonResponse.length;

      return {
        'overdue': overdueCount,
        'due_soon': dueSoonCount,
        'total_active': overdueCount + dueSoonResponse.length,
      };
    } catch (e) {
      print('Error getting loan notification stats: $e');
      return {'overdue': 0, 'due_soon': 0, 'total_active': 0};
    }
  }
}
