import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/encryption_service.dart';
import '../services/session_service.dart';

class TopUpTab extends StatefulWidget {
  const TopUpTab({super.key});

  @override
  State<TopUpTab> createState() => _TopUpTabState();
}

class _TopUpTabState extends State<TopUpTab>
    with SingleTickerProviderStateMixin {
  static const Color evsuRed = Color(0xFFB91C1C);

  // Tab Controller
  late TabController _tabController;

  /// Get current Philippines time as ISO 8601 string (without timezone)
  /// The database now stores plain TIMESTAMP WITHOUT TIME ZONE, so we send plain timestamp
  static String _getPhilippinesTimeISO() {
    // Get current time in UTC and convert to Philippines time (+8 hours)
    final nowUtc = DateTime.now().toUtc();
    final phTime = nowUtc.add(const Duration(hours: 8));
    // Format as ISO 8601 without timezone (database expects plain timestamp)
    // Format: "2025-11-23T14:30:00" (no Z or timezone offset)
    return '${phTime.year}-${phTime.month.toString().padLeft(2, '0')}-${phTime.day.toString().padLeft(2, '0')}T${phTime.hour.toString().padLeft(2, '0')}:${phTime.minute.toString().padLeft(2, '0')}:${phTime.second.toString().padLeft(2, '0')}';
  }

  /// Parse timestamp from database (stored as plain PH time, no conversion needed)
  /// The database now stores timestamps as plain TIMESTAMP WITHOUT TIME ZONE in PH time
  /// So we just parse and display directly without any timezone conversion
  static DateTime _parsePhilippinesTime(String timestampString) {
    // Database stores plain timestamp (e.g., "2025-11-23 14:30:00")
    // Parse it directly - no timezone conversion needed
    return DateTime.parse(timestampString);
  }

  // Manual Top-Up fields
  final TextEditingController _schoolIdController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _feePercentageController = TextEditingController(
    text: '1.0',
  );
  Map<String, dynamic>? _selectedUser;
  bool _isLoading = false;
  String? _validationMessage;
  List<Map<String, dynamic>> _recentTopUps = [];
  bool _isLoadingRecentTopUps = false;

  // Verification fields
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoadingRequests = false;

  @override
  void initState() {
    super.initState();
    print('🚀 DEBUG: TopUpTab initState() called');
    _tabController = TabController(length: 2, vsync: this);
    _amountController.addListener(() {
      setState(() {}); // Rebuild when amount changes
    });
    print('🔍 DEBUG: Loading recent top-ups...');
    _loadRecentTopUps(); // Load recent top-ups when the widget initializes
    print('🔍 DEBUG: Loading pending verification requests...');
    _loadPendingRequests(); // Load pending verification requests

    // Note: Admin notifications are now initialized globally in AdminDashboard
    // No need to initialize here - they work regardless of which tab is active
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _schoolIdController.dispose();
    _feePercentageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth > 600 ? 24.0 : 16.0,
            vertical: 16.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Top-Up Management',
                style: TextStyle(
                  fontSize: isMobile ? 24 : 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage manual top-ups and verify student payment requests',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),

        // Tab Bar
        Container(
          margin: EdgeInsets.symmetric(
            horizontal: screenWidth > 600 ? 24.0 : 16.0,
          ),
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
          child: TabBar(
            controller: _tabController,
            labelColor: evsuRed,
            unselectedLabelColor: Colors.grey,
            indicatorColor: evsuRed,
            indicatorWeight: 3,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            tabs: const [
              Tab(text: 'Manual Top-Up'),
              Tab(text: 'Verification Requests'),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildManualTopUpTab(), _buildVerificationTab()],
          ),
        ),
      ],
    );
  }

  // Manual Top-Up Tab (existing functionality)
  Widget _buildManualTopUpTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top-up form and user info
            LayoutBuilder(
              builder: (context, constraints) {
                bool isWideScreen = constraints.maxWidth > 800;

                return isWideScreen
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildTopUpForm()),
                        const SizedBox(width: 30),
                        Expanded(flex: 1, child: _buildUserInfo()),
                      ],
                    )
                    : Column(
                      children: [
                        _buildTopUpForm(),
                        const SizedBox(height: 30),
                        _buildUserInfo(),
                      ],
                    );
              },
            ),

            const SizedBox(height: 30),
            _buildRecentTopUps(),
          ],
        ),
      ),
    );
  }

  // Verification Tab (new functionality)
  Widget _buildVerificationTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 900;

    return RefreshIndicator(
      onRefresh: _loadPendingRequests,
      color: evsuRed,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Responsive header
              isMobile
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pending Verification Requests',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            onPressed: _loadPendingRequests,
                            icon: const Icon(
                              Icons.refresh,
                              color: evsuRed,
                              size: 20,
                            ),
                            tooltip: 'Refresh',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ],
                  )
                  : Row(
                    children: [
                      Text(
                        'Pending Verification Requests',
                        style: TextStyle(
                          fontSize: isTablet ? 18 : 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _loadPendingRequests,
                        icon: const Icon(Icons.refresh, color: evsuRed),
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
              const SizedBox(height: 16),

              if (_isLoadingRequests)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: evsuRed),
                  ),
                )
              else if (_pendingRequests.isEmpty)
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: const Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          color: Colors.grey,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'No pending verification requests',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ..._pendingRequests
                    .map((request) => _buildRequestCard(request))
                    .toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopUpForm() {
    return Container(
      padding: const EdgeInsets.all(24),
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
            'Top-Up User Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),

          // School ID field with search
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'School ID',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _schoolIdController,
                onChanged: _searchUser,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: evsuRed),
                  hintText: 'Enter School ID (e.g., EVSU-2024-001)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: evsuRed),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Amount field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top-Up Amount',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixText: '₱ ',
                  prefixStyle: const TextStyle(
                    color: evsuRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  hintText: 'Enter amount (e.g., 100.00)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: evsuRed),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Fee Percentage field
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top-Up Fee Percentage',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _feePercentageController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  suffixText: '%',
                  suffixStyle: const TextStyle(
                    color: evsuRed,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  hintText: 'Enter fee percentage (e.g., 1.0)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: evsuRed),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged:
                    (_) => setState(() {}), // Rebuild to update fee display
              ),
              const SizedBox(height: 4),
              if (_amountController.text.isNotEmpty &&
                  _feePercentageController.text.isNotEmpty)
                Builder(
                  builder: (context) {
                    final amount =
                        double.tryParse(_amountController.text) ?? 0.0;
                    final feePercent =
                        double.tryParse(_feePercentageController.text) ?? 1.0;
                    final feeAmount = amount * (feePercent / 100);
                    return Text(
                      'Fee Amount: ₱${feeAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick amount buttons
          const Text(
            'Quick Amount',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                [50, 100, 150, 200, 500].map((amount) {
                  return GestureDetector(
                    onTap: () {
                      _amountController.text = amount.toString();
                      setState(() {}); // Force rebuild
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: evsuRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: evsuRed.withOpacity(0.3)),
                      ),
                      child: Text(
                        '₱$amount',
                        style: TextStyle(
                          color: evsuRed,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 24),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _selectedUser != null && _amountController.text.isNotEmpty
                          ? () => _showTopUpConfirmation()
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _selectedUser != null &&
                                _amountController.text.isNotEmpty
                            ? evsuRed
                            : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _selectedUser == null
                        ? 'Select User First'
                        : _amountController.text.isEmpty
                        ? 'Enter Amount'
                        : 'Process Top-Up',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: _clearForm,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: evsuRed),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Clear',
                  style: TextStyle(color: evsuRed, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
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
            'User Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoading) ...[
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.shade200,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: evsuRed),
                    const SizedBox(height: 8),
                    Text(
                      'Validating ID...',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_selectedUser != null) ...[
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: evsuRed,
                  child: Text(
                    _selectedUser!['name'].toString().substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedUser!['name'].toString(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        'ID: ${_selectedUser!['student_id']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildUserDetailItem(
              'Student ID',
              _selectedUser!['student_id'].toString(),
            ),
            _buildUserDetailItem('Email', _selectedUser!['email'].toString()),
          ] else if (_validationMessage != null) ...[
            Container(
              height: 100,
              decoration: BoxDecoration(
                color:
                    _validationMessage == 'Not registered'
                        ? Colors.red.shade50
                        : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _validationMessage == 'Not registered'
                          ? Colors.red.shade200
                          : Colors.orange.shade200,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _validationMessage == 'Not registered'
                          ? Icons.person_off
                          : Icons.error_outline,
                      color:
                          _validationMessage == 'Not registered'
                              ? Colors.red.shade600
                              : Colors.orange.shade600,
                      size: 32,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _validationMessage!,
                      style: TextStyle(
                        color:
                            _validationMessage == 'Not registered'
                                ? Colors.red.shade700
                                : Colors.orange.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade300,
                  style: BorderStyle.solid,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search, color: Colors.grey.shade400, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Enter School ID to search user',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUserDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTopUps() {
    return Container(
      padding: const EdgeInsets.all(24),
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
                'Recent Top-Ups',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (_isLoadingRecentTopUps)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: evsuRed,
                  ),
                )
              else
                IconButton(
                  onPressed: _loadRecentTopUps,
                  icon: const Icon(Icons.refresh, color: evsuRed),
                  tooltip: 'Refresh',
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isLoadingRecentTopUps)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: evsuRed),
              ),
            )
          else if (_recentTopUps.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Center(
                child: Column(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.grey, size: 48),
                    SizedBox(height: 8),
                    Text(
                      'No recent top-ups found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._recentTopUps.map((topup) => _buildTopUpItem(topup)).toList(),
        ],
      ),
    );
  }

  Widget _buildTopUpItem(Map<String, dynamic> topup) {
    // Parse timestamp directly (database stores plain PH time, no conversion needed)
    final createdAt = _parsePhilippinesTime(topup['created_at']);

    // Format date as DD/MM/YYYY
    final formattedDate =
        '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.year}';

    // Format time in 12-hour format with AM/PM
    final hour12 =
        createdAt.hour == 0
            ? 12
            : createdAt.hour > 12
            ? createdAt.hour - 12
            : createdAt.hour;
    final amPm = createdAt.hour < 12 ? 'AM' : 'PM';
    final formattedTime =
        '${hour12.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')} $amPm';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.green.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.add, color: Colors.green.shade700, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topup['student_name'] ?? 'Unknown Student',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: ${topup['student_id']}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
                Text(
                  '$formattedDate $formattedTime',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 9),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₱${(topup['amount'] as num).toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _searchUser(String schoolId) async {
    if (schoolId.isEmpty) {
      setState(() {
        _selectedUser = null;
        _validationMessage = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _validationMessage = null;
    });

    try {
      // Initialize Supabase if not already done
      await SupabaseService.initialize();

      // Search for student in auth_students table
      final response =
          await SupabaseService.adminClient
              .from('auth_students')
              .select('*')
              .eq('student_id', schoolId.trim())
              .maybeSingle();

      if (response != null) {
        // Decrypt the student data
        final decryptedData = _decryptStudentData(response);

        setState(() {
          _selectedUser = decryptedData;
          _validationMessage = null;
          _isLoading = false;
        });
      } else {
        setState(() {
          _selectedUser = null;
          _validationMessage = 'Not registered';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _selectedUser = null;
        _validationMessage = 'Error validating ID: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _decryptStudentData(Map<String, dynamic> studentData) {
    try {
      // Decrypt the student data
      final decryptedData = EncryptionService.decryptUserData(studentData);

      return {
        'name': decryptedData['name'] ?? 'N/A',
        'student_id': studentData['student_id'],
        'email': decryptedData['email'] ?? 'N/A',
        'course': decryptedData['course'] ?? 'N/A',
        'rfid_id': decryptedData['rfid_id'] ?? 'N/A',
        'balance': studentData['balance']?.toString() ?? '₱0.00',
        'status': 'Active',
        'raw_balance':
            studentData['balance']?.toDouble() ??
            0.0, // Store raw balance for calculations
      };
    } catch (e) {
      // If decryption fails, return basic data
      return {
        'name': 'N/A',
        'student_id': studentData['student_id'],
        'email': 'N/A',
        'course': 'N/A',
        'rfid_id': 'N/A',
        'balance': '₱0.00',
        'status': 'Active',
        'raw_balance': 0.0,
      };
    }
  }

  Future<Map<String, dynamic>> _updateUserBalance({
    required String studentId,
    required double topUpAmount,
    required double adminEarn,
  }) async {
    try {
      // Initialize Supabase if not already done
      await SupabaseService.initialize();

      // Use the database function to process top-up transaction
      // Set processed_by based on admin role
      final processedBy = SessionService.isAdminStaff ? 'staff' : 'admin';

      final response = await SupabaseService.adminClient.rpc(
        'process_top_up_transaction',
        params: {
          'p_student_id': studentId,
          'p_amount': topUpAmount,
          'p_processed_by': processedBy,
          'p_notes': 'Top-up via admin panel',
          'p_transaction_type': 'top_up', // Transaction type parameter
          'p_admin_earn': adminEarn, // Admin fee amount
          'p_vendor_earn': 0.00, // No vendor fee for manual top-ups
        },
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'data': {
            'previous_balance': response['data']['previous_balance'],
            'new_balance': response['data']['new_balance'],
            'top_up_amount': response['data']['amount'],
            'transaction_id': response['data']['transaction_id'],
          },
          'message': 'Balance updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': response['error'] ?? 'Unknown error',
          'message': response['message'] ?? 'Failed to process top-up',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update balance: ${e.toString()}',
      };
    }
  }

  Future<void> _loadRecentTopUps() async {
    setState(() {
      _isLoadingRecentTopUps = true;
    });

    try {
      // Initialize Supabase if not already done
      await SupabaseService.initialize();

      print('🔍 DEBUG: Calling get_recent_top_up_transactions...');

      // Use the database function to get recent top-up transactions
      final response = await SupabaseService.adminClient.rpc(
        'get_recent_top_up_transactions',
        params: {'p_limit': 10},
      );

      print('🔍 DEBUG: Response received: $response');
      print('🔍 DEBUG: Response type: ${response.runtimeType}');

      // Handle different response structures
      List<dynamic> transactions = [];

      if (response is Map<String, dynamic>) {
        // Check if response has 'success' key (new format)
        if (response['success'] == true && response['data'] != null) {
          transactions = response['data'] as List<dynamic>;
          print(
            '🔍 DEBUG: Found ${transactions.length} transactions in response.data',
          );
        }
        // Check if response is directly a list (old format or direct return)
        else if (response.containsKey('data') && response['data'] is List) {
          transactions = response['data'] as List<dynamic>;
          print(
            '🔍 DEBUG: Found ${transactions.length} transactions in response.data (no success key)',
          );
        }
        // Check if response itself is structured as transactions
        else if (response.containsKey('id') ||
            response.containsKey('student_id')) {
          // Single transaction object
          transactions = [response];
          print('🔍 DEBUG: Found single transaction in response');
        }
      } else if (response is List) {
        // Response is directly a list
        transactions = response;
        print(
          '🔍 DEBUG: Response is directly a list with ${transactions.length} items',
        );
      }

      print('🔍 DEBUG: Processing ${transactions.length} transactions...');

      // Decrypt student names in the transactions
      List<Map<String, dynamic>> decryptedTransactions = [];
      for (var transaction in transactions) {
        if (transaction == null || transaction is! Map) {
          print('⚠️ DEBUG: Skipping invalid transaction: $transaction');
          continue;
        }

        final transactionMap = transaction as Map<String, dynamic>;

        Map<String, dynamic> decryptedTransaction = Map<String, dynamic>.from(
          transactionMap,
        );

        // Try to decrypt the student name if it looks encrypted
        String studentName =
            transactionMap['student_name'] ?? 'Unknown Student';
        if (studentName != 'Unknown Student' && studentName.length > 20) {
          try {
            // The name from database might be encrypted, try to decrypt it
            studentName = EncryptionService.decryptData(studentName);
            print('✅ DEBUG: Decrypted student name: $studentName');
          } catch (e) {
            // If decryption fails, use the original name
            print('⚠️ DEBUG: Failed to decrypt student name: $e');
          }
        }

        decryptedTransaction['student_name'] = studentName;
        decryptedTransactions.add(decryptedTransaction);
        print(
          '✅ DEBUG: Added transaction: ${transactionMap['id']} - ${studentName} - ₱${transactionMap['amount']}',
        );
      }

      print(
        '✅ DEBUG: Total decrypted transactions: ${decryptedTransactions.length}',
      );

      // If no transactions found via RPC, try direct query as fallback
      if (decryptedTransactions.isEmpty) {
        print('⚠️ DEBUG: No transactions from RPC, trying direct query...');
        try {
          final directResponse = await SupabaseService.adminClient
              .from('top_up_transactions')
              .select('*, auth_students(student_id, name)')
              .order('created_at', ascending: false)
              .limit(10);

          print(
            '🔍 DEBUG: Direct query returned ${directResponse.length} rows',
          );

          for (final row in directResponse) {
            final studentData = row['auth_students'];
            String studentName = 'Unknown Student';

            if (studentData != null && studentData is Map) {
              final name = studentData['name'];
              if (name != null) {
                try {
                  studentName = EncryptionService.decryptData(name.toString());
                } catch (e) {
                  studentName = name.toString();
                }
              }
            }

            decryptedTransactions.add({
              'id': row['id'],
              'student_id': row['student_id'],
              'student_name': studentName,
              'amount': row['amount'],
              'previous_balance': row['previous_balance'],
              'new_balance': row['new_balance'],
              'transaction_type': row['transaction_type'],
              'processed_by': row['processed_by'],
              'notes': row['notes'],
              'admin_earn': row['admin_earn'] ?? 0.00,
              'vendor_earn': row['vendor_earn'] ?? 0.00,
              'created_at': row['created_at'],
            });
          }

          print(
            '✅ DEBUG: Direct query found ${decryptedTransactions.length} transactions',
          );
        } catch (directError) {
          print('❌ DEBUG: Direct query also failed: $directError');
        }
      }

      // Sort by created_at descending (latest first) to ensure newest transactions appear first
      decryptedTransactions.sort((a, b) {
        try {
          final dateA = _parsePhilippinesTime(a['created_at'] ?? '');
          final dateB = _parsePhilippinesTime(b['created_at'] ?? '');
          return dateB.compareTo(dateA); // Descending order (newest first)
        } catch (e) {
          return 0; // Keep original order if parsing fails
        }
      });

      setState(() {
        _recentTopUps = decryptedTransactions;
        _isLoadingRecentTopUps = false;
      });

      print(
        '✅ DEBUG: State updated with ${decryptedTransactions.length} recent top-ups',
      );
    } catch (e, stackTrace) {
      print('❌ DEBUG: ERROR loading recent top-ups:');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      setState(() {
        _recentTopUps = [];
        _isLoadingRecentTopUps = false;
      });
    }
  }

  void _clearForm() {
    setState(() {
      _schoolIdController.clear();
      _amountController.clear();
      _feePercentageController.text = '1.0'; // Reset to default
      _selectedUser = null;
      _validationMessage = null;
      _isLoading = false;
    });
  }

  void _showTopUpConfirmation() {
    if (_selectedUser == null || _amountController.text.isEmpty) return;

    final topUpAmount = double.tryParse(_amountController.text) ?? 0.0;
    final feePercentage = double.tryParse(_feePercentageController.text) ?? 1.0;
    final adminEarn = topUpAmount * (feePercentage / 100);
    final currentBalance = _selectedUser!['raw_balance'] ?? 0.0;
    final newBalance = currentBalance + topUpAmount;

    showDialog(
      context: context,
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isMobile = screenWidth < 600;
        final isSmallPhone = screenWidth < 360;

        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal:
                isSmallPhone
                    ? 12
                    : isMobile
                    ? 16
                    : 24,
            vertical:
                isSmallPhone
                    ? 12
                    : isMobile
                    ? 16
                    : 24,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? screenWidth * 0.95 : 500,
              maxHeight: screenHeight * 0.85,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(
                  isSmallPhone ? 16 : (isMobile ? 20 : 24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirm Top-Up',
                      style: TextStyle(
                        fontSize: isSmallPhone ? 16 : (isMobile ? 18 : 20),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: isSmallPhone ? 12 : (isMobile ? 14 : 16)),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(isSmallPhone ? 12 : 14),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User: ${_selectedUser!['name']}',
                            style: TextStyle(fontSize: isSmallPhone ? 12 : 13),
                            softWrap: true,
                          ),
                          SizedBox(height: isSmallPhone ? 4 : 6),
                          Text(
                            'Student ID: ${_selectedUser!['student_id']}',
                            style: TextStyle(fontSize: isSmallPhone ? 12 : 13),
                            softWrap: true,
                          ),
                          SizedBox(height: isSmallPhone ? 4 : 6),
                          Text(
                            'Email: ${_selectedUser!['email']}',
                            style: TextStyle(fontSize: isSmallPhone ? 12 : 13),
                            softWrap: true,
                          ),
                          SizedBox(height: isSmallPhone ? 4 : 6),
                          Text(
                            'Course: ${_selectedUser!['course']}',
                            style: TextStyle(fontSize: isSmallPhone ? 12 : 13),
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isSmallPhone ? 12 : (isMobile ? 14 : 16)),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryTile(
                            label: 'Current Balance',
                            value: '₱${currentBalance.toStringAsFixed(2)}',
                          ),
                        ),
                        SizedBox(width: isSmallPhone ? 8 : 12),
                        Expanded(
                          child: _buildSummaryTile(
                            label: 'Top-Up Amount',
                            value: '₱${topUpAmount.toStringAsFixed(2)}',
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isSmallPhone ? 8 : 12),
                    _buildSummaryTile(
                      label: 'Admin Fee (${feePercentage.toStringAsFixed(2)}%)',
                      value: '₱${adminEarn.toStringAsFixed(2)}',
                    ),
                    SizedBox(height: isSmallPhone ? 8 : 12),
                    _buildSummaryTile(
                      label: 'New Balance',
                      value: '₱${newBalance.toStringAsFixed(2)}',
                      highlight: true,
                    ),
                    SizedBox(height: isSmallPhone ? 14 : 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: evsuRed),
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallPhone ? 12 : 14,
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: evsuRed,
                                fontSize: isSmallPhone ? 13 : 14,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: isSmallPhone ? 8 : 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _showTopUpSafetyConfirmation(amount: topUpAmount);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: evsuRed,
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallPhone ? 12 : 14,
                              ),
                            ),
                            child: Text(
                              'Confirm',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isSmallPhone ? 13 : 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTopUpSafetyConfirmation({required double amount}) {
    if (_selectedUser == null) {
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Are you sure?'),
            content: Text(
              'Are you sure you want to top-up ₱${amount.toStringAsFixed(2)} '
              'to ${_selectedUser!['name']} (${_selectedUser!['student_id']})?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('No, cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _processTopUp();
                },
                style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                child: const Text(
                  'Yes, top-up',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _processTopUp() async {
    if (_selectedUser == null || _amountController.text.isEmpty) return;

    final topUpAmount = double.tryParse(_amountController.text) ?? 0.0;
    final feePercentage = double.tryParse(_feePercentageController.text) ?? 1.0;
    final adminEarn = topUpAmount * (feePercentage / 100);
    final studentId = _selectedUser!['student_id'];

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: evsuRed),
                const SizedBox(height: 16),
                Text(
                  'Processing top-up of ₱${topUpAmount.toStringAsFixed(2)}...',
                ),
              ],
            ),
          ),
    );

    try {
      // Update the balance
      final result = await _updateUserBalance(
        studentId: studentId,
        topUpAmount: topUpAmount,
        adminEarn: adminEarn,
      );

      // Close loading dialog
      Navigator.pop(context);

      if (result['success']) {
        // Update the local user data
        setState(() {
          _selectedUser!['raw_balance'] = result['data']['new_balance'];
          _selectedUser!['balance'] =
              '₱${result['data']['new_balance'].toStringAsFixed(2)}';
        });

        // Refresh recent top-ups to show the new transaction
        _loadRecentTopUps();

        // Show success dialog (responsive, scrollable to avoid overflow)
        showDialog(
          context: context,
          builder: (context) {
            final screenWidth = MediaQuery.of(context).size.width;
            final screenHeight = MediaQuery.of(context).size.height;
            final isMobile = screenWidth < 600;
            final isSmallPhone = screenWidth < 360;

            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal:
                    isSmallPhone
                        ? 12
                        : isMobile
                        ? 16
                        : 24,
                vertical:
                    isSmallPhone
                        ? 12
                        : isMobile
                        ? 16
                        : 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? screenWidth * 0.95 : 500,
                  maxHeight: screenHeight * 0.85,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(
                      isSmallPhone ? 16 : (isMobile ? 20 : 24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: isSmallPhone ? 22 : (isMobile ? 24 : 28),
                            ),
                            SizedBox(
                              width: isSmallPhone ? 6 : (isMobile ? 8 : 10),
                            ),
                            Expanded(
                              child: Text(
                                'Top-Up Successful',
                                style: TextStyle(
                                  fontSize:
                                      isSmallPhone ? 14 : (isMobile ? 16 : 18),
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                          height: isSmallPhone ? 12 : (isMobile ? 14 : 16),
                        ),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(isSmallPhone ? 12 : 14),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'User: ${_selectedUser!['name']}',
                                style: TextStyle(
                                  fontSize: isSmallPhone ? 12 : 13,
                                ),
                                softWrap: true,
                              ),
                              SizedBox(height: isSmallPhone ? 4 : 6),
                              Text(
                                'Student ID: ${_selectedUser!['student_id']}',
                                style: TextStyle(
                                  fontSize: isSmallPhone ? 12 : 13,
                                ),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: isSmallPhone ? 12 : (isMobile ? 14 : 16),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryTile(
                                label: 'Previous Balance',
                                value:
                                    '₱${result['data']['previous_balance'].toStringAsFixed(2)}',
                              ),
                            ),
                            SizedBox(width: isSmallPhone ? 8 : 12),
                            Expanded(
                              child: _buildSummaryTile(
                                label: 'Top-Up Amount',
                                value:
                                    '₱${result['data']['top_up_amount'].toStringAsFixed(2)}',
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallPhone ? 8 : 12),
                        _buildSummaryTile(
                          label: 'Admin Fee',
                          value:
                              '₱${(result['data']['admin_earn'] ?? 0.00).toStringAsFixed(2)}',
                        ),
                        SizedBox(height: isSmallPhone ? 8 : 12),
                        _buildSummaryTile(
                          label: 'New Balance',
                          value:
                              '₱${result['data']['new_balance'].toStringAsFixed(2)}',
                          highlight: true,
                        ),
                        SizedBox(height: isSmallPhone ? 14 : 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _clearForm();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: evsuRed,
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallPhone ? 12 : 14,
                              ),
                            ),
                            child: const Text(
                              'OK',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      } else {
        // Show error dialog (responsive)
        showDialog(
          context: context,
          builder: (context) {
            final screenWidth = MediaQuery.of(context).size.width;
            final isMobile = screenWidth < 600;
            final isSmallPhone = screenWidth < 360;

            return Dialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal:
                    isSmallPhone
                        ? 12
                        : isMobile
                        ? 16
                        : 24,
                vertical:
                    isSmallPhone
                        ? 12
                        : isMobile
                        ? 16
                        : 24,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isMobile ? screenWidth * 0.95 : 500,
                ),
                child: Padding(
                  padding: EdgeInsets.all(
                    isSmallPhone ? 16 : (isMobile ? 20 : 24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.error,
                            color: Colors.red,
                            size: isSmallPhone ? 22 : (isMobile ? 24 : 28),
                          ),
                          SizedBox(
                            width: isSmallPhone ? 6 : (isMobile ? 8 : 10),
                          ),
                          Expanded(
                            child: Text(
                              'Top-Up Failed',
                              style: TextStyle(
                                fontSize:
                                    isSmallPhone ? 14 : (isMobile ? 16 : 18),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: isSmallPhone ? 12 : (isMobile ? 14 : 16),
                      ),
                      Text(
                        result['message'] ??
                            'An error occurred while processing the top-up.',
                        style: TextStyle(
                          fontSize: isSmallPhone ? 12 : (isMobile ? 13 : 14),
                        ),
                        softWrap: true,
                      ),
                      SizedBox(
                        height: isSmallPhone ? 14 : (isMobile ? 16 : 20),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: evsuRed,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallPhone ? 12 : 14,
                            ),
                          ),
                          child: const Text(
                            'OK',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      // Show error dialog (responsive)
      showDialog(
        context: context,
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final isMobile = screenWidth < 600;
          final isSmallPhone = screenWidth < 360;

          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal:
                  isSmallPhone
                      ? 12
                      : isMobile
                      ? 16
                      : 24,
              vertical:
                  isSmallPhone
                      ? 12
                      : isMobile
                      ? 16
                      : 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? screenWidth * 0.95 : 500,
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(
                    isSmallPhone ? 16 : (isMobile ? 20 : 24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.error,
                            color: Colors.red,
                            size: isSmallPhone ? 22 : (isMobile ? 24 : 28),
                          ),
                          SizedBox(
                            width: isSmallPhone ? 6 : (isMobile ? 8 : 10),
                          ),
                          Expanded(
                            child: Text(
                              'Top-Up Failed',
                              style: TextStyle(
                                fontSize:
                                    isSmallPhone ? 14 : (isMobile ? 16 : 18),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: isSmallPhone ? 12 : (isMobile ? 14 : 16),
                      ),
                      Text(
                        'An unexpected error occurred: ${e.toString()}',
                        style: TextStyle(
                          fontSize: isSmallPhone ? 12 : (isMobile ? 13 : 14),
                        ),
                        softWrap: true,
                      ),
                      SizedBox(
                        height: isSmallPhone ? 14 : (isMobile ? 16 : 20),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: evsuRed,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallPhone ? 12 : 14,
                            ),
                          ),
                          child: const Text(
                            'OK',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    }
  }

  // =====================================================
  // VERIFICATION TAB METHODS
  // =====================================================

  /// Load pending verification requests from top_up_requests table
  Future<void> _loadPendingRequests() async {
    print('🔍 DEBUG: Starting _loadPendingRequests()...');

    setState(() {
      _isLoadingRequests = true;
    });

    try {
      print('🔍 DEBUG: Initializing SupabaseService...');
      await SupabaseService.initialize();
      print('✅ DEBUG: SupabaseService initialized successfully');

      // Debug: Check adminClient configuration
      print('🔍 DEBUG: Admin client ready for service_role operations');
      print('🔍 DEBUG: Attempting to query top_up_requests table...');

      // First, try to get raw data without join to test basic access
      print(
        '🔍 DEBUG: Attempting to fetch raw top_up_requests (without join)...',
      );
      try {
        final rawTest = await SupabaseService.adminClient
            .from('top_up_requests')
            .select('*')
            .limit(5);
        print(
          '✅ DEBUG: Raw query successful! Found ${rawTest.length} total records',
        );
        print(
          '🔍 DEBUG: Sample raw data: ${rawTest.isNotEmpty ? rawTest[0] : "No data"}',
        );
      } catch (rawError) {
        print('❌ DEBUG: Raw query FAILED: $rawError');
        print('❌ DEBUG: Error type: ${rawError.runtimeType}');
        if (rawError.toString().contains('relation') ||
            rawError.toString().contains('does not exist')) {
          print('❌ DEBUG: TABLE NOT FOUND in database!');
          print(
            '❌ DEBUG: Run create_top_up_requests_table.sql in Supabase SQL Editor',
          );
        } else if (rawError.toString().contains('permission') ||
            rawError.toString().contains('denied')) {
          print('❌ DEBUG: PERMISSION DENIED - Check RLS policies!');
          print(
            '❌ DEBUG: Run fix_top_up_requests_access.sql in Supabase SQL Editor',
          );
        } else {
          print(
            '❌ DEBUG: Unknown error - Check your Supabase service_role key in .env',
          );
        }
      }

      // Now try with status filter
      print(
        '🔍 DEBUG: Fetching pending requests (status = "Pending Verification")...',
      );
      final pendingTest = await SupabaseService.adminClient
          .from('top_up_requests')
          .select('*')
          .eq('status', 'Pending Verification');
      print(
        '✅ DEBUG: Found ${pendingTest.length} requests with status "Pending Verification"',
      );

      if (pendingTest.isEmpty) {
        print('⚠️  DEBUG: No pending requests found! Check if:');
        print(
          '   1. Data exists in database with status = "Pending Verification"',
        );
        print(
          '   2. Status field is exactly "Pending Verification" (case-sensitive)',
        );
        setState(() {
          _pendingRequests = [];
          _isLoadingRequests = false;
        });
        return;
      }

      // Try to fetch with student info join (using LEFT JOIN instead of INNER)
      print('🔍 DEBUG: Attempting to join with auth_students table...');

      List<Map<String, dynamic>> response;
      try {
        // Try with LEFT JOIN first (more forgiving)
        response = List<Map<String, dynamic>>.from(
          await SupabaseService.adminClient
              .from('top_up_requests')
              .select('*, auth_students(student_id, name, email)')
              .eq('status', 'Pending Verification')
              .order('created_at', ascending: false),
        );
        print(
          '✅ DEBUG: Query with LEFT JOIN successful! Found ${response.length} records',
        );
      } catch (joinError) {
        print(
          '⚠️  DEBUG: JOIN failed, fetching without student details: $joinError',
        );
        // Fallback: Fetch without join
        response = List<Map<String, dynamic>>.from(
          await SupabaseService.adminClient
              .from('top_up_requests')
              .select('*')
              .eq('status', 'Pending Verification')
              .order('created_at', ascending: false),
        );
        print(
          '✅ DEBUG: Query without JOIN successful! Found ${response.length} records',
        );
      }

      print('🔍 DEBUG: Response type: ${response.runtimeType}');
      print(
        '🔍 DEBUG: First record: ${response.isNotEmpty ? response[0] : "Empty"}',
      );

      List<Map<String, dynamic>> requests = [];
      for (var i = 0; i < response.length; i++) {
        var request = response[i];
        print('🔍 DEBUG: Processing request ${i + 1}/${response.length}');
        print('   - Request ID: ${request['id']}');
        print('   - User ID: ${request['user_id']}');
        print('   - Amount: ${request['amount']}');
        print('   - Status: ${request['status']}');
        print(
          '   - Has auth_students data: ${request.containsKey('auth_students')}',
        );

        // Decrypt student name if encrypted
        String studentName = 'Unknown Student';
        try {
          final studentData = request['auth_students'];
          if (studentData != null && studentData is Map) {
            print('   - Student data found: $studentData');
            if (studentData['name'] != null) {
              print('   - Attempting to decrypt name...');
              studentName = EncryptionService.decryptData(studentData['name']);
              print('   ✅ Decrypted name: $studentName');
            } else {
              print('   ⚠️  Student name is null');
            }
          } else {
            print('   ⚠️  No student data from join, will use user_id');
            // Fallback: Fetch student data manually by user_id
            final userId = request['user_id'];
            if (userId != null) {
              try {
                final studentResponse =
                    await SupabaseService.adminClient
                        .from('auth_students')
                        .select('name')
                        .eq('student_id', userId)
                        .maybeSingle();

                if (studentResponse != null &&
                    studentResponse['name'] != null) {
                  studentName = EncryptionService.decryptData(
                    studentResponse['name'],
                  );
                  print('   ✅ Fetched and decrypted name: $studentName');
                } else {
                  studentName = 'Student $userId';
                  print('   ⚠️  Using fallback name: $studentName');
                }
              } catch (fetchError) {
                studentName = 'Student $userId';
                print(
                  '   ⚠️  Failed to fetch student, using fallback: $fetchError',
                );
              }
            }
          }
        } catch (e) {
          print('   ❌ Failed to decrypt student name: $e');
          // Use user_id as fallback
          final userId = request['user_id'];
          studentName = userId != null ? 'Student $userId' : 'Unknown Student';
        }

        requests.add({
          'id': request['id'],
          'user_id': request['user_id'],
          'amount': request['amount'],
          'screenshot_url': request['screenshot_url'],
          'gcash_reference': request['gcash_reference'] ?? 'N/A',
          'status': request['status'],
          'created_at': request['created_at'],
          'student_name': studentName,
        });
        print('   ✅ Added request to list');
      }

      print('✅ DEBUG: Processed ${requests.length} requests successfully');
      print('🔍 DEBUG: Setting state with ${requests.length} requests...');

      setState(() {
        _pendingRequests = requests;
        _isLoadingRequests = false;
      });

      print(
        '✅ DEBUG: State updated! UI should now show ${requests.length} requests',
      );
    } catch (e, stackTrace) {
      print('❌ DEBUG: ERROR in _loadPendingRequests:');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      print('   Error type: ${e.runtimeType}');

      // Try to provide more specific error info
      if (e.toString().contains('permission denied')) {
        print(
          '❌ DEBUG: PERMISSION DENIED - Admin cannot access top_up_requests',
        );
        print(
          '   Solution: Run fix_top_up_requests_access.sql in Supabase SQL Editor',
        );
      } else if (e.toString().contains('relation') ||
          e.toString().contains('does not exist')) {
        print('❌ DEBUG: TABLE NOT FOUND - top_up_requests table may not exist');
        print(
          '   Solution: Create the table using the schema in documentation',
        );
      } else if (e.toString().contains('column')) {
        print('❌ DEBUG: COLUMN ERROR - Table structure may be incorrect');
        print('   Check that all required columns exist in top_up_requests');
      }

      setState(() {
        _pendingRequests = [];
        _isLoadingRequests = false;
      });
    }
  }

  /// Build a request card displaying student info and proof
  Widget _buildRequestCard(Map<String, dynamic> request) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Parse timestamp directly (database stores plain PH time, no conversion needed)
    final createdAt = _parsePhilippinesTime(request['created_at']);
    final formattedDate =
        '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    final formattedTime =
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with student info
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: evsuRed,
                  radius: isMobile ? 18 : 20,
                  child: Text(
                    request['student_name']
                        .toString()
                        .substring(0, 1)
                        .toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 16,
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['student_name'] ?? 'Unknown Student',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'ID: ${request['user_id']}',
                        style: TextStyle(
                          fontSize: isMobile ? 10 : 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isMobile ? 4 : 8),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 8 : 12,
                    vertical: isMobile ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '₱${request['amount']}',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w700,
                      fontSize: isMobile ? 14 : 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Request details
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: isMobile ? 14 : 16,
                      color: Colors.grey.shade600,
                    ),
                    SizedBox(width: isMobile ? 4 : 6),
                    Expanded(
                      child: Text(
                        'Submitted: $formattedDate at $formattedTime',
                        style: TextStyle(
                          fontSize: isMobile ? 10 : 12,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 6 : 8),

                // GCash Reference Number
                if (request['gcash_reference'] != null &&
                    request['gcash_reference'] != 'N/A')
                  Row(
                    children: [
                      Icon(
                        Icons.payment,
                        size: isMobile ? 14 : 16,
                        color: Colors.orange.shade700,
                      ),
                      SizedBox(width: isMobile ? 4 : 6),
                      Expanded(
                        child: Text(
                          'GCash Ref: ${request['gcash_reference']}',
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: isMobile ? 8 : 12),

                // Proof of payment preview
                GestureDetector(
                  onTap: () => _showRequestDetails(request),
                  child: Container(
                    height: isMobile ? 150 : 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        request['screenshot_url'],
                        fit: BoxFit.cover,
                        width: double.infinity,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value:
                                  loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                              color: evsuRed,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: Colors.grey.shade400,
                                  size: 48,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 6 : 8),
                Center(
                  child: Text(
                    'Tap to view full image',
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 12 : 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(request),
                        icon: Icon(Icons.close, size: isMobile ? 16 : 18),
                        label: Text(
                          'Reject',
                          style: TextStyle(fontSize: isMobile ? 12 : 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 12,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showApproveDialog(request),
                        icon: Icon(Icons.check, size: isMobile ? 16 : 18),
                        label: Text(
                          'Approve',
                          style: TextStyle(fontSize: isMobile ? 12 : 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 12,
                          ),
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
    );
  }

  /// Show full request details in a dialog
  void _showRequestDetails(Map<String, dynamic> request) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;

    // Parse timestamp directly (database stores plain PH time, no conversion needed)
    final createdAt = _parsePhilippinesTime(request['created_at']);
    final formattedDateTime =
        '${createdAt.day}/${createdAt.month}/${createdAt.year} at ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isMobile ? screenWidth * 0.95 : 600,
                maxHeight: screenHeight * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    decoration: BoxDecoration(
                      color: evsuRed,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: isMobile ? 20 : 24,
                        ),
                        SizedBox(width: isMobile ? 8 : 12),
                        Text(
                          'Request Details',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isMobile ? 16 : 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: isMobile ? 20 : 24,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(
                              'Student Name',
                              request['student_name'],
                              isMobile: isMobile,
                            ),
                            _buildDetailRow(
                              'Student ID',
                              request['user_id'],
                              isMobile: isMobile,
                            ),
                            _buildDetailRow(
                              'Amount',
                              '₱${request['amount']}',
                              isMobile: isMobile,
                            ),
                            _buildDetailRow(
                              'GCash Reference',
                              request['gcash_reference'] ?? 'N/A',
                              isMobile: isMobile,
                            ),
                            _buildDetailRow(
                              'Submitted',
                              formattedDateTime,
                              isMobile: isMobile,
                            ),
                            _buildDetailRow(
                              'Status',
                              request['status'],
                              isMobile: isMobile,
                            ),
                            SizedBox(height: isMobile ? 16 : 20),
                            Text(
                              'Proof of Payment',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: isMobile ? 6 : 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: double.infinity,
                                  maxHeight:
                                      isMobile
                                          ? screenHeight * 0.4
                                          : screenHeight * 0.6,
                                ),
                                child: Image.network(
                                  request['screenshot_url'],
                                  fit: BoxFit.contain,
                                  width: double.infinity,
                                  loadingBuilder: (
                                    context,
                                    child,
                                    loadingProgress,
                                  ) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      height: 200,
                                      alignment: Alignment.center,
                                      child: CircularProgressIndicator(
                                        value:
                                            loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                        .cumulativeBytesLoaded /
                                                    loadingProgress
                                                        .expectedTotalBytes!
                                                : null,
                                        color: evsuRed,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.error_outline,
                                              size: 48,
                                              color: Colors.grey,
                                            ),
                                            SizedBox(height: 8),
                                            Text('Failed to load image'),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isMobile = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isMobile ? 90 : 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 11 : 13,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 11 : 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Show approve confirmation dialog
  void _showApproveDialog(Map<String, dynamic> request) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;
    final isSmallPhone = screenWidth < 400;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal:
                  isSmallPhone
                      ? 12
                      : isMobile
                      ? 16
                      : 24,
              vertical:
                  isSmallPhone
                      ? 12
                      : isMobile
                      ? 16
                      : 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? screenWidth * 0.95 : 500,
                maxHeight: screenHeight * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isSmallPhone
                          ? 16
                          : isMobile
                          ? 20
                          : 24,
                      isSmallPhone
                          ? 16
                          : isMobile
                          ? 20
                          : 24,
                      isSmallPhone
                          ? 16
                          : isMobile
                          ? 20
                          : 24,
                      isSmallPhone
                          ? 12
                          : isMobile
                          ? 16
                          : 20,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size:
                              isSmallPhone
                                  ? 22
                                  : isMobile
                                  ? 24
                                  : 28,
                        ),
                        SizedBox(
                          width:
                              isSmallPhone
                                  ? 6
                                  : isMobile
                                  ? 8
                                  : 10,
                        ),
                        Expanded(
                          child: Text(
                            'Approve Top-Up Request',
                            style: TextStyle(
                              fontSize:
                                  isSmallPhone
                                      ? 14
                                      : isMobile
                                      ? 16
                                      : 20,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal:
                            isSmallPhone
                                ? 16
                                : isMobile
                                ? 20
                                : 24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Are you sure you want to approve this top-up request?',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize:
                                  isSmallPhone
                                      ? 12
                                      : isMobile
                                      ? 13
                                      : 14,
                            ),
                          ),
                          SizedBox(
                            height:
                                isSmallPhone
                                    ? 12
                                    : isMobile
                                    ? 14
                                    : 16,
                          ),
                          _buildInfoRow(
                            'Student:',
                            request['student_name']?.toString() ?? 'N/A',
                            isSmallPhone,
                            isMobile,
                          ),
                          SizedBox(
                            height:
                                isSmallPhone
                                    ? 6
                                    : isMobile
                                    ? 8
                                    : 10,
                          ),
                          _buildInfoRow(
                            'Student ID:',
                            request['user_id']?.toString() ?? 'N/A',
                            isSmallPhone,
                            isMobile,
                          ),
                          SizedBox(
                            height:
                                isSmallPhone
                                    ? 6
                                    : isMobile
                                    ? 8
                                    : 10,
                          ),
                          Text(
                            'Amount: ₱${request['amount']?.toString() ?? '0.00'}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize:
                                  isSmallPhone
                                      ? 13
                                      : isMobile
                                      ? 14
                                      : 16,
                              color: Colors.green,
                            ),
                          ),
                          SizedBox(
                            height:
                                isSmallPhone
                                    ? 12
                                    : isMobile
                                    ? 14
                                    : 16,
                          ),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(
                              isSmallPhone
                                  ? 10
                                  : isMobile
                                  ? 12
                                  : 14,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              'This will add ₱${request['amount']?.toString() ?? '0.00'} to the student\'s balance and record the transaction.',
                              style: TextStyle(
                                fontSize:
                                    isSmallPhone
                                        ? 10
                                        : isMobile
                                        ? 11
                                        : 12,
                              ),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Actions
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isSmallPhone
                          ? 12
                          : isMobile
                          ? 16
                          : 20,
                      isSmallPhone
                          ? 12
                          : isMobile
                          ? 16
                          : 20,
                      isSmallPhone
                          ? 12
                          : isMobile
                          ? 16
                          : 20,
                      isSmallPhone
                          ? 12
                          : isMobile
                          ? 16
                          : 20,
                    ),
                    child:
                        isSmallPhone
                            ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      Navigator.pop(context);
                                      _approveRequest(request);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      padding: EdgeInsets.symmetric(
                                        vertical: isSmallPhone ? 12 : 14,
                                      ),
                                    ),
                                    child: Text(
                                      'Approve',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: isSmallPhone ? 13 : 14,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontSize: isSmallPhone ? 13 : 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                            : Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: isMobile ? 12 : 14,
                                    ),
                                  ),
                                ),
                                SizedBox(width: isMobile ? 8 : 12),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _approveRequest(request);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 16 : 20,
                                      vertical: isMobile ? 10 : 12,
                                    ),
                                  ),
                                  child: Text(
                                    'Approve',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isMobile ? 12 : 14,
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
  }

  /// Helper widget for info rows
  Widget _buildInfoRow(
    String label,
    String value,
    bool isSmallPhone,
    bool isMobile,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize:
                isSmallPhone
                    ? 11
                    : isMobile
                    ? 12
                    : 14,
          ),
        ),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize:
                  isSmallPhone
                      ? 11
                      : isMobile
                      ? 12
                      : 14,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  /// Show reject confirmation dialog
  void _showRejectDialog(Map<String, dynamic> request) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            contentPadding: EdgeInsets.all(isMobile ? 16 : 24),
            title: Row(
              children: [
                Icon(Icons.cancel, color: Colors.red, size: isMobile ? 24 : 28),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    'Reject Top-Up Request',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 20,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to reject this request?',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 13 : 14,
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  Text(
                    'Student: ${request['student_name']}',
                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                  ),
                  SizedBox(height: isMobile ? 4 : 8),
                  Text(
                    'Amount: ₱${request['amount']}',
                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: 'Reason for rejection (optional)',
                      labelStyle: TextStyle(fontSize: isMobile ? 12 : 14),
                      border: const OutlineInputBorder(),
                      hintText: 'e.g., Invalid reference number',
                      hintStyle: TextStyle(fontSize: isMobile ? 11 : 12),
                      contentPadding: EdgeInsets.all(isMobile ? 10 : 12),
                    ),
                    style: TextStyle(fontSize: isMobile ? 12 : 14),
                    maxLines: isMobile ? 3 : 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(fontSize: isMobile ? 12 : 14),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _rejectRequest(request, reasonController.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 12 : 16,
                    vertical: isMobile ? 8 : 12,
                  ),
                ),
                child: Text(
                  'Reject',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ),
            ],
            actionsPadding: EdgeInsets.all(isMobile ? 8 : 16),
          ),
    );
  }

  /// Approve a top-up request
  Future<void> _approveRequest(Map<String, dynamic> request) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: evsuRed),
                SizedBox(height: 16),
                Text('Processing approval...'),
              ],
            ),
          ),
    );

    try {
      await SupabaseService.initialize();

      // Get student's current balance
      final studentResponse =
          await SupabaseService.adminClient
              .from('auth_students')
              .select('balance')
              .eq('student_id', request['user_id'])
              .single();

      final currentBalance = (studentResponse['balance'] ?? 0.0).toDouble();
      final topUpAmount = (request['amount'] as int).toDouble();
      final newBalance = currentBalance + topUpAmount;

      // Update student balance
      await SupabaseService.adminClient
          .from('auth_students')
          .update({
            'balance': newBalance,
            'updated_at': _getPhilippinesTimeISO(),
          })
          .eq('student_id', request['user_id']);

      // Insert into top_up_transactions
      // NOTE: DB check constraint likely allows only specific values for transaction_type (e.g., 'top_up', 'loan_disbursement').
      // To avoid violating the constraint, we use 'top_up' here and encode GCASH source in metadata fields.
      // Set processed_by based on admin role
      final processedBy =
          SessionService.isAdminStaff
              ? 'Staff (GCash Verification)'
              : 'Admin (GCash Verification)';

      await SupabaseService.adminClient.from('top_up_transactions').insert({
        'student_id': request['user_id'],
        'amount': topUpAmount,
        'previous_balance': currentBalance,
        'new_balance': newBalance,
        'transaction_type': 'top_up_gcash',
        'processed_by': processedBy,
        'notes': 'GCash payment verification • Request ID: ${request['id']}',
        'created_at': _getPhilippinesTimeISO(),
      });

      // Delete proof of payment image from storage bucket before deleting the record
      try {
        final screenshotUrl = request['screenshot_url']?.toString() ?? '';
        if (screenshotUrl.isNotEmpty) {
          // Extract file path from URL
          // URL format: https://[project].supabase.co/storage/v1/object/public/Proof%20Payment/[filename]
          // or: Proof Payment/[filename]
          String filePath = '';

          if (screenshotUrl.contains('/storage/v1/object/public/')) {
            // Full URL format - extract path after 'Proof Payment' or 'Proof%20Payment'
            final parts = screenshotUrl.split('/storage/v1/object/public/');
            if (parts.length > 1) {
              final pathAfterBucket = parts[1];
              // Remove bucket name and get just the filename
              if (pathAfterBucket.startsWith('Proof%20Payment/')) {
                filePath = pathAfterBucket.replaceFirst('Proof%20Payment/', '');
              } else if (pathAfterBucket.startsWith('Proof Payment/')) {
                filePath = pathAfterBucket.replaceFirst('Proof Payment/', '');
              } else {
                // Try to find the filename directly
                final pathParts = pathAfterBucket.split('/');
                if (pathParts.length > 1) {
                  filePath = pathParts.sublist(1).join('/');
                } else {
                  filePath = pathParts.last;
                }
              }
            }
          } else if (screenshotUrl.contains('Proof Payment/') ||
              screenshotUrl.contains('Proof%20Payment/')) {
            // Direct path format
            filePath = screenshotUrl
                .replaceFirst('Proof Payment/', '')
                .replaceFirst('Proof%20Payment/', '');
          } else {
            // Assume it's just the filename
            filePath = screenshotUrl.split('/').last;
          }

          // Decode URL encoding if present
          filePath = Uri.decodeComponent(filePath);

          if (filePath.isNotEmpty) {
            print('DEBUG: Deleting proof of payment image: $filePath');
            await SupabaseService.adminClient.storage
                .from('Proof Payment')
                .remove([filePath]);
            print('DEBUG: Successfully deleted proof of payment image');
          } else {
            print(
              'WARNING: Could not extract file path from screenshot_url: $screenshotUrl',
            );
          }
        } else {
          print('WARNING: screenshot_url is empty, skipping image deletion');
        }
      } catch (storageError) {
        // Log error but don't fail the approval process
        print(
          'WARNING: Failed to delete proof of payment image: $storageError',
        );
        print(
          'DEBUG: Continuing with approval despite storage deletion failure',
        );
      }

      // Delete from top_up_requests
      await SupabaseService.adminClient
          .from('top_up_requests')
          .delete()
          .eq('id', request['id']);

      // Close loading dialog
      Navigator.pop(context);

      // Refresh lists
      _loadPendingRequests();
      _loadRecentTopUps();

      // Show success dialog (responsive, scrollable to avoid overflow)
      showDialog(
        context: context,
        builder: (context) {
          final screenWidth = MediaQuery.of(context).size.width;
          final screenHeight = MediaQuery.of(context).size.height;
          final isMobile = screenWidth < 600;
          final isSmallPhone = screenWidth < 360;

          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal:
                  isSmallPhone
                      ? 12
                      : isMobile
                      ? 16
                      : 24,
              vertical:
                  isSmallPhone
                      ? 12
                      : isMobile
                      ? 16
                      : 24,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isMobile ? screenWidth * 0.95 : 500,
                maxHeight: screenHeight * 0.85,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(
                    isSmallPhone ? 16 : (isMobile ? 20 : 24),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: isSmallPhone ? 22 : (isMobile ? 24 : 28),
                          ),
                          SizedBox(
                            width: isSmallPhone ? 6 : (isMobile ? 8 : 10),
                          ),
                          Expanded(
                            child: Text(
                              'Request Approved',
                              style: TextStyle(
                                fontSize:
                                    isSmallPhone ? 14 : (isMobile ? 16 : 18),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                        height: isSmallPhone ? 12 : (isMobile ? 14 : 16),
                      ),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isSmallPhone ? 12 : 14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Student: ${request['student_name']}',
                              style: TextStyle(
                                fontSize: isSmallPhone ? 12 : 13,
                              ),
                              softWrap: true,
                            ),
                            SizedBox(height: isSmallPhone ? 4 : 6),
                            Text(
                              'Student ID: ${request['user_id']}',
                              style: TextStyle(
                                fontSize: isSmallPhone ? 12 : 13,
                              ),
                              softWrap: true,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: isSmallPhone ? 12 : (isMobile ? 14 : 16),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryTile(
                              label: 'Previous Balance',
                              value: '₱${currentBalance.toStringAsFixed(2)}',
                            ),
                          ),
                          SizedBox(width: isSmallPhone ? 8 : 12),
                          Expanded(
                            child: _buildSummaryTile(
                              label: 'Top-Up Amount',
                              value: '₱${topUpAmount.toStringAsFixed(2)}',
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallPhone ? 8 : 12),
                      _buildSummaryTile(
                        label: 'New Balance',
                        value: '₱${newBalance.toStringAsFixed(2)}',
                        highlight: true,
                      ),
                      SizedBox(height: isSmallPhone ? 14 : 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: evsuRed,
                            padding: EdgeInsets.symmetric(
                              vertical: isSmallPhone ? 12 : 14,
                            ),
                          ),
                          child: const Text(
                            'OK',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      // Show error dialog
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Text('Approval Failed'),
                ],
              ),
              content: Text('Failed to approve request: ${e.toString()}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }

  // Small helper to render a labeled value in the success dialog
  Widget _buildSummaryTile({
    required String label,
    required String value,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? Colors.green.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: highlight ? Colors.green.shade800 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// Reject a top-up request
  Future<void> _rejectRequest(
    Map<String, dynamic> request,
    String reason,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: evsuRed),
                SizedBox(height: 16),
                Text('Processing rejection...'),
              ],
            ),
          ),
    );

    try {
      await SupabaseService.initialize();

      // Delete proof of payment image from storage bucket before deleting the record
      try {
        final screenshotUrl = request['screenshot_url']?.toString() ?? '';
        if (screenshotUrl.isNotEmpty) {
          // Extract file path from URL
          // URL format: https://[project].supabase.co/storage/v1/object/public/Proof%20Payment/[filename]
          // or: Proof Payment/[filename]
          String filePath = '';

          if (screenshotUrl.contains('/storage/v1/object/public/')) {
            // Full URL format - extract path after 'Proof Payment' or 'Proof%20Payment'
            final parts = screenshotUrl.split('/storage/v1/object/public/');
            if (parts.length > 1) {
              final pathAfterBucket = parts[1];
              // Remove bucket name and get just the filename
              if (pathAfterBucket.startsWith('Proof%20Payment/')) {
                filePath = pathAfterBucket.replaceFirst('Proof%20Payment/', '');
              } else if (pathAfterBucket.startsWith('Proof Payment/')) {
                filePath = pathAfterBucket.replaceFirst('Proof Payment/', '');
              } else {
                // Try to find the filename directly
                final pathParts = pathAfterBucket.split('/');
                if (pathParts.length > 1) {
                  filePath = pathParts.sublist(1).join('/');
                } else {
                  filePath = pathParts.last;
                }
              }
            }
          } else if (screenshotUrl.contains('Proof Payment/') ||
              screenshotUrl.contains('Proof%20Payment/')) {
            // Direct path format
            filePath = screenshotUrl
                .replaceFirst('Proof Payment/', '')
                .replaceFirst('Proof%20Payment/', '');
          } else {
            // Assume it's just the filename
            filePath = screenshotUrl.split('/').last;
          }

          // Decode URL encoding if present
          filePath = Uri.decodeComponent(filePath);

          if (filePath.isNotEmpty) {
            print(
              'DEBUG: Deleting proof of payment image (rejected): $filePath',
            );
            await SupabaseService.adminClient.storage
                .from('Proof Payment')
                .remove([filePath]);
            print('DEBUG: Successfully deleted proof of payment image');
          } else {
            print(
              'WARNING: Could not extract file path from screenshot_url: $screenshotUrl',
            );
          }
        } else {
          print('WARNING: screenshot_url is empty, skipping image deletion');
        }
      } catch (storageError) {
        // Log error but don't fail the rejection process
        print(
          'WARNING: Failed to delete proof of payment image: $storageError',
        );
        print(
          'DEBUG: Continuing with rejection despite storage deletion failure',
        );
      }

      // Delete the request from top_up_requests table
      await SupabaseService.adminClient
          .from('top_up_requests')
          .delete()
          .eq('id', request['id']);

      // Close loading dialog
      Navigator.pop(context);

      // Refresh pending requests
      _loadPendingRequests();

      // Show success dialog
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.orange, size: 28),
                  SizedBox(width: 8),
                  Text('Request Rejected'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Student: ${request['student_name']}'),
                  Text('Amount: ₱${request['amount']}'),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Reason: $reason'),
                  ],
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.pop(context);

      // Show error dialog
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red, size: 28),
                  SizedBox(width: 8),
                  Text('Rejection Failed'),
                ],
              ),
              content: Text('Failed to reject request: ${e.toString()}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }
}
