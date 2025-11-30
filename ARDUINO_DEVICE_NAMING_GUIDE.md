# ESP32 Device Naming Guide for EvsuPay Scanners

## Current Setup Issue

Your Supabase database has scanner IDs: `EvsuPay1`, `EvsuPay2`, ..., `EvsuPay100`
But your Arduino code has: `String deviceName = "EvsuPayScanner1";`

## Required Fix for Arduino Code

### File: `esp32_payment_scanner.ino`

**Line 76 - Change device name to match database:**

```cpp
// OLD (line 76):
String deviceName = "EvsuPayScanner1";

// NEW - Change to match your database exactly:
String deviceName = "EvsuPay1";    // For scanner #1
String deviceName = "EvsuPay2";    // For scanner #2
String deviceName = "EvsuPay3";    // For scanner #3
// ... and so on up to EvsuPay100
```

## Complete Example for Different Scanners

### For Scanner 1 (EvsuPay1):

```cpp
// BLE device name
String deviceName = "EvsuPay1";
```

### For Scanner 2 (EvsuPay2):

```cpp
// BLE device name
String deviceName = "EvsuPay2";
```

### For Scanner 10 (EvsuPay10):

```cpp
// BLE device name
String deviceName = "EvsuPay10";
```

## Service Account Assignment Example

Based on your Supabase data:

```json
{
  "id": 19,
  "service_name": "Cashier",
  "username": "pedz1",
  "scanner_id": "EvsuPay1" // This service uses EvsuPay1 scanner
}
```

**This means:**

- When `pedz1` (Cashier service) logs in → App connects to `EvsuPay1` device
- When another service with `scanner_id: "EvsuPay2"` logs in → App connects to `EvsuPay2` device

## Expected Debug Output After Fix

```
DEBUG ServiceBT: Service requesting connection to scanner: EvsuPay1
DEBUG ServiceBT: Previous service scanner: None
DEBUG ServiceBT: Checking bonded device: 'EvsuPay1' (ID: XX:XX:XX:XX:XX:XX)
DEBUG ServiceBT: Expected device names: [EvsuPay1, ESP32_RFID_Scanner_EvsuPay1, ...]
DEBUG ServiceBT: ✅ EXACT MATCH: EvsuPay1 == EvsuPay1
DEBUG ServiceBT: ✅ MATCH! Found target scanner in bonded devices: 'EvsuPay1'
DEBUG ServiceBT: Successfully connected to: EvsuPay1
```

## Multi-Service Session Support

The app now supports different services connecting to different scanners:

1. **Service A** logs in with `scanner_id: "EvsuPay1"` → Connects to `EvsuPay1`
2. **Service B** logs in with `scanner_id: "EvsuPay2"` → Disconnects from `EvsuPay1`, connects to `EvsuPay2`
3. **Service A** logs in again → Disconnects from `EvsuPay2`, reconnects to `EvsuPay1`

## Important Notes

1. **Each ESP32 device must have a unique name** matching the database
2. **Pair each device** with your phone using the exact name (EvsuPay1, EvsuPay2, etc.)
3. **Update Arduino code** for each physical device to use the correct name
4. **Test connection** by checking debug output in Flutter app
