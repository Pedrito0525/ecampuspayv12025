import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

class EncryptionService {
  static const String _encryptionKey =
      'EVSU_CAMPUS_PAY_2024_SECURE_KEY_32_CHARS!';
  static late final Encrypter _encrypter;
  static late final IV _iv;

  /// Initialize encryption service
  static void initialize() {
    // Create a 32-character key for AES-256
    final key = Key.fromBase64(
      base64.encode(utf8.encode(_encryptionKey).take(32).toList()),
    );
    _encrypter = Encrypter(AES(key));

    // Generate a default IV for fallback decryption
    _iv = IV.fromSecureRandom(16);
  }

  /// Hash password using SHA-256 with salt
  static String hashPassword(String password, {String? salt}) {
    final actualSalt = salt ?? _generateSalt();
    final bytes = utf8.encode(password + actualSalt);
    final digest = sha256.convert(bytes);
    return '$actualSalt:${digest.toString()}';
  }

  /// Verify password against hash
  static bool verifyPassword(String password, String hashedPassword) {
    try {
      final parts = hashedPassword.split(':');
      if (parts.length != 2) return false;

      final salt = parts[0];

      final testHash = hashPassword(password, salt: salt);
      return testHash == hashedPassword;
    } catch (e) {
      return false;
    }
  }

  /// Encrypt sensitive data
  static String encryptData(String data) {
    try {
      // Use a fixed IV for consistency with existing data
      // This ensures compatibility with the existing encrypted data in the database
      final fixedIv = IV.fromBase64('AAAAAAAAAAAAAAAAAAAAAA=='); // Zero IV
      final encrypted = _encrypter.encrypt(data, iv: fixedIv);
      // Store only the encrypted data (no IV prefix for compatibility)
      return base64.encode(encrypted.bytes);
    } catch (e) {
      throw Exception('Encryption failed: $e');
    }
  }

  /// Decrypt sensitive data
  static String decryptData(String encryptedData) {
    try {
      final bytes = base64.decode(encryptedData);

      // Try multiple decryption approaches
      final approaches = [
        _tryOldFormatWithZeroIV, // Try zero IV first since that's what we use for encryption
        _tryNewFormatDecryption,
        _tryOldFormatWithCommonIV,
        _tryOldFormatWithRawKey,
        _tryOldFormatWithSessionIV,
        _tryOldFormatWithRandomIV,
      ];

      for (int i = 0; i < approaches.length; i++) {
        try {
          final result = approaches[i](bytes);
          if (result != null && result.isNotEmpty) {
            return result;
          }
        } catch (e) {
          // Continue to next approach
        }
      }

      throw Exception('All decryption approaches failed');
    } catch (e) {
      throw Exception('Decryption failed: $e');
    }
  }

  /// Try new format decryption (IV + encrypted data)
  static String? _tryNewFormatDecryption(List<int> bytes) {
    if (bytes.length < 32) {
      return null;
    }

    final ivBytes = Uint8List.fromList(bytes.take(16).toList());
    final encryptedBytes = Uint8List.fromList(bytes.skip(16).toList());

    final iv = IV(ivBytes);
    final encrypted = Encrypted(encryptedBytes);
    return _encrypter.decrypt(encrypted, iv: iv);
  }

  /// Try old format with zero IV
  static String? _tryOldFormatWithZeroIV(List<int> bytes) {
    final zeroIv = IV.fromBase64('AAAAAAAAAAAAAAAAAAAAAA==');
    final encrypted = Encrypted(Uint8List.fromList(bytes));
    return _encrypter.decrypt(encrypted, iv: zeroIv);
  }

  /// Try old format with a common IV that might have been used
  static String? _tryOldFormatWithCommonIV(List<int> bytes) {
    // Try with a common IV that might have been used during original encryption
    final commonIv = IV.fromBase64(
      'MTIzNDU2Nzg5MGFiY2RlZg==',
    ); // "1234567890abcdef" in base64
    final encrypted = Encrypted(Uint8List.fromList(bytes));
    return _encrypter.decrypt(encrypted, iv: commonIv);
  }

  /// Try old format with raw key (not base64 encoded)
  static String? _tryOldFormatWithRawKey(List<int> bytes) {
    try {
      // Try with raw key instead of base64 encoded key
      final rawKey = Key.fromUtf8(_encryptionKey);
      final rawEncrypter = Encrypter(AES(rawKey));
      final zeroIv = IV.fromBase64('AAAAAAAAAAAAAAAAAAAAAA==');
      final encrypted = Encrypted(Uint8List.fromList(bytes));
      return rawEncrypter.decrypt(encrypted, iv: zeroIv);
    } catch (e) {
      return null;
    }
  }

  /// Try old format with session IV
  static String? _tryOldFormatWithSessionIV(List<int> bytes) {
    final encrypted = Encrypted(Uint8List.fromList(bytes));
    return _encrypter.decrypt(encrypted, iv: _iv);
  }

  /// Try old format with random IV (fallback)
  static String? _tryOldFormatWithRandomIV(List<int> bytes) {
    final randomIv = IV.fromSecureRandom(16);
    final encrypted = Encrypted(Uint8List.fromList(bytes));
    return _encrypter.decrypt(encrypted, iv: randomIv);
  }

  /// Encrypt user data map
  static Map<String, dynamic> encryptUserData(Map<String, dynamic> userData) {
    final encryptedData = Map<String, dynamic>.from(userData);

    // Encrypt sensitive fields
    if (encryptedData['name'] != null) {
      encryptedData['name'] = encryptData(encryptedData['name'].toString());
    }
    if (encryptedData['email'] != null) {
      encryptedData['email'] = encryptData(encryptedData['email'].toString());
    }
    if (encryptedData['course'] != null) {
      encryptedData['course'] = encryptData(encryptedData['course'].toString());
    }
    if (encryptedData['rfid_id'] != null) {
      encryptedData['rfid_id'] = encryptData(
        encryptedData['rfid_id'].toString(),
      );
    }

    return encryptedData;
  }

  /// Decrypt user data map
  static Map<String, dynamic> decryptUserData(
    Map<String, dynamic> encryptedData,
  ) {
    final decryptedData = Map<String, dynamic>.from(encryptedData);

    try {
      // Decrypt sensitive fields
      if (decryptedData['name'] != null) {
        final encryptedName = decryptedData['name'].toString();

        if (looksLikeEncryptedData(encryptedName)) {
          try {
            final decryptedName = decryptData(encryptedName);
            decryptedData['name'] = decryptedName;
          } catch (e) {
            // Keep original if decryption fails
          }
        } else {
          // Try to decrypt anyway if it looks like base64 data
          if (encryptedName.length > 20 &&
              (encryptedName.contains('=') || encryptedName.length % 4 == 0)) {
            try {
              final decryptedName = decryptData(encryptedName);
              decryptedData['name'] = decryptedName;
            } catch (e) {
              // Keep original if decryption fails
            }
          }
        }
      }

      if (decryptedData['email'] != null) {
        final encryptedEmail = decryptedData['email'].toString();

        if (looksLikeEncryptedData(encryptedEmail)) {
          try {
            final decryptedEmail = decryptData(encryptedEmail);
            decryptedData['email'] = decryptedEmail;
          } catch (e) {
            // Keep original if decryption fails
          }
        } else {
          // Try to decrypt anyway if it looks like base64 data
          if (encryptedEmail.length > 20 &&
              (encryptedEmail.contains('=') ||
                  encryptedEmail.length % 4 == 0)) {
            try {
              final decryptedEmail = decryptData(encryptedEmail);
              decryptedData['email'] = decryptedEmail;
            } catch (e) {
              // Keep original if decryption fails
            }
          }
        }
      }

      if (decryptedData['course'] != null) {
        final encryptedCourse = decryptedData['course'].toString();

        if (looksLikeEncryptedData(encryptedCourse)) {
          try {
            final decryptedCourse = decryptData(encryptedCourse);
            decryptedData['course'] = decryptedCourse;
          } catch (e) {
            // Keep original if decryption fails
          }
        } else {
          // Try to decrypt anyway if it looks like base64 data
          if (encryptedCourse.length > 20 &&
              (encryptedCourse.contains('=') ||
                  encryptedCourse.length % 4 == 0)) {
            try {
              final decryptedCourse = decryptData(encryptedCourse);
              decryptedData['course'] = decryptedCourse;
            } catch (e) {
              // Keep original if decryption fails
            }
          }
        }
      }

      if (decryptedData['rfid_id'] != null) {
        final encryptedRfid = decryptedData['rfid_id'].toString();

        if (looksLikeEncryptedData(encryptedRfid)) {
          try {
            final decryptedRfid = decryptData(encryptedRfid);
            decryptedData['rfid_id'] = decryptedRfid;
          } catch (e) {
            // Keep original if decryption fails
          }
        }
      }
    } catch (e) {
      // Handle general decryption error
    }

    return decryptedData;
  }

  /// Generate a random salt
  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64.encode(saltBytes);
  }

  /// Check if data is encrypted (has base64 pattern)
  static bool isEncrypted(String data) {
    try {
      // Check if it's a valid base64 string
      base64.decode(data);
      // Check if it's longer than typical unencrypted data
      return data.length > 20;
    } catch (e) {
      return false;
    }
  }

  /// Check if data looks like encrypted data (base64 with IV)
  static bool looksLikeEncryptedData(String data) {
    try {
      // Must be valid base64
      final bytes = base64.decode(data);

      // Check if it's long enough to contain IV + encrypted data (at least 32 bytes)
      if (bytes.length >= 32) {
        // For new format (IV + encrypted data), it should be at least 32 bytes
        // For old format, it could be shorter but still encrypted
        final variance = _calculateByteVariance(bytes);
        final hasHighVariance = variance > 15; // Even lower threshold
        final isLongEnough =
            bytes.length >= 16; // Minimum for any encrypted data
        final isBase64Like = data.contains('=') || data.length % 4 == 0;

        return hasHighVariance && isLongEnough && isBase64Like;
      }

      // For shorter data, check if it looks like old format encrypted data
      if (bytes.length >= 8) {
        final variance = _calculateByteVariance(bytes);
        final hasHighVariance =
            variance > 10; // Very low threshold for short data
        final isBase64Like = data.contains('=') || data.length % 4 == 0;

        return hasHighVariance && isBase64Like;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Calculate variance of bytes to detect encrypted data
  static double _calculateByteVariance(List<int> bytes) {
    if (bytes.isEmpty) return 0;

    final mean = bytes.reduce((a, b) => a + b) / bytes.length;
    final variance =
        bytes.map((b) => (b - mean) * (b - mean)).reduce((a, b) => a + b) /
        bytes.length;
    return variance;
  }

  /// Encrypt password for storage (one-way hash)
  static String encryptPassword(String password) {
    return hashPassword(password);
  }

  /// Verify password for login
  static bool verifyPasswordForLogin(String password, String storedHash) {
    return verifyPassword(password, storedHash);
  }

  /// Generate secure random string
  static String generateSecureRandom({int length = 32}) {
    final random = Random.secure();
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    return String.fromCharCodes(
      Iterable.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  /// Encrypt sensitive fields in a list of user data
  static List<Map<String, dynamic>> encryptUserDataList(
    List<Map<String, dynamic>> userDataList,
  ) {
    return userDataList.map((userData) => encryptUserData(userData)).toList();
  }

  /// Decrypt sensitive fields in a list of user data
  static List<Map<String, dynamic>> decryptUserDataList(
    List<Map<String, dynamic>> encryptedDataList,
  ) {
    return encryptedDataList
        .map((userData) => decryptUserData(userData))
        .toList();
  }

  /// Create a secure hash for data integrity
  static String createDataHash(Map<String, dynamic> data) {
    final jsonString = jsonEncode(data);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Verify data integrity
  static bool verifyDataIntegrity(
    Map<String, dynamic> data,
    String expectedHash,
  ) {
    final actualHash = createDataHash(data);
    return actualHash == expectedHash;
  }
}
