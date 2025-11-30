import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/animation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/supabase_service.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  static const Color evsuRed = Color(0xFFB01212);
  String _selectedPeriod = 'Daily';
  final List<String> _periods = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
  final List<String> _monthNames = const [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  bool _loading = false;
  double _topUpIncome = 0.0;
  double _loanIncome = 0.0;
  double _totalIncome = 0.0;
  int _topupCount = 0;
  int _loanDisbursementCount = 0;
  double _manualTopUpTotal = 0.0;
  double _gcashTopUpTotal = 0.0;
  int _manualTopUpCount = 0;
  int _gcashTopUpCount = 0;

  // Balance overview data
  double _totalStudentBalance = 0.0;
  double _totalServiceBalance = 0.0;
  double _totalSystemBalance = 0.0;
  int _studentCount = 0;
  int _serviceCount = 0;
  bool _balanceLoading = false;

  // Analysis data
  List<Map<String, dynamic>> _topupAnalysis = [];
  List<Map<String, dynamic>> _loanAnalysis = [];
  List<Map<String, dynamic>> _vendorTransactionCount = [];
  bool _analysisLoading = false;
  bool _exportingExcel = false;
  late int _selectedMonth;
  late int _selectedMonthYear;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedMonthYear = now.year;
    _selectedYear = now.year;
    _loadIncome();
    _loadBalanceOverview();
    _loadAnalysisData();
  }

  Future<void> _loadIncome() async {
    setState(() => _loading = true);
    try {
      await SupabaseService.initialize();
      final range = _getDateRangeFor(_selectedPeriod);
      final DateTime? rangeStart = range['start'];
      final DateTime? rangeEnd = range['end'];

      // Fetch top-up transactions within the selected range
      var topupQuery = SupabaseService.client
          .from('top_up_transactions')
          .select('admin_earn, transaction_type, amount, created_at');
      if (rangeStart != null) {
        topupQuery = topupQuery.gte('created_at', rangeStart.toIso8601String());
      }
      if (rangeEnd != null) {
        topupQuery = topupQuery.lt('created_at', rangeEnd.toIso8601String());
      }
      final List<dynamic> topupRows = await topupQuery;

      double topUpIncome = 0.0;
      int topupCount = topupRows.length;
      double manualTopUpTotal = 0.0;
      double gcashTopUpTotal = 0.0;
      int manualTopUpCount = 0;
      int gcashTopUpCount = 0;

      for (final row in topupRows) {
        final adminEarn = (row['admin_earn'] as num?)?.toDouble() ?? 0.0;
        topUpIncome += adminEarn;

        final transactionType = row['transaction_type']?.toString() ?? '';
        final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;

        if (transactionType == 'top_up') {
          manualTopUpTotal += amount;
          manualTopUpCount += 1;
        } else if (transactionType == 'top_up_gcash') {
          gcashTopUpTotal += amount;
          gcashTopUpCount += 1;
        }
      }

      // Fetch loan data within the selected range
      var loanQuery = SupabaseService.client
          .from('active_loans')
          .select('interest_amount, created_at');
      if (rangeStart != null) {
        loanQuery = loanQuery.gte('created_at', rangeStart.toIso8601String());
      }
      if (rangeEnd != null) {
        loanQuery = loanQuery.lt('created_at', rangeEnd.toIso8601String());
      }
      final List<dynamic> loanRows = await loanQuery;

      double loanIncome = 0.0;
      for (final loan in loanRows) {
        loanIncome += (loan['interest_amount'] as num?)?.toDouble() ?? 0.0;
      }
      final int loanDisbursementCount = loanRows.length;

      final double totalIncome = topUpIncome + loanIncome;

      if (mounted) {
        setState(() {
          _topUpIncome = topUpIncome;
          _loanIncome = loanIncome;
          _totalIncome = totalIncome;
          _topupCount = topupCount;
          _loanDisbursementCount = loanDisbursementCount;
          _manualTopUpTotal = manualTopUpTotal;
          _manualTopUpCount = manualTopUpCount;
          _gcashTopUpTotal = gcashTopUpTotal;
          _gcashTopUpCount = gcashTopUpCount;
        });
        print('DEBUG: State updated successfully');
      } else {
        print('DEBUG: WARNING - Widget not mounted, state not updated');
      }
    } catch (_) {
      // no-op UI fallback
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBalanceOverview() async {
    setState(() => _balanceLoading = true);
    try {
      final res = await SupabaseService.getBalanceOverview();
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        setState(() {
          _totalStudentBalance =
              (data['total_student_balance'] as num?)?.toDouble() ?? 0.0;
          _totalServiceBalance =
              (data['total_service_balance'] as num?)?.toDouble() ?? 0.0;
          _totalSystemBalance =
              (data['total_system_balance'] as num?)?.toDouble() ?? 0.0;
          _studentCount = data['student_count'] as int? ?? 0;
          _serviceCount = data['service_count'] as int? ?? 0;
        });
      }
    } catch (_) {
      // no-op UI fallback
    } finally {
      if (mounted) setState(() => _balanceLoading = false);
    }
  }

  Future<void> _loadAnalysisData() async {
    setState(() => _analysisLoading = true);
    try {
      final range = _getDateRangeFor(_selectedPeriod);

      // Load all analysis data in parallel
      final results = await Future.wait([
        SupabaseService.getTopUpAnalysis(
          start: range['start'],
          end: range['end'],
        ),
        SupabaseService.getLoanAnalysis(
          start: range['start'],
          end: range['end'],
        ),
        SupabaseService.getVendorTransactionCountAnalysis(
          start: range['start'],
          end: range['end'],
        ),
      ]);

      if (mounted) {
        setState(() {
          // Top-up analysis
          if (results[0]['success'] == true) {
            _topupAnalysis =
                (results[0]['data']['topups'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
          }

          // Loan analysis
          if (results[1]['success'] == true) {
            _loanAnalysis =
                (results[1]['data']['loans'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
          }

          // Vendor transaction count analysis
          if (results[2]['success'] == true) {
            _vendorTransactionCount =
                (results[2]['data']['vendors'] as List<dynamic>?)
                    ?.cast<Map<String, dynamic>>() ??
                [];
          }
        });
      }
    } catch (_) {
      // no-op UI fallback
    } finally {
      if (mounted) setState(() => _analysisLoading = false);
    }
  }

  void _refreshCurrentPeriodData() {
    _loadIncome();
    _loadAnalysisData();
  }

  void _onPeriodSelected(String period) {
    if (_selectedPeriod == period) return;
    setState(() => _selectedPeriod = period);
    _refreshCurrentPeriodData();
  }

  void _onMonthChanged(int? month) {
    if (month == null || month == _selectedMonth) return;
    setState(() => _selectedMonth = month);
    if (_selectedPeriod == 'Monthly') {
      _refreshCurrentPeriodData();
    }
  }

  void _onMonthYearChanged(int? year) {
    if (year == null || year == _selectedMonthYear) return;
    setState(() => _selectedMonthYear = year);
    if (_selectedPeriod == 'Monthly') {
      _refreshCurrentPeriodData();
    }
  }

  void _onYearChanged(int? year) {
    if (year == null || year == _selectedYear) return;
    setState(() => _selectedYear = year);
    if (_selectedPeriod == 'Yearly') {
      _refreshCurrentPeriodData();
    }
  }

  Map<String, DateTime?> _getDateRangeFor(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'Daily':
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1));
        return {'start': start, 'end': end};
      case 'Weekly':
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 7));
        return {'start': start, 'end': end};
      case 'Monthly':
        final start = DateTime(_selectedMonthYear, _selectedMonth, 1);
        final end = DateTime(_selectedMonthYear, _selectedMonth + 1, 1);
        return {'start': start, 'end': end};
      case 'Yearly':
        final start = DateTime(_selectedYear, 1, 1);
        final end = DateTime(_selectedYear + 1, 1, 1);
        return {'start': start, 'end': end};
      default:
        return {'start': null, 'end': null};
    }
  }

  List<int> get _yearOptions {
    final currentYear = DateTime.now().year;
    final Set<int> years = {};
    for (int year = currentYear; year >= currentYear - 10; year--) {
      years.add(year);
    }
    years.add(_selectedMonthYear);
    years.add(_selectedYear);
    final List<int> sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  Widget _buildMonthYearSelector() {
    final yearOptions = _yearOptions;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Month & Year',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: evsuRed,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 420;

              final monthField = DropdownButtonFormField<int>(
                value: _selectedMonth,
                decoration: const InputDecoration(
                  labelText: 'Month',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: List.generate(
                  12,
                  (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text(_monthNames[index]),
                  ),
                ),
                onChanged: _onMonthChanged,
              );

              final yearField = DropdownButtonFormField<int>(
                value: _selectedMonthYear,
                decoration: const InputDecoration(
                  labelText: 'Year',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items:
                    yearOptions
                        .map(
                          (year) => DropdownMenuItem<int>(
                            value: year,
                            child: Text(year.toString()),
                          ),
                        )
                        .toList(),
                onChanged: _onMonthYearChanged,
              );

              if (isNarrow) {
                return Column(
                  children: [monthField, const SizedBox(height: 12), yearField],
                );
              }

              return Row(
                children: [
                  Expanded(child: monthField),
                  const SizedBox(width: 12),
                  Expanded(child: yearField),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    final yearOptions = _yearOptions;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Year',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: evsuRed,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _selectedYear,
            decoration: const InputDecoration(
              labelText: 'Year',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items:
                yearOptions
                    .map(
                      (year) => DropdownMenuItem<int>(
                        value: year,
                        child: Text(year.toString()),
                      ),
                    )
                    .toList(),
            onChanged: _onYearChanged,
          ),
        ],
      ),
    );
  }

  String _formatCurrency(double value) {
    return '₱${value.toStringAsFixed(2)}';
  }

  String _formatDateForExport(DateTime dateTime) {
    final local = dateTime.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');

    return '$year-$month-$day $hour:$minute';
  }

  void _showSnackBarMessage(
    String message, {
    Color backgroundColor = evsuRed,
    SnackBarAction? action,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        action: action,
      ),
    );
  }

  Future<void> _showExportSuccessDialog({required String csvPath}) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Export Successful',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
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
                  'Successfully exported to downloads.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please wait several minutes for the system to generate.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (csvPath.isNotEmpty) ...[
                  const Text(
                    'CSV file:',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    csvPath,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: evsuRed,
                  ),
                ),
              ),
            ],
          ),
    );
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
                        'Reports & Analytics',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      Text(
                        'System performance overview',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                _exportingExcel
                    ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          evsuRed,
                        ),
                      ),
                    )
                    : IconButton(
                      onPressed: _exportReports,
                      icon: const Icon(Icons.file_download, color: evsuRed),
                    ),
              ],
            ),
            const SizedBox(height: 24),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_loading) const SizedBox(height: 16),

            // Period Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children:
                    _periods
                        .map(
                          (period) => Expanded(
                            child: GestureDetector(
                              onTap: () {
                                _onPeriodSelected(period);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      _selectedPeriod == period
                                          ? evsuRed
                                          : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  period,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color:
                                        _selectedPeriod == period
                                            ? Colors.white
                                            : Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            const SizedBox(height: 24),
            if (_selectedPeriod == 'Monthly') _buildMonthYearSelector(),
            if (_selectedPeriod == 'Yearly') _buildYearSelector(),
            if (_selectedPeriod == 'Monthly' || _selectedPeriod == 'Yearly')
              const SizedBox(height: 16),

            // Key Metrics
            Container(
              padding: const EdgeInsets.all(20),
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
                    '$_selectedPeriod Overview',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total Income (Full Width)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: evsuRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: evsuRed.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Total Income',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: evsuRed,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCurrency(_totalIncome),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: evsuRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Top-up and Loan Disbursement Overview
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      if (isMobile) {
                        // Mobile: Stack vertically
                        return Column(
                          children: [
                            _IncomeMetricItem(
                              title: 'Top-up Income',
                              value: _formatCurrency(_topUpIncome),
                              count: _topupCount,
                              countLabel: 'Top-ups',
                              color: Colors.blue,
                              icon: Icons.account_balance_wallet,
                            ),
                            const SizedBox(height: 12),
                            _IncomeMetricItem(
                              title: 'Loan Income',
                              value: _formatCurrency(_loanIncome),
                              count: _loanDisbursementCount,
                              countLabel: 'Loan Disbursements',
                              color: Colors.green,
                              icon: Icons.credit_card,
                            ),
                            const SizedBox(height: 12),
                            _TopUpChannelBreakdown(
                              manualTotal: _formatCurrency(_manualTopUpTotal),
                              manualCount: _manualTopUpCount,
                              gcashTotal: _formatCurrency(_gcashTopUpTotal),
                              gcashCount: _gcashTopUpCount,
                            ),
                          ],
                        );
                      } else {
                        // Desktop: Side by side
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _IncomeMetricItem(
                                    title: 'Top-up Income',
                                    value: _formatCurrency(_topUpIncome),
                                    count: _topupCount,
                                    countLabel: 'Top-ups',
                                    color: Colors.blue,
                                    icon: Icons.account_balance_wallet,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _IncomeMetricItem(
                                    title: 'Loan Income',
                                    value: _formatCurrency(_loanIncome),
                                    count: _loanDisbursementCount,
                                    countLabel: 'Loan Disbursements',
                                    color: Colors.green,
                                    icon: Icons.credit_card,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _TopUpChannelBreakdown(
                              manualTotal: _formatCurrency(_manualTopUpTotal),
                              manualCount: _manualTopUpCount,
                              gcashTotal: _formatCurrency(_gcashTopUpTotal),
                              gcashCount: _gcashTopUpCount,
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Balance Overview Section
            Container(
              padding: const EdgeInsets.all(20),
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
                      const Icon(Icons.account_balance_wallet, color: evsuRed),
                      const SizedBox(width: 8),
                      const Text(
                        'Balance Overview',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _loadBalanceOverview,
                        icon: const Icon(Icons.refresh, color: evsuRed),
                        tooltip: 'Refresh balance data',
                      ),
                      if (_balanceLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Track your actual cash flow - money you handle should equal total balances',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Total System Balance
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: evsuRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: evsuRed.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.money, color: evsuRed, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total System Balance',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: evsuRed,
                                ),
                              ),
                              Text(
                                _formatCurrency(_totalSystemBalance),
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: evsuRed,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₱${_totalSystemBalance.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: evsuRed,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Balance Breakdown
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 600;

                      if (isMobile) {
                        // Mobile: Stack vertically
                        return Column(
                          children: [
                            _BalanceItem(
                              title: 'Student Balances',
                              value: _formatCurrency(_totalStudentBalance),
                              count: _studentCount,
                              color: Colors.blue,
                              icon: Icons.school,
                            ),
                            const SizedBox(height: 12),
                            _BalanceItem(
                              title: 'Service Balances',
                              value: _formatCurrency(_totalServiceBalance),
                              count: _serviceCount,
                              color: Colors.green,
                              icon: Icons.store,
                            ),
                          ],
                        );
                      } else {
                        // Desktop: Side by side
                        return Row(
                          children: [
                            Expanded(
                              child: _BalanceItem(
                                title: 'Student Balances',
                                value: _formatCurrency(_totalStudentBalance),
                                count: _studentCount,
                                color: Colors.blue,
                                icon: Icons.school,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _BalanceItem(
                                title: 'Service Balances',
                                value: _formatCurrency(_totalServiceBalance),
                                count: _serviceCount,
                                color: Colors.green,
                                icon: Icons.store,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Balance Verification
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          _totalSystemBalance ==
                                  (_totalStudentBalance + _totalServiceBalance)
                              ? Colors.green.withOpacity(0.1)
                              : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _totalSystemBalance ==
                                    (_totalStudentBalance +
                                        _totalServiceBalance)
                                ? Colors.green.withOpacity(0.3)
                                : Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _totalSystemBalance ==
                                  (_totalStudentBalance + _totalServiceBalance)
                              ? Icons.check_circle
                              : Icons.warning,
                          color:
                              _totalSystemBalance ==
                                      (_totalStudentBalance +
                                          _totalServiceBalance)
                                  ? Colors.green
                                  : Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _totalSystemBalance ==
                                    (_totalStudentBalance +
                                        _totalServiceBalance)
                                ? 'Balance verification: ✓ All balances match'
                                : 'Balance verification: ⚠ Balances do not match',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color:
                                  _totalSystemBalance ==
                                          (_totalStudentBalance +
                                              _totalServiceBalance)
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Top-up Analysis
            Container(
              padding: const EdgeInsets.all(20),
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
                      const Text(
                        'Top-up Analysis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      const Spacer(),
                      if (_analysisLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_topupAnalysis.isEmpty && !_analysisLoading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_balance_wallet,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No top-up data available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Top-up transactions will appear here',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _topupAnalysis.length,
                      itemBuilder: (context, index) {
                        final item = _topupAnalysis[index];
                        return _TopUpItem(
                          amount: _formatCurrency(item['amount'] as double),
                          count: item['count'] as int,
                          percentage: item['percentage'] as double,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Loan Analysis
            Container(
              padding: const EdgeInsets.all(20),
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
                      const Text(
                        'Loan Analysis',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                      const Spacer(),
                      if (_analysisLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loanAnalysis.isEmpty && !_analysisLoading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.credit_card,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No loan data available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Paid loan transactions will appear here',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _loanAnalysis.length,
                      itemBuilder: (context, index) {
                        final item = _loanAnalysis[index];
                        return _LoanItem(
                          amount: _formatCurrency(item['amount'] as double),
                          count: item['count'] as int,
                          percentage: item['percentage'] as double,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Vendor Transaction Count Analysis
            Container(
              padding: const EdgeInsets.all(20),
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
                      const Expanded(
                        child: Text(
                          'Vendor Transaction Count Analysis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: evsuRed,
                          ),
                        ),
                      ),
                      if (_analysisLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Which vendors have the most transaction activity',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_vendorTransactionCount.isEmpty && !_analysisLoading)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.analytics,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No transaction data available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Transaction count analysis will appear here',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _vendorTransactionCount.length,
                      itemBuilder: (context, index) {
                        final vendor = _vendorTransactionCount[index];
                        return _VendorTransactionCountItem(
                          name: vendor['service_name'] as String,
                          totalTransactions:
                              vendor['total_transactions'] as int,
                          rank: index + 1,
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Export Options
            Container(
              padding: const EdgeInsets.all(20),
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
                  const Text(
                    'Export Reports',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: _ExportButton(
                      title: 'Export CSV Report',
                      icon: Icons.table_chart,
                      onTap: _exportReports,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  void _exportReports() {
    _showExportTypeSelectionDialog();
  }

  Future<void> _showExportTypeSelectionDialog() async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Export CSV Report'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose export type:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                // Option 1: Full Export
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String>(
                    value: 'full',
                    groupValue: 'full',
                    onChanged: (_) {},
                  ),
                  title: const Text('Full Export'),
                  subtitle: const Text(
                    'Top-up income breakdown, loan income, balance overview, daily reports, active loans, vendor ranking',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showExportDateSelectionDialog(isIncomeOnly: false);
                  },
                ),
                const Divider(),
                // Option 2: Income Only Export
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String>(
                    value: 'income',
                    groupValue: 'full',
                    onChanged: (_) {},
                  ),
                  title: const Text('Income Only Export'),
                  subtitle: const Text('Top-up income and loan income only'),
                  onTap: () {
                    Navigator.pop(context);
                    _showExportDateSelectionDialog(isIncomeOnly: true);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> _showExportDateSelectionDialog({
    required bool isIncomeOnly,
  }) async {
    final range = _getDateRangeFor(_selectedPeriod);
    final DateTime? defaultStart = range['start'];
    final DateTime? defaultEnd = range['end'];

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              isIncomeOnly
                  ? 'Export Income CSV Report'
                  : 'Export Full CSV Report',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose date range for export:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                // Option 1: Use selected period
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String>(
                    value: 'period',
                    groupValue: 'period',
                    onChanged: (_) {},
                  ),
                  title: Text('Use $_selectedPeriod Period'),
                  subtitle: Text(
                    defaultStart != null && defaultEnd != null
                        ? '${_formatDateForDisplay(defaultStart)} to ${_formatDateForDisplay(defaultEnd)}'
                        : 'Current period selection',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (isIncomeOnly) {
                      _exportIncomeOnlyCSV(
                        startDate: defaultStart,
                        endDate: defaultEnd,
                      );
                    } else {
                      _exportComprehensiveCSV(
                        startDate: defaultStart,
                        endDate: defaultEnd,
                      );
                    }
                  },
                ),
                const Divider(),
                // Option 2: Custom date range
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String>(
                    value: 'range',
                    groupValue: 'period',
                    onChanged: (_) {},
                  ),
                  title: const Text('Custom Date Range'),
                  subtitle: const Text('Select start and end dates'),
                  onTap: () {
                    Navigator.pop(context);
                    _showDateRangePicker(isIncomeOnly: isIncomeOnly);
                  },
                ),
                const Divider(),
                // Option 3: Single date
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Radio<String>(
                    value: 'single',
                    groupValue: 'period',
                    onChanged: (_) {},
                  ),
                  title: const Text('Single Date'),
                  subtitle: const Text('Export data for one specific date'),
                  onTap: () {
                    Navigator.pop(context);
                    _showSingleDatePicker(isIncomeOnly: isIncomeOnly);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  Future<void> _showDateRangePicker({required bool isIncomeOnly}) async {
    final now = DateTime.now();
    final range = _getDateRangeFor(_selectedPeriod);
    final DateTime? defaultStart = range['start'];
    final DateTime? defaultEnd = range['end'];
    final DateTimeRange initialRange =
        defaultStart != null && defaultEnd != null
            ? DateTimeRange(start: defaultStart, end: defaultEnd)
            : DateTimeRange(
              start: now.subtract(const Duration(days: 30)),
              end: now,
            );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
    );

    if (picked != null) {
      if (isIncomeOnly) {
        _exportIncomeOnlyCSV(startDate: picked.start, endDate: picked.end);
      } else {
        _exportComprehensiveCSV(startDate: picked.start, endDate: picked.end);
      }
    }
  }

  Future<void> _showSingleDatePicker({required bool isIncomeOnly}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );

    if (picked != null) {
      // Single date: start and end are the same day
      final startOfDay = DateTime(picked.year, picked.month, picked.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      if (isIncomeOnly) {
        _exportIncomeOnlyCSV(startDate: startOfDay, endDate: endOfDay);
      } else {
        _exportComprehensiveCSV(startDate: startOfDay, endDate: endOfDay);
      }
    }
  }

  String _formatDateForDisplay(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _generateIncomeOnlyCSV({
    required double manualTopUpIncome,
    required double vendorCommissionTotal,
    required double totalTopUpIncome,
    required double loanIncome,
    DateTime? startDate,
    DateTime? endDate,
    required String reportTitle,
    required DateTime now,
  }) {
    final buffer = StringBuffer();

    // Header Section
    buffer.writeln(reportTitle);
    buffer.writeln('Generated At,${_formatDateForExport(now)}');
    if (startDate != null && endDate != null) {
      final startStr = _formatDateForDisplay(startDate);
      final endStr = _formatDateForDisplay(endDate);
      if (startStr == endStr) {
        buffer.writeln('Date Range,$startStr');
      } else {
        buffer.writeln('Date Range,$startStr to $endStr');
      }
    }
    buffer.writeln('');

    // Section 1: Top-up Income Breakdown
    buffer.writeln('TOP-UP INCOME BREAKDOWN');
    buffer.writeln('Metric,Amount (₱)');
    buffer.writeln(
      'Manual Top-up Income (Admin Commission),${manualTopUpIncome.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Vendor Commission Total,${vendorCommissionTotal.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Total Top-up Income,${totalTopUpIncome.toStringAsFixed(2)}',
    );
    buffer.writeln('');

    // Section 2: Loan Income
    buffer.writeln('LOAN INCOME');
    buffer.writeln('Metric,Amount (₱)');
    buffer.writeln('Loan Income,${loanIncome.toStringAsFixed(2)}');
    buffer.writeln('');

    // Section 3: Total Income Summary
    buffer.writeln('TOTAL INCOME SUMMARY');
    buffer.writeln('Metric,Amount (₱)');
    buffer.writeln(
      'Total Income (Top-up + Loan),${(totalTopUpIncome + loanIncome).toStringAsFixed(2)}',
    );

    return buffer.toString();
  }

  String _generateComprehensiveCSV({
    required Map<String, Map<String, double>> dailyTopUps,
    required double manualTopUpIncome,
    required double vendorCommissionTotal,
    required double totalTopUpIncome,
    required double loanIncome,
    required double totalStudentBalance,
    required double totalServiceBalance,
    required double totalSystemBalance,
    required List<Map<String, dynamic>> loanDetails,
    required List<Map<String, dynamic>> sortedVendors,
    required double totalAdminCommission,
    DateTime? startDate,
    DateTime? endDate,
    required String reportTitle,
    required DateTime now,
  }) {
    final buffer = StringBuffer();

    // Header Section
    buffer.writeln(reportTitle);
    buffer.writeln('Generated At,${_formatDateForExport(now)}');
    if (startDate != null && endDate != null) {
      final startStr = _formatDateForDisplay(startDate);
      final endStr = _formatDateForDisplay(endDate);
      if (startStr == endStr) {
        buffer.writeln('Date Range,$startStr');
      } else {
        buffer.writeln('Date Range,$startStr to $endStr');
      }
    }
    buffer.writeln('');

    // Section 1: Top-up Income Breakdown
    buffer.writeln('TOP-UP INCOME BREAKDOWN');
    buffer.writeln('Metric,Amount (₱)');
    buffer.writeln(
      'Manual Top-up Income (Admin Commission),${manualTopUpIncome.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Vendor Commission Total,${vendorCommissionTotal.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Total Top-up Income,${totalTopUpIncome.toStringAsFixed(2)}',
    );
    buffer.writeln('');

    // Section 2: Loan Income
    buffer.writeln('LOAN INCOME');
    buffer.writeln('Metric,Amount (₱)');
    buffer.writeln('Loan Income,${loanIncome.toStringAsFixed(2)}');
    buffer.writeln('');

    // Section 3: Balance Overview
    buffer.writeln('BALANCE OVERVIEW');
    buffer.writeln('Metric,Amount (₱)');
    buffer.writeln(
      'Total Student Balance,${totalStudentBalance.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Total Service/Vendor Balance,${totalServiceBalance.toStringAsFixed(2)}',
    );
    buffer.writeln(
      'Total System Balance,${totalSystemBalance.toStringAsFixed(2)}',
    );
    buffer.writeln('');

    // Section 4: Daily Reports
    buffer.writeln('DAILY REPORTS');
    buffer.writeln('Date,Manual Top-up (₱),GCash Top-up (₱),Total Top-up (₱)');

    // Sort dates chronologically
    final sortedDates =
        dailyTopUps.keys.toList()..sort((a, b) => a.compareTo(b));

    double grandTotalManual = 0.0;
    double grandTotalGcash = 0.0;
    double grandTotal = 0.0;

    // Write daily data
    for (final dateKey in sortedDates) {
      final dailyData = dailyTopUps[dateKey]!;
      final manualAmount = dailyData['manual'] ?? 0.0;
      final gcashAmount = dailyData['gcash'] ?? 0.0;
      final totalAmount = manualAmount + gcashAmount;

      grandTotalManual += manualAmount;
      grandTotalGcash += gcashAmount;
      grandTotal += totalAmount;

      // Format date for display (YYYY-MM-DD to readable format)
      final dateParts = dateKey.split('-');
      final displayDate = '${dateParts[1]}/${dateParts[2]}/${dateParts[0]}';

      buffer.writeln(
        '$displayDate,${manualAmount.toStringAsFixed(2)},${gcashAmount.toStringAsFixed(2)},${totalAmount.toStringAsFixed(2)}',
      );
    }

    // Add totals row for daily reports
    if (sortedDates.isNotEmpty) {
      buffer.writeln(
        'TOTAL,${grandTotalManual.toStringAsFixed(2)},${grandTotalGcash.toStringAsFixed(2)},${grandTotal.toStringAsFixed(2)}',
      );
    }
    buffer.writeln('');

    // Section 5: Active Loans Payment Breakdown
    buffer.writeln('ACTIVE LOANS - PAYMENT BREAKDOWN');
    buffer.writeln(
      'Loan ID,Student ID,Loan Amount,Interest Amount,Status,Manual Top-up,GCash Top-up',
    );

    for (final loan in loanDetails) {
      buffer.writeln(
        '${loan['loan_id']},${loan['student_id']},${(loan['loan_amount'] as double).toStringAsFixed(2)},${(loan['interest_amount'] as double).toStringAsFixed(2)},${loan['status']},${(loan['manual_topup'] as double).toStringAsFixed(2)},${(loan['gcash_topup'] as double).toStringAsFixed(2)}',
      );
    }
    buffer.writeln('');

    // Section 6: Vendor Top-up Ranking
    buffer.writeln('VENDOR TOP-UP RANKING');
    buffer.writeln(
      'Rank,Vendor Name,Total Top-ups,Total Amount,Vendor Commission,Admin Commission,Total Commission',
    );

    int rank = 1;
    for (final vendor in sortedVendors) {
      final vendorCommission =
          (vendor['vendor_commission'] as num?)?.toDouble() ?? 0.0;
      final adminCommission =
          (vendor['admin_commission'] as num?)?.toDouble() ?? 0.0;
      final totalCommission =
          (vendor['total_commission'] as num?)?.toDouble() ?? 0.0;

      buffer.writeln(
        '$rank,${vendor['vendor_name']},${vendor['total_topups']},${(vendor['total_amount'] as double).toStringAsFixed(2)},${vendorCommission.toStringAsFixed(2)},${adminCommission.toStringAsFixed(2)},${totalCommission.toStringAsFixed(2)}',
      );
      rank++;
    }

    // Add total admin commission row
    if (sortedVendors.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln(
        'TOTAL ADMIN COMMISSION,,,,,${totalAdminCommission.toStringAsFixed(2)},',
      );
    }

    return buffer.toString();
  }

  Future<void> _exportIncomeOnlyCSV({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_exportingExcel) {
      _showSnackBarMessage('An export is already in progress. Please wait...');
      return;
    }

    if (mounted) {
      setState(() => _exportingExcel = true);
    }

    try {
      await SupabaseService.initialize();
      // Use provided dates or fall back to selected period
      if (startDate == null || endDate == null) {
        final range = _getDateRangeFor(_selectedPeriod);
        startDate = range['start'];
        endDate = range['end'];
      }

      // Fetch top-up transactions with admin_earn and vendor_earn for income breakdown
      var topupIncomeQuery = SupabaseService.client
          .from('top_up_transactions')
          .select(
            'admin_earn, vendor_earn, transaction_type, amount, created_at',
          )
          .inFilter('transaction_type', [
            'top_up',
            'top_up_gcash',
            'top_up_services',
          ]);
      if (startDate != null) {
        topupIncomeQuery = topupIncomeQuery.gte(
          'created_at',
          startDate.toIso8601String(),
        );
      }
      if (endDate != null) {
        topupIncomeQuery = topupIncomeQuery.lt(
          'created_at',
          endDate.toIso8601String(),
        );
      }
      final topupsForIncome = await topupIncomeQuery;

      // Calculate top-up income breakdown
      double manualTopUpIncome = 0.0; // Admin commission from manual top-ups
      double vendorCommissionTotal = 0.0; // Total vendor commission
      double totalTopUpIncome = 0.0;

      for (final t in topupsForIncome) {
        final adminEarn = (t['admin_earn'] as num?)?.toDouble() ?? 0.0;
        final vendorEarn = (t['vendor_earn'] as num?)?.toDouble() ?? 0.0;
        final transactionType = t['transaction_type']?.toString() ?? '';

        vendorCommissionTotal += vendorEarn;

        if (transactionType == 'top_up') {
          manualTopUpIncome += adminEarn;
        }
      }

      totalTopUpIncome = manualTopUpIncome + vendorCommissionTotal;

      // Fetch loan data within the selected range
      var loanQuery = SupabaseService.client
          .from('active_loans')
          .select('interest_amount, created_at');
      if (startDate != null) {
        loanQuery = loanQuery.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        loanQuery = loanQuery.lt('created_at', endDate.toIso8601String());
      }
      final loanRows = await loanQuery;

      double loanIncome = 0.0;
      for (final loan in loanRows) {
        loanIncome += (loan['interest_amount'] as num?)?.toDouble() ?? 0.0;
      }

      final DateTime now = DateTime.now();

      // Determine report title based on date range
      String reportTitle;
      if (startDate != null && endDate != null) {
        final startStr = _formatDateForDisplay(startDate);
        final endStr = _formatDateForDisplay(endDate);
        if (startStr == endStr) {
          reportTitle = 'Income Report - $startStr';
        } else {
          reportTitle = 'Income Report - $startStr to $endStr';
        }
      } else {
        reportTitle = '$_selectedPeriod Income Report';
      }

      // Generate income-only CSV content
      String csvContent = '';
      try {
        csvContent = _generateIncomeOnlyCSV(
          manualTopUpIncome: manualTopUpIncome,
          vendorCommissionTotal: vendorCommissionTotal,
          totalTopUpIncome: totalTopUpIncome,
          loanIncome: loanIncome,
          startDate: startDate,
          endDate: endDate,
          reportTitle: reportTitle,
          now: now,
        );
      } catch (e) {
        throw Exception('Failed to generate CSV content: $e');
      }

      if (csvContent.isEmpty) {
        throw Exception('CSV content is empty');
      }

      // Prepare file paths
      final String timestampSuffix =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      String fileNamePrefix;
      if (startDate != null && endDate != null) {
        final startStr =
            '${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}';
        final endStr =
            '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
        if (startStr == endStr) {
          fileNamePrefix = 'income_report_$startStr';
        } else {
          fileNamePrefix = 'income_report_${startStr}_to_$endStr';
        }
      } else {
        final periodName = _selectedPeriod.toLowerCase();
        fileNamePrefix = '${periodName}_income_report';
      }

      final String csvFileName = '${fileNamePrefix}_$timestampSuffix.csv';

      // Get downloads directory
      Directory? downloadsDir;
      try {
        if (Platform.isAndroid) {
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            downloadsDir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          downloadsDir = await getApplicationDocumentsDirectory();
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          downloadsDir = await getDownloadsDirectory();
        }
      } catch (e) {
        print('Error getting downloads directory: $e');
        downloadsDir = null;
      }

      // Save CSV file
      bool csvSaved = false;
      String? csvSavedPath;

      if (downloadsDir != null) {
        try {
          // Ensure directory exists
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }

          final csvFile = File('${downloadsDir.path}/$csvFileName');
          await csvFile.writeAsString(csvContent, flush: true);

          // Verify file was actually saved
          if (await csvFile.exists()) {
            csvSaved = true;
            csvSavedPath = csvFile.path;
            print('CSV file saved successfully to: $csvSavedPath');
          } else {
            throw Exception('File was not created');
          }
        } catch (e) {
          print('Error saving CSV to downloads: $e');
          csvSaved = false;
          csvSavedPath = null;
        }
      }

      if (!csvSaved) {
        try {
          final csvOutputPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save CSV report',
            fileName: csvFileName,
            type: FileType.custom,
            allowedExtensions: ['csv'],
          );

          if (csvOutputPath != null && csvOutputPath.trim().isNotEmpty) {
            final csvFile = File(csvOutputPath);
            await csvFile.writeAsString(csvContent, flush: true);

            // Verify file was actually saved
            if (await csvFile.exists()) {
              csvSaved = true;
              csvSavedPath = csvFile.path;
              print('CSV file saved successfully to: $csvSavedPath');
            } else {
              throw Exception('File was not created');
            }
          }
        } catch (e) {
          print('Error saving CSV via file picker: $e');
          throw Exception('Unable to save CSV file: $e');
        }
      }

      if (!csvSaved || csvSavedPath == null) {
        throw Exception('Unable to save CSV file. Please try again.');
      }

      // Show success modal dialog
      await _showExportSuccessDialog(csvPath: csvSavedPath);
    } catch (e) {
      _showSnackBarMessage(
        'CSV export failed: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _exportingExcel = false);
      }
    }
  }

  Future<void> _exportComprehensiveCSV({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_exportingExcel) {
      _showSnackBarMessage('An export is already in progress. Please wait...');
      return;
    }

    if (mounted) {
      setState(() => _exportingExcel = true);
    }

    try {
      await SupabaseService.initialize();
      // Use provided dates or fall back to selected period
      if (startDate == null || endDate == null) {
        final range = _getDateRangeFor(_selectedPeriod);
        startDate = range['start'];
        endDate = range['end'];
      }

      // Fetch all required data in parallel
      final balanceResult = await SupabaseService.getBalanceOverview();
      final incomeResult = await SupabaseService.getIncomeSummary(
        start: startDate,
        end: endDate,
      );

      // Fetch top-up transactions with admin_earn and vendor_earn for income breakdown
      var topupIncomeQuery = SupabaseService.client
          .from('top_up_transactions')
          .select(
            'admin_earn, vendor_earn, transaction_type, amount, created_at',
          )
          .inFilter('transaction_type', [
            'top_up',
            'top_up_gcash',
            'top_up_services',
          ]);
      if (startDate != null) {
        topupIncomeQuery = topupIncomeQuery.gte(
          'created_at',
          startDate.toIso8601String(),
        );
      }
      if (endDate != null) {
        topupIncomeQuery = topupIncomeQuery.lt(
          'created_at',
          endDate.toIso8601String(),
        );
      }
      final topupsForIncome = await topupIncomeQuery;

      // Calculate top-up income breakdown
      double manualTopUpIncome = 0.0; // Admin commission from manual top-ups
      double vendorCommissionTotal = 0.0; // Total vendor commission
      double totalTopUpIncome = 0.0;

      // Group top-ups by date for daily reports
      Map<String, Map<String, double>> dailyTopUps =
          {}; // date -> {manual: amount, gcash: amount}

      for (final t in topupsForIncome) {
        final adminEarn = (t['admin_earn'] as num?)?.toDouble() ?? 0.0;
        final vendorEarn = (t['vendor_earn'] as num?)?.toDouble() ?? 0.0;
        final transactionType = t['transaction_type']?.toString() ?? '';
        final amount = (t['amount'] as num?)?.toDouble() ?? 0.0;
        final createdAt = t['created_at']?.toString() ?? '';

        vendorCommissionTotal += vendorEarn;

        if (transactionType == 'top_up') {
          manualTopUpIncome += adminEarn;
        }

        // Group by date for daily reports (only manual and GCash)
        if ((transactionType == 'top_up' ||
                transactionType == 'top_up_gcash') &&
            createdAt.isNotEmpty) {
          try {
            final dateTime = DateTime.parse(createdAt);
            final dateKey =
                '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';

            if (!dailyTopUps.containsKey(dateKey)) {
              dailyTopUps[dateKey] = {'manual': 0.0, 'gcash': 0.0};
            }

            if (transactionType == 'top_up') {
              dailyTopUps[dateKey]!['manual'] =
                  (dailyTopUps[dateKey]!['manual'] ?? 0.0) + amount;
            } else if (transactionType == 'top_up_gcash') {
              dailyTopUps[dateKey]!['gcash'] =
                  (dailyTopUps[dateKey]!['gcash'] ?? 0.0) + amount;
            }
          } catch (e) {
            print('Error parsing date: $e');
          }
        }
      }

      totalTopUpIncome = manualTopUpIncome + vendorCommissionTotal;

      // Fetch active loans with payment breakdown
      var loanQuery = SupabaseService.client
          .from('active_loans')
          .select(
            'id, student_id, loan_amount, interest_amount, status, paid_at, created_at',
          );
      if (startDate != null) {
        loanQuery = loanQuery.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        loanQuery = loanQuery.lt('created_at', endDate.toIso8601String());
      }
      final loans = await loanQuery;

      // For each loan, check how it was paid (manual or GCash)
      List<Map<String, dynamic>> loanDetails = [];
      for (final loan in loans) {
        final loanId = loan['id'];
        final studentId = loan['student_id']?.toString() ?? '';

        // Check loan payments from top_up_transactions
        double manualLoanAmount = 0.0;
        double gcashLoanAmount = 0.0;

        // Note: Loan payment breakdown by channel (manual vs GCash) would require
        // tracking which top-ups were used to pay loans. For now, showing loan details.
        loanDetails.add({
          'loan_id': loanId,
          'student_id': studentId,
          'loan_amount': (loan['loan_amount'] as num?)?.toDouble() ?? 0.0,
          'interest_amount':
              (loan['interest_amount'] as num?)?.toDouble() ?? 0.0,
          'status': loan['status']?.toString() ?? '',
          'manual_topup': manualLoanAmount,
          'gcash_topup': gcashLoanAmount,
        });
      }

      // Fetch vendor top-up statistics
      var vendorTopupQuery = SupabaseService.client
          .from('top_up_transactions')
          .select(
            'processed_by, vendor_earn, admin_earn, amount, transaction_type, created_at',
          )
          .eq('transaction_type', 'top_up_services');
      if (startDate != null) {
        vendorTopupQuery = vendorTopupQuery.gte(
          'created_at',
          startDate.toIso8601String(),
        );
      }
      if (endDate != null) {
        vendorTopupQuery = vendorTopupQuery.lt(
          'created_at',
          endDate.toIso8601String(),
        );
      }
      final vendorTopups = await vendorTopupQuery;

      // Group vendor top-ups by processed_by (username)
      Map<String, Map<String, dynamic>> vendorStats = {};
      double totalAdminCommission = 0.0;

      for (final vt in vendorTopups) {
        final processedBy = vt['processed_by']?.toString() ?? 'Unknown';
        final amount = (vt['amount'] as num?)?.toDouble() ?? 0.0;
        final vendorEarn = (vt['vendor_earn'] as num?)?.toDouble() ?? 0.0;
        final adminEarn = (vt['admin_earn'] as num?)?.toDouble() ?? 0.0;

        if (!vendorStats.containsKey(processedBy)) {
          vendorStats[processedBy] = {
            'vendor_name': processedBy,
            'total_topups': 0,
            'total_amount': 0.0,
            'vendor_commission': 0.0,
            'admin_commission': 0.0,
            'total_commission': 0.0,
          };
        }

        vendorStats[processedBy]!['total_topups'] =
            (vendorStats[processedBy]!['total_topups'] as int) + 1;
        vendorStats[processedBy]!['total_amount'] =
            (vendorStats[processedBy]!['total_amount'] as double) + amount;
        vendorStats[processedBy]!['vendor_commission'] =
            (vendorStats[processedBy]!['vendor_commission'] as double) +
            vendorEarn;
        vendorStats[processedBy]!['admin_commission'] =
            (vendorStats[processedBy]!['admin_commission'] as double) +
            adminEarn;
        vendorStats[processedBy]!['total_commission'] =
            (vendorStats[processedBy]!['total_commission'] as double) +
            vendorEarn +
            adminEarn;

        totalAdminCommission += adminEarn;
      }

      // Get vendor names from service_accounts
      final vendorList = vendorStats.keys.toList();
      if (vendorList.isNotEmpty) {
        final serviceAccounts = await SupabaseService.client
            .from('service_accounts')
            .select('username, service_name')
            .inFilter('username', vendorList);
        for (final sa in serviceAccounts) {
          final username = sa['username']?.toString() ?? '';
          final serviceName = sa['service_name']?.toString() ?? '';
          if (vendorStats.containsKey(username)) {
            vendorStats[username]!['vendor_name'] =
                serviceName.isNotEmpty ? serviceName : username;
          }
        }
      }

      // Sort vendors by total top-ups (descending)
      final sortedVendors =
          vendorStats.values.toList()..sort(
            (a, b) =>
                (b['total_topups'] as int).compareTo(a['total_topups'] as int),
          );

      // Get balance and income data
      final balanceData =
          (balanceResult['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      final incomeData =
          (incomeResult['data'] as Map<String, dynamic>?) ??
          <String, dynamic>{};

      final double totalStudentBalance =
          (balanceData['total_student_balance'] as num?)?.toDouble() ?? 0.0;
      final double totalServiceBalance =
          (balanceData['total_service_balance'] as num?)?.toDouble() ?? 0.0;
      final double totalSystemBalance =
          (balanceData['total_system_balance'] as num?)?.toDouble() ??
          (totalStudentBalance + totalServiceBalance);
      final double loanIncome =
          (incomeData['loan_income'] as num?)?.toDouble() ?? 0.0;

      final DateTime now = DateTime.now();

      // Determine report title based on date range
      String reportTitle;
      if (startDate != null && endDate != null) {
        final startStr = _formatDateForDisplay(startDate);
        final endStr = _formatDateForDisplay(endDate);
        if (startStr == endStr) {
          reportTitle = 'Single Date Report - $startStr';
        } else {
          reportTitle = 'Custom Date Range Report';
        }
      } else {
        reportTitle = '$_selectedPeriod Income Report';
      }

      // Generate comprehensive CSV content
      String csvContent = '';
      try {
        csvContent = _generateComprehensiveCSV(
          dailyTopUps: dailyTopUps,
          manualTopUpIncome: manualTopUpIncome,
          vendorCommissionTotal: vendorCommissionTotal,
          totalTopUpIncome: totalTopUpIncome,
          loanIncome: loanIncome,
          totalStudentBalance: totalStudentBalance,
          totalServiceBalance: totalServiceBalance,
          totalSystemBalance: totalSystemBalance,
          loanDetails: loanDetails,
          sortedVendors: sortedVendors,
          totalAdminCommission: totalAdminCommission,
          startDate: startDate,
          endDate: endDate,
          reportTitle: reportTitle,
          now: now,
        );
      } catch (e) {
        throw Exception('Failed to generate CSV content: $e');
      }

      if (csvContent.isEmpty) {
        throw Exception('CSV content is empty');
      }

      // Prepare file paths
      final String timestampSuffix =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      String fileNamePrefix;
      if (startDate != null && endDate != null) {
        final startStr =
            '${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}';
        final endStr =
            '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
        if (startStr == endStr) {
          fileNamePrefix = 'report_$startStr';
        } else {
          fileNamePrefix = 'report_${startStr}_to_$endStr';
        }
      } else {
        final periodName = _selectedPeriod.toLowerCase();
        fileNamePrefix = '${periodName}_reports';
      }

      final String csvFileName = '${fileNamePrefix}_$timestampSuffix.csv';

      // Get downloads directory
      Directory? downloadsDir;
      try {
        if (Platform.isAndroid) {
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            downloadsDir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          downloadsDir = await getApplicationDocumentsDirectory();
        } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
          downloadsDir = await getDownloadsDirectory();
        }
      } catch (e) {
        print('Error getting downloads directory: $e');
        downloadsDir = null;
      }

      // Save CSV file
      bool csvSaved = false;
      String? csvSavedPath;

      if (downloadsDir != null) {
        try {
          // Ensure directory exists
          if (!await downloadsDir.exists()) {
            await downloadsDir.create(recursive: true);
          }

          final csvFile = File('${downloadsDir.path}/$csvFileName');
          await csvFile.writeAsString(csvContent, flush: true);

          // Verify file was actually saved
          if (await csvFile.exists()) {
            csvSaved = true;
            csvSavedPath = csvFile.path;
            print('CSV file saved successfully to: $csvSavedPath');
          } else {
            throw Exception('File was not created');
          }
        } catch (e) {
          print('Error saving CSV to downloads: $e');
          csvSaved = false;
          csvSavedPath = null;
        }
      }

      if (!csvSaved) {
        try {
          final csvOutputPath = await FilePicker.platform.saveFile(
            dialogTitle: 'Save CSV report',
            fileName: csvFileName,
            type: FileType.custom,
            allowedExtensions: ['csv'],
          );

          if (csvOutputPath != null && csvOutputPath.trim().isNotEmpty) {
            final csvFile = File(csvOutputPath);
            await csvFile.writeAsString(csvContent, flush: true);

            // Verify file was actually saved
            if (await csvFile.exists()) {
              csvSaved = true;
              csvSavedPath = csvFile.path;
              print('CSV file saved successfully to: $csvSavedPath');
            } else {
              throw Exception('File was not created');
            }
          }
        } catch (e) {
          print('Error saving CSV via file picker: $e');
          throw Exception('Unable to save CSV file: $e');
        }
      }

      if (!csvSaved || csvSavedPath == null) {
        throw Exception('Unable to save CSV file. Please try again.');
      }

      // Show success modal dialog
      await _showExportSuccessDialog(csvPath: csvSavedPath);
    } catch (e) {
      _showSnackBarMessage(
        'CSV export failed: $e',
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _exportingExcel = false);
      }
    }
  }
}

class _TopUpItem extends StatelessWidget {
  static const Color evsuRed = Color(0xFFB01212);
  final String amount;
  final int count;
  final double percentage;

  const _TopUpItem({
    required this.amount,
    required this.count,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: evsuRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                amount,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: evsuRed,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count transactions',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  height: 4,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _TopUpItem.evsuRed,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoanItem extends StatelessWidget {
  final String amount;
  final int count;
  final double percentage;

  const _LoanItem({
    required this.amount,
    required this.count,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                amount,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count loans',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  height: 4,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: percentage / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomeMetricItem extends StatelessWidget {
  final String title;
  final String value;
  final int count;
  final String countLabel;
  final Color color;
  final IconData icon;

  const _IncomeMetricItem({
    required this.title,
    required this.value,
    required this.count,
    required this.countLabel,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.trending_up, color: color.withOpacity(0.7), size: 16),
              const SizedBox(width: 4),
              Text(
                '$count $countLabel',
                style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopUpChannelBreakdown extends StatelessWidget {
  final String manualTotal;
  final int manualCount;
  final String gcashTotal;
  final int gcashCount;

  const _TopUpChannelBreakdown({
    required this.manualTotal,
    required this.manualCount,
    required this.gcashTotal,
    required this.gcashCount,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1024;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.payments,
                color: _TopUpItem.evsuRed,
                size: isMobile ? 18 : 20,
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Text(
                'Top-up Channels',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.w700,
                  color: _TopUpItem.evsuRed,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (isMobile) {
                // Mobile: Stack vertically
                return Column(
                  children: [
                    _TopUpChannelTile(
                      label: 'Cash Desk',
                      total: manualTotal,
                      count: manualCount,
                      color: Colors.blue,
                      icon: Icons.attach_money,
                      isMobile: true,
                    ),
                    SizedBox(height: isMobile ? 10 : 12),
                    _TopUpChannelTile(
                      label: 'GCash Verified',
                      total: gcashTotal,
                      count: gcashCount,
                      color: Colors.deepPurple,
                      icon: Icons.qr_code_scanner,
                      isMobile: true,
                    ),
                  ],
                );
              } else {
                // Tablet/Desktop: Side by side
                return Row(
                  children: [
                    Expanded(
                      child: _TopUpChannelTile(
                        label: 'Cash Desk',
                        total: manualTotal,
                        count: manualCount,
                        color: Colors.blue,
                        icon: Icons.attach_money,
                        isMobile: false,
                      ),
                    ),
                    SizedBox(width: isTablet ? 10 : 12),
                    Expanded(
                      child: _TopUpChannelTile(
                        label: 'GCash Verified',
                        total: gcashTotal,
                        count: gcashCount,
                        color: Colors.deepPurple,
                        icon: Icons.qr_code_scanner,
                        isMobile: false,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _TopUpChannelTile extends StatelessWidget {
  final String label;
  final String total;
  final int count;
  final Color color;
  final IconData icon;
  final bool isMobile;

  const _TopUpChannelTile({
    required this.label,
    required this.total,
    required this.count,
    required this.color,
    required this.icon,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.12), color.withOpacity(0.06)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: color, size: isMobile ? 18 : 20),
              ),
              SizedBox(width: isMobile ? 8 : 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 14),
          Text(
            total,
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: isMobile ? 4 : 6),
          Row(
            children: [
              Icon(
                Icons.receipt_long,
                size: isMobile ? 12 : 14,
                color: color.withOpacity(0.7),
              ),
              SizedBox(width: isMobile ? 4 : 6),
              Flexible(
                child: Text(
                  '$count ${count == 1 ? 'transaction' : 'transactions'}',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: color.withOpacity(0.75),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  final String title;
  final String value;
  final int count;
  final Color color;
  final IconData icon;

  const _BalanceItem({
    required this.title,
    required this.value,
    required this.count,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$count accounts',
            style: TextStyle(fontSize: 12, color: color.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

class _VendorTransactionCountItem extends StatelessWidget {
  static const Color evsuRed = Color(0xFFB01212);
  final String name;
  final int totalTransactions;
  final int rank;

  const _VendorTransactionCountItem({
    required this.name,
    required this.totalTransactions,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: rank <= 3 ? evsuRed.withOpacity(0.05) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: rank <= 3 ? evsuRed.withOpacity(0.3) : Colors.grey.shade200,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: rank <= 3 ? evsuRed : Colors.grey[300],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      rank.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: rank <= 3 ? Colors.white : Colors.grey[600],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: rank <= 3 ? evsuRed : Colors.black87,
                        ),
                      ),
                      Text(
                        '$totalTransactions total transactions',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  totalTransactions.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: rank <= 3 ? evsuRed : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  static const Color evsuRed = Color(0xFFB01212);
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _ExportButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: _ExportButton.evsuRed.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: _ExportButton.evsuRed),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _ExportButton.evsuRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
