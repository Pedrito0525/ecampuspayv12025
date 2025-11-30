

#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

#include <ArduinoJson.h>
#include <SPI.h>
#include <MFRC522.h>

// BLE Service and Characteristic UUIDs (must match Flutter app)
#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E" // ESP32 receives
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E" // ESP32 transmits

// Pin definitions for MFRC522 (using standard SPI pins)
#define RST_PIN         22  // GPIO22 (Reset)
#define SS_PIN          21  // GPIO21 (SDA/SS)

// MFRC522 instance
MFRC522 mfrc522(SS_PIN, RST_PIN);

// BLE variables
BLEServer* pServer = NULL;
BLECharacteristic* pTxCharacteristic;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Scanner state
struct ScannerState {
  bool isReady;
  bool isScanning;
  String lastScannedCard;
  unsigned long scanStartTime;
  String paymentAccount;
  double amount;
  String itemName;
  bool bleConnected;
  String scanMode; // "payment" or "registration"
} scanner;

// System state
unsigned long lastCardRead = 0;
const unsigned long CARD_READ_COOLDOWN = 2000; // 2 seconds cooldown
const unsigned long SCAN_TIMEOUT = 30000; // 30 seconds timeout
const unsigned long HEARTBEAT_INTERVAL = 5000; // 5 seconds heartbeat

// BLE device name
String deviceName = "EvsuPay1";
unsigned long lastHeartbeat = 0;

// Forward declarations
void initializeBLE();
void sendBLEMessage(String message);
void sendConnectionConfirmation();
void sendHealthStatus();
void sendScannerStatus();
void sendRfidData(String rfidId);
void sendHeartbeat();
void sendScanTimeout();
void sendScannerStopped();
void sendError(String errorMessage);
void processBluetoothMessage(String message);
void startScanner(DynamicJsonDocument& doc);
void startRegistrationScanner();
void stopScanning();
void handleRfidScanning();
void testRfidForApp();
String getRfidString();
String getCardTypeName();
void testRfidReading();
void sendRegistrationData(String rfidId);

// BLE Server Callbacks
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("✓ BLE client connected!");
      scanner.bleConnected = true;
      
      // Send connection confirmation
      sendConnectionConfirmation();
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("✗ BLE client disconnected!");
      scanner.bleConnected = false;
      stopScanning(); // Stop any ongoing scanning
      
      // Restart advertising
      BLEDevice::startAdvertising();
      Serial.println("BLE advertising restarted");
    }
};

// BLE Characteristic Callbacks (for receiving data)
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String rxValue = pCharacteristic->getValue();

      if (rxValue.length() > 0) {
        processBluetoothMessage(rxValue);
      }
    }
};

void setup() {
  Serial.begin(115200);
  
  // Initialize SPI for MFRC522
  SPI.begin();
  
  // Initialize MFRC522
  mfrc522.PCD_Init();
  
  // Test MFRC522 connection
  Serial.println("Testing MFRC522 connection...");
  Serial.println("=== ESP32 Standard SPI Pin Configuration ===");
  Serial.println("SCK  (Clock):     GPIO18");
  Serial.println("MOSI (Data Out):  GPIO23");
  Serial.println("MISO (Data In):   GPIO19");
  Serial.println("SS   (Slave Sel): GPIO21");
  Serial.println("RST  (Reset):     GPIO22");
  Serial.println("==========================================");
  
  byte v = mfrc522.PCD_ReadRegister(mfrc522.VersionReg);
  Serial.print("MFRC522 Software Version: 0x");
  Serial.print(v, HEX);
  if (v == 0x91)
    Serial.println(" = v1.0");
  else if (v == 0x92)
    Serial.println(" = v2.0");
  else
    Serial.println(" (unknown)");
  
  if ((v == 0x00) || (v == 0xFF)) {
    Serial.println("WARNING: Communication failure, is the MFRC522 properly connected?");
    Serial.println("Check wiring according to pin configuration above.");
  } else {
    Serial.println("✓ MFRC522 initialized successfully!");
    
    // Test antenna gain settings for better card detection
    mfrc522.PCD_SetAntennaGain(mfrc522.RxGain_max);
    Serial.println("✓ Antenna gain set to maximum for better detection");
    
    // Perform self-test
    Serial.println("Performing MFRC522 self-test...");
    bool selfTestResult = mfrc522.PCD_PerformSelfTest();
    Serial.println(selfTestResult ? "✓ Self-test passed!" : "✗ Self-test failed!");
    
    // Re-initialize after self-test
    mfrc522.PCD_Init();
    mfrc522.PCD_SetAntennaGain(mfrc522.RxGain_max);
  }
  
  // Initialize BLE
  initializeBLE();
  
  // Initialize scanner state
  scanner.isReady = false;
  scanner.isScanning = false;
  scanner.lastScannedCard = "";
  scanner.bleConnected = false;
  scanner.scanMode = "payment";
  
  Serial.println("=== EVSU Canteen ESP32 RFID Reader (BLE) ===");
  Serial.println("Ready to read RFID cards via BLE!");
  Serial.println("BLE Name: " + deviceName);
  Serial.println("===========================================");
  Serial.println();
  Serial.println("🔍 RFID READER TEST MODE");
  Serial.println("Place a 13.56MHz RFID card near the scanner to test...");
  Serial.println();
  Serial.println("📱 BLE CONNECTION");
  Serial.println("Connect from Flutter app to start payment processing...");
  Serial.println();
}

void loop() {
  // Handle BLE connection status changes
  if (!deviceConnected && oldDeviceConnected) {
    // Disconnecting
    delay(500); // Give the bluetooth stack the chance to get things ready
    pServer->startAdvertising(); // Restart advertising
    Serial.println("BLE advertising started");
    oldDeviceConnected = deviceConnected;
  }
  
  // Connecting
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
  
  // Send heartbeat if connected
  if (scanner.bleConnected && (millis() - lastHeartbeat > HEARTBEAT_INTERVAL)) {
    sendHeartbeat();
    lastHeartbeat = millis();
  }
  
  // Check if scanner is ready and handle RFID reading
  if (scanner.isReady && scanner.bleConnected) {
    handleRfidScanning();
    
    // Check for scan timeout
    if (scanner.isScanning && (millis() - scanner.scanStartTime > SCAN_TIMEOUT)) {
      Serial.println("Scan timeout - stopping scan");
      stopScanning();
      sendScanTimeout();
    }
  } else {
    // Test RFID reading even when not ready (for debugging)
    static unsigned long lastTestScan = 0;
    if (millis() - lastTestScan > 2000) { // Test every 2 seconds
      testRfidReading();
      lastTestScan = millis();
    }
  }
  
  delay(10); // Small delay for better performance
}

void initializeBLE() {
  Serial.println("=== BLE Initialization ===");
  
  // Create the BLE Device
  BLEDevice::init(deviceName.c_str());

  // Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic for TX (ESP32 -> Flutter)
  pTxCharacteristic = pService->createCharacteristic(
                        CHARACTERISTIC_UUID_TX,
                        BLECharacteristic::PROPERTY_NOTIFY
                      );
  pTxCharacteristic->addDescriptor(new BLE2902());

  // Create a BLE Characteristic for RX (Flutter -> ESP32)
  BLECharacteristic* pRxCharacteristic = pService->createCharacteristic(
                                          CHARACTERISTIC_UUID_RX,
                                          BLECharacteristic::PROPERTY_WRITE
                                        );
  pRxCharacteristic->setCallbacks(new MyCallbacks());

  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);  // Set value to 0x00 to not advertise this parameter
  BLEDevice::startAdvertising();
  
  Serial.println("✓ BLE initialized successfully!");
  Serial.println("Device Name: " + deviceName);
  Serial.println("Waiting for BLE connection...");
  Serial.println("===========================");
}

void sendConnectionConfirmation() {
  DynamicJsonDocument doc(200);
  doc["type"] = "connection";
  doc["status"] = "connected";
  doc["device"] = "ESP32_RFID_Scanner";
  doc["message"] = "BLE Connected successfully";
  
  String response;
  serializeJson(doc, response);
  sendBLEMessage(response);
}

void sendBLEMessage(String message) {
  if (deviceConnected && pTxCharacteristic) {
    pTxCharacteristic->setValue(message.c_str());
    pTxCharacteristic->notify();
    delay(10); // Bluetooth stack needs time
  }
}

void processBluetoothMessage(String message) {
  message.trim();
  Serial.println("BLE Received: " + message);
  
  // Parse JSON command
  DynamicJsonDocument doc(512);
  DeserializationError error = deserializeJson(doc, message);
  
  if (error) {
    Serial.println("JSON parsing failed: " + String(error.c_str()));
    sendError("Invalid JSON format");
    return;
  }
  
  String command = doc["command"];
  
  if (command == "health_check") {
    sendHealthStatus();
  }
  else if (command == "start_scanner") {
    startScanner(doc);
  }
  else if (command == "start_registration_scanner") {
    startRegistrationScanner();
  }
  else if (command == "stop_scanner") {
    stopScanning();
    sendScannerStopped();
  }
  else if (command == "get_status") {
    sendScannerStatus();
  }
  else if (command == "test_rfid") {
    testRfidForApp();
  }
  else {
    sendError("Unknown command: " + command);
  }
}

void sendHealthStatus() {
  DynamicJsonDocument doc(300);
  doc["type"] = "health_response";
  doc["status"] = "online";
  doc["device"] = "ESP32_RFID_Scanner";
  doc["bleConnected"] = scanner.bleConnected;
  doc["scannerReady"] = scanner.isReady;
  doc["scanning"] = scanner.isScanning;
  doc["uptime"] = millis();
  
  // MFRC522 status
  byte version = mfrc522.PCD_ReadRegister(mfrc522.VersionReg);
  doc["mfrc522Version"] = String("0x") + String(version, HEX);
  doc["mfrc522Working"] = (version != 0x00 && version != 0xFF);
  
  String response;
  serializeJson(doc, response);
  sendBLEMessage(response);
}

void startScanner(DynamicJsonDocument& doc) {
  scanner.paymentAccount = doc["paymentAccount"].as<String>();
  scanner.amount = doc["amount"];
  scanner.itemName = doc["itemName"].as<String>();
  scanner.isReady = true;
  scanner.isScanning = true;
  scanner.scanStartTime = millis();
  scanner.lastScannedCard = "";
  scanner.scanMode = "payment";
  
  Serial.println("=== PAYMENT SCANNER STARTED ===");
  Serial.println("Payment Account: " + scanner.paymentAccount);
  Serial.println("Item: " + scanner.itemName);
  Serial.println("Amount: ₱" + String(scanner.amount, 2));
  Serial.println("Waiting for RFID card scan...");
  Serial.println("===============================");
  
  // Send confirmation to app via BLE
  DynamicJsonDocument response(200);
  response["type"] = "scanner_started";
  response["status"] = "ready";
  response["message"] = "Scanner ready - place RFID card near reader";
  
  String responseStr;
  serializeJson(response, responseStr);
  sendBLEMessage(responseStr);
}

void startRegistrationScanner() {
  scanner.paymentAccount = "registration";
  scanner.amount = 0.0;
  scanner.itemName = "School ID Registration";
  scanner.isReady = true;
  scanner.isScanning = true;
  scanner.scanStartTime = millis();
  scanner.lastScannedCard = "";
  scanner.scanMode = "registration";
  
  Serial.println("=== REGISTRATION SCANNER STARTED ===");
  Serial.println("Mode: School ID Registration");
  Serial.println("Waiting for School ID card scan...");
  Serial.println("====================================");
  
  // Send confirmation to app via BLE
  DynamicJsonDocument response(200);
  response["type"] = "registration_scanner_started";
  response["status"] = "ready";
  response["message"] = "Registration scanner ready - place School ID card near reader";
  
  String responseStr;
  serializeJson(response, responseStr);
  sendBLEMessage(responseStr);
}

void sendScannerStatus() {
  DynamicJsonDocument doc(400);
  doc["type"] = "status_response";
  doc["scannerReady"] = scanner.isReady;
  doc["scanning"] = scanner.isScanning;
  doc["lastScannedCard"] = scanner.lastScannedCard;
  doc["bleConnected"] = scanner.bleConnected;
  
  if (scanner.isReady) {
    doc["paymentAccount"] = scanner.paymentAccount;
    doc["amount"] = scanner.amount;
    doc["itemName"] = scanner.itemName;
    doc["timeRemaining"] = max(0, (int)(SCAN_TIMEOUT - (millis() - scanner.scanStartTime)));
  }
  
  String response;
  serializeJson(doc, response);
  sendBLEMessage(response);
}

void handleRfidScanning() {
  if (mfrc522.PICC_IsNewCardPresent()) {
    Serial.println("DEBUG: New card detected, attempting to read...");
    
    if (mfrc522.PICC_ReadCardSerial()) {
      String rfidId = getRfidString();
      
      // Check cooldown and prevent duplicate reads
      if (rfidId != "" && rfidId != scanner.lastScannedCard) {
        if (millis() - lastCardRead >= CARD_READ_COOLDOWN) {
          scanner.lastScannedCard = rfidId;
          lastCardRead = millis();
          
          Serial.println("=== RFID CARD READ SUCCESSFULLY ===");
          Serial.println("Card ID: " + rfidId);
          Serial.println("Card Type: " + getCardTypeName());
          Serial.println("UID Size: " + String(mfrc522.uid.size) + " bytes");
          Serial.println("Sending to Flutter app via BLE...");
          Serial.println("===================================");
          
          // Send RFID data to Flutter app via BLE based on scan mode
          if (scanner.scanMode == "registration") {
            sendRegistrationData(rfidId);
          } else {
            sendRfidData(rfidId);
          }
          
        } else {
          Serial.println("DEBUG: Card read too soon, waiting for cooldown...");
        }
      } else if (rfidId == scanner.lastScannedCard) {
        Serial.println("DEBUG: Same card detected, ignoring...");
      }
      
      // Halt the card and stop encryption
      mfrc522.PICC_HaltA();
      mfrc522.PCD_StopCrypto1();
    } else {
      Serial.println("DEBUG: Card present but failed to read serial data");
    }
  }
}

void sendRfidData(String rfidId) {
  DynamicJsonDocument doc(300);
  doc["type"] = "rfid_scanned";
  doc["cardId"] = rfidId;
  doc["cardType"] = getCardTypeName();
  doc["uidSize"] = mfrc522.uid.size;
  doc["timestamp"] = millis();
  doc["paymentAccount"] = scanner.paymentAccount;
  doc["amount"] = scanner.amount;
  doc["itemName"] = scanner.itemName;
  
  String response;
  serializeJson(doc, response);
  sendBLEMessage(response);
}

void testRfidForApp() {
  Serial.println("=== RFID TEST REQUESTED (BLE) ===");
  
  DynamicJsonDocument doc(400);
  doc["type"] = "rfid_test_response";
  doc["message"] = "Testing RFID scanner - place card near reader";
  
  // Try to read a card immediately
  bool cardDetected = false;
  String rfidId = "";
  String cardType = "";
  
  for (int attempt = 0; attempt < 50; attempt++) { // Try for 5 seconds
    if (mfrc522.PICC_IsNewCardPresent()) {
      if (mfrc522.PICC_ReadCardSerial()) {
        rfidId = getRfidString();
        cardType = getCardTypeName();
        cardDetected = true;
        
        mfrc522.PICC_HaltA();
        mfrc522.PCD_StopCrypto1();
        break;
      }
    }
    delay(100);
  }
  
  doc["cardDetected"] = cardDetected;
  if (cardDetected) {
    doc["cardId"] = rfidId;
    doc["cardType"] = cardType;
    doc["uidSize"] = mfrc522.uid.size;
    Serial.println("✓ Test card detected: " + rfidId);
  } else {
    Serial.println("✗ No test card detected");
  }
  
  // MFRC522 diagnostics
  byte version = mfrc522.PCD_ReadRegister(mfrc522.VersionReg);
  doc["mfrc522Version"] = String("0x") + String(version, HEX);
  doc["mfrc522Working"] = (version != 0x00 && version != 0xFF);
  
  String response;
  serializeJson(doc, response);
  sendBLEMessage(response);
}

void sendHeartbeat() {
  DynamicJsonDocument doc(150);
  doc["type"] = "heartbeat";
  doc["timestamp"] = millis();
  doc["scanning"] = scanner.isScanning;
  
  String response;
  serializeJson(doc, response);
  sendBLEMessage(response);
}

void sendScanTimeout() {
  DynamicJsonDocument doc(200);
  doc["type"] = "scan_timeout";
  doc["message"] = "Scan timeout - no card detected within time limit";
  
  String response;
  serializeJson(doc, response);
  sendBLEMessage(response);
}

void sendScannerStopped() {
  DynamicJsonDocument doc(150);
  doc["type"] = "scanner_stopped";
  doc["message"] = "Scanner stopped successfully";
  
  String response;
  serializeJson(doc, response);
  sendBLEMessage(response);
}

void sendError(String errorMessage) {
  DynamicJsonDocument doc(200);
  doc["type"] = "error";
  doc["message"] = errorMessage;
  
  String response;
  serializeJson(doc, response);
  sendBLEMessage(response);
}

String getRfidString() {
  String rfidId = "";
  for (byte i = 0; i < mfrc522.uid.size; i++) {
    if (mfrc522.uid.uidByte[i] < 0x10) {
      rfidId += "0";
    }
    rfidId += String(mfrc522.uid.uidByte[i], HEX);
  }
  rfidId.toUpperCase();
  return rfidId;
}

String getCardTypeName() {
  MFRC522::PICC_Type piccType = mfrc522.PICC_GetType(mfrc522.uid.sak);
  return String(mfrc522.PICC_GetTypeName(piccType));
}

void testRfidReading() {
  if (mfrc522.PICC_IsNewCardPresent()) {
    if (mfrc522.PICC_ReadCardSerial()) {
      String rfidId = getRfidString();
      String cardType = getCardTypeName();
      
      Serial.println("=== RFID TEST SCAN ===");
      Serial.println("Card ID: " + rfidId);
      Serial.println("Card Type: " + cardType);
      Serial.println("UID Size: " + String(mfrc522.uid.size) + " bytes");
      Serial.print("Raw UID: ");
      for (byte i = 0; i < mfrc522.uid.size; i++) {
        Serial.print("0x");
        if (mfrc522.uid.uidByte[i] < 0x10) Serial.print("0");
        Serial.print(mfrc522.uid.uidByte[i], HEX);
        if (i < mfrc522.uid.size - 1) Serial.print(" ");
      }
      Serial.println();
      Serial.println("======================");
      
      mfrc522.PICC_HaltA();
      mfrc522.PCD_StopCrypto1();
      delay(1000); // Prevent rapid re-reads
    }
  }
}

void sendRegistrationData(String rfidId) {
  DynamicJsonDocument doc(300);
  doc["type"] = "rfid_registration_scanned";
  doc["cardId"] = rfidId;
  doc["cardType"] = getCardTypeName();
  doc["uidSize"] = mfrc522.uid.size;
  doc["timestamp"] = millis();
  doc["scanMode"] = "registration";
  
  String response;
  serializeJson(doc, response);
  sendBLEMessage(response);
  
  Serial.println("=== REGISTRATION RFID SENT ===");
  Serial.println("Card ID: " + rfidId);
  Serial.println("Sent to Flutter app for registration");
  Serial.println("===============================");
}

void stopScanning() {
  scanner.isReady = false;
  scanner.isScanning = false;
  scanner.lastScannedCard = "";
  scanner.scanMode = "payment"; // Reset to default
  
  Serial.println("Scanner stopped - ready for new requests");
} 