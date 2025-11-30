import 'package:flutter/material.dart';
import 'dashboard_tab.dart';
import 'reports_tab.dart';
import 'transactions_tab.dart';
import 'topup_tab.dart';
import 'user_management_tab.dart';
import 'vendors_tab.dart';
import 'settings_tab.dart';
import 'loaning_tab.dart';
import 'feedback_tab.dart';
import 'withdrawal_requests_tab.dart';
import 'admin_management_tab.dart';
import '../login_page.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import '../user/user_dashboard.dart';
import '../services_school/service_dashboard.dart';
import '../services/admin_notification_service.dart';

class AdminDashboard extends StatefulWidget {
  final int? initialTabIndex;
  final bool? navigateToServiceRegistration;

  const AdminDashboard({
    super.key,
    this.initialTabIndex,
    this.navigateToServiceRegistration,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const Color evsuRed = Color(0xFFB91C1C);
  static const Color evsuRedDark = Color(0xFF7F1D1D);
  int _currentIndex = 0;
  bool _isSidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final List<Widget> _tabs;
  int? _settingsInitialFunction;

  // Staff permissions
  Map<String, bool> _staffPermissions = {};
  bool _isLoadingPermissions = false;

  final List<NavigationItem> _navigationItems = [
    NavigationItem(
      icon: Icons.dashboard,
      activeIcon: Icons.dashboard,
      label: 'Dashboard',
      id: 'dashboard',
    ),
    NavigationItem(
      icon: Icons.analytics_outlined,
      activeIcon: Icons.analytics,
      label: 'Reports',
      id: 'reports',
    ),
    NavigationItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      label: 'Transactions',
      id: 'transactions',
    ),
    NavigationItem(
      icon: Icons.add_card_outlined,
      activeIcon: Icons.add_card,
      label: 'Top-Up',
      id: 'topup',
    ),
    NavigationItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet,
      label: 'Withdrawal Requests',
      id: 'withdrawal_requests',
    ),
    NavigationItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'Settings',
      id: 'settings',
    ),
    NavigationItem(
      icon: Icons.people_outline,
      activeIcon: Icons.people,
      label: 'User Management',
      id: 'users',
    ),
    NavigationItem(
      icon: Icons.store_outlined,
      activeIcon: Icons.store,
      label: 'Service Ports',
      id: 'vendors',
    ),
    NavigationItem(
      icon: Icons.admin_panel_settings_outlined,
      activeIcon: Icons.admin_panel_settings,
      label: 'Admin Management',
      id: 'admin_management',
    ),
    NavigationItem(
      icon: Icons.account_balance_outlined,
      activeIcon: Icons.account_balance,
      label: 'Loaning',
      id: 'loaning',
    ),
    NavigationItem(
      icon: Icons.feedback_outlined,
      activeIcon: Icons.feedback,
      label: 'Feedback',
      id: 'feedback',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkSession();

    // Set initial tab index if provided
    if (widget.initialTabIndex != null) {
      _currentIndex = widget.initialTabIndex!;
    }

    // Load permissions for staff and initialize tabs
    if (SessionService.isAdminStaff) {
      _loadStaffPermissions().then((_) {
        _initializeTabs();
      });
    } else {
      // Full admin sees all tabs - no permission check needed
      _initializeTabs();
    }

    // Initialize admin notifications when dashboard opens
    _initializeAdminNotifications();
  }

  Future<void> _loadStaffPermissions() async {
    if (!SessionService.isAdminStaff) return;

    setState(() {
      _isLoadingPermissions = true;
    });

    try {
      // Get current admin ID from session
      final currentUserData = SessionService.currentUserData;
      if (currentUserData == null) {
        print('ERROR: No current user data found');
        return;
      }

      final adminId = currentUserData['id'];
      if (adminId == null) {
        print(
          'ERROR: No admin ID found in session data. Session data: $currentUserData',
        );
        // Try to get admin ID from username if id is missing
        final username =
            currentUserData['student_id'] ?? currentUserData['username'];
        if (username != null) {
          try {
            // Query admin_accounts to get ID
            final adminResponse =
                await SupabaseService.client
                    .from('admin_accounts')
                    .select('id')
                    .eq('username', username)
                    .maybeSingle();

            if (adminResponse != null && adminResponse['id'] != null) {
              final fetchedId = adminResponse['id'];
              print('DEBUG: Fetched admin ID from database: $fetchedId');
              // Load permissions with fetched ID
              await _loadPermissionsForAdminId(fetchedId);
              return;
            }
          } catch (e) {
            print('ERROR: Failed to fetch admin ID: $e');
          }
        }
        return;
      }

      // Load permissions from database
      await _loadPermissionsForAdminId(adminId);
    } catch (e) {
      print('Error loading staff permissions: $e');
      // Default to all false on error
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

  Future<void> _loadPermissionsForAdminId(dynamic adminId) async {
    try {
      // Convert adminId to int if needed
      final int staffId =
          adminId is int ? adminId : (int.tryParse(adminId.toString()) ?? 0);

      if (staffId == 0) {
        print('ERROR: Invalid admin ID: $adminId');
        return;
      }

      // Load permissions from database
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
        print(
          'DEBUG: Loaded permissions for staff ID $staffId: $_staffPermissions',
        );
      } else {
        // No permissions found - default to all false
        print('WARNING: No permissions found for staff ID $staffId');
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
      print('ERROR: Failed to load permissions for admin ID $adminId: $e');
      // Default to all false on error
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
  }

  void _initializeTabs() {
    if (SessionService.isAdminStaff) {
      // Build tabs based on permissions
      final List<Widget> allowedTabs = [];
      final List<int> tabMapping =
          []; // Maps staff tab index to original tab index

      // Map permission keys to tab widgets and original indices
      if (_staffPermissions['dashboard'] == true) {
        allowedTabs.add(const DashboardTab());
        tabMapping.add(0);
      }
      if (_staffPermissions['reports'] == true) {
        allowedTabs.add(const ReportsTab());
        tabMapping.add(1);
      }
      if (_staffPermissions['transactions'] == true) {
        allowedTabs.add(const TransactionsTab());
        tabMapping.add(2);
      }
      if (_staffPermissions['topup'] == true) {
        allowedTabs.add(const TopUpTab());
        tabMapping.add(3);
      }
      if (_staffPermissions['withdrawal_requests'] == true) {
        allowedTabs.add(const WithdrawalRequestsTab());
        tabMapping.add(4);
      }
      if (_staffPermissions['settings'] == true) {
        allowedTabs.add(SettingsTab(initialFunction: _settingsInitialFunction));
        tabMapping.add(5);
      }
      if (_staffPermissions['user_management'] == true) {
        allowedTabs.add(const UserManagementTab());
        tabMapping.add(6);
      }
      if (_staffPermissions['service_ports'] == true) {
        allowedTabs.add(
          VendorsTab(
            navigateToServiceRegistration: widget.navigateToServiceRegistration,
          ),
        );
        tabMapping.add(7);
      }
      if (_staffPermissions['admin_management'] == true) {
        allowedTabs.add(const AdminManagementTab());
        tabMapping.add(8);
      }
      if (_staffPermissions['loaning'] == true) {
        allowedTabs.add(const LoaningTab());
        tabMapping.add(9);
      }
      if (_staffPermissions['feedback'] == true) {
        allowedTabs.add(const FeedbackTab());
        tabMapping.add(10);
      }

      // If no permissions granted, show empty state or default tab
      if (allowedTabs.isEmpty) {
        allowedTabs.add(_buildNoPermissionsTab());
      }

      setState(() {
        _tabs = allowedTabs;
        if (widget.initialTabIndex == null) {
          _currentIndex = 0;
        } else {
          // Map original tab index to staff-accessible tab index
          final originalIndex = widget.initialTabIndex!;
          final mappedIndex = tabMapping.indexOf(originalIndex);
          _currentIndex = mappedIndex >= 0 ? mappedIndex : 0;
        }
      });
    } else {
      // Full admin sees all tabs
      setState(() {
        _tabs = [
          const DashboardTab(), // 0 - Dashboard (Main)
          const ReportsTab(), // 1 - Reports (Main)
          const TransactionsTab(), // 2 - Transactions (Main)
          const TopUpTab(), // 3 - Top-Up (Main)
          const WithdrawalRequestsTab(), // 4 - Withdrawal Requests (Main)
          SettingsTab(
            initialFunction: _settingsInitialFunction,
          ), // 5 - Settings (Bottom nav profile replacement)
          const UserManagementTab(), // 6 - User Management (Management)
          VendorsTab(
            navigateToServiceRegistration: widget.navigateToServiceRegistration,
          ), // 7 - Service Ports (Management)
          const AdminManagementTab(), // 8 - Admin Management (Management)
          const LoaningTab(), // 9 - Loaning (Management)
          const FeedbackTab(), // 10 - Feedback (Management)
        ];
      });
    }
  }

  Widget _buildNoPermissionsTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No Permissions Granted',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please contact your administrator to grant access to tabs.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Initialize admin notifications for all requests
  /// This ensures notifications work regardless of which tab is active
  Future<void> _initializeAdminNotifications() async {
    try {
      await AdminNotificationService.startListening();
      print('✅ DEBUG: Admin notifications initialized in dashboard');
    } catch (e) {
      print(
        '❌ ERROR: Failed to initialize admin notifications in dashboard: $e',
      );
    }
  }

  void _checkSession() {
    // Check if session exists and is valid
    if (!SessionService.isLoggedIn) {
      // Redirect to login if not logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      });
      return;
    }

    // If logged in but not an admin, redirect based on user type
    if (!SessionService.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (SessionService.isStudent) {
          // Navigate to user dashboard if student
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const UserDashboard()),
          );
        } else if (SessionService.isService) {
          // Navigate to service dashboard if service
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder:
                  (context) => const ServiceDashboard(
                    serviceName: 'Service',
                    serviceType: 'Service',
                  ),
            ),
          );
        } else {
          // Unknown user type, redirect to login
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      });
    }

    // If we reach here, the session is valid
    print('DEBUG: Admin session is valid');
  }

  // Method to change tab index from child widgets
  void changeTabIndex(int index) {
    if (index >= 0 && index < _tabs.length) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  // Method to navigate to settings with specific function
  void navigateToSettingsWithFunction(int functionIndex) {
    // General Settings (function 0) is special - all staff can access it to update their own credentials
    // Other settings functions require settings permission
    if (SessionService.isAdminStaff && functionIndex != 0) {
      if (_staffPermissions['settings'] != true) {
        // Show error message if no permission for non-General Settings functions
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Access denied: You do not have permission to access this Settings function.',
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return; // Prevent navigation
      }
    }

    setState(() {
      _settingsInitialFunction = functionIndex;
      _currentIndex = 5; // Settings tab index
    });
    // Rebuild the tabs with the new initial function
    _tabs[5] = SettingsTab(initialFunction: _settingsInitialFunction);
  }

  // Filter navigation items based on admin role and permissions
  List<NavigationItem> _getFilteredNavigationItems() {
    if (SessionService.isAdminStaff) {
      // Map navigation item IDs to permission keys
      final Map<String, String> idToPermissionMap = {
        'dashboard': 'dashboard',
        'reports': 'reports',
        'transactions': 'transactions',
        'topup': 'topup',
        'withdrawal_requests': 'withdrawal_requests',
        'settings': 'settings',
        'users':
            'user_management', // 'users' maps to 'user_management' permission
        'vendors':
            'service_ports', // 'vendors' maps to 'service_ports' permission
        'admin_management': 'admin_management',
        'loaning': 'loaning',
        'feedback': 'feedback',
      };

      // Filter navigation items based on permissions
      return _navigationItems.where((item) {
        final permissionKey = idToPermissionMap[item.id];
        if (permissionKey == null) return false;
        return _staffPermissions[permissionKey] == true;
      }).toList();
    }
    // Full admin sees all items
    return _navigationItems;
  }

  // Map navigation item ID to tab widget index for staff
  int _getTabIndexForNavigationId(String navigationId) {
    if (!SessionService.isAdminStaff) {
      // For full admin, use direct mapping
      final Map<String, int> idToIndexMap = {
        'dashboard': 0,
        'reports': 1,
        'transactions': 2,
        'topup': 3,
        'withdrawal_requests': 4,
        'settings': 5,
        'users': 6,
        'vendors': 7,
        'admin_management': 8,
        'loaning': 9,
        'feedback': 10,
      };
      return idToIndexMap[navigationId] ?? 0;
    }

    // For staff, find the index based on permissions
    final Map<String, String> idToPermissionMap = {
      'dashboard': 'dashboard',
      'reports': 'reports',
      'transactions': 'transactions',
      'topup': 'topup',
      'withdrawal_requests': 'withdrawal_requests',
      'settings': 'settings',
      'users': 'user_management',
      'vendors': 'service_ports',
      'admin_management': 'admin_management',
      'loaning': 'loaning',
      'feedback': 'feedback',
    };

    final permissionKey = idToPermissionMap[navigationId];
    if (permissionKey == null || _staffPermissions[permissionKey] != true) {
      return 0; // Default to first allowed tab
    }

    // Find the index in the filtered tabs list
    int index = 0;
    final List<String> orderedPermissions = [
      'dashboard',
      'reports',
      'transactions',
      'topup',
      'withdrawal_requests',
      'settings',
      'user_management',
      'service_ports',
      'admin_management',
      'loaning',
      'feedback',
    ];

    for (final perm in orderedPermissions) {
      if (perm == permissionKey) {
        return index;
      }
      if (_staffPermissions[perm] == true) {
        index++;
      }
    }

    return 0;
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state while permissions are being loaded for staff
    if (SessionService.isAdminStaff && _isLoadingPermissions) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading permissions...',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 1024;
        final isTablet =
            constraints.maxWidth > 768 && constraints.maxWidth <= 1024;

        if (isDesktop) {
          return _buildDesktopLayout();
        } else if (isTablet) {
          return _buildTabletLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildDesktopLayout() {
    final sidebarWidth = _isSidebarCollapsed ? 70.0 : 280.0;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: sidebarWidth,
            child: _buildSidebar(isCollapsed: _isSidebarCollapsed),
          ),
          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildDesktopHeader(),
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      appBar: _buildMobileAppBar(),
      drawer: SizedBox(width: 250, child: _buildSidebar(isCollapsed: false)),
      body: _buildMainContent(),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      appBar: _buildMobileAppBar(),
      drawer: SizedBox(width: 280, child: _buildSidebar(isCollapsed: false)),
      body: _buildMainContent(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildSidebar({required bool isCollapsed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo Section
          Container(
            padding: const EdgeInsets.all(25),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE9ECEF))),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [evsuRed, evsuRedDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'E',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  const Text(
                    'eCampusPay',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: evsuRed,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Navigation Menu
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                if (!isCollapsed)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                    child: Text(
                      'MAIN',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ..._getFilteredNavigationItems()
                    .take(6)
                    .map((item) => _buildNavItem(item, isCollapsed)),
                if (!isCollapsed && !SessionService.isAdminStaff) ...[
                  const SizedBox(height: 20),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                    child: Text(
                      'MANAGEMENT',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
                ..._getFilteredNavigationItems()
                    .skip(6)
                    .map((item) => _buildNavItem(item, isCollapsed)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(NavigationItem item, bool isCollapsed) {
    final tabIndex = _getTabIndexForNavigationId(item.id);
    final isActive = _currentIndex == tabIndex && _tabs.length > tabIndex;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: InkWell(
        onTap: () {
          if (tabIndex >= 0 && tabIndex < _tabs.length) {
            setState(() => _currentIndex = tabIndex);
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCollapsed ? 12 : 25,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFEF2F2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              right: BorderSide(
                color: isActive ? evsuRed : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isActive ? item.activeIcon : item.icon,
                color: isActive ? evsuRed : Colors.grey[600],
                size: 18,
              ),
              if (!isCollapsed) ...[
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isActive ? evsuRed : Colors.grey[600],
                    ),
                  ),
                ),
                if (item.badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: evsuRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      item.badge.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [evsuRed, evsuRedDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Row(
          children: [
            IconButton(
              onPressed:
                  () => setState(
                    () => _isSidebarCollapsed = !_isSidebarCollapsed,
                  ),
              icon: const Icon(Icons.menu, color: Colors.white),
            ),
            const SizedBox(width: 20),
            const Text(
              'eCampusPay Admin',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            // Admin Info
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'System Administrator',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Full Access',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(width: 20),
            IconButton(
              onPressed: _showQuickActions,
              icon: const Icon(Icons.account_circle, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    return AppBar(
      backgroundColor: evsuRed,
      elevation: 2,
      leading: IconButton(
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        icon: const Icon(Icons.menu, color: Colors.white),
      ),
      title: const Text(
        'eCampusPay Admin',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      actions: [
        IconButton(
          onPressed: _showQuickActions,
          icon: const Icon(Icons.account_circle, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
      child:
          _currentIndex < _tabs.length
              ? _tabs[_currentIndex]
              : _tabs[0], // Fallback to dashboard if index is out of range
    );
  }

  Widget _buildBottomNavigation() {
    if (SessionService.isAdminStaff) {
      // For staff, only show bottom nav items they have permission for
      final filteredItems = _getFilteredNavigationItems();
      final List<BottomNavigationBarItem> items = [];
      final List<int> tabIndices = [];

      // Map navigation items to bottom nav items (only first 4 main tabs)
      final mainNavIds = ['dashboard', 'reports', 'transactions', 'settings'];
      for (final navId in mainNavIds) {
        final navItem = filteredItems.firstWhere(
          (item) => item.id == navId,
          orElse:
              () => NavigationItem(
                icon: Icons.circle,
                activeIcon: Icons.circle,
                label: '',
                id: navId,
              ),
        );
        if (navItem.id != '' &&
            _staffPermissions[_getPermissionKeyForNavId(navId)] == true) {
          final tabIndex = _getTabIndexForNavigationId(navId);
          items.add(
            BottomNavigationBarItem(
              icon: Icon(
                _currentIndex == tabIndex
                    ? _getActiveIconForNavId(navId)
                    : _getInactiveIconForNavId(navId),
              ),
              label: navItem.label,
            ),
          );
          tabIndices.add(tabIndex);
        }
      }

      // BottomNavigationBar requires at least 2 items
      // Hide bottom nav if less than 2 items (0 or 1 permission granted)
      if (items.isEmpty || items.length < 2) {
        return const SizedBox.shrink(); // Hide bottom nav if insufficient permissions
      }

      // Find current bottom nav index
      int bottomNavIndex = 0;
      for (int i = 0; i < tabIndices.length; i++) {
        if (tabIndices[i] == _currentIndex) {
          bottomNavIndex = i;
          break;
        }
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: bottomNavIndex,
          onTap: (index) {
            if (index < tabIndices.length) {
              setState(() => _currentIndex = tabIndices[index]);
            }
          },
          type: BottomNavigationBarType.fixed,
          selectedItemColor: evsuRed,
          unselectedItemColor: Colors.grey[600],
          backgroundColor: Colors.white,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: items,
        ),
      );
    }

    // Full admin - original bottom navigation logic
    int bottomNavIndex = _currentIndex;
    if (_currentIndex == 5) {
      bottomNavIndex = 3; // Settings tab (index 5) maps to bottom nav index 3
    } else if (_currentIndex > 3 && _currentIndex != 5) {
      bottomNavIndex = 3; // Other tabs > 3 default to settings
    } else if (_currentIndex > 2) {
      bottomNavIndex =
          2; // Top-Up (3) and Withdrawal (4) show Transactions as active
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: bottomNavIndex,
        onTap: (index) {
          // Map bottom navigation index to actual tab index
          int actualIndex = index;
          if (index == 3) {
            actualIndex =
                5; // Bottom nav index 3 (Settings) maps to tab index 5
          }
          setState(() => _currentIndex = actualIndex);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: evsuRed,
        unselectedItemColor: Colors.grey[600],
        backgroundColor: Colors.white,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
        items: [
          BottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 0 ? Icons.dashboard : Icons.dashboard_outlined,
            ),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 1 ? Icons.analytics : Icons.analytics_outlined,
            ),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 2
                  ? Icons.receipt_long
                  : Icons.receipt_long_outlined,
            ),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              _currentIndex == 5 ? Icons.settings : Icons.settings_outlined,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  String _getPermissionKeyForNavId(String navId) {
    final Map<String, String> idToPermissionMap = {
      'dashboard': 'dashboard',
      'reports': 'reports',
      'transactions': 'transactions',
      'topup': 'topup',
      'withdrawal_requests': 'withdrawal_requests',
      'settings': 'settings',
      'users': 'user_management',
      'vendors': 'service_ports',
      'admin_management': 'admin_management',
      'loaning': 'loaning',
      'feedback': 'feedback',
    };
    return idToPermissionMap[navId] ?? '';
  }

  IconData _getActiveIconForNavId(String navId) {
    switch (navId) {
      case 'dashboard':
        return Icons.dashboard;
      case 'reports':
        return Icons.analytics;
      case 'transactions':
        return Icons.receipt_long;
      case 'settings':
        return Icons.settings;
      default:
        return Icons.circle;
    }
  }

  IconData _getInactiveIconForNavId(String navId) {
    switch (navId) {
      case 'dashboard':
        return Icons.dashboard_outlined;
      case 'reports':
        return Icons.analytics_outlined;
      case 'transactions':
        return Icons.receipt_long_outlined;
      case 'settings':
        return Icons.settings_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  void _showQuickActions() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1024;

    if (isDesktop) {
      // Show as a popup dialog for desktop/web
      showDialog(
        context: context,
        builder:
            (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: evsuRed,
                        ),
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Admin Profile is accessible to all staff (for updating own credentials)
                            _buildActionButton(
                              icon: Icons.person,
                              iconColor: evsuRed,
                              title: 'Admin Profile',
                              onTap: () {
                                Navigator.pop(context);
                                navigateToSettingsWithFunction(
                                  0,
                                ); // Navigate to General Settings
                              },
                            ),
                            _buildActionButton(
                              icon: Icons.settings,
                              iconColor: Colors.grey[600]!,
                              title: 'Settings',
                              onTap: () {
                                Navigator.pop(context);
                                changeTabIndex(5); // Navigate to Settings tab
                              },
                            ),
                            _buildActionButton(
                              icon: Icons.logout,
                              iconColor: Colors.red,
                              title: 'Logout',
                              onTap: () {
                                Navigator.pop(context);
                                _logout();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
      );
    } else {
      // Show as bottom sheet for mobile/tablet
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder:
            (context) => Container(
              margin: const EdgeInsets.all(16),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: evsuRed,
                      ),
                    ),
                  ),
                  // Admin Profile is accessible to all staff (for updating own credentials)
                  ListTile(
                    leading: const Icon(Icons.person, color: evsuRed),
                    title: const Text('Admin Profile'),
                    onTap: () {
                      Navigator.pop(context);
                      navigateToSettingsWithFunction(
                        0,
                      ); // Navigate to General Settings
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings, color: Colors.grey),
                    title: const Text('Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      changeTabIndex(5); // Navigate to Settings tab
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Logout'),
                    onTap: () {
                      Navigator.pop(context);
                      _logout();
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Stop admin notifications when dashboard is disposed (e.g., on logout)
    AdminNotificationService.stopListening();
    super.dispose();
  }

  void _logout() {
    // Show confirmation dialog for logout
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () {
                  // Stop admin notifications before logout
                  AdminNotificationService.stopListening();
                  Navigator.pop(context); // Close dialog
                  // Navigate to login page and clear all previous routes
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
                child: const Text(
                  'Logout',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String id;
  final int? badge;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.id,
    this.badge,
  });
}
