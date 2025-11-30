import 'dart:async';

import 'supabase_service.dart';

/// Service for managing transaction inbox messages and read/unread status
///
/// This service now reads directly from the transaction tables:
/// top_up_transactions, service_transactions, and user_transfers. It no longer
/// depends on a dedicated inbox table.
class InboxService {
  static const String _topUpType = 'top_up';
  static const String _servicePaymentType = 'service_payment';
  static const String _transferType = 'transfer';

  /// Fetch all transaction messages for a student with read/unread status
  static Future<List<Map<String, dynamic>>> fetchInboxMessages(
    String studentId,
  ) async {
    if (studentId.isEmpty) {
      return [];
    }

    try {
      await SupabaseService.initialize();
      final client = SupabaseService.client;

      // Fetch read markers for this student
      final readRows = await client
          .from('read_inbox')
          .select('transaction_type, transaction_id')
          .eq('student_id', studentId);

      final readKeys = <String>{};
      for (final row in readRows as List) {
        final type = row['transaction_type']?.toString();
        final id = row['transaction_id'];
        if (type != null && id != null) {
          readKeys.add(_buildReadKey(type, id));
        }
      }

      // Fetch transactions from each source table
      final topUpRows = await client
          .from('top_up_transactions')
          .select('id, amount, processed_by, notes, created_at')
          .eq('student_id', studentId);

      final serviceRows = await client
          .from('service_transactions')
          .select(
            'id, student_id, main_service_id, service_account_id, total_amount, items, metadata, created_at',
          )
          .eq('student_id', studentId);

      final transferSentRows = await client
          .from('user_transfers')
          .select(
            'id, sender_student_id, recipient_student_id, amount, status, created_at',
          )
          .eq('sender_student_id', studentId);

      final transferReceivedRows = await client
          .from('user_transfers')
          .select(
            'id, sender_student_id, recipient_student_id, amount, status, created_at',
          )
          .eq('recipient_student_id', studentId);

      final transferRowMap = <dynamic, Map<String, dynamic>>{};
      for (final row in transferSentRows as List) {
        final id = row['id'];
        if (id != null) {
          transferRowMap[id] = Map<String, dynamic>.from(row as Map);
        }
      }
      for (final row in transferReceivedRows as List) {
        final id = row['id'];
        if (id != null) {
          transferRowMap.putIfAbsent(
            id,
            () => Map<String, dynamic>.from(row as Map),
          );
        }
      }

      // Fetch withdrawal requests for this student
      final withdrawalRequestRows = await client
          .from('withdrawal_requests')
          .select(
            'id, student_id, amount, transfer_type, gcash_number, gcash_account_name, status, created_at, processed_at, processed_by, admin_notes',
          )
          .eq('student_id', studentId);

      final notifications = <Map<String, dynamic>>[
        ..._mapTopUpTransactions(topUpRows as List, readKeys),
        ..._mapServiceTransactions(serviceRows as List, readKeys),
        ..._mapTransferTransactions(
          transferRowMap.values.toList(),
          readKeys,
          studentId,
        ),
        ..._mapWithdrawalRequests(withdrawalRequestRows as List, readKeys),
      ];

      notifications.sort(
        (a, b) =>
            _parseDate(b['created_at']).compareTo(_parseDate(a['created_at'])),
      );

      return notifications;
    } catch (e) {
      print('ERROR: Failed to fetch inbox messages: $e');
      return [];
    }
  }

  /// Mark a transaction as read (upsert into read_inbox)
  static Future<bool> markMessageAsRead({
    required String studentId,
    required int transactionId,
    required String transactionType,
  }) async {
    try {
      await SupabaseService.initialize();
      final client = SupabaseService.client;

      await client.from('read_inbox').upsert({
        'student_id': studentId,
        'transaction_type': transactionType,
        'transaction_id': transactionId,
        'read_at': DateTime.now().toIso8601String(),
      }, onConflict: 'student_id,transaction_type,transaction_id');

      return true;
    } catch (e) {
      print('ERROR: Failed to mark transaction as read: $e');
      return false;
    }
  }

  /// Mark all unread inbox messages as read for a student
  static Future<bool> markAllAsRead(String studentId) async {
    try {
      if (studentId.isEmpty) return false;
      await SupabaseService.initialize();
      final client = SupabaseService.client;

      // Fetch current messages to determine unread items
      final messages = await fetchInboxMessages(studentId);
      final unread = messages.where((m) => m['is_read'] != true).toList();
      if (unread.isEmpty) {
        return true;
      }

      // Build upsert rows for read_inbox
      final rows =
          unread
              .map<Map<String, dynamic>>((m) {
                final txId = m['transaction_id'];
                final txType = (m['transaction_type'] ?? m['type'])?.toString();
                return {
                  'student_id': studentId,
                  'transaction_type': txType,
                  'transaction_id':
                      txId is int ? txId : int.tryParse(txId.toString()),
                  'read_at': DateTime.now().toIso8601String(),
                };
              })
              .where(
                (row) =>
                    row['transaction_type'] != null &&
                    row['transaction_id'] != null,
              )
              .toList();

      if (rows.isEmpty) {
        return true;
      }

      // Batch upsert
      await client
          .from('read_inbox')
          .upsert(
            rows,
            onConflict: 'student_id,transaction_type,transaction_id',
          );

      return true;
    } catch (e) {
      print('ERROR: Failed to mark all inbox messages as read: $e');
      return false;
    }
  }

  /// Get unread transaction count by comparing read markers against transactions
  static Future<int> getUnreadCount(String studentId) async {
    final messages = await fetchInboxMessages(studentId);
    return messages.where((message) => message['is_read'] != true).length;
  }

  /// Subscribe to transaction updates across all relevant tables
  static Stream<List<Map<String, dynamic>>> subscribeToInbox(String studentId) {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    final subscriptions = <StreamSubscription<List<Map<String, dynamic>>>>[];

    controller.onListen = () {
      void addStream(Stream<List<Map<String, dynamic>>> stream) {
        final sub = stream.listen(
          (data) => controller.add(data),
          onError: controller.addError,
        );
        subscriptions.add(sub);
      }

      try {
        final topUpStream = SupabaseService.client
            .from('top_up_transactions')
            .stream(primaryKey: ['id'])
            .eq('student_id', studentId);
        addStream(topUpStream);

        final serviceStream = SupabaseService.client
            .from('service_transactions')
            .stream(primaryKey: ['id'])
            .eq('student_id', studentId);
        addStream(serviceStream);

        final transferSentStream = SupabaseService.client
            .from('user_transfers')
            .stream(primaryKey: ['id'])
            .eq('sender_student_id', studentId);
        addStream(transferSentStream);

        final transferReceivedStream = SupabaseService.client
            .from('user_transfers')
            .stream(primaryKey: ['id'])
            .eq('recipient_student_id', studentId);
        addStream(transferReceivedStream);

        final withdrawalRequestStream = SupabaseService.client
            .from('withdrawal_requests')
            .stream(primaryKey: ['id'])
            .eq('student_id', studentId);
        addStream(withdrawalRequestStream);
      } catch (e) {
        controller.addError(e);
      }
    };

    controller.onCancel = () async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
      subscriptions.clear();
    };

    return controller.stream;
  }

  /// Subscribe to read state updates for the current student
  static Stream<List<Map<String, dynamic>>> subscribeToReadState(
    String studentId,
  ) {
    return SupabaseService.client
        .from('read_inbox')
        .stream(primaryKey: ['id'])
        .eq('student_id', studentId);
  }

  /// Check if a specific transaction has been marked as read
  static Future<bool> isMessageRead({
    required String studentId,
    required String transactionType,
    required int transactionId,
  }) async {
    try {
      await SupabaseService.initialize();
      final client = SupabaseService.client;

      final result =
          await client
              .from('read_inbox')
              .select('id')
              .eq('student_id', studentId)
              .eq('transaction_type', transactionType)
              .eq('transaction_id', transactionId)
              .maybeSingle();

      return result != null;
    } catch (e) {
      print('ERROR: Failed to verify read status: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> _mapTopUpTransactions(
    List<dynamic> rows,
    Set<String> readKeys,
  ) {
    return rows.map<Map<String, dynamic>>((row) {
      final id = row['id'];
      final amount = (row['amount'] as num?)?.toDouble();
      final processedBy = row['processed_by']?.toString();
      final createdAt = row['created_at'];
      final readKey = _buildReadKey(_topUpType, id);

      final messageBuffer = StringBuffer(
        amount != null
            ? 'Top-up of ${_formatCurrency(amount)}'
            : 'Top-up processed',
      );
      if (processedBy != null && processedBy.isNotEmpty) {
        messageBuffer.write(' by $processedBy');
      }
      messageBuffer.write('.');

      return {
        'id': id,
        'transaction_id': id,
        'transaction_type': _topUpType,
        'type': 'top_up',
        'title': 'Top-up Successful',
        'message': messageBuffer.toString(),
        'amount': amount,
        'processed_by': processedBy,
        'notes': row['notes'],
        'created_at': createdAt,
        'is_urgent': false,
        'is_read': readKeys.contains(readKey),
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _mapServiceTransactions(
    List<dynamic> rows,
    Set<String> readKeys,
  ) {
    return rows.map<Map<String, dynamic>>((row) {
      final id = row['id'];
      final amount = (row['total_amount'] as num?)?.toDouble();
      final metadata = row['metadata'];
      String? serviceName;
      if (metadata is Map && metadata['service_name'] != null) {
        serviceName = metadata['service_name'].toString();
      }

      final createdAt = row['created_at'];
      final readKey = _buildReadKey(_servicePaymentType, id);

      final message =
          amount != null
              ? 'You paid ${_formatCurrency(amount)}${serviceName != null ? ' for $serviceName' : ''}.'
              : 'A service transaction was recorded.';

      return {
        'id': id,
        'transaction_id': id,
        'transaction_type': _servicePaymentType,
        'type': 'service_payment',
        'title': serviceName ?? 'Service Payment',
        'message': message,
        'amount': amount,
        'service_account_id': row['service_account_id'],
        'main_service_id': row['main_service_id'],
        'items': row['items'],
        'metadata': metadata,
        'created_at': createdAt,
        'is_urgent': false,
        'is_read': readKeys.contains(readKey),
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _mapTransferTransactions(
    List<dynamic> rows,
    Set<String> readKeys,
    String studentId,
  ) {
    return rows.map<Map<String, dynamic>>((row) {
      final id = row['id'];
      final senderId = row['sender_student_id']?.toString();
      final recipientId = row['recipient_student_id']?.toString();
      final amount = (row['amount'] as num?)?.toDouble();
      final createdAt = row['created_at'];
      final isSender = senderId == studentId;

      final displayType = isSender ? 'transfer_sent' : 'transfer_received';
      final title = isSender ? 'Transfer Sent' : 'Transfer Received';
      final counterpart = isSender ? recipientId : senderId;

      final message =
          amount != null
              ? (isSender
                  ? 'You sent ${_formatCurrency(amount)} to ${counterpart ?? 'another user'}.'
                  : 'You received ${_formatCurrency(amount)} from ${counterpart ?? 'another user'}.')
              : 'A fund transfer was recorded.';

      final readKey = _buildReadKey(_transferType, id);

      return {
        'id': id,
        'transaction_id': id,
        'transaction_type': _transferType,
        'type': displayType,
        'title': title,
        'message': message,
        'amount': amount,
        'sender_student_id': senderId,
        'recipient_student_id': recipientId,
        'status': row['status'],
        'created_at': createdAt,
        'is_urgent': false,
        'is_read': readKeys.contains(readKey),
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _mapWithdrawalRequests(
    List<dynamic> rows,
    Set<String> readKeys,
  ) {
    final now = DateTime.now();
    final tenMinutesAgo = now.subtract(const Duration(minutes: 10));

    // Filter rows to only include those within 10-minute window
    final filteredRows =
        rows.where((row) {
          final createdAt = row['created_at'];
          final createdAtDate = _parseDate(createdAt);
          return createdAtDate.isAfter(tenMinutesAgo);
        }).toList();

    return filteredRows.map<Map<String, dynamic>>((row) {
      final id = row['id'];
      final amount = (row['amount'] as num?)?.toDouble();
      final status = row['status']?.toString() ?? 'Pending';
      final transferType = row['transfer_type']?.toString() ?? '';
      final createdAt = row['created_at'];
      final processedAt = row['processed_at'];
      final processedBy = row['processed_by']?.toString();
      final adminNotes = row['admin_notes']?.toString();

      final readKey = _buildReadKey('withdrawal_request', id);

      String title;
      String message;
      bool isUrgent = false;

      if (status == 'Approved') {
        title = 'Withdrawal Approved';
        message =
            amount != null
                ? 'Your withdrawal request of ${_formatCurrency(amount)} has been approved.'
                : 'Your withdrawal request has been approved.';
        if (processedBy != null && processedBy.isNotEmpty) {
          message += ' Processed by $processedBy.';
        }
      } else if (status == 'Rejected') {
        title = 'Withdrawal Rejected';
        message =
            amount != null
                ? 'Your withdrawal request of ${_formatCurrency(amount)} has been rejected.'
                : 'Your withdrawal request has been rejected.';
        if (adminNotes != null && adminNotes.isNotEmpty) {
          message += ' Reason: $adminNotes';
        }
        isUrgent = true;
      } else {
        // Pending status
        title = 'Withdrawal Request Submitted';
        message =
            amount != null
                ? 'Your withdrawal request of ${_formatCurrency(amount)} via $transferType is pending approval.'
                : 'Your withdrawal request is pending approval.';
        isUrgent = true;
      }

      return {
        'id': id,
        'transaction_id': id,
        'transaction_type': 'withdrawal_request',
        'type': 'withdrawal_request',
        'title': title,
        'message': message,
        'amount': amount,
        'status': status,
        'transfer_type': transferType,
        'gcash_number': row['gcash_number'],
        'gcash_account_name': row['gcash_account_name'],
        'processed_at': processedAt,
        'processed_by': processedBy,
        'admin_notes': adminNotes,
        'created_at': createdAt,
        'is_urgent': isUrgent,
        'is_read': readKeys.contains(readKey),
      };
    }).toList();
  }

  static String _buildReadKey(String type, dynamic id) {
    return '$type::${id?.toString() ?? ''}';
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (value is DateTime) {
      // Convert from UTC to Philippines time (UTC+8)
      final utc = value.isUtc ? value : value.toUtc();
      return utc.add(const Duration(hours: 8));
    }
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    // Database stores UTC, so convert to Philippines time (UTC+8)
    final utc = parsed.isUtc ? parsed : parsed.toUtc();
    return utc.add(const Duration(hours: 8));
  }

  static String _formatCurrency(num? value) {
    final amount = (value ?? 0).toDouble();
    return '₱${amount.toStringAsFixed(2)}';
  }
}
