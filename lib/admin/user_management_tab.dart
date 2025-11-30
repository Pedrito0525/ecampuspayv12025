import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import '../services/esp32_bluetoothv2_service.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';
import '../services/encryption_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class UserManagementTab extends StatefulWidget {
  const UserManagementTab({super.key});

  @override
  State<UserManagementTab> createState() => _UserManagementTabState();
}

class _UserManagementTabState extends State<UserManagementTab> {
  static const Color evsuRed = Color(0xFFB91C1C);
  int _selectedFunction = -1;

  // Form controllers for account registration
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();
  final TextEditingController _rfidController = TextEditingController();

  // Form controllers for ID replacement
  final TextEditingController _replacementStudentIdController =
      TextEditingController();
  final TextEditingController _replacementStudentNameController =
      TextEditingController();
  final TextEditingController _replacementRfidController =
      TextEditingController();

  // ID Replacement state
  bool _isLoadingReplacementData = false;
  String? _currentRfidId; // Store the current RFID ID before replacement

  // CSV Import variables
  List<List<dynamic>> _csvData = [];
  List<Map<String, String>> _importPreviewData = [];
  bool _isImporting = false;

  // Bluetooth RFID Scanner variables
  StreamSubscription? _rfidDataSubscription;
  StreamSubscription? _connectionStatusSubscription;
  StreamSubscription? _statusSubscription;
  bool _isScanningRfid = false;
  bool _isScannerConnected = false;
  String _scannerStatus = "Disconnected";
  Timer? _autoReconnectTimer;
  Timer? _connectionCheckTimer;
  Timer? _recentRegistrationsRefreshTimer;
  Timer? _recentRFIDListRefreshTimer;

  // Student data fetching
  bool _isLoadingStudentData = false;

  // Course dropdown state
  String? _selectedCourse;
  List<String> _availableCourses = [];
  bool _isLoadingCourses = false;

  // User directory search
  String _searchQuery = '';
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  // Refresh key for smooth updates
  Key _recentRegistrationsKey = UniqueKey();
  Future<Map<String, dynamic>>? _cachedRecentRegistrationsFuture;
  Key _recentRFIDListKey = UniqueKey();
  Future<Map<String, dynamic>>? _cachedRecentRFIDListFuture;
  Key _userDirectoryKey = UniqueKey();
  Future<Map<String, dynamic>>? _cachedUserDirectoryFuture;

  @override
  void initState() {
    super.initState();
    _initializeBluetoothService();
    _startRecentRegistrationsRefreshTimer();
    _startRecentRFIDListRefreshTimer();
    // Initialize cached futures
    _cachedRecentRegistrationsFuture = SupabaseService.getAllUsers();
    _cachedRecentRFIDListFuture = SupabaseService.getRecentIdReplacements(
      limit: 5,
    );
    _cachedUserDirectoryFuture = SupabaseService.getAllUsers();
    // Load available courses
    _loadAvailableCourses();
  }

  @override
  void dispose() {
    _autoReconnectTimer?.cancel();
    _connectionCheckTimer?.cancel();
    _recentRegistrationsRefreshTimer?.cancel();
    _recentRFIDListRefreshTimer?.cancel();
    _cleanupBluetoothService();
    _studentIdController.dispose();
    _studentNameController.dispose();
    _emailController.dispose();
    _courseController.dispose();
    _rfidController.dispose();
    _replacementStudentIdController.dispose();
    _replacementStudentNameController.dispose();
    _replacementRfidController.dispose();
    super.dispose();
  }

  void _initializeBluetoothService() async {
    // Cancel existing subscriptions first to prevent duplicates
    _rfidDataSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _statusSubscription?.cancel();

    // Initialize Bluetooth and attempt auto-connection
    bool initialized = await ESP32BluetoothService.initialize();
    if (initialized) {
      _checkExistingConnection();

      // Test scanner assignment data first
      await _testScannerAssignment();

      // Attempt auto-connection to assigned scanner if not already connected
      if (!ESP32BluetoothService.isConnected) {
        await _autoConnectToAssignedScanner();
      }
    }

    // Listen to RFID scan results
    _rfidDataSubscription = ESP32BluetoothService.rfidDataStream.listen((
      data,
    ) async {
      // Check if widget is still mounted before updating UI
      if (!mounted) return;

      final String scannedRfidId = data['cardId'] ?? '';

      // Close scanning dialog if open
      if (_isScanningRfid) {
        try {
          Navigator.of(context).pop();
        } catch (e) {
          // Dialog might already be closed, ignore error
          print('Dialog already closed: $e');
        }
      }

      // Validate RFID before setting it in the form
      if (scannedRfidId.isNotEmpty) {
        try {
          // Initialize Supabase service
          await SupabaseService.initialize();

          // Determine which form we're in based on _selectedFunction
          final bool isReplacementForm = _selectedFunction == 1;

          // Check if RFID already exists (only for registration, not replacement)
          if (!isReplacementForm) {
            final rfidExists = await SupabaseService.authStudentRfidExists(
              scannedRfidId,
            );

            if (rfidExists) {
              // Show error message for existing RFID
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'RFID ID $scannedRfidId is already registered',
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }

              // Update UI state but don't set the RFID
              if (mounted) {
                setState(() {
                  _isScanningRfid = false;
                });
              }

              // Clean up after scan (but keep connection alive)
              _cleanupAfterScan();
              return;
            }
          } else {
            // For replacement form, check if RFID exists and show warning
            final rfidExists = await SupabaseService.authStudentRfidExists(
              scannedRfidId,
            );

            if (rfidExists) {
              // Show warning but still allow replacement
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Warning: RFID ID $scannedRfidId is already registered. Please verify before replacing.',
                    ),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            }
          }

          // RFID is available (or allowed for replacement), set it in the appropriate form
          if (mounted) {
            setState(() {
              // Set RFID in the correct controller based on which form is active
              if (isReplacementForm) {
                _replacementRfidController.text = scannedRfidId;
              } else {
                _rfidController.text = scannedRfidId;
              }

              _isScanningRfid = false;
            });
          }

          // Update connection status
          _checkAndUpdateConnectionStatus();

          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isReplacementForm
                      ? 'New RFID card scanned: $scannedRfidId'
                      : 'RFID card scanned: $scannedRfidId',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );
          }
        } catch (e) {
          // Handle validation error
          if (mounted) {
            setState(() {
              _isScanningRfid = false;
            });

            // Update connection status
            _checkAndUpdateConnectionStatus();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error validating RFID: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }

      // Clean up after scan (but keep connection alive)
      _cleanupAfterScan();

      // Refresh connection status to ensure UI is up to date
      _refreshConnectionStatus();
    });

    // Listen to connection status
    _connectionStatusSubscription = ESP32BluetoothService.connectionStatusStream
        .listen((connected) {
          if (mounted) {
            setState(() {
              _isScannerConnected = connected;
              _scannerStatus =
                  connected ? "Connected to assigned scanner" : "Disconnected";
            });
          }
        });

    // Listen to status messages
    _statusSubscription = ESP32BluetoothService.statusMessageStream.listen((
      message,
    ) {
      // Hide error messages from UI - only log to console for debugging
      if (message.contains('❌') || message.contains('error')) {
        if (mounted) {
          setState(() {
            _isScanningRfid = false;
          });
          // Log error to console but don't show to user
          print('BLE Status Error (hidden from UI): $message');
        }
      }
    });

    // Start auto-reconnect timer (check every 5 seconds)
    _startAutoReconnectTimer();

    // Start connection check timer (check every 3 seconds to refresh button state)
    _startConnectionCheckTimer();
  }

  /// Start connection check timer to refresh button state every 3 seconds
  void _startConnectionCheckTimer() {
    // Cancel existing timer if any
    _connectionCheckTimer?.cancel();

    // Check connection status immediately
    _checkAndUpdateConnectionStatus();

    // Start periodic timer to check every 3 seconds
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && !_isScanningRfid) {
        _checkAndUpdateConnectionStatus();
      }
    });
  }

  /// Check connection status and update state (refreshes button state)
  void _checkAndUpdateConnectionStatus() {
    if (!mounted) return;

    // Check actual connection status from service
    final bool isConnected = ESP32BluetoothService.isConnected;

    // Only update if state changed to avoid unnecessary rebuilds
    if (_isScannerConnected != isConnected) {
      setState(() {
        _isScannerConnected = isConnected;
        _scannerStatus =
            isConnected ? "Connected to assigned scanner" : "Disconnected";
      });
    }
  }

  /// Start auto-reconnect timer to check connection every 5 seconds
  void _startAutoReconnectTimer() {
    // Cancel existing timer if any
    _autoReconnectTimer?.cancel();

    // Start new periodic timer
    _autoReconnectTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      // Only try to reconnect if not currently scanning and not connected
      if (!_isScanningRfid && mounted) {
        // Check current connection status
        bool isConnected = ESP32BluetoothService.isConnected;

        if (!isConnected) {
          // Try to reconnect to assigned scanner
          print(
            'DEBUG: Auto-reconnect timer: Scanner disconnected, attempting reconnect...',
          );

          // Update status
          if (mounted) {
            setState(() {
              _scannerStatus = 'Reconnecting...';
            });
          }

          // Attempt auto-connection
          await _autoConnectToAssignedScanner();
        }
      }
    });
  }

  void _cleanupBluetoothService() {
    // Cancel auto-reconnect timer
    _autoReconnectTimer?.cancel();
    _autoReconnectTimer = null;

    // Cancel connection check timer
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;

    // Cancel all subscriptions
    _rfidDataSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _statusSubscription?.cancel();

    // Reset subscription variables
    _rfidDataSubscription = null;
    _connectionStatusSubscription = null;
    _statusSubscription = null;

    // Disconnect from ESP32 service
    ESP32BluetoothService.disconnect();

    // Reset scanning state
    if (mounted) {
      setState(() {
        _isScanningRfid = false;
        _isScannerConnected = false;
        _scannerStatus = "Disconnected";
      });
    }
  }

  void _checkExistingConnection() {
    _checkAndUpdateConnectionStatus();
  }

  /// Refresh the connection status and update UI accordingly
  void _refreshConnectionStatus() {
    _checkAndUpdateConnectionStatus();
  }

  /// Start periodic refresh timer for recent registrations (every 60 seconds)
  void _startRecentRegistrationsRefreshTimer() {
    // Cancel existing timer if any
    _recentRegistrationsRefreshTimer?.cancel();

    // Start periodic timer to refresh every 60 seconds
    _recentRegistrationsRefreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (timer) {
        if (mounted) {
          _refreshRecentRegistrations();
        }
      },
    );
  }

  /// Refresh recent registrations smoothly without obvious rebuild
  void _refreshRecentRegistrations() {
    if (!mounted) return;

    // Clear cached future to force refresh
    _cachedRecentRegistrationsFuture = null;

    // Smoothly refresh by updating the key after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _recentRegistrationsKey = UniqueKey();
          // Create new future when key changes
          _cachedRecentRegistrationsFuture = SupabaseService.getAllUsers();
        });
      }
    });
  }

  /// Get cached or create new future for recent registrations
  Future<Map<String, dynamic>> _getRecentRegistrationsFuture() {
    _cachedRecentRegistrationsFuture ??= SupabaseService.getAllUsers();
    return _cachedRecentRegistrationsFuture!;
  }

  /// Start periodic refresh timer for recent RFID list (every 60 seconds)
  void _startRecentRFIDListRefreshTimer() {
    // Cancel existing timer if any
    _recentRFIDListRefreshTimer?.cancel();

    // Start periodic timer to refresh every 60 seconds
    _recentRFIDListRefreshTimer = Timer.periodic(const Duration(seconds: 60), (
      timer,
    ) {
      if (mounted) {
        _refreshRecentRFIDList();
      }
    });
  }

  /// Refresh recent RFID list smoothly without obvious rebuild
  void _refreshRecentRFIDList() {
    if (!mounted) return;

    // Clear cached future to force refresh
    _cachedRecentRFIDListFuture = null;

    // Smoothly refresh by updating the key after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _recentRFIDListKey = UniqueKey();
          // Create new future when key changes
          _cachedRecentRFIDListFuture = SupabaseService.getRecentIdReplacements(
            limit: 5,
          );
        });
      }
    });
  }

  /// Get cached or create new future for recent RFID list
  Future<Map<String, dynamic>> _getRecentRFIDListFuture() {
    _cachedRecentRFIDListFuture ??= SupabaseService.getRecentIdReplacements(
      limit: 5,
    );
    return _cachedRecentRFIDListFuture!;
  }

  /// Refresh user directory independently
  void _refreshUserDirectory() {
    if (!mounted) return;

    // Clear cached future to force refresh
    _cachedUserDirectoryFuture = null;

    // Clear user lists to force reload
    setState(() {
      _allUsers = [];
      _filteredUsers = [];
    });

    // Smoothly refresh by updating the key after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _userDirectoryKey = UniqueKey();
          // Create new future when key changes
          _cachedUserDirectoryFuture = SupabaseService.getAllUsers();
        });
      }
    });
  }

  /// Get cached or create new future for user directory
  Future<Map<String, dynamic>> _getUserDirectoryFuture() {
    _cachedUserDirectoryFuture ??= SupabaseService.getAllUsers();
    return _cachedUserDirectoryFuture!;
  }

  /// Check and request Bluetooth permissions for Android 12+
  Future<bool> _checkBluetoothPermissions() async {
    if (!Platform.isAndroid) {
      return true; // iOS doesn't need runtime permissions for Bluetooth
    }

    // Check Android version - permissions only required for Android 12+ (API 31+)
    try {
      // Check if we have the required permissions
      Map<Permission, PermissionStatus> permissions =
          await [
            Permission.bluetoothConnect,
            Permission.bluetoothScan,
          ].request();

      bool bluetoothConnectGranted =
          permissions[Permission.bluetoothConnect]?.isGranted ?? false;
      bool bluetoothScanGranted =
          permissions[Permission.bluetoothScan]?.isGranted ?? false;

      if (bluetoothConnectGranted && bluetoothScanGranted) {
        return true;
      }

      // If permissions are denied, show explanation and request again
      if (mounted) {
        bool shouldRequest = await _showPermissionDialog();
        if (shouldRequest) {
          // Request permissions again
          Map<Permission, PermissionStatus> retryPermissions =
              await [
                Permission.bluetoothConnect,
                Permission.bluetoothScan,
              ].request();

          bool retryConnectGranted =
              retryPermissions[Permission.bluetoothConnect]?.isGranted ?? false;
          bool retryScanGranted =
              retryPermissions[Permission.bluetoothScan]?.isGranted ?? false;

          return retryConnectGranted && retryScanGranted;
        }
      }

      return false;
    } catch (e) {
      print('Permission check error: $e');
      return false;
    }
  }

  /// Show dialog explaining why Bluetooth permissions are needed
  Future<bool> _showPermissionDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.bluetooth, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Bluetooth Permission Required'),
                ],
              ),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To auto-connect to EvsuPayScanner1, this app needs:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text('• Bluetooth Connect - To connect to your scanner'),
                  Text('• Bluetooth Scan - To find nearby scanners'),
                  SizedBox(height: 12),
                  Text(
                    'These permissions are required for Android 12+ to access Bluetooth devices.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Grant Permissions'),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  /// Test function to verify scanner assignment data
  Future<void> _testScannerAssignment() async {
    try {
      print('=== TESTING SCANNER ASSIGNMENT ===');

      // Test 1: Check current user data
      final currentUserData = SessionService.currentUserData;
      print('Current user data: $currentUserData');
      print('Current user data keys: ${currentUserData?.keys.toList()}');
      print('Username from session: ${currentUserData?['username']}');
      print('Email from session: ${currentUserData?['email']}');
      print('User ID from session: ${currentUserData?['id']}');

      // Test 2: Check all admin accounts
      final allAdmins = await SupabaseService.client
          .from('admin_accounts')
          .select('id, username, full_name, scanner_id')
          .order('username');
      print('All admin accounts: $allAdmins');

      // Test 3: Check specific admin with scanner_id
      final adminsWithScanners = await SupabaseService.client
          .from('admin_accounts')
          .select('id, username, full_name, scanner_id')
          .not('scanner_id', 'is', null)
          .neq('scanner_id', '');
      print('Admins with scanners: $adminsWithScanners');

      print('=== END TEST ===');
    } catch (e) {
      print('Test error: $e');
    }
  }

  Future<void> _autoConnectToAssignedScanner() async {
    if (mounted) {
      setState(() {
        _scannerStatus = 'Checking assigned scanner...';
      });
    }

    try {
      print('DEBUG: Starting auto-connect to assigned scanner...');

      // Get the current admin's assigned scanner
      final assignedScanner = await _getAssignedScanner();

      print('DEBUG: Assigned scanner result: $assignedScanner');

      if (assignedScanner != null && assignedScanner.isNotEmpty) {
        if (mounted) {
          setState(() {
            _scannerStatus =
                'Connecting to assigned scanner: $assignedScanner...';
          });
        }

        print('DEBUG: Attempting to connect to scanner: $assignedScanner');
        // Attempt to connect to the specific assigned scanner
        await _connectToSpecificScanner(assignedScanner);
      } else {
        // If no specific scanner assigned, try to auto-connect to any paired ESP32 device
        print(
          'DEBUG: No specific scanner assigned, trying auto-connect to paired devices',
        );
        await _fallbackAutoConnect();
      }
    } catch (error) {
      // Hide connection errors from UI - only log to console
      print('DEBUG: Error getting assigned scanner (hidden from UI): $error');
      if (mounted) {
        setState(() {
          // Set generic disconnected status instead of error message
          _scannerStatus = 'Disconnected';
        });
      }
      // Try to fallback to paired devices
      await _fallbackAutoConnect();
    }
  }

  /// Fallback method using ESP32BluetoothService's built-in auto-connect
  Future<void> _fallbackAutoConnect() async {
    try {
      print('DEBUG: Trying built-in auto-connect as fallback');
      bool connected =
          await ESP32BluetoothService.autoConnectToPreferredDevice();

      if (connected) {
        if (mounted) {
          setState(() {
            _scannerStatus = "Auto-connected to preferred scanner";
          });
        }
        print('DEBUG: Successfully auto-connected using built-in method');
      } else {
        // Try paired devices as last resort
        await _autoConnectToPairedDevices();
      }
    } catch (error) {
      print('DEBUG: Built-in auto-connect failed: $error');
      await _autoConnectToPairedDevices();
    }
  }

  Future<String?> _getAssignedScanner() async {
    try {
      final currentUsername = SessionService.currentUserData?['username'] ?? '';
      final currentEmail = SessionService.currentUserData?['email'] ?? '';

      print('DEBUG: Getting assigned scanner for username: "$currentUsername"');
      print('DEBUG: Current email: "$currentEmail"');

      // Try to find by username first
      if (currentUsername.isNotEmpty) {
        final response =
            await SupabaseService.client
                .from('admin_accounts')
                .select('scanner_id')
                .eq('username', currentUsername)
                .maybeSingle();

        print('DEBUG: Database response by username: $response');

        if (response != null && response['scanner_id'] != null) {
          final scannerId = response['scanner_id'];
          print('DEBUG: Found scanner by username: $scannerId');
          return scannerId;
        }
      }

      // If username didn't work, try by email
      if (currentEmail.isNotEmpty) {
        print('DEBUG: Trying to find by email: $currentEmail');

        final response =
            await SupabaseService.client
                .from('admin_accounts')
                .select('scanner_id')
                .eq('email', currentEmail)
                .maybeSingle();

        print('DEBUG: Database response by email: $response');

        if (response != null && response['scanner_id'] != null) {
          final scannerId = response['scanner_id'];
          print('DEBUG: Found scanner by email: $scannerId');
          return scannerId;
        }
      }

      // If both failed, try to find by any available field
      print('DEBUG: Trying to find admin by any available method...');

      final allAdmins = await SupabaseService.client
          .from('admin_accounts')
          .select('id, username, email, scanner_id')
          .limit(10);

      print('DEBUG: All admins for comparison: $allAdmins');

      // Try to match by any available field
      for (var admin in allAdmins) {
        if (admin['username'] == currentUsername ||
            admin['email'] == currentEmail ||
            (currentEmail.isNotEmpty &&
                admin['email']?.toString().toLowerCase() ==
                    currentEmail.toLowerCase())) {
          print('DEBUG: Found matching admin: $admin');
          return admin['scanner_id'];
        }
      }

      print('DEBUG: No matching admin found');
      return null;
    } catch (e) {
      print('Error getting assigned scanner: $e');
      return null;
    }
  }

  /// Auto-connect to any paired ESP32 devices (fallback method)
  Future<void> _autoConnectToPairedDevices() async {
    if (mounted) {
      setState(() {
        _scannerStatus = 'Looking for paired ESP32 devices...';
      });
    }

    try {
      // Check Bluetooth permissions first
      bool hasPermissions = await _checkBluetoothPermissions();
      if (!hasPermissions) {
        if (mounted) {
          setState(() {
            _scannerStatus =
                'Bluetooth permissions denied - Cannot auto-connect';
          });
        }
        return;
      }

      // Get paired ESP32 devices
      List<BluetoothDevice> pairedDevices =
          await ESP32BluetoothService.getPairedESP32Devices();

      if (pairedDevices.isEmpty) {
        if (mounted) {
          setState(() {
            // Hide connection details from UI - show generic status
            _scannerStatus = 'Disconnected';
          });
        }
        print('DEBUG: No paired ESP32 devices found (hidden from UI)');
        return;
      }

      // Try to connect to the first available paired device
      for (BluetoothDevice device in pairedDevices) {
        if (mounted) {
          setState(() {
            _scannerStatus = 'Connecting to ${device.platformName}...';
          });
        }

        print(
          'DEBUG: Attempting to connect to paired device: ${device.platformName}',
        );
        bool connected = await ESP32BluetoothService.connectToDevice(device);

        if (connected) {
          if (mounted) {
            setState(() {
              _scannerStatus = "Connected to ${device.platformName}";
            });
          }
          print(
            'DEBUG: Successfully connected to paired device: ${device.platformName}',
          );
          return;
        }
      }

      // If we get here, none of the paired devices connected successfully
      if (mounted) {
        setState(() {
          // Set generic disconnected status instead of error message
          _scannerStatus = 'Disconnected';
        });
      }
      print(
        'DEBUG: Failed to connect to any paired ESP32 device (hidden from UI)',
      );
    } catch (error) {
      // Hide connection errors from UI - only log to console
      print(
        'DEBUG: Error in auto-connect to paired devices (hidden from UI): $error',
      );
      if (mounted) {
        setState(() {
          // Set generic disconnected status instead of error message
          _scannerStatus = 'Disconnected';
        });
      }
    }
  }

  /// Connect to a specific scanner by its ID (using same approach as service dashboard)
  Future<void> _connectToSpecificScanner(String scannerId) async {
    if (mounted) {
      setState(() {
        _scannerStatus = 'Searching for scanner: $scannerId...';
      });
    }

    // First check if we have the necessary permissions
    bool hasPermissions = await _checkBluetoothPermissions();

    if (!hasPermissions) {
      if (mounted) {
        setState(() {
          _scannerStatus = 'Bluetooth permissions denied - Cannot connect';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Bluetooth permissions required for scanner: $scannerId',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: openAppSettings,
            ),
          ),
        );
      }
      return;
    }

    try {
      // First try system connected devices (like service dashboard)
      print('DEBUG: Checking system connected devices...');
      List<BluetoothDevice> systemDevices = await FlutterBluePlus.systemDevices(
        [],
      );

      for (BluetoothDevice device in systemDevices) {
        print('DEBUG: Checking system device: ${device.platformName}');
        if (device.platformName == scannerId) {
          print(
            'DEBUG: Found target scanner in system devices: ${device.platformName}',
          );
          if (mounted) {
            setState(() {
              _scannerStatus = 'Connecting to system device $scannerId...';
            });
          }

          bool connected = await ESP32BluetoothService.connectToDevice(device);
          if (connected) {
            if (mounted) {
              setState(() {
                _scannerStatus = "Connected to $scannerId";
              });
            }
            print('Successfully connected to assigned scanner: $scannerId');
            return;
          }
        }
      }

      // Then try bonded/paired devices (like service dashboard)
      print('DEBUG: Checking bonded devices...');
      List<BluetoothDevice> bondedDevices = await FlutterBluePlus.bondedDevices;

      for (BluetoothDevice device in bondedDevices) {
        String deviceName = device.platformName;
        print(
          'DEBUG: Checking bonded device: "$deviceName" (ID: ${device.remoteId})',
        );

        if (deviceName == scannerId) {
          print('DEBUG: Found target scanner in bonded devices: $deviceName');
          if (mounted) {
            setState(() {
              _scannerStatus = 'Connecting to paired $scannerId...';
            });
          }

          bool connected = await ESP32BluetoothService.connectToDevice(device);
          if (connected) {
            if (mounted) {
              setState(() {
                _scannerStatus = "Connected to $scannerId";
              });
            }
            print('Successfully connected to assigned scanner: $scannerId');
            return;
          }
        }
      }

      // Only scan as last resort (like service dashboard)
      print('DEBUG: Scanner not found in paired devices, scanning...');
      if (mounted) {
        setState(() {
          _scannerStatus = 'Scanning for $scannerId...';
        });
      }

      List<BluetoothDevice> devices =
          await ESP32BluetoothService.scanForDevices();

      // Look for the specific scanner
      BluetoothDevice? targetDevice;
      for (BluetoothDevice device in devices) {
        final deviceName =
            device.platformName.isNotEmpty
                ? device.platformName
                : device.remoteId.toString();
        if (deviceName == scannerId) {
          targetDevice = device;
          break;
        }
      }

      if (targetDevice != null) {
        if (mounted) {
          setState(() {
            _scannerStatus = 'Connecting to $scannerId...';
          });
        }

        bool connected = await ESP32BluetoothService.connectToDevice(
          targetDevice,
        );
        if (connected) {
          if (mounted) {
            setState(() {
              _scannerStatus = "Connected to $scannerId";
            });
          }
          print('Successfully connected to assigned scanner: $scannerId');
        } else {
          if (mounted) {
            setState(() {
              // Hide connection failure details from UI - show generic status
              _scannerStatus = "Disconnected";
            });
          }
          print(
            'Failed to connect to assigned scanner $scannerId (hidden from UI)',
          );
        }
      } else {
        if (mounted) {
          setState(() {
            // Hide connection failure details from UI - show generic status
            _scannerStatus = "Disconnected";
          });
        }
        print(
          'Assigned scanner $scannerId not found in available devices (hidden from UI)',
        );
      }
    } catch (error) {
      // Hide connection errors from UI - only log to console
      print(
        'Error connecting to specific scanner $scannerId (hidden from UI): $error',
      );
      if (mounted) {
        setState(() {
          // Set generic disconnected status instead of error message
          _scannerStatus = 'Disconnected';
        });
      }
    }
  }

  void _cleanupAfterScan() {
    // Stop any ongoing scanning but keep connection alive
    ESP32BluetoothService.stopScanner();

    // Reset scanning state
    if (mounted) {
      setState(() {
        _isScanningRfid = false;
      });
    }

    // Update connection status based on actual connection state
    _checkAndUpdateConnectionStatus();

    // Don't clean up connections - keep scanner connected for next scan!
    // _cleanupBluetoothService(); // Removed - this was disconnecting the scanner
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedFunction != -1) {
      return _buildFunctionDetail(_selectedFunction);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'User Management',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Manage user accounts and RFID cards',
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
                    icon: Icons.person_add,
                    title: 'Account Registration',
                    description: 'Register new user accounts with RFID',
                    color: Colors.green,
                    onTap: () => setState(() => _selectedFunction = 0),
                  ),
                  _buildFunctionCard(
                    index: 1,
                    icon: Icons.credit_card,
                    title: 'ID Replacement',
                    description: 'Replace lost or damaged RFID cards',
                    color: Colors.blue,
                    onTap: () => setState(() => _selectedFunction = 1),
                  ),
                  _buildFunctionCard(
                    index: 2,
                    icon: Icons.people,
                    title: 'User Directory',
                    description: 'View and search all users',
                    color: evsuRed,
                    onTap: () => setState(() => _selectedFunction = 2),
                  ),
                  _buildFunctionCard(
                    index: 3,
                    icon: Icons.history,
                    title: 'User Activity',
                    description: 'View user transaction history',
                    color: Colors.teal,
                    onTap: () => setState(() => _selectedFunction = 3),
                  ),
                  _buildFunctionCard(
                    index: 4,
                    icon: Icons.upload_file,
                    title: 'CSV Import',
                    description: 'Import user data from CSV file',
                    color: Colors.orange,
                    onTap: () => setState(() => _selectedFunction = 4),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionDetail(int functionIndex) {
    switch (functionIndex) {
      case 0:
        return _buildAccountActivation();
      case 1:
        return _buildRFIDManagement();
      case 2:
        return _buildUserDirectory();
      case 3:
        return _buildUserActivity();
      case 4:
        return _buildCSVImport();
      default:
        return Container();
    }
  }

  Widget _buildAccountActivation() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

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
                    'Account Registration',
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

            // Account Creation Form and Pending Activations
            LayoutBuilder(
              builder: (context, constraints) {
                bool isWideScreen = constraints.maxWidth > 1000;

                return isWideScreen
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildAccountCreationForm()),
                        const SizedBox(width: 30),
                        Expanded(flex: 3, child: _buildRecentRegistrations()),
                      ],
                    )
                    : Column(
                      children: [
                        _buildAccountCreationForm(),
                        const SizedBox(height: 30),
                        _buildRecentRegistrations(),
                      ],
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountCreationForm() {
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
            'Register New Account',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),

          _buildFormFieldWithLoading(
            'Student ID',
            Icons.school,
            controller: _studentIdController,
            onChanged: _onStudentIdChanged,
            isLoading: _isLoadingStudentData,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            'Student Name',
            Icons.person,
            controller: _studentNameController,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            'Email Address (@evsu.edu.ph)',
            Icons.email,
            controller: _emailController,
            onChanged: _onEmailChanged,
          ),
          const SizedBox(height: 16),
          _buildCourseDropdown(),
          const SizedBox(height: 16),

          // RFID Card Input Field
          _buildFormField(
            'RFID Card Number',
            Icons.credit_card,
            controller: _rfidController,
          ),
          const SizedBox(height: 12),

          // Scan Button - Mobile Friendly Design
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  (_isScanningRfid || !_isScannerConnected)
                      ? null
                      : _scanRFIDCard,
              icon:
                  _isScanningRfid
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : Icon(
                        _isScannerConnected
                            ? Icons.nfc
                            : Icons.bluetooth_disabled,
                        color: Colors.white,
                        size: 20,
                      ),
              label: Text(
                _isScanningRfid
                    ? 'Scanning RFID Card...'
                    : _isScannerConnected
                    ? 'Scan School ID Card'
                    : 'Connect Scanner First',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isScanningRfid
                        ? Colors.grey.shade400
                        : _isScannerConnected
                        ? Colors.blue.shade600
                        : Colors.grey.shade500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: _isScanningRfid ? 0 : 2,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Scanner Status Indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color:
                  _isScannerConnected
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color:
                    _isScannerConnected
                        ? Colors.green.shade200
                        : Colors.orange.shade200,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isScannerConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  size: 16,
                  color:
                      _isScannerConnected
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Scanner: $_scannerStatus',
                    style: TextStyle(
                      fontSize: 12,
                      color:
                          _isScannerConnected
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showCreateAccountDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: evsuRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Register Account',
                    style: TextStyle(
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

  Widget _buildRecentRegistrations() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return FutureBuilder<Map<String, dynamic>>(
      key: _recentRegistrationsKey,
      future: _getRecentRegistrationsFuture(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading recent registrations...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error loading recent registrations: ${snapshot.error}'),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!['success']) {
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.data?['message'] ??
                        'Failed to load recent registrations',
                  ),
                ],
              ),
            ),
          );
        }

        final allUsers = snapshot.data!['data'] as List<dynamic>;
        // Get only the first 5 most recent registrations
        final recentUsers = allUsers.take(5).toList();

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
              // Responsive header layout
              isMobile
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recent Registrations',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${recentUsers.length} Registered',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  )
                  : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Recent Registrations',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${recentUsers.length} Registered',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 24),

              ...recentUsers.map((user) => _buildRecentUserCard(user)).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentUserCard(Map<String, dynamic> user) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    // Extract data from the real database response
    final name = user['name']?.toString() ?? 'N/A';
    final studentId = user['student_id']?.toString() ?? 'N/A';
    final email = user['email']?.toString() ?? 'N/A';
    final course = user['course']?.toString() ?? 'N/A';
    final rfidId = user['rfid_id']?.toString() ?? 'N/A';
    final createdAt = user['created_at']?.toString() ?? '';
    final registeredDate = _formatDate(createdAt);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      padding: EdgeInsets.all(isMobile ? 16.0 : 20.0),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User info and action buttons
          isMobile
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: evsuRed,
                        child: Text(
                          name.isNotEmpty
                              ? name.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'School ID: $studentId',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Registered',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
              : Row(
                children: [
                  CircleAvatar(
                    backgroundColor: evsuRed,
                    child: Text(
                      name.isNotEmpty
                          ? name.substring(0, 1).toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'School ID: $studentId',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
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
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green.shade700,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Registered',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          SizedBox(height: isMobile ? 12 : 16),

          // User details - compact layout
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Email: $email',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Course: $course',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'RFID: $rfidId',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Registration date
          Text(
            'Registered: $registeredDate',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey.shade500,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRFIDManagement() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedFunction = -1),
                icon: const Icon(Icons.arrow_back, color: evsuRed),
              ),
              const Text(
                'ID Replacement',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // RFID management interface
          LayoutBuilder(
            builder: (context, constraints) {
              bool isWideScreen = constraints.maxWidth > 800;

              return isWideScreen
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 2, child: _buildRFIDForm()),
                      const SizedBox(width: 30),
                      Expanded(flex: 1, child: _buildRFIDList()),
                    ],
                  )
                  : Column(
                    children: [
                      _buildRFIDForm(),
                      const SizedBox(height: 30),
                      _buildRFIDList(),
                    ],
                  );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRFIDForm() {
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
            'Replace RFID Card',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),

          _buildFormFieldWithLoading(
            'Student ID',
            Icons.badge,
            controller: _replacementStudentIdController,
            onChanged: _onReplacementStudentIdChanged,
            isLoading: _isLoadingReplacementData,
          ),
          const SizedBox(height: 16),
          _buildFormField(
            'Student Name',
            Icons.person,
            controller: _replacementStudentNameController,
          ),
          const SizedBox(height: 16),

          // Display current RFID if found
          if (_currentRfidId != null && _currentRfidId!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.credit_card,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current RFID Card',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        Text(
                          _currentRfidId!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade900,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          _buildReplacementRFIDCardField(),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _performRFIDReplacement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: evsuRed,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Replace RFID Card',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              OutlinedButton(
                onPressed: _clearReplacementForm,
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

  Widget _buildRFIDList() {
    return FutureBuilder<Map<String, dynamic>>(
      key: _recentRFIDListKey,
      future: _getRecentRFIDListFuture(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading recent RFID cards...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError ||
            !snapshot.hasData ||
            !snapshot.data!['success']) {
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    snapshot.data?['message'] ??
                        'Failed to load recent RFID cards',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final replacements = snapshot.data!['data'] as List<dynamic>;

        if (replacements.isEmpty) {
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
                  'Recent RFID Cards',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.credit_card_off,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No recent RFID replacements',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

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
                'Recent RFID Cards',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              ...replacements.map((replacement) {
                final studentName =
                    replacement['student_name']?.toString() ?? 'N/A';
                final newRfidId =
                    replacement['new_rfid_id']?.toString() ?? 'N/A';
                final oldRfidId = replacement['old_rfid_id']?.toString();
                final issueDate = replacement['issue_date']?.toString() ?? '';
                final formattedDate = _formatDate(issueDate);

                return _buildRFIDCardItem({
                  'student': studentName,
                  'cardNumber': newRfidId,
                  'oldCardNumber': oldRfidId,
                  'status': 'Replaced',
                  'issued': formattedDate,
                });
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRFIDCardItem(Map<String, String?> card) {
    final isReplaced = card['status'] == 'Replaced';
    final oldCardNumber = card['oldCardNumber'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isReplaced ? Colors.orange.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isReplaced ? Colors.orange.shade200 : Colors.blue.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  card['student'] ?? 'N/A',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      isReplaced
                          ? Colors.orange.shade100
                          : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  card['status'] ?? 'Active',
                  style: TextStyle(
                    color:
                        isReplaced
                            ? Colors.orange.shade700
                            : Colors.green.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (oldCardNumber != null && oldCardNumber.isNotEmpty) ...[
            Text(
              'Old Card: $oldCardNumber',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            'New Card: ${card['cardNumber'] ?? 'N/A'}',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Issued: ${card['issued'] ?? 'N/A'}',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildUserDirectory() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedFunction = -1),
                icon: const Icon(Icons.arrow_back, color: evsuRed),
              ),
              const Text(
                'User Directory',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          _buildUserDirectoryContent(),
        ],
      ),
    );
  }

  Widget _buildUserDirectoryContent() {
    return FutureBuilder<Map<String, dynamic>>(
      key: _userDirectoryKey,
      future: _getUserDirectoryFuture(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading users...'),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text('Error loading users: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Refresh the widget
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!['success']) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 48),
                  const SizedBox(height: 16),
                  Text(snapshot.data?['message'] ?? 'Failed to load users'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Refresh the widget
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final users = snapshot.data!['data'] as List<dynamic>;

        // Update all users from fresh data (always use latest data)
        _allUsers = users.cast<Map<String, dynamic>>();

        // Filter users based on search query
        _filteredUsers =
            _allUsers.where((user) {
              if (_searchQuery.isEmpty) return true;

              final searchLower = _searchQuery.toLowerCase();
              final name = (user['name'] ?? '').toString().toLowerCase();
              final studentId =
                  (user['student_id'] ?? '').toString().toLowerCase();
              final email = (user['email'] ?? '').toString().toLowerCase();
              final course = (user['course'] ?? '').toString().toLowerCase();

              return name.contains(searchLower) ||
                  studentId.contains(searchLower) ||
                  email.contains(searchLower) ||
                  course.contains(searchLower);
            }).toList();

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'All Users',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: evsuRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${_filteredUsers.length} Users',
                          style: TextStyle(
                            color: evsuRed,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: evsuRed),
                        onPressed: _refreshUserDirectory,
                        tooltip: 'Refresh User Directory',
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search bar
              TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: 'Search by name, ID, email, or course...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: evsuRed),
                  ),
                  suffixIcon:
                      _searchQuery.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                          : null,
                ),
              ),
              const SizedBox(height: 16),

              if (_searchQuery.isNotEmpty && _filteredUsers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No users match "$_searchQuery"',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_filteredUsers.isEmpty)
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
                        Icons.people_outline,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No users found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No users have been registered yet',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ..._filteredUsers
                    .map((user) => _buildUserDirectoryItem(user))
                    .toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUserDirectoryItem(Map<String, dynamic> user) {
    final isActive = user['is_active'] == true;
    final name = user['name']?.toString() ?? 'N/A';
    final email = user['email']?.toString() ?? 'N/A';
    final studentId = user['student_id']?.toString() ?? 'N/A';
    final course = user['course']?.toString() ?? 'N/A';
    final balance = user['balance']?.toString() ?? '0.0';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: evsuRed,
            child: Text(
              name.substring(0, 1),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: $studentId',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                Text(
                  '$course • ${email.split('@')[0]}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade100 : Colors.red.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isActive ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color:
                        isActive ? Colors.green.shade700 : Colors.red.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₱${double.tryParse(balance)?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'details':
                  _showUserDetailsDialog(user);
                  break;
                case 'delete':
                  _showDeleteUserDialog(name, email);
                  break;
              }
            },
            itemBuilder: (context) {
              // Staff cannot delete users, only view details
              final isStaff = SessionService.isAdminStaff;

              return [
                const PopupMenuItem(
                  value: 'details',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),
                // Only show delete option if not staff
                if (!isStaff)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
              ];
            },
            child: Icon(Icons.more_vert, color: Colors.grey.shade600, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildUserActivity() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _selectedFunction = -1),
                icon: const Icon(Icons.arrow_back, color: evsuRed),
              ),
              const Text(
                'User Activity',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          _buildUserActivityContent(),
        ],
      ),
    );
  }

  Widget _buildUserActivityContent() {
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
      child: const Text(
        'User activity logs, transaction history, and usage analytics would be displayed here.',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }

  // Helper methods
  Widget _buildFormField(
    String label,
    IconData icon, {
    TextEditingController? controller,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: evsuRed),
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
    );
  }

  Widget _buildFormFieldWithLoading(
    String label,
    IconData icon, {
    TextEditingController? controller,
    Function(String)? onChanged,
    bool isLoading = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            if (isLoading) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: evsuRed,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 12,
                  color: evsuRed,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: evsuRed),
            suffixIcon:
                isLoading
                    ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: evsuRed,
                        ),
                      ),
                    )
                    : null,
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
    );
  }

  void _showSuccessDialog(String message) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Success',
                    style: TextStyle(fontSize: isMobile ? 18 : 20),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
                maxWidth: screenWidth * 0.9,
              ),
              child: SingleChildScrollView(
                child: Text(
                  message,
                  style: TextStyle(fontSize: isMobile ? 13 : 14),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _showRegistrationSuccessDialog({
    required String studentName,
    required String studentId,
    required String email,
    required String course,
    required String rfidCard,
    required String password,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Account Registered Successfully!',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
                maxWidth: screenWidth * 0.9,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.person,
                            color: Colors.green.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Student account has been registered',
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSuccessDialogRow(
                      'Student',
                      studentName,
                      isMobile: isMobile,
                    ),
                    const SizedBox(height: 8),
                    _buildSuccessDialogRow(
                      'Student ID',
                      studentId,
                      isMobile: isMobile,
                    ),
                    const SizedBox(height: 8),
                    _buildSuccessDialogRow(
                      'Email',
                      email,
                      isMobile: isMobile,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    _buildSuccessDialogRow(
                      'Course',
                      course,
                      isMobile: isMobile,
                    ),
                    const SizedBox(height: 8),
                    _buildSuccessDialogRow(
                      'RFID Card',
                      rfidCard,
                      isMobile: isMobile,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
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
                                Icons.lock,
                                color: Colors.blue.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Temporary Password:',
                                style: TextStyle(
                                  fontSize: isMobile ? 11 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            password,
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'The student can now login using their email and password.',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  /// Build success dialog row
  Widget _buildSuccessDialogRow(
    String label,
    String value, {
    required bool isMobile,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isMobile ? 75 : 85,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 12 : 13,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: isMobile ? 12 : 13),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showReplaceCardDialog(String studentName) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Replace RFID Card'),
            content: Text('Issue a replacement RFID card for $studentName?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showSuccessDialog(
                    'Replacement RFID card issued successfully!',
                  );
                },
                child: const Text('Replace'),
              ),
            ],
          ),
    );
  }

  void _showCreateAccountDialog() async {
    final String studentId = _studentIdController.text.trim();
    final String studentName = _studentNameController.text.trim();
    final String email = _emailController.text.trim();
    final String course = _selectedCourse ?? '';
    final String rfidCard = _rfidController.text.trim();

    // Validate required fields
    if (studentId.isEmpty ||
        studentName.isEmpty ||
        email.isEmpty ||
        course.isEmpty ||
        rfidCard.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all required fields including RFID card and course',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate EVSU email format - show dialog if invalid
    if (!email.toLowerCase().endsWith('@evsu.edu.ph')) {
      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  SizedBox(width: isMobile ? 8 : 12),
                  Flexible(
                    child: Text(
                      'Invalid Email',
                      style: TextStyle(fontSize: isMobile ? 18 : 20),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                  maxWidth: screenWidth * 0.9,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    'Please enter a valid EVSU email ending with @evsu.edu.ph',
                    style: TextStyle(fontSize: isMobile ? 13 : 14),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1024;

    // Calculate responsive width: wider on larger screens
    double modalWidth;
    if (isMobile) {
      modalWidth = screenWidth * 0.95; // 95% on mobile
    } else if (isTablet) {
      modalWidth = screenWidth * 0.75; // 75% on tablet
    } else {
      modalWidth =
          screenWidth * 0.6; // 60% on desktop, but with min/max constraints
      modalWidth = modalWidth.clamp(500.0, 800.0); // Min 500px, max 800px
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => LayoutBuilder(
            builder: (context, constraints) {
              final dialogWidth = constraints.maxWidth;
              final isDialogMobile = dialogWidth < 600;

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isDialogMobile ? 16 : 24,
                  vertical: 20,
                ),
                title: Container(
                  padding: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(isDialogMobile ? 6 : 8),
                        decoration: BoxDecoration(
                          color: evsuRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.person_add,
                          color: evsuRed,
                          size: isDialogMobile ? 20 : 24,
                        ),
                      ),
                      SizedBox(width: isDialogMobile ? 8 : 12),
                      Expanded(
                        child: Text(
                          'Confirm Account Registration',
                          style: TextStyle(
                            fontSize:
                                isDialogMobile
                                    ? 16
                                    : isTablet
                                    ? 18
                                    : 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                content: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: screenHeight * 0.75,
                    maxWidth: modalWidth,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isDialogMobile ? 10 : 12),
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
                                size: isDialogMobile ? 18 : 20,
                              ),
                              SizedBox(width: isDialogMobile ? 6 : 8),
                              Expanded(
                                child: Text(
                                  'Please review all details before confirming registration:',
                                  style: TextStyle(
                                    fontSize: isDialogMobile ? 11 : 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: isDialogMobile ? 16 : 20),
                        _buildConfirmDialogDetailCard(
                          icon: Icons.school,
                          label: 'Student ID',
                          value: studentId,
                          isMobile: isDialogMobile,
                          dialogWidth: dialogWidth,
                        ),
                        SizedBox(height: isDialogMobile ? 10 : 12),
                        _buildConfirmDialogDetailCard(
                          icon: Icons.person,
                          label: 'Student Name',
                          value: studentName,
                          isMobile: isDialogMobile,
                          dialogWidth: dialogWidth,
                        ),
                        SizedBox(height: isDialogMobile ? 10 : 12),
                        _buildConfirmDialogDetailCard(
                          icon: Icons.email,
                          label: 'Email Address',
                          value: email,
                          isMobile: isDialogMobile,
                          maxLines: 2,
                          dialogWidth: dialogWidth,
                        ),
                        SizedBox(height: isDialogMobile ? 10 : 12),
                        _buildConfirmDialogDetailCard(
                          icon: Icons.book,
                          label: 'Course',
                          value: course,
                          isMobile: isDialogMobile,
                          dialogWidth: dialogWidth,
                        ),
                        SizedBox(height: isDialogMobile ? 10 : 12),
                        _buildConfirmDialogDetailCard(
                          icon: Icons.credit_card,
                          label: 'RFID Card Number',
                          value: rfidCard,
                          isMobile: isDialogMobile,
                          dialogWidth: dialogWidth,
                        ),
                        SizedBox(height: isDialogMobile ? 16 : 20),
                        Container(
                          padding: EdgeInsets.all(isDialogMobile ? 10 : 12),
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
                                size: isDialogMobile ? 18 : 20,
                              ),
                              SizedBox(width: isDialogMobile ? 6 : 8),
                              Expanded(
                                child: Text(
                                  'This will complete the registration process and the student can immediately use their RFID card.',
                                  style: TextStyle(
                                    fontSize: isDialogMobile ? 10 : 12,
                                    color: Colors.orange.shade900,
                                    fontStyle: FontStyle.italic,
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
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDialogMobile ? 16 : 24,
                        vertical: isDialogMobile ? 10 : 12,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontSize: isDialogMobile ? 13 : 14),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _performRegistration(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: evsuRed,
                      padding: EdgeInsets.symmetric(
                        horizontal: isDialogMobile ? 16 : 24,
                        vertical: isDialogMobile ? 10 : 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Confirm & Register',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: isDialogMobile ? 13 : 14,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
    );
  }

  void _performRegistration(BuildContext dialogContext) async {
    final String studentId = _studentIdController.text.trim();
    final String studentName = _studentNameController.text.trim();
    final String email = _emailController.text.trim();
    final String course = _selectedCourse ?? '';
    final String rfidCard = _rfidController.text.trim();

    Navigator.pop(dialogContext); // Close dialog

    // Show loading
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Flexible(
                    child: Text(
                      'Registering student account...',
                      style: TextStyle(fontSize: isMobile ? 13 : 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );

    try {
      // Register student account with authentication
      final result = await SupabaseService.registerStudentAccount(
        studentId: studentId,
        name: studentName,
        email: email,
        course: course,
        rfidId: rfidCard,
      );

      Navigator.pop(context); // Close loading dialog

      if (result['success']) {
        final password = result['data']['password'] ?? 'N/A';
        _showRegistrationSuccessDialog(
          studentName: studentName,
          studentId: studentId,
          email: email,
          course: course,
          rfidCard: rfidCard,
          password: password,
        );
        _clearForm(); // Clear the form after successful registration

        // Refresh recent registrations when new account is registered
        _refreshRecentRegistrations();
      } else {
        final screenWidth = MediaQuery.of(context).size.width;
        final isMobile = screenWidth < 600;

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Registration Failed',
                        style: TextStyle(fontSize: isMobile ? 18 : 20),
                      ),
                    ),
                  ],
                ),
                content: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                    maxWidth: screenWidth * 0.9,
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      result['message'] ?? 'Unknown error occurred',
                      style: TextStyle(fontSize: isMobile ? 13 : 14),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      final screenWidth = MediaQuery.of(context).size.width;
      final isMobile = screenWidth < 600;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Registration Error',
                      style: TextStyle(fontSize: isMobile ? 18 : 20),
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                  maxWidth: screenWidth * 0.9,
                ),
                child: SingleChildScrollView(
                  child: Text(
                    'An unexpected error occurred: $e',
                    style: TextStyle(fontSize: isMobile ? 13 : 14),
                  ),
                ),
              ),
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

  // Autofill functionality when Student ID is entered - now using Supabase
  void _onStudentIdChanged(String studentId) async {
    // Clear previous data first
    _studentNameController.clear();
    _emailController.clear();
    setState(() {
      _selectedCourse = null;
    });

    // Skip if student ID is empty or too short
    if (studentId.trim().isEmpty || studentId.trim().length < 3) {
      return;
    }

    setState(() {
      _isLoadingStudentData = true;
    });

    try {
      // Fetch student data from Supabase
      final result = await SupabaseService.getStudentForRegistration(
        studentId.trim(),
      );

      setState(() {
        _isLoadingStudentData = false;
      });

      if (result['success'] && result['data'] != null) {
        final studentData = result['data'];
        final courseFromDb = studentData['course']?.toString() ?? '';

        setState(() {
          _studentNameController.text = studentData['name'] ?? '';
          _emailController.text = studentData['email'] ?? '';
          // Auto-select course from dropdown if it exists (with proper capitalization)
          if (courseFromDb.isNotEmpty) {
            final matchingCourse = _findMatchingCourse(courseFromDb);
            if (matchingCourse != null) {
              _selectedCourse =
                  matchingCourse; // Use properly capitalized version
            }
            // If course doesn't match any available course, don't auto-select
            // User can manually select from dropdown
          }
        });

        // Show success message for autofill
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Student found: ${studentData['name']} - Form auto-filled',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
      // Student not found - silently proceed to manual input (no error message)
    } catch (e) {
      setState(() {
        _isLoadingStudentData = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching student data: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Clear all form fields
  void _clearForm() {
    _studentIdController.clear();
    _studentNameController.clear();
    _emailController.clear();
    setState(() {
      _selectedCourse = null;
    });
    _rfidController.clear();
  }

  // RFID card scanning functionality
  void _scanRFIDCard() async {
    // Check if already scanning
    if (_isScanningRfid) return;

    // Check if scanner is connected before allowing scan
    if (!_isScannerConnected) {
      _showError(
        "Scanner is not connected. Please wait for auto-connection or check scanner status.",
      );
      return;
    }

    // Check Bluetooth permissions first
    bool hasPermissions = await _checkBluetoothPermissions();
    if (!hasPermissions) {
      _showError(
        "Bluetooth permissions are required to scan RFID cards. Please grant permissions in app settings.",
      );
      return;
    }

    setState(() {
      _isScanningRfid = true;
    });

    try {
      // Don't disconnect - use existing connection!
      // Just show scanning dialog and start scanning
      _showScanningDialog(
        "Scanner connected! Place School ID card near the reader...",
      );

      // Start registration scanning with already connected device
      bool scanStarted = await ESP32BluetoothService.startRegistrationScanner();
      if (!scanStarted) {
        try {
          Navigator.of(context).pop(); // Close scanning dialog
        } catch (e) {
          print('Error closing dialog: $e');
        }
        _showError("Failed to start RFID scanning.");
        return;
      }

      // Set timeout for scanning
      Timer(const Duration(seconds: 30), () {
        if (_isScanningRfid && mounted) {
          try {
            Navigator.of(context).pop(); // Close scanning dialog
          } catch (e) {
            print('Error closing dialog: $e');
          }
          setState(() {
            _isScanningRfid = false;
            // Update status based on actual connection state after timeout
            _scannerStatus =
                ESP32BluetoothService.isConnected
                    ? "Connected to assigned scanner"
                    : "Disconnected";
          });
          // Stop scanning but keep connection alive
          ESP32BluetoothService.stopScanner();
          _showError("Scanning timeout. Please try again.");
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isScanningRfid = false;
          // Update status based on actual connection state after error
          _scannerStatus =
              ESP32BluetoothService.isConnected
                  ? "Connected to assigned scanner"
                  : "Disconnected";
        });

        // Stop scanning but keep connection alive
        ESP32BluetoothService.stopScanner();

        // Hide BLE connection errors from UI - only log to console
        final errorString = error.toString().toLowerCase();
        final isConnectionError =
            errorString.contains('connection') ||
            errorString.contains('bluetooth') ||
            errorString.contains('ble') ||
            errorString.contains('connect') ||
            errorString.contains('disconnect');

        if (isConnectionError) {
          print('RFID scanning BLE connection error (hidden from UI): $error');
        } else {
          // Show non-connection errors (e.g., scanning timeout, card read error)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('RFID scanning error: $error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  void _showScanningDialog(String message) {
    // Check if widget is still mounted before showing dialog
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.nfc, color: Colors.blue),
                const SizedBox(width: 8),
                const Flexible(
                  child: Text(
                    'Starting to Scan ID',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Scanner Status: $_scannerStatus',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  try {
                    Navigator.pop(context);
                  } catch (e) {
                    print('Error closing dialog: $e');
                  }
                  // Clean up properly when canceling
                  _cleanupAfterScan();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _showError(String message) {
    // Clean up after error
    _cleanupAfterScan();

    if (mounted) {
      // Reset scanning state
      setState(() {
        _isScanningRfid = false;
        // Set generic disconnected status instead of "Error" for BLE connection issues
        _scannerStatus =
            ESP32BluetoothService.isConnected
                ? "Connected to assigned scanner"
                : "Disconnected";
      });

      // Check if this is a BLE connection error message
      final messageLower = message.toLowerCase();
      final isConnectionError =
          messageLower.contains('connection') ||
          messageLower.contains('bluetooth') ||
          messageLower.contains('ble') ||
          messageLower.contains('connect') ||
          messageLower.contains('disconnect');

      // Hide BLE connection error messages from UI
      if (isConnectionError) {
        print('BLE connection error (hidden from UI): $message');
      } else {
        // Show non-connection errors (e.g., scanning timeout, permission issues)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Widget _buildCSVImport() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

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
                    'CSV Import',
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

            // CSV Import Interface
            LayoutBuilder(
              builder: (context, constraints) {
                bool isWideScreen = constraints.maxWidth > 1000;

                return isWideScreen
                    ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: _buildCSVUploadSection()),
                        const SizedBox(width: 30),
                        Expanded(flex: 3, child: _buildCSVPreviewSection()),
                      ],
                    )
                    : Column(
                      children: [
                        _buildCSVUploadSection(),
                        const SizedBox(height: 30),
                        _buildCSVPreviewSection(),
                      ],
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCSVUploadSection() {
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
            'Import User Data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
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
                    Icon(Icons.info, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'CSV Format Requirements',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your CSV file should contain the following columns:\n'
                  '• student_id (e.g., 2022-30600)\n'
                  '• name (Full name)\n'
                  '• email (Must be unique)\n'
                  '• course (Course code or name)\n\n'
                  'Note: Header row is required with exact column names.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // File picker button
          Center(
            child: InkWell(
              onTap: _pickCSVFile,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload,
                      size: 48,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Click to select CSV file',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Supported formats: .csv',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Download template button
          Center(
            child: OutlinedButton.icon(
              onPressed: _downloadCSVTemplate,
              icon: const Icon(Icons.download),
              label: const Text('Download CSV Template'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: evsuRed),
                foregroundColor: evsuRed,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCSVPreviewSection() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Import Preview',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              if (_importPreviewData.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_importPreviewData.length} records',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          if (_importPreviewData.isEmpty)
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
                    Icons.table_chart,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No file selected',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select a CSV file to see the preview here',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else ...[
            // CSV Data Preview
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Student ID')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Course')),
                  DataColumn(label: Text('Status')),
                ],
                rows:
                    _importPreviewData.take(10).map((user) {
                      bool isValid = _validateUserData(user);
                      return DataRow(
                        color: WidgetStateProperty.all(
                          isValid ? null : Colors.red.shade50,
                        ),
                        cells: [
                          DataCell(Text(user['student_id'] ?? '')),
                          DataCell(Text(user['name'] ?? '')),
                          DataCell(Text(user['email'] ?? '')),
                          DataCell(Text(user['course'] ?? '')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isValid
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isValid ? 'Valid' : 'Invalid',
                                style: TextStyle(
                                  color:
                                      isValid
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            if (_importPreviewData.length > 10)
              Text(
                'Showing first 10 of ${_importPreviewData.length} records',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            const SizedBox(height: 24),

            // Import actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isImporting ? null : _importUsers,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: evsuRed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child:
                        _isImporting
                            ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Importing...',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            )
                            : const Text(
                              'Import Users',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton(
                  onPressed: _clearImportData,
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
              ],
            ),
          ],
        ],
      ),
    );
  }

  // CSV Import Methods
  Future<void> _pickCSVFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
        withData: true, // Important for web compatibility
      );

      if (result != null && result.files.single.bytes != null) {
        // Use bytes for web compatibility
        Uint8List bytes = result.files.single.bytes!;
        String csvString = utf8.decode(bytes);

        // Parse CSV
        List<List<dynamic>> csvData = const CsvToListConverter().convert(
          csvString,
        );

        if (csvData.isNotEmpty) {
          setState(() {
            _csvData = csvData;
            _importPreviewData = _parseCSVToUserData(csvData);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'CSV file loaded: ${_importPreviewData.length} records found',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reading CSV file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, String>> _parseCSVToUserData(List<List<dynamic>> csvData) {
    if (csvData.length < 2) return []; // Need at least header + 1 data row

    List<String> headers =
        csvData[0].map((e) => e.toString().toLowerCase().trim()).toList();
    List<Map<String, String>> users = [];

    // Find column indices based on exact column names
    int studentIdIndex = -1;
    int nameIndex = -1;
    int emailIndex = -1;
    int courseIndex = -1;

    for (int i = 0; i < headers.length; i++) {
      String header = headers[i];
      if (header == 'student_id') {
        studentIdIndex = i;
      } else if (header == 'name') {
        nameIndex = i;
      } else if (header == 'email') {
        emailIndex = i;
      } else if (header == 'course') {
        courseIndex = i;
      }
    }

    // Validate that all required columns are present
    if (studentIdIndex == -1 ||
        nameIndex == -1 ||
        emailIndex == -1 ||
        courseIndex == -1) {
      return []; // Return empty if required columns are missing
    }

    // Process each data row
    for (int i = 1; i < csvData.length; i++) {
      List<dynamic> row = csvData[i];

      // Skip empty rows
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }

      Map<String, String> user = {};

      // Extract data based on column positions
      if (studentIdIndex < row.length) {
        user['student_id'] = row[studentIdIndex]?.toString().trim() ?? '';
      }
      if (nameIndex < row.length) {
        user['name'] = row[nameIndex]?.toString().trim() ?? '';
      }
      if (emailIndex < row.length) {
        user['email'] = row[emailIndex]?.toString().trim() ?? '';
      }
      if (courseIndex < row.length) {
        user['course'] = row[courseIndex]?.toString().trim() ?? '';
      }

      // Only add user if we have all essential data
      if (user['student_id']?.isNotEmpty == true &&
          user['name']?.isNotEmpty == true &&
          user['email']?.isNotEmpty == true &&
          user['course']?.isNotEmpty == true) {
        users.add(user);
      }
    }

    return users;
  }

  bool _validateUserData(Map<String, String> user) {
    // Check if all required fields are present and not empty
    if (user['student_id']?.isNotEmpty != true ||
        user['name']?.isNotEmpty != true ||
        user['email']?.isNotEmpty != true ||
        user['course']?.isNotEmpty != true) {
      return false;
    }

    // Validate email format
    String email = user['email']!;
    if (!RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email)) {
      return false;
    }

    return true;
  }

  Future<void> _importUsers() async {
    if (_importPreviewData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data to import. Please select a CSV file first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isImporting = true;
    });

    try {
      // Validate CSV data before import
      final validation = SupabaseService.validateCSVData(
        _importPreviewData.map((e) => Map<String, dynamic>.from(e)).toList(),
      );

      if (!validation['valid']) {
        setState(() {
          _isImporting = false;
        });

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Validation Failed'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Please fix the following issues:'),
                      const SizedBox(height: 12),
                      ...validation['errors'].map<Widget>(
                        (error) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '• ',
                                style: TextStyle(color: Colors.red),
                              ),
                              Expanded(
                                child: Text(
                                  error,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
        return;
      }

      // Show confirmation dialog
      bool? confirm = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Confirm Import'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready to import ${validation['total_rows']} students to Supabase database.',
                  ),
                  const SizedBox(height: 12),
                  const Text('This will:'),
                  const Text(
                    '• Insert all valid records into student_info table',
                  ),
                  const Text('• Skip any duplicate student IDs or emails'),
                  const Text('• Cannot be undone'),
                  const SizedBox(height: 12),
                  const Text(
                    'Do you want to proceed?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                  child: const Text(
                    'Import',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
      );

      if (confirm != true) {
        setState(() {
          _isImporting = false;
        });
        return;
      }

      // Get all existing student IDs from database to filter out duplicates
      List<String> existingStudentIds = [];
      try {
        await SupabaseService.initialize();
        final existingStudents = await SupabaseService.client
            .from('student_info')
            .select('student_id');

        existingStudentIds =
            existingStudents
                .map(
                  (student) => student['student_id']?.toString().trim() ?? '',
                )
                .where((id) => id.isNotEmpty)
                .toList();
      } catch (e) {
        print('Error fetching existing student IDs: $e');
        // Continue with import even if we can't check existing IDs
      }

      // Filter out students that already exist in the database
      final studentsToImport =
          _importPreviewData.where((student) {
            final studentId = student['student_id']?.toString().trim() ?? '';
            return studentId.isNotEmpty &&
                !existingStudentIds.contains(studentId);
          }).toList();

      final skippedCount = _importPreviewData.length - studentsToImport.length;

      // Check if there are any new students to import
      if (studentsToImport.isEmpty) {
        setState(() {
          _isImporting = false;
        });

        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isMobile = screenWidth < 600;

        showDialog(
          context: context,
          builder:
              (context) => LayoutBuilder(
                builder: (context, constraints) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info,
                          color: Colors.blue,
                          size: isMobile ? 20 : 24,
                        ),
                        SizedBox(width: isMobile ? 8 : 12),
                        Flexible(
                          child: Text(
                            'No New Students',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 20,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    content: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: screenHeight * 0.4,
                        maxWidth: screenWidth * 0.9,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              skippedCount > 0
                                  ? 'All ${skippedCount} student(s) from the CSV already exist in the database.'
                                  : 'No valid students to import.',
                              style: TextStyle(fontSize: isMobile ? 13 : 14),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No new students were imported.',
                              style: TextStyle(fontSize: isMobile ? 13 : 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 24,
                            vertical: isMobile ? 8 : 12,
                          ),
                        ),
                        child: Text(
                          'OK',
                          style: TextStyle(fontSize: isMobile ? 14 : 16),
                        ),
                      ),
                    ],
                  );
                },
              ),
        );
        return;
      }

      // Perform the actual import to Supabase (only new students)
      final result = await SupabaseService.insertStudentsBatch(
        studentsToImport.map((e) => Map<String, dynamic>.from(e)).toList(),
      );

      setState(() {
        _isImporting = false;
      });

      if (result['success']) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isMobile = screenWidth < 600;

        showDialog(
          context: context,
          builder:
              (context) => LayoutBuilder(
                builder: (context, constraints) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: isMobile ? 20 : 24,
                        ),
                        SizedBox(width: isMobile ? 8 : 12),
                        Flexible(
                          child: Text(
                            'Import Successful',
                            style: TextStyle(
                              fontSize: isMobile ? 18 : 20,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    content: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: screenHeight * 0.5,
                        maxWidth: screenWidth * 0.9,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Successfully imported ${result['count']} new student(s) to the database.',
                              style: TextStyle(fontSize: isMobile ? 13 : 14),
                            ),
                            if (skippedCount > 0) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Skipped ${skippedCount} student(s) that already exist in the database.',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontWeight: FontWeight.w600,
                                  fontSize: isMobile ? 13 : 14,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              'Students are now registered in the system and can be assigned RFID cards.',
                              style: TextStyle(fontSize: isMobile ? 13 : 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearImportData();
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 24,
                            vertical: isMobile ? 8 : 12,
                          ),
                        ),
                        child: Text(
                          'OK',
                          style: TextStyle(fontSize: isMobile ? 14 : 16),
                        ),
                      ),
                    ],
                  );
                },
              ),
        );
      } else {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text('Import Failed'),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result['message']),
                      if (result['error'] != null) ...[
                        const SizedBox(height: 12),
                        const Text(
                          'Technical details:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          result['error'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      setState(() {
        _isImporting = false;
      });

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Unexpected Error'),
              content: Text('An unexpected error occurred: ${e.toString()}'),
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

  void _clearImportData() {
    setState(() {
      _csvData.clear();
      _importPreviewData.clear();
    });
  }

  void _downloadCSVTemplate() {
    // In a real implementation, this would generate and download a CSV template
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('CSV Template'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a CSV file with the following headers (exact names required):',
                ),
                SizedBox(height: 12),
                Text(
                  'student_id,name,email,course',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    backgroundColor: Colors.grey,
                  ),
                ),
                SizedBox(height: 12),
                Text('Example data:'),
                Text(
                  '2022-30600,Juan Dela Cruz,juan.delacruz@evsu.edu.ph,BSIT',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    backgroundColor: Colors.grey,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Notes:\n• Use exact column names (lowercase)\n• Student ID format: YYYY-NNNNN\n• Email must be unique\n• All fields required',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _scanRFIDCardForReplacement() async {
    if (_isScanningRfid || !mounted) return;

    // Check if scanner is connected before allowing scan
    if (!_isScannerConnected) {
      _showError(
        "Scanner is not connected. Please wait for auto-connection or check scanner status.",
      );
      return;
    }

    // Check Bluetooth permissions first
    bool hasPermissions = await _checkBluetoothPermissions();
    if (!hasPermissions) {
      _showError(
        "Bluetooth permissions are required to scan RFID cards. Please grant permissions in app settings.",
      );
      return;
    }

    if (!mounted) return;

    // Set scanning state
    setState(() {
      _isScanningRfid = true;
      _scannerStatus = "Scanning for replacement card...";
    });

    try {
      // Don't disconnect - use existing connection!
      _showScanningDialog(
        "Scanner connected! Place new RFID card near the reader...",
      );

      // Start payment scanner for RFID card replacement
      bool scanStarted = await ESP32BluetoothService.startPaymentScanner(
        paymentAccount: 'replacement',
        amount: 0.0,
        itemName: 'ID Replacement',
      );

      if (!scanStarted) {
        if (mounted) {
          try {
            Navigator.of(context).pop(); // Close scanning dialog
          } catch (e) {
            print('Error closing dialog: $e');
          }
          _showError("Failed to start RFID scanning for replacement.");
        }
        return;
      }

      // Set timeout for scanning
      Timer(const Duration(seconds: 30), () {
        if (_isScanningRfid && mounted) {
          try {
            Navigator.of(context).pop(); // Close scanning dialog
          } catch (e) {
            print('Error closing dialog: $e');
          }
          setState(() {
            _isScanningRfid = false;
            // Update status based on actual connection state after timeout
            _scannerStatus =
                ESP32BluetoothService.isConnected
                    ? "Connected to assigned scanner"
                    : "Disconnected";
          });
          // Stop scanning but keep connection alive
          ESP32BluetoothService.stopScanner();
          if (mounted) {
            _showError("Scanning timeout. Please try again.");
          }
        }
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isScanningRfid = false;
          // Update status based on actual connection state after error
          _scannerStatus =
              ESP32BluetoothService.isConnected
                  ? "Connected to assigned scanner"
                  : "Disconnected";
        });

        // Stop scanning but keep connection alive
        ESP32BluetoothService.stopScanner();

        // Hide BLE connection errors from UI - only log to console
        final errorString = error.toString().toLowerCase();
        final isConnectionError =
            errorString.contains('connection') ||
            errorString.contains('bluetooth') ||
            errorString.contains('ble') ||
            errorString.contains('connect') ||
            errorString.contains('disconnect');

        if (isConnectionError) {
          print(
            'RFID replacement scanning BLE connection error (hidden from UI): $error',
          );
        } else {
          // Show non-connection errors (e.g., scanning timeout, card read error)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('RFID replacement scanning error: $error'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  /// Helper function to validate EVSU email format
  bool _isValidEvsuEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@evsu\.edu\.ph$',
    ).hasMatch(email.toLowerCase());
  }

  /// Enhanced email validation with domain and mailbox verification
  Future<Map<String, dynamic>> _validateEvsuEmail(String email) async {
    // Step 1: Check email format
    if (email.trim().isEmpty) {
      return {'valid': false, 'message': 'Email cannot be empty'};
    }

    // Step 2: Check if email contains @
    if (!email.contains('@')) {
      return {
        'valid': false,
        'message': 'Please enter a valid EVSU email ending with @evsu.edu.ph',
      };
    }

    // Step 3: Check domain structure
    final emailLower = email.toLowerCase().trim();
    if (!emailLower.endsWith('@evsu.edu.ph')) {
      return {
        'valid': false,
        'message': 'Please enter a valid EVSU email ending with @evsu.edu.ph',
      };
    }

    // Step 4: Validate format with regex
    if (!_isValidEvsuEmail(emailLower)) {
      return {
        'valid': false,
        'message': 'Please enter a valid EVSU email ending with @evsu.edu.ph',
      };
    }

    // Step 5: Optional mailbox verification (MX check)
    // For now, we'll do basic validation. In production, you can add MX record check
    // or use an email deliverability API like ZeroBounce, NeverBounce, etc.
    try {
      // Basic validation: check if email format is correct
      // In a real implementation, you could:
      // 1. Check MX records for evsu.edu.ph domain
      // 2. Use an email verification API
      // 3. Send a test email and verify delivery

      // For now, we'll just validate the format is correct
      // The actual mailbox verification can be added later with an API call

      return {'valid': true, 'message': 'Email format is valid'};
    } catch (e) {
      return {'valid': false, 'message': 'Error validating email: $e'};
    }
  }

  /// Handle email field changes (no validation, validation happens on Register Account click)
  void _onEmailChanged(String email) {
    // No validation needed while typing
    // Validation will happen when Register Account button is clicked
  }

  /// Load available courses - only use hardcoded standard courses
  Future<void> _loadAvailableCourses() async {
    setState(() {
      _isLoadingCourses = true;
    });

    // Use only the standard EVSU courses (no database fetching)
    setState(() {
      _availableCourses = [
        'BEED',
        'BSIT',
        'BTVTED-FSM',
        'BEPED',
        'BSED-SCI',
        'BSEd-Math',
        'BSBA-HM',
        'BS-IndTech',
        'BSHM',
      ]..sort();
      _isLoadingCourses = false;
    });
  }

  /// Capitalize course name properly (handle special cases like BSIT, BSED-SCI, etc.)
  String _capitalizeCourse(String course) {
    if (course.isEmpty) return course;

    // Trim and convert to uppercase for standard course codes
    final trimmed = course.trim().toUpperCase();

    // Handle special cases with mixed case
    final specialCases = {
      'BSED-MATH': 'BSEd-Math',
      'BSED-SCI': 'BSED-SCI',
      'BSIT': 'BSIT',
      'BEED': 'BEED',
      'BEPED': 'BEPED',
      'BSBA-HM': 'BSBA-HM',
      'BS-INDTECH': 'BS-IndTech',
      'BTVTED-FSM': 'BTVTED-FSM',
      'BSHM': 'BSHM',
    };

    // Check if it matches a special case
    if (specialCases.containsKey(trimmed)) {
      return specialCases[trimmed]!;
    }

    // Default: return uppercase
    return trimmed;
  }

  /// Find matching course in available courses (case-insensitive)
  String? _findMatchingCourse(String courseFromDb) {
    if (courseFromDb.isEmpty) return null;

    final capitalized = _capitalizeCourse(courseFromDb);

    // First try exact match
    if (_availableCourses.contains(capitalized)) {
      return capitalized;
    }

    // Then try case-insensitive match
    for (var availableCourse in _availableCourses) {
      if (availableCourse.toUpperCase() == capitalized.toUpperCase()) {
        return availableCourse; // Return the properly capitalized version
      }
    }

    return null;
  }

  /// Build course dropdown widget
  Widget _buildCourseDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Course',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
            if (_isLoadingCourses) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: evsuRed,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _selectedCourse,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.book, color: evsuRed),
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
          hint: const Text('Select course'),
          items:
              _availableCourses.map((course) {
                return DropdownMenuItem<String>(
                  value: course,
                  child: Text(course),
                );
              }).toList(),
          onChanged: (String? value) {
            setState(() {
              _selectedCourse = value;
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please select a course';
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Format date string for display
  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  /// Show delete user confirmation dialog
  void _showDeleteUserDialog(String name, String email) {
    // Prevent staff from accessing delete dialog
    if (SessionService.isAdminStaff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Staff accounts do not have permission to delete users.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete User'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Are you sure you want to delete this user?'),
                const SizedBox(height: 12),
                Text('Name: $name'),
                Text('Email: $email'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action will permanently delete the user from both auth.users and auth_students tables. This cannot be undone.',
                          style: TextStyle(fontSize: 12),
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
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _deleteUser(email),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  /// Delete user from database
  Future<void> _deleteUser(String email) async {
    // Prevent staff from deleting users
    if (SessionService.isAdminStaff) {
      Navigator.pop(context); // Close dialog if open
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Staff accounts do not have permission to delete users.',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    Navigator.pop(context); // Close dialog

    // Show loading dialog
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Flexible(
                    child: Text(
                      'Deleting user...',
                      style: TextStyle(fontSize: isMobile ? 13 : 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );

    try {
      final result = await SupabaseService.deleteUser(email);

      Navigator.pop(context); // Close loading dialog

      if (result['success']) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Refresh the user directory
        _refreshUserDirectory();
      } else {
        // Show error message
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Failed'),
                  ],
                ),
                content: Text(result['message']),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete Error'),
                ],
              ),
              content: Text('An unexpected error occurred: $e'),
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

  /// Show user details dialog
  void _showUserDetailsDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('User Details'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Name', user['name']?.toString() ?? 'N/A'),
                  _buildDetailRow('Email', user['email']?.toString() ?? 'N/A'),
                  _buildDetailRow(
                    'Student ID',
                    user['student_id']?.toString() ?? 'N/A',
                  ),
                  _buildDetailRow(
                    'Course',
                    user['course']?.toString() ?? 'N/A',
                  ),
                  _buildDetailRow(
                    'RFID ID',
                    user['rfid_id']?.toString() ?? 'N/A',
                  ),
                  _buildDetailRow(
                    'Balance',
                    '₱${double.tryParse(user['balance']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                  ),
                  _buildDetailRow(
                    'Status',
                    user['is_active'] == true ? 'Active' : 'Inactive',
                  ),
                  _buildDetailRow(
                    'Created',
                    _formatDate(user['created_at']?.toString() ?? ''),
                  ),
                  _buildDetailRow(
                    'Auth User ID',
                    user['auth_user_id']?.toString() ?? 'N/A',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  /// Build detail row for user details dialog
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// Build confirm dialog row for registration confirmation
  Widget _buildConfirmDialogRow(
    String label,
    String value, {
    required bool isMobile,
    int maxLines = 1,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: isMobile ? 70 : 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 12 : 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: isMobile ? 12 : 13),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// Build styled detail card for confirmation dialog
  Widget _buildConfirmDialogDetailCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isMobile,
    int maxLines = 1,
    double? dialogWidth,
  }) {
    final isWideCard = dialogWidth != null && dialogWidth > 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 5 : 6),
            decoration: BoxDecoration(
              color: evsuRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: evsuRed, size: isMobile ? 16 : 18),
          ),
          SizedBox(width: isMobile ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize:
                        isMobile
                            ? 10
                            : isWideCard
                            ? 13
                            : 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: isMobile ? 3 : 4),
                SelectableText(
                  value,
                  style: TextStyle(
                    fontSize:
                        isMobile
                            ? 12
                            : isWideCard
                            ? 15
                            : 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.3,
                  ),
                  maxLines: maxLines,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Lookup student data when Student ID is entered for replacement
  void _onReplacementStudentIdChanged(String studentId) async {
    // Clear previous data first
    _replacementStudentNameController.clear();
    _replacementRfidController.clear();

    setState(() {
      _currentRfidId = null;
    });

    // Skip if student ID is empty or not in expected format
    // Expected format: 2022-23333 (YYYY-NNNNN = 10 characters with hyphen)
    // Only check when user has entered complete ID (exactly 10 characters)
    if (studentId.trim().isEmpty || studentId.trim().length < 10) {
      return;
    }

    setState(() {
      _isLoadingReplacementData = true;
    });

    try {
      // Fetch student data from auth_students table
      final result = await SupabaseService.getStudentByStudentId(
        studentId.trim(),
      );

      setState(() {
        _isLoadingReplacementData = false;
      });

      if (result['success'] && result['data'] != null) {
        final studentData = result['data'];

        setState(() {
          _replacementStudentNameController.text = studentData['name'] ?? '';
          _currentRfidId = studentData['rfid_id'];
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Student found: ${studentData['name']}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        // Student not found - show alert only if ID looks complete (10 characters)
        if (mounted && studentId.trim().length >= 10) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Student Not Registered'),
                    ],
                  ),
                  content: const Text(
                    'The entered Student ID is not registered in the system. '
                    'Please verify the Student ID or register the student first.',
                  ),
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
    } catch (e) {
      setState(() {
        _isLoadingReplacementData = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching student data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Build RFID card field for replacement
  Widget _buildReplacementRFIDCardField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'New RFID Card Number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _replacementRfidController,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.credit_card, color: evsuRed),
            hintText: 'Scan new RFID card',
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
        const SizedBox(height: 12),

        // Scan Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                (_isScanningRfid || !_isScannerConnected)
                    ? null
                    : _scanRFIDCardForReplacement,
            icon:
                _isScanningRfid
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                    : Icon(
                      _isScannerConnected
                          ? Icons.nfc
                          : Icons.bluetooth_disabled,
                      color: Colors.white,
                      size: 20,
                    ),
            label: Text(
              _isScanningRfid
                  ? 'Scanning New RFID Card...'
                  : _isScannerConnected
                  ? 'Scan New School ID Card'
                  : 'Connect Scanner First',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isScanningRfid
                      ? Colors.grey.shade400
                      : _isScannerConnected
                      ? Colors.blue.shade600
                      : Colors.grey.shade500,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: _isScanningRfid ? 0 : 2,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Scanner Status Indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color:
                _isScannerConnected
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color:
                  _isScannerConnected
                      ? Colors.green.shade200
                      : Colors.orange.shade200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isScannerConnected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                size: 16,
                color:
                    _isScannerConnected
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scanner: $_scannerStatus',
                  style: TextStyle(
                    fontSize: 12,
                    color:
                        _isScannerConnected
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Clear the ID replacement form
  void _clearReplacementForm() {
    setState(() {
      _replacementStudentIdController.clear();
      _replacementStudentNameController.clear();
      _replacementRfidController.clear();
      _currentRfidId = null;
    });
  }

  /// Perform RFID replacement process
  void _performRFIDReplacement() async {
    final String studentId = _replacementStudentIdController.text.trim();
    final String studentName = _replacementStudentNameController.text.trim();
    final String newRfidId = _replacementRfidController.text.trim();

    // Validate required fields
    if (studentId.isEmpty || studentName.isEmpty || newRfidId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all required fields and scan new RFID card',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Confirm RFID Replacement'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Replace RFID card for this student?'),
                  const SizedBox(height: 12),
                  Text(
                    'Student ID: $studentId',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text('Name: $studentName'),
                  const SizedBox(height: 12),
                  if (_currentRfidId != null && _currentRfidId!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Old RFID: $_currentRfidId',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'New RFID: $newRfidId',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Text('New RFID: $newRfidId'),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    'This will update the RFID card for this student.',
                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                child: const Text(
                  'Replace',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    // Show loading
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            content: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: isMobile ? 12 : 16),
                  Flexible(
                    child: Text(
                      'Replacing RFID card...',
                      style: TextStyle(fontSize: isMobile ? 13 : 14),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );

    try {
      // Perform RFID replacement in database
      final result = await SupabaseService.replaceRFIDCard(
        studentId: studentId,
        newRfidId: newRfidId,
        studentName: studentName,
        oldRfidId: _currentRfidId,
      );

      Navigator.pop(context); // Close loading dialog

      if (result['success']) {
        // Refresh RFID list when new replacement is done
        _refreshRecentRFIDList();

        // Show success dialog
        await showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Success'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RFID card successfully replaced!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Student: $studentName'),
                    Text('Student ID: $studentId'),
                    if (_currentRfidId != null &&
                        _currentRfidId!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Old RFID: $_currentRfidId',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    Text(
                      'New RFID: $newRfidId',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );

        // Clear the form after successful replacement
        _clearReplacementForm();
      } else {
        // Show error dialog
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Row(
                  children: [
                    Icon(Icons.error, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Replacement Failed'),
                  ],
                ),
                content: Text(result['message'] ?? 'Unknown error occurred'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.error, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Replacement Error'),
                ],
              ),
              content: Text('An unexpected error occurred: $e'),
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
