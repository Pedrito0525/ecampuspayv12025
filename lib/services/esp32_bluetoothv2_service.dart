import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ESP32BluetoothService {
  static const String esp32DeviceName = "EvsuPayScanner1";

  // BLE Service and Characteristic UUIDs (these will match ESP32 code)
  static const String serviceUUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String rxCharacteristicUUID =
      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // ESP32 receives
  static const String txCharacteristicUUID =
      "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // ESP32 transmits

  static BluetoothDevice? _connectedDevice;
  static BluetoothCharacteristic? _rxCharacteristic;
  static BluetoothCharacteristic? _txCharacteristic;
  static bool _isConnected = false;
  static bool _isScanning = false;
  static StreamSubscription<List<int>>? _characteristicSubscription;
  static StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  // Stream controllers for various events
  static final StreamController<Map<String, dynamic>> _rfidDataController =
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<bool> _connectionStatusController =
      StreamController<bool>.broadcast();
  static final StreamController<String> _statusMessageController =
      StreamController<String>.broadcast();

  // Getters for streams
  static Stream<Map<String, dynamic>> get rfidDataStream =>
      _rfidDataController.stream;
  static Stream<bool> get connectionStatusStream =>
      _connectionStatusController.stream;
  static Stream<String> get statusMessageStream =>
      _statusMessageController.stream;

  // Getters for current state
  static bool get isConnected => _isConnected;
  static bool get isScanning => _isScanning;
  static BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Initialize BLE - simple check for Bluetooth enabled
  static Future<bool> initialize() async {
    try {
      // Check if Bluetooth is supported
      if (await FlutterBluePlus.isSupported == false) {
        _statusMessageController.add('❌ BLE is not supported on this device');
        return false;
      }

      // Check if Bluetooth is enabled
      var adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _statusMessageController.add(
          '📱 Please turn on Bluetooth to connect to ESP32',
        );
        return false;
      }

      _statusMessageController.add(
        '✅ Bluetooth is on - ready to connect to ESP32',
      );
      return true;
    } catch (e) {
      _statusMessageController.add('❌ Bluetooth check failed: $e');
      return false;
    }
  }

  /// Check for already paired ESP32 devices
  static Future<List<BluetoothDevice>> getPairedESP32Devices() async {
    try {
      _statusMessageController.add('🔍 Checking for paired ESP32 devices...');

      List<BluetoothDevice> pairedDevices = [];

      // Get system bonded devices (paired via Android settings)
      List<BluetoothDevice> bondedDevices = await FlutterBluePlus.bondedDevices;

      for (BluetoothDevice device in bondedDevices) {
        String deviceName = device.platformName;
        if (deviceName.isEmpty) {
          deviceName = device.remoteId.toString();
        }

        _statusMessageController.add('📱 Found paired device: $deviceName');

        // Check if it's our ESP32 device
        if (deviceName.contains('ESP32') ||
            deviceName.contains('RFID') ||
            deviceName.contains(esp32DeviceName)) {
          pairedDevices.add(device);
          _statusMessageController.add('✅ Found paired ESP32: $deviceName');
        }
      }

      if (pairedDevices.isEmpty) {
        _statusMessageController.add('❌ No paired ESP32 devices found');
        _statusMessageController.add(
          '💡 Pair ESP32_RFID_Scanner in phone Bluetooth settings first',
        );
      } else {
        _statusMessageController.add(
          '✅ Found ${pairedDevices.length} paired ESP32 device(s)',
        );
      }

      return pairedDevices;
    } catch (e) {
      _statusMessageController.add('❌ Failed to check paired devices: $e');
      return [];
    }
  }

  /// Scan for ESP32 BLE devices
  static Future<List<BluetoothDevice>> scanForDevices() async {
    try {
      _statusMessageController.add('🔍 Scanning for ESP32 BLE devices...');

      List<BluetoothDevice> foundDevices = [];

      // Stop any ongoing scan first
      await FlutterBluePlus.stopScan();

      // Set up scan results listener BEFORE starting scan
      StreamSubscription? scanSubscription;

      scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          // Get device name (fallback to remoteId if empty)
          String deviceName = result.device.platformName;
          String advertisedName = result.advertisementData.localName;

          if (deviceName.isEmpty && advertisedName.isNotEmpty) {
            deviceName = advertisedName;
          }

          // Debug: log all discovered devices
          if (deviceName.isNotEmpty) {
            _statusMessageController.add('📱 Found device: $deviceName');
          }

          // More flexible matching for ESP32
          bool isESP32Device =
              deviceName.contains('ESP32') ||
              advertisedName.contains('ESP32') ||
              deviceName.contains('RFID') ||
              advertisedName.contains('RFID') ||
              deviceName.contains(esp32DeviceName) ||
              advertisedName.contains(esp32DeviceName);

          if (isESP32Device) {
            if (!foundDevices.any(
              (d) => d.remoteId == result.device.remoteId,
            )) {
              foundDevices.add(result.device);
              _statusMessageController.add(
                '✅ Found ESP32: $deviceName (${result.device.remoteId})',
              );
            }
          }
        }
      });

      // Start scanning with longer timeout
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        withServices: [], // Scan for all services
        withNames: [], // Scan for all names
      );

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 16));

      // Clean up
      await scanSubscription.cancel();
      await FlutterBluePlus.stopScan();

      _statusMessageController.add(
        '✅ Scan completed - Found ${foundDevices.length} ESP32 device(s)',
      );
      return foundDevices;
    } catch (e) {
      _statusMessageController.add('❌ Device scan failed: $e');
      return [];
    }
  }

  /// Connect to ESP32 BLE device
  static Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      _statusMessageController.add(
        '🔗 Connecting to ${device.platformName}...',
      );

      // Disconnect if already connected
      await disconnect();

      // Connect to the device
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find our custom service
      BluetoothService? targetService;
      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase() ==
            serviceUUID.toUpperCase()) {
          targetService = service;
          break;
        }
      }

      if (targetService == null) {
        throw Exception('ESP32 RFID service not found');
      }

      // Find RX and TX characteristics
      for (BluetoothCharacteristic characteristic
          in targetService.characteristics) {
        String charUuid = characteristic.uuid.toString().toUpperCase();
        if (charUuid == rxCharacteristicUUID.toUpperCase()) {
          _rxCharacteristic = characteristic;
        } else if (charUuid == txCharacteristicUUID.toUpperCase()) {
          _txCharacteristic = characteristic;
        }
      }

      if (_rxCharacteristic == null || _txCharacteristic == null) {
        throw Exception('Required characteristics not found');
      }

      // Subscribe to notifications from ESP32
      await _txCharacteristic!.setNotifyValue(true);
      _characteristicSubscription = _txCharacteristic!.lastValueStream.listen(
        _onDataReceived,
      );

      // Set up connection state monitoring to detect disconnections
      _connectionSubscription?.cancel();
      _connectionSubscription = device.connectionState.listen((state) {
        debugPrint('🔌 ESP32 BLE Connection state changed: $state');
        final bool wasConnected = _isConnected;
        _isConnected = (state == BluetoothConnectionState.connected);

        // If connection was lost, update state and notify listeners
        if (wasConnected && !_isConnected) {
          debugPrint('❌ ESP32 BLE Disconnected - updating UI state');
          // Update internal state
          _isScanning = false;
          // Cancel characteristic subscription
          _characteristicSubscription?.cancel();
          _characteristicSubscription = null;
          // Clear characteristics
          _rxCharacteristic = null;
          _txCharacteristic = null;
          // Clear device reference to ensure state is consistent
          // Note: The connection state listener will continue to work because
          // it's attached to the device object itself (captured in the closure)
          _connectedDevice = null;
          // Notify UI immediately via stream
          _connectionStatusController.add(false);
          _statusMessageController.add('🔌 Disconnected from ESP32 BLE');
        } else if (!wasConnected && _isConnected) {
          debugPrint('✅ ESP32 BLE Reconnected - updating UI state');
          // Notify UI of reconnection
          _connectionStatusController.add(true);
          _statusMessageController.add('✅ Reconnected to ESP32 BLE');
        }
      });

      _isConnected = true;
      _connectionStatusController.add(true);

      _statusMessageController.add(
        '✅ Connected to ESP32 BLE: ${device.platformName}',
      );

      // Send health check
      await Future.delayed(const Duration(milliseconds: 500));
      await _sendHealthCheck();

      return true;
    } catch (e) {
      _statusMessageController.add('❌ BLE Connection failed: $e');
      _isConnected = false;
      _connectionStatusController.add(false);
      return false;
    }
  }

  /// Handle incoming data from ESP32 via BLE
  static void _onDataReceived(List<int> data) {
    try {
      String receivedData = String.fromCharCodes(data);
      debugPrint('📥 Received from ESP32 BLE: $receivedData');

      // Process the received message
      if (receivedData.trim().isNotEmpty) {
        _processMessage(receivedData.trim());
      }
    } catch (e) {
      _statusMessageController.add('BLE data processing error: $e');
    }
  }

  /// Process individual message from ESP32
  static void _processMessage(String message) {
    try {
      Map<String, dynamic> data = json.decode(message);
      String messageType = data['type'] ?? '';

      switch (messageType) {
        case 'connection':
          _statusMessageController.add('✅ ESP32 BLE connection confirmed');
          break;

        case 'health_response':
          _statusMessageController.add('✅ ESP32 BLE health check OK');
          break;

        case 'scanner_started':
          _isScanning = true;
          _statusMessageController.add(
            '🎯 ESP32 scanner started - place RFID card near reader',
          );
          break;

        case 'rfid_scanned':
          _isScanning = false;
          _rfidDataController.add(data);
          _statusMessageController.add(
            '🔍 REAL RFID card detected: ${data['cardId']}',
          );
          break;

        case 'rfid_registration_scanned':
          _isScanning = false;
          // Add scan mode to distinguish registration scans
          data['scanMode'] = 'registration';
          _rfidDataController.add(data);
          _statusMessageController.add(
            '🎓 School ID card scanned: ${data['cardId']}',
          );
          break;

        case 'registration_scanner_started':
          _isScanning = true;
          _statusMessageController.add(
            '🎯 Registration scanner started - place School ID near reader',
          );
          break;

        case 'scan_timeout':
          _isScanning = false;
          _statusMessageController.add('⏰ Scan timeout - no card detected');
          break;

        case 'scanner_stopped':
          _isScanning = false;
          _statusMessageController.add('⏹️ Scanner stopped');
          break;

        case 'error':
          _statusMessageController.add('❌ ESP32 error: ${data['message']}');
          break;

        case 'heartbeat':
          // Silent heartbeat, just update scanning status
          _isScanning = data['scanning'] ?? false;
          break;

        default:
          debugPrint('Unknown ESP32 message type: $messageType');
      }
    } catch (e) {
      debugPrint('ESP32 message processing error: $e');
    }
  }

  /// Send command to ESP32 via BLE
  static Future<bool> _sendCommand(Map<String, dynamic> command) async {
    try {
      if (!_isConnected || _rxCharacteristic == null) {
        _statusMessageController.add('❌ Not connected to ESP32 BLE');
        return false;
      }

      String commandJson = json.encode(command);
      debugPrint('📤 Sending to ESP32 BLE: $commandJson');

      List<int> data = utf8.encode(commandJson);
      await _rxCharacteristic!.write(data);

      _statusMessageController.add(
        '📤 BLE Command sent: ${command['command']}',
      );
      return true;
    } catch (e) {
      _statusMessageController.add('BLE send command error: $e');
      return false;
    }
  }

  /// Send health check to ESP32
  static Future<bool> _sendHealthCheck() async {
    return await _sendCommand({'command': 'health_check'});
  }

  /// Start RFID scanner on ESP32 for payment
  static Future<bool> startPaymentScanner({
    required String paymentAccount,
    required double amount,
    required String itemName,
  }) async {
    try {
      if (!_isConnected) {
        _statusMessageController.add('❌ Not connected to ESP32 BLE scanner');
        return false;
      }

      Map<String, dynamic> command = {
        'command': 'start_scanner',
        'paymentAccount': paymentAccount,
        'amount': amount,
        'itemName': itemName,
      };

      bool success = await _sendCommand(command);
      if (success) {
        _statusMessageController.add('🎯 Payment scanner started on ESP32 BLE');
        debugPrint(
          '🎯 ESP32 Serial Monitor should now show: "=== SCANNER STARTED ==="',
        );
        debugPrint('🎯 ESP32 is now waiting to scan RFID card via BLE');
      }

      return success;
    } catch (e) {
      _statusMessageController.add('Start BLE scanner error: $e');
      return false;
    }
  }

  /// Start RFID scanner on ESP32 for registration
  static Future<bool> startRegistrationScanner() async {
    try {
      if (!_isConnected) {
        _statusMessageController.add('❌ Not connected to ESP32 BLE scanner');
        return false;
      }

      Map<String, dynamic> command = {'command': 'start_registration_scanner'};

      bool success = await _sendCommand(command);
      if (success) {
        _statusMessageController.add(
          '🎓 Registration scanner started on ESP32 BLE',
        );
        debugPrint(
          '🎓 ESP32 Serial Monitor should now show: "=== REGISTRATION SCANNER STARTED ==="',
        );
        debugPrint('🎓 ESP32 is now waiting to scan School ID card via BLE');
      }

      return success;
    } catch (e) {
      _statusMessageController.add('Start registration BLE scanner error: $e');
      return false;
    }
  }

  /// Stop RFID scanner on ESP32
  static Future<bool> stopScanner() async {
    try {
      if (!_isConnected) {
        return true; // Already stopped
      }

      bool success = await _sendCommand({'command': 'stop_scanner'});
      if (success) {
        _isScanning = false;
        _statusMessageController.add('⏹️ ESP32 BLE scanner stopped');
      }

      return success;
    } catch (e) {
      _statusMessageController.add('Stop BLE scanner error: $e');
      return false;
    }
  }

  /// Test RFID scanner on ESP32
  static Future<bool> testRfidScanner() async {
    try {
      if (!_isConnected) {
        _statusMessageController.add('❌ Not connected to ESP32 BLE scanner');
        return false;
      }

      bool success = await _sendCommand({'command': 'test_rfid'});
      if (success) {
        _statusMessageController.add('🧪 RFID test command sent to ESP32 BLE');
      }

      return success;
    } catch (e) {
      _statusMessageController.add('Test BLE scanner error: $e');
      return false;
    }
  }

  /// Get scanner status from ESP32
  static Future<bool> getStatus() async {
    try {
      if (!_isConnected) {
        return false;
      }

      return await _sendCommand({'command': 'get_status'});
    } catch (e) {
      _statusMessageController.add('Get BLE status error: $e');
      return false;
    }
  }

  /// Disconnect from ESP32 BLE
  static Future<void> disconnect() async {
    try {
      // Cancel connection state subscription first
      _connectionSubscription?.cancel();
      _connectionSubscription = null;

      _characteristicSubscription?.cancel();
      _characteristicSubscription = null;

      if (_connectedDevice != null) {
        await stopScanner();
        await _connectedDevice!.disconnect();
      }

      _connectedDevice = null;
      _rxCharacteristic = null;
      _txCharacteristic = null;
      _isConnected = false;
      _isScanning = false;

      _connectionStatusController.add(false);
      _statusMessageController.add('🔌 Disconnected from ESP32 BLE');
    } catch (e) {
      _statusMessageController.add('BLE disconnect error: $e');
    }
  }

  /// Save preferred ESP32 device for auto-connection
  static Future<void> savePreferredDevice(BluetoothDevice device) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save device info as JSON
      Map<String, String> deviceInfo = {
        'id': device.remoteId.toString(),
        'name':
            device.platformName.isNotEmpty
                ? device.platformName
                : 'ESP32_Scanner',
        'lastConnected': DateTime.now().toIso8601String(),
      };

      // Get existing preferred devices
      List<String> existingDevices =
          prefs.getStringList('preferred_esp32_devices') ?? [];

      // Remove existing entry if it exists (to avoid duplicates)
      existingDevices.removeWhere((deviceJson) {
        Map<String, dynamic> existing = Map<String, dynamic>.from(
          json.decode(deviceJson),
        );
        return existing['id'] == deviceInfo['id'];
      });

      // Add current device to the top of the list
      existingDevices.insert(0, json.encode(deviceInfo));

      // Keep only the last 5 devices
      if (existingDevices.length > 5) {
        existingDevices = existingDevices.take(5).toList();
      }

      await prefs.setStringList('preferred_esp32_devices', existingDevices);
      _statusMessageController.add('✅ ESP32 device saved to preferred list');
    } catch (e) {
      _statusMessageController.add('Failed to save preferred device: $e');
    }
  }

  /// Get list of preferred ESP32 devices
  static Future<List<Map<String, String>>> getPreferredDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> deviceStrings =
          prefs.getStringList('preferred_esp32_devices') ?? [];

      List<Map<String, String>> devices = [];
      for (String deviceString in deviceStrings) {
        Map<String, dynamic> deviceData = json.decode(deviceString);
        devices.add(Map<String, String>.from(deviceData));
      }

      return devices;
    } catch (e) {
      _statusMessageController.add('Failed to load preferred devices: $e');
      return [];
    }
  }

  /// Remove device from preferred list
  static Future<void> removePreferredDevice(String deviceId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> existingDevices =
          prefs.getStringList('preferred_esp32_devices') ?? [];

      existingDevices.removeWhere((deviceJson) {
        Map<String, dynamic> existing = Map<String, dynamic>.from(
          json.decode(deviceJson),
        );
        return existing['id'] == deviceId;
      });

      await prefs.setStringList('preferred_esp32_devices', existingDevices);
      _statusMessageController.add('✅ Device removed from preferred list');
    } catch (e) {
      _statusMessageController.add('Failed to remove preferred device: $e');
    }
  }

  /// Auto-connect to preferred ESP32 devices
  static Future<bool> autoConnectToPreferredDevice() async {
    try {
      _statusMessageController.add('🔄 Attempting auto-connection...');

      // Get preferred devices
      List<Map<String, String>> preferredDevices = await getPreferredDevices();
      if (preferredDevices.isEmpty) {
        _statusMessageController.add(
          '📱 No preferred devices found - will try paired devices',
        );
        return await autoConnectToPairedDevices();
      }

      // Try to connect to each preferred device
      for (Map<String, String> deviceInfo in preferredDevices) {
        String deviceId = deviceInfo['id'] ?? '';
        String deviceName = deviceInfo['name'] ?? 'Unknown';

        _statusMessageController.add(
          '🔍 Looking for preferred device: $deviceName',
        );

        // First check bonded/paired devices
        List<BluetoothDevice> bondedDevices =
            await FlutterBluePlus.bondedDevices;
        for (BluetoothDevice device in bondedDevices) {
          if (device.remoteId.toString() == deviceId) {
            _statusMessageController.add(
              '📱 Found preferred device in paired list: $deviceName',
            );
            bool connected = await connectToDevice(device);
            if (connected) {
              _statusMessageController.add(
                '✅ Auto-connected to preferred device: $deviceName',
              );
              return true;
            }
          }
        }

        // If not found in bonded devices, try scanning
        _statusMessageController.add(
          '🔍 Scanning for preferred device: $deviceName',
        );
        List<BluetoothDevice> scannedDevices = await scanForDevices();
        for (BluetoothDevice device in scannedDevices) {
          if (device.remoteId.toString() == deviceId) {
            _statusMessageController.add(
              '📡 Found preferred device via scan: $deviceName',
            );
            bool connected = await connectToDevice(device);
            if (connected) {
              _statusMessageController.add(
                '✅ Auto-connected to preferred device: $deviceName',
              );
              return true;
            }
          }
        }
      }

      _statusMessageController.add(
        '❌ Could not auto-connect to any preferred device',
      );
      return false;
    } catch (e) {
      _statusMessageController.add('Auto-connect error: $e');
      return false;
    }
  }

  /// Auto-connect to any paired ESP32 devices
  static Future<bool> autoConnectToPairedDevices() async {
    try {
      List<BluetoothDevice> pairedDevices = await getPairedESP32Devices();

      for (BluetoothDevice device in pairedDevices) {
        _statusMessageController.add(
          '🔗 Trying to connect to: ${device.platformName}',
        );
        bool connected = await connectToDevice(device);
        if (connected) {
          // Save as preferred device
          await savePreferredDevice(device);
          _statusMessageController.add(
            '✅ Auto-connected to: ${device.platformName}',
          );
          return true;
        }
      }

      _statusMessageController.add(
        '❌ Could not auto-connect to any paired device',
      );
      return false;
    } catch (e) {
      _statusMessageController.add('Auto-connect to paired devices error: $e');
      return false;
    }
  }

  /// Get current connected scanner info
  static Map<String, String>? getConnectedScannerInfo() {
    if (_connectedDevice != null && _isConnected) {
      return {
        'id': _connectedDevice!.remoteId.toString(),
        'name':
            _connectedDevice!.platformName.isNotEmpty
                ? _connectedDevice!.platformName
                : 'ESP32_Scanner',
        'status': 'Connected',
        'scanning': _isScanning ? 'Yes' : 'No',
      };
    }
    return null;
  }

  /// Enhanced connect method that also saves as preferred
  static Future<bool> connectAndSaveDevice(BluetoothDevice device) async {
    bool connected = await connectToDevice(device);
    if (connected) {
      await savePreferredDevice(device);
    }
    return connected;
  }

  /// Dispose resources
  static void dispose() {
    _connectionSubscription?.cancel();
    _characteristicSubscription?.cancel();
    _rfidDataController.close();
    _connectionStatusController.close();
    _statusMessageController.close();
  }
}
