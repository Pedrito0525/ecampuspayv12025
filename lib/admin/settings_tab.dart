import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'system_update_screen.dart';
import 'api_configuration_screen.dart';
import '../services/supabase_service.dart';
import '../services/admin_notification_service.dart';
import '../services/session_service.dart';
import '../services/encryption_service.dart';

class SettingsTab extends StatefulWidget {
  final int? initialFunction;

  const SettingsTab({super.key, this.initialFunction});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  static const Color evsuRed = Color(0xFFB91C1C);

  // General Settings state
  int _selectedFunction = -1;
  bool _isUpdating = false;
  bool _adminNotificationsEnabled = true;
  bool _maintenanceModeEnabled = false;

  // Password visibility states
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  DateTime? _lastMaintenanceModeCheck;
  StreamSubscription<List<Map<String, dynamic>>>? _maintenanceSubscription;
  bool _adminProfileLoaded = false;
  String? _storedAdminUsername;
  bool _adminEmailVerified = false;
  String? _supabaseAdminUserId;
  bool _isVerifyingEmail = false;
  String? _emailVerificationMessage;

  // Reset Database state
  bool _isResetting = false;
  ResetMode _resetMode = ResetMode.full;
  final TextEditingController _confirmPasswordController2 =
      TextEditingController();

  // Commission Settings state
  double _vendorCommission = 1.00;
  double _adminCommission = 0.50;
  bool _isLoadingCommissionSettings = false;
  bool _isUpdatingCommissionSettings = false;
  final TextEditingController _vendorCommissionController =
      TextEditingController(text: '1.00');
  final TextEditingController _adminCommissionController =
      TextEditingController(text: '0.50');

  // Backup & Recovery state
  static const List<String> _backupTargetTables = [
    'auth_students',
    'student_info',
    'id_replacement',
    'service_accounts',
    'service_transactions',
    'transaction_csu',
    'payment_items',
    'top_up_requests',
    'top_up_transactions',
    'withdrawal_requests',
    'withdrawal_transactions',
    'service_withdrawal_requests',
    'user_transfers',
    'read_inbox',
    'feedback',
    'loan_plans',
    'loan_applications',
    'active_loans',
    'loan_payments',
  ];

  static const List<String> _recoveryTableOrder = [
    'loan_plans',
    'auth_students',
    'id_replacement',
    'student_info',
    'service_accounts',
    'payment_items',
    'top_up_requests',
    'top_up_transactions',
    'withdrawal_requests',
    'withdrawal_transactions',
    'service_withdrawal_requests',
    'user_transfers',
    'service_transactions',
    'transaction_csu',
    'read_inbox',
    'feedback',
    'loan_applications',
    'active_loans',
    'loan_payments',
  ];

  // Deletion order for full restore mode (children before parents to respect FK constraints)
  static const List<String> _recoveryDeletionOrder = [
    'loan_payments',
    'loan_applications', // Must be deleted before loan_plans
    'active_loans',
    'transaction_csu',
    'service_transactions',
    'payment_items',
    'top_up_transactions',
    'withdrawal_transactions',
    'user_transfers',
    'read_inbox',
    'feedback',
    'id_replacement',
    'withdrawal_requests',
    'service_withdrawal_requests',
    'top_up_requests',
    'loan_plans', // Deleted after loan_applications
    'student_info',
    // Note: auth_students and service_accounts are preserved, not deleted
  ];

  static const Map<String, String> _recoveryPrimaryKeys = {
    'loan_plans': 'id',
    'auth_students': 'id',
    'id_replacement': 'id',
    'student_info': 'id',
    'service_accounts': 'id',
    'payment_items': 'id',
    'top_up_requests': 'id',
    'top_up_transactions': 'id',
    'withdrawal_requests': 'id',
    'withdrawal_transactions': 'id',
    'service_withdrawal_requests': 'id',
    'user_transfers': 'id',
    'service_transactions': 'id',
    'transaction_csu': 'id',
    'read_inbox': 'id',
    'feedback': 'id',
    'loan_applications': 'id',
    'active_loans': 'id',
    'loan_payments': 'id',
  };

  static const Map<String, String> _identityColumnOverrides = {
    'payment_items': 'id',
    'service_transactions': 'id',
    'transaction_csu': 'id',
  };

  static const List<_RecoveryForeignKey> _recoveryForeignKeyChecks = [
    _RecoveryForeignKey(
      childTable: 'id_replacement',
      childColumn: 'student_id',
      parentTable: 'auth_students',
      parentColumn: 'student_id',
    ),
    _RecoveryForeignKey(
      childTable: 'active_loans',
      childColumn: 'student_id',
      parentTable: 'auth_students',
      parentColumn: 'student_id',
    ),
    _RecoveryForeignKey(
      childTable: 'active_loans',
      childColumn: 'loan_plan_id',
      parentTable: 'loan_plans',
      parentColumn: 'id',
    ),
    _RecoveryForeignKey(
      childTable: 'loan_payments',
      childColumn: 'loan_id',
      parentTable: 'active_loans',
      parentColumn: 'id',
    ),
    _RecoveryForeignKey(
      childTable: 'loan_payments',
      childColumn: 'student_id',
      parentTable: 'auth_students',
      parentColumn: 'student_id',
    ),
    _RecoveryForeignKey(
      childTable: 'service_transactions',
      childColumn: 'service_account_id',
      parentTable: 'service_accounts',
      parentColumn: 'id',
    ),
    _RecoveryForeignKey(
      childTable: 'transaction_csu',
      childColumn: 'service_transactions_id',
      parentTable: 'service_transactions',
      parentColumn: 'id',
    ),
    _RecoveryForeignKey(
      childTable: 'service_transactions',
      childColumn: 'student_id',
      parentTable: 'auth_students',
      parentColumn: 'student_id',
    ),
    _RecoveryForeignKey(
      childTable: 'payment_items',
      childColumn: 'service_account_id',
      parentTable: 'service_accounts',
      parentColumn: 'id',
    ),
    _RecoveryForeignKey(
      childTable: 'top_up_requests',
      childColumn: 'user_id',
      parentTable: 'auth_students',
      parentColumn: 'student_id',
    ),
    _RecoveryForeignKey(
      childTable: 'top_up_transactions',
      childColumn: 'student_id',
      parentTable: 'auth_students',
      parentColumn: 'student_id',
    ),
    _RecoveryForeignKey(
      childTable: 'withdrawal_transactions',
      childColumn: 'student_id',
      parentTable: 'auth_students',
      parentColumn: 'student_id',
    ),
    _RecoveryForeignKey(
      childTable: 'withdrawal_transactions',
      childColumn: 'service_account_id',
      parentTable: 'service_accounts',
      parentColumn: 'id',
    ),
    _RecoveryForeignKey(
      childTable: 'withdrawal_requests',
      childColumn: 'student_id',
      parentTable: 'auth_students',
      parentColumn: 'student_id',
    ),
    _RecoveryForeignKey(
      childTable: 'user_transfers',
      childColumn: 'sender_student_id',
      parentTable: 'auth_students',
      parentColumn: 'student_id',
    ),
    _RecoveryForeignKey(
      childTable: 'user_transfers',
      childColumn: 'recipient_student_id',
      parentTable: 'auth_students',
      parentColumn: 'student_id',
    ),
    _RecoveryForeignKey(
      childTable: 'read_inbox',
      childColumn: 'student_id',
      parentTable: 'auth_students',
      parentColumn: 'student_id',
    ),
    _RecoveryForeignKey(
      childTable: 'loan_applications',
      childColumn: 'student_id',
      parentTable: 'auth_students',
      parentColumn: 'student_id',
    ),
    _RecoveryForeignKey(
      childTable: 'loan_applications',
      childColumn: 'loan_plan_id',
      parentTable: 'loan_plans',
      parentColumn: 'id',
    ),
    _RecoveryForeignKey(
      childTable: 'feedback',
      childColumn: 'student_id',
      parentTable: 'auth_students',
      parentColumn: 'student_id',
    ),
    _RecoveryForeignKey(
      childTable: 'service_withdrawal_requests',
      childColumn: 'service_account_id',
      parentTable: 'service_accounts',
      parentColumn: 'id',
    ),
  ];
  late List<_BackupTableStatus> _backupTableStatuses;
  List<String> _backupLogs = [];
  bool _isBackingUpTables = false;
  double _backupProgress = 0.0;
  int _backupInterfaceIndex = 0;
  String? _backupSavedPath;
  final ListToCsvConverter _csvConverter = const ListToCsvConverter();
  final CsvToListConverter _csvParser = const CsvToListConverter();

  Map<String, _RecoveryCsvPayload> _recoveryPayloads = {};
  late List<_RecoveryTableStatus> _recoveryTableStatuses;
  List<String> _recoveryLogs = [];
  List<_RecoveryValidationResult> _recoveryValidationResults = [];
  bool _recoveryValidationComplete = false;
  bool _isRecovering = false;
  bool _recoveryConstraintsDisabled = false;
  double _recoveryProgress = 0.0;
  _RecoveryMode _recoveryMode = _RecoveryMode.full;

  @override
  void initState() {
    super.initState();
    _initializeBackupStatuses();
    _initializeRecoveryStatuses();
    // Set initial function if provided
    // General Settings (function 0) is special - all staff can access it
    // Other functions require settings permission
    if (widget.initialFunction != null) {
      if (widget.initialFunction == 0) {
        // General Settings - always allowed
        _selectedFunction = widget.initialFunction!;
      } else {
        // Restricted functions - check permission asynchronously
        _checkAndSetRestrictedFunction(widget.initialFunction!);
      }
    }
    // Load current admin notification setting (in-memory)
    _adminNotificationsEnabled =
        AdminNotificationService.getNotificationsEnabled();
    // Load maintenance mode status
    _loadMaintenanceModeStatus();
    _subscribeToMaintenanceStream();
  }

  // Check permission and set restricted function
  Future<void> _checkAndSetRestrictedFunction(int functionIndex) async {
    final hasPermission = await _checkSettingsPermissionForFunction();
    if (hasPermission) {
      if (mounted) {
        setState(() {
          _selectedFunction = functionIndex;
        });
        // Load commission settings if accessing commission function
        if (functionIndex == 4) {
          _loadCommissionSettings();
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Access denied: You do not have permission to access this Settings function.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Handle General Settings access - always allowed for all staff to update own credentials
  void _handleGeneralSettingsAccess() {
    // General Settings is special - all staff can access it to update their own credentials
    setState(() {
      _selectedFunction = 0;
    });
  }

  // Check if staff member has settings permission for restricted functions
  Future<bool> _checkSettingsPermissionForFunction() async {
    // Full admins always have access
    if (!SessionService.isAdminStaff) {
      return true;
    }

    try {
      final currentUserData = SessionService.currentUserData;
      if (currentUserData == null) {
        return false;
      }

      final adminId = currentUserData['id'];
      if (adminId == null) {
        return false;
      }

      final int staffId =
          adminId is int ? adminId : (int.tryParse(adminId.toString()) ?? 0);
      if (staffId == 0) {
        return false;
      }

      // Query permissions
      final response = await SupabaseService.client.rpc(
        'get_staff_permissions',
        params: {'p_staff_id': staffId},
      );

      if (response != null &&
          response['success'] == true &&
          response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        return data['settings'] == true;
      }
      return false;
    } catch (e) {
      print('Error checking settings permission: $e');
      return false;
    }
  }

  // Handle access to restricted settings functions
  Future<void> _handleRestrictedSettingsAccess(int functionIndex) async {
    final hasPermission = await _checkSettingsPermissionForFunction();
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access denied: You do not have permission to access this Settings function.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _selectedFunction = functionIndex;
    });

    // Load commission settings if accessing commission function
    if (functionIndex == 4) {
      _loadCommissionSettings();
    }
  }

  // Form controllers for General Settings
  final TextEditingController _currentUsernameController =
      TextEditingController();
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newUsernameController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _newFullNameController = TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();

  @override
  void dispose() {
    _currentUsernameController.dispose();
    _currentPasswordController.dispose();
    _newUsernameController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newFullNameController.dispose();
    _newEmailController.dispose();
    _confirmPasswordController2.dispose();
    _vendorCommissionController.dispose();
    _adminCommissionController.dispose();
    _maintenanceSubscription?.cancel();
    super.dispose();
  }

  void _initializeBackupStatuses() {
    _backupTableStatuses =
        _backupTargetTables
            .map((table) => _BackupTableStatus(tableName: table))
            .toList();
  }

  void _initializeRecoveryStatuses() {
    _recoveryTableStatuses =
        _recoveryTableOrder
            .map((table) => _RecoveryTableStatus(tableName: table))
            .toList();
    _recoveryPayloads = {};
    _recoveryLogs = [];
    _recoveryValidationResults = [];
    _recoveryValidationComplete = false;
    _isRecovering = false;
    _recoveryProgress = 0.0;
    _recoveryConstraintsDisabled = false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh maintenance mode when widget becomes visible
    // This helps catch cases where navigation doesn't trigger rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMaintenanceModeStatus();
        _loadAdminProfileSummary(silent: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Refresh maintenance mode status when widget is built and route is active
    // This ensures refresh when returning from navigation
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      final now = DateTime.now();
      // Only refresh if last check was more than 1 second ago to avoid excessive calls
      if (_lastMaintenanceModeCheck == null ||
          now.difference(_lastMaintenanceModeCheck!).inSeconds > 1) {
        _lastMaintenanceModeCheck = now;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadMaintenanceModeStatus();
          }
        });
      }
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'System Settings',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Configure system parameters and preferences',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 30),

          // Show function detail if selected, otherwise show cards
          if (_selectedFunction == 0)
            _buildGeneralSettings()
          else if (_selectedFunction == 1)
            _buildResetDatabase()
          else if (_selectedFunction == 2)
            _buildNotificationSettings()
          else if (_selectedFunction == 3)
            _buildBackupAndRecovery()
          else if (_selectedFunction == 4)
            _buildCommissionSettings()
          else
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
                      icon: Icons.settings,
                      title: 'General Settings',
                      description: 'Configure system preferences',
                      color: evsuRed,
                      onTap: () => _handleGeneralSettingsAccess(),
                    ),
                    _buildFunctionCard(
                      icon: Icons.notifications,
                      title: 'Notification Settings',
                      description: 'Configure system notifications',
                      color: Colors.blue,
                      onTap: () => _handleRestrictedSettingsAccess(2),
                    ),
                    _buildFunctionCard(
                      icon: Icons.backup,
                      title: 'Backup & Recovery',
                      description:
                          _maintenanceModeEnabled
                              ? 'Configure data backup and recovery'
                              : 'Enable maintenance mode to access tools',
                      color: Colors.purple,
                      isDisabled: !_maintenanceModeEnabled,
                      onTap:
                          !_maintenanceModeEnabled
                              ? () {
                                _showMaintenanceModeDialog();
                              }
                              : () => _handleRestrictedSettingsAccess(3),
                    ),
                    _buildFunctionCard(
                      icon: Icons.update,
                      title: 'System Updates',
                      description: 'Manage system updates and maintenance',
                      color: Colors.orange,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SystemUpdateScreen(),
                          ),
                        );
                        // Refresh maintenance mode status when returning
                        _loadMaintenanceModeStatus();
                      },
                    ),
                    _buildFunctionCard(
                      icon: Icons.integration_instructions,
                      title: 'E-Wallet Payment QR',
                      description: 'Configure QR Payment Options',
                      color: Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => const ApiConfigurationScreen(),
                          ),
                        );
                      },
                    ),
                    _buildFunctionCard(
                      icon: Icons.percent,
                      title: 'Commission Settings',
                      description:
                          'Configure vendor and admin commission percentages',
                      color: Colors.green.shade700,
                      onTap: () => _handleRestrictedSettingsAccess(4),
                    ),
                    _buildFunctionCard(
                      icon: Icons.delete_forever,
                      title: 'Reset Database',
                      description:
                          _maintenanceModeEnabled
                              ? 'Permanently delete all data and reset IDs'
                              : 'Enable maintenance mode before resetting',
                      color: Colors.red.shade900,
                      isDisabled: !_maintenanceModeEnabled,
                      onTap:
                          !_maintenanceModeEnabled
                              ? () {
                                _showMaintenanceModeDialog();
                              }
                              : () => _handleRestrictedSettingsAccess(1),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
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
        border: Border.all(color: Colors.grey.shade200),
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
              const SizedBox(width: 8),
              const Text(
                'General Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Update admin account credentials and information',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 30),

          // Admin Credentials Form
          _buildAdminCredentialsForm(),
        ],
      ),
    );
  }

  Widget _buildNotificationSettings() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
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
          // Header with back button
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedFunction = -1),
                icon: const Icon(Icons.arrow_back, color: evsuRed),
                iconSize: isMobile ? 20 : 24,
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Expanded(
                child: Text(
                  'Notification Settings',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            'Enable or disable admin notifications for top-ups and withdrawals.',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Colors.grey.shade700,
              height: 1.35,
            ),
            softWrap: true,
          ),
          SizedBox(height: isMobile ? 16 : 24),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SwitchListTile.adaptive(
              contentPadding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 16,
                vertical: isMobile ? 6 : 8,
              ),
              title: Text(
                'Enable Admin Notifications',
                style: TextStyle(
                  fontSize: isMobile ? 15 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              subtitle: Text(
                'Receive updates when students submit top-up or withdrawal requests.',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
                softWrap: true,
              ),
              value: _adminNotificationsEnabled,
              activeColor: evsuRed,
              onChanged: (value) async {
                setState(() {
                  _adminNotificationsEnabled = value;
                });
                await AdminNotificationService.setNotificationsEnabled(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupAndRecovery() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    if (!_maintenanceModeEnabled) {
      return _buildMaintenanceRequirementCard(
        isMobile: isMobile,
        isTablet: isTablet,
        title: 'Backup & Recovery',
        icon: Icons.backup,
        message:
            'Enable System Maintenance Mode to run backups or recoveries. This prevents users from making changes while data is being exported or restored.',
      );
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
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
              IconButton(
                onPressed:
                    _isBackingUpTables
                        ? null
                        : () => setState(() => _selectedFunction = -1),
                icon: const Icon(Icons.arrow_back, color: evsuRed),
                iconSize: isMobile ? 20 : 24,
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Expanded(
                child: Text(
                  'Backup & Recovery',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: Colors.blue.shade700,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Protected',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontSize: isMobile ? 12 : 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 8 : 10),
          Text(
            'Export every critical table to CSV, bundle them into a ZIP archive, and prepare the system for a future recovery workflow.',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Colors.grey.shade700,
              height: 1.35,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 20),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<int>(
                value: 0,
                label: Text('Backup'),
                icon: Icon(Icons.cloud_download_outlined),
              ),
              ButtonSegment<int>(
                value: 1,
                label: Text('Recovery'),
                icon: Icon(Icons.restore_outlined),
              ),
            ],
            selected: {_backupInterfaceIndex},
            onSelectionChanged: (selection) {
              setState(() {
                _backupInterfaceIndex = selection.first;
              });
            },
          ),
          SizedBox(height: isMobile ? 20 : 24),
          if (_backupInterfaceIndex == 0)
            _buildBackupInterface(isMobile, isTablet)
          else
            _buildRecoveryInterface(isMobile, isTablet),
        ],
      ),
    );
  }

  Widget _buildBackupInterface(bool isMobile, bool isTablet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBackupFlowCard(isMobile),
        SizedBox(height: isMobile ? 16 : 20),
        _buildBackupTableChipList(isMobile),
        SizedBox(height: isMobile ? 16 : 20),
        if (_isBackingUpTables || _backupProgress > 0)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value:
                    _isBackingUpTables
                        ? (_backupProgress <= 0 ? null : _backupProgress)
                        : _backupProgress,
                color: evsuRed,
                backgroundColor: Colors.red.shade50,
                minHeight: 6,
              ),
              SizedBox(height: 6),
              Text(
                _isBackingUpTables
                    ? 'Backing up... ${(_backupProgress * 100).clamp(0, 100).toStringAsFixed(0)}%'
                    : _backupProgress == 0
                    ? 'Backup ready to run'
                    : 'Last run: ${(_backupProgress * 100).toStringAsFixed(0)}% complete',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color: _isBackingUpTables ? evsuRed : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        SizedBox(height: isMobile ? 16 : 20),
        _buildBackupStatusList(isMobile),
        SizedBox(height: isMobile ? 16 : 20),
        _buildBackupActionRow(isMobile),
        if (_backupSavedPath != null) ...[
          SizedBox(height: isMobile ? 12 : 16),
          _buildBackupSummaryCard(isMobile),
        ],
        SizedBox(height: isMobile ? 16 : 20),
        _buildBackupLogPanel(isMobile),
      ],
    );
  }

  Widget _buildRecoveryInterface(bool isMobile, bool isTablet) {
    final bool hasFiles = _recoveryPayloads.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRecoveryOverviewCard(isMobile),
        SizedBox(height: isMobile ? 16 : 20),
        _buildRecoveryModeSelector(isMobile),
        SizedBox(height: isMobile ? 16 : 20),
        _buildRecoveryFileSelector(isMobile),
        SizedBox(height: isMobile ? 16 : 20),
        if (_isRecovering || _recoveryProgress > 0)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(
                value:
                    _isRecovering
                        ? (_recoveryProgress <= 0 ? null : _recoveryProgress)
                        : _recoveryProgress,
                color: Colors.teal.shade600,
                backgroundColor: Colors.teal.shade50,
                minHeight: 6,
              ),
              SizedBox(height: 6),
              Text(
                _isRecovering
                    ? 'Restoring data... ${(_recoveryProgress * 100).clamp(0, 100).toStringAsFixed(0)}%'
                    : _recoveryProgress == 0
                    ? 'Waiting to start recovery'
                    : 'Last run reached ${(_recoveryProgress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color:
                      _isRecovering
                          ? Colors.teal.shade700
                          : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: isMobile ? 12 : 16),
            ],
          ),
        _buildRecoveryStatusList(isMobile),
        if (hasFiles && _recoveryValidationResults.isNotEmpty) ...[
          SizedBox(height: isMobile ? 16 : 20),
          _buildValidationResultsCard(isMobile),
        ],
        SizedBox(height: isMobile ? 16 : 20),
        _buildRecoveryActionRow(isMobile),
        SizedBox(height: isMobile ? 16 : 20),
        _buildRecoveryLogPanel(isMobile),
      ],
    );
  }

  Widget _buildCommissionSettings() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
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
          // Header with back button
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedFunction = -1),
                icon: const Icon(Icons.arrow_back, color: evsuRed),
                iconSize: isMobile ? 20 : 24,
              ),
              SizedBox(width: isMobile ? 6 : 8),
              Expanded(
                child: Text(
                  'Commission Settings',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            'Configure global commission percentages for vendor and admin earnings from top-up transactions.',
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              color: Colors.grey.shade700,
              height: 1.35,
            ),
            softWrap: true,
          ),
          SizedBox(height: isMobile ? 20 : 24),

          // Commission Settings Form
          if (_isLoadingCommissionSettings)
            Center(
              child: Padding(
                padding: EdgeInsets.all(isMobile ? 40 : 60),
                child: const CircularProgressIndicator(),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info Card
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: isMobile ? 20 : 24,
                      ),
                      SizedBox(width: isMobile ? 8 : 12),
                      Expanded(
                        child: Text(
                          'These percentages are used to calculate vendor and admin earnings from top-up transactions. Only service_type vendors have top-up functionality.',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.blue.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isMobile ? 20 : 24),

                // Vendor Commission Field
                Text(
                  'Vendor Commission (%)',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 10),
                TextFormField(
                  controller: _vendorCommissionController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Vendor Commission Percentage',
                    hintText: '1.00',
                    prefixIcon: const Icon(Icons.store, color: evsuRed),
                    suffixText: '%',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: evsuRed, width: 2),
                    ),
                    helperText: 'Default: 1.00% (Range: 0.00 - 100.00)',
                    helperMaxLines: 2,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter vendor commission';
                    }
                    final commission = double.tryParse(value);
                    if (commission == null) {
                      return 'Please enter a valid number';
                    }
                    if (commission < 0 || commission > 100) {
                      return 'Commission must be between 0.00 and 100.00';
                    }
                    return null;
                  },
                ),
                SizedBox(height: isMobile ? 20 : 24),

                // Admin Commission Field
                Text(
                  'Admin Commission (%)',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 10),
                TextFormField(
                  controller: _adminCommissionController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Admin Commission Percentage',
                    hintText: '0.50',
                    prefixIcon: const Icon(
                      Icons.admin_panel_settings,
                      color: evsuRed,
                    ),
                    suffixText: '%',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: evsuRed, width: 2),
                    ),
                    helperText: 'Default: 0.50% (Range: 0.00 - 100.00)',
                    helperMaxLines: 2,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter admin commission';
                    }
                    final commission = double.tryParse(value);
                    if (commission == null) {
                      return 'Please enter a valid number';
                    }
                    if (commission < 0 || commission > 100) {
                      return 'Commission must be between 0.00 and 100.00';
                    }
                    return null;
                  },
                ),
                SizedBox(height: isMobile ? 24 : 30),

                // Update Button
                SizedBox(
                  width: double.infinity,
                  height: isMobile ? 46 : 50,
                  child: ElevatedButton.icon(
                    onPressed:
                        _isUpdatingCommissionSettings
                            ? null
                            : _updateCommissionSettings,
                    icon:
                        _isUpdatingCommissionSettings
                            ? SizedBox(
                              width: isMobile ? 18 : 20,
                              height: isMobile ? 18 : 20,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Icon(Icons.save),
                    label: Text(
                      _isUpdatingCommissionSettings
                          ? 'Updating...'
                          : 'Update Commission Settings',
                      style: TextStyle(fontSize: isMobile ? 14 : 15),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: evsuRed,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _loadCommissionSettings() async {
    setState(() {
      _isLoadingCommissionSettings = true;
    });

    try {
      final result = await SupabaseService.getCommissionSettings();
      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        setState(() {
          _vendorCommission =
              (data['vendor_commission'] as num?)?.toDouble() ?? 1.00;
          _adminCommission =
              (data['admin_commission'] as num?)?.toDouble() ?? 0.50;
          _vendorCommissionController.text = _vendorCommission.toStringAsFixed(
            2,
          );
          _adminCommissionController.text = _adminCommission.toStringAsFixed(2);
        });
      } else {
        if (mounted) {
          final errorMessage =
              result['message'] ?? 'Failed to load commission settings';
          final friendlyMessage = _getUserFriendlyErrorMessage(errorMessage);
          _showErrorDialog(friendlyMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = _getUserFriendlyErrorMessage(e);
        _showErrorDialog(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCommissionSettings = false;
        });
      }
    }
  }

  Future<void> _updateCommissionSettings() async {
    // Validate inputs
    final vendorCommission = double.tryParse(
      _vendorCommissionController.text.trim(),
    );
    final adminCommission = double.tryParse(
      _adminCommissionController.text.trim(),
    );

    if (vendorCommission == null) {
      _showErrorDialog('Please enter a valid vendor commission percentage');
      return;
    }
    if (adminCommission == null) {
      _showErrorDialog('Please enter a valid admin commission percentage');
      return;
    }
    if (vendorCommission < 0 || vendorCommission > 100) {
      _showErrorDialog('Vendor commission must be between 0.00 and 100.00');
      return;
    }
    if (adminCommission < 0 || adminCommission > 100) {
      _showErrorDialog('Admin commission must be between 0.00 and 100.00');
      return;
    }

    setState(() {
      _isUpdatingCommissionSettings = true;
    });

    try {
      final result = await SupabaseService.updateCommissionSettings(
        vendorCommission: vendorCommission,
        adminCommission: adminCommission,
      );

      if (result['success'] == true) {
        setState(() {
          _vendorCommission = vendorCommission;
          _adminCommission = adminCommission;
        });
        if (mounted) {
          _showSuccessDialog(
            'Commission settings updated successfully!\n\n'
            'Vendor Commission: ${vendorCommission.toStringAsFixed(2)}%\n'
            'Admin Commission: ${adminCommission.toStringAsFixed(2)}%',
          );
        }
      } else {
        if (mounted) {
          final errorMessage =
              result['message'] ?? 'Failed to update commission settings';
          final friendlyMessage = _getUserFriendlyErrorMessage(errorMessage);
          _showErrorDialog(friendlyMessage);
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = _getUserFriendlyErrorMessage(e);
        _showErrorDialog(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingCommissionSettings = false;
        });
      }
    }
  }

  Widget _buildMaintenanceRequirementCard({
    required bool isMobile,
    required bool isTablet,
    required String title,
    required IconData icon,
    required String message,
  }) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
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
              IconButton(
                onPressed: () => setState(() => _selectedFunction = -1),
                icon: const Icon(Icons.arrow_back, color: evsuRed),
                iconSize: isMobile ? 20 : 24,
              ),
              SizedBox(width: isMobile ? 4 : 8),
              Icon(
                icon,
                color: Colors.orange.shade700,
                size: isMobile ? 24 : 28,
              ),
              SizedBox(width: isMobile ? 4 : 8),
              Expanded(
                child: Text(
                  '$title Locked',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 20 : 30),
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.announcement_outlined,
                      color: Colors.orange.shade700,
                      size: isMobile ? 24 : 28,
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Expanded(
                      child: Text(
                        'Enable Maintenance Mode',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : (isTablet ? 17 : 18),
                          fontWeight: FontWeight.w700,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: isMobile ? 16 : 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SystemUpdateScreen(),
                        ),
                      );
                      _loadMaintenanceModeStatus();
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Open System Maintenance Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: evsuRed,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: isMobile ? 12 : 16,
                      ),
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

  Widget _buildBackupFlowCard(bool isMobile) {
    final steps = [
      'User clicks “Backup Database” to trigger the process.',
      'System loads the curated list of mission-critical tables.',
      'Each table fetches all rows, captures ordered column names, and prepares CSV headers.',
      'Rows are converted into CSV format and saved as <table_name>.csv.',
      'All CSV files are automatically compressed into a single ZIP archive.',
      'The admin receives a success message and the saved file path.',
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_outlined, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Backup flow logic',
                style: TextStyle(
                  fontSize: isMobile ? 15 : 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 12),
          ...List.generate(
            steps.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == steps.length - 1 ? 0 : 10,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      steps[index],
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: Colors.blue.shade900,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupTableChipList(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Included tables (${_backupTargetTables.length})',
            style: TextStyle(
              fontSize: isMobile ? 14 : 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 10 : 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _backupTargetTables
                    .map(
                      (table) => Chip(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        avatar: Icon(
                          Icons.table_chart,
                          size: 16,
                          color: Colors.grey.shade700,
                        ),
                        label: Text(
                          table,
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupStatusList(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Table export status',
          style: TextStyle(
            fontSize: isMobile ? 14 : 15,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        ..._backupTableStatuses.map(
          (status) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(_statusIcon(status), color: _statusColor(status.status)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.tableName,
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        status.status == 'Failed'
                            ? (status.errorMessage ?? 'Export failed')
                            : '${status.rowCount} rows · ${status.columnCount} columns',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color:
                              status.status == 'Failed'
                                  ? Colors.red.shade700
                                  : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(status.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.status,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(status.status),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackupActionRow(bool isMobile) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isBackingUpTables ? null : _handleBackupAllTables,
            icon:
                _isBackingUpTables
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.cloud_download_outlined),
            label: Text(
              _isBackingUpTables ? 'Backing up...' : 'Backup database',
              style: TextStyle(fontSize: isMobile ? 14 : 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: evsuRed,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, isMobile ? 46 : 50),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: _isBackingUpTables ? null : _resetBackupState,
          child: const Text('Reset state'),
        ),
      ],
    );
  }

  Widget _buildBackupSummaryCard(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backup archive saved',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _backupSavedPath ?? '',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.green.shade900,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupLogPanel(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Activity log',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Clear logs',
                icon: const Icon(Icons.clear_all, size: 20),
                onPressed:
                    _backupLogs.isEmpty || _isBackingUpTables
                        ? null
                        : () => setState(() => _backupLogs = []),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 12),
          if (_backupLogs.isEmpty)
            Text(
              'Logs will appear here when you run a backup.',
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: Colors.grey.shade600,
              ),
            )
          else
            SizedBox(
              height: isMobile ? 160 : 200,
              child: ListView.builder(
                itemCount: _backupLogs.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      _backupLogs[index],
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRecoveryOverviewCard(bool isMobile) {
    final steps = [
      'Select every CSV exported from the backup ZIP (no mixing of versions).',
      'Validate table coverage and column headers before any data touches the DB.',
      'Temporarily disable foreign key triggers to avoid parent-child conflicts.',
      'Choose a restore mode: Full (truncate first) or Append (skip existing rows).',
      'Load tables in dependency order, then verify row counts and orphan records.',
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.restore_outlined, color: Colors.teal.shade700),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Guided recovery workflow (${_recoveryForeignKeyChecks.length} integrity checks)',
                  style: TextStyle(
                    fontSize: isMobile ? 15 : 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.teal.shade900,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 12),
          ...List.generate(
            steps.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == steps.length - 1 ? 0 : (isMobile ? 8 : 10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.teal.shade100),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.teal.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      steps[index],
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: Colors.teal.shade900,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryModeSelector(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Restore mode',
            style: TextStyle(
              fontSize: isMobile ? 14 : 15,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: isMobile ? 10 : 12),
          SegmentedButton<_RecoveryMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment<_RecoveryMode>(
                value: _RecoveryMode.full,
                label: Text('Full Restore'),
                icon: Icon(Icons.delete_sweep_outlined),
              ),
              ButtonSegment<_RecoveryMode>(
                value: _RecoveryMode.append,
                label: Text('Append Restore'),
                icon: Icon(Icons.playlist_add_outlined),
              ),
            ],
            selected: {_recoveryMode},
            onSelectionChanged:
                _isRecovering
                    ? null
                    : (selection) {
                      setState(() {
                        _recoveryMode = selection.first;
                      });
                    },
          ),
          SizedBox(height: isMobile ? 12 : 14),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child:
                _recoveryMode == _RecoveryMode.full
                    ? Text(
                      'Full Restore wipes each table before inserting CSV rows. Choose this when rebuilding an environment from scratch.',
                      key: const ValueKey('full'),
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    )
                    : Text(
                      'Append Restore keeps existing data and only inserts records that do not already exist (based on primary keys).',
                      key: const ValueKey('append'),
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryFileSelector(bool isMobile) {
    final bool hasSelection = _recoveryPayloads.isNotEmpty;
    final missingTables =
        _recoveryTableStatuses
            .where((status) => status.statusLabel == 'Missing File')
            .length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.file_present, color: Colors.blueGrey.shade600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CSV bundle (${_recoveryPayloads.length}/${_recoveryTableOrder.length})',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _isRecovering ? null : _handleRecoveryFileSelection,
                icon: const Icon(Icons.folder_open),
                label: Text(hasSelection ? 'Re-select files' : 'Choose files'),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 12),
          if (!hasSelection)
            Text(
              'Select all CSV files that were generated by the backup wizard. File names should match table names (e.g., auth_students.csv).',
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: Colors.grey.shade700,
                height: 1.35,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _recoveryPayloads.entries
                      .map(
                        (entry) => Chip(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          avatar: Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                          label: Text(
                            entry.value.fileName,
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 13,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          SizedBox(height: isMobile ? 10 : 12),
          Row(
            children: [
              Icon(
                missingTables == 0 ? Icons.verified : Icons.warning_amber,
                color:
                    missingTables == 0 ? Colors.green.shade700 : Colors.orange,
                size: 18,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  missingTables == 0
                      ? 'All required tables have CSV files attached.'
                      : '$missingTables table(s) still missing CSV files.',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color:
                        missingTables == 0
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed:
                    hasSelection && !_isRecovering ? _resetRecoveryState : null,
                child: const Text('Clear selection'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryStatusList(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Table readiness & results',
          style: TextStyle(
            fontSize: isMobile ? 14 : 15,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        ..._recoveryTableStatuses.map(
          (status) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.all(isMobile ? 12 : 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  _recoveryStatusIcon(status.statusLabel),
                  color: _recoveryStatusColor(status.statusLabel),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        status.tableName,
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatRecoveryStatusDetail(status),
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color:
                              status.hasError
                                  ? Colors.red.shade700
                                  : Colors.grey.shade700,
                        ),
                      ),
                      if (status.message != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          status.message!,
                          style: TextStyle(
                            fontSize: isMobile ? 11 : 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _recoveryStatusColor(
                      status.statusLabel,
                    ).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.statusLabel,
                    style: TextStyle(
                      fontSize: isMobile ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: _recoveryStatusColor(status.statusLabel),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildValidationResultsCard(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rule_folder, color: Colors.blueGrey.shade600),
              const SizedBox(width: 8),
              Text(
                'Post-restore integrity report',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 12),
          ..._recoveryValidationResults.map(
            (result) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: EdgeInsets.all(isMobile ? 10 : 12),
              decoration: BoxDecoration(
                color:
                    result.isError ? Colors.red.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      result.isError
                          ? Colors.red.shade200
                          : Colors.green.shade200,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    result.isError ? Icons.error : Icons.check_circle,
                    color:
                        result.isError
                            ? Colors.red.shade700
                            : Colors.green.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.title,
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.detail,
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.black87,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoveryActionRow(bool isMobile) {
    final bool readyToRestore =
        _recoveryValidationComplete &&
        _recoveryPayloads.length == _recoveryTableOrder.length;

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed:
                !_isRecovering && readyToRestore ? _startRecoveryProcess : null,
            icon:
                _isRecovering
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : const Icon(Icons.play_arrow_rounded),
            label: Text(
              _isRecovering ? 'Restoring data...' : 'Start recovery',
              style: TextStyle(fontSize: isMobile ? 14 : 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  readyToRestore ? Colors.teal.shade700 : Colors.grey,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, isMobile ? 46 : 50),
            ),
          ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: _isRecovering ? null : _resetRecoveryState,
          child: const Text('Reset flow'),
        ),
      ],
    );
  }

  Widget _buildRecoveryLogPanel(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Recovery log',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Clear logs',
                icon: const Icon(Icons.clear_all, size: 20),
                onPressed:
                    _recoveryLogs.isEmpty || _isRecovering
                        ? null
                        : () => setState(() => _recoveryLogs = []),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 10 : 12),
          if (_recoveryLogs.isEmpty)
            Text(
              'Logs will appear here once validation or restore steps begin.',
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                color: Colors.grey.shade600,
              ),
            )
          else
            SizedBox(
              height: isMobile ? 160 : 200,
              child: ListView.builder(
                itemCount: _recoveryLogs.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      _recoveryLogs[index],
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Color _recoveryStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green.shade700;
      case 'Ready':
        return Colors.blue.shade700;
      case 'Processing':
        return Colors.teal.shade700;
      case 'Schema mismatch':
      case 'Failed':
        return Colors.red.shade700;
      case 'Missing File':
      case 'Skipped':
        return Colors.orange.shade700;
      default:
        return Colors.grey.shade600;
    }
  }

  IconData _recoveryStatusIcon(String status) {
    switch (status) {
      case 'Completed':
        return Icons.check_circle_outline;
      case 'Ready':
        return Icons.assignment_turned_in_outlined;
      case 'Processing':
        return Icons.loop;
      case 'Schema mismatch':
      case 'Failed':
        return Icons.error_outline;
      case 'Missing File':
        return Icons.warning_amber_rounded;
      default:
        return Icons.hourglass_empty;
    }
  }

  String _formatRecoveryStatusDetail(_RecoveryTableStatus status) {
    switch (status.statusLabel) {
      case 'Completed':
        return 'Inserted ${status.insertedRows} · Skipped ${status.skippedRows}';
      case 'Ready':
        return '${status.csvRowCount} rows queued (${status.fileName ?? 'CSV'})';
      case 'Schema mismatch':
        return 'Validate headers before continuing';
      case 'Missing File':
        return 'No CSV selected for this table';
      case 'Processing':
        return 'Restoring rows...';
      case 'Failed':
        return 'Recovery halted for this table';
      default:
        return 'Awaiting validation';
    }
  }

  _RecoveryTableStatus? _getRecoveryStatus(String tableName) {
    try {
      return _recoveryTableStatuses.firstWhere(
        (status) => status.tableName == tableName,
      );
    } catch (_) {
      return null;
    }
  }

  Color _statusColor(String status) {
    if (status == 'Completed') return Colors.green.shade700;
    if (status == 'Processing') return Colors.blue.shade700;
    if (status == 'Failed') return Colors.red.shade700;
    return Colors.grey.shade600;
  }

  IconData _statusIcon(_BackupTableStatus status) {
    switch (status.status) {
      case 'Completed':
        return Icons.check_circle_outline;
      case 'Processing':
        return Icons.sync;
      case 'Failed':
        return Icons.error_outline;
      default:
        return Icons.hourglass_bottom;
    }
  }

  Future<void> _handleBackupAllTables() async {
    if (_isBackingUpTables) return;

    setState(() {
      _isBackingUpTables = true;
      _backupProgress = 0;
      _backupSavedPath = null;
      _backupLogs = [];
      for (final status in _backupTableStatuses) {
        status.reset();
      }
    });

    try {
      final Map<String, List<int>> csvFiles = {};
      int completed = 0;

      for (final status in _backupTableStatuses) {
        _logBackupMessage('Starting ${status.tableName}...');
        if (mounted) {
          setState(status.markProcessing);
        }

        final result = await SupabaseService.fetchTableDump(
          tableName: status.tableName,
        );

        if (result['success'] == true) {
          final rows =
              (result['data'] as List<dynamic>? ?? [])
                  .map<Map<String, dynamic>>(
                    (row) => Map<String, dynamic>.from(row as Map),
                  )
                  .toList();
          final columns =
              (result['columns'] as List<dynamic>? ?? [])
                  .map((col) => col.toString())
                  .toList();

          final payload = _createCsvBytes(columns, rows);
          csvFiles['${status.tableName}.csv'] = payload.bytes;

          if (mounted) {
            setState(() {
              status.markSuccess(rows.length, payload.columnCount);
            });
          }

          _logBackupMessage(
            'Completed ${status.tableName} (${rows.length} rows, ${payload.columnCount} columns)',
          );
        } else {
          final errorMessage =
              result['message']?.toString() ??
              result['error']?.toString() ??
              'Unknown error';

          final payload = _createCsvBytes(
            ['error'],
            [
              {'error': errorMessage},
            ],
          );
          csvFiles['${status.tableName}.csv'] = payload.bytes;

          if (mounted) {
            setState(() {
              status.markFailed(errorMessage);
            });
          }

          _logBackupMessage('Failed ${status.tableName}: $errorMessage');
        }

        completed++;
        if (mounted) {
          setState(
            () => _backupProgress = completed / _backupTableStatuses.length,
          );
        }
      }

      if (csvFiles.isEmpty) {
        throw Exception('No tables were exported. Please check the logs.');
      }

      final archiveBytes = _buildZipArchive(csvFiles);
      final savedPath = await _persistBackupArchive(
        archiveBytes,
        _buildBackupFileName(),
      );

      if (mounted) {
        setState(() {
          _backupSavedPath = savedPath;
        });
      }

      _logBackupMessage('Backup saved to $savedPath');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Backup saved to: $savedPath')));
        _showSuccessDialog('Backup complete! Archive saved to:\n$savedPath');
      }
    } catch (e) {
      _logBackupMessage('Backup failed: $e');
      if (mounted) {
        _showErrorDialog('Backup failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUpTables = false;
        });
      }
    }
  }

  ({List<int> bytes, int columnCount}) _createCsvBytes(
    List<String> columns,
    List<Map<String, dynamic>> rows,
  ) {
    var headers = List<String>.from(columns);
    var dataRows = List<Map<String, dynamic>>.from(rows);

    // If headers are empty but we have data rows, extract headers from first row
    if (headers.isEmpty && dataRows.isNotEmpty) {
      headers = dataRows.first.keys.map((key) => key.toString()).toList();
    }

    // If headers are still empty (no columns from schema and no data), use fallback
    if (headers.isEmpty) {
      headers = ['info'];
      dataRows = [
        {'info': 'No data available'},
      ];
    }

    // Create CSV with headers (even if no data rows)
    final csvMatrix = <List<dynamic>>[];
    csvMatrix.add(headers); // Always include headers

    // Add data rows if available
    for (final row in dataRows) {
      csvMatrix.add(
        headers.map((column) => _stringifyCsvValue(row[column])).toList(),
      );
    }

    // If no data rows but we have headers, CSV will contain only the header row
    // This preserves table structure even when empty

    final csvString = _csvConverter.convert(csvMatrix);
    return (bytes: utf8.encode(csvString), columnCount: headers.length);
  }

  String _stringifyCsvValue(dynamic value) {
    if (value == null) return '';
    if (value is DateTime) return value.toIso8601String();
    if (value is bool) return value ? 'true' : 'false';
    if (value is Map || value is List) {
      try {
        return jsonEncode(value);
      } catch (_) {
        return value.toString();
      }
    }
    return value.toString();
  }

  Uint8List _buildZipArchive(Map<String, List<int>> files) {
    final archive = Archive();
    files.forEach((fileName, bytes) {
      archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
    });

    final encoded = ZipEncoder().encode(archive);
    if (encoded == null) {
      throw Exception('Failed to compress backup files.');
    }
    return Uint8List.fromList(encoded);
  }

  Future<String> _persistBackupArchive(
    Uint8List archiveBytes,
    String fileName,
  ) async {
    final autoPath = await _attemptAutoSave(archiveBytes, fileName);
    if (autoPath != null) {
      return autoPath;
    }

    String? manualPath;
    try {
      manualPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save backup archive',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
    } catch (e) {
      _logBackupMessage('Manual save dialog failed: $e');
      manualPath = null;
    }

    if (manualPath != null && manualPath.trim().isNotEmpty) {
      final file = File(manualPath);
      await file.writeAsBytes(archiveBytes, flush: true);
      return file.path;
    }

    throw Exception('Backup file was not saved.');
  }

  Future<String?> _attemptAutoSave(
    Uint8List archiveBytes,
    String fileName,
  ) async {
    try {
      Directory? targetDir;
      if (Platform.isAndroid) {
        targetDir = Directory('/storage/emulated/0/Download');
        if (!await targetDir.exists()) {
          targetDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        targetDir = await getApplicationDocumentsDirectory();
      } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        targetDir = await getDownloadsDirectory();
        targetDir ??= await getApplicationDocumentsDirectory();
      } else {
        targetDir = await getApplicationDocumentsDirectory();
      }

      if (targetDir == null) return null;

      final file = File('${targetDir.path}/$fileName');
      await file.create(recursive: true);
      await file.writeAsBytes(archiveBytes, flush: true);
      return file.path;
    } catch (e) {
      _logBackupMessage('Auto-save skipped: $e');
      return null;
    }
  }

  String _buildBackupFileName() {
    final now = DateTime.now();
    final datePart =
        '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
    final timePart =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'backup_${datePart}_$timePart.zip';
  }

  void _resetBackupState() {
    if (_isBackingUpTables) return;
    for (final status in _backupTableStatuses) {
      status.reset();
    }
    setState(() {
      _backupLogs = [];
      _backupProgress = 0;
      _backupSavedPath = null;
    });
  }

  void _logBackupMessage(String message) {
    if (!mounted) return;
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _backupLogs.insert(0, '[$timestamp] $message');
      if (_backupLogs.length > 80) {
        _backupLogs = _backupLogs.sublist(0, 80);
      }
    });
  }

  void _logRecoveryMessage(String message) {
    if (!mounted) return;
    final now = DateTime.now();
    final timestamp =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    setState(() {
      _recoveryLogs.insert(0, '[$timestamp] $message');
      if (_recoveryLogs.length > 120) {
        _recoveryLogs = _recoveryLogs.sublist(0, 120);
      }
    });
  }

  void _resetRecoveryState() {
    if (_isRecovering) return;
    setState(_initializeRecoveryStatuses);
    _logRecoveryMessage('Recovery state cleared.');
  }

  Future<void> _handleRecoveryFileSelection() async {
    if (_isRecovering) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );
      if (result == null || result.files.isEmpty) return;
      await _ingestRecoveryFiles(result.files);
    } catch (e) {
      _logRecoveryMessage('File selection failed: $e');
      if (mounted) {
        _showErrorDialog('Failed to select CSV files: $e');
      }
    }
  }

  Future<void> _ingestRecoveryFiles(List<PlatformFile> files) async {
    final Map<String, _RecoveryCsvPayload> parsedPayloads = {};
    final List<String> errors = [];

    for (final file in files) {
      final inferredTable = _inferTableNameFromFile(file.name);
      if (inferredTable == null) {
        errors.add('${file.name}: Unknown table name');
        continue;
      }

      try {
        final payload = await _parseRecoveryCsv(file, inferredTable);
        final schemaResult = await _validateRecoveryPayload(
          inferredTable,
          payload,
        );
        if (!schemaResult.success) {
          errors.add('${file.name}: ${schemaResult.message}');
          final status = _getRecoveryStatus(inferredTable);
          if (status != null) {
            setState(
              () => status.markSchemaIssue(
                schemaResult.message ?? 'Schema mismatch',
              ),
            );
          }
          continue;
        }
        parsedPayloads[inferredTable] = payload;
      } catch (e) {
        errors.add('${file.name}: $e');
        final status = _getRecoveryStatus(inferredTable);
        if (status != null) {
          setState(() => status.markFailed('Unable to parse CSV'));
        }
      }
    }

    setState(() {
      for (final status in _recoveryTableStatuses) {
        status.reset();
        final payload = parsedPayloads[status.tableName];
        if (payload == null) {
          status.markMissing('Awaiting CSV file');
        } else {
          status.markReady(payload.rows.length, fileName: payload.fileName);
        }
      }

      _recoveryPayloads = parsedPayloads;
      _recoveryValidationResults = [];
      _recoveryProgress = 0;
      _recoveryValidationComplete =
          parsedPayloads.length == _recoveryTableOrder.length && errors.isEmpty;
    });

    if (errors.isNotEmpty) {
      _logRecoveryMessage('Validation issues detected.');
      if (mounted) {
        _showErrorDialog(
          'Some CSV files need attention:\n${errors.join('\n')}',
        );
      }
    } else {
      _logRecoveryMessage(
        'Validated ${parsedPayloads.length}/${_recoveryTableOrder.length} tables.',
      );
    }
  }

  String? _inferTableNameFromFile(String fileName) {
    final normalized = fileName
        .toLowerCase()
        .replaceAll('.csv', '')
        .replaceAll(' ', '_');

    // Sort tables by length (longest first) to match more specific names first
    // This ensures "service_withdrawal_requests" matches before "withdrawal_requests"
    final sortedTables = List<String>.from(_backupTargetTables)
      ..sort((a, b) => b.length.compareTo(a.length));

    // Try exact match first (most reliable)
    for (final table in sortedTables) {
      final target = table.toLowerCase();
      if (normalized == target) {
        return table;
      }
    }

    // Try ends with pattern (e.g., backup_service_withdrawal_requests.csv)
    // Check longer names first to avoid partial matches
    for (final table in sortedTables) {
      final target = table.toLowerCase();
      if (normalized.endsWith('_$target') || normalized.endsWith(target)) {
        return table;
      }
    }

    // Try starts with pattern (e.g., service_withdrawal_requests_backup.csv)
    for (final table in sortedTables) {
      final target = table.toLowerCase();
      if (normalized.startsWith('${target}_') ||
          normalized.startsWith(target)) {
        return table;
      }
    }

    // Last resort: contains match with underscore boundaries
    // This ensures "withdrawal_requests" doesn't match "service_withdrawal_requests"
    for (final table in sortedTables) {
      final target = table.toLowerCase();
      // Check if target appears with underscore boundaries or at start/end
      if (normalized.contains('_${target}_') ||
          normalized.startsWith('${target}_') ||
          normalized.endsWith('_$target') ||
          normalized == target) {
        return table;
      }
    }

    return null;
  }

  Future<_RecoveryCsvPayload> _parseRecoveryCsv(
    PlatformFile file,
    String tableName,
  ) async {
    if (file.path == null) {
      throw Exception('File path is not available for ${file.name}');
    }

    final content = await File(file.path!).readAsString();
    final rows = _csvParser.convert(content);
    if (rows.isEmpty) {
      throw Exception('${file.name} does not contain any data.');
    }

    final headers =
        rows.first.map((header) => header.toString().trim()).toList();
    final dataRows = <Map<String, dynamic>>[];

    for (final row in rows.skip(1)) {
      final rowMap = <String, dynamic>{};
      for (int i = 0; i < headers.length; i++) {
        final header = headers[i];
        if (header.isEmpty) continue;
        final cell = i < row.length ? row[i] : null;
        rowMap[header] = _convertCsvValue(cell);
      }

      if (rowMap.values.every((value) => value == null || value == '')) {
        continue;
      }
      dataRows.add(rowMap);
    }

    return _RecoveryCsvPayload(
      tableName: tableName,
      fileName: file.name,
      filePath: file.path!,
      headers: headers,
      rows: dataRows,
    );
  }

  dynamic _convertCsvValue(dynamic value) {
    if (value == null) return null;
    if (value is num || value is bool) return value;

    final stringValue = value.toString().trim();
    if (stringValue.isEmpty) return null;

    final lower = stringValue.toLowerCase();
    if (lower == 'true' || lower == 'false') {
      return lower == 'true';
    }

    if (RegExp(r'^-?\d+$').hasMatch(stringValue)) {
      return int.tryParse(stringValue);
    }
    if (RegExp(r'^-?\d+\.\d+$').hasMatch(stringValue)) {
      return double.tryParse(stringValue);
    }

    if ((stringValue.startsWith('{') && stringValue.endsWith('}')) ||
        (stringValue.startsWith('[') && stringValue.endsWith(']'))) {
      try {
        return jsonDecode(stringValue);
      } catch (_) {
        return stringValue;
      }
    }

    return stringValue;
  }

  Future<_SchemaValidationResult> _validateRecoveryPayload(
    String tableName,
    _RecoveryCsvPayload payload,
  ) async {
    try {
      // Try to get table columns with fallback support
      List<String> columns = await SupabaseService.getTableColumns(
        tableName: tableName,
        sampleRow: payload.rows.isNotEmpty ? payload.rows.first : null,
      );

      // If still empty, try using CSV headers as a fallback for validation
      if (columns.isEmpty && payload.headers.isNotEmpty) {
        _logRecoveryMessage(
          'Warning: Table metadata unavailable for $tableName. Using CSV headers for validation.',
        );
        // Use CSV headers as reference, but still validate
        columns = payload.headers;
      }

      if (columns.isEmpty) {
        return const _SchemaValidationResult(
          success: false,
          message: 'Table metadata unavailable and CSV has no headers.',
        );
      }

      final dbColumns = columns.map((c) => c.toLowerCase()).toSet();
      final csvColumns =
          payload.headers.map((c) => c.toLowerCase().trim()).toSet();
      final missing = dbColumns.difference(csvColumns);

      if (missing.isNotEmpty) {
        return _SchemaValidationResult(
          success: false,
          message: 'Missing columns: ${missing.join(', ')}',
        );
      }

      return const _SchemaValidationResult(success: true);
    } catch (e) {
      return _SchemaValidationResult(
        success: false,
        message: 'Schema validation failed: $e',
      );
    }
  }

  Future<void> _startRecoveryProcess() async {
    if (_isRecovering) return;
    if (!_recoveryValidationComplete) {
      _showErrorDialog(
        'Please provide valid CSV files for all tables before starting recovery.',
      );
      return;
    }

    final tablesToProcess =
        _recoveryTableStatuses
            .where((status) => _recoveryPayloads.containsKey(status.tableName))
            .toList();
    if (tablesToProcess.isEmpty) {
      _showErrorDialog('No tables are ready for recovery.');
      return;
    }

    setState(() {
      _isRecovering = true;
      _recoveryLogs = [];
      _recoveryProgress = 0;
      for (final status in tablesToProcess) {
        status.message = null;
      }
    });

    try {
      await _toggleForeignKeysForRecovery(false);

      // For full restore mode, clear tables in deletion order first (children before parents)
      if (_recoveryMode == _RecoveryMode.full) {
        _logRecoveryMessage(
          'Clearing tables in deletion order for full restore...',
        );
        for (final tableName in _recoveryDeletionOrder) {
          // Skip auth_students and service_accounts as they are preserved
          if (tableName == 'auth_students' || tableName == 'service_accounts') {
            continue;
          }

          // Only clear if we have a payload for this table
          if (!_recoveryPayloads.containsKey(tableName)) {
            continue;
          }

          final primaryKey = _recoveryPrimaryKeys[tableName] ?? 'id';
          try {
            final clearResp = await SupabaseService.deleteAllRows(
              tableName: tableName,
              primaryKey: primaryKey,
            );
            if (clearResp['success'] == true) {
              _logRecoveryMessage('$tableName cleared before restore.');
            } else {
              _logRecoveryMessage(
                'Warning: Failed to clear $tableName: ${clearResp['message']}',
              );
            }
          } catch (e) {
            _logRecoveryMessage('Warning: Error clearing $tableName: $e');
            // Continue with other tables even if one fails
          }
        }
      }

      int processed = 0;
      for (final status in tablesToProcess) {
        final payload = _recoveryPayloads[status.tableName];
        if (payload == null) continue;

        setState(status.markProcessing);
        try {
          final outcome = await _restoreTableFromPayload(
            status.tableName,
            payload,
          );
          setState(
            () =>
                status.markCompleted(outcome.insertedRows, outcome.skippedRows),
          );
          _logRecoveryMessage(
            status.tableName == 'auth_students' ||
                    status.tableName == 'service_accounts'
                ? '${status.tableName}: restored ${outcome.insertedRows} balances, skipped ${outcome.skippedRows}'
                : '${status.tableName}: inserted ${outcome.insertedRows}, skipped ${outcome.skippedRows}',
          );
        } catch (e) {
          setState(() => status.markFailed(e.toString()));
          _logRecoveryMessage('${status.tableName} failed: $e');
          rethrow;
        }

        processed++;
        if (mounted) {
          setState(() {
            _recoveryProgress = processed / tablesToProcess.length;
          });
        }
      }

      await _toggleForeignKeysForRecovery(true);
      await _runFinalRecoveryValidation();

      // Reset sequences to prevent duplicate key errors on new inserts
      _logRecoveryMessage('Resetting sequences after recovery...');
      final sequenceResetResult =
          await SupabaseService.resetSequencesAfterRecovery();
      if (sequenceResetResult['success'] == true) {
        _logRecoveryMessage(
          'Sequences reset successfully. New inserts will continue from highest ID.',
        );
      } else {
        _logRecoveryMessage(
          'Warning: Sequence reset failed: ${sequenceResetResult['message'] ?? 'Unknown error'}. '
          'You may need to manually reset sequences.',
        );
      }

      if (mounted) {
        _showSuccessDialog('Recovery completed successfully.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Recovery failed: $e');
      }
    } finally {
      if (_recoveryConstraintsDisabled) {
        await _toggleForeignKeysForRecovery(true);
      }
      if (mounted) {
        setState(() {
          _isRecovering = false;
          _recoveryProgress = 0;
        });
      }
    }
  }

  Future<void> _handleVerifyEmail() async {
    final username =
        (_storedAdminUsername ?? _currentUsernameController.text).trim();
    if (username.isEmpty) {
      _showErrorDialog(
        'Unable to determine your admin username. Please reload the page.',
      );
      return;
    }
    final password = _currentPasswordController.text.trim();

    if (password.isEmpty) {
      _showErrorDialog('Please enter your current password to verify email.');
      return;
    }

    setState(() {
      _isVerifyingEmail = true;
      _emailVerificationMessage = null;
    });

    try {
      final result = await SupabaseService.verifyAdminEmail(
        username: username,
        password: password,
      );

      if (!mounted) return;

      setState(() {
        _isVerifyingEmail = false;
        _emailVerificationMessage = result['message']?.toString();
      });

      if (result['success'] == true) {
        setState(() {
          _adminEmailVerified = result['email_verified'] == true;
          if (result['supabase_uid'] != null) {
            _supabaseAdminUserId = result['supabase_uid'].toString();
          }
        });
        await _loadAdminProfileSummary(silent: true);
        _showSuccessDialog(
          result['message'] ??
              'Verification email sent. Please check your inbox.',
        );
      } else {
        _showErrorDialog(
          result['message'] ?? 'Failed to verify email. Please try again.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isVerifyingEmail = false;
      });
      _showErrorDialog('Failed to verify email: $e');
    }
  }

  Future<_TableRestoreOutcome> _restoreTableFromPayload(
    String tableName,
    _RecoveryCsvPayload payload,
  ) async {
    // Special handling for auth_students: only restore balances, preserve accounts
    if (tableName == 'auth_students') {
      return await _restoreAuthStudentsBalances(payload);
    }

    // Special handling for service_accounts: only restore balances, preserve accounts
    if (tableName == 'service_accounts') {
      return await _restoreServiceAccountsBalances(payload);
    }

    final primaryKey = _recoveryPrimaryKeys[tableName] ?? 'id';
    final mode = _recoveryMode;
    var rows = payload.rows;
    int skipped = 0;

    // For full restore mode, tables are already cleared in deletion order above
    // So we skip clearing here to avoid duplicate work and FK constraint errors
    if (mode == _RecoveryMode.full) {
      // Tables are already cleared in the correct order, just proceed with insert
      _logRecoveryMessage('$tableName ready for restore (already cleared).');
    } else {
      final existingKeys = await SupabaseService.fetchPrimaryKeyValues(
        tableName: tableName,
        primaryKey: primaryKey,
      );
      final filtered = <Map<String, dynamic>>[];
      for (final row in rows) {
        final keyValue = row[primaryKey];
        if (keyValue == null) {
          skipped++;
          continue;
        }
        final keyString = keyValue.toString();
        if (existingKeys.contains(keyString)) {
          skipped++;
          continue;
        }
        filtered.add(row);
      }
      rows = filtered;
    }

    if (rows.isEmpty) {
      return _TableRestoreOutcome(insertedRows: 0, skippedRows: skipped);
    }

    final identityColumn = _identityColumnOverrides[tableName];
    if (identityColumn != null) {
      final resp = await SupabaseService.setIdentityGenerationMode(
        tableName: tableName,
        columnName: identityColumn,
        generatedAlways: false,
      );
      if (resp['success'] != true) {
        throw Exception(
          resp['message'] ??
              'Unable to relax identity column for $tableName.$identityColumn',
        );
      }
    }

    try {
      final insertResp = await SupabaseService.insertRows(
        tableName: tableName,
        rows: rows,
      );
      if (insertResp['success'] != true) {
        throw Exception(insertResp['message'] ?? 'Insert operation failed.');
      }

      final inserted =
          insertResp['inserted'] is int
              ? insertResp['inserted'] as int
              : rows.length;

      return _TableRestoreOutcome(insertedRows: inserted, skippedRows: skipped);
    } finally {
      if (identityColumn != null) {
        await SupabaseService.setIdentityGenerationMode(
          tableName: tableName,
          columnName: identityColumn,
          generatedAlways: true,
        );
      }
    }
  }

  /// Restore balances for auth_students table only (preserve accounts)
  Future<_TableRestoreOutcome> _restoreAuthStudentsBalances(
    _RecoveryCsvPayload payload,
  ) async {
    int updated = 0;
    int skipped = 0;

    try {
      await SupabaseService.initialize();

      _logRecoveryMessage(
        'Restoring balances for auth_students (preserving accounts)...',
      );

      for (final row in payload.rows) {
        // Get student_id from CSV (may be encrypted or plain text depending on backup format)
        final studentIdFromCsv = row['student_id']?.toString();
        final balanceStr = row['balance']?.toString();

        if (studentIdFromCsv == null || studentIdFromCsv.isEmpty) {
          skipped++;
          continue;
        }

        // Parse balance from backup
        final balance = double.tryParse(balanceStr ?? '0') ?? 0.0;

        try {
          // Try to update balance using student_id from CSV
          // The student_id in CSV should match the format in database (encrypted or plain)
          final updateResult = await SupabaseService.adminClient
              .from('auth_students')
              .update({'balance': balance})
              .eq('student_id', studentIdFromCsv)
              .select('student_id')
              .limit(1);

          // Check if update was successful (updateResult should be a list)
          if (updateResult.isNotEmpty) {
            updated++;
          } else {
            // Student not found - try with encrypted student_id if CSV has plain text
            // Note: This handles the case where CSV has plain text but DB has encrypted
            try {
              final encryptedData = EncryptionService.encryptUserData({
                'student_id': studentIdFromCsv,
              });
              final encryptedStudentId =
                  encryptedData['student_id']?.toString() ?? '';

              if (encryptedStudentId.isNotEmpty) {
                final encryptedUpdateResult = await SupabaseService.adminClient
                    .from('auth_students')
                    .update({'balance': balance})
                    .eq('student_id', encryptedStudentId)
                    .select('student_id')
                    .limit(1);

                if (encryptedUpdateResult.isNotEmpty) {
                  updated++;
                } else {
                  skipped++;
                  _logRecoveryMessage(
                    'Skipped student_id $studentIdFromCsv: Student not found in database',
                  );
                }
              } else {
                skipped++;
                _logRecoveryMessage(
                  'Skipped student_id $studentIdFromCsv: Failed to encrypt for lookup',
                );
              }
            } catch (encryptError) {
              skipped++;
              _logRecoveryMessage(
                'Skipped student_id $studentIdFromCsv: ${encryptError.toString()}',
              );
            }
          }
        } catch (e) {
          // Update failed - skip
          skipped++;
          _logRecoveryMessage(
            'Skipped student_id $studentIdFromCsv: ${e.toString()}',
          );
        }
      }

      _logRecoveryMessage(
        'auth_students balances restored: $updated updated, $skipped skipped',
      );

      return _TableRestoreOutcome(insertedRows: updated, skippedRows: skipped);
    } catch (e) {
      throw Exception('Failed to restore auth_students balances: $e');
    }
  }

  /// Restore balances for service_accounts table only (preserve accounts)
  Future<_TableRestoreOutcome> _restoreServiceAccountsBalances(
    _RecoveryCsvPayload payload,
  ) async {
    int updated = 0;
    int skipped = 0;

    try {
      await SupabaseService.initialize();

      _logRecoveryMessage(
        'Restoring balances for service_accounts (preserving accounts)...',
      );

      for (final row in payload.rows) {
        // Get id from CSV
        final idFromCsv = row['id'];
        final balanceStr = row['balance']?.toString();

        if (idFromCsv == null) {
          skipped++;
          continue;
        }

        // Parse balance from backup
        final balance = double.tryParse(balanceStr ?? '0') ?? 0.0;

        try {
          // Try to update balance using id from CSV
          final updateResult = await SupabaseService.adminClient
              .from('service_accounts')
              .update({'balance': balance})
              .eq('id', idFromCsv)
              .select('id')
              .limit(1);

          // Check if update was successful (updateResult should be a list)
          if (updateResult.isNotEmpty) {
            updated++;
          } else {
            skipped++;
            _logRecoveryMessage(
              'Skipped service_account id $idFromCsv: Service account not found in database',
            );
          }
        } catch (e) {
          // Update failed - skip
          skipped++;
          _logRecoveryMessage(
            'Skipped service_account id $idFromCsv: ${e.toString()}',
          );
        }
      }

      _logRecoveryMessage(
        'service_accounts balances restored: $updated updated, $skipped skipped',
      );

      return _TableRestoreOutcome(insertedRows: updated, skippedRows: skipped);
    } catch (e) {
      throw Exception('Failed to restore service_accounts balances: $e');
    }
  }

  Future<void> _toggleForeignKeysForRecovery(bool enable) async {
    try {
      final resp = await SupabaseService.toggleRecoveryTriggers(enable: enable);
      if (resp['success'] == true) {
        setState(() {
          _recoveryConstraintsDisabled = !enable;
        });
        _logRecoveryMessage(
          enable
              ? 'Foreign key triggers re-enabled.'
              : 'Foreign key triggers disabled.',
        );
      } else {
        throw Exception(resp['message'] ?? 'Failed to toggle triggers.');
      }
    } catch (e) {
      _logRecoveryMessage('Constraint toggle error: $e');
      if (!enable) {
        rethrow;
      }
    }
  }

  Future<void> _runFinalRecoveryValidation() async {
    final expectedCounts = _buildExpectedCountsPayload();
    final response = await SupabaseService.runRecoveryIntegrityCheck(
      expectedCounts: expectedCounts,
    );

    if (response['success'] == true) {
      final data = response['data'] ?? {};
      final rowCounts =
          (data['row_counts'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();
      final fkChecks =
          (data['fk_checks'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>();

      final results = <_RecoveryValidationResult>[];
      for (final row in rowCounts) {
        final table = row['table']?.toString() ?? 'Unknown';
        final expected = row['expected'];
        final actual = row['actual'];
        final matches = expected == null || expected == actual;
        results.add(
          _RecoveryValidationResult(
            title: '$table row count',
            detail:
                expected == null
                    ? 'Database has $actual row(s)'
                    : 'Expected $expected · Actual $actual',
            isError: !matches,
          ),
        );
      }

      for (final check in fkChecks) {
        final missing = (check['missing'] ?? 0) as int;
        final childTable = check['child_table'] ?? '';
        final childColumn = check['child_column'] ?? '';
        final parentTable = check['parent_table'] ?? '';
        final parentColumn = check['parent_column'] ?? '';
        results.add(
          _RecoveryValidationResult(
            title: '$childTable.$childColumn → $parentTable.$parentColumn',
            detail:
                missing == 0
                    ? 'No orphan rows detected.'
                    : '$missing orphan row(s) need review.',
            isError: missing > 0,
          ),
        );
      }

      setState(() {
        _recoveryValidationResults = results;
      });
      _logRecoveryMessage('Integrity validation completed.');
    } else {
      final message = response['message'] ?? 'Integrity validation failed.';
      _logRecoveryMessage(message);
      if (mounted) {
        _showErrorDialog(message);
      }
    }
  }

  Map<String, int> _buildExpectedCountsPayload() {
    final counts = <String, int>{};
    _recoveryPayloads.forEach((table, payload) {
      counts[table] = payload.rows.length;
    });
    return counts;
  }

  Widget _buildAdminCredentialsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Update Admin Password',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Change your admin password (optional)',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),

        // Current Credentials Section
        const Text(
          'Current Credentials',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),

        // Current Username
        TextFormField(
          controller: _currentUsernameController,
          decoration: InputDecoration(
            labelText: 'Current Username',
            prefixIcon: const Icon(Icons.person, color: evsuRed),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Current Password
        TextFormField(
          controller: _currentPasswordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: 'Current Password',
            prefixIcon: const Icon(Icons.lock, color: evsuRed),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Email Section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _adminEmailVerified
                        ? Icons.verified
                        : Icons.mark_email_unread,
                    color: _adminEmailVerified ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _adminEmailVerified
                              ? 'Email verified with Supabase Auth'
                              : 'Email not yet linked to Supabase Auth',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color:
                                _adminEmailVerified
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700,
                          ),
                        ),
                        if (_newEmailController.text.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Current: ${_newEmailController.text}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (!_adminEmailVerified)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            _isVerifyingEmail ? null : _handleVerifyEmail,
                        icon:
                            _isVerifyingEmail
                                ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.verified_user),
                        label: const Text('Verify Email'),
                      ),
                    ),
                  if (_adminEmailVerified) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUpdating ? null : _showChangeEmailDialog,
                        icon: const Icon(Icons.email),
                        label: const Text('Change Email'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: evsuRed,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (_supabaseAdminUserId?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Text(
                  'Supabase UID: ${_supabaseAdminUserId!}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
              if (_emailVerificationMessage?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  _emailVerificationMessage ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // New Password Section
        const Text(
          'New Password (Optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Leave blank if you don\'t want to change your password',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 12),

        // New Password
        TextFormField(
          controller: _newPasswordController,
          obscureText: !_isNewPasswordVisible,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'New Password (Optional)',
            prefixIcon: const Icon(Icons.lock_outline, color: evsuRed),
            suffixIcon: IconButton(
              icon: Icon(
                _isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.grey.shade600,
              ),
              onPressed: () {
                setState(() {
                  _isNewPasswordVisible = !_isNewPasswordVisible;
                });
              },
              tooltip:
                  _isNewPasswordVisible ? 'Hide password' : 'Show password',
            ),
            helperText:
                _newPasswordController.text.isNotEmpty
                    ? 'Password must be at least 6 characters'
                    : null,
            helperMaxLines: 2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Confirm Password
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: !_isConfirmPasswordVisible,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Confirm New Password (Optional)',
            prefixIcon: const Icon(Icons.lock_outline, color: evsuRed),
            suffixIcon: IconButton(
              icon: Icon(
                _isConfirmPasswordVisible
                    ? Icons.visibility
                    : Icons.visibility_off,
                color: Colors.grey.shade600,
              ),
              onPressed: () {
                setState(() {
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                });
              },
              tooltip:
                  _isConfirmPasswordVisible ? 'Hide password' : 'Show password',
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: evsuRed, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Password Requirements:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '• Minimum 6 characters required',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              '• Leave password fields empty to keep current password unchanged',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 30),

        // Update Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _isUpdating ? null : _updateAdminCredentials,
            style: ElevatedButton.styleFrom(
              backgroundColor: evsuRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child:
                _isUpdating
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      'Update Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
          ),
        ),
      ],
    );
  }

  Future<void> _updateAdminCredentials() async {
    // Validate form
    if (!_validateForm()) return;

    // Check if password is being updated
    final newPassword = _newPasswordController.text.trim();
    if (newPassword.isEmpty) {
      _showPasswordUpdateErrorModal('Please enter a new password to update');
      return;
    }

    setState(() {
      _isUpdating = true;
    });

    try {
      // Get current admin info to preserve username and full name
      final adminData = await SupabaseService.getCurrentAdminInfo();
      final currentUsername =
          adminData['success'] == true && adminData['data'] != null
              ? adminData['data']['username']?.toString() ??
                  _currentUsernameController.text.trim()
              : _currentUsernameController.text.trim();
      final currentFullName =
          adminData['success'] == true && adminData['data'] != null
              ? adminData['data']['full_name']?.toString() ?? ''
              : '';
      final currentEmail =
          adminData['success'] == true && adminData['data'] != null
              ? adminData['data']['email']?.toString() ??
                  _newEmailController.text.trim()
              : _newEmailController.text.trim();

      final result = await SupabaseService.updateAdminCredentials(
        currentUsername: _currentUsernameController.text.trim(),
        currentPassword: _currentPasswordController.text.trim(),
        newUsername: currentUsername, // Keep same username
        newPassword: newPassword,
        newFullName: currentFullName, // Keep same full name
        newEmail: currentEmail, // Keep same email
      );

      if (result['success']) {
        _showSuccessDialog('Admin password updated successfully!');
        _clearForm();
        // Reload admin profile to refresh email display
        await _loadAdminProfileSummary(silent: true);
      } else {
        _showPasswordUpdateErrorModal(
          result['message'] ?? 'Failed to update password',
        );
      }
    } catch (e) {
      _showPasswordUpdateErrorModal(e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  bool _validateForm() {
    if (_currentUsernameController.text.trim().isEmpty) {
      _showErrorDialog('Please enter current username');
      return false;
    }
    if (_currentPasswordController.text.trim().isEmpty) {
      _showErrorDialog('Please enter current password');
      return false;
    }

    // Password fields are optional, but if filled, must be valid
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (newPassword.isNotEmpty || confirmPassword.isNotEmpty) {
      // If either password field is filled, both must be filled
      if (newPassword.isEmpty) {
        _showPasswordUpdateErrorModal('Please enter new password');
        return false;
      }
      if (confirmPassword.isEmpty) {
        _showPasswordUpdateErrorModal('Please confirm new password');
        return false;
      }
      if (newPassword != confirmPassword) {
        _showPasswordUpdateErrorModal('Passwords do not match');
        return false;
      }
      if (newPassword.length < 6) {
        _showPasswordUpdateErrorModal('Password must be at least 6 characters');
        return false;
      }
    }

    return true;
  }

  void _clearForm() {
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    // Don't clear username and email - keep them for display
  }

  Future<void> _showChangeEmailDialog() async {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController newEmailController = TextEditingController();
    bool isUpdatingEmail = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.email, color: evsuRed),
                  SizedBox(width: isMobile ? 8 : 12),
                  Expanded(
                    child: Text(
                      'Change Email Address',
                      style: TextStyle(fontSize: isMobile ? 18 : 20),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      isMobile ? MediaQuery.of(context).size.width * 0.9 : 500,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter your admin password and new email address:',
                        style: TextStyle(fontSize: isMobile ? 13 : 14),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Admin Password',
                          prefixIcon: const Icon(Icons.lock, color: evsuRed),
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
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: newEmailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'New Email Address',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
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
                        ),
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
                                'After changing email, you will need to verify the new email address.',
                                style: TextStyle(
                                  fontSize: isMobile ? 11 : 12,
                                  color: Colors.blue.shade900,
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
              actions: [
                TextButton(
                  onPressed:
                      isUpdatingEmail ? null : () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(fontSize: isMobile ? 14 : 16),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      isUpdatingEmail
                          ? null
                          : () async {
                            final password = passwordController.text.trim();
                            final newEmail = newEmailController.text.trim();

                            if (password.isEmpty) {
                              _showErrorDialog(
                                'Please enter your admin password',
                              );
                              return;
                            }
                            if (newEmail.isEmpty) {
                              _showErrorDialog(
                                'Please enter new email address',
                              );
                              return;
                            }
                            if (!RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            ).hasMatch(newEmail)) {
                              _showErrorDialog(
                                'Please enter a valid email address',
                              );
                              return;
                            }

                            setDialogState(() {
                              isUpdatingEmail = true;
                            });

                            try {
                              // Get current admin info
                              final adminData =
                                  await SupabaseService.getCurrentAdminInfo();
                              final currentUsername =
                                  adminData['success'] == true &&
                                          adminData['data'] != null
                                      ? adminData['data']['username']
                                              ?.toString() ??
                                          _currentUsernameController.text.trim()
                                      : _currentUsernameController.text.trim();
                              final currentFullName =
                                  adminData['success'] == true &&
                                          adminData['data'] != null
                                      ? adminData['data']['full_name']
                                              ?.toString() ??
                                          ''
                                      : '';

                              final result =
                                  await SupabaseService.updateAdminCredentials(
                                    currentUsername: currentUsername,
                                    currentPassword: password,
                                    newUsername:
                                        currentUsername, // Keep same username
                                    newPassword: '', // Don't change password
                                    newFullName:
                                        currentFullName, // Keep same full name
                                    newEmail: newEmail,
                                  );

                              if (!context.mounted) return;

                              if (result['success']) {
                                Navigator.pop(context);
                                _showSuccessDialog(
                                  'Email address updated successfully! Please verify your new email address.',
                                );
                                // Reload admin profile
                                await _loadAdminProfileSummary(silent: true);
                                // Reset email verification status
                                setState(() {
                                  _adminEmailVerified = false;
                                });
                              } else {
                                setDialogState(() {
                                  isUpdatingEmail = false;
                                });
                                _showErrorDialog(
                                  result['message'] ??
                                      'Failed to update email address',
                                );
                              }
                            } catch (e) {
                              if (!context.mounted) return;
                              setDialogState(() {
                                isUpdatingEmail = false;
                              });
                              _showErrorDialog('Error updating email: $e');
                            }
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: evsuRed,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 16 : 20,
                      vertical: isMobile ? 10 : 12,
                    ),
                  ),
                  child:
                      isUpdatingEmail
                          ? SizedBox(
                            width: isMobile ? 16 : 20,
                            height: isMobile ? 16 : 20,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            'Update Email',
                            style: TextStyle(fontSize: isMobile ? 14 : 16),
                          ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSuccessDialog(String message) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: isMobile ? 24 : 28,
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    'Success',
                    style: TextStyle(fontSize: isMobile ? 18 : 20),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    isMobile ? MediaQuery.of(context).size.width * 0.8 : 400,
              ),
              child: Text(
                message,
                style: TextStyle(fontSize: isMobile ? 14 : 16),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              ),
            ],
          ),
    );
  }

  /// Get user-friendly error message from exception
  String _getUserFriendlyErrorMessage(dynamic error) {
    // Check for SocketException (no internet connection)
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Convert error to string for pattern matching
    final errorString = error.toString().toLowerCase();

    // Check for ClientException with SocketException (common network error pattern)
    if (errorString.contains('clientexception') &&
        (errorString.contains('socketexception') ||
            errorString.contains('failed host lookup') ||
            errorString.contains('failed host') ||
            errorString.contains('network is unreachable'))) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Check for SocketException patterns in error string
    if (errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('failed host') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('no internet') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timed out')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Check for timeout errors
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return 'Request timed out. Please check your connection and try again.';
    }

    // Check for ClientException (general network errors)
    if (errorString.contains('clientexception')) {
      return 'Network error. Please check your connection and try again.';
    }

    // Check for Supabase-specific errors
    if (errorString.contains('postgres') || errorString.contains('database')) {
      return 'Database error. Please try again later.';
    }

    // Default error message
    return 'An error occurred. Please try again.';
  }

  void _showErrorDialog(String message) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: isMobile ? 24 : 28),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    'Error',
                    style: TextStyle(fontSize: isMobile ? 18 : 20),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    isMobile ? MediaQuery.of(context).size.width * 0.8 : 400,
              ),
              child: SingleChildScrollView(
                child: Text(
                  message,
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              ),
            ],
          ),
    );
  }

  void _showPasswordUpdateErrorModal(String errorMessage) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Simplify error messages
    String simpleMessage = 'Failed to update password';
    final errorLower = errorMessage.toLowerCase();

    if (errorLower.contains('password') && errorLower.contains('6')) {
      simpleMessage = 'Password must be at least 6 characters';
    } else if (errorLower.contains('password') &&
        errorLower.contains('match')) {
      simpleMessage = 'Passwords do not match';
    } else if (errorLower.contains('password') &&
        errorLower.contains('empty')) {
      simpleMessage = 'Please enter a new password';
    } else if (errorLower.contains('invalid') &&
        errorLower.contains('password')) {
      simpleMessage = 'Current password is incorrect';
    } else if (errorLower.contains('failed to update')) {
      // Extract the actual error message after "Failed to update password: "
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
            title: Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: isMobile ? 24 : 28,
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    'Failed to Update Password',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              simpleMessage,
              style: TextStyle(fontSize: isMobile ? 14 : 16),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: evsuRed,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 24,
                    vertical: isMobile ? 10 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'OK',
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              ),
            ],
          ),
    );
  }

  Widget _buildFunctionCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return InkWell(
      onTap: isDisabled ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: isDisabled ? 0.5 : 1.0,
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
            border: Border.all(
              color: isDisabled ? Colors.grey.shade300 : Colors.grey.shade200,
            ),
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
                        colors: [
                          isDisabled ? Colors.grey : color,
                          (isDisabled ? Colors.grey : color).withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: Colors.white, size: 24),
                  ),
                  const Spacer(),
                  if (isDisabled)
                    Icon(Icons.lock, color: Colors.orange.shade700, size: 18)
                  else
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
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDisabled ? Colors.grey.shade600 : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color:
                      isDisabled
                          ? Colors.orange.shade700
                          : Colors.grey.shade600,
                  height: 1.4,
                  fontWeight: isDisabled ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reset Database Screen
  Widget _buildResetDatabase() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    if (!_maintenanceModeEnabled) {
      return _buildMaintenanceRequirementCard(
        isMobile: isMobile,
        isTablet: isTablet,
        title: 'Reset Database',
        icon: Icons.delete_forever,
        message:
            'Resetting the database is only allowed while System Maintenance Mode is enabled. Turn it on to ensure no users can access the app during this destructive action.',
      );
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : (isTablet ? 20 : 24)),
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
          // Header with back button
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedFunction = -1),
                icon: const Icon(Icons.arrow_back, color: evsuRed),
                iconSize: isMobile ? 20 : 24,
              ),
              SizedBox(width: isMobile ? 4 : 8),
              Icon(Icons.warning, color: Colors.red, size: isMobile ? 24 : 28),
              SizedBox(width: isMobile ? 4 : 8),
              Expanded(
                child: Text(
                  'Reset Database',
                  style: TextStyle(
                    fontSize: isMobile ? 20 : (isTablet ? 22 : 24),
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 4 : 8),
          Text(
            'DANGER ZONE: This action is irreversible',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: isMobile ? 20 : 30),

          // Warning Banner
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red.shade300,
                width: isMobile ? 1 : 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: isMobile ? 24 : 28,
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Expanded(
                      child: Text(
                        'WARNING: Critical Operation',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : (isTablet ? 17 : 18),
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Text(
                  _resetMode == ResetMode.full
                      ? 'This action will permanently delete ALL data from the following tables:'
                      : 'This action will permanently delete data from the following tables. Student accounts and service accounts will be preserved, but balances will be reset to ₱0.00:',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade900,
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 12),
                _buildTableList(isMobile, isTablet),
                SizedBox(height: isMobile ? 12 : 16),
                Text(
                  _resetMode == ResetMode.full
                      ? 'All auto-increment IDs will be reset to 1.'
                      : 'All auto-increment IDs will be reset to 1 (except auth_students and service_accounts).',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade900,
                  ),
                ),
                SizedBox(height: isMobile ? 6 : 8),
                Text(
                  'This operation CANNOT be undone. Consider backing up your data before proceeding.',
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red.shade900,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 20 : 30),

          // Reset Mode Selector
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reset Mode',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: isMobile ? 10 : 12),
                SegmentedButton<ResetMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment<ResetMode>(
                      value: ResetMode.full,
                      label: Text('Full Reset'),
                      icon: Icon(Icons.delete_sweep_outlined),
                    ),
                    ButtonSegment<ResetMode>(
                      value: ResetMode.preserveStudents,
                      label: Text('Preserve Students'),
                      icon: Icon(Icons.people_outline),
                    ),
                  ],
                  selected: {_resetMode},
                  onSelectionChanged:
                      _isResetting
                          ? null
                          : (selection) {
                            setState(() {
                              _resetMode = selection.first;
                            });
                          },
                ),
                SizedBox(height: isMobile ? 12 : 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child:
                      _resetMode == ResetMode.full
                          ? Container(
                            key: const ValueKey('full'),
                            padding: EdgeInsets.all(isMobile ? 10 : 12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.red.shade700,
                                  size: isMobile ? 18 : 20,
                                ),
                                SizedBox(width: isMobile ? 8 : 10),
                                Expanded(
                                  child: Text(
                                    'Full Reset: Deletes ALL data from ALL tables including student accounts. All IDs will be reset to 1.',
                                    style: TextStyle(
                                      fontSize: isMobile ? 12 : 13,
                                      color: Colors.red.shade900,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                          : Container(
                            key: const ValueKey('preserve'),
                            padding: EdgeInsets.all(isMobile ? 10 : 12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade700,
                                  size: isMobile ? 18 : 20,
                                ),
                                SizedBox(width: isMobile ? 8 : 10),
                                Expanded(
                                  child: Text(
                                    'Preserve Students/Services: Deletes data from all tables EXCEPT auth_students and service_accounts. Student accounts and service accounts login credentials are preserved, but balances are reset to ₱0.00. All transaction history and other data will be deleted.',
                                    style: TextStyle(
                                      fontSize: isMobile ? 12 : 13,
                                      color: Colors.blue.shade900,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 20 : 30),

          // Backup Reminder
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.backup,
                  color: Colors.amber.shade700,
                  size: isMobile ? 20 : 24,
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Text(
                    'NOTE: An automatic backup will be created before resetting the database. This ensures you can recover data if needed.',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isMobile ? 20 : 30),

          // Reset Database Button
          SizedBox(
            width: double.infinity,
            height: isMobile ? 45 : (isTablet ? 48 : 50),
            child: ElevatedButton(
              onPressed: _isResetting ? null : _showResetConfirmationDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child:
                  _isResetting
                      ? SizedBox(
                        width: isMobile ? 18 : 20,
                        height: isMobile ? 18 : 20,
                        child: const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                      : Text(
                        'Reset Database',
                        style: TextStyle(
                          fontSize: isMobile ? 14 : (isTablet ? 15 : 16),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableList(bool isMobile, bool isTablet) {
    final tables = [
      'loan_payments',
      'service_transactions',
      'transaction_csu',
      'top_up_transactions',
      'user_transfers',
      'withdrawal_transactions',
      'service_withdrawal_requests',
      'withdrawal_requests',
      'payment_items',
      'loan_applications',
      'active_loans',
      'auth_students',
      'service_accounts',
      'top_up_requests',
      'feedback',
      'id_replacement',
      'read_inbox',
      'user_notifications',
      // Note: service_hierarchy is a VIEW (not a table) - will be empty after deleting service_accounts
      // Note: top_up_transaction_summary is a VIEW (not a table) - will be empty after deleting top_up_transactions
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            tables
                .map(
                  (table) => Padding(
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 3 : 4),
                    child: Row(
                      children: [
                        Icon(
                          Icons.table_chart,
                          size: isMobile ? 14 : 16,
                          color: Colors.red.shade700,
                        ),
                        SizedBox(width: isMobile ? 6 : 8),
                        Expanded(
                          child: Text(
                            table,
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 13,
                              fontFamily: 'monospace',
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Future<void> _showResetConfirmationDialog() async {
    _confirmPasswordController2.clear();
    int cooldownSeconds = 5;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Start countdown timer if not already started
            if (cooldownSeconds == 5) {
              _startCooldownTimerForDialog(setDialogState, (newValue) {
                cooldownSeconds = newValue;
              }, cooldownSeconds);
            }

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning, color: Colors.red.shade700, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Confirm Reset Database',
                      style: TextStyle(
                        fontSize:
                            MediaQuery.of(context).size.width < 600 ? 18 : 20,
                      ),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth:
                      MediaQuery.of(context).size.width < 600
                          ? MediaQuery.of(context).size.width * 0.9
                          : 500,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _resetMode == ResetMode.full
                            ? 'This will permanently delete ALL data from ALL system tables and reset their IDs. This action CANNOT be undone.'
                            : 'This will delete data from all tables EXCEPT auth_students and service_accounts. Student accounts and service accounts login credentials will be preserved, but balances will be reset to ₱0.00. All transaction history and other data will be deleted. This action CANNOT be undone.',
                        style: TextStyle(
                          fontSize:
                              MediaQuery.of(context).size.width < 600 ? 13 : 14,
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'For security, please enter your admin password to confirm:',
                        style: TextStyle(
                          fontSize:
                              MediaQuery.of(context).size.width < 600 ? 13 : 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController2,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Admin Password',
                          labelStyle: TextStyle(
                            fontSize:
                                MediaQuery.of(context).size.width < 600
                                    ? 13
                                    : 14,
                          ),
                          prefixIcon: const Icon(Icons.lock, color: evsuRed),
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
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical:
                                MediaQuery.of(context).size.width < 600
                                    ? 12
                                    : 16,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (cooldownSeconds > 0)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.orange.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.timer,
                                color: Colors.orange.shade700,
                                size:
                                    MediaQuery.of(context).size.width < 600
                                        ? 20
                                        : 24,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Please wait $cooldownSeconds seconds before confirming...',
                                  style: TextStyle(
                                    fontSize:
                                        MediaQuery.of(context).size.width < 600
                                            ? 12
                                            : 13,
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.w500,
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
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width < 600 ? 13 : 14,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      cooldownSeconds > 0
                          ? null
                          : () {
                            Navigator.of(context).pop();
                            _showFinalConfirmationDialog();
                          },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          MediaQuery.of(context).size.width < 600 ? 16 : 20,
                      vertical:
                          MediaQuery.of(context).size.width < 600 ? 10 : 12,
                    ),
                  ),
                  child: Text(
                    'Confirm Reset',
                    style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width < 600 ? 13 : 14,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _startCooldownTimerForDialog(
    StateSetter setDialogState,
    Function(int) updateCooldown,
    int currentSeconds,
  ) {
    if (currentSeconds > 0) {
      Future.delayed(const Duration(seconds: 1), () {
        final newSeconds = currentSeconds - 1;
        setDialogState(() {
          updateCooldown(newSeconds);
        });

        if (newSeconds > 0) {
          _startCooldownTimerForDialog(
            setDialogState,
            updateCooldown,
            newSeconds,
          );
        }
      });
    }
  }

  Future<void> _showFinalConfirmationDialog() async {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Colors.red.shade700,
                size: isMobile ? 24 : 28,
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: Text(
                  'Final Confirmation',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  isMobile ? MediaQuery.of(context).size.width * 0.9 : 500,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red.shade700,
                          size: isMobile ? 28 : 32,
                        ),
                        SizedBox(width: isMobile ? 8 : 12),
                        Expanded(
                          child: Text(
                            'ARE YOU ABSOLUTELY SURE?',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 20),
                  Text(
                    'This is your LAST chance to cancel. Once you proceed:',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  ...List.generate(4, (index) {
                    final warnings = [
                      'ALL data will be PERMANENTLY deleted',
                      'This action CANNOT be undone',
                      'No backup will be created automatically',
                      'The system will be reset to a clean state',
                    ];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == 3 ? 0 : (isMobile ? 8 : 10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.close,
                            color: Colors.red.shade700,
                            size: isMobile ? 18 : 20,
                          ),
                          SizedBox(width: isMobile ? 8 : 10),
                          Expanded(
                            child: Text(
                              warnings[index],
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showAreYouSureDialog();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 20,
                  vertical: isMobile ? 10 : 12,
                ),
              ),
              child: Text(
                'YES, RESET NOW',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAreYouSureDialog() async {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: isMobile ? 24 : 28,
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: Text(
                  'Are You Sure?',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  isMobile ? MediaQuery.of(context).size.width * 0.9 : 500,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: isMobile ? 24 : 28,
                        ),
                        SizedBox(width: isMobile ? 8 : 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'This is your LAST chance to cancel!',
                                style: TextStyle(
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red.shade900,
                                ),
                              ),
                              SizedBox(height: isMobile ? 8 : 10),
                              Text(
                                _resetMode == ResetMode.full
                                    ? 'Once you proceed, ALL data will be PERMANENTLY deleted from ALL tables. This action CANNOT be undone.'
                                    : 'Once you proceed, all data will be deleted except student accounts and service accounts. Student accounts and service accounts login credentials will be preserved, but balances will be reset to ₱0.00. All transaction history and other data will be deleted. This action CANNOT be undone.',
                                style: TextStyle(
                                  fontSize: isMobile ? 13 : 14,
                                  color: Colors.red.shade900,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 20),
                  Text(
                    'Please take a moment to reconsider:',
                    style: TextStyle(
                      fontSize: isMobile ? 13 : 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: isMobile ? 12 : 16),
                  ...List.generate(3, (index) {
                    final warnings = [
                      'Have you backed up your data?',
                      'Are you certain you want to proceed?',
                      'This will affect all system data.',
                    ];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: index == 2 ? 0 : (isMobile ? 8 : 10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.help_outline,
                            color: Colors.orange.shade700,
                            size: isMobile ? 18 : 20,
                          ),
                          SizedBox(width: isMobile ? 8 : 10),
                          Expanded(
                            child: Text(
                              warnings[index],
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 14,
                                color: Colors.black87,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 20,
                  vertical: isMobile ? 10 : 12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: isMobile ? 18 : 20),
                  SizedBox(width: isMobile ? 4 : 6),
                  Text(
                    'Rethink',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _performDatabaseReset();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 20,
                  vertical: isMobile ? 10 : 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete_forever, size: isMobile ? 18 : 20),
                  SizedBox(width: isMobile ? 4 : 6),
                  Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<String?> _performAutomaticBackup() async {
    // Perform backup automatically before reset (both full and preserve students modes)
    // This function is called from a dialog, so we don't update parent widget state
    // to avoid setState() during build errors

    if (_isBackingUpTables) return null;

    // Set flag without setState to prevent concurrent backups
    _isBackingUpTables = true;

    try {
      final Map<String, List<int>> csvFiles = {};

      for (final status in _backupTableStatuses) {
        final result = await SupabaseService.fetchTableDump(
          tableName: status.tableName,
        );

        if (result['success'] == true) {
          final rows =
              (result['data'] as List<dynamic>? ?? [])
                  .map<Map<String, dynamic>>(
                    (row) => Map<String, dynamic>.from(row as Map),
                  )
                  .toList();
          final columns =
              (result['columns'] as List<dynamic>? ?? [])
                  .map((col) => col.toString())
                  .toList();

          final payload = _createCsvBytes(columns, rows);
          csvFiles['${status.tableName}.csv'] = payload.bytes;
        } else {
          final errorMessage =
              result['message']?.toString() ??
              result['error']?.toString() ??
              'Unknown error';

          final payload = _createCsvBytes(
            ['error'],
            [
              {'error': errorMessage},
            ],
          );
          csvFiles['${status.tableName}.csv'] = payload.bytes;
        }
      }

      if (csvFiles.isEmpty) {
        throw Exception('No tables were exported. Please check the logs.');
      }

      final archiveBytes = _buildZipArchive(csvFiles);
      final savedPath = await _persistBackupArchive(
        archiveBytes,
        _buildBackupFileName(),
      );

      return savedPath;
    } catch (e) {
      rethrow;
    } finally {
      // Reset flag without setState
      _isBackingUpTables = false;
    }
  }

  Future<void> _performDatabaseReset() async {
    // Validate password
    if (_confirmPasswordController2.text.trim().isEmpty) {
      _showErrorDialog('Please enter your admin password to confirm.');
      return;
    }

    // Perform automatic backup first for both reset modes
    // Show backup progress dialog
    final backupResult = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _BackupProgressDialog(performBackup: _performAutomaticBackup);
      },
    );

    if (backupResult == null || backupResult.isEmpty) {
      // Backup failed or was cancelled
      if (mounted) {
        _showErrorDialog(
          'Backup failed. Reset operation cancelled for safety. Please try backing up manually first.',
        );
      }
      return;
    }

    // Backup completed successfully
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup completed: $backupResult'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    setState(() {
      _isResetting = true;
    });

    try {
      print('=== DEBUG: Reset Database Started ===');
      print(
        'DEBUG: Password entered: ${_confirmPasswordController2.text.trim()}',
      );

      // Check if current user has admin role (not moderator/staff)
      final currentRole = SessionService.adminRole;
      print('DEBUG: Current user role: $currentRole');

      if (currentRole != 'admin') {
        _showErrorDialog(
          'Access Denied: Only users with role="admin" can reset the database.\n\n'
          'Your current role: ${currentRole.toUpperCase()}\n'
          'Please contact an administrator to perform this operation.',
        );
        return;
      }

      // Get admin account with role='admin' for password verification
      print('DEBUG: Fetching admin account with role=admin...');
      final adminData = await SupabaseService.getAdminAccountForReset();

      print('DEBUG: Admin data response: ${adminData['success']}');
      if (adminData['success']) {
        print(
          'DEBUG: Admin username from DB: ${adminData['data']['username']}',
        );
        print('DEBUG: Admin role: ${adminData['data']['role']}');
        print('DEBUG: Admin data keys: ${adminData['data'].keys.toList()}');
      } else {
        print('DEBUG: Failed to get admin data: ${adminData['message']}');
        print('DEBUG: Error: ${adminData['error']}');
      }

      if (!adminData['success']) {
        _showErrorDialog(
          'Failed to verify admin credentials.\nError: ${adminData['message']}',
        );
        return;
      }

      // Verify the admin account has role='admin'
      final adminRole =
          adminData['data']['role']?.toString().toLowerCase() ?? '';
      if (adminRole != 'admin') {
        _showErrorDialog(
          'Access Denied: Only accounts with role="admin" can reset the database.\n\n'
          'The account "${adminData['data']['username']}" has role: ${adminRole.toUpperCase()}',
        );
        return;
      }

      // Call the reset database function with password verification
      print('DEBUG: Calling resetDatabase with:');
      print('  - username: ${adminData['data']['username']}');
      print('  - role: ${adminData['data']['role']}');
      print(
        '  - password length: ${_confirmPasswordController2.text.trim().length}',
      );

      final result =
          _resetMode == ResetMode.full
              ? await SupabaseService.resetDatabase(
                adminPassword: _confirmPasswordController2.text.trim(),
                adminUsername: adminData['data']['username'],
              )
              : await SupabaseService.resetDatabasePreserveStudents(
                adminPassword: _confirmPasswordController2.text.trim(),
                adminUsername: adminData['data']['username'],
              );

      print('DEBUG: Reset result: ${result['success']}');
      print('DEBUG: Reset message: ${result['message']}');
      if (!result['success']) {
        print('DEBUG: Reset error: ${result['error']}');
      }
      print('=== DEBUG: Reset Database Completed ===');

      if (result['success']) {
        _showSuccessDialog(
          _resetMode == ResetMode.full
              ? 'Database has been successfully reset. All data has been deleted and IDs have been reset.'
              : 'Database reset completed. Student accounts and service accounts have been preserved. Student and service account balances have been reset to ₱0.00. All transaction history and other data have been deleted.',
        );
        _confirmPasswordController2.clear();
      } else {
        _showErrorDialog(
          result['message'] ?? 'Failed to reset database. Please try again.',
        );
      }
    } catch (e) {
      print('DEBUG: Exception caught: $e');
      print('DEBUG: Exception type: ${e.runtimeType}');
      _showErrorDialog('Error resetting database: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isResetting = false;
        });
      }
    }
  }

  Future<void> _loadMaintenanceModeStatus() async {
    try {
      final resp = await SupabaseService.getSystemUpdateSettings();
      final settings = resp['data'] ?? {};
      if (mounted) {
        setState(() {
          _maintenanceModeEnabled = settings['maintenance_mode'] == true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _maintenanceModeEnabled = false;
        });
      }
    }
  }

  Future<void> _subscribeToMaintenanceStream() async {
    try {
      await SupabaseService.initialize();
      _maintenanceSubscription?.cancel();
      _maintenanceSubscription = SupabaseService.client
          .from('system_update_settings')
          .stream(primaryKey: ['id'])
          .limit(1)
          .listen((event) {
            if (event.isEmpty) return;
            final row = event.first;
            final enabled = row['maintenance_mode'] == true;
            if (!mounted) {
              _maintenanceModeEnabled = enabled;
              return;
            }
            if (_maintenanceModeEnabled != enabled) {
              setState(() {
                _maintenanceModeEnabled = enabled;
              });
            }
          });
    } catch (_) {
      // Ignore streaming errors; manual refresh will still work.
    }
  }

  Future<void> _loadAdminProfileSummary({bool silent = false}) async {
    final resp = await SupabaseService.getCurrentAdminInfo();
    if (!mounted) return;
    if (resp['success'] == true && resp['data'] != null) {
      final data = Map<String, dynamic>.from(resp['data']);
      setState(() {
        _storedAdminUsername = data['username']?.toString();
        _adminEmailVerified = data['email_verified'] == true;
        _supabaseAdminUserId = data['supabase_uid']?.toString();
      });
      if (!_adminProfileLoaded) {
        setState(() {
          _adminProfileLoaded = true;
          _currentUsernameController.text = data['username']?.toString() ?? '';
          _newFullNameController.text = data['full_name']?.toString() ?? '';
          _newEmailController.text = data['email']?.toString() ?? '';
        });
      }
    } else if (!silent) {
      _showErrorDialog(resp['message'] ?? 'Failed to load admin profile.');
    }
  }

  void _showMaintenanceModeDialog() {
    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.build_circle,
                  color: Colors.orange.shade700,
                  size: isMobile ? 24 : 28,
                ),
                SizedBox(width: isMobile ? 8 : 12),
                Expanded(
                  child: Text(
                    'Maintenance Mode Active',
                    style: TextStyle(fontSize: isMobile ? 18 : 20),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth:
                    isMobile ? MediaQuery.of(context).size.width * 0.8 : 400,
              ),
              child: Text(
                'This feature requires System Maintenance Mode to be turned on. Please enable maintenance mode in System Updates & Maintenance settings before continuing.',
                style: TextStyle(fontSize: isMobile ? 14 : 16),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SystemUpdateScreen(),
                    ),
                  );
                  // Refresh maintenance mode status when returning
                  _loadMaintenanceModeStatus();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: evsuRed,
                  foregroundColor: Colors.white,
                ),
                child: Text(
                  'Go to Settings',
                  style: TextStyle(fontSize: isMobile ? 14 : 16),
                ),
              ),
            ],
          ),
    );
  }
}

class _BackupTableStatus {
  _BackupTableStatus({required this.tableName});

  final String tableName;
  String status = 'Pending';
  int rowCount = 0;
  int columnCount = 0;
  String? errorMessage;

  void markProcessing() {
    status = 'Processing';
    errorMessage = null;
  }

  void markSuccess(int rows, int columns) {
    status = 'Completed';
    rowCount = rows;
    columnCount = columns;
    errorMessage = null;
  }

  void markFailed(String message) {
    status = 'Failed';
    rowCount = 0;
    columnCount = 0;
    errorMessage = message;
  }

  void reset() {
    status = 'Pending';
    rowCount = 0;
    columnCount = 0;
    errorMessage = null;
  }
}

class _RecoveryTableStatus {
  _RecoveryTableStatus({required this.tableName});

  final String tableName;
  String statusLabel = 'Pending';
  int csvRowCount = 0;
  int insertedRows = 0;
  int skippedRows = 0;
  String? fileName;
  String? message;
  bool hasError = false;

  void markReady(int rows, {String? fileName}) {
    statusLabel = 'Ready';
    csvRowCount = rows;
    insertedRows = 0;
    skippedRows = 0;
    hasError = false;
    message = null;
    this.fileName = fileName;
  }

  void markMissing(String note) {
    statusLabel = 'Missing File';
    csvRowCount = 0;
    insertedRows = 0;
    skippedRows = 0;
    hasError = true;
    message = note;
  }

  void markSchemaIssue(String note) {
    statusLabel = 'Schema mismatch';
    csvRowCount = 0;
    insertedRows = 0;
    skippedRows = 0;
    hasError = true;
    message = note;
  }

  void markProcessing() {
    statusLabel = 'Processing';
    hasError = false;
    message = null;
  }

  void markCompleted(int inserted, int skipped) {
    statusLabel = 'Completed';
    insertedRows = inserted;
    skippedRows = skipped;
    hasError = false;
    message = null;
  }

  void markFailed(String note) {
    statusLabel = 'Failed';
    hasError = true;
    message = note;
  }

  void reset() {
    statusLabel = 'Pending';
    csvRowCount = 0;
    insertedRows = 0;
    skippedRows = 0;
    hasError = false;
    message = null;
    fileName = null;
  }
}

class _RecoveryCsvPayload {
  _RecoveryCsvPayload({
    required this.tableName,
    required this.fileName,
    required this.filePath,
    required this.headers,
    required this.rows,
  });

  final String tableName;
  final String fileName;
  final String filePath;
  final List<String> headers;
  final List<Map<String, dynamic>> rows;
}

class _SchemaValidationResult {
  const _SchemaValidationResult({required this.success, this.message});

  final bool success;
  final String? message;
}

class _RecoveryValidationResult {
  const _RecoveryValidationResult({
    required this.title,
    required this.detail,
    required this.isError,
  });

  final String title;
  final String detail;
  final bool isError;
}

class _TableRestoreOutcome {
  const _TableRestoreOutcome({
    required this.insertedRows,
    required this.skippedRows,
  });

  final int insertedRows;
  final int skippedRows;
}

enum _RecoveryMode { full, append }

enum ResetMode { full, preserveStudents }

class _RecoveryForeignKey {
  const _RecoveryForeignKey({
    required this.childTable,
    required this.childColumn,
    required this.parentTable,
    required this.parentColumn,
  });

  final String childTable;
  final String childColumn;
  final String parentTable;
  final String parentColumn;
}

class _BackupProgressDialog extends StatefulWidget {
  final Future<String?> Function() performBackup;

  const _BackupProgressDialog({required this.performBackup});

  @override
  State<_BackupProgressDialog> createState() => _BackupProgressDialogState();
}

class _BackupProgressDialogState extends State<_BackupProgressDialog> {
  bool _isBackingUp = true;
  String? _backupPath;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startBackup();
  }

  Future<void> _startBackup() async {
    try {
      final savedPath = await widget.performBackup();
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _backupPath = savedPath;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            Icons.backup,
            color: Colors.blue.shade700,
            size: isMobile ? 24 : 28,
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Text(
              'Creating Backup',
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isMobile ? MediaQuery.of(context).size.width * 0.9 : 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isBackingUp) ...[
              Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    SizedBox(height: isMobile ? 16 : 20),
                    Text(
                      'Backing up database before reset...',
                      style: TextStyle(
                        fontSize: isMobile ? 13 : 14,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isMobile ? 8 : 10),
                    Text(
                      'Please wait, this may take a few moments.',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else if (_errorMessage != null) ...[
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade700,
                      size: isMobile ? 20 : 24,
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Expanded(
                      child: Text(
                        'Backup failed: $_errorMessage',
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          color: Colors.red.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: isMobile ? 20 : 24,
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Expanded(
                      child: Text(
                        'Backup completed successfully!',
                        style: TextStyle(
                          fontSize: isMobile ? 13 : 14,
                          color: Colors.green.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions:
          _errorMessage != null
              ? [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: Text(
                    'Cancel Reset',
                    style: TextStyle(fontSize: isMobile ? 14 : 16),
                  ),
                ),
              ]
              : _isBackingUp
              ? []
              : [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_backupPath ?? ''),
                  child: Text(
                    'Continue',
                    style: TextStyle(fontSize: isMobile ? 14 : 16),
                  ),
                ),
              ],
    );
  }
}
