import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class VendorsTab extends StatefulWidget {
  final bool? navigateToServiceRegistration;

  const VendorsTab({super.key, this.navigateToServiceRegistration});

  @override
  State<VendorsTab> createState() => _VendorsTabState();
}

class _VendorsTabState extends State<VendorsTab> {
  static const Color evsuRed = Color(0xFFB91C1C);
  int _selectedFunction = -1;

  // Form state variables
  String? _selectedServiceCategory;
  String? _selectedOperationalType;
  int? _selectedMainServiceId;

  // Form controllers
  final TextEditingController _serviceNameController = TextEditingController();
  final TextEditingController _contactPersonController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _scannerIdController = TextEditingController();
  final TextEditingController _commissionRateController =
      TextEditingController();

  // Loading states
  bool _isCreatingAccount = false;
  bool _isLoadingMainServices = false;

  // Password visibility state
  bool _isPasswordVisible = false;

  // Main services list
  List<Map<String, dynamic>> _mainServices = [];

  // Scanner assignment state variables
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _adminAccounts = [];
  bool _isLoadingScanners = false;
  String? _selectedServiceId;
  String? _selectedScannerId;

  // Analytics state variables
  Map<String, dynamic>? _analyticsData;
  bool _isLoadingAnalytics = false;
  String _selectedDateFilter = 'month';
  String _selectedCategoryFilter = 'all';

  // Service categories
  final List<String> _serviceCategories = [
    'School Org',
    'Vendor',
    'Campus Service Units',
  ];

  // Operational types for Campus Service Units
  final List<String> _operationalTypes = ['Main', 'Sub'];

  @override
  void dispose() {
    _serviceNameController.dispose();
    _contactPersonController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _scannerIdController.dispose();
    _commissionRateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // If navigateToServiceRegistration is true, automatically navigate to Service Registration
    if (widget.navigateToServiceRegistration == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedFunction = 0; // Service Registration is index 0
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _selectedFunction != -1
        ? _buildFunctionDetail(_selectedFunction)
        : SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Service Management',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage services and service points',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 30),

                // Function Cards
                LayoutBuilder(
                  builder: (context, constraints) {
                    int crossAxisCount = 1;
                    if (constraints.maxWidth > 1200) {
                      crossAxisCount = 3;
                    } else if (constraints.maxWidth > 800) {
                      crossAxisCount = 2;
                    }

                    return GridView.count(
                      crossAxisCount: crossAxisCount,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 1.5,
                      children: [
                        _buildFunctionCard(
                          index: 0,
                          icon: Icons.add_business,
                          title: 'Service Registration',
                          description: 'Create new service accounts',
                          color: evsuRed,
                          onTap: () => setState(() => _selectedFunction = 0),
                        ),
                        _buildFunctionCard(
                          index: 1,
                          icon: Icons.bluetooth,
                          title: 'RFID Scanner Assignment',
                          description:
                              'Assign RFID Bluetooth scanners to vendors',
                          color: Colors.blue,
                          onTap: () => setState(() => _selectedFunction = 1),
                        ),
                        _buildFunctionCard(
                          index: 2,
                          icon: Icons.business_center,
                          title: 'Service Account Management',
                          description: 'Manage existing service accounts',
                          color: Colors.green,
                          onTap: () => setState(() => _selectedFunction = 2),
                        ),
                        _buildFunctionCard(
                          index: 3,
                          icon: Icons.analytics,
                          title: 'Performance Analytics',
                          description:
                              'View comprehensive performance metrics and analytics',
                          color: Colors.purple,
                          onTap: () => setState(() => _selectedFunction = 3),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
  }

  Widget _buildFunctionDetail(int functionIndex) {
    switch (functionIndex) {
      case 0:
        return _buildServiceRegistration();
      case 1:
        return _buildScannerAssignment();
      case 2:
        return _buildServiceAccountManagement();
      case 3:
        return _buildPerformanceAnalytics();
      default:
        return Container();
    }
  }

  Widget _buildServiceRegistration() {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 600 ? 24.0 : 16.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedFunction = -1),
                  icon: const Icon(Icons.arrow_back, color: evsuRed),
                ),
                Expanded(
                  child: Text(
                    'Service Registration',
                    style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width > 600 ? 28 : 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Responsive layout with MediaQuery
            LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = MediaQuery.of(context).size.width;
                bool isWideScreen = screenWidth > 800;

                return isWideScreen
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildServiceForm()),
                        const SizedBox(width: 20),
                        Expanded(flex: 1, child: _buildServiceList()),
                      ],
                    )
                    : Column(
                      children: [
                        _buildServiceForm(),
                        const SizedBox(height: 20),
                        _buildServiceList(),
                      ],
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Create Service Account',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),

          // Form fields with flexible spacing
          _buildFormField(
            'Service Name',
            Icons.business,
            _serviceNameController,
          ),
          SizedBox(height: isMobile ? 12 : 16),

          // Service Category Dropdown
          _buildServiceCategoryDropdown(),
          SizedBox(height: isMobile ? 12 : 16),

          // Conditional Operational Type Dropdown (only for Campus Service Units)
          if (_selectedServiceCategory == 'Campus Service Units') ...[
            _buildOperationalTypeDropdown(),
            SizedBox(height: isMobile ? 12 : 16),
          ],

          // Conditional Main Service Selection (only if Sub is selected)
          if (_selectedServiceCategory == 'Campus Service Units' &&
              _selectedOperationalType == 'Sub') ...[
            _buildMainServiceDropdown(),
            SizedBox(height: isMobile ? 12 : 16),
          ],

          _buildFormField(
            'Contact Person',
            Icons.person,
            _contactPersonController,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          _buildFormField('Email Address', Icons.email, _emailController),
          SizedBox(height: isMobile ? 12 : 16),
          _buildFormField('Phone Number', Icons.phone, _phoneController),
          SizedBox(height: isMobile ? 12 : 16),
          _buildFormField(
            'Username',
            Icons.account_circle,
            _usernameController,
          ),
          SizedBox(height: isMobile ? 12 : 16),
          _buildPasswordField(),
          SizedBox(height: isMobile ? 16 : 24),

          // Action buttons - responsive layout
          isMobile
              ? Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _isCreatingAccount ? null : _createServiceAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: evsuRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          _isCreatingAccount
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                'Create Service Account',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isCreatingAccount ? null : _clearForm,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: evsuRed),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          color: evsuRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              )
              : Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _isCreatingAccount ? null : _createServiceAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: evsuRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          _isCreatingAccount
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                'Create Service Account',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: OutlinedButton(
                      onPressed: _isCreatingAccount ? null : _clearForm,
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
                        style: TextStyle(
                          color: evsuRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildServiceAccountManagement() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header with back button
          Container(
            color: evsuRed,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedFunction = -1),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                Expanded(
                  child: Text(
                    'Service Account Management',
                    style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width > 600 ? 28 : 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Statistics Header
          Container(
            color: evsuRed,
            padding: EdgeInsets.fromLTRB(
              MediaQuery.of(context).size.width < 400 ? 12 : 16,
              0,
              MediaQuery.of(context).size.width < 400 ? 12 : 16,
              MediaQuery.of(context).size.width < 400 ? 12 : 16,
            ),
            child: FutureBuilder<Map<String, dynamic>>(
              future: SupabaseService.getAllServiceAccountsForManagement(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    !snapshot.data!['success']) {
                  return const Center(
                    child: Text(
                      'Error loading statistics',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                }

                final serviceAccounts = List<Map<String, dynamic>>.from(
                  snapshot.data!['data'],
                );

                final screenWidth = MediaQuery.of(context).size.width;
                final isMobile = screenWidth < 600;
                final isSmallPhone = screenWidth < 400;

                // Responsive grid layout
                if (isMobile) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Total Services',
                              value: serviceAccounts.length.toString(),
                              icon: Icons.business_center,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: isSmallPhone ? 6 : 8),
                          Expanded(
                            child: _StatCard(
                              title: 'Active',
                              value:
                                  serviceAccounts
                                      .where((s) => s['is_active'] == true)
                                      .length
                                      .toString(),
                              icon: Icons.check_circle,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallPhone ? 6 : 8),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Main',
                              value:
                                  serviceAccounts
                                      .where(
                                        (s) => s['operational_type'] == 'Main',
                                      )
                                      .length
                                      .toString(),
                              icon: Icons.account_balance,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: isSmallPhone ? 6 : 8),
                          Expanded(
                            child: _StatCard(
                              title: 'Sub',
                              value:
                                  serviceAccounts
                                      .where(
                                        (s) => s['operational_type'] == 'Sub',
                                      )
                                      .length
                                      .toString(),
                              icon: Icons.subdirectory_arrow_right,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                // Tablet and desktop layout
                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        title: 'Total Services',
                        value: serviceAccounts.length.toString(),
                        icon: Icons.business_center,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        title: 'Active',
                        value:
                            serviceAccounts
                                .where((s) => s['is_active'] == true)
                                .length
                                .toString(),
                        icon: Icons.check_circle,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        title: 'Main Accounts',
                        value:
                            serviceAccounts
                                .where((s) => s['operational_type'] == 'Main')
                                .length
                                .toString(),
                        icon: Icons.account_balance,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        title: 'Sub Accounts',
                        value:
                            serviceAccounts
                                .where((s) => s['operational_type'] == 'Sub')
                                .length
                                .toString(),
                        icon: Icons.subdirectory_arrow_right,
                        color: Colors.white,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Service List
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal:
                  MediaQuery.of(context).size.width < 400
                      ? 12.0
                      : (MediaQuery.of(context).size.width > 600 ? 24.0 : 16.0),
            ),
            child: _buildServiceManagementList(),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceManagementList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallPhone = screenWidth < 400;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallPhone ? 12.0 : (isMobile ? 14.0 : 24.0)),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Manage Service Accounts',
                  style: TextStyle(
                    fontSize: isSmallPhone ? 16 : (isMobile ? 18 : 20),
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh, size: isSmallPhone ? 20 : 24),
                onPressed: () {
                  setState(() {}); // Refresh the list
                },
                tooltip: 'Refresh',
                color: evsuRed,
                padding: EdgeInsets.all(isSmallPhone ? 8 : 12),
                constraints: BoxConstraints(
                  minWidth: isSmallPhone ? 36 : 48,
                  minHeight: isSmallPhone ? 36 : 48,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallPhone ? 16 : 20),

          // Service accounts list
          FutureBuilder<Map<String, dynamic>>(
            future: SupabaseService.getAllServiceAccountsForManagement(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: CircularProgressIndicator(color: evsuRed),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading service accounts',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: isMobile ? 12 : 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {}); // Retry
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: evsuRed,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || !snapshot.data!['success']) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.business_center_outlined,
                          color: Colors.grey.shade400,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No service accounts found',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.data?['message'] ??
                              'No service accounts have been registered yet',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: isMobile ? 12 : 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final services = List<Map<String, dynamic>>.from(
                snapshot.data!['data'],
              );

              if (services.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.business_center_outlined,
                          color: Colors.grey.shade400,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No services available',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first service account to get started',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: isMobile ? 12 : 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final service = services[index];
                  return _buildServiceManagementItem(service);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceManagementItem(Map<String, dynamic> service) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallPhone = screenWidth < 400;

    // Extract service data
    final serviceName =
        service['service_name']?.toString() ?? 'Unknown Service';
    final serviceCategory =
        service['service_category']?.toString() ?? 'No Category';
    final operationalType = service['operational_type']?.toString() ?? 'Main';
    final isActive = service['is_active'] == true;
    final contactPerson = service['contact_person']?.toString() ?? 'N/A';
    final email = service['email']?.toString() ?? 'N/A';
    final phone = service['phone']?.toString() ?? 'N/A';
    final username = service['username']?.toString() ?? 'N/A';
    final scannerId = service['scanner_id']?.toString();
    final balance =
        service['balance'] != null
            ? (service['balance'] is num
                ? (service['balance'] as num).toDouble()
                : double.tryParse(service['balance'].toString()) ?? 0.0)
            : null;
    final mainServiceName = service['main_service_name']?.toString();
    final isMainAccount = operationalType == 'Main';

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? Colors.green.shade200 : Colors.grey.shade300,
          width: isActive ? 1.5 : 1,
        ),
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
          // Header Section
          Container(
            padding: EdgeInsets.all(isSmallPhone ? 12 : (isMobile ? 14 : 20)),
            decoration: BoxDecoration(
              color: isMainAccount ? Colors.blue.shade50 : Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Service Icon
                Container(
                  padding: EdgeInsets.all(isSmallPhone ? 8 : 10),
                  decoration: BoxDecoration(
                    color:
                        isMainAccount
                            ? Colors.blue.shade100
                            : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isMainAccount
                        ? Icons.account_balance
                        : Icons.subdirectory_arrow_right,
                    color:
                        isMainAccount
                            ? Colors.blue.shade700
                            : Colors.grey.shade700,
                    size: isSmallPhone ? 18 : (isMobile ? 20 : 24),
                  ),
                ),
                SizedBox(width: isSmallPhone ? 8 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              serviceName,
                              style: TextStyle(
                                fontSize:
                                    isSmallPhone ? 14 : (isMobile ? 16 : 18),
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: isSmallPhone ? 4 : 8),
                          // Status Badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallPhone ? 8 : 10,
                              vertical: isSmallPhone ? 4 : 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isActive ? Colors.green : Colors.red.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isActive ? Icons.check_circle : Icons.cancel,
                                  size: isSmallPhone ? 12 : 14,
                                  color:
                                      isActive
                                          ? Colors.white
                                          : Colors.red.shade700,
                                ),
                                SizedBox(width: isSmallPhone ? 2 : 4),
                                Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color:
                                        isActive
                                            ? Colors.white
                                            : Colors.red.shade700,
                                    fontSize: isSmallPhone ? 10 : 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: isSmallPhone ? 4 : 6),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallPhone ? 6 : 8,
                              vertical: isSmallPhone ? 3 : 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isMainAccount
                                      ? Colors.blue.shade100
                                      : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isMainAccount ? 'MAIN' : 'SUB',
                              style: TextStyle(
                                color:
                                    isMainAccount
                                        ? Colors.blue.shade700
                                        : Colors.grey.shade700,
                                fontSize: isSmallPhone ? 9 : 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(width: isSmallPhone ? 6 : 8),
                          Flexible(
                            child: Text(
                              serviceCategory,
                              style: TextStyle(
                                fontSize:
                                    isSmallPhone ? 11 : (isMobile ? 12 : 13),
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

          // Details Section
          Padding(
            padding: EdgeInsets.all(isSmallPhone ? 12 : (isMobile ? 14 : 20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Contact Information
                _buildDetailRow(
                  icon: Icons.person,
                  label: 'Contact',
                  value: contactPerson,
                  isMobile: isMobile,
                  isSmallPhone: isSmallPhone,
                ),
                SizedBox(height: isSmallPhone ? 8 : 10),
                _buildDetailRow(
                  icon: Icons.email,
                  label: 'Email',
                  value: email,
                  isMobile: isMobile,
                  isSmallPhone: isSmallPhone,
                ),
                SizedBox(height: isSmallPhone ? 8 : 10),
                _buildDetailRow(
                  icon: Icons.phone,
                  label: 'Phone',
                  value: phone,
                  isMobile: isMobile,
                  isSmallPhone: isSmallPhone,
                ),
                SizedBox(height: isSmallPhone ? 8 : 10),
                _buildDetailRow(
                  icon: Icons.account_circle,
                  label: 'Username',
                  value: username,
                  isMobile: isMobile,
                  isSmallPhone: isSmallPhone,
                ),

                // Additional Information
                if (isMainAccount && balance != null) ...[
                  SizedBox(height: isSmallPhone ? 8 : 10),
                  Container(
                    padding: EdgeInsets.all(isSmallPhone ? 10 : 12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: Colors.green.shade700,
                          size: isSmallPhone ? 18 : 20,
                        ),
                        SizedBox(width: isSmallPhone ? 6 : 8),
                        Flexible(
                          child: Text(
                            'Balance: ',
                            style: TextStyle(
                              fontSize:
                                  isSmallPhone ? 11 : (isMobile ? 12 : 13),
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            '₱${balance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize:
                                  isSmallPhone ? 13 : (isMobile ? 14 : 16),
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (!isMainAccount && mainServiceName != null) ...[
                  SizedBox(height: isSmallPhone ? 8 : 10),
                  _buildDetailRow(
                    icon: Icons.link,
                    label: 'Connected to',
                    value: mainServiceName,
                    isMobile: isMobile,
                    isSmallPhone: isSmallPhone,
                  ),
                ],

                // Always show scanner assignment
                SizedBox(height: isSmallPhone ? 8 : 10),
                Container(
                  padding: EdgeInsets.all(isSmallPhone ? 10 : 12),
                  decoration: BoxDecoration(
                    color:
                        (scannerId != null && scannerId.isNotEmpty)
                            ? Colors.blue.shade50
                            : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          (scannerId != null && scannerId.isNotEmpty)
                              ? Colors.blue.shade200
                              : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bluetooth,
                        color:
                            (scannerId != null && scannerId.isNotEmpty)
                                ? Colors.blue.shade700
                                : Colors.grey.shade600,
                        size: isSmallPhone ? 16 : (isMobile ? 18 : 20),
                      ),
                      SizedBox(width: isSmallPhone ? 6 : 8),
                      Flexible(
                        child: Text(
                          'Scanner: ',
                          style: TextStyle(
                            fontSize: isSmallPhone ? 11 : (isMobile ? 12 : 13),
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          (scannerId != null && scannerId.isNotEmpty)
                              ? scannerId
                              : 'Not assigned',
                          style: TextStyle(
                            fontSize: isSmallPhone ? 11 : (isMobile ? 12 : 13),
                            color:
                                (scannerId != null && scannerId.isNotEmpty)
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade600,
                            fontWeight: FontWeight.w600,
                            fontFamily:
                                (scannerId != null && scannerId.isNotEmpty)
                                    ? 'monospace'
                                    : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons Section
          Container(
            padding: EdgeInsets.all(isSmallPhone ? 10 : (isMobile ? 12 : 16)),
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
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _editServiceAccount(service),
                            icon: Icon(
                              Icons.edit,
                              size: isSmallPhone ? 16 : 18,
                            ),
                            label: Text(
                              isSmallPhone ? 'Edit' : 'Edit Service',
                              style: TextStyle(
                                fontSize: isSmallPhone ? 13 : 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: evsuRed,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                vertical: isSmallPhone ? 12 : 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallPhone ? 6 : 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _toggleServiceStatus(service),
                                icon: Icon(
                                  isActive
                                      ? Icons.pause_circle_outline
                                      : Icons.play_circle_outline,
                                  size: isSmallPhone ? 16 : 18,
                                ),
                                label: Text(
                                  isActive ? 'Deactivate' : 'Activate',
                                  style: TextStyle(
                                    fontSize: isSmallPhone ? 12 : 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor:
                                      isActive
                                          ? Colors.orange.shade700
                                          : Colors.green.shade700,
                                  side: BorderSide(
                                    color:
                                        isActive
                                            ? Colors.orange.shade700
                                            : Colors.green.shade700,
                                    width: 1.5,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: isSmallPhone ? 10 : 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: isSmallPhone ? 6 : 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _deleteServiceAccount(service),
                                icon: Icon(
                                  Icons.delete,
                                  size: isSmallPhone ? 16 : 18,
                                ),
                                label: Text(
                                  'Delete',
                                  style: TextStyle(
                                    fontSize: isSmallPhone ? 12 : 13,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(
                                    color: Colors.red,
                                    width: 1.5,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: isSmallPhone ? 10 : 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                    : Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _editServiceAccount(service),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: evsuRed,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _toggleServiceStatus(service),
                            icon: Icon(
                              isActive
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline,
                              size: 18,
                            ),
                            label: Text(
                              isActive ? 'Deactivate' : 'Activate',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  isActive
                                      ? Colors.orange.shade700
                                      : Colors.green.shade700,
                              side: BorderSide(
                                color:
                                    isActive
                                        ? Colors.orange.shade700
                                        : Colors.green.shade700,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _deleteServiceAccount(service),
                            icon: const Icon(Icons.delete, size: 18),
                            label: const Text('Delete'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(
                                color: Colors.red,
                                width: 1.5,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  // Helper widget for detail rows
  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isMobile,
    bool isSmallPhone = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: isSmallPhone ? 16 : (isMobile ? 17 : 18),
          color: Colors.grey.shade600,
        ),
        SizedBox(width: isSmallPhone ? 6 : 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallPhone ? 10 : (isMobile ? 11 : 12),
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isSmallPhone ? 1 : 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: isSmallPhone ? 12 : (isMobile ? 13 : 14),
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _editServiceAccount(Map<String, dynamic> service) async {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    final nameCtrl = TextEditingController(text: service['service_name'] ?? '');
    final contactCtrl = TextEditingController(
      text: service['contact_person'] ?? '',
    );
    final emailCtrl = TextEditingController(text: service['email'] ?? '');
    final phoneCtrl = TextEditingController(text: service['phone'] ?? '');
    final usernameCtrl = TextEditingController(text: service['username'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.edit, color: evsuRed, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit Service Account',
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: isMobile ? double.infinity : 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Service Name
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Service Name',
                          prefixIcon: const Icon(
                            Icons.business,
                            color: evsuRed,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: evsuRed,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Contact Person
                      TextField(
                        controller: contactCtrl,
                        decoration: InputDecoration(
                          labelText: 'Contact Person',
                          prefixIcon: const Icon(Icons.person, color: evsuRed),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: evsuRed,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Email
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          prefixIcon: const Icon(Icons.email, color: evsuRed),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: evsuRed,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Phone
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: const Icon(Icons.phone, color: evsuRed),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: evsuRed,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Username
                      TextField(
                        controller: usernameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Username',
                          prefixIcon: const Icon(
                            Icons.account_circle,
                            color: evsuRed,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: evsuRed,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed:
                      saving
                          ? null
                          : () async {
                            setStateDialog(() => saving = true);
                            final result =
                                await SupabaseService.updateServiceAccount(
                                  accountId: service['id'],
                                  serviceName: nameCtrl.text.trim(),
                                  contactPerson: contactCtrl.text.trim(),
                                  email: emailCtrl.text.trim(),
                                  phone: phoneCtrl.text.trim(),
                                  commissionRate: null,
                                );
                            setStateDialog(() => saving = false);
                            if (result['success'] == true) {
                              if (mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Service updated successfully',
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                                setState(() {}); // refresh list
                              }
                            } else {
                              if (mounted) {
                                // Improve error handling for duplicate email
                                final errorMessage =
                                    result['message'] ?? result['error'] ?? '';
                                final errorLower = errorMessage.toLowerCase();

                                String errorText =
                                    'Update failed: $errorMessage';
                                if (errorLower.contains('duplicate') ||
                                    errorLower.contains('unique constraint') ||
                                    errorLower.contains('already exists')) {
                                  if (errorLower.contains('email')) {
                                    errorText =
                                        'Email already exists: ${emailCtrl.text.trim()}\n\nThis email is already registered. Please use a different email address.';
                                  } else if (errorLower.contains('username')) {
                                    errorText =
                                        'Username already exists: ${usernameCtrl.text.trim()}\n\nThis username is already taken. Please choose a different username.';
                                  }
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(errorText),
                                    backgroundColor: Colors.red,
                                    duration: const Duration(seconds: 5),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: evsuRed,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  icon:
                      saving
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.save, size: 18),
                  label: Text(
                    saving ? 'Saving...' : 'Save Changes',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _toggleServiceStatus(Map<String, dynamic> service) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final bool newStatus = !(service['is_active'] == true);
    final serviceName =
        service['service_name']?.toString() ?? 'Unknown Service';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  newStatus ? Icons.play_circle : Icons.pause_circle,
                  color: newStatus ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    newStatus ? 'Activate Service' : 'Deactivate Service',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to ${newStatus ? 'activate' : 'deactivate'} this service?',
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        newStatus
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color:
                          newStatus
                              ? Colors.green.shade200
                              : Colors.orange.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.business,
                        color:
                            newStatus
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          serviceName,
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w600,
                            color:
                                newStatus
                                    ? Colors.green.shade900
                                    : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  final result = await SupabaseService.updateServiceAccount(
                    accountId: service['id'],
                    isActive: newStatus,
                  );
                  if (result['success'] == true) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                newStatus
                                    ? Icons.check_circle
                                    : Icons.pause_circle,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Service ${newStatus ? 'activated' : 'deactivated'} successfully',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                      setState(() {});
                    }
                  } else {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Operation failed: ${result['message']}',
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: Icon(
                  newStatus ? Icons.play_arrow : Icons.pause,
                  size: 18,
                ),
                label: Text(newStatus ? 'Activate' : 'Deactivate'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: newStatus ? Colors.green : Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
    );
  }

  void _deleteServiceAccount(Map<String, dynamic> service) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final serviceName =
        service['service_name']?.toString() ?? 'Unknown Service';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.warning, color: Colors.red, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Delete Service Account',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete this service account?',
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.business,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          serviceName,
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action cannot be undone. All associated data will be permanently deleted.',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  // Close the delete confirmation dialog first
                  Navigator.pop(context);

                  // Show loading indicator and store its context
                  BuildContext? loadingContext;
                  if (mounted) {
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (dialogContext) {
                        loadingContext = dialogContext;
                        return const Center(child: CircularProgressIndicator());
                      },
                    );
                  }

                  try {
                    final result = await SupabaseService.deleteServiceAccount(
                      accountId: service['id'],
                    );

                    if (result['success'] == true) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Service account deleted successfully',
                                  ),
                                ),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        );
                        setState(() {});
                      }
                    } else {
                      if (mounted) {
                        // Check if deletion failed due to transactions
                        final hasTransactions =
                            result['has_transactions'] == true;
                        final transactionCount = result['transaction_count'];

                        if (hasTransactions) {
                          // Show a detailed dialog for transaction-related errors
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        color: Colors.orange.shade700,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Cannot Delete Service Account',
                                          style: TextStyle(
                                            fontSize: isMobile ? 18 : 20,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'This service account cannot be deleted because it has transaction history.',
                                        style: TextStyle(
                                          fontSize: isMobile ? 14 : 16,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.orange.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.receipt_long,
                                              color: Colors.orange.shade700,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                (transactionCount != null &&
                                                        transactionCount > 0)
                                                    ? 'This account has $transactionCount associated transaction(s).'
                                                    : 'This account has associated transactions.',
                                                style: TextStyle(
                                                  fontSize: isMobile ? 13 : 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.orange.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.blue.shade200,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.lightbulb_outline,
                                              color: Colors.blue.shade700,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'To maintain data integrity, service accounts with transaction history cannot be deleted. Instead, you can deactivate the account.',
                                                style: TextStyle(
                                                  fontSize: isMobile ? 12 : 13,
                                                  color: Colors.blue.shade900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                      ),
                                      child: Text(
                                        'I Understand',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _toggleServiceStatus(service);
                                      },
                                      icon: const Icon(
                                        Icons.pause_circle_outline,
                                        size: 18,
                                      ),
                                      label: const Text('Deactivate Instead'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        elevation: 2,
                                      ),
                                    ),
                                  ],
                                ),
                          );
                        } else {
                          // Show snackbar for other errors
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      result['message'] ?? 'Delete failed',
                                    ),
                                  ),
                                ],
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }
                      }
                    }
                  } catch (e) {
                    // Handle any unexpected errors
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Error deleting service account: ${e.toString()}',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    }
                  } finally {
                    // Always close loading indicator, even if there was an error
                    if (mounted && loadingContext != null) {
                      try {
                        Navigator.pop(loadingContext!);
                      } catch (e) {
                        // Dialog might already be closed, ignore error
                        print('Warning: Could not close loading dialog: $e');
                      }
                    }
                  }
                },
                icon: const Icon(Icons.delete, size: 18),
                label: const Text('Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildScannerAssignment() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Load data when this function is first accessed
    if (_services.isEmpty && !_isLoadingScanners) {
      _loadScannerData();
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth > 600 ? 24.0 : 16.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedFunction = -1),
                  icon: const Icon(Icons.arrow_back, color: evsuRed),
                ),
                Expanded(
                  child: Text(
                    'RFID Scanner Assignment',
                    style: TextStyle(
                      fontSize: isMobile ? 24 : 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 20 : 30),

            // Scanner assignment interface
            _isLoadingScanners
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                  builder: (context, constraints) {
                    bool isWideScreen = constraints.maxWidth > 800;

                    return isWideScreen
                        ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildScannerAssignmentForm(),
                            ),
                            const SizedBox(width: 20),
                            Expanded(flex: 1, child: _buildScannerList()),
                          ],
                        )
                        : Column(
                          children: [
                            _buildScannerAssignmentForm(),
                            SizedBox(height: isMobile ? 20 : 30),
                            _buildScannerList(),
                          ],
                        );
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerAssignmentForm() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
            'Assign RFID Scanner',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),

          // Service Selection
          Text(
            'Select Service',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedServiceId,
                hint: const Text('Choose service to assign scanner'),
                isExpanded: true,
                items:
                    _services.map((service) {
                      return DropdownMenuItem<String>(
                        value: service['id'].toString(),
                        child: Text(
                          service['service_name'] ?? 'Unknown Service',
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedServiceId = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Scanner Selection
          Text(
            'Select RFID Scanner',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedScannerId,
                hint: const Text('Choose EvsuPay1-100 scanner'),
                isExpanded: true,
                items: _buildScannerDropdownItems(),
                onChanged: (value) {
                  setState(() {
                    _selectedScannerId = value;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Assignment Summary
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Assignment Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Services with scanners: ${_services.where((s) => s['scanner_id'] != null && s['scanner_id'].toString().isNotEmpty).length}',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
                Text(
                  'Services without scanners: ${_services.where((s) => s['scanner_id'] == null || s['scanner_id'].toString().isEmpty).length}',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
                Text(
                  'Admin accounts with scanners: ${_adminAccounts.where((a) => a['scanner_id'] != null && a['scanner_id'].toString().isNotEmpty).length}',
                  style: TextStyle(
                    color: Colors.blue.shade600,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Assign Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _assignScanner,
              style: ElevatedButton.styleFrom(
                backgroundColor: evsuRed,
                padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Assign Scanner',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Separate services with and without scanners
    final servicesWithScanners =
        _services
            .where(
              (service) =>
                  service['scanner_id'] != null &&
                  service['scanner_id'].toString().isNotEmpty,
            )
            .toList();
    final servicesWithoutScanners =
        _services
            .where(
              (service) =>
                  service['scanner_id'] == null ||
                  service['scanner_id'].toString().isEmpty,
            )
            .toList();

    return Container(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
            'Service Scanner Assignments',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),

          // Services with scanners
          Text(
            'Services with RFID Scanners (${servicesWithScanners.length})',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            child:
                servicesWithScanners.isEmpty
                    ? Center(
                      child: Text(
                        'No services have scanners assigned',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: servicesWithScanners.length,
                      itemBuilder: (context, index) {
                        final service = servicesWithScanners[index];
                        return _buildServiceWithScannerItem(service);
                      },
                    ),
          ),
          const SizedBox(height: 16),

          // Services without scanners
          Text(
            'Services without RFID Scanners (${servicesWithoutScanners.length})',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w500,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 200,
            child:
                servicesWithoutScanners.isEmpty
                    ? Center(
                      child: Text(
                        'All services have scanners assigned',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: servicesWithoutScanners.length,
                      itemBuilder: (context, index) {
                        final service = servicesWithoutScanners[index];
                        return _buildServiceWithoutScannerItem(service);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceWithScannerItem(Map<String, dynamic> service) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.bluetooth, color: Colors.green.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['service_name'] ?? 'Unknown Service',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  'Scanner: ${service['scanner_id']} • ${service['service_category'] ?? 'Unknown'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _unassignScanner(service['scanner_id']),
            icon: const Icon(Icons.remove_circle, color: Colors.red),
            iconSize: 20,
            tooltip: 'Unassign Scanner',
          ),
        ],
      ),
    );
  }

  Widget _buildServiceWithoutScannerItem(Map<String, dynamic> service) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.bluetooth_disabled,
            color: Colors.orange.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service['service_name'] ?? 'Unknown Service',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  '${service['service_category'] ?? 'Unknown'} • No Scanner Assigned',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Needs Scanner',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: isMobile ? 10 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Additional helper methods for service management
  Widget _buildServiceList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Registered Services',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 12 : 16),

          // Use FutureBuilder to load real data from database
          FutureBuilder<Map<String, dynamic>>(
            future: SupabaseService.getServiceAccounts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading services',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: isMobile ? 14 : 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: isMobile ? 12 : 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || !snapshot.data!['success']) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.business_center_outlined,
                          color: Colors.grey.shade400,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No services found',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: isMobile ? 14 : 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.data?['message'] ??
                              'No service accounts have been registered yet',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: isMobile ? 12 : 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              final services = List<Map<String, dynamic>>.from(
                snapshot.data!['data'],
              );

              if (services.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.business_center_outlined,
                          color: Colors.grey.shade400,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No services registered',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: isMobile ? 14 : 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first service account to get started',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: isMobile ? 12 : 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children:
                    services
                        .map((service) => _buildServiceListItem(service))
                        .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceListItem(Map<String, dynamic> service) {
    // Map database fields to display
    final serviceName =
        service['service_name']?.toString() ?? 'Unknown Service';
    final serviceCategory =
        service['service_category']?.toString() ?? 'No Category';
    final operationalType = service['operational_type']?.toString() ?? 'Main';
    final isActive = service['is_active'] == true;
    final isMainAccount = operationalType == 'Main';
    final balance =
        service['balance'] != null
            ? (service['balance'] is num
                ? (service['balance'] as num).toDouble()
                : double.tryParse(service['balance'].toString()) ?? 0.0)
            : null;
    final mainServiceName = service['main_service_name']?.toString();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      padding: EdgeInsets.all(isMobile ? 12.0 : 16.0),
      decoration: BoxDecoration(
        color: isMainAccount ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isMainAccount ? Colors.blue.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: isMobile ? 30 : 40,
            decoration: BoxDecoration(
              color:
                  isActive
                      ? (isMainAccount ? Colors.blue : Colors.green)
                      : Colors.orange,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        serviceName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 14 : 16,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if (isMainAccount) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'MAIN',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'SUB',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  serviceCategory,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isMobile ? 12 : 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (isMainAccount && balance != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Balance: ₱${balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ] else if (!isMainAccount && mainServiceName != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Connected to: $mainServiceName',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: isMobile ? 11 : 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 12,
              vertical: isMobile ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: isActive ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color:
                    isActive ? Colors.green.shade700 : Colors.orange.shade700,
                fontSize: isMobile ? 10 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceAnalytics() {
    // Load analytics data when this function is first accessed
    if (_analyticsData == null && !_isLoadingAnalytics) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadAnalyticsData();
      });
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: MediaQuery.of(context).size.width > 600 ? 24.0 : 16.0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _selectedFunction = -1),
                  icon: const Icon(Icons.arrow_back, color: evsuRed),
                ),
                Expanded(
                  child: Text(
                    'Performance Analytics',
                    style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width > 600 ? 28 : 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Analytics content
            _buildAnalyticsContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall Performance Section
        _buildOverallPerformanceSection(),
        const SizedBox(height: 24),

        // Filters Section
        _buildFiltersSection(),
        const SizedBox(height: 24),

        // Top & Lowest Performers
        _buildPerformersSection(),
        const SizedBox(height: 24),

        // Trends Section
        _buildTrendsSection(),
      ],
    );
  }

  Widget _buildOverallPerformanceSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
              Text(
                'Overall Performance',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              if (_isLoadingAnalytics)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  onPressed: _loadAnalyticsData,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh Data',
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Performance metrics grid
          _isLoadingAnalytics
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              )
              : _analyticsData == null
              ? Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.analytics_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No data available',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _loadAnalyticsData,
                      child: const Text('Load Analytics Data'),
                    ),
                  ],
                ),
              )
              : _buildResponsiveMetricsGrid(),
        ],
      ),
    );
  }

  Widget _buildFiltersSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      constraints: const BoxConstraints(
        minHeight: 120, // Ensure minimum height
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Filter Analytics',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Filter controls
          _buildResponsiveFilters(),

          // Debug: Add some spacing to ensure visibility
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildResponsiveFilters() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      return Column(
        children: [
          _buildDateFilter(),
          const SizedBox(height: 16),
          _buildCategoryFilter(),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: _buildDateFilter()),
        const SizedBox(width: 16),
        Expanded(child: _buildCategoryFilter()),
      ],
    );
  }

  Widget _buildDateFilter() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time Period',
          style: TextStyle(
            fontSize: isMobile ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: isMobile ? 48 : 56, // Fixed height for consistency
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 12,
            vertical: isMobile ? 4 : 8,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDateFilter,
              hint: Text(
                'Select period',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.grey[600],
                ),
              ),
              isExpanded: true,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: Colors.black87,
              ),
              dropdownColor: Colors.white,
              items: const [
                DropdownMenuItem(
                  value: 'day',
                  child: Text('Today', style: TextStyle(color: Colors.black87)),
                ),
                DropdownMenuItem(
                  value: 'week',
                  child: Text(
                    'This Week',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
                DropdownMenuItem(
                  value: 'month',
                  child: Text(
                    'This Month',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
                DropdownMenuItem(
                  value: 'year',
                  child: Text(
                    'This Year',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedDateFilter = value;
                  });
                  _loadAnalyticsData();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Type',
          style: TextStyle(
            fontSize: isMobile ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: isMobile ? 48 : 56, // Fixed height for consistency
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 12,
            vertical: isMobile ? 4 : 8,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategoryFilter,
              hint: Text(
                'All Categories',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.grey[600],
                ),
              ),
              isExpanded: true,
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: Colors.black87,
              ),
              dropdownColor: Colors.white,
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text(
                    'All Categories',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Vendor',
                  child: Text(
                    'Vendors',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
                DropdownMenuItem(
                  value: 'School Org',
                  child: Text(
                    'School Organizations',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
                DropdownMenuItem(
                  value: 'Campus Service Units',
                  child: Text(
                    'Campus Service Units',
                    style: TextStyle(color: Colors.black87),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategoryFilter = value;
                  });
                  _loadAnalyticsData();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPerformersSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
            'Top & Lowest Performers',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          _buildResponsivePerformersLayout(),
        ],
      ),
    );
  }

  Widget _buildResponsivePerformersLayout() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    if (isMobile) {
      return Column(
        children: [
          _buildTopPerformers(),
          const SizedBox(height: 16),
          _buildLowestPerformers(),
        ],
      );
    }

    if (isTablet) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildTopPerformers()),
              const SizedBox(width: 12),
              Expanded(child: _buildLowestPerformers()),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildTopPerformers()),
        const SizedBox(width: 16),
        Expanded(child: _buildLowestPerformers()),
      ],
    );
  }

  Widget _buildTopPerformers() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Top 5 Performers',
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 12),
        _isLoadingAnalytics
            ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            )
            : _analyticsData == null
            ? const Center(
              child: Text(
                'No data available',
                style: TextStyle(color: Colors.grey),
              ),
            )
            : _buildPerformersList(true),
      ],
    );
  }

  Widget _buildLowestPerformers() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lowest Performers',
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.w600,
            color: Colors.orange,
          ),
        ),
        const SizedBox(height: 12),
        _isLoadingAnalytics
            ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            )
            : _analyticsData == null
            ? const Center(
              child: Text(
                'No data available',
                style: TextStyle(color: Colors.grey),
              ),
            )
            : _buildPerformersList(false),
      ],
    );
  }

  Widget _buildPerformerItem({
    required String name,
    required String revenue,
    required String transactions,
    required bool isTop,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: isTop ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isTop ? Colors.green.shade200 : Colors.orange.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isTop ? Icons.trending_up : Icons.trending_down,
            color: isTop ? Colors.green : Colors.orange,
            size: isMobile ? 18 : 20,
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 12 : 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  '$revenue • $transactions transactions',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isMobile ? 10 : 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendsSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
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
            'Performance Trends',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Trends data display
          _isLoadingAnalytics
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(),
                ),
              )
              : _analyticsData == null
              ? _buildNoDataTrends()
              : _buildTrendsData(),
        ],
      ),
    );
  }

  Widget _buildNoDataTrends() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 12),
            Text(
              'No Trends Data Available',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Load analytics data to view trends',
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAnalyticsData,
              child: const Text('Load Data'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsData() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final serviceData = List<Map<String, dynamic>>.from(
      _analyticsData!['service_data'],
    );

    // Calculate trend data
    final totalRevenue = serviceData.fold<double>(
      0.0,
      (sum, data) => sum + (data['total_revenue'] as double),
    );
    final totalTransactions = serviceData.fold<int>(
      0,
      (sum, data) => sum + (data['transaction_count'] as int),
    );
    final activeServices =
        serviceData.where((data) => data['is_active'] == true).length;

    return Column(
      children: [
        // Summary cards
        _buildTrendsSummaryCards(
          totalRevenue,
          totalTransactions,
          activeServices,
          isMobile,
        ),
        const SizedBox(height: 20),

        // Simple bar chart representation
        _buildSimpleTrendsChart(serviceData, isMobile),
      ],
    );
  }

  Widget _buildTrendsSummaryCards(
    double totalRevenue,
    int totalTransactions,
    int activeServices,
    bool isMobile,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildTrendCard(
            title: 'Total Revenue',
            value: '₱${totalRevenue.toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet,
            color: Colors.green,
            isMobile: isMobile,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTrendCard(
            title: 'Transactions',
            value: totalTransactions.toString(),
            icon: Icons.receipt_long,
            color: Colors.blue,
            isMobile: isMobile,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildTrendCard(
            title: 'Active Services',
            value: activeServices.toString(),
            icon: Icons.business_center,
            color: Colors.purple,
            isMobile: isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isMobile,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: isMobile ? 20 : 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 10 : 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleTrendsChart(
    List<Map<String, dynamic>> serviceData,
    bool isMobile,
  ) {
    // Sort services by revenue for chart
    serviceData.sort(
      (a, b) => (b['total_revenue'] as double).compareTo(
        a['total_revenue'] as double,
      ),
    );

    // Take top 5 services for chart
    final topServices = serviceData.take(5).toList();

    if (topServices.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(
          child: Text(
            'No service data available for trends',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: isMobile ? 14 : 16,
            ),
          ),
        ),
      );
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top 5 Services by Revenue',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: topServices.length,
              itemBuilder: (context, index) {
                final service = topServices[index];
                final revenue = service['total_revenue'] as double;
                final maxRevenue = topServices.first['total_revenue'] as double;
                final percentage =
                    maxRevenue > 0 ? (revenue / maxRevenue) : 0.0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              service['service_name'] ?? 'Unknown Service',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '₱${revenue.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: Colors.grey.shade200,
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: percentage,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveMetricsGrid() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    final metrics = _analyticsData!['overall_metrics'];

    // For very small screens, use single column
    if (screenWidth < 400) {
      return Column(
        children: [
          _buildMetricCard(
            title: 'Total Transactions',
            value: metrics['total_transactions'].toString(),
            icon: Icons.receipt_long,
            color: Colors.blue,
            trend: '+12.5%',
            trendUp: true,
            isCompact: true,
          ),
          const SizedBox(height: 12),
          _buildMetricCard(
            title: 'Total Revenue',
            value: '₱${metrics['total_revenue'].toStringAsFixed(2)}',
            icon: Icons.account_balance_wallet,
            color: Colors.green,
            trend: '+8.3%',
            trendUp: true,
            isCompact: true,
          ),
          const SizedBox(height: 12),
          _buildMetricCard(
            title: 'Active Services',
            value: metrics['active_services'].toString(),
            icon: Icons.business_center,
            color: Colors.purple,
            trend: '+2',
            trendUp: true,
            isCompact: true,
          ),
        ],
      );
    }

    // For mobile screens, use 2 columns
    if (isMobile) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Transactions',
                  value: metrics['total_transactions'].toString(),
                  icon: Icons.receipt_long,
                  color: Colors.blue,
                  trend: '+12.5%',
                  trendUp: true,
                  isCompact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  title: 'Total Revenue',
                  value: '₱${metrics['total_revenue'].toStringAsFixed(2)}',
                  icon: Icons.attach_money,
                  color: Colors.green,
                  trend: '+8.3%',
                  trendUp: true,
                  isCompact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMetricCard(
            title: 'Active Services',
            value: metrics['active_services'].toString(),
            icon: Icons.business_center,
            color: Colors.purple,
            trend: '+2',
            trendUp: true,
            isCompact: true,
          ),
        ],
      );
    }

    // For tablet and desktop, use 3 columns
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Total Transactions',
            value: metrics['total_transactions'].toString(),
            icon: Icons.receipt_long,
            color: Colors.blue,
            trend: '+12.5%',
            trendUp: true,
            isCompact: isTablet,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: 'Total Revenue',
            value: '₱${metrics['total_revenue'].toStringAsFixed(2)}',
            icon: Icons.attach_money,
            color: Colors.green,
            trend: '+8.3%',
            trendUp: true,
            isCompact: isTablet,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: 'Active Services',
            value: metrics['active_services'].toString(),
            icon: Icons.business_center,
            color: Colors.purple,
            trend: '+2',
            trendUp: true,
            isCompact: isTablet,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required String trend,
    required bool trendUp,
    bool isCompact = false,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isVerySmall = screenWidth < 400;

    return Container(
      padding: EdgeInsets.all(isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: isCompact ? 18 : 20),
              const Spacer(),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCompact ? 4 : 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: trendUp ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    trend,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isCompact ? 9 : 10,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isCompact ? 6 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isCompact ? (isVerySmall ? 18 : 20) : 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isCompact ? 11 : 12,
              color: color.withOpacity(0.8),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  // Analytics data loading methods
  Future<void> _loadAnalyticsData() async {
    setState(() {
      _isLoadingAnalytics = true;
    });

    try {
      // Calculate date range based on selected filter
      DateTime startDate;
      DateTime endDate = DateTime.now();

      switch (_selectedDateFilter) {
        case 'day':
          startDate = DateTime.now().subtract(const Duration(days: 1));
          break;
        case 'week':
          startDate = DateTime.now().subtract(const Duration(days: 7));
          break;
        case 'month':
          startDate = DateTime.now().subtract(const Duration(days: 30));
          break;
        case 'year':
          startDate = DateTime.now().subtract(const Duration(days: 365));
          break;
        default:
          startDate = DateTime.now().subtract(const Duration(days: 30));
      }

      // Get analytics data
      final result = await SupabaseService.getAnalyticsData(
        startDate: startDate,
        endDate: endDate,
        serviceCategory:
            _selectedCategoryFilter == 'all' ? null : _selectedCategoryFilter,
      );

      if (result['success']) {
        setState(() {
          _analyticsData = result['data'];
        });
      } else {
        _showErrorDialog('Failed to load analytics data: ${result['message']}');
      }
    } catch (e) {
      _showErrorDialog('Error loading analytics data: $e');
    } finally {
      setState(() {
        _isLoadingAnalytics = false;
      });
    }
  }

  Widget _buildPerformersList(bool isTop) {
    if (_analyticsData == null) return const SizedBox.shrink();

    final serviceData = List<Map<String, dynamic>>.from(
      _analyticsData!['service_data'],
    );

    // Sort by revenue
    serviceData.sort(
      (a, b) => (b['total_revenue'] as double).compareTo(
        a['total_revenue'] as double,
      ),
    );

    // Get top or lowest performers
    final performers =
        isTop
            ? serviceData.take(5).toList()
            : serviceData.reversed.take(3).toList();

    if (performers.isEmpty) {
      return const Center(
        child: Text('No data available', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children:
          performers
              .map(
                (performer) => _buildPerformerItem(
                  name: performer['service_name'] ?? 'Unknown Service',
                  revenue:
                      '₱${(performer['total_revenue'] as double).toStringAsFixed(2)}',
                  transactions: performer['transaction_count'].toString(),
                  isTop: isTop,
                ),
              )
              .toList(),
    );
  }

  Widget _buildFormField(
    String label,
    IconData icon,
    TextEditingController controller,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: evsuRed, size: isMobile ? 20 : 24),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 10 : 12,
            ),
            isDense: isMobile,
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCategoryDropdown() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallPhone = screenWidth < 400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Service Category',
          style: TextStyle(
            fontSize: isSmallPhone ? 11 : (isMobile ? 12 : 14),
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isSmallPhone ? 6 : (isMobile ? 6 : 8)),
        Container(
          constraints: BoxConstraints(
            minHeight: isSmallPhone ? 48 : (isMobile ? 50 : 56),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedServiceCategory,
            isExpanded: true,
            hint: Text(
              'Select service category',
              style: TextStyle(
                fontSize: isSmallPhone ? 12 : (isMobile ? 13 : 14),
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            style: TextStyle(
              fontSize: isSmallPhone ? 12 : (isMobile ? 13 : 14),
              color: Colors.black87,
            ),
            icon: Icon(
              Icons.arrow_drop_down,
              color: evsuRed,
              size: isSmallPhone ? 20 : (isMobile ? 22 : 24),
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.category,
                color: evsuRed,
                size: isSmallPhone ? 18 : (isMobile ? 20 : 24),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: evsuRed, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallPhone ? 12 : (isMobile ? 14 : 16),
                vertical: isSmallPhone ? 12 : (isMobile ? 14 : 16),
              ),
              isDense: false,
            ),
            dropdownColor: Colors.white,
            menuMaxHeight: isSmallPhone ? 200 : (isMobile ? 250 : 300),
            items:
                _serviceCategories.map<DropdownMenuItem<String>>((
                  String value,
                ) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: isSmallPhone ? 12 : (isMobile ? 13 : 14),
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  );
                }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedServiceCategory = newValue;
                // Reset dependent dropdowns
                _selectedOperationalType = null;
                _selectedMainServiceId = null;
              });
            },
            validator:
                (value) =>
                    value == null ? 'Please select a service category' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildOperationalTypeDropdown() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallPhone = screenWidth < 400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operational Type',
          style: TextStyle(
            fontSize: isSmallPhone ? 11 : (isMobile ? 12 : 14),
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isSmallPhone ? 6 : (isMobile ? 6 : 8)),
        Container(
          constraints: BoxConstraints(
            minHeight: isSmallPhone ? 48 : (isMobile ? 50 : 56),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedOperationalType,
            isExpanded: true,
            hint: Text(
              'Select operational type',
              style: TextStyle(
                fontSize: isSmallPhone ? 12 : (isMobile ? 13 : 14),
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            style: TextStyle(
              fontSize: isSmallPhone ? 12 : (isMobile ? 13 : 14),
              color: Colors.black87,
            ),
            icon: Icon(
              Icons.arrow_drop_down,
              color: evsuRed,
              size: isSmallPhone ? 20 : (isMobile ? 22 : 24),
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.settings,
                color: evsuRed,
                size: isSmallPhone ? 18 : (isMobile ? 20 : 24),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: evsuRed, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallPhone ? 12 : (isMobile ? 14 : 16),
                vertical: isSmallPhone ? 12 : (isMobile ? 14 : 16),
              ),
              isDense: false,
            ),
            dropdownColor: Colors.white,
            menuMaxHeight: isSmallPhone ? 200 : (isMobile ? 250 : 300),
            items:
                _operationalTypes.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: isSmallPhone ? 12 : (isMobile ? 13 : 14),
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  );
                }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedOperationalType = newValue;
                // Reset main service selection when changing operational type
                _selectedMainServiceId = null;
              });

              // Load main services when Sub is selected
              if (newValue == 'Sub') {
                _loadMainServices();
              }
            },
            validator:
                (value) =>
                    value == null ? 'Please select an operational type' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildMainServiceDropdown() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallPhone = screenWidth < 400;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connected to Main Service',
          style: TextStyle(
            fontSize: isSmallPhone ? 11 : (isMobile ? 12 : 14),
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isSmallPhone ? 6 : (isMobile ? 6 : 8)),
        Container(
          constraints: BoxConstraints(
            minHeight: isSmallPhone ? 48 : (isMobile ? 50 : 56),
          ),
          child: DropdownButtonFormField<int>(
            value: _selectedMainServiceId,
            isExpanded: true,
            hint: Text(
              'Select main service',
              style: TextStyle(
                fontSize: isSmallPhone ? 12 : (isMobile ? 13 : 14),
                color: Colors.grey.shade600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            style: TextStyle(
              fontSize: isSmallPhone ? 12 : (isMobile ? 13 : 14),
              color: Colors.black87,
            ),
            icon: Icon(
              Icons.arrow_drop_down,
              color: evsuRed,
              size: isSmallPhone ? 20 : (isMobile ? 22 : 24),
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.link,
                color: evsuRed,
                size: isSmallPhone ? 18 : (isMobile ? 20 : 24),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: evsuRed, width: 2),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallPhone ? 12 : (isMobile ? 14 : 16),
                vertical: isSmallPhone ? 12 : (isMobile ? 14 : 16),
              ),
              isDense: false,
            ),
            dropdownColor: Colors.white,
            menuMaxHeight: isSmallPhone ? 200 : (isMobile ? 250 : 300),
            items:
                _mainServices.map<DropdownMenuItem<int>>((
                  Map<String, dynamic> service,
                ) {
                  return DropdownMenuItem<int>(
                    value: service['id'],
                    child: Text(
                      service['service_name'] ?? 'Unknown Service',
                      style: TextStyle(
                        fontSize: isSmallPhone ? 12 : (isMobile ? 13 : 14),
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  );
                }).toList(),
            onChanged: (int? newValue) {
              setState(() {
                _selectedMainServiceId = newValue;
              });
            },
            validator:
                (value) =>
                    value == null
                        ? 'Please select a main service to connect to'
                        : null,
          ),
        ),
        if (_isLoadingMainServices)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(evsuRed),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading main services...',
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPasswordField() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: TextStyle(
            fontSize: isMobile ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: isMobile ? 6 : 8),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.lock,
              color: evsuRed,
              size: isMobile ? 20 : 24,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey.shade600,
                size: isMobile ? 20 : 24,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
              tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 16,
              vertical: isMobile ? 10 : 12,
            ),
            isDense: isMobile,
          ),
        ),
        SizedBox(height: isMobile ? 4 : 6),
        Text(
          'Password must be at least 6 characters',
          style: TextStyle(
            fontSize: isMobile ? 10 : 11,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Success'),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  // Scanner dropdown items (EvsuPay1-100)
  List<DropdownMenuItem<String>> _buildScannerDropdownItems() {
    List<DropdownMenuItem<String>> items = [];

    for (int i = 1; i <= 100; i++) {
      String scannerId = 'EvsuPay$i';
      // Check if this scanner is already assigned to a service
      bool isAssignedToService = _services.any(
        (service) => service['scanner_id'] == scannerId,
      );
      // Check if this scanner is already assigned to an admin account
      bool isAssignedToAdmin = _adminAccounts.any(
        (admin) => admin['scanner_id'] == scannerId,
      );
      // Scanner is assigned if it's assigned to either a service or admin
      bool isAssigned = isAssignedToService || isAssignedToAdmin;

      // Determine assignment type for display
      String assignmentType = '';
      if (isAssignedToService && isAssignedToAdmin) {
        assignmentType = '(Service & Admin)';
      } else if (isAssignedToService) {
        assignmentType = '(Service)';
      } else if (isAssignedToAdmin) {
        assignmentType = '(Admin)';
      }

      items.add(
        DropdownMenuItem<String>(
          value: scannerId,
          enabled: !isAssigned,
          child: Row(
            children: [
              Icon(
                Icons.bluetooth,
                color: isAssigned ? Colors.grey : Colors.green[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  scannerId,
                  style: TextStyle(
                    color: isAssigned ? Colors.grey : Colors.black87,
                  ),
                ),
              ),
              if (isAssigned)
                Text(
                  assignmentType,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        ),
      );
    }

    return items;
  }

  // Load scanner data
  Future<void> _loadScannerData() async {
    setState(() {
      _isLoadingScanners = true;
    });

    try {
      // Load services
      final servicesResult = await SupabaseService.getServiceAccounts();
      if (servicesResult['success']) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(servicesResult['data']);
        });
      }

      // Load admin accounts to check scanner assignments
      try {
        final adminResponse = await SupabaseService.client
            .from('admin_accounts')
            .select('id, scanner_id')
            .order('full_name');
        setState(() {
          _adminAccounts = List<Map<String, dynamic>>.from(adminResponse);
        });
      } catch (e) {
        print('Error loading admin accounts for scanner check: $e');
        // Continue even if admin loading fails
        _adminAccounts = [];
      }

      // Load scanners from database
      await _loadScanners();
    } catch (e) {
      _showErrorDialog('Error loading data: $e');
    } finally {
      setState(() {
        _isLoadingScanners = false;
      });
    }
  }

  Future<void> _loadScanners() async {
    try {
      // Reload services to get updated scanner assignments
      final servicesResult = await SupabaseService.getServiceAccounts();
      if (servicesResult['success']) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(servicesResult['data']);
        });
      }

      // Reload admin accounts to get updated scanner assignments
      try {
        final adminResponse = await SupabaseService.client
            .from('admin_accounts')
            .select('id, scanner_id')
            .order('full_name');
        setState(() {
          _adminAccounts = List<Map<String, dynamic>>.from(adminResponse);
        });
      } catch (e) {
        print('Error reloading admin accounts: $e');
        // Continue even if admin loading fails
      }
    } catch (e) {
      _showErrorDialog('Error loading scanner data: $e');
    }
  }

  Future<void> _assignScanner() async {
    if (_selectedServiceId == null || _selectedScannerId == null) {
      _showErrorDialog('Please select both service and scanner');
      return;
    }

    // Check if scanner is already assigned to a service
    bool isAlreadyAssignedToService = _services.any(
      (service) => service['scanner_id'] == _selectedScannerId,
    );
    // Check if scanner is already assigned to an admin account
    bool isAlreadyAssignedToAdmin = _adminAccounts.any(
      (admin) => admin['scanner_id'] == _selectedScannerId,
    );
    // Scanner is assigned if it's assigned to either a service or admin
    bool isAlreadyAssigned =
        isAlreadyAssignedToService || isAlreadyAssignedToAdmin;

    if (isAlreadyAssigned) {
      String assignmentType = '';
      if (isAlreadyAssignedToService && isAlreadyAssignedToAdmin) {
        assignmentType = 'service and admin account';
      } else if (isAlreadyAssignedToService) {
        assignmentType = 'service account';
      } else if (isAlreadyAssignedToAdmin) {
        assignmentType = 'admin account';
      }
      _showErrorDialog('This scanner is already assigned to a $assignmentType');
      return;
    }

    try {
      // Insert scanner into database if not exists
      await _ensureScannerExists(_selectedScannerId!);

      // Assign scanner to service using the updated function
      final response = await SupabaseService.client.rpc(
        'assign_scanner_to_service',
        params: {
          'scanner_device_id': _selectedScannerId!,
          'service_account_id': int.parse(_selectedServiceId!),
        },
      );

      if (response == true) {
        _showSuccessDialog('Scanner assigned successfully');
        await _loadScanners();
        setState(() {
          _selectedServiceId = null;
          _selectedScannerId = null;
        });
      } else {
        _showErrorDialog('Failed to assign scanner');
      }
    } catch (e) {
      _showErrorDialog('Error assigning scanner: $e');
    }
  }

  Future<void> _ensureScannerExists(String scannerId) async {
    try {
      // Check if scanner exists in database
      final existing =
          await SupabaseService.client
              .from('scanner_devices')
              .select('id')
              .eq('scanner_id', scannerId)
              .maybeSingle();

      if (existing == null) {
        // Use a more permissive approach - try to insert with proper error handling
        try {
          await SupabaseService.client.from('scanner_devices').insert({
            'scanner_id': scannerId,
            'device_name':
                'RFID Bluetooth Scanner ${scannerId.replaceAll('EvsuPay', '')}',
            'device_type': 'RFID_Bluetooth_Scanner',
            'model': 'ESP32 RFID',
            'serial_number':
                'ESP${scannerId.replaceAll('EvsuPay', '').padLeft(3, '0')}',
            'status': 'Available',
            'notes': 'Ready for assignment',
          });
        } catch (insertError) {
          // If direct insert fails due to RLS, try using a database function
          print(
            'Direct insert failed, scanner may already exist or RLS issue: $insertError',
          );
          // The assignment function will handle scanner creation
        }
      }
    } catch (e) {
      print('Error ensuring scanner exists: $e');
      // Continue with assignment - the function will handle scanner creation
    }
  }

  Future<void> _unassignScanner(String scannerId) async {
    try {
      final response = await SupabaseService.client.rpc(
        'unassign_scanner_from_service',
        params: {'scanner_device_id': scannerId},
      );

      if (response == true) {
        _showSuccessDialog('Scanner unassigned successfully');
        await _loadScanners();
      } else {
        _showErrorDialog('Failed to unassign scanner');
      }
    } catch (e) {
      _showErrorDialog('Error unassigning scanner: $e');
    }
  }

  Widget _buildFunctionCard({
    required int index,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Service Account Management Methods

  Future<void> _loadMainServices() async {
    setState(() {
      _isLoadingMainServices = true;
    });

    try {
      final result = await SupabaseService.getMainServiceAccounts();
      if (result['success']) {
        setState(() {
          _mainServices = List<Map<String, dynamic>>.from(result['data']);
        });
      } else {
        _showErrorDialog('Failed to load main services: ${result['message']}');
      }
    } catch (e) {
      _showErrorDialog('Error loading main services: ${e.toString()}');
    } finally {
      setState(() {
        _isLoadingMainServices = false;
      });
    }
  }

  Future<void> _createServiceAccount() async {
    // Validate form
    if (!_validateForm()) return;

    setState(() {
      _isCreatingAccount = true;
    });

    try {
      // Automatically set code to "EVSU-OCC" for Campus Service Units
      String? serviceCode;
      if (_selectedServiceCategory == 'Campus Service Units') {
        serviceCode = 'EVSU-OCC';
      }

      final result = await SupabaseService.createServiceAccount(
        serviceName: _serviceNameController.text.trim(),
        serviceCategory: _selectedServiceCategory!,
        operationalType: _selectedOperationalType ?? 'Main',
        mainServiceId:
            _selectedOperationalType == 'Sub' ? _selectedMainServiceId : null,
        contactPerson: _contactPersonController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text.trim(),
        scannerId: null, // Scanner ID removed from form
        commissionRate: 0.0, // Commission rate removed from form
        code: serviceCode, // Auto-set code for Campus Service Units
      );

      if (result['success']) {
        _showSuccessDialog('Service account created successfully!');
        _clearForm();
        // Refresh service list after successful creation
        setState(() {});
      } else {
        // Improve error handling for duplicate email
        final errorMessage = result['message'] ?? result['error'] ?? '';
        final errorLower = errorMessage.toLowerCase();

        if (errorLower.contains('duplicate') ||
            errorLower.contains('unique constraint') ||
            errorLower.contains('already exists')) {
          if (errorLower.contains('email')) {
            _showErrorDialog(
              'Email already exists: ${_emailController.text.trim()}\n\nThis email is already registered in the database. Please use a different email address.',
            );
          } else if (errorLower.contains('username')) {
            _showErrorDialog(
              'Username already exists: ${_usernameController.text.trim()}\n\nThis username is already taken. Please choose a different username.',
            );
          } else {
            _showErrorDialog(
              'Account already exists: $errorMessage\n\nThis service account may already be registered. Please check the service list.',
            );
          }
        } else {
          _showErrorDialog('Failed to create service account: $errorMessage');
        }
      }
    } catch (e) {
      // Handle specific error types
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('duplicate') ||
          errorString.contains('unique constraint') ||
          errorString.contains('already exists')) {
        if (errorString.contains('email')) {
          _showErrorDialog(
            'Email already exists: ${_emailController.text.trim()}\n\nThis email is already registered in the database. Please use a different email address.',
          );
        } else {
          _showErrorDialog(
            'Error creating service account: $e\n\nThe account may already exist in the database.',
          );
        }
      } else {
        _showErrorDialog('Error creating service account: ${e.toString()}');
      }
    } finally {
      setState(() {
        _isCreatingAccount = false;
      });
    }
  }

  bool _validateForm() {
    // Validate service name
    if (_serviceNameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter service name');
      return false;
    }

    // Validate service category
    if (_selectedServiceCategory == null) {
      _showErrorDialog('Please select service category');
      return false;
    }

    // Validate operational type for Campus Service Units
    if (_selectedServiceCategory == 'Campus Service Units' &&
        _selectedOperationalType == null) {
      _showErrorDialog('Please select operational type');
      return false;
    }

    // Validate main service selection for sub accounts
    if (_selectedOperationalType == 'Sub' && _selectedMainServiceId == null) {
      _showErrorDialog('Please select a main service to connect to');
      return false;
    }

    // Validate contact person
    if (_contactPersonController.text.trim().isEmpty) {
      _showErrorDialog('Please enter contact person');
      return false;
    }

    // Validate email (more flexible)
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showErrorDialog('Please enter email address');
      return false;
    }

    // Basic email validation (not strict EVSU requirement)
    if (!_isValidEmail(email)) {
      _showErrorDialog('Please enter a valid email address');
      return false;
    }

    // Validate phone
    if (_phoneController.text.trim().isEmpty) {
      _showErrorDialog('Please enter phone number');
      return false;
    }

    // Validate username
    if (_usernameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter username');
      return false;
    }

    // Validate password
    final password = _passwordController.text.trim();
    if (password.isEmpty) {
      _showErrorDialog('Please enter password');
      return false;
    }
    if (password.length < 6) {
      _showErrorDialog('Password must be at least 6 characters long');
      return false;
    }

    return true;
  }

  // Helper function for basic email validation
  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  void _clearForm() {
    _serviceNameController.clear();
    _contactPersonController.clear();
    _emailController.clear();
    _phoneController.clear();
    _usernameController.clear();
    _passwordController.clear();
    // Scanner ID and Commission Rate controllers removed from form
    _scannerIdController.clear();
    _commissionRateController.clear();

    setState(() {
      _selectedServiceCategory = null;
      _selectedOperationalType = null;
      _selectedMainServiceId = null;
      _mainServices.clear();
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Error'),
            content: Text(message),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallPhone = screenWidth < 400;

    return Container(
      padding: EdgeInsets.all(isSmallPhone ? 8 : (isMobile ? 10 : 12)),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: isSmallPhone ? 16 : (isMobile ? 18 : 20),
          ),
          SizedBox(height: isSmallPhone ? 4 : (isMobile ? 5 : 6)),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallPhone ? 16 : (isMobile ? 18 : 20),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isSmallPhone ? 8 : (isMobile ? 9 : 10),
                color: color.withOpacity(0.9),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
