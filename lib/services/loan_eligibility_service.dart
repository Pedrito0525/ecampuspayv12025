import '../services/supabase_service.dart';
import '../services/encryption_service.dart';

/// Service for checking loan eligibility based on OCR-extracted data
class LoanEligibilityService {
  /// Check eligibility based on OCR data
  static Future<Map<String, dynamic>> checkEligibility({
    required Map<String, dynamic> ocrData,
    required String studentId,
  }) async {
    final result = <String, dynamic>{
      'is_eligible': false,
      'rejection_reason': '',
      'checks': <String, bool>{},
    };

    try {
      await SupabaseService.initialize();

      // Get current user profile name
      final studentProfile =
          await SupabaseService.client
              .from('auth_students')
              .select('name')
              .eq('student_id', studentId)
              .single();

      String profileName = studentProfile['name']?.toString() ?? '';

      // Decrypt name if needed
      try {
        if (profileName.isNotEmpty &&
            EncryptionService.looksLikeEncryptedData(profileName)) {
          profileName = EncryptionService.decryptData(profileName);
        }
      } catch (e) {
        print('Note: Could not decrypt name: $e');
        // Continue with encrypted name if decryption fails
      }

      // Normalize names for comparison (remove extra spaces, convert to lowercase)
      final ocrName = (ocrData['name'] as String? ?? '').trim().toLowerCase();
      final normalizedProfileName = profileName.trim().toLowerCase();

      // Get current academic year and semester from system
      final currentAySem = await _getCurrentAcademicYearSemester();
      final currentAy = currentAySem['academic_year'] ?? '';
      final currentSem = currentAySem['semester'] ?? '';

      // Check A: Status must be "Officially Enrolled"
      final status = (ocrData['status'] as String? ?? '').trim();
      final statusCheck =
          status.toLowerCase().contains('officially enrolled') ||
          status.toLowerCase() == 'officially enrolled';
      result['checks']['status'] = statusCheck;
      if (!statusCheck) {
        result['rejection_reason'] = 'Status is not "Officially Enrolled"';
        return result;
      }

      // Check B: AY & Semester must match system's current AY/SEM
      final ocrAy = (ocrData['academic_year'] as String? ?? '').trim();
      final ocrSem = (ocrData['semester'] as String? ?? '').trim();

      // Normalize AY comparison (handle formats like "2024-2025" vs "2024/2025")
      final normalizedOcrAy =
          ocrAy.replaceAll('/', '-').replaceAll(' ', '').toLowerCase();
      final normalizedCurrentAy =
          currentAy.replaceAll('/', '-').replaceAll(' ', '').toLowerCase();

      final ayMatch =
          normalizedOcrAy.isNotEmpty &&
          normalizedCurrentAy.isNotEmpty &&
          normalizedOcrAy == normalizedCurrentAy;

      // Debug logging
      print('DEBUG Eligibility: OCR AY: "$ocrAy" -> "$normalizedOcrAy"');
      print(
        'DEBUG Eligibility: Current AY: "$currentAy" -> "$normalizedCurrentAy"',
      );
      print('DEBUG Eligibility: AY Match: $ayMatch');

      // Normalize semester comparison
      final normalizedOcrSem = _normalizeSemester(ocrSem);
      final normalizedCurrentSem = _normalizeSemester(currentSem);

      final semMatch =
          normalizedOcrSem.isNotEmpty &&
          normalizedCurrentSem.isNotEmpty &&
          normalizedOcrSem == normalizedCurrentSem;

      result['checks']['academic_year'] = ayMatch;
      result['checks']['semester'] = semMatch;

      if (!ayMatch || !semMatch) {
        String reason = '';
        if (!ayMatch && !semMatch) {
          reason =
              'Academic Year ($ocrAy) and Semester ($ocrSem) do not match current system values (AY: $currentAy, Sem: $currentSem)';
        } else if (!ayMatch) {
          reason =
              'Academic Year ($ocrAy) does not match current system value ($currentAy)';
        } else {
          reason =
              'Semester ($ocrSem) does not match current system value ($currentSem)';
        }
        result['rejection_reason'] = reason;
        return result;
      }

      // Check C: OCR name must match user profile name (partial match allowed)
      // Example: OCR "PEDRITO" should match profile "Pedrito M. Parrilla"
      // Example: OCR "JOAN" should match profile "Joan Ramas"
      print('DEBUG Eligibility: OCR Name: "$ocrName"');
      print('DEBUG Eligibility: Profile Name: "$normalizedProfileName"');
      bool nameMatch = false;
      if (ocrName.isNotEmpty && normalizedProfileName.isNotEmpty) {
        // Remove periods and extra spaces for better matching
        final cleanOcrName =
            ocrName.replaceAll('.', '').replaceAll(RegExp(r'\s+'), ' ').trim();
        final cleanProfileName =
            normalizedProfileName
                .replaceAll('.', '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();

        // Split names into words (include single letters for middle initials)
        final ocrWords =
            cleanOcrName
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .toList();
        final profileWords =
            cleanProfileName
                .split(RegExp(r'\s+'))
                .where((w) => w.isNotEmpty)
                .toList();

        // Check if OCR name matches profile name (exact or partial)
        if (cleanOcrName == cleanProfileName) {
          nameMatch = true;
        } else if (cleanProfileName.contains(cleanOcrName) ||
            cleanOcrName.contains(cleanProfileName)) {
          nameMatch = true;
        } else if (ocrWords.isNotEmpty && profileWords.isNotEmpty) {
          // Check if first name matches (most common case: OCR has "PEDRITO", profile has "Pedrito M. Parrilla")
          if (ocrWords[0] == profileWords[0]) {
            nameMatch = true;
          } else {
            // Check if any OCR word matches any profile word (case-insensitive)
            for (final ocrWord in ocrWords) {
              if (ocrWord.length >= 3) {
                // Only check words with 3+ characters
                if (profileWords.any(
                  (profileWord) =>
                      profileWord.toLowerCase() == ocrWord.toLowerCase() ||
                      profileWord.toLowerCase().startsWith(
                        ocrWord.toLowerCase(),
                      ) ||
                      ocrWord.toLowerCase().startsWith(
                        profileWord.toLowerCase(),
                      ),
                )) {
                  nameMatch = true;
                  break;
                }
              }
            }
          }
        }
      }

      result['checks']['name'] = nameMatch;

      // Check D: Subject list must not be empty
      final subjects = ocrData['subjects'] as List<dynamic>? ?? [];
      // Convert to list of strings and filter out empty values
      final subjectList =
          subjects
              .map((s) => s.toString().trim())
              .where((s) => s.isNotEmpty)
              .toList();
      final hasSubjects = subjectList.isNotEmpty;
      result['checks']['subjects'] = hasSubjects;
      print(
        'DEBUG Eligibility: Subjects raw: $subjects, Processed: $subjectList, Count: ${subjectList.length}, Has subjects: $hasSubjects',
      );

      // Check E: OCR text must be readable (confidence OK)
      final confidence = (ocrData['confidence'] as num? ?? 0.0).toDouble();
      final confidenceCheck = confidence >= 0.5; // Minimum 50% confidence
      result['checks']['confidence'] = confidenceCheck;
      print(
        'DEBUG Eligibility: Confidence: $confidence, Check: $confidenceCheck',
      );

      // Now check all conditions and set rejection reason if any fail
      if (!nameMatch) {
        result['rejection_reason'] =
            'Name on enrollment screenshot does not match profile name. OCR: "$ocrName", Profile: "$normalizedProfileName"';
        return result;
      }

      if (!hasSubjects) {
        result['rejection_reason'] =
            'No subjects found in enrollment screenshot';
        return result;
      }

      if (!confidenceCheck) {
        result['rejection_reason'] =
            'Enrollment screenshot is not readable or unclear';
        return result;
      }

      // All checks passed
      result['is_eligible'] = true;
      result['rejection_reason'] = '';

      return result;
    } catch (e) {
      result['rejection_reason'] = 'Error during eligibility check: $e';
      return result;
    }
  }

  /// Get current academic year and semester from system
  /// Semester logic: Sem 1 = June to December, Sem 2 = January to May
  static Future<Map<String, String>> _getCurrentAcademicYearSemester() async {
    try {
      await SupabaseService.initialize();

      // Always calculate from current date to ensure latest academic year
      // Don't rely on database function if it returns outdated values
      final now = DateTime.now();
      final month = now.month;
      final year = now.year;

      String semester = '';
      String academicYear = '';

      // Determine semester from current date
      // Sem 1: June (6) to December (12)
      // Sem 2: January (1) to May (5)
      if (month >= 6 && month <= 12) {
        semester = '1st Semester';
      } else {
        semester = '2nd Semester';
      }

      // Calculate academic year from current date
      // Academic year runs from June to May
      // If between Jun-Dec (Sem 1): Current year to next year (e.g., Nov 2025 = 2025-2026)
      // If between Jan-May (Sem 2): Previous year to current year (e.g., Feb 2026 = 2025-2026)
      if (month >= 6 && month <= 12) {
        // June-December: Current year to next year (e.g., Nov 2025 = 2025-2026)
        academicYear = '$year-${year + 1}';
      } else {
        // January-May: Previous year to current year (e.g., Feb 2026 = 2025-2026)
        academicYear = '${year - 1}-$year';
      }

      print(
        'DEBUG System AY/Sem Calculation: Date: ${now.toString()}, Month: $month, Year: $year',
      );
      print(
        'DEBUG System AY/Sem: Calculated AY: $academicYear, Semester: $semester',
      );
      return {'academic_year': academicYear, 'semester': semester};
    } catch (e) {
      print('Error getting current AY/Sem: $e');
    }

    // Fallback: Determine semester from current date
    // Sem 1: June to December (months 6-12)
    // Sem 2: January to May (months 1-5)
    final now = DateTime.now();
    final month = now.month;
    final year = now.year;

    String semester = '1st Semester';
    if (month >= 1 && month <= 5) {
      semester = '2nd Semester';
    }

    // Calculate academic year based on current date
    // Academic year runs from June to May
    // If between Jun-Dec (Sem 1): Current year to next year (e.g., Nov 2025 = 2025-2026)
    // If between Jan-May (Sem 2): Previous year to current year (e.g., Feb 2025 = 2024-2025)
    String academicYear = '';
    if (month >= 6 && month <= 12) {
      // June-December: Current year to next year (e.g., Nov 2025 = 2025-2026)
      academicYear = '$year-${year + 1}';
    } else {
      // January-May: Previous year to current year (e.g., Feb 2025 = 2024-2025)
      academicYear = '${year - 1}-$year';
    }

    print('DEBUG AY/Sem Calculation: Date: ${now.toString()}, Month: $month');
    print(
      'DEBUG AY/Sem Calculation: Calculated AY: $academicYear, Semester: $semester',
    );

    return {'academic_year': academicYear, 'semester': semester};
  }

  /// Normalize semester string for comparison
  static String _normalizeSemester(String sem) {
    final lower = sem.toLowerCase().trim();
    if (lower.contains('1st') || lower.contains('first') || lower == '1') {
      return '1st Semester';
    } else if (lower.contains('2nd') ||
        lower.contains('second') ||
        lower == '2') {
      return '2nd Semester';
    }
    return sem.trim();
  }
}
