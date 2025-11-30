import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../services/encryption_service.dart';
import 'service_withdraw_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({Key? key}) : super(key: key);

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  StreamSubscription<List<Map<String, dynamic>>>? _balanceSubscription;
  double _todaysSales = 0.0;
  double _monthlySales = 0.0;
  double _totalFeesEarned = 0.0;
  List<Map<String, dynamic>> _recentActivities = [];
  bool _isLoadingActivities = true;

  // Commission settings
  double _vendorCommission = 1.00; // Default 1%
  double _adminCommission = 0.50; // Default 0.5%

  String _formatCreatedAt(dynamic createdAt) {
    if (createdAt == null) return 'N/A';

    final raw = createdAt.toString();
    if (raw.isEmpty) return 'N/A';

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final month = months[parsed.month - 1];
    final day = parsed.day;
    final year = parsed.year;

    var hour = parsed.hour % 12;
    hour = hour == 0 ? 12 : hour;
    final minute = parsed.minute.toString().padLeft(2, '0');
    final meridiem = parsed.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $year $hour:$minute $meridiem';
  }

  @override
  void initState() {
    super.initState();
    // Subscribe to balance updates only for Main accounts
    final operationalType =
        SessionService.currentUserData?['operational_type']?.toString() ??
        'Main';
    // ignore: avoid_print
    print('DEBUG HomeTab: init, operationalType=$operationalType');
    if (operationalType == 'Main') {
      _fetchInitialServiceBalance();
      _subscribeToServiceBalance();
    }
    _loadTodaysSales();
    _loadMonthlySales();
    _loadTotalFeesEarned();
    _loadRecentActivities();
    _loadCommissionSettings();
  }

  Future<void> _loadCommissionSettings() async {
    try {
      final result = await SupabaseService.getCommissionSettings();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        if (mounted) {
          setState(() {
            _vendorCommission =
                (data['vendor_commission'] as num?)?.toDouble() ?? 1.00;
            _adminCommission =
                (data['admin_commission'] as num?)?.toDouble() ?? 0.50;
          });
        }
      }
    } catch (e) {
      print('DEBUG HomeTab: Error loading commission settings: $e');
      // Keep defaults if loading fails
    }
  }

  @override
  void dispose() {
    try {
      _balanceSubscription?.cancel();
    } catch (_) {}
    super.dispose();
  }

  void _subscribeToServiceBalance() {
    // Safety: Only Main accounts should fetch balance
    final operationalType =
        SessionService.currentUserData?['operational_type']?.toString() ??
        'Main';
    if (operationalType != 'Main') return;

    final serviceIdStr =
        SessionService.currentUserData?['service_id']?.toString();
    if (serviceIdStr == null || serviceIdStr.isEmpty) return;
    final int? serviceId = int.tryParse(serviceIdStr);
    if (serviceId == null) return;

    // ignore: avoid_print
    print('DEBUG HomeTab: subscribing to service_accounts id=$serviceId');

    try {
      _balanceSubscription?.cancel();
    } catch (_) {}

    _balanceSubscription = SupabaseService.client
        .from('service_accounts')
        .stream(primaryKey: ['id'])
        .eq('id', serviceId)
        .limit(1)
        .listen((rows) {
          // ignore: avoid_print
          print('DEBUG HomeTab: realtime rows len=${rows.length}');
          if (rows.isEmpty) return;
          final row = rows.first;
          final newBalance = double.tryParse(row['balance']?.toString() ?? '');
          if (newBalance != null) {
            // ignore: avoid_print
            print('DEBUG HomeTab: realtime balance=$newBalance');
            SessionService.currentUserData?['balance'] = newBalance.toString();
            if (mounted) setState(() {});
          }
        });
  }

  Future<void> _fetchInitialServiceBalance() async {
    try {
      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString();
      if (serviceIdStr == null || serviceIdStr.isEmpty) return;
      final int? serviceId = int.tryParse(serviceIdStr);
      if (serviceId == null) return;

      // ignore: avoid_print
      print('DEBUG HomeTab: fetching initial balance for id=$serviceId');
      final row =
          await SupabaseService.client
              .from('service_accounts')
              .select('balance')
              .eq('id', serviceId)
              .maybeSingle();
      if (row != null) {
        final newBalance = double.tryParse(row['balance']?.toString() ?? '');
        if (newBalance != null) {
          // ignore: avoid_print
          print('DEBUG HomeTab: initial balance=$newBalance');
          SessionService.currentUserData?['balance'] = newBalance.toString();
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG HomeTab: initial balance error: $e');
      // ignore errors; realtime will still update
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isWeb = screenWidth > 600;

    final currentBalance =
        double.tryParse(
          SessionService.currentUserData?['balance']?.toString() ?? '0',
        ) ??
        0.0;
    final todaysSalesStr = '₱${_todaysSales.toStringAsFixed(2)}';

    final serviceName =
        SessionService.currentUserData?['service_name']?.toString() ??
        'Service';
    final operationalType =
        SessionService.currentUserData?['operational_type']?.toString() ??
        'Main';
    final serviceCategory =
        SessionService.currentUserData?['service_category']?.toString() ?? '';
    final bool vendorAllowed = serviceCategory == 'Vendor';

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWeb ? 24 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isWeb ? 24 : 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB91C1C), Color(0xFF7F1D1D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB91C1C).withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back!',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: isWeb ? 16 : 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            serviceName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isWeb ? 20 : 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            operationalType,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (operationalType == 'Main') ...[
                  Text(
                    'Service Account Balance',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: isWeb ? 16 : 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '₱${currentBalance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isWeb ? 42 : 36,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Available for transactions and student top-ups',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Quick Actions
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: isWeb ? 20 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              if (vendorAllowed) ...[
                Expanded(
                  child: _buildActionCard(
                    title: 'Top Up Student',
                    subtitle: 'Transfer balance to students',
                    icon: Icons.person_add,
                    color: Colors.green,
                    onTap: () => _showTopUpDialog(),
                    isWeb: isWeb,
                  ),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: _buildActionCard(
                  title: 'Transaction History',
                  subtitle: 'View recent transactions',
                  icon: Icons.history,
                  color: Colors.blue,
                  onTap: () => _showTransactionHistory(),
                  isWeb: isWeb,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  title: 'Profile Settings',
                  subtitle: 'Update service information',
                  icon: Icons.settings,
                  color: Colors.purple,
                  onTap: () => _showProfileSettingsDialog(),
                  isWeb: isWeb,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final isWithinWorkingHours = _isWithinWorkingHours();
                    final isMainAccount = operationalType == 'Main';
                    final isEnabled = isMainAccount && isWithinWorkingHours;

                    String subtitle;
                    if (!isMainAccount) {
                      subtitle = 'Only available for Main accounts';
                    } else if (!isWithinWorkingHours) {
                      subtitle = 'Available 8:00 AM - 5:00 PM (PH Time)';
                    } else {
                      subtitle = 'Withdraw funds to admin';
                    }

                    return _buildActionCard(
                      title: 'Withdraw',
                      subtitle: subtitle,
                      icon: Icons.account_balance_wallet,
                      color: isEnabled ? Colors.red.shade700 : Colors.grey,
                      onTap:
                          isMainAccount
                              ? () {
                                if (isWithinWorkingHours) {
                                  _navigateToWithdraw();
                                } else {
                                  _showWorkingHoursModal();
                                }
                              }
                              : null,
                      isWeb: isWeb,
                      isEnabledOverride: isEnabled,
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Balance Overview Cards
          Text(
            'Balance Overview',
            style: TextStyle(
              fontSize: isWeb ? 20 : 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Today\'s Sales',
                  value: todaysSalesStr,
                  icon: Icons.trending_up,
                  color: Colors.green,
                  isWeb: isWeb,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  title: 'This Month',
                  value: '₱${_monthlySales.toStringAsFixed(2)}',
                  icon: Icons.calendar_month,
                  color: Colors.blue,
                  isWeb: isWeb,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Total Fees Earned',
                  value: '₱${_totalFeesEarned.toStringAsFixed(2)}',
                  icon: Icons.monetization_on,
                  color: Colors.purple,
                  isWeb: isWeb,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Recent Activity
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isWeb ? 24 : 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
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
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: isWeb ? 18 : 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showTransactionHistory(),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isLoadingActivities) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ] else if (_recentActivities.isEmpty) ...[
                  _buildActivityItem(
                    'No recent activity',
                    'Start by topping up students or making sales',
                    Icons.info_outline,
                    Colors.grey,
                    null,
                  ),
                ] else ...[
                  ..._recentActivities.map(
                    (activity) => _buildActivityItem(
                      activity['title'] as String,
                      activity['subtitle'] as String,
                      activity['icon'] as IconData,
                      activity['color'] as Color,
                      activity['created_at']?.toString(),
                      activityData: activity,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTodaysSales() async {
    try {
      await SupabaseService.initialize();
      final now = DateTime.now();
      final localStart = DateTime(now.year, now.month, now.day);
      final localEndNext = localStart.add(const Duration(days: 1));
      final from = localStart.toUtc().toIso8601String();
      final to = localEndNext.toUtc().toIso8601String();

      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString() ?? '0';
      final serviceId = int.tryParse(serviceIdStr) ?? 0;
      final operationalType =
          SessionService.currentUserData?['operational_type']?.toString() ??
          'Main';
      final mainServiceIdStr =
          SessionService.currentUserData?['main_service_id']?.toString();
      final rootMainId =
          operationalType == 'Sub'
              ? (int.tryParse(mainServiceIdStr ?? '') ?? serviceId)
              : serviceId;

      // ignore: avoid_print
      print(
        'DEBUG HomeTab: today localStart=$localStart localEndNext=$localEndNext, UTC from=$from to=$to, rootMainId=$rootMainId',
      );

      final res = await SupabaseService.client
          .from('service_transactions')
          .select(
            'total_amount, main_service_id, service_account_id, created_at',
          )
          .or(
            'main_service_id.eq.${rootMainId},service_account_id.eq.${rootMainId}',
          )
          .gte('created_at', from)
          .lt('created_at', to);

      double sum = 0.0;
      for (final row in (res as List)) {
        sum += ((row['total_amount'] as num?)?.toDouble() ?? 0.0);
      }
      // ignore: avoid_print
      print(
        'DEBUG HomeTab: today sales rows=${(res as List).length}, sum=$sum',
      );
      if (mounted) setState(() => _todaysSales = sum);
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG HomeTab: load today sales error: $e');
    }
  }

  Future<void> _loadMonthlySales() async {
    try {
      await SupabaseService.initialize();
      final now = DateTime.now();
      final localStart = DateTime(now.year, now.month, 1);
      final localEndNext = DateTime(now.year, now.month + 1, 1);
      final from = localStart.toUtc().toIso8601String();
      final to = localEndNext.toUtc().toIso8601String();

      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString() ?? '0';
      final serviceId = int.tryParse(serviceIdStr) ?? 0;
      final operationalType =
          SessionService.currentUserData?['operational_type']?.toString() ??
          'Main';
      final mainServiceIdStr =
          SessionService.currentUserData?['main_service_id']?.toString();
      final rootMainId =
          operationalType == 'Sub'
              ? (int.tryParse(mainServiceIdStr ?? '') ?? serviceId)
              : serviceId;

      // ignore: avoid_print
      print(
        'DEBUG HomeTab: monthly localStart=$localStart localEndNext=$localEndNext, UTC from=$from to=$to, rootMainId=$rootMainId',
      );

      final res = await SupabaseService.client
          .from('service_transactions')
          .select(
            'total_amount, main_service_id, service_account_id, created_at',
          )
          .or(
            'main_service_id.eq.${rootMainId},service_account_id.eq.${rootMainId}',
          )
          .gte('created_at', from)
          .lt('created_at', to);

      double sum = 0.0;
      for (final row in (res as List)) {
        sum += ((row['total_amount'] as num?)?.toDouble() ?? 0.0);
      }
      // ignore: avoid_print
      print(
        'DEBUG HomeTab: monthly sales rows=${(res as List).length}, sum=$sum',
      );
      if (mounted) setState(() => _monthlySales = sum);
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG HomeTab: load monthly sales error: $e');
    }
  }

  Future<void> _loadTotalFeesEarned() async {
    try {
      await SupabaseService.initialize();
      final serviceUsername =
          SessionService.currentUserData?['username']?.toString();

      if (serviceUsername == null || serviceUsername.isEmpty) {
        if (mounted) setState(() => _totalFeesEarned = 0.0);
        return;
      }

      // Get all top-up transactions processed by this service account
      final topUpTransactions = await SupabaseService.client
          .from('top_up_transactions')
          .select('vendor_earn')
          .eq('processed_by', serviceUsername)
          .eq('transaction_type', 'top_up_services');

      double totalFees = 0.0;
      for (final transaction in (topUpTransactions as List)) {
        final vendorEarn =
            (transaction['vendor_earn'] as num?)?.toDouble() ?? 0.0;
        totalFees += vendorEarn;
      }

      // ignore: avoid_print
      print(
        'DEBUG HomeTab: total fees earned rows=${(topUpTransactions as List).length}, sum=$totalFees',
      );
      if (mounted) setState(() => _totalFeesEarned = totalFees);
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG HomeTab: load total fees earned error: $e');
    }
  }

  Future<void> _loadRecentActivities() async {
    try {
      await SupabaseService.initialize();
      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString() ?? '0';
      final serviceId = int.tryParse(serviceIdStr) ?? 0;
      final operationalType =
          SessionService.currentUserData?['operational_type']?.toString() ??
          'Main';

      final List<Map<String, dynamic>> activities = [];

      // Get top-up transactions (where this service account processed top-ups)
      try {
        // Get the service account username for filtering
        final serviceUsername =
            SessionService.currentUserData?['username']?.toString();

        if (serviceUsername != null && serviceUsername.isNotEmpty) {
          final topUpTransactions = await SupabaseService.client
              .from('top_up_transactions')
              .select(
                'id, student_id, amount, created_at, processed_by, transaction_type',
              )
              .eq('processed_by', serviceUsername) // Filter by username
              .eq(
                'transaction_type',
                'top_up_services',
              ) // Only show service account top-ups
              .order('created_at', ascending: false)
              .limit(10);

          // Get service name from session data (since we're filtering by current service)
          final serviceName =
              SessionService.currentUserData?['service_name']?.toString() ??
              'Unknown Service';

          for (final transaction in topUpTransactions) {
            // Fetch student name from auth_students table
            String? studentName;
            try {
              final studentId = transaction['student_id']?.toString();
              if (studentId != null && studentId.isNotEmpty) {
                final studentRow =
                    await SupabaseService.client
                        .from('auth_students')
                        .select('name')
                        .eq('student_id', studentId)
                        .maybeSingle();
                if (studentRow != null) {
                  String name = studentRow['name']?.toString() ?? '';
                  if (EncryptionService.looksLikeEncryptedData(name)) {
                    name = EncryptionService.decryptData(name);
                  }
                  studentName = name;
                }
              }
            } catch (e) {
              print('DEBUG HomeTab: Error fetching student name: $e');
            }

            activities.add({
              'id': transaction['id'],
              'type': 'top_up',
              'title': 'Student Top-up',
              'subtitle':
                  'Topped up ₱${(transaction['amount'] as num).toStringAsFixed(2)} to student ${transaction['student_id']} • Processed by: $serviceName',
              'amount': transaction['amount'],
              'created_at':
                  transaction['created_at'], // Use actual transaction timestamp
              'student_name': studentName,
              'student_id': transaction['student_id']?.toString(),
              'icon': Icons.person_add,
              'color': Colors.green,
            });
          }
        }
      } catch (e) {
        print('DEBUG HomeTab: Error loading top-up transactions: $e');
      }

      // Get service transactions (payments made by students to this service)
      try {
        final serviceTransactions = await SupabaseService.client
            .from('service_transactions')
            .select(
              'id, student_id, total_amount, created_at, items, service_account_id, transaction_code, purpose, service_accounts!service_transactions_service_account_id_fkey(service_name, service_category)',
            )
            .or(
              operationalType == 'Main'
                  ? 'main_service_id.eq.${serviceId},service_account_id.eq.${serviceId}'
                  : 'service_account_id.eq.${serviceId}',
            )
            .order('created_at', ascending: false)
            .limit(10);

        for (final transaction in serviceTransactions) {
          final items = transaction['items'] as List?;
          final firstItem = items?.isNotEmpty == true ? items!.first : null;
          final itemName = firstItem?['name']?.toString() ?? 'Service Payment';
          final serviceName =
              (transaction['service_accounts']?['service_name']?.toString()) ??
              'Unknown Service';
          final transactionServiceCategory =
              transaction['service_accounts']?['service_category']
                  ?.toString() ??
              '';
          final transactionIsCampusServiceUnits =
              transactionServiceCategory == 'Campus Service Units';

          // Debug: Print transaction data to understand the structure
          print('DEBUG: Transaction data: ${transaction.toString()}');
          print(
            'DEBUG: Service accounts data: ${transaction['service_accounts']}',
          );
          print('DEBUG: Service name extracted: $serviceName');

          activities.add({
            'id': transaction['id'],
            'transaction_code': transaction['transaction_code'],
            'purpose': transaction['purpose'],
            'is_campus_service_units': transactionIsCampusServiceUnits,
            'type': 'payment',
            'title': 'Payment Received',
            'subtitle':
                '₱${(transaction['total_amount'] as num).toStringAsFixed(2)} for $itemName from student ${transaction['student_id']} • Service: $serviceName',
            'amount': transaction['total_amount'],
            'created_at': transaction['created_at'],
            'icon': Icons.payment,
            'color': Colors.blue,
          });
        }
      } catch (e) {
        print('DEBUG HomeTab: Error loading service transactions: $e');
      }

      // Get withdrawal transactions (where users withdrew to this service account)
      try {
        print(
          'DEBUG HomeTab: Fetching withdrawal transactions for service ID: $serviceId',
        );
        final withdrawalResult = await SupabaseService.adminClient
            .from('withdrawal_transactions')
            .select(
              'id, student_id, amount, created_at, transaction_type, metadata',
            )
            .eq('destination_service_id', serviceId)
            .eq('transaction_type', 'Withdraw to Service')
            .order('created_at', ascending: false)
            .limit(10);

        print(
          'DEBUG HomeTab: Withdrawal transactions found: ${withdrawalResult.length}',
        );

        for (final withdrawal in (withdrawalResult as List)) {
          final amount = (withdrawal['amount'] as num?)?.toDouble() ?? 0.0;
          final studentId = withdrawal['student_id']?.toString() ?? 'Unknown';

          activities.add({
            'id': withdrawal['id'],
            'type': 'withdrawal',
            'title': 'Balance Transfer Received',
            'subtitle':
                '₱${amount.toStringAsFixed(2)} transferred from student $studentId',
            'amount': amount,
            'created_at': withdrawal['created_at'],
            'icon': Icons.account_balance_wallet,
            'color': Colors.purple,
          });
        }
      } catch (e) {
        print('DEBUG HomeTab: Error loading withdrawal transactions: $e');
      }

      // Get service withdrawal requests (withdrawal requests submitted by this service account)
      try {
        print(
          'DEBUG HomeTab: Fetching service withdrawal requests for service ID: $serviceId',
        );
        final withdrawalRequests = await SupabaseService.client
            .from('service_withdrawal_requests')
            .select('*')
            .eq('service_account_id', serviceId)
            .order('created_at', ascending: false)
            .limit(10);

        print(
          'DEBUG HomeTab: Service withdrawal requests found: ${withdrawalRequests.length}',
        );

        for (final request in (withdrawalRequests as List)) {
          final amount = (request['amount'] as num?)?.toDouble() ?? 0.0;
          final status = request['status']?.toString() ?? 'Pending';

          // Determine color and icon based on status
          Color statusColor;
          IconData statusIcon;
          String statusText;

          switch (status) {
            case 'Approved':
              statusColor = Colors.green;
              statusIcon = Icons.check_circle;
              statusText = 'Approved';
              break;
            case 'Rejected':
              statusColor = Colors.red;
              statusIcon = Icons.cancel;
              statusText = 'Rejected';
              break;
            default:
              statusColor = Colors.orange;
              statusIcon = Icons.pending;
              statusText = 'Pending';
          }

          activities.add({
            'id': request['id'],
            'type': 'service_withdrawal_request',
            'title': 'Withdrawal Request',
            'subtitle':
                '₱${amount.toStringAsFixed(2)} withdrawal request • Status: $statusText',
            'amount': amount,
            'status': status,
            'created_at': request['created_at'],
            'processed_at': request['processed_at'],
            'processed_by': request['processed_by'],
            'admin_notes': request['admin_notes'],
            'icon': statusIcon,
            'color': statusColor,
          });
        }
      } catch (e) {
        print('DEBUG HomeTab: Error loading service withdrawal requests: $e');
      }

      // Sort all activities by created_at (most recent first)
      activities.sort((a, b) {
        final aTime =
            DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      // Take only the 10 most recent activities for home tab
      if (mounted) {
        setState(() {
          _recentActivities = activities.take(10).toList();
          _isLoadingActivities = false;
        });
      }
    } catch (e) {
      print('DEBUG HomeTab: Error loading recent activities: $e');
      if (mounted) {
        setState(() {
          _isLoadingActivities = false;
        });
      }
    }
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    required bool isWeb,
    bool? isEnabledOverride,
  }) {
    final isEnabled = isEnabledOverride ?? (onTap != null);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isWeb ? 20 : 16),
        decoration: BoxDecoration(
          color: isEnabled ? Colors.white : Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          boxShadow:
              isEnabled
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : [],
        ),
        child: Column(
          children: [
            Container(
              width: isWeb ? 50 : 45,
              height: isWeb ? 50 : 45,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: isWeb ? 24 : 20),
            ),
            SizedBox(height: isWeb ? 12 : 10),
            Text(
              title,
              style: TextStyle(
                fontSize: isWeb ? 14 : 13,
                fontWeight: FontWeight.bold,
                color: isEnabled ? Colors.black : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isWeb ? 4 : 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: isWeb ? 12 : 11,
                color: isEnabled ? Colors.grey[600] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isWeb,
  }) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 16 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
            children: [
              Icon(icon, color: color, size: isWeb ? 18 : 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isWeb ? 12 : 11,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isWeb ? 8 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isWeb ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    dynamic createdAt, {
    Map<String, dynamic>? activityData,
  }) {
    final formattedCreatedAt = _formatCreatedAt(createdAt);
    return GestureDetector(
      onTap:
          activityData != null
              ? () => _showTransactionDetailModal(activityData)
              : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
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
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  if (formattedCreatedAt != 'N/A') ...[
                    const SizedBox(height: 2),
                    Text(
                      formattedCreatedAt,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ],
              ),
            ),
            if (activityData != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 16),
            ],
          ],
        ),
      ),
    );
  }

  /// Check if current time is within working hours (8am-5pm PH time)
  bool _isWithinWorkingHours() {
    // Get current time in PH timezone (UTC+8)
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final currentHour = now.hour;

    // Working hours: 8am (8) to 5pm (17)
    return currentHour >= 8 && currentHour < 23;
  }

  void _showWorkingHoursModal() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Working Hours Restriction',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Withdrawals are only available during working hours:\n\n'
              'Monday - Friday: 8:00 AM - 5:00 PM (PH Time)\n\n'
              'Please try again during these hours.',
              style: TextStyle(fontSize: 14),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> _navigateToWithdraw() async {
    // Check if within working hours
    if (!_isWithinWorkingHours()) {
      _showWorkingHoursModal();
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ServiceWithdrawScreen()),
    );

    // If withdrawal was successful, refresh the UI
    if (result == true && mounted) {
      // Refresh balance and recent activities
      final operationalType =
          SessionService.currentUserData?['operational_type']?.toString() ??
          'Main';
      if (operationalType == 'Main') {
        await _fetchInitialServiceBalance();
      }
      await _loadRecentActivities();
      setState(() {
        // This will refresh the balance display
      });
    }
  }

  void _showTopUpDialog() {
    final amounts = [50, 100, 200, 500, 1000];
    int? selectedAmount;
    final TextEditingController studentIdController = TextEditingController();
    final TextEditingController customAmountController =
        TextEditingController();
    String? studentIdError;
    String? studentName;
    String? customAmountError;
    bool isConfirmed = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              final screenWidth = MediaQuery.of(context).size.width;
              final isMobile = screenWidth < 600;
              final dialogWidth = isMobile ? screenWidth * 0.9 : 600.0;

              return Dialog(
                child: Container(
                  width: dialogWidth,
                  constraints: BoxConstraints(
                    maxWidth: 600,
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Top Up Student Balance',
                                style: TextStyle(
                                  fontSize: isMobile ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade900,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      // Content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Student ID Input
                              TextField(
                                controller: studentIdController,
                                decoration: InputDecoration(
                                  labelText: 'Student ID',
                                  border: const OutlineInputBorder(),
                                  errorText: studentIdError,
                                ),
                                onChanged: (value) async {
                                  if (value.isNotEmpty) {
                                    final result = await _validateStudentId(
                                      value,
                                    );
                                    setState(() {
                                      studentName = result['name'];
                                      studentIdError = result['error'];
                                      // Reset confirmation checkbox when student ID changes
                                      if (result['error'] != null) {
                                        isConfirmed = false;
                                      }
                                    });
                                  } else {
                                    setState(() {
                                      studentName = null;
                                      studentIdError = null;
                                      isConfirmed = false;
                                    });
                                  }
                                },
                              ),

                              if (studentName != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.green.shade50,
                                        Colors.green.shade100,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.green.shade300,
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.green.withOpacity(0.1),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: Colors.green,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Student Found:',
                                            style: TextStyle(
                                              fontSize: isMobile ? 12 : 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 36,
                                        ),
                                        child: Text(
                                          studentName ?? '',
                                          style: TextStyle(
                                            fontSize: isMobile ? 13 : 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.green.shade800,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),
                              const Text(
                                'Select Amount:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children:
                                    amounts.map((amount) {
                                      // Calculate fees based on commission settings
                                      final totalFeePercent =
                                          _vendorCommission + _adminCommission;
                                      final totalFee =
                                          amount * (totalFeePercent / 100);
                                      final studentReceives = amount - totalFee;

                                      // Vendor pays full amount, but earns back vendor commission
                                      final vendorEarn =
                                          amount * (_vendorCommission / 100);
                                      final vendorPays = amount - vendorEarn;

                                      return ChoiceChip(
                                        label: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('₱$amount'),
                                            if (selectedAmount == amount) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Student gets ₱${studentReceives.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              Text(
                                                'You pay ₱${vendorPays.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.orange,
                                                ),
                                              ),
                                              Text(
                                                'Fee: ₱${totalFee.toStringAsFixed(2)} (${totalFeePercent.toStringAsFixed(2)}%)',
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        selected: selectedAmount == amount,
                                        onSelected: (selected) {
                                          if (selected) {
                                            setState(() {
                                              selectedAmount = amount;
                                              customAmountController.clear();
                                              customAmountError = null;
                                            });
                                          }
                                        },
                                      );
                                    }).toList(),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Or Enter Custom Amount:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: customAmountController,
                                decoration: InputDecoration(
                                  labelText: 'Custom Amount',
                                  border: const OutlineInputBorder(),
                                  prefixText: '₱ ',
                                  errorText: customAmountError,
                                  helperText: 'Minimum amount: ₱50.00',
                                ),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                onChanged: (value) {
                                  setState(() {
                                    if (value.isNotEmpty) {
                                      // Clear predefined selection when custom amount is entered
                                      selectedAmount = null;
                                      final customAmount = double.tryParse(
                                        value,
                                      );
                                      if (customAmount == null ||
                                          customAmount <= 0) {
                                        customAmountError =
                                            'Please enter a valid amount greater than 0';
                                        isConfirmed = false;
                                      } else if (customAmount < 50) {
                                        customAmountError =
                                            'Minimum amount is ₱50.00';
                                        isConfirmed = false;
                                      } else {
                                        customAmountError = null;
                                      }
                                    } else {
                                      customAmountError = null;
                                    }
                                  });
                                },
                              ),
                              // Show commission breakdown for custom amount
                              if (customAmountController.text.isNotEmpty &&
                                  customAmountError == null) ...[
                                const SizedBox(height: 12),
                                Builder(
                                  builder: (context) {
                                    final customAmount =
                                        double.tryParse(
                                          customAmountController.text,
                                        ) ??
                                        0.0;
                                    if (customAmount < 50)
                                      return const SizedBox.shrink();

                                    // Calculate fees based on commission settings
                                    final totalFeePercent =
                                        _vendorCommission + _adminCommission;
                                    final totalFee =
                                        customAmount * (totalFeePercent / 100);
                                    final studentReceives =
                                        customAmount - totalFee;

                                    // Vendor pays full amount, but earns back vendor commission
                                    final vendorEarn =
                                        customAmount *
                                        (_vendorCommission / 100);
                                    final vendorPays =
                                        customAmount - vendorEarn;

                                    return Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.blue.shade300,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                color: Colors.blue.shade700,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                'Amount Breakdown',
                                                style: TextStyle(
                                                  fontSize: isMobile ? 13 : 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.blue.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          _buildBreakdownRow(
                                            'Requested Amount',
                                            '₱${customAmount.toStringAsFixed(2)}',
                                            Colors.black87,
                                          ),
                                          const SizedBox(height: 6),
                                          _buildBreakdownRow(
                                            'Student Receives',
                                            '₱${studentReceives.toStringAsFixed(2)}',
                                            Colors.green,
                                          ),
                                          const SizedBox(height: 6),
                                          _buildBreakdownRow(
                                            'You Pay (Net)',
                                            '₱${vendorPays.toStringAsFixed(2)}',
                                            Colors.orange,
                                          ),
                                          const SizedBox(height: 6),
                                          _buildBreakdownRow(
                                            'Total Fee',
                                            '₱${totalFee.toStringAsFixed(2)} (${totalFeePercent.toStringAsFixed(2)}%)',
                                            Colors.grey,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '• Vendor Commission: ${_vendorCommission.toStringAsFixed(2)}% (₱${vendorEarn.toStringAsFixed(2)})',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '• Admin Commission: ${_adminCommission.toStringAsFixed(2)}% (₱${(customAmount * (_adminCommission / 100)).toStringAsFixed(2)})',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // Footer with actions
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 20,
                          vertical: isMobile ? 12 : 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                        ),
                        child:
                            isMobile
                                ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton(
                                          onPressed:
                                              () => Navigator.pop(context),
                                          child: Text(
                                            'Cancel',
                                            style: TextStyle(
                                              fontSize: isMobile ? 12 : 14,
                                            ),
                                          ),
                                        ),
                                        if (studentName != null)
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                isConfirmed = !isConfirmed;
                                              });
                                            },
                                            icon: Icon(
                                              isConfirmed
                                                  ? Icons.check_circle
                                                  : Icons
                                                      .radio_button_unchecked,
                                              size: 14,
                                              color:
                                                  isConfirmed
                                                      ? Colors.green
                                                      : Colors.grey,
                                            ),
                                            label: Text(
                                              'Confirm',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    isConfirmed
                                                        ? Colors.green
                                                        : Colors.grey,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 6,
                                              ),
                                              minimumSize: const Size(0, 32),
                                              side: BorderSide(
                                                color:
                                                    isConfirmed
                                                        ? Colors.green
                                                        : Colors.grey,
                                                width: 1,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (studentName != null) ...[
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed:
                                              studentName != null &&
                                                      ((selectedAmount !=
                                                              null) ||
                                                          (customAmountController
                                                                  .text
                                                                  .isNotEmpty &&
                                                              customAmountError ==
                                                                  null &&
                                                              (double.tryParse(
                                                                        customAmountController
                                                                            .text,
                                                                      ) ??
                                                                      0) >=
                                                                  50)) &&
                                                      isConfirmed
                                                  ? () {
                                                    Navigator.pop(context);
                                                    final amountToTransfer =
                                                        selectedAmount ??
                                                        (double.tryParse(
                                                                  customAmountController
                                                                      .text,
                                                                ) ??
                                                                0)
                                                            .round();
                                                    _processStudentTopUp(
                                                      amountToTransfer,
                                                      studentIdController.text,
                                                      studentName!,
                                                    );
                                                  }
                                                  : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                studentName != null &&
                                                        ((selectedAmount !=
                                                                null) ||
                                                            (customAmountController
                                                                    .text
                                                                    .isNotEmpty &&
                                                                customAmountError ==
                                                                    null &&
                                                                (double.tryParse(
                                                                          customAmountController
                                                                              .text,
                                                                        ) ??
                                                                        0) >=
                                                                    50)) &&
                                                        isConfirmed
                                                    ? Colors.green
                                                    : Colors.grey,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                          ),
                                          child: Text(
                                            'Transfer',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                )
                                : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Small confirmation button
                                        if (studentName != null) ...[
                                          OutlinedButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                isConfirmed = !isConfirmed;
                                              });
                                            },
                                            icon: Icon(
                                              isConfirmed
                                                  ? Icons.check_circle
                                                  : Icons
                                                      .radio_button_unchecked,
                                              size: 14,
                                              color:
                                                  isConfirmed
                                                      ? Colors.green
                                                      : Colors.grey,
                                            ),
                                            label: Text(
                                              'Confirm',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color:
                                                    isConfirmed
                                                        ? Colors.green
                                                        : Colors.grey,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 8,
                                              ),
                                              side: BorderSide(
                                                color:
                                                    isConfirmed
                                                        ? Colors.green
                                                        : Colors.grey,
                                                width: 1,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        // Transfer button
                                        ElevatedButton(
                                          onPressed:
                                              studentName != null &&
                                                      ((selectedAmount !=
                                                              null) ||
                                                          (customAmountController
                                                                  .text
                                                                  .isNotEmpty &&
                                                              customAmountError ==
                                                                  null &&
                                                              (double.tryParse(
                                                                        customAmountController
                                                                            .text,
                                                                      ) ??
                                                                      0) >=
                                                                  50)) &&
                                                      isConfirmed
                                                  ? () {
                                                    Navigator.pop(context);
                                                    final amountToTransfer =
                                                        selectedAmount ??
                                                        (double.tryParse(
                                                                  customAmountController
                                                                      .text,
                                                                ) ??
                                                                0)
                                                            .round();
                                                    _processStudentTopUp(
                                                      amountToTransfer,
                                                      studentIdController.text,
                                                      studentName!,
                                                    );
                                                  }
                                                  : null,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                studentName != null &&
                                                        ((selectedAmount !=
                                                                null) ||
                                                            (customAmountController
                                                                    .text
                                                                    .isNotEmpty &&
                                                                customAmountError ==
                                                                    null &&
                                                                (double.tryParse(
                                                                          customAmountController
                                                                              .text,
                                                                        ) ??
                                                                        0) >=
                                                                    50)) &&
                                                        isConfirmed
                                                    ? Colors.green
                                                    : Colors.grey,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 20,
                                              vertical: 12,
                                            ),
                                          ),
                                          child: Text(
                                            'Transfer',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Future<Map<String, dynamic>> _validateStudentId(String studentId) async {
    try {
      final response =
          await SupabaseService.client
              .from('auth_students')
              .select('student_id, name')
              .eq('student_id', studentId)
              .maybeSingle();

      if (response == null) {
        return {'error': 'Student ID not found'};
      }

      // Decrypt the student name
      String studentName = response['name']?.toString() ?? '';

      try {
        // Check if the name looks encrypted and decrypt it
        if (EncryptionService.looksLikeEncryptedData(studentName)) {
          studentName = EncryptionService.decryptData(studentName);
        }
      } catch (e) {
        print('Failed to decrypt student name: $e');
        // Keep the original name if decryption fails
      }

      return {'name': studentName};
    } catch (e) {
      return {'error': 'Error validating student ID: $e'};
    }
  }

  Future<void> _processStudentTopUp(
    int amount,
    String studentId,
    String studentName,
  ) async {
    // Calculate amounts based on commission settings
    final totalFeePercent = _vendorCommission + _adminCommission;
    final totalFee = amount * (totalFeePercent / 100);
    final studentReceives =
        amount - totalFee; // Student receives amount minus total fee

    // Vendor commission and admin commission
    final vendorEarn = amount * (_vendorCommission / 100);
    final adminEarn = amount * (_adminCommission / 100);

    // Vendor pays full amount, but earns back vendor commission
    // Net vendor deduction = amount - vendor commission
    final vendorPays = amount - vendorEarn;

    final serviceAccountId = SessionService.currentUserData?['service_id'];
    if (serviceAccountId == null) {
      _showErrorSnackBar('Service account not found');
      return;
    }

    // Check service account balance
    final currentServiceBalance =
        double.tryParse(
          SessionService.currentUserData?['balance']?.toString() ?? '0',
        ) ??
        0.0;

    if (currentServiceBalance < vendorPays) {
      _showErrorSnackBar(
        'Insufficient balance. Need ₱${vendorPays.toStringAsFixed(2)} but have ₱${currentServiceBalance.toStringAsFixed(2)}',
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Processing transfer...'),
              ],
            ),
          ),
    );

    try {
      // Use the proper top-up transaction function that creates records in top_up_transactions table
      // Round values to 2 decimal places to match DECIMAL(10,2) in database
      final vendorEarnRounded = double.parse(vendorEarn.toStringAsFixed(2));
      final adminEarnRounded = double.parse(adminEarn.toStringAsFixed(2));
      final studentReceivesRounded = double.parse(
        studentReceives.toStringAsFixed(2),
      );

      print('DEBUG: Creating top-up transaction for studentId: "$studentId"');
      print(
        'DEBUG: Top-up details - Requested: ₱$amount, Student receives: ₱$studentReceivesRounded',
      );
      print(
        'DEBUG: Commission details - Vendor commission: ${_vendorCommission}% = ₱$vendorEarnRounded, Admin commission: ${_adminCommission}% = ₱$adminEarnRounded',
      );
      print('DEBUG: Vendor pays (net): ₱$vendorPays');

      // Get the service account username for processed_by field
      // Use username instead of service name to match the foreign key relationship
      final serviceUsername =
          SessionService.currentUserData?['username']?.toString() ??
          SessionService.currentUserData?['service_name']?.toString() ??
          'Service Account';
      final serviceName =
          SessionService.currentUserData?['service_name']?.toString() ??
          'Service Account';

      final topUpResult = await SupabaseService.client.rpc(
        'process_top_up_transaction',
        params: {
          'p_student_id': studentId,
          'p_amount':
              studentReceivesRounded, // Amount student receives (after fees)
          'p_processed_by':
              serviceUsername, // Use username to match foreign key
          'p_notes': 'Top-up from service account $serviceName',
          'p_transaction_type':
              'top_up_services', // Use top_up_services for service account top-ups
          'p_admin_earn':
              adminEarnRounded, // Admin commission earned (based on requested amount)
          'p_vendor_earn':
              vendorEarnRounded, // Vendor commission earned (based on requested amount)
        },
      );

      print('DEBUG: Top-up result: $topUpResult');

      if (topUpResult == null || topUpResult['success'] != true) {
        throw Exception(topUpResult?['message'] ?? 'Top-up transaction failed');
      }

      // Update service account balance
      // Vendor pays: amount - vendor commission (net deduction)
      final newServiceBalance = currentServiceBalance - vendorPays;
      await SupabaseService.client
          .from('service_accounts')
          .update({'balance': newServiceBalance})
          .eq('id', serviceAccountId);

      // Update local session data
      SessionService.currentUserData?['balance'] = newServiceBalance.toString();

      Navigator.pop(context); // Close loading dialog

      setState(() {}); // Refresh the UI
      _loadRecentActivities(); // Refresh recent activities

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Successfully transferred ₱${studentReceives.toStringAsFixed(2)} to $studentName.\n'
            'Your balance: ₱${newServiceBalance.toStringAsFixed(2)} (₱${vendorPays.toStringAsFixed(2)} deducted, ₱${vendorEarn.toStringAsFixed(2)} commission earned)',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      _showErrorSnackBar('Transfer failed: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showErrorModal(String errorMessage) {
    // Simplify error messages
    String simpleMessage = 'Failed to update profile';
    final errorLower = errorMessage.toLowerCase();

    if (errorLower.contains('password') && errorLower.contains('6')) {
      simpleMessage = 'Password must be at least 6 characters';
    } else if (errorLower.contains('password') &&
        errorLower.contains('match')) {
      simpleMessage = 'Passwords do not match';
    } else if (errorLower.contains('password') &&
        errorLower.contains('empty')) {
      simpleMessage = 'Please enter a new password';
    } else if (errorLower.contains('service account not found')) {
      simpleMessage = 'Service account not found';
    } else if (errorLower.contains('invalid service account')) {
      simpleMessage = 'Invalid service account ID';
    } else if (errorLower.contains('no changes')) {
      simpleMessage = 'No changes to update';
    } else if (errorLower.contains('failed to update')) {
      // Extract the actual error message after "Failed to update profile: "
      final parts = errorMessage.split(':');
      if (parts.length > 1) {
        simpleMessage = parts.last.trim();
      }
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 24),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to Update Profile',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Text(simpleMessage, style: const TextStyle(fontSize: 14)),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB91C1C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadAllTransactions() async {
    try {
      await SupabaseService.initialize();
      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString() ?? '0';
      final serviceId = int.tryParse(serviceIdStr) ?? 0;
      final operationalType =
          SessionService.currentUserData?['operational_type']?.toString() ??
          'Main';

      final List<Map<String, dynamic>> activities = [];

      // Get top-up transactions (where this service account processed top-ups)
      try {
        // Get the service account username for filtering
        final serviceUsername =
            SessionService.currentUserData?['username']?.toString();

        if (serviceUsername != null && serviceUsername.isNotEmpty) {
          final topUpTransactions = await SupabaseService.client
              .from('top_up_transactions')
              .select(
                'id, student_id, amount, created_at, processed_by, transaction_type',
              )
              .eq('processed_by', serviceUsername) // Filter by username
              .eq(
                'transaction_type',
                'top_up_services',
              ) // Only show service account top-ups
              .order('created_at', ascending: false)
              .limit(50); // Load more for history modal

          // Get service name from session data (since we're filtering by current service)
          final serviceName =
              SessionService.currentUserData?['service_name']?.toString() ??
              'Unknown Service';

          for (final transaction in topUpTransactions) {
            // Fetch student name from auth_students table
            String? studentName;
            try {
              final studentId = transaction['student_id']?.toString();
              if (studentId != null && studentId.isNotEmpty) {
                final studentRow =
                    await SupabaseService.client
                        .from('auth_students')
                        .select('name')
                        .eq('student_id', studentId)
                        .maybeSingle();
                if (studentRow != null) {
                  String name = studentRow['name']?.toString() ?? '';
                  if (EncryptionService.looksLikeEncryptedData(name)) {
                    name = EncryptionService.decryptData(name);
                  }
                  studentName = name;
                }
              }
            } catch (e) {
              print(
                'DEBUG HomeTab: Error fetching student name for history: $e',
              );
            }

            activities.add({
              'id': transaction['id'],
              'type': 'top_up',
              'title': 'Student Top-up',
              'subtitle':
                  'Topped up ₱${(transaction['amount'] as num).toStringAsFixed(2)} to student ${transaction['student_id']} • Processed by: $serviceName',
              'amount': transaction['amount'],
              'created_at':
                  transaction['created_at'], // Use actual transaction timestamp (UTC from Supabase)
              'student_name': studentName,
              'student_id': transaction['student_id']?.toString(),
              'icon': Icons.person_add,
              'color': Colors.green,
            });
          }
        }
      } catch (e) {
        print(
          'DEBUG HomeTab: Error loading top-up transactions for history: $e',
        );
      }

      // Get service transactions (payments made by students to this service)
      try {
        final serviceTransactions = await SupabaseService.client
            .from('service_transactions')
            .select(
              'id, student_id, total_amount, created_at, items, service_account_id, transaction_code, purpose, service_accounts!service_transactions_service_account_id_fkey(service_name, service_category)',
            )
            .or(
              operationalType == 'Main'
                  ? 'main_service_id.eq.${serviceId},service_account_id.eq.${serviceId}'
                  : 'service_account_id.eq.${serviceId}',
            )
            .order('created_at', ascending: false)
            .limit(50);

        for (final transaction in serviceTransactions) {
          final items = transaction['items'] as List?;
          final firstItem = items?.isNotEmpty == true ? items!.first : null;
          final itemName = firstItem?['name']?.toString() ?? 'Service Payment';
          final serviceName =
              (transaction['service_accounts']?['service_name']?.toString()) ??
              'Unknown Service';
          final transactionServiceCategory =
              transaction['service_accounts']?['service_category']
                  ?.toString() ??
              '';
          final transactionIsCampusServiceUnits =
              transactionServiceCategory == 'Campus Service Units';

          // Debug: Print transaction data to understand the structure
          print('DEBUG History: Transaction data: ${transaction.toString()}');
          print(
            'DEBUG History: Service accounts data: ${transaction['service_accounts']}',
          );
          print('DEBUG History: Service name extracted: $serviceName');

          activities.add({
            'id': transaction['id'],
            'transaction_code': transaction['transaction_code'],
            'purpose': transaction['purpose'],
            'is_campus_service_units': transactionIsCampusServiceUnits,
            'type': 'payment',
            'title': 'Payment Received',
            'subtitle':
                '₱${(transaction['total_amount'] as num).toStringAsFixed(2)} for $itemName from student ${transaction['student_id']} • Service: $serviceName',
            'amount': transaction['total_amount'],
            'created_at': transaction['created_at'],
            'icon': Icons.payment,
            'color': Colors.blue,
          });
        }
      } catch (e) {
        print(
          'DEBUG HomeTab: Error loading service transactions for history: $e',
        );
      }

      // Get withdrawal transactions (show entries where this service is origin or destination)
      try {
        print(
          'DEBUG HomeTab: Fetching withdrawal transactions for history (service ID: $serviceId)',
        );
        final withdrawalResult = await SupabaseService.adminClient
            .from('withdrawal_transactions')
            .select(
              'id, student_id, amount, created_at, transaction_type, metadata, destination_service_id',
            )
            .eq('destination_service_id', serviceId)
            .order('created_at', ascending: false)
            .limit(50); // Load more for history modal

        print(
          'DEBUG HomeTab: Withdrawal transactions (history) found: ${withdrawalResult.length}',
        );

        for (final withdrawal in (withdrawalResult as List)) {
          final amount = (withdrawal['amount'] as num?)?.toDouble() ?? 0.0;
          final studentId = withdrawal['student_id']?.toString() ?? 'Unknown';

          // Fetch student name
          String? studentName;
          try {
            if (studentId != 'Unknown') {
              final studentRow =
                  await SupabaseService.client
                      .from('auth_students')
                      .select('name')
                      .eq('student_id', studentId)
                      .maybeSingle();
              if (studentRow != null) {
                String name = studentRow['name']?.toString() ?? '';
                if (EncryptionService.looksLikeEncryptedData(name)) {
                  name = EncryptionService.decryptData(name);
                }
                if (name.isNotEmpty) studentName = name;
              }
            }
          } catch (_) {}

          final namePart = studentName != null ? ' • $studentName' : '';

          activities.add({
            'id': withdrawal['id'],
            'type': 'withdrawal',
            'title': 'Withdrawal',
            'subtitle':
                'Student $studentId$namePart • ₱${amount.toStringAsFixed(2)}',
            'amount': amount,
            'created_at': withdrawal['created_at'],
            'student_id': studentId,
            'student_name': studentName,
            'icon': Icons.account_balance_wallet,
            'color': Colors.purple,
          });
        }
      } catch (e) {
        print(
          'DEBUG HomeTab: Error loading withdrawal transactions for history: $e',
        );
      }

      // Get service withdrawal requests (withdrawal requests submitted by this service account)
      try {
        print(
          'DEBUG HomeTab: Fetching service withdrawal requests for history (service ID: $serviceId)',
        );
        final withdrawalRequests = await SupabaseService.client
            .from('service_withdrawal_requests')
            .select('*')
            .eq('service_account_id', serviceId)
            .order('created_at', ascending: false)
            .limit(50); // Load more for history modal

        print(
          'DEBUG HomeTab: Service withdrawal requests (history) found: ${withdrawalRequests.length}',
        );

        for (final request in (withdrawalRequests as List)) {
          final amount = (request['amount'] as num?)?.toDouble() ?? 0.0;
          final status = request['status']?.toString() ?? 'Pending';

          // Determine color and icon based on status
          Color statusColor;
          IconData statusIcon;
          String statusText;

          switch (status) {
            case 'Approved':
              statusColor = Colors.green;
              statusIcon = Icons.check_circle;
              statusText = 'Approved';
              break;
            case 'Rejected':
              statusColor = Colors.red;
              statusIcon = Icons.cancel;
              statusText = 'Rejected';
              break;
            default:
              statusColor = Colors.orange;
              statusIcon = Icons.pending;
              statusText = 'Pending';
          }

          activities.add({
            'id': request['id'],
            'type': 'service_withdrawal_request',
            'title': 'Withdrawal Request',
            'subtitle':
                '₱${amount.toStringAsFixed(2)} withdrawal request • Status: $statusText',
            'amount': amount,
            'status': status,
            'created_at': request['created_at'],
            'processed_at': request['processed_at'],
            'processed_by': request['processed_by'],
            'admin_notes': request['admin_notes'],
            'icon': statusIcon,
            'color': statusColor,
          });
        }
      } catch (e) {
        print(
          'DEBUG HomeTab: Error loading service withdrawal requests for history: $e',
        );
      }

      // Sort all activities by created_at (most recent first)
      activities.sort((a, b) {
        final aTime =
            DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTime =
            DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

      return activities;
    } catch (e) {
      print('DEBUG HomeTab: Error loading all transactions: $e');
      return [];
    }
  }

  void _showTransactionHistory() {
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setState) {
              final screenSize = MediaQuery.of(context).size;
              final isSmallScreen = screenSize.width < 600;

              return Dialog(
                insetPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 16 : 32,
                  vertical: isSmallScreen ? 16 : 32,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: screenSize.width * (isSmallScreen ? 0.95 : 0.9),
                    maxHeight: screenSize.height * (isSmallScreen ? 0.9 : 0.8),
                  ),
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Transaction History',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
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
                        SizedBox(height: isSmallScreen ? 12 : 16),

                        // Loading or Content
                        Expanded(
                          child: FutureBuilder<List<Map<String, dynamic>>>(
                            future: _loadAllTransactions(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (snapshot.hasError) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'Error loading transactions: ${snapshot.error}',
                                      style: const TextStyle(color: Colors.red),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }

                              final activities = snapshot.data ?? [];

                              if (activities.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'No transaction history found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }

                              return ListView.builder(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: activities.length,
                                itemBuilder: (context, index) {
                                  final activity = activities[index];
                                  return _buildActivityItem(
                                    activity['title'] as String,
                                    activity['subtitle'] as String,
                                    activity['icon'] as IconData,
                                    activity['color'] as Color,
                                    activity['created_at']?.toString(),
                                    activityData: activity,
                                  );
                                },
                              );
                            },
                          ),
                        ),

                        // Footer
                        SizedBox(height: isSmallScreen ? 12 : 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }

  void _showProfileSettingsDialog() {
    final currentData = SessionService.currentUserData;

    final serviceNameController = TextEditingController(
      text: currentData?['service_name']?.toString() ?? '',
    );
    final contactPersonController = TextEditingController(
      text: currentData?['contact_person']?.toString() ?? '',
    );
    final phoneController = TextEditingController(
      text: currentData?['phone']?.toString() ?? '',
    );
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool showPassword = false;
    bool showConfirmPassword = false;
    bool isUpdating = false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
                  title: const Text('Profile Settings'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Service Name
                        TextField(
                          controller: serviceNameController,
                          decoration: const InputDecoration(
                            labelText: 'Service Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Contact Person
                        TextField(
                          controller: contactPersonController,
                          decoration: const InputDecoration(
                            labelText: 'Contact Person',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Phone
                        TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextField(
                          controller: passwordController,
                          obscureText: !showPassword,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'New Password (optional)',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  showPassword = !showPassword;
                                });
                              },
                            ),
                            helperText:
                                passwordController.text.isNotEmpty
                                    ? 'Password must be at least 6 characters'
                                    : null,
                            helperMaxLines: 2,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Confirm Password
                        TextField(
                          controller: confirmPasswordController,
                          obscureText: !showConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                showConfirmPassword
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  showConfirmPassword = !showConfirmPassword;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Password validation note
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Password Requirements:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• Minimum 6 characters required',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '• Leave password fields empty to keep current password unchanged',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isUpdating ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed:
                          isUpdating
                              ? null
                              : () async {
                                setState(() {
                                  isUpdating = true;
                                });

                                try {
                                  await _updateProfile(
                                    serviceName:
                                        serviceNameController.text.trim(),
                                    contactPerson:
                                        contactPersonController.text.trim(),
                                    phone: phoneController.text.trim(),
                                    newPassword: passwordController.text.trim(),
                                    confirmPassword:
                                        confirmPasswordController.text.trim(),
                                  );
                                  Navigator.pop(context);
                                } catch (e) {
                                  _showErrorModal(e.toString());
                                } finally {
                                  setState(() {
                                    isUpdating = false;
                                  });
                                }
                              },
                      child:
                          isUpdating
                              ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('Update Profile'),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _updateProfile({
    required String serviceName,
    required String contactPerson,
    required String phone,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      // Validate password if provided
      if (newPassword.isNotEmpty || confirmPassword.isNotEmpty) {
        if (newPassword.isEmpty) {
          throw Exception('Please enter a new password');
        }
        if (newPassword.length < 6) {
          throw Exception(
            'Password must be at least 6 characters long. Please enter a stronger password.',
          );
        }
        if (newPassword != confirmPassword) {
          throw Exception(
            'Passwords do not match. Please ensure both passwords are identical.',
          );
        }
      }

      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString();
      if (serviceIdStr == null || serviceIdStr.isEmpty) {
        throw Exception('Service account not found');
      }

      final serviceId = int.tryParse(serviceIdStr);
      if (serviceId == null) {
        throw Exception('Invalid service account ID');
      }

      // Prepare update data - only include non-empty fields
      Map<String, dynamic> updateData = {};

      if (serviceName.isNotEmpty) {
        updateData['service_name'] = serviceName;
      }
      if (contactPerson.isNotEmpty) {
        updateData['contact_person'] = contactPerson;
      }
      if (phone.isNotEmpty) {
        updateData['phone'] = phone;
      }

      // Handle password update if provided
      if (newPassword.isNotEmpty) {
        // Import the encryption service for password hashing
        updateData['password_hash'] = EncryptionService.hashPassword(
          newPassword,
        );
      }

      if (updateData.isEmpty) {
        throw Exception('No changes to update');
      }

      // Update the service account
      final result = await SupabaseService.updateServiceAccount(
        accountId: serviceId,
        serviceName: updateData['service_name'],
        contactPerson: updateData['contact_person'],
        phone: updateData['phone'],
        passwordHash: updateData['password_hash'],
      );

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Failed to update profile');
      }

      // Update local session data
      if (serviceName.isNotEmpty) {
        SessionService.currentUserData?['service_name'] = serviceName;
      }
      if (contactPerson.isNotEmpty) {
        SessionService.currentUserData?['contact_person'] = contactPerson;
      }
      if (phone.isNotEmpty) {
        SessionService.currentUserData?['phone'] = phone;
      }

      // Refresh the UI
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('DEBUG HomeTab: Profile update error: $e');
      rethrow;
    }
  }

  void _showTransactionDetailModal(Map<String, dynamic> activity) async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch actual transaction data based on activity type
      final transactionData = await _fetchServiceTransactionData(activity);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show transaction details modal
      showDialog(
        context: context,
        builder: (context) {
          final screenSize = MediaQuery.of(context).size;
          final isSmallScreen = screenSize.width < 600;

          return Dialog(
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
                            _getTransactionTitle(transactionData?['type']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Transaction Details',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Transaction Details
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Transaction ID or Transaction Code
                          _buildReceiptRow(
                            'Transaction ${_shouldUseTransactionCode(activity) ? "Code" : "ID"}',
                            _getTransactionIdentifier(
                              transactionData,
                              activity,
                            ),
                          ),

                          // Amount
                          if (activity['amount'] != null)
                            _buildReceiptRow(
                              'Amount',
                              '₱${(activity['amount'] as num).toStringAsFixed(2)}',
                              isAmount: true,
                            ),

                          // Date and Time
                          _buildReceiptRow(
                            'Date & Time',
                            _formatCreatedAt(activity['created_at']),
                          ),

                          // Additional transaction-specific details
                          ..._buildTransactionDetails(transactionData),

                          const SizedBox(height: 20),

                          // Close button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFB91C1C),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
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
          );
        },
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load transaction details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _fetchServiceTransactionData(
    Map<String, dynamic> activity,
  ) async {
    try {
      final transactionId = activity['id'];
      final transactionType = activity['type'];

      if (transactionId == null) return null;

      switch (transactionType) {
        case 'payment':
          {
            // Fetch service transaction details with service name and category
            final result =
                await SupabaseService.client
                    .from('service_transactions')
                    .select(
                      '*, service_accounts!service_transactions_service_account_id_fkey(service_name, service_category)',
                    )
                    .eq('id', transactionId)
                    .single();

            // Add service name and category to result
            if (result['service_accounts'] != null) {
              result['service_name'] =
                  result['service_accounts']['service_name']?.toString() ??
                  'Unknown Service';
              result['service_category'] =
                  result['service_accounts']['service_category']?.toString() ??
                  '';
            } else {
              result['service_name'] = 'Unknown Service';
              result['service_category'] = '';
            }

            // Attempt to fetch and decrypt student name
            try {
              final studentId = result['student_id']?.toString();
              if (studentId != null && studentId.isNotEmpty) {
                final studentRow =
                    await SupabaseService.client
                        .from('auth_students')
                        .select('name')
                        .eq('student_id', studentId)
                        .maybeSingle();
                if (studentRow != null) {
                  String studentName = studentRow['name']?.toString() ?? '';
                  if (EncryptionService.looksLikeEncryptedData(studentName)) {
                    studentName = EncryptionService.decryptData(studentName);
                  }
                  result['student_name'] = studentName;
                }
              }
            } catch (_) {}

            result['student_name'] ??= activity['student_name'];
            result['student_id'] ??=
                activity['student_id']?.toString() ?? activity['student_id'];

            return {
              'type': 'service_payment',
              'data': result,
              'id': transactionId,
            };
          }

        case 'top_up':
          {
            // Fetch top-up transaction details
            final result =
                await SupabaseService.client
                    .from('top_up_transactions')
                    .select('*')
                    .eq('id', transactionId)
                    .single();

            // For service account top-ups, fetch service name from service_accounts table
            final processedBy = result['processed_by']?.toString();
            final transactionType = result['transaction_type']?.toString();

            if (transactionType == 'top_up_services' && processedBy != null) {
              try {
                // Try to get service name from service_accounts table
                final serviceAccount =
                    await SupabaseService.client
                        .from('service_accounts')
                        .select('service_name, username')
                        .eq('username', processedBy)
                        .maybeSingle();

                if (serviceAccount != null) {
                  result['service_name'] =
                      serviceAccount['service_name']?.toString() ??
                      serviceAccount['username']?.toString() ??
                      processedBy;
                } else {
                  result['service_name'] = processedBy;
                }
              } catch (_) {
                // If lookup fails, use processed_by as fallback
                result['service_name'] = processedBy;
              }
            } else {
              // For admin or other transactions, use processed_by as is
              result['service_name'] = processedBy ?? 'Unknown Service';
            }

            // Attempt to fetch and decrypt student name
            try {
              final studentId = result['student_id']?.toString();
              if (studentId != null && studentId.isNotEmpty) {
                final studentRow =
                    await SupabaseService.client
                        .from('auth_students')
                        .select('name')
                        .eq('student_id', studentId)
                        .maybeSingle();
                if (studentRow != null) {
                  String studentName = studentRow['name']?.toString() ?? '';
                  if (EncryptionService.looksLikeEncryptedData(studentName)) {
                    studentName = EncryptionService.decryptData(studentName);
                  }
                  result['student_name'] = studentName;
                }
              }
            } catch (_) {}

            result['student_name'] ??= activity['student_name'];
            result['student_id'] ??=
                activity['student_id']?.toString() ?? activity['student_id'];

            return {'type': 'top_up', 'data': result, 'id': transactionId};
          }

        case 'withdrawal':
          {
            // Fetch withdrawal transaction details
            final result =
                await SupabaseService.adminClient
                    .from('withdrawal_transactions')
                    .select('*')
                    .eq('id', transactionId)
                    .single();

            // Attempt to fetch and decrypt student name
            try {
              final studentId = result['student_id']?.toString();
              if (studentId != null && studentId.isNotEmpty) {
                final studentRow =
                    await SupabaseService.client
                        .from('auth_students')
                        .select('name')
                        .eq('student_id', studentId)
                        .maybeSingle();
                if (studentRow != null) {
                  String studentName = studentRow['name']?.toString() ?? '';
                  if (EncryptionService.looksLikeEncryptedData(studentName)) {
                    studentName = EncryptionService.decryptData(studentName);
                  }
                  result['student_name'] = studentName;
                }
              }
            } catch (_) {}

            return {'type': 'withdrawal', 'data': result, 'id': transactionId};
          }

        case 'service_withdrawal_request':
          {
            // Fetch service withdrawal request details
            final result =
                await SupabaseService.client
                    .from('service_withdrawal_requests')
                    .select('*')
                    .eq('id', transactionId)
                    .single();

            // Fetch service account name
            try {
              final serviceAccountId = result['service_account_id'];
              if (serviceAccountId != null) {
                final serviceRow =
                    await SupabaseService.client
                        .from('service_accounts')
                        .select('service_name')
                        .eq('id', serviceAccountId)
                        .maybeSingle();
                if (serviceRow != null) {
                  result['service_name'] =
                      serviceRow['service_name']?.toString() ??
                      'Unknown Service';
                }
              }
            } catch (_) {}

            return {
              'type': 'service_withdrawal_request',
              'data': result,
              'id': transactionId,
            };
          }

        default:
          return null;
      }
    } catch (e) {
      print('Error fetching service transaction data: $e');
      return null;
    }
  }

  String _getTransactionTitle(String? transactionType) {
    switch (transactionType?.toLowerCase()) {
      case 'top_up':
        return 'Top-up Transaction';
      case 'service_payment':
        return 'Service Payment';
      case 'withdrawal':
        return 'Balance Transfer Received';
      case 'service_withdrawal_request':
        return 'Withdrawal Request';
      default:
        return 'Transaction';
    }
  }

  List<Widget> _buildTransactionDetails(Map<String, dynamic>? transactionData) {
    if (transactionData == null) return [];

    final data = transactionData['data'] as Map<String, dynamic>?;
    if (data == null) return [];

    final transactionType = transactionData['type'] as String?;
    final List<Widget> details = [];

    switch (transactionType?.toLowerCase()) {
      case 'top_up':
        // Display order: Student Name, Student ID, Amount, Date/Time
        if (data['student_name'] != null &&
            (data['student_name'] as String).isNotEmpty) {
          details.add(
            _buildReceiptRow('Student Name', data['student_name'] as String),
          );
        }
        details.add(
          _buildReceiptRow(
            'Student ID',
            data['student_id']?.toString() ?? 'N/A',
          ),
        );
        details.add(
          _buildReceiptRow(
            'Amount',
            '₱${_safeParseNumber(data['amount']).toStringAsFixed(2)}',
            isAmount: true,
          ),
        );
        // Date/Time is already shown in the main receipt section, so we don't duplicate it here
        if (data['processed_by'] != null) {
          details.add(
            _buildReceiptRow('Processed By', data['processed_by'].toString()),
          );
        }
        if (data['service_name'] != null) {
          details.add(
            _buildReceiptRow('Service Name', data['service_name'].toString()),
          );
        }
        break;

      case 'service_payment':
        details.add(
          _buildReceiptRow(
            'Student ID',
            data['student_id']?.toString() ?? 'N/A',
          ),
        );
        if (data['student_name'] != null &&
            (data['student_name'] as String).isNotEmpty) {
          details.add(
            _buildReceiptRow('Student Name', data['student_name'] as String),
          );
        }
        details.add(
          _buildReceiptRow(
            'Total Amount',
            '₱${_safeParseNumber(data['total_amount']).toStringAsFixed(2)}',
          ),
        );

        // Add purpose for Campus Service Units transactions
        final serviceCategory = data['service_category']?.toString() ?? '';
        final isCampusServiceUnits = serviceCategory == 'Campus Service Units';
        if (isCampusServiceUnits && data['purpose'] != null) {
          final purpose = data['purpose']?.toString();
          if (purpose != null && purpose.isNotEmpty) {
            details.add(_buildReceiptRow('Purpose of Payment', purpose));
          }
        }

        // Add service name
        if (data['service_name'] != null) {
          details.add(
            _buildReceiptRow('Service Name', data['service_name'].toString()),
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

      case 'withdrawal':
        details.add(
          _buildReceiptRow(
            'Student ID',
            data['student_id']?.toString() ?? 'N/A',
          ),
        );
        if (data['student_name'] != null &&
            (data['student_name'] as String).isNotEmpty) {
          details.add(
            _buildReceiptRow('Student Name', data['student_name'] as String),
          );
        }
        details.add(
          _buildReceiptRow(
            'Transfer Amount',
            '₱${_safeParseNumber(data['amount']).toStringAsFixed(2)}',
          ),
        );
        details.add(
          _buildReceiptRow(
            'Transfer Type',
            data['transaction_type']?.toString() ?? 'Withdraw to Service',
          ),
        );

        final metadata = data['metadata'] as Map<String, dynamic>?;
        if (metadata != null && metadata['destination_service_name'] != null) {
          details.add(
            _buildReceiptRow(
              'Destination Service',
              metadata['destination_service_name'].toString(),
            ),
          );
        }
        break;

      case 'service_withdrawal_request':
        // Display service withdrawal request details
        if (data['service_name'] != null) {
          details.add(
            _buildReceiptRow('Service Name', data['service_name'].toString()),
          );
        }
        details.add(
          _buildReceiptRow(
            'Withdrawal Amount',
            '₱${_safeParseNumber(data['amount']).toStringAsFixed(2)}',
            isAmount: true,
          ),
        );
        details.add(
          _buildReceiptRow(
            'Status',
            data['status']?.toString() ?? 'Pending',
            statusColor: _getStatusColor(data['status']?.toString()),
          ),
        );
        if (data['processed_at'] != null) {
          details.add(
            _buildReceiptRow(
              'Processed At',
              _formatCreatedAt(data['processed_at']),
            ),
          );
        }
        if (data['processed_by'] != null) {
          details.add(
            _buildReceiptRow('Processed By', data['processed_by'].toString()),
          );
        }
        if (data['admin_notes'] != null &&
            (data['admin_notes'] as String).isNotEmpty) {
          details.add(
            _buildReceiptRow('Admin Notes', data['admin_notes'].toString()),
          );
        }
        break;
    }

    return details;
  }

  Color? _getStatusColor(String? status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Pending':
        return Colors.orange;
      default:
        return null;
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

  double _safeParseNumber(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Widget _buildBreakdownRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Check if transaction code should be used instead of transaction ID
  bool _shouldUseTransactionCode(Map<String, dynamic> activity) {
    // Check if this is a payment transaction and if it's from Campus Service Units
    if (activity['type'] == 'payment') {
      final isCampusServiceUnits = activity['is_campus_service_units'] == true;
      return isCampusServiceUnits;
    }
    return false;
  }

  /// Get transaction identifier (code for Campus Service Units, ID for others)
  String _getTransactionIdentifier(
    Map<String, dynamic>? transactionData,
    Map<String, dynamic> activity,
  ) {
    // For payment transactions from Campus Service Units, use transaction_code
    if (_shouldUseTransactionCode(activity)) {
      final transactionCode =
          activity['transaction_code']?.toString() ??
          transactionData?['data']?['transaction_code']?.toString();
      if (transactionCode != null && transactionCode.isNotEmpty) {
        return transactionCode;
      }
    }

    // For all other cases, use transaction ID
    final transactionId =
        transactionData?['id']?.toString() ?? activity['id']?.toString();
    if (transactionId != null) {
      return '#${transactionId.padLeft(8, '0')}';
    }
    return 'N/A';
  }
}
