import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR Service for extracting text from enrollment screenshots
class OCRService {
  static final TextRecognizer _textRecognizer = TextRecognizer();

  /// Extract text from image file
  static Future<String> extractTextFromImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );

      String fullText = '';
      // Safely iterate through blocks and lines
      if (recognizedText.blocks.isNotEmpty) {
        for (final block in recognizedText.blocks) {
          if (block.lines.isNotEmpty) {
            for (final line in block.lines) {
              if (line.text.isNotEmpty) {
                fullText += '${line.text}\n';
              }
            }
          }
        }
      }

      return fullText.trim();
    } catch (e) {
      throw Exception('OCR processing failed: $e');
    }
  }

  /// Extract enrollment data from OCR text
  static Future<Map<String, dynamic>> extractEnrollmentData(
    String ocrText,
  ) async {
    final data = <String, dynamic>{
      'name': '',
      'status': '',
      'academic_year': '',
      'semester': '',
      'subjects': <String>[],
      'date': '',
      'confidence': 0.0,
      'raw_text': ocrText,
      'has_links': false,
      'validation_error': '',
    };

    // Validate OCR text
    if (ocrText.isEmpty || ocrText.trim().length < 10) {
      data['validation_error'] =
          'Screenshot is too unclear or empty. Please capture a clearer image.';
      return data; // Return empty data if OCR text is too short
    }

    // Check if image contains URLs/links (should not have links in enrollment screenshot)
    final textLower = ocrText.toLowerCase();
    final hasLinks =
        RegExp(r'\.(edu|com|org|net|ph)').hasMatch(textLower) ||
        textLower.contains('http') ||
        textLower.contains('www.') ||
        textLower.contains('.evsu') ||
        textLower.contains('app.evsu');

    data['has_links'] = hasLinks;

    if (hasLinks) {
      data['validation_error'] =
          'Screenshot contains links or URLs. Please capture only the enrollment subjects section without navigation menu or links.';
      print('DEBUG OCR: Image contains links/URLs - validation failed');
    }

    final lines =
        ocrText.split('\n').where((line) => line.trim().isNotEmpty).toList();

    // Extract Name (usually appears near the top, contains letters and spaces)
    // First, try to find name after "Name:" label
    bool nameFound = false;
    for (int i = 0; i < lines.length && i < 20; i++) {
      try {
        final line = lines[i];
        final trimmed = line.trim();
        final lowerTrimmed = trimmed.toLowerCase();

        // Check if line contains "name:" label
        if (lowerTrimmed.contains('name') && lowerTrimmed.contains(':')) {
          // Extract name after colon
          final parts = trimmed.split(':');
          if (parts.length > 1) {
            String nameCandidate = parts.sublist(1).join(':').trim();
            // Clean up name (remove extra spaces, special chars at start/end)
            nameCandidate = nameCandidate.replaceAll(
              RegExp(r'^[^\w]+|[^\w]+$'),
              '',
            );

            // Exclude common non-name patterns
            final lowerNameCandidate = nameCandidate.toLowerCase();
            if (lowerNameCandidate.contains('officially') ||
                lowerNameCandidate.contains('enrolled') ||
                lowerNameCandidate.contains('status') ||
                lowerNameCandidate.contains('academic') ||
                lowerNameCandidate.contains('semester') ||
                lowerNameCandidate.contains('portal') ||
                lowerNameCandidate.contains('student')) {
              continue; // Skip this line, it's not a name
            }

            if (nameCandidate.length > 2 && nameCandidate.length < 60) {
              // Clean up name: remove trailing dashes, KB/S, numbers, and special characters
              String cleanName = nameCandidate;
              // Remove trailing dashes, hyphens, and special characters
              cleanName = cleanName.replaceAll(RegExp(r'[-–—]+$'), '').trim();
              // Remove patterns like "KB/S", "KB", numbers at the end
              cleanName =
                  cleanName
                      .replaceAll(
                        RegExp(
                          r'\s*(KB/S?|MB/S?|\d+[KMGT]?B?)\s*$',
                          caseSensitive: false,
                        ),
                        '',
                      )
                      .trim();
              // Remove any trailing special characters except periods (for middle initials)
              cleanName =
                  cleanName.replaceAll(RegExp(r'[^\w\s\.]+$'), '').trim();
              // Remove any numbers at the end
              cleanName =
                  cleanName.replaceAll(RegExp(r'\s+\d+\s*$'), '').trim();

              // Check if it looks like a name (contains letters, not just numbers/symbols)
              if (cleanName.length >= 2 &&
                  RegExp(r'[A-Za-z]').hasMatch(cleanName)) {
                data['name'] = cleanName;
                nameFound = true;
                print(
                  'DEBUG OCR: Found name via label: "$nameCandidate" -> cleaned: "$cleanName"',
                );
                break;
              }
            }
          }
        }
      } catch (e) {
        continue;
      }
    }

    // If name not found via label, look for name-like text
    // Prioritize header area (first 5 lines) where name typically appears on right side
    if (!nameFound) {
      // First pass: Look in header area (first 5 lines) for all-uppercase names (like "PEDRITO")
      for (int i = 0; i < lines.length && i < 5; i++) {
        try {
          final line = lines[i];
          final trimmed = line.trim();
          final lowerTrimmed = trimmed.toLowerCase();

          // Skip URLs/domains (like app.evsu.edu.ph)
          if (RegExp(r'\.(edu|com|org|net|ph)').hasMatch(lowerTrimmed) ||
              lowerTrimmed.contains('.evsu') ||
              lowerTrimmed.contains('http') ||
              lowerTrimmed.contains('www.')) {
            continue; // Skip URLs/domains
          }

          // Skip table headers and common non-name patterns
          if (lowerTrimmed.contains('subjcode') ||
              lowerTrimmed.contains('sec.') ||
              lowerTrimmed.contains('description') ||
              lowerTrimmed.contains('portal') ||
              lowerTrimmed.contains('student') ||
              lowerTrimmed.contains('enrollment') ||
              lowerTrimmed.contains('academic') ||
              lowerTrimmed.contains('status') ||
              lowerTrimmed.contains('officially') ||
              lowerTrimmed.contains('enrolled') ||
              lowerTrimmed.contains('year') ||
              lowerTrimmed.contains('semester') ||
              lowerTrimmed.contains('sem') ||
              lowerTrimmed.contains('subject') ||
              lowerTrimmed.contains('course') ||
              lowerTrimmed.contains('sy:') ||
              lowerTrimmed.contains('ay:') ||
              RegExp(r'^\d+[-/]\d+').hasMatch(trimmed) || // Not a date/year
              RegExp(
                r'^[A-Z]{2,5}[\s-\.]*\d+',
              ).hasMatch(trimmed) || // Not a course code
              RegExp(r'^[A-Z]{2,}\s+[A-Z]{2,}').hasMatch(trimmed)) {
            // Not table headers like "SUBJCODE SEC"
            continue;
          }

          // Look for name-like text (2-50 chars, contains letters, no numbers at start)
          if (trimmed.length >= 2 &&
              trimmed.length <= 50 &&
              RegExp(r'^[A-Za-z]').hasMatch(trimmed) && // Starts with letter
              RegExp(
                r'^[A-Za-z\s\.]+$',
              ).hasMatch(trimmed.replaceAll(RegExp(r'[^\w\s\.]'), ''))) {
            // Only letters, spaces, periods
            // Check if it's all uppercase (likely a name in header like "PEDRITO")
            final isAllUppercase =
                trimmed == trimmed.toUpperCase() && trimmed.length <= 20;
            final hasMixedCase = RegExp(r'[a-z]').hasMatch(trimmed);

            // Accept if it's all uppercase (like "PEDRITO") or has mixed case (like "John Doe")
            if (isAllUppercase || hasMixedCase) {
              // Make sure it's not a common word or phrase
              final commonWords = [
                'subjects',
                'enrolled',
                'status',
                'academic',
                'semester',
                'subjects enrolled',
                'enrollment status',
              ];
              bool isCommonWord = false;
              for (final word in commonWords) {
                if (lowerTrimmed == word || lowerTrimmed.contains(word)) {
                  isCommonWord = true;
                  break;
                }
              }

              if (!isCommonWord) {
                // Clean up name: remove trailing dashes, KB/S, numbers, and special characters
                String cleanName = trimmed;
                // Remove trailing dashes, hyphens, and special characters
                cleanName = cleanName.replaceAll(RegExp(r'[-–—]+$'), '').trim();
                // Remove patterns like "KB/S", "KB", numbers at the end
                cleanName =
                    cleanName
                        .replaceAll(
                          RegExp(
                            r'\s*(KB/S?|MB/S?|\d+[KMGT]?B?)\s*$',
                            caseSensitive: false,
                          ),
                          '',
                        )
                        .trim();
                // Remove any trailing special characters except periods (for middle initials)
                cleanName =
                    cleanName.replaceAll(RegExp(r'[^\w\s\.]+$'), '').trim();
                // Remove any numbers at the end
                cleanName =
                    cleanName.replaceAll(RegExp(r'\s+\d+\s*$'), '').trim();

                if (cleanName.isNotEmpty && cleanName.length >= 2) {
                  data['name'] = cleanName;
                  nameFound = true;
                  print(
                    'DEBUG OCR: Found name: "$trimmed" -> cleaned: "$cleanName" at line $i',
                  );
                  break;
                }
              }
            }
          }
        } catch (e) {
          continue;
        }
      }

      // If still not found in header, search more lines (up to line 15)
      if (!nameFound) {
        for (int i = 5; i < lines.length && i < 15; i++) {
          try {
            final line = lines[i];
            final trimmed = line.trim();
            final lowerTrimmed = trimmed.toLowerCase();

            // Skip URLs/domains
            if (RegExp(r'\.(edu|com|org|net|ph)').hasMatch(lowerTrimmed) ||
                lowerTrimmed.contains('.evsu') ||
                lowerTrimmed.contains('http') ||
                lowerTrimmed.contains('www.')) {
              continue;
            }

            // Skip if contains excluded patterns
            if (lowerTrimmed.contains('subjcode') ||
                lowerTrimmed.contains('sec.') ||
                lowerTrimmed.contains('description') ||
                lowerTrimmed.contains('portal') ||
                lowerTrimmed.contains('student') ||
                lowerTrimmed.contains('enrollment') ||
                lowerTrimmed.contains('academic') ||
                lowerTrimmed.contains('status') ||
                lowerTrimmed.contains('officially') ||
                lowerTrimmed.contains('enrolled') ||
                lowerTrimmed.contains('year') ||
                lowerTrimmed.contains('semester') ||
                lowerTrimmed.contains('sem') ||
                lowerTrimmed.contains('subject') ||
                lowerTrimmed.contains('course') ||
                RegExp(r'^\d+[-/]\d+').hasMatch(trimmed) ||
                RegExp(r'^[A-Z]{2,5}[\s-\.]*\d+').hasMatch(trimmed)) {
              continue;
            }

            // Look for name-like text
            if (trimmed.length >= 2 &&
                trimmed.length <= 50 &&
                RegExp(r'^[A-Za-z]').hasMatch(trimmed) &&
                RegExp(
                  r'^[A-Za-z\s\.]+$',
                ).hasMatch(trimmed.replaceAll(RegExp(r'[^\w\s\.]'), ''))) {
              final isAllUppercase =
                  trimmed == trimmed.toUpperCase() && trimmed.length <= 20;
              final hasMixedCase = RegExp(r'[a-z]').hasMatch(trimmed);

              if (isAllUppercase || hasMixedCase) {
                final commonWords = [
                  'subjects',
                  'enrolled',
                  'status',
                  'academic',
                  'semester',
                  'subjects enrolled',
                  'enrollment status',
                ];
                bool isCommonWord = false;
                for (final word in commonWords) {
                  if (lowerTrimmed == word || lowerTrimmed.contains(word)) {
                    isCommonWord = true;
                    break;
                  }
                }

                if (!isCommonWord) {
                  // Clean up name: remove trailing dashes, KB/S, numbers, and special characters
                  String cleanName = trimmed;
                  // Remove trailing dashes, hyphens, and special characters
                  cleanName =
                      cleanName.replaceAll(RegExp(r'[-–—]+$'), '').trim();
                  // Remove patterns like "KB/S", "KB", numbers at the end
                  cleanName =
                      cleanName
                          .replaceAll(
                            RegExp(
                              r'\s*(KB/S?|MB/S?|\d+[KMGT]?B?)\s*$',
                              caseSensitive: false,
                            ),
                            '',
                          )
                          .trim();
                  // Remove any trailing special characters except periods (for middle initials)
                  cleanName =
                      cleanName.replaceAll(RegExp(r'[^\w\s\.]+$'), '').trim();
                  // Remove any numbers at the end
                  cleanName =
                      cleanName.replaceAll(RegExp(r'\s+\d+\s*$'), '').trim();

                  if (cleanName.isNotEmpty && cleanName.length >= 2) {
                    data['name'] = cleanName;
                    nameFound = true;
                    print(
                      'DEBUG OCR: Found name: "$trimmed" -> cleaned: "$cleanName" at line $i (extended search)',
                    );
                    break;
                  }
                }
              }
            }
          } catch (e) {
            continue;
          }
        }
      }
    }

    // Debug: Print if name was found
    if (data['name'].toString().isEmpty) {
      print('DEBUG OCR: Name not found. First 10 lines:');
      for (int i = 0; i < lines.length && i < 10; i++) {
        print('  Line $i: "${lines[i].trim()}"');
      }
    }

    // Extract Status (look for "Officially Enrolled" or similar)
    // Try multiple patterns, starting with most specific
    // First, check if "Officially Enrolled" appears anywhere in the text
    if (textLower.contains('officially') && textLower.contains('enrolled')) {
      // Find the full phrase
      final officiallyEnrolledPattern = RegExp(
        r'officially\s+enrolled',
        caseSensitive: false,
      );
      final match = officiallyEnrolledPattern.firstMatch(textLower);
      if (match != null) {
        data['status'] = 'Officially Enrolled';
      }
    }

    // If not found, try other patterns
    if (data['status'].toString().isEmpty) {
      final statusPatterns = [
        r'status[:\s]+([a-z\s]+enrolled)',
        r'status[:\s]+([a-z\s]+)',
        r'enrollment\s+status[:\s]+([a-z\s]+)',
      ];

      for (final pattern in statusPatterns) {
        try {
          final regex = RegExp(pattern, caseSensitive: false);
          final match = regex.firstMatch(textLower);
          if (match != null) {
            String status = '';
            // Safely get group 1 if it exists, otherwise use group 0
            try {
              if (match.groupCount >= 1 && match.group(1) != null) {
                status = match.group(1)!;
              } else {
                status = match.group(0) ?? '';
              }
            } catch (e) {
              status = match.group(0) ?? '';
            }

            // Clean and normalize status
            status = status.trim();

            if (status.toLowerCase().contains('officially') &&
                status.toLowerCase().contains('enrolled')) {
              data['status'] = 'Officially Enrolled';
              break;
            } else if (status.toLowerCase().contains('enrolled')) {
              data['status'] = status;
              break;
            }
          }
        } catch (e) {
          // Continue to next pattern if this one fails
          continue;
        }
      }
    }

    // Extract Academic Year (format: 2024-2025, AY 2024-2025, etc.)
    // Also check for semester on the same line (e.g., "2025-2026, Sem : 1")
    final ayPatterns = [
      r'(\d{4}[-/]\d{4})',
      r'ay[:\s]+(\d{4}[-/]\d{4})',
      r'academic\s+year[:\s]+(\d{4}[-/]\d{4})',
    ];

    for (final pattern in ayPatterns) {
      try {
        final regex = RegExp(pattern, caseSensitive: false);
        final match = regex.firstMatch(textLower);
        if (match != null) {
          String ay = '';
          try {
            if (match.groupCount >= 1 && match.group(1) != null) {
              ay = match.group(1)!;
            } else {
              ay = match.group(0) ?? '';
            }
          } catch (e) {
            ay = match.group(0) ?? '';
          }
          if (ay.isNotEmpty) {
            data['academic_year'] = ay.trim();

            // Check if semester is on the same line (e.g., "2025-2026, Sem : 1")
            // Find the full line containing the academic year match
            int lineStart = ocrText.lastIndexOf('\n', match.start);
            if (lineStart == -1) lineStart = 0;
            int lineEnd = ocrText.indexOf('\n', match.end);
            if (lineEnd == -1) lineEnd = ocrText.length;
            final originalLine = ocrText.substring(lineStart, lineEnd).trim();

            // Look for semester patterns after the academic year on the same line
            final semOnSameLinePatterns = [
              r'[,;]\s*sem[:\s]*([12]|first|second|1st|2nd)',
              r'[,;]\s*semester[:\s]*([12]|first|second|1st|2nd)',
              r'sem[:\s]*([12]|first|second|1st|2nd)',
            ];

            for (final semPattern in semOnSameLinePatterns) {
              try {
                final semRegex = RegExp(semPattern, caseSensitive: false);
                final semMatch = semRegex.firstMatch(
                  originalLine.toLowerCase(),
                );
                if (semMatch != null) {
                  String sem = '';
                  try {
                    if (semMatch.groupCount >= 1 && semMatch.group(1) != null) {
                      sem = semMatch.group(1)!;
                    }
                  } catch (e) {
                    // Continue
                  }

                  if (sem.isNotEmpty) {
                    sem = sem.trim().toLowerCase();
                    if (sem == '1' || sem.contains('first') || sem == '1st') {
                      data['semester'] = '1st Semester';
                    } else if (sem == '2' ||
                        sem.contains('second') ||
                        sem == '2nd') {
                      data['semester'] = '2nd Semester';
                    }
                    break;
                  }
                }
              } catch (e) {
                continue;
              }
            }

            break;
          }
        }
      } catch (e) {
        continue;
      }
    }

    // Extract Semester (1st Semester, 2nd Semester, First Semester, etc.)
    // Only extract if not already found from academic year line
    if (data['semester'].toString().isEmpty) {
      final semPatterns = [
        r'sem[:\s]+([12]|first|second|1st|2nd)',
        r'semester[:\s]+([12]|first|second|1st|2nd)',
        r'(1st|first|1)\s+semester',
        r'(2nd|second|2)\s+semester',
        r'sem[:\s]*([12])',
      ];

      for (final pattern in semPatterns) {
        try {
          final regex = RegExp(pattern, caseSensitive: false);
          final match = regex.firstMatch(textLower);
          if (match != null) {
            String sem = '';
            try {
              if (match.groupCount >= 1 && match.group(1) != null) {
                sem = match.group(1)!;
              } else {
                sem = match.group(0) ?? '';
              }
            } catch (e) {
              sem = match.group(0) ?? '';
            }

            sem = sem.trim().toLowerCase();
            if (sem == '1' || sem.contains('first') || sem == '1st') {
              data['semester'] = '1st Semester';
              break;
            } else if (sem == '2' || sem.contains('second') || sem == '2nd') {
              data['semester'] = '2nd Semester';
              break;
            }
          }
        } catch (e) {
          continue;
        }
      }
    }

    // Extract Subjects (lines that look like course codes)
    // Look for patterns like "IT 413", "IT 433", "Gen Ed. 001", "PE 122"
    final subjects = <String>[];
    final excludedKeywords = [
      'subjcode',
      'sec.',
      'description',
      'subject',
      'course',
      'code',
      'name',
      'status',
      'academic',
      'year',
      'semester',
      'enrollment',
      'portal',
      'student',
      'official',
      'enrolled',
      'date',
      'time',
      'id',
      'number',
      'lab schedule',
      'schedule',
    ];

    for (final line in lines) {
      try {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed.length < 3) continue;

        final lowerTrimmed = trimmed.toLowerCase();

        // Skip if contains excluded keywords
        bool shouldExclude = false;
        for (final keyword in excludedKeywords) {
          if (lowerTrimmed.contains(keyword)) {
            shouldExclude = true;
            break;
          }
        }
        if (shouldExclude) continue;

        // Look for course codes - extract just the code part
        // Pattern 1: Simple codes like "IT 413", "PE 122", "CS 101"
        // Match: "IT 413" or "IT413" or "IT-413"
        final simpleCodeMatch = RegExp(
          r'^([A-Z]{2,5}[\s-\.]*\d{2,4})',
        ).firstMatch(trimmed);
        if (simpleCodeMatch != null) {
          final code = simpleCodeMatch.group(1)?.trim() ?? '';
          if (code.isNotEmpty && !subjects.contains(code)) {
            subjects.add(code);
            continue; // Found a code, move to next line
          }
        }

        // Pattern 2: Multi-word codes like "Gen Ed. 001", "Gen Ed 001"
        final multiWordMatch = RegExp(
          r'^([A-Z][a-z]+\s+[A-Z][a-z]*\.?\s*\d{2,4})',
        ).firstMatch(trimmed);
        if (multiWordMatch != null) {
          final code = multiWordMatch.group(1)?.trim() ?? '';
          if (code.isNotEmpty && !subjects.contains(code)) {
            subjects.add(code);
            continue;
          }
        }

        // Pattern 3: Check if line contains a course code anywhere (not just at start)
        // This handles cases where code might be in a table cell like "IT 413    4A    System Administration"
        final codeInLineMatch = RegExp(
          r'\b([A-Z]{2,5}[\s-\.]*\d{2,4})\b',
        ).firstMatch(trimmed);
        if (codeInLineMatch != null) {
          final code = codeInLineMatch.group(1)?.trim() ?? '';
          // Clean up the code (normalize spaces)
          final cleanCode = code.replaceAll(RegExp(r'\s+'), ' ').trim();
          // Make sure it's a valid course code (has letters and numbers)
          if (cleanCode.isNotEmpty &&
              RegExp(r'[A-Z]').hasMatch(cleanCode) &&
              RegExp(r'\d').hasMatch(cleanCode) &&
              !cleanCode.contains('/')) {
            // Not a date
            if (!subjects.contains(cleanCode)) {
              subjects.add(cleanCode);
            }
          }
        }
      } catch (e) {
        // Continue to next line if this one fails
        continue;
      }
    }
    data['subjects'] = subjects;

    // Debug: Print extracted subjects
    print('DEBUG OCR: Extracted ${subjects.length} subjects: $subjects');

    // Extract Date (various date formats)
    final datePatterns = [
      r'(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})',
      r'(\d{4}[/-]\d{1,2}[/-]\d{1,2})',
    ];

    for (final pattern in datePatterns) {
      try {
        final regex = RegExp(pattern);
        final match = regex.firstMatch(ocrText);
        if (match != null) {
          String date = '';
          try {
            if (match.groupCount >= 1 && match.group(1) != null) {
              date = match.group(1)!;
            } else {
              date = match.group(0) ?? '';
            }
          } catch (e) {
            date = match.group(0) ?? '';
          }
          if (date.isNotEmpty) {
            data['date'] = date.trim();
            break;
          }
        }
      } catch (e) {
        continue;
      }
    }

    // Calculate confidence based on extracted fields
    // Each field is worth 20% (5 fields total)
    double confidence = 0.0;

    // Name (20%)
    if (data['name'].toString().isNotEmpty &&
        !data['name'].toString().toLowerCase().contains('officially') &&
        !data['name'].toString().toLowerCase().contains('enrolled')) {
      confidence += 0.20;
    }

    // Status (20%) - Must be "Officially Enrolled"
    if (data['status'].toString().toLowerCase().contains(
      'officially enrolled',
    )) {
      confidence += 0.20;
    }

    // Academic Year (20%)
    if (data['academic_year'].toString().isNotEmpty) {
      confidence += 0.20;
    }

    // Semester (20%)
    if (data['semester'].toString().isNotEmpty) {
      confidence += 0.20;
    }

    // Subjects (20%) - Must have at least 1 subject code
    if ((data['subjects'] as List).isNotEmpty) {
      confidence += 0.20;
    }

    // Additional boost if OCR text is substantial (indicates readable image)
    if (ocrText.length > 100) {
      confidence = (confidence + 0.1).clamp(0.0, 1.0);
    }

    data['confidence'] = confidence;

    return data;
  }

  /// Dispose resources
  static Future<void> dispose() async {
    await _textRecognizer.close();
  }
}
