import 'package:flutter/material.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../services/encryption_service.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:path_provider/path_provider.dart';

class ServiceReportsTab extends StatefulWidget {
  const ServiceReportsTab({super.key});

  @override
  State<ServiceReportsTab> createState() => _ServiceReportsTabState();
}

class _ServiceReportsTabState extends State<ServiceReportsTab> {
  static const Color evsuRed = Color(0xFFB91C1C);

  // Period selection
  String _selectedPeriod = 'Today';
  DateTimeRange? _dateRange;

  // Service data
  Map<String, String> _serviceNames = {}; // service_id -> service_name

  // Data
  List<Map<String, dynamic>> _transactions = [];
  double _totalAmount = 0.0;
  int _totalCount = 0;
  // Aggregations
  Map<String, Map<String, dynamic>> _itemAggregates = {};
  // Map<String, int> _dailyCounts = {}; // reserved for future daily chart

  @override
  void initState() {
    super.initState();
    // Default to today's range
    _applyPeriodRange('Today');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadServiceNames();
      _loadTransactions();
    });
  }

  @override
  Widget build(BuildContext context) {
    // DEBUG: current state for UI sections
    // ignore: avoid_print
    print(
      'DEBUG ReportsTab(build): totalCount=${_totalCount}, totalAmount=${_totalAmount.toStringAsFixed(2)}, items=${_itemAggregates.length}, tx=${_transactions.length}',
    );
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final isWeb = screenWidth > 600;
    final isTablet = screenWidth > 480 && screenWidth <= 1024;

    // Responsive sizing
    final horizontalPadding = isWeb ? 24.0 : (isTablet ? 20.0 : 16.0);
    final verticalPadding = isWeb ? 20.0 : (isTablet ? 16.0 : 12.0);
    // final crossAxisCount = isWeb ? 3 : (isTablet ? 2 : 1);

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isWeb ? 24 : 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [evsuRed, Color(0xFF7F1D1D)],
                ),
                borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reports & Analytics',
                          style: TextStyle(
                            fontSize: isWeb ? 28 : (isTablet ? 24 : 22),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: isWeb ? 8 : 6),
                        Text(
                          'System performance overview',
                          style: TextStyle(
                            fontSize: isWeb ? 16 : (isTablet ? 15 : 14),
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Export buttons with responsive layout
                  if (isWeb)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // CSV Export button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () => _exportWithRange('CSV'),
                            icon: Icon(
                              Icons.table_chart,
                              color: Colors.white,
                              size: 28,
                            ),
                            tooltip: 'Export CSV',
                          ),
                        ),
                        SizedBox(width: 8),
                        // Excel Export button
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () => _exportWithRange('Excel'),
                            icon: Icon(
                              Icons.table_view,
                              color: Colors.white,
                              size: 28,
                            ),
                            tooltip: 'Export Excel',
                          ),
                        ),
                      ],
                    )
                  else
                    // Mobile/Tablet: Single export button with dropdown or stack
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.file_download,
                          color: Colors.white,
                          size: 24,
                        ),
                        tooltip: 'Export Reports',
                        onSelected: (format) => _exportWithRange(format),
                        itemBuilder:
                            (context) => [
                              PopupMenuItem(
                                value: 'CSV',
                                child: Row(
                                  children: [
                                    Icon(Icons.table_chart, size: 20),
                                    SizedBox(width: 8),
                                    Text('Export CSV'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'Excel',
                                child: Row(
                                  children: [
                                    Icon(Icons.table_view, size: 20),
                                    SizedBox(width: 8),
                                    Text('Export Excel'),
                                  ],
                                ),
                              ),
                            ],
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: isWeb ? 30 : 24),

            // Period Selector
            Container(
              padding: EdgeInsets.all(isWeb ? 20 : 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
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
                        'Period Overview',
                        style: TextStyle(
                          fontSize: isWeb ? 18 : 16,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isWeb ? 16 : 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double maxWidth = constraints.maxWidth;
                      final bool isNarrow = maxWidth < 360;

                      return Align(
                        alignment:
                            isNarrow ? Alignment.center : Alignment.centerLeft,
                        child: Wrap(
                          alignment:
                              isNarrow
                                  ? WrapAlignment.center
                                  : WrapAlignment.start,
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              ['Today', 'Week', 'Month', 'Year'].map((period) {
                                final isSelected = _selectedPeriod == period;
                                return ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minWidth: isNarrow ? maxWidth * 0.4 : 72,
                                  ),
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedPeriod = period;
                                        _applyPeriodRange(period);
                                      });
                                      _loadTransactions();
                                    },
                                    child: Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isWeb ? 16 : 12,
                                        vertical: isWeb ? 10 : 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? evsuRed
                                                : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color:
                                              isSelected
                                                  ? evsuRed
                                                  : Colors.grey[300]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          period,
                                          style: TextStyle(
                                            color:
                                                isSelected
                                                    ? Colors.white
                                                    : Colors.grey[700],
                                            fontSize: isWeb ? 14 : 13,
                                            fontWeight:
                                                isSelected
                                                    ? FontWeight.w600
                                                    : FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: isWeb ? 24 : 20),

            // Key Metrics (from fetched data)
            Container(
              padding: EdgeInsets.all(isWeb ? 24 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
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
                    style: TextStyle(
                      fontSize: isWeb ? 22 : (isTablet ? 20 : 18),
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                  SizedBox(height: isWeb ? 20 : 16),

                  if (isWeb)
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 20,
                      mainAxisSpacing: 20,
                      childAspectRatio: 2.5,
                      children: [
                        _MetricItem(
                          title: 'Total Revenue',
                          value: '₱' + _totalAmount.toStringAsFixed(2),
                          change: '',
                          isPositive: true,
                          isWeb: isWeb,
                        ),
                        _MetricItem(
                          title: 'Transactions',
                          value: _totalCount.toString(),
                          change: '',
                          isPositive: true,
                          isWeb: isWeb,
                        ),
                        _MetricItem(
                          title: 'Average Amount',
                          value:
                              _totalCount == 0
                                  ? '₱0.00'
                                  : '₱' +
                                      (_totalAmount / _totalCount)
                                          .toStringAsFixed(2),
                          change: '',
                          isPositive: true,
                          isWeb: isWeb,
                        ),
                        const SizedBox.shrink(),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _MetricItem(
                                title: 'Total Revenue',
                                value: '₱' + _totalAmount.toStringAsFixed(2),
                                change: '',
                                isPositive: true,
                                isWeb: isWeb,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _MetricItem(
                                title: 'Transactions',
                                value: _totalCount.toString(),
                                change: '',
                                isPositive: true,
                                isWeb: isWeb,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricItem(
                                title: 'Average Amount',
                                value:
                                    _totalCount == 0
                                        ? '₱0.00'
                                        : '₱' +
                                            (_totalAmount / _totalCount)
                                                .toStringAsFixed(2),
                                change: '',
                                isPositive: true,
                                isWeb: isWeb,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),

            SizedBox(height: isWeb ? 30 : 24),

            // Item Breakdown (Selected Range)
            Container(
              padding: EdgeInsets.all(isWeb ? 24 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
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
                    'Item Breakdown ($_selectedPeriod)',
                    style: TextStyle(
                      fontSize: isWeb ? 20 : (isTablet ? 18 : 16),
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_itemAggregates.isEmpty)
                    Builder(
                      builder: (context) {
                        // ignore: avoid_print
                        print('DEBUG ReportsTab(build): Item breakdown empty');
                        return Text(
                          'No items in this period.',
                          style: TextStyle(color: Colors.grey[600]),
                        );
                      },
                    )
                  else
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.3,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _itemAggregates.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = _itemAggregates.entries.elementAt(
                            index,
                          );
                          final name = entry.key;
                          final qty = entry.value['quantity'] as int;
                          final total = (entry.value['total'] as double);
                          return ListTile(
                            dense: true,
                            title: Text(
                              name,
                              style: TextStyle(
                                fontSize: isWeb ? 14 : (isTablet ? 13 : 12),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              '${qty} • ₱${total.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: isWeb ? 13 : (isTablet ? 12 : 11),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: isWeb ? 30 : 24),

            // Transactions + Export
            Container(
              padding: EdgeInsets.all(isWeb ? 24 : 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isWeb ? 16 : 12),
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
                  // Transactions header with responsive export buttons
                  if (isWeb)
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Transactions',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: evsuRed,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton.icon(
                              onPressed: () => _exportWithRange('CSV'),
                              icon: Icon(Icons.table_chart),
                              label: Text('Export CSV'),
                            ),
                            SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => _exportWithRange('Excel'),
                              icon: Icon(Icons.table_view),
                              label: Text('Export Excel'),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transactions',
                          style: TextStyle(
                            fontSize: isTablet ? 18 : 16,
                            fontWeight: FontWeight.bold,
                            color: evsuRed,
                          ),
                        ),
                        SizedBox(height: 12),
                        // Export buttons in a row for mobile/tablet
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton.icon(
                              onPressed: () => _exportWithRange('CSV'),
                              icon: Icon(Icons.table_chart, size: 16),
                              label: Text('CSV'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _exportWithRange('Excel'),
                              icon: Icon(Icons.table_view, size: 16),
                              label: Text('Excel'),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    Builder(
                      builder: (context) {
                        // ignore: avoid_print
                        print(
                          'DEBUG ReportsTab(build): Transactions empty for today',
                        );
                        return Text(
                          'No transactions today.',
                          style: TextStyle(color: Colors.grey[600]),
                        );
                      },
                    )
                  else
                    Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.4,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _transactions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final t = _transactions[index];
                          final createdAtStr =
                              t['created_at']?.toString() ?? '';
                          final localDateTime = _formatDateTimeForDisplay(
                            createdAtStr,
                          );
                          return ListTile(
                            dense: true,
                            title: Text(
                              '$localDateTime  •  ₱${(t['total_amount'] as num).toDouble().toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: isWeb ? 14 : (isTablet ? 13 : 12),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              'Items: ' +
                                  (t['items'] as List).length.toString(),
                              style: TextStyle(
                                fontSize: isWeb ? 12 : (isTablet ? 11 : 10),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            SizedBox(height: isWeb ? 60 : 100), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  // Export modal removed; direct CSV export is provided via buttons

  // Removed unused export/email helpers

  void _applyPeriodRange(String period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end = now;

    switch (period) {
      case 'Today':
        start = DateTime(now.year, now.month, now.day);
        break;
      case 'Week':
        // Start of current week (Monday)
        final weekday = now.weekday;
        start = now.subtract(Duration(days: weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        break;
      case 'Month':
        // Start of current month
        start = DateTime(now.year, now.month, 1);
        break;
      case 'Year':
        // Start of current year
        start = DateTime(now.year, 1, 1);
        break;
      default:
        start = DateTime(now.year, now.month, now.day);
    }

    _dateRange = DateTimeRange(start: start, end: end);
  }

  // Removed unused date range helpers

  Future<void> _loadTransactions() async {
    // start fetch
    try {
      // Use the selected date range
      final range = _dateRange;
      if (range == null) return;

      final startOfDay = DateTime(
        range.start.year,
        range.start.month,
        range.start.day,
        0,
        0,
        0,
      );
      final endOfDay = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );

      final from = startOfDay.toIso8601String();
      final to = endOfDay.toIso8601String();

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
      // DEBUG: Inputs
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab: period=$_selectedPeriod, local range: $startOfDay to $endOfDay, rootMainId=$rootMainId',
      );

      await SupabaseService.initialize();

      final res = await SupabaseService.client
          .from('service_transactions')
          .select(
            'id, created_at, items, total_amount, service_account_id, main_service_id',
          )
          .or(
            'main_service_id.eq.${rootMainId},service_account_id.eq.${rootMainId}',
          )
          .gte('created_at', from)
          .lt('created_at', to)
          .order('created_at', ascending: false);
      // DEBUG: raw result length
      // ignore: avoid_print
      print('DEBUG ReportsTab: query returned ${(res as List).length} rows');

      final tx =
          (res as List)
              .map<Map<String, dynamic>>(
                (e) => Map<String, dynamic>.from(e as Map),
              )
              .toList();
      // DEBUG: first few rows
      for (int i = 0; i < (tx.length > 3 ? 3 : tx.length); i++) {
        final t = tx[i];
        // ignore: avoid_print
        print(
          'DEBUG ReportsTab: row[$i] id=${t['id']} created_at=${t['created_at']} total_amount=${t['total_amount']}',
        );
      }
      double total = 0.0;
      final itemAgg = <String, Map<String, dynamic>>{};
      final daily = <String, int>{};
      for (final t in tx) {
        total += (t['total_amount'] as num).toDouble();
        final created = DateTime.tryParse(t['created_at']?.toString() ?? '');
        if (created != null) {
          final key =
              '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')}';
          daily[key] = (daily[key] ?? 0) + 1;
        }
        final items =
            (t['items'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
        for (final it in items) {
          final name = (it['name'] ?? '').toString();
          final qty = (it['quantity'] as num?)?.toInt() ?? 1;
          final lineTotal =
              (it['total'] as num?)?.toDouble() ??
              ((it['price'] as num?)?.toDouble() ?? 0.0) * qty;
          final prev = itemAgg[name];
          if (prev == null) {
            itemAgg[name] = {'quantity': qty, 'total': lineTotal};
          } else {
            itemAgg[name] = {
              'quantity': (prev['quantity'] as int) + qty,
              'total': (prev['total'] as double) + lineTotal,
            };
          }
        }
      }
      // DEBUG: aggregates
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab: totalAmount=$total, txCount=${tx.length}, distinctItems=${itemAgg.length}',
      );
      setState(() {
        _transactions = tx;
        _totalAmount = total;
        _totalCount = tx.length;
        _itemAggregates = itemAgg;
        // _dailyCounts = daily;
      });
    } catch (e) {
      if (!mounted) return;
      // ignore: avoid_print
      print('DEBUG ReportsTab: load error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load transactions: $e')),
      );
    } finally {
      // done
    }
  }

  /// Show date selection dialog with option for single date or date range
  Future<void> _showDateSelectionDialog(
    DateTimeRange initialRange,
    String format, {
    required bool includePurposeAndCode,
  }) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Select Date Range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Choose the date range for export:'),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showDateRangePicker(
                          initialRange,
                          format,
                          includePurposeAndCode: includePurposeAndCode,
                        );
                      },
                      icon: Icon(Icons.date_range),
                      label: Text('Date Range'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _showSingleDatePicker(
                          format,
                          includePurposeAndCode: includePurposeAndCode,
                        );
                      },
                      icon: Icon(Icons.calendar_today),
                      label: Text('Single Date'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Show date range picker
  Future<void> _showDateRangePicker(
    DateTimeRange initialRange,
    String format, {
    required bool includePurposeAndCode,
  }) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
    );
    if (picked != null) {
      await _performExport(
        picked,
        format,
        includePurposeAndCode: includePurposeAndCode,
      );
    }
  }

  /// Show single date picker
  Future<void> _showSingleDatePicker(
    String format, {
    required bool includePurposeAndCode,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      // Convert single date to date range (same day)
      final dateRange = DateTimeRange(start: picked, end: picked);
      await _performExport(
        dateRange,
        format,
        includePurposeAndCode: includePurposeAndCode,
      );
    }
  }

  /// Perform the actual export with the selected date range
  Future<void> _performExport(
    DateTimeRange dateRange,
    String format, {
    required bool includePurposeAndCode,
  }) async {
    try {
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

      if (_serviceNames.isEmpty) {
        await _loadServiceNames();
      }

      await SupabaseService.initialize();

      final startOfDay = DateTime(
        dateRange.start.year,
        dateRange.start.month,
        dateRange.start.day,
        0,
        0,
        0,
      );
      final endOfDay = DateTime(
        dateRange.end.year,
        dateRange.end.month,
        dateRange.end.day,
        23,
        59,
        59,
      );

      final from = startOfDay.toIso8601String();
      final to = endOfDay.toIso8601String();

      // ignore: avoid_print
      print('DEBUG ReportsTab(export): local range: $startOfDay to $endOfDay');

      final res = await SupabaseService.client
          .from('service_transactions')
          .select(
            'id, created_at, items, total_amount, service_account_id, main_service_id, student_id, purpose, transaction_code',
          )
          .eq('service_account_id', serviceId)
          .gte('created_at', from)
          .lt('created_at', to)
          .order('created_at', ascending: false);

      final tx =
          (res as List)
              .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
              .toList();

      final studentIds =
          tx
              .map((t) {
                final raw = t['student_id'];
                if (raw == null) return null;
                final value = raw.toString().trim();
                return value.isEmpty ? null : value;
              })
              .where((id) => id != null)
              .map((id) => id!)
              .toSet();
      final studentNames = await _fetchStudentNames(studentIds);

      // Group data by service_account_id and items + capture transaction details
      final groupedData = <String, Map<String, dynamic>>{};
      final transactionRows = <Map<String, dynamic>>[];
      double totalAmount = 0.0;

      for (final t in tx) {
        final transactionTotal = (t['total_amount'] as num?)?.toDouble() ?? 0.0;
        totalAmount += transactionTotal;

        final serviceAccountId = t['service_account_id']?.toString() ?? '';
        final serviceAccountName =
            _serviceNames[serviceAccountId] ?? 'Unknown Service';
        final mainServiceId =
            t['main_service_id']?.toString() ?? rootMainId.toString();
        final mainServiceName =
            _serviceNames[mainServiceId] ??
            _serviceNames[rootMainId.toString()] ??
            serviceAccountName;

        final rawStudentId = t['student_id'];
        final studentId =
            rawStudentId == null ? '' : rawStudentId.toString().trim();
        final studentName =
            studentId.isEmpty
                ? 'Walk-in'
                : (studentNames[studentId] ?? 'Unknown Student');

        final purpose = t['purpose']?.toString() ?? '';
        final transactionCode = t['transaction_code']?.toString() ?? '';

        final items =
            (t['items'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
        final itemSummaryParts = <String>[];

        for (final item in items) {
          final itemName = (item['name'] ?? '').toString();
          final qtyNum = (item['quantity'] as num?)?.toInt() ?? 1;
          final lineTotal =
              (item['total'] as num?)?.toDouble() ??
              ((item['price'] as num?)?.toDouble() ?? 0.0) * qtyNum;

          // Create unique key for grouping
          final groupKey = '${serviceAccountId}_$itemName';

          final existing = groupedData[groupKey];
          if (existing == null) {
            groupedData[groupKey] = {
              'service_transaction': serviceAccountName,
              'main_transaction': mainServiceName,
              'item': itemName,
              'total_count': qtyNum,
              'total_amount': lineTotal,
            };
          } else {
            existing['total_count'] = (existing['total_count'] as int) + qtyNum;
            existing['total_amount'] =
                (existing['total_amount'] as double) + lineTotal;
          }

          itemSummaryParts.add(
            '$itemName x$qtyNum (₱${lineTotal.toStringAsFixed(2)})',
          );
        }

        transactionRows.add({
          'service_transaction': serviceAccountName,
          'main_transaction': mainServiceName,
          'student_id': studentId.isEmpty ? 'N/A' : studentId,
          'student_name': studentId.isEmpty ? 'Walk-in' : studentName,
          'item':
              itemSummaryParts.isEmpty
                  ? 'No items'
                  : itemSummaryParts.join('; '),
          'total_payment': transactionTotal,
          'purpose': purpose,
          'transaction_code': transactionCode,
        });
      }

      // Fetch top-up commission earnings
      final topUpCommissionData = await _fetchTopUpCommissionEarnings(from, to);

      // Debug: Print top-up commission data
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab(export): Top-up commission data: $topUpCommissionData',
      );
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab(export): Total commission: ${topUpCommissionData['totalCommission']}, Transaction count: ${topUpCommissionData['transactionCount']}',
      );

      // Use the provided format
      if (format == 'Excel') {
        await _exportToExcel(
          groupedData,
          transactionRows,
          totalAmount,
          dateRange,
          topUpCommissionData,
          includePurposeAndCode: includePurposeAndCode,
        );
      } else {
        await _exportToCsv(
          groupedData,
          transactionRows,
          totalAmount,
          dateRange,
          topUpCommissionData,
          includePurposeAndCode: includePurposeAndCode,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  /// Fetch top-up commission earnings for the service account
  Future<Map<String, dynamic>> _fetchTopUpCommissionEarnings(
    String from,
    String to,
  ) async {
    try {
      final serviceUsername =
          SessionService.currentUserData?['username']?.toString();

      if (serviceUsername == null || serviceUsername.isEmpty) {
        return {
          'totalCommission': 0.0,
          'transactionCount': 0,
          'transactions': <Map<String, dynamic>>[],
        };
      }

      await SupabaseService.initialize();

      // Debug: Print query parameters
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab: Fetching top-up commission - serviceUsername: $serviceUsername, from: $from, to: $to',
      );

      // Fetch top-up transactions processed by this service account
      final topUpTransactions = await SupabaseService.client
          .from('top_up_transactions')
          .select(
            'id, student_id, amount, vendor_earn, created_at, transaction_type',
          )
          .eq('processed_by', serviceUsername)
          .eq('transaction_type', 'top_up_services')
          .gte('created_at', from)
          .lt('created_at', to)
          .order('created_at', ascending: false);

      // Debug: Print query results
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab: Top-up transactions found: ${(topUpTransactions as List).length}',
      );

      double totalCommission = 0.0;
      final transactions = <Map<String, dynamic>>[];

      for (final transaction in (topUpTransactions as List)) {
        final vendorEarn =
            (transaction['vendor_earn'] as num?)?.toDouble() ?? 0.0;
        totalCommission += vendorEarn;

        // Debug: Print each transaction
        // ignore: avoid_print
        print(
          'DEBUG ReportsTab: Top-up transaction - student_id: ${transaction['student_id']}, amount: ${transaction['amount']}, vendor_earn: $vendorEarn',
        );

        transactions.add({
          'student_id': transaction['student_id']?.toString() ?? 'N/A',
          'amount': (transaction['amount'] as num?)?.toDouble() ?? 0.0,
          'vendor_earn': vendorEarn,
          'created_at': transaction['created_at']?.toString() ?? '',
        });
      }

      // Debug: Print summary
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab: Total commission: $totalCommission, Transaction count: ${transactions.length}',
      );

      return {
        'totalCommission': totalCommission,
        'transactionCount': transactions.length,
        'transactions': transactions,
      };
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG ReportsTab: Failed to fetch top-up commission: $e');
      return {
        'totalCommission': 0.0,
        'transactionCount': 0,
        'transactions': <Map<String, dynamic>>[],
      };
    }
  }

  /// Load service names for display in exports
  Future<void> _loadServiceNames() async {
    try {
      await SupabaseService.initialize();

      final response = await SupabaseService.client
          .from('service_accounts')
          .select('id, service_name')
          .eq('is_active', true);

      final serviceMap = <String, String>{};
      for (final service in response) {
        serviceMap[service['id'].toString()] =
            service['service_name'] as String;
      }

      if (mounted) {
        setState(() {
          _serviceNames = serviceMap;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG ReportsTab: Failed to load service names: $e');
    }
  }

  Future<Map<String, String>> _fetchStudentNames(Set<String> studentIds) async {
    if (studentIds.isEmpty) return {};
    try {
      await SupabaseService.initialize();
      final response = await SupabaseService.client
          .from('auth_students')
          .select('student_id, name')
          .inFilter('student_id', studentIds.toList());

      final names = <String, String>{};
      for (final entry in response as List) {
        final id = entry['student_id']?.toString();
        if (id == null || id.isEmpty) continue;
        String name = entry['name']?.toString() ?? '';
        if (name.isNotEmpty && EncryptionService.looksLikeEncryptedData(name)) {
          try {
            name = EncryptionService.decryptData(name);
          } catch (_) {
            // Keep original if decryption fails
          }
        }
        names[id] = name;
      }
      return names;
    } catch (e) {
      // ignore: avoid_print
      print('DEBUG ReportsTab: failed to fetch student names: $e');
      return {};
    }
  }

  // Removed old export (non-range) method; using _exportWithRange instead

  String _formatDateTimeForDisplay(String dateTimeStr) {
    try {
      final localDateTime = DateTime.parse(dateTimeStr);

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

      final dateStr =
          '${months[localDateTime.month - 1]} ${localDateTime.day}, ${localDateTime.year}';

      // Format time as "9:56 am"
      final hour =
          localDateTime.hour == 0
              ? 12
              : (localDateTime.hour > 12
                  ? localDateTime.hour - 12
                  : localDateTime.hour);
      final minute = localDateTime.minute.toString().padLeft(2, '0');
      final amPm = localDateTime.hour < 12 ? 'am' : 'pm';
      final timeStr = '$hour:$minute $amPm';

      return '$dateStr $timeStr';
    } catch (e) {
      return dateTimeStr; // Return original if parsing fails
    }
  }

  Future<void> _exportWithRange(String format) async {
    try {
      final now = DateTime.now();
      final initialRange =
          _dateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);

      // Determine if current service is Campus Service Units
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

      bool includePurposeAndCode = false;
      try {
        await SupabaseService.initialize();
        final serviceRow =
            await SupabaseService.client
                .from('service_accounts')
                .select('service_category')
                .eq('id', rootMainId)
                .maybeSingle();
        final category =
            serviceRow == null
                ? ''
                : serviceRow['service_category']?.toString() ?? '';
        includePurposeAndCode =
            category.trim().toLowerCase() == 'campus service units';
      } catch (_) {
        includePurposeAndCode = false;
      }

      // Show date selection dialog
      await _showDateSelectionDialog(
        initialRange,
        format,
        includePurposeAndCode: includePurposeAndCode,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _exportToCsv(
    Map<String, Map<String, dynamic>> groupedData,
    List<Map<String, dynamic>> transactionRows,
    double totalAmount,
    DateTimeRange dateRange,
    Map<String, dynamic> topUpCommissionData, {
    required bool includePurposeAndCode,
  }) async {
    try {
      final summaryHeaders = [
        'Service Transaction',
        'Main Service',
        'Item',
        'Total Count',
        'Total Amount',
      ];
      final transactionHeaders = [
        'Service Transaction',
        'Main Service',
        'Student ID',
        'Student Name',
        'Item',
        'Total Payment',
        if (includePurposeAndCode) 'Purpose',
        if (includePurposeAndCode) 'Transaction Code',
      ];
      final topUpCommissionHeaders = [
        'Student ID',
        'Top-up Amount',
        'Vendor Commission Earned',
        'Date',
      ];

      String formatRow(List<String> columns) =>
          columns.map((c) => '"${c.replaceAll('"', '""')}"').join(',');

      final csv = StringBuffer();
      csv.writeln('Summary');
      csv.writeln(formatRow(summaryHeaders));

      for (final entry in groupedData.entries) {
        final data = entry.value;
        final row = [
          data['service_transaction'] as String? ?? '',
          data['main_transaction'] as String? ?? '',
          data['item'] as String? ?? '',
          (data['total_count'] as int?)?.toString() ?? '0',
          ((data['total_amount'] as double?) ?? 0.0).toStringAsFixed(2),
        ];
        csv.writeln(formatRow(row));
      }

      if (groupedData.isNotEmpty) {
        csv.writeln(
          formatRow(['TOTAL', '', '', '', totalAmount.toStringAsFixed(2)]),
        );
      }

      csv.writeln('');
      csv.writeln('Transactions');
      csv.writeln(formatRow(transactionHeaders));

      if (transactionRows.isEmpty) {
        csv.writeln(formatRow(['No transactions found', '', '', '', '', '']));
      } else {
        for (final row in transactionRows) {
          final csvRow = [
            row['service_transaction'] as String? ?? '',
            row['main_transaction'] as String? ?? '',
            row['student_id'] as String? ?? '',
            row['student_name'] as String? ?? '',
            row['item'] as String? ?? '',
            ((row['total_payment'] as double?) ?? 0.0).toStringAsFixed(2),
            if (includePurposeAndCode) row['purpose'] as String? ?? '',
            if (includePurposeAndCode) row['transaction_code'] as String? ?? '',
          ];
          csv.writeln(formatRow(csvRow));
        }
      }

      // Add Top-up Commission Earnings section
      csv.writeln('');
      csv.writeln('Top-up Commission Earnings');
      csv.writeln(formatRow(topUpCommissionHeaders));

      // Debug: Check data structure
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab(CSV): topUpCommissionData type: ${topUpCommissionData.runtimeType}',
      );
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab(CSV): topUpCommissionData keys: ${topUpCommissionData.keys}',
      );

      final topUpTransactionsRaw = topUpCommissionData['transactions'];
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab(CSV): topUpTransactionsRaw type: ${topUpTransactionsRaw.runtimeType}',
      );
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab(CSV): topUpTransactionsRaw value: $topUpTransactionsRaw',
      );

      final topUpTransactions =
          topUpTransactionsRaw is List
              ? List<Map<String, dynamic>>.from(
                topUpTransactionsRaw.map(
                  (e) => Map<String, dynamic>.from(e as Map),
                ),
              )
              : <Map<String, dynamic>>[];

      final totalCommission =
          (topUpCommissionData['totalCommission'] as num?)?.toDouble() ?? 0.0;

      // ignore: avoid_print
      print(
        'DEBUG ReportsTab(CSV): topUpTransactions length: ${topUpTransactions.length}',
      );
      // ignore: avoid_print
      print('DEBUG ReportsTab(CSV): totalCommission: $totalCommission');

      if (topUpTransactions.isEmpty) {
        csv.writeln(formatRow(['No top-up transactions found', '', '', '']));
        // ignore: avoid_print
        print('DEBUG ReportsTab(CSV): Writing "No top-up transactions found"');
      } else {
        // ignore: avoid_print
        print(
          'DEBUG ReportsTab(CSV): Writing ${topUpTransactions.length} top-up transactions',
        );
        for (final transaction in topUpTransactions) {
          // ignore: avoid_print
          print('DEBUG ReportsTab(CSV): Processing transaction: $transaction');

          final studentId = transaction['student_id']?.toString() ?? 'N/A';
          final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;
          final vendorEarn =
              (transaction['vendor_earn'] as num?)?.toDouble() ?? 0.0;
          final createdAt = transaction['created_at']?.toString() ?? '';
          final formattedDate =
              createdAt.isNotEmpty
                  ? _formatDateTimeForDisplay(createdAt)
                  : 'N/A';

          // ignore: avoid_print
          print(
            'DEBUG ReportsTab(CSV): studentId=$studentId, amount=$amount, vendorEarn=$vendorEarn, date=$formattedDate',
          );

          final csvRow = [
            studentId,
            amount.toStringAsFixed(2),
            vendorEarn.toStringAsFixed(2),
            formattedDate,
          ];
          csv.writeln(formatRow(csvRow));
        }
      }

      csv.writeln('');
      csv.writeln(
        formatRow([
          'TOTAL COMMISSION EARNED',
          '',
          totalCommission.toStringAsFixed(2),
          '',
        ]),
      );

      final csvContent = csv.toString();

      // Debug: Verify CSV content includes all sections
      // ignore: avoid_print
      print('DEBUG ReportsTab(CSV): CSV content length: ${csvContent.length}');
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab(CSV): Contains "Summary": ${csvContent.contains("Summary")}',
      );
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab(CSV): Contains "Transactions": ${csvContent.contains("Transactions")}',
      );
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab(CSV): Contains "Top-up Commission Earnings": ${csvContent.contains("Top-up Commission Earnings")}',
      );
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab(CSV): Transaction rows count: ${transactionRows.length}',
      );
      // ignore: avoid_print
      print(
        'DEBUG ReportsTab(CSV): Top-up transactions count: ${topUpTransactions.length}',
      );

      final bytes = utf8.encode(csvContent);

      // Auto-save to downloads folder
      String defaultFileName =
          'service_transactions_${dateRange.start.year}-${dateRange.start.month.toString().padLeft(2, '0')}-${dateRange.start.day.toString().padLeft(2, '0')}_to_${dateRange.end.year}-${dateRange.end.month.toString().padLeft(2, '0')}-${dateRange.end.day.toString().padLeft(2, '0')}.csv';

      try {
        // Get downloads directory
        Directory? downloadsDir;
        if (Platform.isAndroid) {
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            downloadsDir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          downloadsDir = await getApplicationDocumentsDirectory();
        } else {
          // For desktop platforms
          downloadsDir = await getDownloadsDirectory();
        }

        if (downloadsDir != null) {
          final file = File('${downloadsDir.path}/$defaultFileName');
          await file.writeAsBytes(bytes, flush: true);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CSV saved to: ${file.path}'),
              duration: Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () {
                  // Try to open the file location
                  if (Platform.isWindows) {
                    Process.run('explorer', ['/select,', file.path]);
                  } else if (Platform.isMacOS) {
                    Process.run('open', ['-R', file.path]);
                  } else if (Platform.isLinux) {
                    Process.run('xdg-open', [downloadsDir!.path]);
                  }
                },
              ),
            ),
          );
          return;
        }
      } catch (saveErr) {
        // ignore: avoid_print
        print('DEBUG: Auto-save failed: $saveErr');
      }

      // Fallback: Try file picker
      String? outputPath;
      try {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save CSV report',
          fileName: defaultFileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );
      } catch (_) {
        outputPath = null;
      }

      if (outputPath != null && outputPath.trim().isNotEmpty) {
        try {
          final file = File(outputPath);
          await file.writeAsBytes(bytes, flush: true);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('CSV saved to: ${file.path}')));
          return;
        } catch (writeErr) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to save: $writeErr')));
        }
      }

      // Final fallback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save CSV file. Please try again.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('CSV export failed: $e')));
    }
  }

  Future<void> _exportToExcel(
    Map<String, Map<String, dynamic>> groupedData,
    List<Map<String, dynamic>> transactionRows,
    double totalAmount,
    DateTimeRange dateRange,
    Map<String, dynamic> topUpCommissionData, {
    required bool includePurposeAndCode,
  }) async {
    try {
      // Create Excel workbook with single sheet
      final excelWorkbook = excel.Excel.createExcel();
      // Use the default sheet and rename it
      excelWorkbook.rename('Sheet1', 'Service Report');
      final reportSheet = excelWorkbook['Service Report'];

      int currentRowIndex = 0;

      // Section 1: Summary
      reportSheet
          .cell(
            excel.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: currentRowIndex,
            ),
          )
          .value = excel.TextCellValue('Summary');
      currentRowIndex++;

      final summaryHeaders = [
        'Service Transaction',
        'Main Service',
        'Item',
        'Total Count',
        'Total Amount',
      ];
      for (int i = 0; i < summaryHeaders.length; i++) {
        reportSheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: i,
                rowIndex: currentRowIndex,
              ),
            )
            .value = excel.TextCellValue(summaryHeaders[i]);
      }
      currentRowIndex++;

      for (final entry in groupedData.entries) {
        final data = entry.value;
        reportSheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: currentRowIndex,
              ),
            )
            .value = excel.TextCellValue(
          data['service_transaction'] as String? ?? '',
        );
        reportSheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 1,
                rowIndex: currentRowIndex,
              ),
            )
            .value = excel.TextCellValue(
          data['main_transaction'] as String? ?? '',
        );
        reportSheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 2,
                rowIndex: currentRowIndex,
              ),
            )
            .value = excel.TextCellValue(data['item'] as String? ?? '');
        reportSheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 3,
                rowIndex: currentRowIndex,
              ),
            )
            .value = excel.IntCellValue((data['total_count'] as int?) ?? 0);
        reportSheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 4,
                rowIndex: currentRowIndex,
              ),
            )
            .value = excel.DoubleCellValue(
          (data['total_amount'] as double?) ?? 0.0,
        );
        currentRowIndex++;
      }

      if (groupedData.isNotEmpty) {
        reportSheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: currentRowIndex,
              ),
            )
            .value = excel.TextCellValue('TOTAL');
        reportSheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 4,
                rowIndex: currentRowIndex,
              ),
            )
            .value = excel.DoubleCellValue(totalAmount);
        currentRowIndex++;
      }

      // Blank row separator
      currentRowIndex++;

      // Section 2: Transactions
      reportSheet
          .cell(
            excel.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: currentRowIndex,
            ),
          )
          .value = excel.TextCellValue('Transactions');
      currentRowIndex++;

      final transactionHeaders = [
        'Service Transaction',
        'Main Service',
        'Student ID',
        'Student Name',
        'Item',
        'Total Payment',
        if (includePurposeAndCode) 'Purpose',
        if (includePurposeAndCode) 'Transaction Code',
      ];
      for (int i = 0; i < transactionHeaders.length; i++) {
        reportSheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: i,
                rowIndex: currentRowIndex,
              ),
            )
            .value = excel.TextCellValue(transactionHeaders[i]);
      }
      currentRowIndex++;

      if (transactionRows.isEmpty) {
        reportSheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: currentRowIndex,
              ),
            )
            .value = excel.TextCellValue('No transactions found');
        currentRowIndex++;
      } else {
        for (final row in transactionRows) {
          reportSheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: currentRowIndex,
                ),
              )
              .value = excel.TextCellValue(
            row['service_transaction'] as String? ?? '',
          );
          reportSheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 1,
                  rowIndex: currentRowIndex,
                ),
              )
              .value = excel.TextCellValue(
            row['main_transaction'] as String? ?? '',
          );
          reportSheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 2,
                  rowIndex: currentRowIndex,
                ),
              )
              .value = excel.TextCellValue(row['student_id'] as String? ?? '');
          reportSheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 3,
                  rowIndex: currentRowIndex,
                ),
              )
              .value = excel.TextCellValue(
            row['student_name'] as String? ?? '',
          );
          reportSheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 4,
                  rowIndex: currentRowIndex,
                ),
              )
              .value = excel.TextCellValue(row['item'] as String? ?? '');
          reportSheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 5,
                  rowIndex: currentRowIndex,
                ),
              )
              .value = excel.DoubleCellValue(
            (row['total_payment'] as double?) ?? 0.0,
          );
          if (includePurposeAndCode) {
            reportSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 6,
                    rowIndex: currentRowIndex,
                  ),
                )
                .value = excel.TextCellValue(row['purpose'] as String? ?? '');
            reportSheet
                .cell(
                  excel.CellIndex.indexByColumnRow(
                    columnIndex: 7,
                    rowIndex: currentRowIndex,
                  ),
                )
                .value = excel.TextCellValue(
              row['transaction_code'] as String? ?? '',
            );
          }
          currentRowIndex++;
        }
      }

      // Blank row separator
      currentRowIndex++;

      // Section 3: Top-up Commission Earnings
      reportSheet
          .cell(
            excel.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: currentRowIndex,
            ),
          )
          .value = excel.TextCellValue('Top-up Commission Earnings');
      currentRowIndex++;

      final topUpCommissionHeaders = [
        'Student ID',
        'Top-up Amount',
        'Vendor Commission Earned',
        'Date',
      ];
      for (int i = 0; i < topUpCommissionHeaders.length; i++) {
        reportSheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: i,
                rowIndex: currentRowIndex,
              ),
            )
            .value = excel.TextCellValue(topUpCommissionHeaders[i]);
      }
      currentRowIndex++;

      final topUpTransactionsRaw = topUpCommissionData['transactions'];
      final topUpTransactions =
          topUpTransactionsRaw is List
              ? List<Map<String, dynamic>>.from(
                topUpTransactionsRaw.map(
                  (e) => Map<String, dynamic>.from(e as Map),
                ),
              )
              : <Map<String, dynamic>>[];
      final totalCommission =
          (topUpCommissionData['totalCommission'] as num?)?.toDouble() ?? 0.0;

      if (topUpTransactions.isEmpty) {
        reportSheet
            .cell(
              excel.CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: currentRowIndex,
              ),
            )
            .value = excel.TextCellValue('No top-up transactions found');
        currentRowIndex++;
      } else {
        for (final transaction in topUpTransactions) {
          final createdAt = transaction['created_at']?.toString() ?? '';
          final formattedDate =
              createdAt.isNotEmpty
                  ? _formatDateTimeForDisplay(createdAt)
                  : 'N/A';

          reportSheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: currentRowIndex,
                ),
              )
              .value = excel.TextCellValue(
            transaction['student_id']?.toString() ?? 'N/A',
          );
          reportSheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 1,
                  rowIndex: currentRowIndex,
                ),
              )
              .value = excel.DoubleCellValue(
            (transaction['amount'] as num?)?.toDouble() ?? 0.0,
          );
          reportSheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 2,
                  rowIndex: currentRowIndex,
                ),
              )
              .value = excel.DoubleCellValue(
            (transaction['vendor_earn'] as num?)?.toDouble() ?? 0.0,
          );
          reportSheet
              .cell(
                excel.CellIndex.indexByColumnRow(
                  columnIndex: 3,
                  rowIndex: currentRowIndex,
                ),
              )
              .value = excel.TextCellValue(formattedDate);
          currentRowIndex++;
        }
      }

      // Always write total commission row
      reportSheet
          .cell(
            excel.CellIndex.indexByColumnRow(
              columnIndex: 0,
              rowIndex: currentRowIndex,
            ),
          )
          .value = excel.TextCellValue('TOTAL COMMISSION EARNED');
      reportSheet
          .cell(
            excel.CellIndex.indexByColumnRow(
              columnIndex: 2,
              rowIndex: currentRowIndex,
            ),
          )
          .value = excel.DoubleCellValue(totalCommission);

      excelWorkbook.setDefaultSheet('Service Report');

      // Save Excel file
      final bytes = excelWorkbook.encode();
      if (bytes == null) {
        throw Exception('Failed to encode Excel file');
      }

      String defaultFileName =
          'service_transactions_${dateRange.start.year}-${dateRange.start.month.toString().padLeft(2, '0')}-${dateRange.start.day.toString().padLeft(2, '0')}_to_${dateRange.end.year}-${dateRange.end.month.toString().padLeft(2, '0')}-${dateRange.end.day.toString().padLeft(2, '0')}.xlsx';

      try {
        // Get downloads directory
        Directory? downloadsDir;
        if (Platform.isAndroid) {
          downloadsDir = Directory('/storage/emulated/0/Download');
          if (!await downloadsDir.exists()) {
            downloadsDir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          downloadsDir = await getApplicationDocumentsDirectory();
        } else {
          // For desktop platforms
          downloadsDir = await getDownloadsDirectory();
        }

        if (downloadsDir != null) {
          final file = File('${downloadsDir.path}/$defaultFileName');
          await file.writeAsBytes(bytes, flush: true);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel saved to: ${file.path}'),
              duration: Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () {
                  // Try to open the file location
                  if (Platform.isWindows) {
                    Process.run('explorer', ['/select,', file.path]);
                  } else if (Platform.isMacOS) {
                    Process.run('open', ['-R', file.path]);
                  } else if (Platform.isLinux) {
                    Process.run('xdg-open', [downloadsDir!.path]);
                  }
                },
              ),
            ),
          );
          return;
        }
      } catch (saveErr) {
        // ignore: avoid_print
        print('DEBUG: Auto-save failed: $saveErr');
      }

      // Fallback: Try file picker
      String? outputPath;
      try {
        outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Excel report',
          fileName: defaultFileName,
          type: FileType.custom,
          allowedExtensions: ['xlsx'],
        );
      } catch (_) {
        outputPath = null;
      }

      if (outputPath != null && outputPath.trim().isNotEmpty) {
        try {
          final file = File(outputPath);
          await file.writeAsBytes(bytes, flush: true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Excel saved to: ${file.path}')),
          );
          return;
        } catch (writeErr) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to save: $writeErr')));
        }
      }

      // Final fallback
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save Excel file. Please try again.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Excel export failed: $e')));
    }
  }
}

class _MetricItem extends StatelessWidget {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final bool isWeb;

  const _MetricItem({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.isWeb,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isWeb ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isWeb ? 14 : 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: isWeb ? 8 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isWeb ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF333333),
            ),
          ),
          SizedBox(height: isWeb ? 6 : 4),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                size: isWeb ? 18 : 16,
                color: isPositive ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                change,
                style: TextStyle(
                  fontSize: isWeb ? 14 : 12,
                  color: isPositive ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// (no extra components)
