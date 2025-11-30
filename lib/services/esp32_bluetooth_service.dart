import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class Esp32BluetoothService {
  static const String TARGET_DEVICE_NAME = "EvsuPayScanner1";
  static const String SERVICE_UUID = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";
  static const String CHARACTERISTIC_UUID_RX =
      "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; // Flutter sends
  static const String CHARACTERISTIC_UUID_TX =
      "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"; // Flutter receives

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _txCharacteristic;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notificationSubscription;

  // Connection state
  bool _isConnected = false;
  bool _isScanning = false;
  String _connectionStatus = "Disconnected";

  // Streams for UI updates
  final StreamController<String> _connectionStatusController =
      StreamController<String>.broadcast();
  final StreamController<Map<String, dynamic>> _rfidDataController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Getters for streams
  Stream<String> get connectionStatusStream =>
      _connectionStatusController.stream;
  Stream<Map<String, dynamic>> get rfidDataStream => _rfidDataController.stream;
  Stream<String> get errorStream => _errorController.stream;

  // Getters for state
  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  String get connectionStatus => _connectionStatus;

  // Singleton pattern
  static final Esp32BluetoothService _instance =
      Esp32BluetoothService._internal();
  factory Esp32BluetoothService() => _instance;
  Esp32BluetoothService._internal();

  /// Initialize Bluetooth permissions and check if Bluetooth is available
  Future<bool> initialize() async {
    try {
      // Check if Bluetooth is supported
      if (!await FlutterBluePlus.isSupported) {
        _updateError("Bluetooth is not supported on this device");
        return false;
      }

      // Request permissions
      await _requestPermissions();

      // Check if Bluetooth is turned on
      final adapterState = await FlutterBluePlus.adapterState.first;
      if (adapterState != BluetoothAdapterState.on) {
        _updateError("Please enable Bluetooth to use RFID scanning");
        return false;
      }

      _updateConnectionStatus("Bluetooth ready");
      return true;
    } catch (e) {
      _updateError("Failed to initialize Bluetooth: $e");
      return false;
    }
  }

  /// Request necessary permissions for Bluetooth
  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> permissions =
        await [
          Permission.bluetooth,
          Permission.bluetoothConnect,
          Permission.bluetoothScan,
          Permission.location,
        ].request();

    bool allGranted = permissions.values.every((status) => status.isGranted);
    if (!allGranted) {
      throw Exception("Bluetooth permissions not granted");
    }
  }

  /// Scan for ESP32 device and connect
  Future<bool> connectToScanner() async {
    try {
      _updateConnectionStatus("Scanning for scanner...");

      // Stop any existing scan
      await stopScan();

      // Start scanning
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          if (result.device.platformName == TARGET_DEVICE_NAME) {
            print("Found ESP32 scanner: ${result.device.platformName}");
            _connectToDevice(result.device);
            return;
          }
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [Guid(SERVICE_UUID)],
      );

      // Wait for connection or timeout
      await Future.delayed(const Duration(seconds: 12));

      if (!_isConnected) {
        _updateError(
          "Scanner not found. Make sure ESP32 is powered on and nearby.",
        );
        return false;
      }

      return true;
    } catch (e) {
      _updateError("Failed to connect to scanner: $e");
      return false;
    }
  }

  /// Connect to a specific device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await stopScan();
      _updateConnectionStatus("Connecting to scanner...");

      _connectedDevice = device;

      // Listen for connection state changes
      _connectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.connected) {
          _isConnected = true;
          _updateConnectionStatus("Connected to scanner");
          _discoverServices();
        } else {
          _isConnected = false;
          _updateConnectionStatus("Disconnected from scanner");
        }
      });

      // Connect to device
      await device.connect(timeout: const Duration(seconds: 10));
    } catch (e) {
      _updateError("Failed to connect to device: $e");
      _isConnected = false;
    }
  }

  /// Discover services and characteristics
  Future<void> _discoverServices() async {
    try {
      if (_connectedDevice == null) return;

      _updateConnectionStatus("Setting up communication...");

      List<BluetoothService> services =
          await _connectedDevice!.discoverServices();

      for (BluetoothService service in services) {
        if (service.uuid.toString().toUpperCase() ==
            SERVICE_UUID.toUpperCase()) {
          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            String charUuid = characteristic.uuid.toString().toUpperCase();

            if (charUuid == CHARACTERISTIC_UUID_RX.toUpperCase()) {
              _rxCharacteristic = characteristic;
            } else if (charUuid == CHARACTERISTIC_UUID_TX.toUpperCase()) {
              _txCharacteristic = characteristic;

              // Enable notifications for receiving data
              await characteristic.setNotifyValue(true);
              _notificationSubscription = characteristic.lastValueStream.listen(
                (value) {
                  _handleReceivedData(value);
                },
              );
            }
          }
        }
      }

      if (_rxCharacteristic != null && _txCharacteristic != null) {
        _updateConnectionStatus("Scanner ready for use");

        // Send health check to confirm communication
        await _sendCommand({"command": "health_check"});
      } else {
        _updateError("Failed to find scanner communication channels");
      }
    } catch (e) {
      _updateError("Failed to set up communication: $e");
    }
  }

  /// Handle received data from ESP32
  void _handleReceivedData(List<int> data) {
    try {
      String jsonString = utf8.decode(data);
      Map<String, dynamic> message = json.decode(jsonString);

      print("Received from ESP32: $jsonString");

      String messageType = message['type'] ?? '';

      switch (messageType) {
        case 'connection':
          _updateConnectionStatus("Scanner connected and ready");
          break;
        case 'health_response':
          _updateConnectionStatus("Scanner online and healthy");
          break;
        case 'rfid_scanned':
          _handleRfidScanned(message);
          break;
        case 'rfid_registration_scanned':
          _handleRegistrationRfidScanned(message);
          break;
        case 'error':
          _updateError("Scanner error: ${message['message']}");
          break;
        case 'scan_timeout':
          _updateError("Scan timeout - no card detected");
          break;
        case 'scanner_stopped':
          _updateConnectionStatus("Scanner stopped");
          break;
        default:
          print("Unknown message type: $messageType");
      }
    } catch (e) {
      print("Error parsing received data: $e");
    }
  }

  /// Handle RFID scan result
  void _handleRfidScanned(Map<String, dynamic> message) {
    _rfidDataController.add({
      'cardId': message['cardId'],
      'cardType': message['cardType'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'success': true,
      'scanMode': 'payment',
    });
  }

  /// Handle registration RFID scan result
  void _handleRegistrationRfidScanned(Map<String, dynamic> message) {
    _rfidDataController.add({
      'cardId': message['cardId'],
      'cardType': message['cardType'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'success': true,
      'scanMode': 'registration',
    });
  }

  /// Start RFID scanning for registration
  Future<bool> startRegistrationScan() async {
    if (!_isConnected || _rxCharacteristic == null) {
      _updateError("Scanner not connected");
      return false;
    }

    try {
      await _sendCommand({"command": "start_registration_scanner"});

      _isScanning = true;
      _updateConnectionStatus("Scanning for School ID card...");
      return true;
    } catch (e) {
      _updateError("Failed to start scanning: $e");
      return false;
    }
  }

  /// Stop RFID scanning
  Future<void> stopScanning() async {
    if (_isConnected && _rxCharacteristic != null) {
      try {
        await _sendCommand({"command": "stop_scanner"});
      } catch (e) {
        print("Error stopping scanner: $e");
      }
    }
    _isScanning = false;
  }

  /// Send command to ESP32
  Future<void> _sendCommand(Map<String, dynamic> command) async {
    if (_rxCharacteristic == null) return;

    try {
      String jsonString = json.encode(command);
      List<int> data = utf8.encode(jsonString);
      await _rxCharacteristic!.write(data);
      print("Sent to ESP32: $jsonString");
    } catch (e) {
      print("Error sending command: $e");
      throw e;
    }
  }

  /// Test RFID functionality
  Future<void> testRfid() async {
    if (!_isConnected || _rxCharacteristic == null) {
      _updateError("Scanner not connected");
      return;
    }

    try {
      await _sendCommand({"command": "test_rfid"});
      _updateConnectionStatus("Testing RFID scanner...");
    } catch (e) {
      _updateError("Failed to test RFID: $e");
    }
  }

  /// Stop scanning for devices
  Future<void> stopScan() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
      _scanSubscription?.cancel();
    } catch (e) {
      print("Error stopping scan: $e");
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    try {
      await stopScanning();
      await stopScan();

      _notificationSubscription?.cancel();
      _connectionSubscription?.cancel();

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      _connectedDevice = null;
      _rxCharacteristic = null;
      _txCharacteristic = null;
      _isConnected = false;
      _isScanning = false;

      _updateConnectionStatus("Disconnected");
    } catch (e) {
      print("Error disconnecting: $e");
    }
  }

  /// Update connection status
  void _updateConnectionStatus(String status) {
    _connectionStatus = status;
    _connectionStatusController.add(status);
  }

  /// Update error status
  void _updateError(String error) {
    _errorController.add(error);
  }

  /// Dispose resources
  void dispose() {
    disconnect();
    _connectionStatusController.close();
    _rfidDataController.close();
    _errorController.close();
  }
}
