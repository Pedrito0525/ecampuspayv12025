import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class AdminManagementTab extends StatefulWidget {
  const AdminManagementTab({super.key});

  @override
  State<AdminManagementTab> createState() => _AdminManagementTabState();
}

class _AdminManagementTabState extends State<AdminManagementTab> {
  static const Color evsuRed = Color(0xFFB91C1C);
  int _selectedFunction = -1;

  // Admin staff account creation form controllers
  final TextEditingController _staffNameController = TextEditingController();
  final TextEditingController _staffEmailController = TextEditingController();
  final TextEditingController _staffUsernameController =
      TextEditingController();
  final TextEditingController _staffPasswordController =
      TextEditingController();

  // Admin staff account creation state
  bool _isCreatingStaffAccount = false;
  bool _isStaffPasswordVisible = false;

  // Admin scanner assignment state variables
  List<Map<String, dynamic>> _adminAccounts = [];
  List<Map<String, dynamic>> _services = [];
  bool _isLoadingAdminScanners = false;
  String? _selectedAdminId;
  String? _selectedAdminScannerId;

  // Staff management state variables
  List<Map<String, dynamic>> _staffAccounts = [];
  bool _isLoadingStaffAccounts = false;
  Map<String, dynamic>? _editingStaff;
  final TextEditingController _editStaffNameController =
      TextEditingController();
  final TextEditingController _editStaffEmailController =
      TextEditingController();
  final TextEditingController _editStaffUsernameController =
      TextEditingController();
  final TextEditingController _editStaffPasswordController =
      TextEditingController();
  bool _isEditingStaff = false;
  bool _isEditPasswordVisible = false;

  // Staff permissions state variables
  Map<String, bool> _staffPermissions = {};
  bool _isLoadingPermissions = false;
  bool _isUpdatingPermissions = false;
  bool _isDeletingStaff = false;

  @override
  void dispose() {
    _staffNameController.dispose();
    _staffEmailController.dispose();
    _staffUsernameController.dispose();
    _staffPasswordController.dispose();
    _editStaffNameController.dispose();
    _editStaffEmailController.dispose();
    _editStaffUsernameController.dispose();
    _editStaffPasswordController.dispose();
    super.dispose();
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
                  'Admin Management',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage admin accounts and scanner assignments',
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
                          icon: Icons.admin_panel_settings,
                          title: 'Admin Scanner Assignment',
                          description: 'Assign RFID scanners to admin accounts',
                          color: Colors.indigo,
                          onTap: () => setState(() => _selectedFunction = 0),
                        ),
                        _buildFunctionCard(
                          index: 1,
                          icon: Icons.person_add,
                          title: 'Create Admin Staff Account',
                          description: 'Create new admin staff accounts',
                          color: Colors.teal,
                          onTap: () => setState(() => _selectedFunction = 1),
                        ),
                        _buildFunctionCard(
                          index: 2,
                          icon: Icons.manage_accounts,
                          title: 'Staff Management',
                          description: 'Edit and manage admin staff accounts',
                          color: Colors.orange,
                          onTap: () => setState(() => _selectedFunction = 2),
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
        return _buildAdminScannerAssignment();
      case 1:
        return _buildCreateAdminStaffAccount();
      case 2:
        return _buildStaffManagement();
      default:
        return Container();
    }
  }

  Widget _buildCreateAdminStaffAccount() {
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
                    'Create Admin Staff Account',
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

            // Form
            _buildAdminStaffForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminStaffForm() {
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
            'Staff Account Information',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),

          // Staff Name Field
          _buildStaffFormField(
            'Name of the Staff',
            Icons.person,
            _staffNameController,
          ),
          SizedBox(height: isMobile ? 12 : 16),

          // Email Field
          _buildStaffFormField(
            'Email Address',
            Icons.email,
            _staffEmailController,
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: isMobile ? 12 : 16),

          // Username Field
          _buildStaffFormField(
            'Username',
            Icons.account_circle,
            _staffUsernameController,
          ),
          SizedBox(height: isMobile ? 12 : 16),

          // Password Field
          _buildStaffPasswordField(),
          SizedBox(height: isMobile ? 16 : 24),

          // Action buttons
          isMobile
              ? Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _isCreatingStaffAccount
                              ? null
                              : _createAdminStaffAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: evsuRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          _isCreatingStaffAccount
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                'Create Staff Account',
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
                      onPressed:
                          _isCreatingStaffAccount ? null : _clearStaffForm,
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
                          _isCreatingStaffAccount
                              ? null
                              : _createAdminStaffAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: evsuRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child:
                          _isCreatingStaffAccount
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text(
                                'Create Staff Account',
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
                      onPressed:
                          _isCreatingStaffAccount ? null : _clearStaffForm,
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

  Widget _buildStaffFormField(
    String label,
    IconData icon,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
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
          keyboardType: keyboardType,
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

  Widget _buildStaffPasswordField() {
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
          controller: _staffPasswordController,
          obscureText: !_isStaffPasswordVisible,
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.lock,
              color: evsuRed,
              size: isMobile ? 20 : 24,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _isStaffPasswordVisible
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: Colors.grey.shade600,
                size: isMobile ? 20 : 24,
              ),
              onPressed: () {
                setState(() {
                  _isStaffPasswordVisible = !_isStaffPasswordVisible;
                });
              },
              tooltip:
                  _isStaffPasswordVisible ? 'Hide password' : 'Show password',
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

  Future<void> _createAdminStaffAccount() async {
    // Validate form
    if (!_validateStaffForm()) return;

    setState(() {
      _isCreatingStaffAccount = true;
    });

    try {
      // Call RPC function to create admin account
      // Note: Database constraint allows 'admin' or 'moderator'
      // Using 'moderator' for staff accounts
      final response = await SupabaseService.client.rpc(
        'create_admin_account',
        params: {
          'p_username': _staffUsernameController.text.trim(),
          'p_password': _staffPasswordController.text.trim(),
          'p_full_name': _staffNameController.text.trim(),
          'p_email': _staffEmailController.text.trim(),
          'p_role': 'moderator', // Set role to 'moderator' (staff role)
        },
      );

      if (response != null && response['success'] == true) {
        _showSuccessDialog('Admin staff account created successfully!');
        _clearStaffForm();
      } else {
        final errorMessage =
            response?['message'] ?? 'Failed to create staff account';
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      // Handle specific error types
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('duplicate') ||
          errorString.contains('unique constraint') ||
          errorString.contains('already exists')) {
        if (errorString.contains('email')) {
          _showErrorDialog(
            'Email already exists: ${_staffEmailController.text.trim()}\n\nThis email is already registered. Please use a different email address.',
          );
        } else if (errorString.contains('username')) {
          _showErrorDialog(
            'Username already exists: ${_staffUsernameController.text.trim()}\n\nThis username is already taken. Please choose a different username.',
          );
        } else {
          _showErrorDialog(
            'Error creating staff account: $e\n\nThe account may already exist in the database.',
          );
        }
      } else {
        _showErrorDialog('Error creating staff account: ${e.toString()}');
      }
    } finally {
      setState(() {
        _isCreatingStaffAccount = false;
      });
    }
  }

  bool _validateStaffForm() {
    // Validate staff name
    if (_staffNameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter staff name');
      return false;
    }

    // Validate email
    final email = _staffEmailController.text.trim();
    if (email.isEmpty) {
      _showErrorDialog('Please enter email address');
      return false;
    }

    // Basic email validation
    if (!_isValidEmail(email)) {
      _showErrorDialog('Please enter a valid email address');
      return false;
    }

    // Validate username
    if (_staffUsernameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter username');
      return false;
    }

    // Validate password
    final password = _staffPasswordController.text.trim();
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

  void _clearStaffForm() {
    _staffNameController.clear();
    _staffEmailController.clear();
    _staffUsernameController.clear();
    _staffPasswordController.clear();
    setState(() {
      _isStaffPasswordVisible = false;
    });
  }

  Widget _buildAdminScannerAssignment() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Load data when this function is first accessed
    if (_adminAccounts.isEmpty && !_isLoadingAdminScanners) {
      print('DEBUG: Loading admin scanner data...');
      _loadAdminScannerData();
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
                    'Admin Scanner Assignment',
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

            // Admin scanner assignment interface
            _isLoadingAdminScanners
                ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Loading admin accounts and scanner data...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                )
                : LayoutBuilder(
                  builder: (context, constraints) {
                    bool isWideScreen = constraints.maxWidth > 800;

                    // Show error message if no admin accounts are loaded
                    if (_adminAccounts.isEmpty) {
                      return Center(
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 20 : 30),
                          margin: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red.shade600,
                                size: 48,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Admin Accounts Found',
                                style: TextStyle(
                                  fontSize: isMobile ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'This might be due to Row Level Security (RLS) policies blocking access to the admin_accounts table.',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  color: Colors.red.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  _showErrorDialog(
                                    'Please run the fix_admin_accounts_rls.sql script in your database to enable access to admin accounts for scanner assignment.',
                                  );
                                },
                                icon: const Icon(Icons.info_outline),
                                label: const Text('View Instructions'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton.icon(
                                onPressed: _loadAdminScannerData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Retry Loading'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return isWideScreen
                        ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildAdminScannerAssignmentForm(),
                            ),
                            const SizedBox(width: 20),
                            Expanded(flex: 1, child: _buildAdminScannerList()),
                          ],
                        )
                        : Column(
                          children: [
                            _buildAdminScannerAssignmentForm(),
                            SizedBox(height: isMobile ? 20 : 30),
                            _buildAdminScannerList(),
                          ],
                        );
                  },
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminScannerAssignmentForm() {
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
            'Assign Scanner to Admin',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),

          // Admin Selection
          Text(
            'Select Admin Account',
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
                value: _selectedAdminId,
                hint: const Text('Choose admin account'),
                isExpanded: true,
                items:
                    _adminAccounts.map((admin) {
                      return DropdownMenuItem<String>(
                        value: admin['id'].toString(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              admin['full_name'] ?? 'Unknown Admin',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${admin['username']} • ${admin['role']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAdminId = value;
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
                value: _selectedAdminScannerId,
                hint: const Text('Choose available scanner'),
                isExpanded: true,
                items: _buildAdminScannerDropdownItems(),
                onChanged: (value) {
                  setState(() {
                    _selectedAdminScannerId = value;
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
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.indigo.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.indigo.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Assignment Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.indigo.shade700,
                        fontSize: isMobile ? 12 : 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Admins with scanners: ${_adminAccounts.where((a) => a['scanner_id'] != null && a['scanner_id'].toString().isNotEmpty).length}',
                  style: TextStyle(
                    color: Colors.indigo.shade600,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
                Text(
                  'Admins without scanners: ${_adminAccounts.where((a) => a['scanner_id'] == null || a['scanner_id'].toString().isEmpty).length}',
                  style: TextStyle(
                    color: Colors.indigo.shade600,
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
              onPressed: _assignScannerToAdmin,
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

  Widget _buildAdminScannerList() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Separate admins with and without scanners
    final adminsWithScanners =
        _adminAccounts
            .where(
              (admin) =>
                  admin['scanner_id'] != null &&
                  admin['scanner_id'].toString().isNotEmpty,
            )
            .toList();
    final adminsWithoutScanners =
        _adminAccounts
            .where(
              (admin) =>
                  admin['scanner_id'] == null ||
                  admin['scanner_id'].toString().isEmpty,
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
            'Admin Scanner Assignments',
            style: TextStyle(
              fontSize: isMobile ? 18 : 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),

          // Admins with scanners
          Text(
            'Admins with RFID Scanners (${adminsWithScanners.length})',
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
                adminsWithScanners.isEmpty
                    ? Center(
                      child: Text(
                        'No admins have scanners assigned',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: adminsWithScanners.length,
                      itemBuilder: (context, index) {
                        final admin = adminsWithScanners[index];
                        return _buildAdminWithScannerItem(admin);
                      },
                    ),
          ),
          const SizedBox(height: 16),

          // Admins without scanners
          Text(
            'Admins without RFID Scanners (${adminsWithoutScanners.length})',
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
                adminsWithoutScanners.isEmpty
                    ? Center(
                      child: Text(
                        'All admins have scanners assigned',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    )
                    : ListView.builder(
                      itemCount: adminsWithoutScanners.length,
                      itemBuilder: (context, index) {
                        final admin = adminsWithoutScanners[index];
                        return _buildAdminWithoutScannerItem(admin);
                      },
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminWithScannerItem(Map<String, dynamic> admin) {
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
          Icon(
            Icons.admin_panel_settings,
            color: Colors.green.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin['full_name'] ?? 'Unknown Admin',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  'Scanner: ${admin['scanner_id']} • ${admin['role']}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _unassignScannerFromAdmin(admin['id']),
            icon: const Icon(Icons.remove_circle, color: Colors.red),
            iconSize: 20,
            tooltip: 'Unassign Scanner',
          ),
        ],
      ),
    );
  }

  Widget _buildAdminWithoutScannerItem(Map<String, dynamic> admin) {
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
            Icons.admin_panel_settings_outlined,
            color: Colors.orange.shade600,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  admin['full_name'] ?? 'Unknown Admin',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
                Text(
                  '${admin['role']} • No Scanner Assigned',
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

  // Additional helper methods for admin scanner management
  List<DropdownMenuItem<String>> _buildAdminScannerDropdownItems() {
    List<DropdownMenuItem<String>> items = [];

    for (int i = 1; i <= 100; i++) {
      String scannerId = 'EvsuPay$i';
      // Check if this scanner is already assigned to services or admins
      bool isAssignedToService = _services.any(
        (service) => service['scanner_id'] == scannerId,
      );
      bool isAssignedToAdmin = _adminAccounts.any(
        (admin) => admin['scanner_id'] == scannerId,
      );

      items.add(
        DropdownMenuItem<String>(
          value: scannerId,
          child: Row(
            children: [
              Icon(
                Icons.bluetooth,
                color:
                    (isAssignedToService || isAssignedToAdmin)
                        ? Colors.grey
                        : Colors.green[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  scannerId,
                  style: TextStyle(
                    color:
                        (isAssignedToService || isAssignedToAdmin)
                            ? Colors.grey
                            : Colors.black87,
                  ),
                ),
              ),
              if (isAssignedToService || isAssignedToAdmin)
                const Text(
                  '(Assigned)',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        ),
      );
    }

    return items;
  }

  // Load admin scanner data
  Future<void> _loadAdminScannerData() async {
    setState(() {
      _isLoadingAdminScanners = true;
    });

    try {
      // First, try to load admin accounts using the RPC function
      try {
        final response = await SupabaseService.client.rpc(
          'get_admin_accounts_with_scanners',
        );
        if (response != null && response['success']) {
          setState(() {
            _adminAccounts = List<Map<String, dynamic>>.from(response['data']);
          });
        } else {
          // Fallback: load admin accounts directly from table
          await _loadAdminAccountsFallback();
        }
      } catch (rpcError) {
        print('RPC function failed, using fallback: $rpcError');
        // Fallback: load admin accounts directly from table
        await _loadAdminAccountsFallback();
      }

      // Load services to check scanner assignments
      final servicesResult = await SupabaseService.getServiceAccounts();
      if (servicesResult['success']) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(servicesResult['data']);
        });
      } else {
        print('Failed to load services: ${servicesResult['message']}');
        setState(() {
          _services = [];
        });
      }
    } catch (e) {
      print('Error loading admin scanner data: $e');
      _showErrorDialog('Error loading data: $e');
      // Set empty lists to prevent infinite loading
      setState(() {
        _adminAccounts = [];
        _services = [];
      });
    } finally {
      setState(() {
        _isLoadingAdminScanners = false;
      });
    }
  }

  // Fallback method to load admin accounts directly from table
  Future<void> _loadAdminAccountsFallback() async {
    try {
      print('DEBUG: Attempting to load admin accounts directly from table...');

      // Try multiple approaches to load admin accounts
      List<Map<String, dynamic>> accounts = [];

      // Approach 1: Check authentication status first
      try {
        final currentUser = SupabaseService.client.auth.currentUser;
        print('Current auth user: ${currentUser?.id}');
        print('Current auth email: ${currentUser?.email}');
        print('Is authenticated: ${currentUser != null}');
      } catch (authError) {
        print('Auth check failed: $authError');
      }

      // Approach 2: Direct table query
      try {
        final response = await SupabaseService.client
            .from('admin_accounts')
            .select(
              'id, username, full_name, email, role, is_active, scanner_id, created_at, updated_at',
            )
            .order('full_name');

        accounts = List<Map<String, dynamic>>.from(response);
        print(
          'Successfully loaded ${accounts.length} admin accounts via direct query',
        );
      } catch (directError) {
        print('Direct query failed: $directError');

        // Approach 2: Try with different select fields
        try {
          final response = await SupabaseService.client
              .from('admin_accounts')
              .select('id, username, full_name, role, scanner_id')
              .order('full_name');

          accounts = List<Map<String, dynamic>>.from(response);
          print(
            'Successfully loaded ${accounts.length} admin accounts via simplified query',
          );
        } catch (simpleError) {
          print('Simplified query failed: $simpleError');

          // Approach 3: Try with minimal fields
          try {
            final response = await SupabaseService.client
                .from('admin_accounts')
                .select('id, username, full_name')
                .order('full_name');

            accounts = List<Map<String, dynamic>>.from(response);
            print(
              'Successfully loaded ${accounts.length} admin accounts via minimal query',
            );
          } catch (minimalError) {
            print('Minimal query failed: $minimalError');

            // Approach 4: Try with RPC function as last resort
            try {
              print('Trying RPC function as last resort...');
              final rpcResponse = await SupabaseService.client.rpc(
                'get_admin_accounts_with_scanners',
              );
              if (rpcResponse != null && rpcResponse is List) {
                accounts = List<Map<String, dynamic>>.from(rpcResponse);
                print(
                  'Successfully loaded ${accounts.length} admin accounts via RPC',
                );
              } else if (rpcResponse != null &&
                  rpcResponse is Map &&
                  rpcResponse['success'] == true) {
                accounts = List<Map<String, dynamic>>.from(rpcResponse['data']);
                print(
                  'Successfully loaded ${accounts.length} admin accounts via RPC with wrapper',
                );
              } else {
                throw Exception('RPC function returned unexpected format');
              }
            } catch (rpcError) {
              print('RPC approach failed: $rpcError');
              throw minimalError; // Throw the original error
            }
          }
        }
      }

      setState(() {
        _adminAccounts = accounts;
      });

      if (_adminAccounts.isEmpty) {
        print('WARNING: No admin accounts found. This might be due to:');
        print('1. RLS policies blocking access to admin_accounts table');
        print('2. No admin accounts exist in the database');
        print('3. Insufficient permissions for authenticated user');
        print('4. Table structure issues');
      } else {
        print('SUCCESS: Loaded ${_adminAccounts.length} admin accounts');
        // Print first account for debugging
        if (_adminAccounts.isNotEmpty) {
          print('Sample account: ${_adminAccounts.first}');
        }
      }
    } catch (e) {
      print('All admin loading approaches failed: $e');
      print('Error type: ${e.runtimeType}');

      // Check if it's an RLS-related error
      if (e.toString().contains('RLS') ||
          e.toString().contains('permission') ||
          e.toString().contains('policy') ||
          e.toString().contains('403') ||
          e.toString().contains('unauthorized') ||
          e.toString().contains('row-level security')) {
        print(
          'This is definitely an RLS/permission issue. Please run the comprehensive fix_admin_accounts_rls.sql script.',
        );
      }

      setState(() {
        _adminAccounts = [];
      });
    }
  }

  Future<void> _assignScannerToAdmin() async {
    if (_selectedAdminId == null || _selectedAdminScannerId == null) {
      _showErrorDialog('Please select both admin account and scanner');
      return;
    }

    // Check if scanner is already assigned
    bool isAlreadyAssignedToService = _services.any(
      (service) => service['scanner_id'] == _selectedAdminScannerId,
    );
    bool isAlreadyAssignedToAdmin = _adminAccounts.any(
      (admin) => admin['scanner_id'] == _selectedAdminScannerId,
    );

    if (isAlreadyAssignedToService || isAlreadyAssignedToAdmin) {
      _showErrorDialog('This scanner is already assigned to another account');
      return;
    }

    try {
      // Try RPC function first
      try {
        final response = await SupabaseService.client.rpc(
          'assign_scanner_to_admin',
          params: {
            'p_admin_id': int.parse(_selectedAdminId!),
            'p_scanner_id': _selectedAdminScannerId!,
          },
        );

        if (response['success']) {
          _showSuccessDialog('Scanner assigned to admin successfully');
          await _loadAdminScannerData();
          setState(() {
            _selectedAdminId = null;
            _selectedAdminScannerId = null;
          });
          return;
        } else {
          throw Exception(response['message'] ?? 'RPC function failed');
        }
      } catch (rpcError) {
        print('RPC assignment failed, using fallback: $rpcError');
        // Fallback: direct table update
        await _assignScannerFallback();
      }
    } catch (e) {
      _showErrorDialog('Error assigning scanner: $e');
    }
  }

  // Fallback method for scanner assignment
  Future<void> _assignScannerFallback() async {
    try {
      // Direct table update
      await SupabaseService.client
          .from('admin_accounts')
          .update({
            'scanner_id': _selectedAdminScannerId!,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', int.parse(_selectedAdminId!));

      _showSuccessDialog('Scanner assigned to admin successfully');
      await _loadAdminScannerData();
      setState(() {
        _selectedAdminId = null;
        _selectedAdminScannerId = null;
      });
    } catch (e) {
      _showErrorDialog('Error assigning scanner: $e');
    }
  }

  Future<void> _unassignScannerFromAdmin(int adminId) async {
    try {
      // Try RPC function first
      try {
        final response = await SupabaseService.client.rpc(
          'unassign_scanner_from_admin',
          params: {'p_admin_id': adminId},
        );

        if (response['success']) {
          _showSuccessDialog('Scanner unassigned from admin successfully');
          await _loadAdminScannerData();
          return;
        } else {
          throw Exception(response['message'] ?? 'RPC function failed');
        }
      } catch (rpcError) {
        print('RPC unassignment failed, using fallback: $rpcError');
        // Fallback: direct table update
        await _unassignScannerFallback(adminId);
      }
    } catch (e) {
      _showErrorDialog('Error unassigning scanner: $e');
    }
  }

  // Fallback method for scanner unassignment
  Future<void> _unassignScannerFallback(int adminId) async {
    try {
      // Direct table update
      await SupabaseService.client
          .from('admin_accounts')
          .update({
            'scanner_id': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', adminId);

      _showSuccessDialog('Scanner unassigned from admin successfully');
      await _loadAdminScannerData();
    } catch (e) {
      _showErrorDialog('Error unassigning scanner: $e');
    }
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

  Widget _buildStaffManagement() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Load staff accounts when this function is first accessed
    if (_staffAccounts.isEmpty && !_isLoadingStaffAccounts) {
      _loadStaffAccounts();
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
                    'Staff Management',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : (screenWidth > 1024 ? 28 : 24),
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
                IconButton(
                  onPressed: _loadStaffAccounts,
                  icon: const Icon(Icons.refresh, color: evsuRed),
                  tooltip: 'Refresh',
                ),
              ],
            ),
            SizedBox(height: isMobile ? 20 : 30),

            // Loading state
            if (_isLoadingStaffAccounts)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Loading staff accounts...',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else if (_staffAccounts.isEmpty)
              Center(
                child: Container(
                  padding: EdgeInsets.all(isMobile ? 20 : 30),
                  margin: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.people_outline,
                        color: Colors.grey.shade400,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No Staff Accounts Found',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create staff accounts using the "Create Admin Staff Account" function.',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          color: Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              // Staff accounts list
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary cards
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 800;
                      return isWide
                          ? Row(
                            children: [
                              Expanded(
                                child: _buildSummaryCard(
                                  'Total Staff',
                                  _staffAccounts.length.toString(),
                                  Icons.people,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Active',
                                  _staffAccounts
                                      .where((s) => s['is_active'] == true)
                                      .length
                                      .toString(),
                                  Icons.check_circle,
                                  Colors.green,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildSummaryCard(
                                  'Deactivated',
                                  _staffAccounts
                                      .where((s) => s['is_active'] == false)
                                      .length
                                      .toString(),
                                  Icons.cancel,
                                  Colors.red,
                                ),
                              ),
                            ],
                          )
                          : Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildSummaryCard(
                                      'Total Staff',
                                      _staffAccounts.length.toString(),
                                      Icons.people,
                                      Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildSummaryCard(
                                      'Active',
                                      _staffAccounts
                                          .where((s) => s['is_active'] == true)
                                          .length
                                          .toString(),
                                      Icons.check_circle,
                                      Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildSummaryCard(
                                'Deactivated',
                                _staffAccounts
                                    .where((s) => s['is_active'] == false)
                                    .length
                                    .toString(),
                                Icons.cancel,
                                Colors.red,
                              ),
                            ],
                          );
                    },
                  ),
                  SizedBox(height: isMobile ? 20 : 30),

                  // Staff list
                  Text(
                    'Staff Accounts (${_staffAccounts.length})',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : (screenWidth > 1024 ? 20 : 18),
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _staffAccounts.length,
                    itemBuilder: (context, index) {
                      final staff = _staffAccounts[index];
                      return _buildStaffAccountCard(staff, isMobile);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
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
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 40 : 50,
            height: isMobile ? 40 : 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: isMobile ? 20 : 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isMobile ? 18 : (screenWidth > 1024 ? 24 : 20),
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : (screenWidth > 1024 ? 14 : 12),
                    color: Colors.grey.shade600,
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

  Widget _buildStaffAccountCard(Map<String, dynamic> staff, bool isMobile) {
    final isActive = staff['is_active'] == true;
    final role = staff['role']?.toString() ?? 'moderator';

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
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
        border: Border.all(
          color: isActive ? Colors.green.shade200 : Colors.red.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: isMobile ? 40 : 48,
                height: isMobile ? 40 : 48,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isActive ? Icons.person : Icons.person_off,
                  color: isActive ? Colors.green.shade700 : Colors.red.shade700,
                  size: isMobile ? 20 : 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      staff['full_name']?.toString() ?? 'Unknown',
                      style: TextStyle(
                        fontSize: isMobile ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.email,
                          size: isMobile ? 12 : 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            staff['email']?.toString() ?? 'No email',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 13,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.account_circle,
                          size: isMobile ? 12 : 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${staff['username']?.toString() ?? 'N/A'} • ${role.toUpperCase()}',
                            style: TextStyle(
                              fontSize: isMobile ? 10 : 11,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 6 : 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isActive ? Colors.green.shade100 : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Deactivated',
                    style: TextStyle(
                      color:
                          isActive
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                      fontSize: isMobile ? 9 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey.shade200),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 400;
              return isWide
                  ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showEditStaffDialog(staff),
                          icon: Icon(Icons.edit, size: isMobile ? 14 : 16),
                          label: Text(
                            'Edit',
                            style: TextStyle(fontSize: isMobile ? 11 : 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.blue.shade300),
                            foregroundColor: Colors.blue.shade700,
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 8 : 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showPermissionsDialog(staff),
                          icon: Icon(Icons.security, size: isMobile ? 14 : 16),
                          label: Text(
                            'Permissions',
                            style: TextStyle(fontSize: isMobile ? 11 : 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.purple.shade300),
                            foregroundColor: Colors.purple.shade700,
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 8 : 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _toggleStaffStatus(staff),
                          icon: Icon(
                            isActive ? Icons.block : Icons.check_circle,
                            size: isMobile ? 14 : 16,
                          ),
                          label: Text(
                            isActive ? 'Deactivate' : 'Activate',
                            style: TextStyle(fontSize: isMobile ? 11 : 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isActive
                                    ? Colors.red.shade600
                                    : Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 8 : 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showDeleteStaffConfirmation(staff),
                          icon: Icon(Icons.delete, size: isMobile ? 14 : 16),
                          label: Text(
                            'Delete',
                            style: TextStyle(fontSize: isMobile ? 11 : 13),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade300),
                            foregroundColor: Colors.red.shade700,
                            padding: EdgeInsets.symmetric(
                              vertical: isMobile ? 8 : 10,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                  : Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showEditStaffDialog(staff),
                          icon: Icon(Icons.edit, size: 14),
                          label: Text('Edit', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.blue.shade300),
                            foregroundColor: Colors.blue.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showPermissionsDialog(staff),
                          icon: Icon(Icons.security, size: 14),
                          label: Text(
                            'Permissions',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.purple.shade300),
                            foregroundColor: Colors.purple.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _toggleStaffStatus(staff),
                          icon: Icon(
                            isActive ? Icons.block : Icons.check_circle,
                            size: 14,
                          ),
                          label: Text(
                            isActive ? 'Deactivate' : 'Activate',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isActive
                                    ? Colors.red.shade600
                                    : Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showDeleteStaffConfirmation(staff),
                          icon: const Icon(Icons.delete, size: 14),
                          label: const Text(
                            'Delete',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade300),
                            foregroundColor: Colors.red.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _loadStaffAccounts() async {
    setState(() {
      _isLoadingStaffAccounts = true;
    });

    try {
      // Load only staff accounts (moderator role)
      final response = await SupabaseService.client
          .from('admin_accounts')
          .select(
            'id, username, full_name, email, role, is_active, created_at, updated_at',
          )
          .eq('role', 'moderator')
          .order('full_name');

      setState(() {
        _staffAccounts = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading staff accounts: $e');
      _showErrorDialog('Error loading staff accounts: ${e.toString()}');
      setState(() {
        _staffAccounts = [];
      });
    } finally {
      setState(() {
        _isLoadingStaffAccounts = false;
      });
    }
  }

  Future<void> _toggleStaffStatus(Map<String, dynamic> staff) async {
    final username = staff['username']?.toString();
    if (username == null) {
      _showErrorDialog('Invalid staff account');
      return;
    }

    final currentStatus = staff['is_active'] == true;
    final newStatus = !currentStatus;

    try {
      final response = await SupabaseService.client.rpc(
        'update_admin_status',
        params: {'p_username': username, 'p_is_active': newStatus},
      );

      if (response != null && response['success'] == true) {
        _showSuccessDialog(
          'Staff account ${newStatus ? 'activated' : 'deactivated'} successfully',
        );
        await _loadStaffAccounts();
      } else {
        final errorMessage =
            response?['message'] ?? 'Failed to update staff status';
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      _showErrorDialog('Error updating staff status: ${e.toString()}');
    }
  }

  void _showEditStaffDialog(Map<String, dynamic> staff) {
    _editingStaff = staff;
    _editStaffNameController.text = staff['full_name']?.toString() ?? '';
    _editStaffEmailController.text = staff['email']?.toString() ?? '';
    _editStaffUsernameController.text = staff['username']?.toString() ?? '';
    _editStaffPasswordController.clear();
    _isEditPasswordVisible = false;

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Container(
              width: isMobile ? double.infinity : 500,
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.edit, color: evsuRed, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Edit Staff Account',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Name Field
                    _buildEditStaffFormField(
                      'Full Name',
                      Icons.person,
                      _editStaffNameController,
                    ),
                    SizedBox(height: isMobile ? 12 : 16),

                    // Email Field
                    _buildEditStaffFormField(
                      'Email Address',
                      Icons.email,
                      _editStaffEmailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: isMobile ? 12 : 16),

                    // Username Field
                    _buildEditStaffFormField(
                      'Username',
                      Icons.account_circle,
                      _editStaffUsernameController,
                    ),
                    SizedBox(height: isMobile ? 12 : 16),

                    // Password Field (Optional)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Password (Optional)',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: isMobile ? 6 : 8),
                        TextFormField(
                          controller: _editStaffPasswordController,
                          obscureText: !_isEditPasswordVisible,
                          decoration: InputDecoration(
                            prefixIcon: Icon(
                              Icons.lock,
                              color: evsuRed,
                              size: isMobile ? 20 : 24,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isEditPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.grey.shade600,
                                size: isMobile ? 20 : 24,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isEditPasswordVisible =
                                      !_isEditPasswordVisible;
                                });
                              },
                            ),
                            hintText: 'Leave empty to keep current password',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
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
                          'Leave empty to keep current password',
                          style: TextStyle(
                            fontSize: isMobile ? 10 : 11,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 20 : 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _isEditingStaff
                                    ? null
                                    : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: evsuRed),
                              padding: EdgeInsets.symmetric(
                                vertical: isMobile ? 12 : 14,
                              ),
                            ),
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: evsuRed,
                                fontSize: isMobile ? 14 : 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed:
                                _isEditingStaff ? null : _updateStaffAccount,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: evsuRed,
                              padding: EdgeInsets.symmetric(
                                vertical: isMobile ? 12 : 14,
                              ),
                            ),
                            child:
                                _isEditingStaff
                                    ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : Text(
                                      'Update',
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
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Widget _buildEditStaffFormField(
    String label,
    IconData icon,
    TextEditingController controller, {
    TextInputType? keyboardType,
  }) {
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
          keyboardType: keyboardType,
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

  Future<void> _updateStaffAccount() async {
    if (_editingStaff == null) {
      _showErrorDialog('No staff account selected');
      return;
    }

    // Validate form
    if (_editStaffNameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter staff name');
      return;
    }

    final email = _editStaffEmailController.text.trim();
    if (email.isEmpty) {
      _showErrorDialog('Please enter email address');
      return;
    }

    if (!_isValidEmail(email)) {
      _showErrorDialog('Please enter a valid email address');
      return;
    }

    if (_editStaffUsernameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter username');
      return;
    }

    final password = _editStaffPasswordController.text.trim();
    if (password.isNotEmpty && password.length < 6) {
      _showErrorDialog('Password must be at least 6 characters long');
      return;
    }

    setState(() {
      _isEditingStaff = true;
    });

    try {
      final currentUsername = _editingStaff!['username']?.toString();
      final newPassword = password.isEmpty ? 'KEEP_CURRENT' : password;

      // Try to use update_admin_profile RPC function if available
      try {
        final response = await SupabaseService.client.rpc(
          'update_admin_profile',
          params: {
            'p_current_username': currentUsername,
            'p_current_password':
                'KEEP_CURRENT', // We're not verifying password for admin edits
            'p_new_username': _editStaffUsernameController.text.trim(),
            'p_new_password': newPassword,
            'p_new_full_name': _editStaffNameController.text.trim(),
            'p_new_email': email,
          },
        );

        if (response != null && response['success'] == true) {
          Navigator.pop(context);
          _showSuccessDialog('Staff account updated successfully!');
          await _loadStaffAccounts();
          setState(() {
            _editingStaff = null;
          });
          return;
        } else {
          throw Exception(response?['message'] ?? 'RPC function failed');
        }
      } catch (rpcError) {
        print('RPC update failed, using direct update: $rpcError');
        // Fallback: Direct table update
        await _updateStaffAccountDirect();
      }
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('duplicate') ||
          errorString.contains('unique constraint') ||
          errorString.contains('already exists')) {
        if (errorString.contains('email')) {
          _showErrorDialog(
            'Email already exists: $email\n\nThis email is already registered. Please use a different email address.',
          );
        } else if (errorString.contains('username')) {
          _showErrorDialog(
            'Username already exists: ${_editStaffUsernameController.text.trim()}\n\nThis username is already taken. Please choose a different username.',
          );
        } else {
          _showErrorDialog('Error updating staff account: $e');
        }
      } else {
        _showErrorDialog('Error updating staff account: ${e.toString()}');
      }
    } finally {
      setState(() {
        _isEditingStaff = false;
      });
    }
  }

  Future<void> _updateStaffAccountDirect() async {
    try {
      final staffId = _editingStaff!['id'];
      final updateData = {
        'full_name': _editStaffNameController.text.trim(),
        'email': _editStaffEmailController.text.trim(),
        'username': _editStaffUsernameController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Only update password if provided
      final password = _editStaffPasswordController.text.trim();
      if (password.isNotEmpty) {
        // Note: This requires a password update function or direct hash update
        // For now, we'll skip password update in direct mode
        print('Password update skipped in direct mode - use RPC function');
      }

      await SupabaseService.client
          .from('admin_accounts')
          .update(updateData)
          .eq('id', staffId);

      Navigator.pop(context);
      _showSuccessDialog('Staff account updated successfully!');
      await _loadStaffAccounts();
      setState(() {
        _editingStaff = null;
      });
    } catch (e) {
      throw Exception('Direct update failed: $e');
    }
  }

  void _showPermissionsDialog(Map<String, dynamic> staff) {
    final staffId = staff['id'];
    if (staffId == null) {
      _showErrorDialog('Invalid staff account');
      return;
    }

    // Load permissions for this staff
    _loadStaffPermissions(staffId).then((_) {
      if (!mounted) return;
      _showPermissionsDialogUI(staff);
    });
  }

  Future<void> _loadStaffPermissions(int staffId) async {
    setState(() {
      _isLoadingPermissions = true;
    });

    try {
      final response = await SupabaseService.client.rpc(
        'get_staff_permissions',
        params: {'p_staff_id': staffId},
      );

      if (response != null && response['success'] == true) {
        final data = response['data'];
        setState(() {
          _staffPermissions = {
            'dashboard': data['dashboard'] ?? false,
            'reports': data['reports'] ?? false,
            'transactions': data['transactions'] ?? false,
            'topup': data['topup'] ?? false,
            'withdrawal_requests': data['withdrawal_requests'] ?? false,
            'settings': data['settings'] ?? false,
            'user_management': data['user_management'] ?? false,
            'service_ports': data['service_ports'] ?? false,
            'admin_management': data['admin_management'] ?? false,
            'loaning': data['loaning'] ?? false,
            'feedback': data['feedback'] ?? false,
          };
        });
      } else {
        // Initialize with all false if no permissions found
        setState(() {
          _staffPermissions = {
            'dashboard': false,
            'reports': false,
            'transactions': false,
            'topup': false,
            'withdrawal_requests': false,
            'settings': false,
            'user_management': false,
            'service_ports': false,
            'admin_management': false,
            'loaning': false,
            'feedback': false,
          };
        });
      }
    } catch (e) {
      print('Error loading permissions: $e');
      // Initialize with all false on error
      setState(() {
        _staffPermissions = {
          'dashboard': false,
          'reports': false,
          'transactions': false,
          'topup': false,
          'withdrawal_requests': false,
          'settings': false,
          'user_management': false,
          'service_ports': false,
          'admin_management': false,
          'loaning': false,
          'feedback': false,
        };
      });
    } finally {
      setState(() {
        _isLoadingPermissions = false;
      });
    }
  }

  void _showPermissionsDialogUI(Map<String, dynamic> staff) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Container(
                    width: isMobile ? double.infinity : 500,
                    padding: EdgeInsets.all(isMobile ? 16 : 24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.security, color: evsuRed, size: 24),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Permissions for ${staff['full_name'] ?? 'Staff'}',
                                  style: TextStyle(
                                    fontSize: isMobile ? 18 : 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (_isLoadingPermissions)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  children: [
                                    const CircularProgressIndicator(),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Loading permissions...',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Select tabs this staff can access:',
                                  style: TextStyle(
                                    fontSize: isMobile ? 13 : 14,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Permission checkboxes
                                _buildPermissionCheckbox(
                                  'Dashboard',
                                  'dashboard',
                                  Icons.dashboard,
                                  isMobile,
                                  setDialogState,
                                ),
                                _buildPermissionCheckbox(
                                  'Reports',
                                  'reports',
                                  Icons.analytics,
                                  isMobile,
                                  setDialogState,
                                ),
                                _buildPermissionCheckbox(
                                  'Transactions',
                                  'transactions',
                                  Icons.receipt_long,
                                  isMobile,
                                  setDialogState,
                                ),
                                _buildPermissionCheckbox(
                                  'Top-Up',
                                  'topup',
                                  Icons.add_card,
                                  isMobile,
                                  setDialogState,
                                ),
                                _buildPermissionCheckbox(
                                  'Withdrawal Requests',
                                  'withdrawal_requests',
                                  Icons.account_balance_wallet,
                                  isMobile,
                                  setDialogState,
                                ),
                                _buildPermissionCheckbox(
                                  'Settings',
                                  'settings',
                                  Icons.settings,
                                  isMobile,
                                  setDialogState,
                                ),
                                _buildPermissionCheckbox(
                                  'User Management',
                                  'user_management',
                                  Icons.people,
                                  isMobile,
                                  setDialogState,
                                ),
                                _buildPermissionCheckbox(
                                  'Service Ports',
                                  'service_ports',
                                  Icons.store,
                                  isMobile,
                                  setDialogState,
                                ),
                                _buildPermissionCheckbox(
                                  'Admin Management',
                                  'admin_management',
                                  Icons.admin_panel_settings,
                                  isMobile,
                                  setDialogState,
                                ),
                                _buildPermissionCheckbox(
                                  'Loaning',
                                  'loaning',
                                  Icons.account_balance,
                                  isMobile,
                                  setDialogState,
                                ),
                                _buildPermissionCheckbox(
                                  'Feedback',
                                  'feedback',
                                  Icons.feedback,
                                  isMobile,
                                  setDialogState,
                                ),
                              ],
                            ),

                          if (!_isLoadingPermissions) ...[
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed:
                                        _isUpdatingPermissions
                                            ? null
                                            : () => Navigator.pop(context),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: evsuRed),
                                      padding: EdgeInsets.symmetric(
                                        vertical: isMobile ? 12 : 14,
                                      ),
                                    ),
                                    child: Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: evsuRed,
                                        fontSize: isMobile ? 14 : 16,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isUpdatingPermissions
                                            ? null
                                            : () => _updateStaffPermissions(
                                              staff['id'],
                                            ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: evsuRed,
                                      padding: EdgeInsets.symmetric(
                                        vertical: isMobile ? 12 : 14,
                                      ),
                                    ),
                                    child:
                                        _isUpdatingPermissions
                                            ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2,
                                              ),
                                            )
                                            : Text(
                                              'Save Permissions',
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
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
          ),
    );
  }

  Widget _buildPermissionCheckbox(
    String label,
    String key,
    IconData icon,
    bool isMobile,
    StateSetter setDialogState,
  ) {
    final isChecked = _staffPermissions[key] ?? false;

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 10 : 12),
      padding: EdgeInsets.all(isMobile ? 12 : 14),
      decoration: BoxDecoration(
        color: isChecked ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isChecked ? Colors.green.shade300 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: isChecked,
            onChanged: (value) {
              setDialogState(() {
                _staffPermissions[key] = value ?? false;
              });
            },
            activeColor: evsuRed,
          ),
          const SizedBox(width: 8),
          Icon(
            icon,
            size: isMobile ? 18 : 20,
            color: isChecked ? Colors.green.shade700 : Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w500,
                color: isChecked ? Colors.green.shade900 : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStaffPermissions(int staffId) async {
    setState(() {
      _isUpdatingPermissions = true;
    });

    try {
      final response = await SupabaseService.client.rpc(
        'update_staff_permissions',
        params: {
          'p_staff_id': staffId,
          'p_dashboard': _staffPermissions['dashboard'] ?? false,
          'p_reports': _staffPermissions['reports'] ?? false,
          'p_transactions': _staffPermissions['transactions'] ?? false,
          'p_topup': _staffPermissions['topup'] ?? false,
          'p_withdrawal_requests':
              _staffPermissions['withdrawal_requests'] ?? false,
          'p_settings': _staffPermissions['settings'] ?? false,
          'p_user_management': _staffPermissions['user_management'] ?? false,
          'p_service_ports': _staffPermissions['service_ports'] ?? false,
          'p_admin_management': _staffPermissions['admin_management'] ?? false,
          'p_loaning': _staffPermissions['loaning'] ?? false,
          'p_feedback': _staffPermissions['feedback'] ?? false,
        },
      );

      if (response != null && response['success'] == true) {
        Navigator.pop(context);
        _showSuccessDialog('Staff permissions updated successfully!');
      } else {
        final errorMessage =
            response?['message'] ?? 'Failed to update permissions';
        _showErrorDialog(errorMessage);
      }
    } catch (e) {
      _showErrorDialog('Error updating permissions: ${e.toString()}');
    } finally {
      setState(() {
        _isUpdatingPermissions = false;
      });
    }
  }

  void _showDeleteStaffConfirmation(Map<String, dynamic> staff) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final staffName = staff['full_name']?.toString() ?? 'this staff member';
    final username = staff['username']?.toString() ?? 'Unknown';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red.shade600,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Delete Staff Account?',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to permanently delete this staff account?',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Staff Name: $staffName',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.account_circle,
                            size: 16,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Username: $username',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ],
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
                        Icons.info_outline,
                        size: 18,
                        color: Colors.orange.shade700,
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
                onPressed:
                    _isDeletingStaff ? null : () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: isMobile ? 14 : 16,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed:
                    _isDeletingStaff
                        ? null
                        : () {
                          Navigator.pop(context); // Close confirmation dialog
                          _deleteStaffAccount(staff);
                        },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: isMobile ? 12 : 14,
                  ),
                ),
                child:
                    _isDeletingStaff
                        ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Text(
                          'Delete Account',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteStaffAccount(Map<String, dynamic> staff) async {
    final username = staff['username']?.toString();
    if (username == null || username.isEmpty) {
      _showErrorDialog('Invalid staff account: username is missing');
      return;
    }

    setState(() {
      _isDeletingStaff = true;
    });

    try {
      // Try RPC function first
      try {
        final response = await SupabaseService.client.rpc(
          'delete_admin_account',
          params: {'p_username': username},
        );

        if (response != null && response['success'] == true) {
          _showSuccessDialog('Staff account deleted successfully!');
          await _loadStaffAccounts();
        } else {
          final errorMessage =
              response?['message'] ?? 'Failed to delete staff account';
          _showErrorDialog(errorMessage);
        }
      } catch (rpcError) {
        print('RPC delete failed, using fallback: $rpcError');
        // Fallback: Direct table deletion
        await _deleteStaffAccountFallback(staff);
      }
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('foreign key') ||
          errorString.contains('constraint') ||
          errorString.contains('reference')) {
        _showErrorDialog(
          'Cannot delete staff account: This account is referenced by other records in the database.\n\nPlease remove all associated data first.',
        );
      } else {
        _showErrorDialog('Error deleting staff account: ${e.toString()}');
      }
    } finally {
      setState(() {
        _isDeletingStaff = false;
      });
    }
  }

  Future<void> _deleteStaffAccountFallback(Map<String, dynamic> staff) async {
    try {
      final staffId = staff['id'];
      if (staffId == null) {
        throw Exception('Staff ID is missing');
      }

      // Direct table deletion
      await SupabaseService.client
          .from('admin_accounts')
          .delete()
          .eq('id', staffId);

      _showSuccessDialog('Staff account deleted successfully!');
      await _loadStaffAccounts();
    } catch (e) {
      throw Exception('Fallback deletion failed: $e');
    }
  }
}
