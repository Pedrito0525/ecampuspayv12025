import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

/// Bluetooth service specifically for service account scanner connections
/// Maps database scanner IDs to actual device names
class ESP32BluetoothServiceAccount {
  // BLE Service and Characteristic UUIDs (must match ESP32 code)
  static const String serviceUUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String rxCharacteristicUUID =
      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // ESP32 receives (WRITE)
  static const String txCharacteristicUUID =
      "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // ESP32 transmits (NOTIFY)
  static BluetoothDevice? _connectedDevice;
  static StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  static BluetoothCharacteristic? _rxCharacteristic;
  static BluetoothCharacteristic? _txCharacteristic;
  static bool _isInitialized = false;
  static bool _isConnected = false;
  static bool _isConnecting = false;
  static String? _connectedDeviceName;
  static String?
  _currentServiceScannerId; // Track which scanner this service should use

  // Stream controller for RFID data
  static final StreamController<String> _rfidController =
      StreamController<String>.broadcast();
  static Stream<String> get rfidDataStream => _rfidController.stream;

  // Mapping from database scanner_id to allowed device names
  // Enforce strict matching: only the exact assigned name (case-insensitive)
  static Map<String, List<String>> _getScannerDeviceMapping(String scannerId) {
    return {
      scannerId: [scannerId, scannerId.toUpperCase(), scannerId.toLowerCase()],
    };
  }

  /// Get the allowed device names for a scanner ID (strict)
  static List<String> getDeviceNamesForScannerId(String scannerId) {
    // Get dynamic mapping for this scanner ID
    Map<String, List<String>> mapping = _getScannerDeviceMapping(scannerId);
    List<String> deviceNames = mapping[scannerId] ?? [];

    // Remove duplicates
    deviceNames = deviceNames.toSet().toList();

    print("DEBUG ServiceBT: Device names for $scannerId: $deviceNames");
    return deviceNames;
  }

  /// Check if device name matches the target scanner strictly (case-insensitive exact)
  static bool isDeviceNameMatch(String deviceName, String targetScannerId) {
    print(
      "DEBUG ServiceBT: Checking if '$deviceName' matches target '$targetScannerId'",
    );
    // Strict: case-insensitive equality only
    final bool match =
        deviceName.trim().toLowerCase() == targetScannerId.trim().toLowerCase();
    if (match) {
      print("DEBUG ServiceBT: ✅ STRICT MATCH: $deviceName == $targetScannerId");
    } else {
      print(
        "DEBUG ServiceBT: ❌ STRICT NO MATCH: '$deviceName' != '$targetScannerId'",
      );
    }
    return match;
  }

  /// Initialize the Bluetooth service
  static Future<bool> initialize() async {
    try {
      print(
        "DEBUG ServiceBT: Initializing Bluetooth service for service accounts",
      );

      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        print("DEBUG ServiceBT: Bluetooth not supported by this device");
        return false;
      }

      // Check permissions (Android 12+)
      if (Platform.isAndroid) {
        bool permissionsGranted = await _requestBluetoothPermissions();
        if (!permissionsGranted) {
          print("DEBUG ServiceBT: Bluetooth permissions not granted");
          return false;
        }
      }

      _isInitialized = true;
      print("DEBUG ServiceBT: Bluetooth service initialized successfully");
      return true;
    } catch (e) {
      print("DEBUG ServiceBT: Error initializing Bluetooth: $e");
      return false;
    }
  }

  /// Request Bluetooth permissions for Android 12+
  static Future<bool> _requestBluetoothPermissions() async {
    try {
      Map<Permission, PermissionStatus> permissions =
          await [
            Permission.bluetoothConnect,
            Permission.bluetoothScan,
          ].request();

      bool bluetoothConnectGranted =
          permissions[Permission.bluetoothConnect]?.isGranted ?? false;
      bool bluetoothScanGranted =
          permissions[Permission.bluetoothScan]?.isGranted ?? false;

      return bluetoothConnectGranted && bluetoothScanGranted;
    } catch (e) {
      print("DEBUG ServiceBT: Error requesting permissions: $e");
      return false;
    }
  }

  /// Check if currently connected
  static bool get isConnected => _isConnected;
  static bool get isConnecting => _isConnecting;

  /// Get connected device information
  static Map<String, dynamic>? getConnectedDeviceInfo() {
    if (_connectedDevice != null && _isConnected) {
      return {
        'name': _connectedDeviceName ?? _connectedDevice!.platformName,
        'id': _connectedDevice!.remoteId.toString(),
        'type': 'ESP32_RFID_Scanner',
      };
    }
    return null;
  }

  /// Connect to a specific scanner by database ID
  static Future<bool> connectToAssignedScanner(String scannerId) async {
    try {
      print(
        "DEBUG ServiceBT: Service requesting connection to scanner: $scannerId",
      );
      print(
        "DEBUG ServiceBT: Previous service scanner: ${_currentServiceScannerId ?? 'None'}",
      );

      if (!_isInitialized) {
        bool initialized = await initialize();
        if (!initialized) return false;
      }

      if (_isConnecting) {
        print(
          "DEBUG ServiceBT: Skipping connect attempt; already connecting...",
        );
        return false;
      }

      // Check if we need to switch to a different scanner
      if (_currentServiceScannerId != null &&
          _currentServiceScannerId != scannerId) {
        print(
          "DEBUG ServiceBT: Service switching from $_currentServiceScannerId to $scannerId",
        );
        await disconnect(); // Disconnect from previous scanner
      }

      // Update the current service's assigned scanner
      _currentServiceScannerId = scannerId;

      // Check if already connected to the right scanner
      if (_isConnected && _connectedDevice != null) {
        String currentDeviceName =
            _connectedDeviceName ?? _connectedDevice!.platformName;
        if (isDeviceNameMatch(currentDeviceName, scannerId)) {
          print(
            "DEBUG ServiceBT: Already connected to correct scanner: $currentDeviceName for service scanner: $scannerId",
          );
          return true;
        } else {
          print(
            "DEBUG ServiceBT: Connected to wrong scanner ($currentDeviceName), need $scannerId",
          );
          await disconnect();
        }
      }

      // Try to find and connect to the target scanner
      _isConnecting = true;
      bool connected = await _findAndConnectToScanner(scannerId);
      _isConnecting = false;
      return connected;
    } catch (e) {
      print("DEBUG ServiceBT: Error connecting to assigned scanner: $e");
      _isConnecting = false;
      return false;
    }
  }

  /// Find and connect to a specific scanner
  static Future<bool> _findAndConnectToScanner(String scannerId) async {
    try {
      // First try connected devices (already connected via system Bluetooth)
      print("DEBUG ServiceBT: Checking system connected devices...");
      List<BluetoothDevice> systemDevices = await FlutterBluePlus.systemDevices(
        [],
      );

      for (BluetoothDevice device in systemDevices) {
        print(
          "DEBUG ServiceBT: Checking system device: ${device.platformName}",
        );
        if (isDeviceNameMatch(device.platformName, scannerId)) {
          print(
            "DEBUG ServiceBT: Found target scanner in system devices: ${device.platformName}",
          );
          bool success = await _connectToDevice(device);
          if (success) return true;
        }
      }

      // Then try bonded/paired devices
      print("DEBUG ServiceBT: Checking bonded devices...");
      List<BluetoothDevice> bondedDevices = await FlutterBluePlus.bondedDevices;

      for (BluetoothDevice device in bondedDevices) {
        String deviceName = device.platformName;
        print(
          "DEBUG ServiceBT: Checking bonded device: '$deviceName' (ID: ${device.remoteId})",
        );

        // Show all potential matches for debugging
        List<String> expectedNames = getDeviceNamesForScannerId(scannerId);
        print("DEBUG ServiceBT: Expected device names: $expectedNames");

        if (isDeviceNameMatch(deviceName, scannerId)) {
          print(
            "DEBUG ServiceBT: ✅ MATCH! Found target scanner in bonded devices: '$deviceName'",
          );
          bool connected = await _connectToDevice(device);
          if (connected) return true;
        } else {
          print(
            "DEBUG ServiceBT: ❌ No match for '$deviceName' against target '$scannerId'",
          );
        }
      }

      // Finally try scanning for devices
      print("DEBUG ServiceBT: Scanning for devices...");
      bool scanSuccess = await _scanAndConnect(scannerId);
      return scanSuccess;
    } catch (e) {
      print("DEBUG ServiceBT: Error finding scanner: $e");
      return false;
    }
  }

  /// Scan for devices and connect to target scanner
  static Future<bool> _scanAndConnect(String scannerId) async {
    final Completer<bool> completer = Completer<bool>();
    StreamSubscription? scanSubscription;
    try {
      print("DEBUG ServiceBT: Starting scan for target: $scannerId");
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));

      scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        if (completer.isCompleted) return;
        for (ScanResult result in results) {
          final BluetoothDevice device = result.device;
          final String deviceName = device.platformName;
          print("DEBUG ServiceBT: Found device during scan: $deviceName");
          if (isDeviceNameMatch(deviceName, scannerId)) {
            print(
              "DEBUG ServiceBT: Target scanner found during scan: $deviceName",
            );
            await FlutterBluePlus.stopScan();
            await scanSubscription?.cancel();
            final bool ok = await _connectToDevice(device);
            if (!completer.isCompleted) completer.complete(ok);
            return;
          }
        }
      });

      // Fallback timeout: complete based on connection state when scan ends
      Future.delayed(const Duration(seconds: 7)).then((_) async {
        if (!completer.isCompleted) {
          await scanSubscription?.cancel();
          await FlutterBluePlus.stopScan();
          completer.complete(_isConnected);
        }
      });

      return await completer.future;
    } catch (e) {
      print("DEBUG ServiceBT: Error during scan: $e");
      try {
        await scanSubscription?.cancel();
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      return false;
    }
  }

  /// Connect to a specific BluetoothDevice
  static Future<bool> _connectToDevice(BluetoothDevice device) async {
    try {
      print(
        "DEBUG ServiceBT: Attempting to connect to device: ${device.platformName}",
      );

      // Disconnect any existing connection
      if (_connectedDevice != null) {
        await disconnect();
      }

      // Connect to the device
      await device.connect(timeout: const Duration(seconds: 10));

      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      print("DEBUG ServiceBT: Discovered ${services.length} services");

      // Find target service by UUID
      BluetoothService? targetService;
      for (final s in services) {
        if (s.uuid.toString().toUpperCase() == serviceUUID.toUpperCase()) {
          targetService = s;
          break;
        }
      }
      targetService ??= services.isNotEmpty ? services.first : null;

      // Find RX (write) and TX (notify) characteristics
      if (targetService != null) {
        for (final c in targetService.characteristics) {
          final cu = c.uuid.toString().toUpperCase();
          if (cu == rxCharacteristicUUID.toUpperCase()) {
            _rxCharacteristic = c;
          } else if (cu == txCharacteristicUUID.toUpperCase()) {
            _txCharacteristic = c;
          }
        }

        // Fallbacks if UUID match failed
        _rxCharacteristic ??= targetService.characteristics.firstWhere(
          (c) => c.properties.write || c.properties.writeWithoutResponse,
          orElse: () => targetService!.characteristics.first,
        );
        _txCharacteristic ??= targetService.characteristics.firstWhere(
          (c) => c.properties.notify,
          orElse: () => targetService!.characteristics.first,
        );

        // Enable notifications on TX
        if (_txCharacteristic != null && _txCharacteristic!.properties.notify) {
          await _txCharacteristic!.setNotifyValue(true);
          _txCharacteristic!.lastValueStream.listen((value) {
            if (value.isNotEmpty) {
              final String received = String.fromCharCodes(value).trim();
              print("DEBUG ServiceBT: NOTIFY: $received");
              // Enforce that only the assigned scanner can send data
              final String currentDeviceName =
                  _connectedDeviceName ?? _connectedDevice?.platformName ?? '';
              if (_currentServiceScannerId != null &&
                  !isDeviceNameMatch(
                    currentDeviceName,
                    _currentServiceScannerId!,
                  )) {
                print(
                  "DEBUG ServiceBT: Ignoring data from non-assigned device '$currentDeviceName' (assigned: '${_currentServiceScannerId!}')",
                );
                return;
              }
              // Try JSON first
              try {
                final dynamic parsed = json.decode(received);
                if (parsed is Map<String, dynamic>) {
                  final String type = parsed['type']?.toString() ?? '';
                  // Ignore heartbeats and status
                  if (type == 'heartbeat' || type == 'status') return;

                  // Primary event types
                  if (type == 'rfid_scanned' ||
                      type == 'rfid_registration_scanned') {
                    final String cardId = parsed['cardId']?.toString() ?? '';
                    if (cardId.isNotEmpty) {
                      _rfidController.add(cardId);
                      return;
                    }
                  }

                  // Fallbacks: different key names or nested data
                  final candidates = <dynamic>[
                    parsed['rfid'],
                    parsed['cardId'],
                    parsed['uid'],
                    parsed['id'],
                    (parsed['data'] is Map)
                        ? ((parsed['data'] as Map)['rfid'] ??
                            (parsed['data'] as Map)['id'])
                        : null,
                  ];
                  for (final c in candidates) {
                    if (c != null && c.toString().trim().isNotEmpty) {
                      _rfidController.add(c.toString().trim());
                      return;
                    }
                  }
                }
              } catch (_) {
                // Fallback: assume the received string is the card id
                if (received.isNotEmpty) {
                  _rfidController.add(received);
                }
              }
            }
          });
        }
      }

      // Set up connection monitoring
      _connectionSubscription = device.connectionState.listen((state) {
        print("DEBUG ServiceBT: Connection state changed: $state");
        _isConnected = (state == BluetoothConnectionState.connected);

        if (!_isConnected) {
          _connectedDevice = null;
          _connectedDeviceName = null;
          _rxCharacteristic = null;
          _txCharacteristic = null;
        }
      });

      _connectedDevice = device;
      _connectedDeviceName = device.platformName;
      _isConnected = true;

      print(
        "DEBUG ServiceBT: Successfully connected to: ${device.platformName}",
      );
      return true;
    } catch (e) {
      print("DEBUG ServiceBT: Error connecting to device: $e");
      return false;
    }
  }

  /// Start payment scanning mode
  static Future<bool> startPaymentScanner(
    String serviceName,
    double amount,
    String productName,
  ) async {
    try {
      if (!_isConnected || _rxCharacteristic == null) {
        print("DEBUG ServiceBT: Cannot start payment scanner - not connected");
        return false;
      }

      // Send JSON command as expected by ESP32 firmware (processBluetoothMessage)
      final Map<String, dynamic> payload = {
        'command': 'start_scanner',
        'paymentAccount': serviceName,
        'amount': amount,
        'itemName': productName,
      };
      final String commandJson = json.encode(payload);
      final List<int> data = commandJson.codeUnits;

      if (_rxCharacteristic!.properties.write) {
        await _rxCharacteristic!.write(data, withoutResponse: false);
      } else if (_rxCharacteristic!.properties.writeWithoutResponse) {
        await _rxCharacteristic!.write(data, withoutResponse: true);
      } else {
        print("DEBUG ServiceBT: RX characteristic is not writable");
        return false;
      }
      print("DEBUG ServiceBT: Sent start_scanner JSON to ESP32: $commandJson");
      return true;
    } catch (e) {
      print("DEBUG ServiceBT: Error starting payment scanner: $e");
      return false;
    }
  }

  /// Stop the scanner
  static Future<void> stopScanner() async {
    try {
      if (_rxCharacteristic != null) {
        // Send JSON stop command to match ESP32 firmware
        final String commandJson = json.encode({'command': 'stop_scanner'});
        await _rxCharacteristic!.write(commandJson.codeUnits);
        print("DEBUG ServiceBT: Sent stop_scanner JSON to ESP32");
      }
    } catch (e) {
      print("DEBUG ServiceBT: Error stopping scanner: $e");
    }
  }

  /// Disconnect from the current device
  static Future<void> disconnect() async {
    try {
      await stopScanner();

      if (_connectionSubscription != null) {
        await _connectionSubscription!.cancel();
        _connectionSubscription = null;
      }

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
        print("DEBUG ServiceBT: Disconnected from device");
      }

      _connectedDevice = null;
      _connectedDeviceName = null;
      _rxCharacteristic = null;
      _txCharacteristic = null;
      _isConnected = false;
      _currentServiceScannerId = null; // Clear the service scanner assignment
    } catch (e) {
      print("DEBUG ServiceBT: Error during disconnect: $e");
    }
  }

  /// Dispose of the service
  static void dispose() {
    disconnect();
    _rfidController.close();
  }
}
