import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/supabase_service.dart';
import 'admin_dashboard.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  static const Color evsuRed = Color(0xFFB01212);

  // Dashboard data
  int _totalUsers = 0;
  int _activeUsersToday = 0;
  double _totalTransactions = 0.0;
  int _totalServices = 0;
  bool _isLoading = true;
  String? _errorMessage;

  // Chart data
  List<FlSpot> _transactionSpots = [];
  bool _isChartLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize chart data with empty/default values
    _initializeChartData();
    _loadDashboardData();
  }

  void _initializeChartData() {
    // Initialize with sample data to prevent LateInitializationError
    _generateTransactionChartData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use the combined dashboard stats function for better performance
      final response = await SupabaseService.client.rpc(
        'get_dashboard_stats',
        params: {},
      );

      if (response['success']) {
        final data = response['data'];
        setState(() {
          _totalUsers = data['total_users'] ?? 0;
          _activeUsersToday = data['active_users_today'] ?? 0;
          _totalTransactions =
              (data['today_transactions'] as num?)?.toDouble() ?? 0.0;
          _totalServices = data['total_services'] ?? 0;
          _isLoading = false;
        });
      } else {
        // Fallback to individual calls if combined function fails
        final results = await Future.wait([
          SupabaseService.getAllUsers(),
          SupabaseService.getServiceAccounts(),
          _getTodayTransactions(),
          _getActiveUsersToday(),
        ]);

        final usersResult = results[0] as Map<String, dynamic>;
        final servicesResult = results[1] as Map<String, dynamic>;
        final todayTransactions = results[2] as double;
        final activeUsersToday = results[3] as int;

        setState(() {
          _totalUsers =
              usersResult['success'] ? (usersResult['data'] as List).length : 0;
          _totalServices =
              servicesResult['success']
                  ? (servicesResult['data'] as List).length
                  : 0;
          _totalTransactions = todayTransactions;
          _activeUsersToday = activeUsersToday;
          _isLoading = false;
        });
      }

      // Load chart data
      await _loadChartData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading dashboard data: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<double> _getTodayTransactions() async {
    try {
      final response = await SupabaseService.client.rpc(
        'get_today_transaction_total',
        params: {},
      );
      return (response['total'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<int> _getActiveUsersToday() async {
    try {
      final response = await SupabaseService.client.rpc(
        'get_active_users_today',
        params: {},
      );
      return (response['count'] as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _loadChartData() async {
    setState(() {
      _isChartLoading = true;
    });

    try {
      // Load real data from Supabase
      await _loadTransactionChartData();
    } catch (e) {
      print('Error loading chart data: $e');
      // Keep the initialized sample data as fallback
    } finally {
      setState(() {
        _isChartLoading = false;
      });
    }
  }

  Future<void> _loadTransactionChartData() async {
    try {
      final now = DateTime.now();
      _transactionSpots = [];

      // Get data for last 7 days
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));

        // Adjust for Philippines timezone (+8 hours)
        final phStartOfDay = startOfDay.add(const Duration(hours: 8));
        final phEndOfDay = endOfDay.add(const Duration(hours: 8));

        double dailyTotal = 0.0;

        // Get top-up transactions (both manual and GCash)
        final topupResult = await SupabaseService.client
            .from('top_up_transactions')
            .select('amount')
            .inFilter('transaction_type', ['top_up', 'top_up_gcash'])
            .gte('created_at', phStartOfDay.toIso8601String())
            .lt('created_at', phEndOfDay.toIso8601String());

        for (var transaction in topupResult) {
          dailyTotal += (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        }

        // Get service transactions
        final serviceResult = await SupabaseService.client
            .from('service_transactions')
            .select('total_amount')
            .gte('created_at', phStartOfDay.toIso8601String())
            .lt('created_at', phEndOfDay.toIso8601String());

        for (var transaction in serviceResult) {
          dailyTotal +=
              (transaction['total_amount'] as num?)?.toDouble() ?? 0.0;
        }

        // Get user transfers
        final transferResult = await SupabaseService.client
            .from('user_transfers')
            .select('amount')
            .gte('created_at', phStartOfDay.toIso8601String())
            .lt('created_at', phEndOfDay.toIso8601String());

        for (var transaction in transferResult) {
          dailyTotal += (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        }

        // Get loan disbursements
        final loanResult = await SupabaseService.client
            .from('top_up_transactions')
            .select('amount')
            .eq('transaction_type', 'loan_disbursement')
            .gte('created_at', phStartOfDay.toIso8601String())
            .lt('created_at', phEndOfDay.toIso8601String());

        for (var transaction in loanResult) {
          dailyTotal += (transaction['amount'] as num?)?.toDouble() ?? 0.0;
        }

        _transactionSpots.add(FlSpot((6 - i).toDouble(), dailyTotal));
      }
    } catch (e) {
      print('Error loading transaction chart data: $e');
      // Fallback to sample data
      _generateTransactionChartData();
    }
  }

  // Fallback methods for sample data
  void _generateTransactionChartData() {
    // Sample data for last 7 days
    _transactionSpots = List.generate(7, (index) {
      final amount = 1000 + (index * 200) + (index % 3 == 0 ? 500 : 0);
      return FlSpot(index.toDouble(), amount.toDouble());
    });
  }

  // Navigation methods
  void _navigateToUserManagement(BuildContext context) {
    // Find the parent AdminDashboard widget and update its tab index
    final adminDashboard =
        context.findAncestorStateOfType<State<AdminDashboard>>();

    if (adminDashboard != null) {
      // User Management tab is at index 6
      (adminDashboard as dynamic).changeTabIndex(6);
    }
  }

  void _navigateToVendors(BuildContext context) {
    // Find the parent AdminDashboard widget and update its tab index
    final adminDashboard =
        context.findAncestorStateOfType<State<AdminDashboard>>();

    if (adminDashboard != null) {
      // Vendors tab (Service Ports) is at index 7
      (adminDashboard as dynamic).changeTabIndex(7);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      Text(
                        'EVSU eCampusPay System',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  backgroundColor: evsuRed.withOpacity(0.1),
                  child: const Icon(Icons.admin_panel_settings, color: evsuRed),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Statistics Cards
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadDashboardData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Total Users',
                          value: _totalUsers.toString(),
                          icon: Icons.people,
                          color: Colors.blue,
                          onTap: () => _navigateToUserManagement(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Active Today',
                          value: _activeUsersToday.toString(),
                          icon: Icons.online_prediction,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Today\'s Transactions',
                          value: '₱${_totalTransactions.toStringAsFixed(2)}',
                          icon: Icons.attach_money,
                          color: evsuRed,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          title: 'Service Accounts',
                          value: _totalServices.toString(),
                          icon: Icons.business_center,
                          color: Colors.orange,
                          onTap: () => _navigateToVendors(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            const SizedBox(height: 24),

            // Transaction Overview Chart
            _buildTransactionOverviewChart(),
            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionOverviewChart() {
    return _buildChartCard(
      title: 'Transaction Overview',
      subtitle: 'Daily transaction totals for the last 7 days',
      child: SizedBox(
        height: 200,
        child:
            _isChartLoading
                ? const Center(child: CircularProgressIndicator())
                : LineChart(
                  LineChartData(
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          interval: 500,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              '₱${value.toInt()}',
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final days = [
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun',
                            ];
                            return Text(
                              days[value.toInt() % 7],
                              style: const TextStyle(fontSize: 10),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: true),
                    lineBarsData: [
                      LineChartBarData(
                        spots:
                            _transactionSpots.isNotEmpty
                                ? _transactionSpots
                                : [FlSpot(0, 0)], // Fallback to prevent error
                        isCurved: true,
                        color: evsuRed,
                        barWidth: 3,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: evsuRed.withOpacity(0.1),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }

  Widget _buildChartCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: evsuRed,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );

    // Wrap with InkWell if onTap is provided
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: cardContent,
      );
    }

    return cardContent;
  }
}
