import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'encryption_service.dart';
import 'session_service.dart';

class SupabaseService {
  static SupabaseClient? _client;
  static SupabaseClient? _adminClient;

  static const Map<String, List<String>> _columnSchemaFallbacks = {
    'system_update_settings': [
      'id',
      'maintenance_mode',
      'force_update_mode',
      'disable_all_logins',
      'updated_by',
      'updated_at',
    ],
    'admin_activity_log': [
      'id',
      'admin_username',
      'action',
      'description',
      'timestamp',
      'created_at',
    ],
    'loan_plans': [
      'id',
      'name',
      'amount',
      'term_days',
      'interest_rate',
      'penalty_rate',
      'min_topup',
      'status',
      'created_at',
      'updated_at',
    ],
    'auth_students': [
      'id',
      'student_id',
      'name',
      'email',
      'course',
      'rfid_id',
      'password',
      'auth_user_id',
      'balance',
      'is_active',
      'created_at',
      'updated_at',
      'taptopay',
    ],
    'student_info': [
      'id',
      'student_id',
      'name',
      'email',
      'course',
      'created_at',
      'updated_at',
    ],
    'id_replacement': [
      'id',
      'student_id',
      'student_name',
      'old_rfid_id',
      'new_rfid_id',
      'issue_date',
      'created_at',
      'updated_at',
    ],
    'service_accounts': [
      'id',
      'service_name',
      'service_category',
      'operational_type',
      'main_service_id',
      'contact_person',
      'email',
      'phone',
      'username',
      'password_hash',
      'balance',
      'is_active',
      'scanner_id',
      'commission_rate',
      'created_at',
      'updated_at',
    ],
    'payment_items': [
      'id',
      'service_account_id',
      'name',
      'category',
      'base_price',
      'has_sizes',
      'size_options',
      'is_active',
      'created_at',
      'updated_at',
    ],
    'top_up_requests': [
      'id',
      'user_id',
      'amount',
      'screenshot_url',
      'status',
      'created_at',
      'processed_at',
      'processed_by',
      'notes',
    ],
    'top_up_transactions': [
      'id',
      'student_id',
      'amount',
      'previous_balance',
      'new_balance',
      'transaction_type',
      'processed_by',
      'notes',
      'created_at',
      'updated_at',
    ],
    'withdrawal_requests': [
      'id',
      'student_id',
      'amount',
      'transfer_type',
      'gcash_number',
      'gcash_account_name',
      'status',
      'created_at',
      'processed_at',
      'processed_by',
      'admin_notes',
    ],
    'withdrawal_transactions': [
      'id',
      'student_id',
      'service_account_id',
      'amount',
      'transaction_type',
      'destination_service_id',
      'metadata',
      'created_at',
    ],
    'user_transfers': [
      'id',
      'sender_student_id',
      'recipient_student_id',
      'amount',
      'sender_previous_balance',
      'sender_new_balance',
      'recipient_previous_balance',
      'recipient_new_balance',
      'transaction_type',
      'status',
      'notes',
      'created_at',
      'updated_at',
    ],
    'service_transactions': [
      'id',
      'service_account_id',
      'main_service_id',
      'student_id',
      'items',
      'total_amount',
      'metadata',
      'created_at',
    ],
    'read_inbox': [
      'id',
      'student_id',
      'transaction_type',
      'transaction_id',
      'read_at',
      'created_at',
    ],
    'active_loans': [
      'id',
      'student_id',
      'loan_plan_id',
      'loan_amount',
      'interest_amount',
      'penalty_amount',
      'total_amount',
      'term_days',
      'due_date',
      'status',
      'created_at',
      'updated_at',
      'paid_at',
    ],
    'loan_payments': [
      'id',
      'loan_id',
      'student_id',
      'payment_amount',
      'payment_type',
      'remaining_balance',
      'created_at',
    ],
    'loan_applications': [
      'id',
      'student_id',
      'loan_plan_id',
      'ocr_name',
      'ocr_status',
      'ocr_academic_year',
      'ocr_semester',
      'ocr_subjects',
      'ocr_date',
      'ocr_confidence',
      'ocr_raw_text',
      'upload_image_url',
      'decision',
      'rejection_reason',
      'created_at',
      'updated_at',
    ],
    'feedback': [
      'id',
      'user_type',
      'account_username',
      'message',
      'created_at',
      'updated_at',
    ],
    'transaction_csu': [
      'id',
      'service_transactions_id',
      'sequence_number',
      'created_at',
    ],
    'service_withdrawal_requests': [
      'id',
      'service_account_id',
      'amount',
      'transfer_type',
      'gcash_number',
      'gcash_account_name',
      'status',
      'created_at',
      'processed_at',
      'processed_by',
      'admin_notes',
    ],
  };

  // Initialize Supabase client
  static Future<void> initialize() async {
    if (_client == null) {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
      _client = Supabase.instance.client;

      // Initialize encryption service
      EncryptionService.initialize();
    }
  }

  // Get Supabase client instance
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception(
        'Supabase not initialized. Call SupabaseService.initialize() first.',
      );
    }
    return _client!;
  }

  // System Update Settings

  /// Get system update settings (single-row table). If missing, returns safe defaults.
  static Future<Map<String, dynamic>> getSystemUpdateSettings() async {
    try {
      await SupabaseService.initialize();
      final response =
          await client
              .from('system_update_settings')
              .select('*')
              .limit(1)
              .maybeSingle();

      if (response == null) {
        return {
          'success': true,
          'data': {
            'maintenance_mode': false,
            'force_update_mode': false,
            'disable_all_logins': false,
          },
        };
      }

      return {
        'success': true,
        'data': {
          'maintenance_mode': response['maintenance_mode'] == true,
          'force_update_mode': response['force_update_mode'] == true,
          'disable_all_logins': response['disable_all_logins'] == true,
          'updated_at': response['updated_at'],
          'updated_by': response['updated_by'],
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load system update settings: ${e.toString()}',
        'data': {
          'maintenance_mode': false,
          'force_update_mode': false,
          'disable_all_logins': false,
        },
      };
    }
  }

  /// Upsert system update settings (single row with id=1)
  static Future<Map<String, dynamic>> upsertSystemUpdateSettings({
    required bool maintenanceMode,
    required bool forceUpdateMode,
    required bool disableAllLogins,
    String? updatedBy,
  }) async {
    try {
      await SupabaseService.initialize();
      final payload = {
        'id': 1,
        'maintenance_mode': maintenanceMode,
        'force_update_mode': forceUpdateMode,
        'disable_all_logins': disableAllLogins,
        'updated_at': DateTime.now().toIso8601String(),
        if (updatedBy != null) 'updated_by': updatedBy,
      };

      final response =
          await adminClient
              .from('system_update_settings')
              .upsert(payload, onConflict: 'id')
              .select()
              .maybeSingle();

      return {
        'success': true,
        'data': response,
        'message': 'System update settings saved',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to save system update settings: ${e.toString()}',
      };
    }
  }

  /// Reset all system update settings to false
  static Future<Map<String, dynamic>> resetSystemUpdateSettings({
    String? updatedBy,
  }) async {
    return upsertSystemUpdateSettings(
      maintenanceMode: false,
      forceUpdateMode: false,
      disableAllLogins: false,
      updatedBy: updatedBy,
    );
  }

  /// SQL helper: returns SQL to create table and basic policies
  static String get systemUpdateSetupSql => '''
-- Create table to store single-row system update flags
create table if not exists public.system_update_settings (
  id integer primary key default 1,
  maintenance_mode boolean not null default false,
  force_update_mode boolean not null default false,
  disable_all_logins boolean not null default false,
  updated_by text,
  updated_at timestamptz default now()
);

-- Ensure single-row table
insert into public.system_update_settings (id)
values (1)
on conflict (id) do nothing;

-- Enable RLS
alter table public.system_update_settings enable row level security;

-- Policies (adjust to your auth strategy)
-- Allow anonymous read (apps often use anon key); tighten if needed
drop policy if exists "Allow read to all" on public.system_update_settings;
create policy "Allow read to all" on public.system_update_settings for select using (true);

-- Allow admin updates: if you tag admins via a custom claim, adapt this
-- For example, if you have a service key context for admin tools, upserts will work.
drop policy if exists "Allow update via service key" on public.system_update_settings;
create policy "Allow update via service key" on public.system_update_settings
for all to authenticated using (true) with check (true);

-- NOTE: In production, replace the broad update policy with your proper admin role check.
''';

  // Get admin client instance (bypasses RLS)
  static SupabaseClient get adminClient {
    if (_adminClient == null) {
      _adminClient = SupabaseClient(
        SupabaseConfig.supabaseUrl,
        SupabaseConfig.supabaseServiceKey,
      );
    }
    return _adminClient!;
  }

  // Student Info Operations

  /// Insert a single student record
  static Future<Map<String, dynamic>> insertStudent({
    required String studentId,
    required String name,
    required String email,
    required String course,
  }) async {
    try {
      final response =
          await client
              .from(SupabaseConfig.studentInfoTable)
              .insert({
                'student_id': studentId,
                'name': name,
                'email': email,
                'course': course,
              })
              .select()
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Student inserted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to insert student: ${e.toString()}',
      };
    }
  }

  /// Insert multiple students from CSV data
  static Future<Map<String, dynamic>> insertStudentsBatch(
    List<Map<String, dynamic>> students,
  ) async {
    try {
      // Validate required fields for each student
      for (int i = 0; i < students.length; i++) {
        final student = students[i];
        if (student['student_id'] == null ||
            student['student_id'].toString().trim().isEmpty) {
          return {
            'success': false,
            'error': 'Missing student_id',
            'message': 'Row ${i + 1}: Student ID is required',
          };
        }
        if (student['name'] == null ||
            student['name'].toString().trim().isEmpty) {
          return {
            'success': false,
            'error': 'Missing name',
            'message': 'Row ${i + 1}: Student name is required',
          };
        }
        if (student['email'] == null ||
            student['email'].toString().trim().isEmpty) {
          return {
            'success': false,
            'error': 'Missing email',
            'message': 'Row ${i + 1}: Email is required',
          };
        }
        if (student['course'] == null ||
            student['course'].toString().trim().isEmpty) {
          return {
            'success': false,
            'error': 'Missing course',
            'message': 'Row ${i + 1}: Course is required',
          };
        }

        // Validate email format
        final email = student['email'].toString().trim();
        if (!_isValidEmail(email)) {
          return {
            'success': false,
            'error': 'Invalid email',
            'message': 'Row ${i + 1}: Invalid email format: $email',
          };
        }
      }

      // Clean and prepare data
      final cleanedStudents =
          students
              .map(
                (student) => {
                  'student_id': student['student_id'].toString().trim(),
                  'name': student['name'].toString().trim(),
                  'email': student['email'].toString().trim().toLowerCase(),
                  'course': student['course'].toString().trim(),
                },
              )
              .toList();

      // Insert batch using regular client (RLS policies should allow this)
      final response =
          await client
              .from(SupabaseConfig.studentInfoTable)
              .insert(cleanedStudents)
              .select();

      return {
        'success': true,
        'data': response,
        'count': response.length,
        'message': 'Successfully inserted ${response.length} students',
      };
    } catch (e) {
      String errorMessage = e.toString();

      // Handle specific Supabase errors
      if (errorMessage.contains('duplicate key')) {
        if (errorMessage.contains('student_id')) {
          return {
            'success': false,
            'error': 'Duplicate student ID',
            'message': 'One or more student IDs already exist in the database',
          };
        } else if (errorMessage.contains('email')) {
          return {
            'success': false,
            'error': 'Duplicate email',
            'message':
                'One or more email addresses already exist in the database',
          };
        }
      }

      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to insert students: ${e.toString()}',
      };
    }
  }

  /// Get all students
  static Future<Map<String, dynamic>> getAllStudents() async {
    try {
      final response = await SupabaseService.client
          .from(SupabaseConfig.studentInfoTable)
          .select()
          .order('created_at', ascending: false);

      return {
        'success': true,
        'data': response,
        'count': response.length,
        'message': 'Students retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve students: ${e.toString()}',
      };
    }
  }

  /// Get student by ID
  static Future<Map<String, dynamic>> getStudentById(String studentId) async {
    try {
      final response =
          await client
              .from(SupabaseConfig.studentInfoTable)
              .select()
              .eq('student_id', studentId)
              .maybeSingle();

      return {
        'success': true,
        'data': response,
        'message': response != null ? 'Student found' : 'Student not found',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve student: ${e.toString()}',
      };
    }
  }

  /// Get student for registration (checks if student exists and needs RFID)
  static Future<Map<String, dynamic>> getStudentForRegistration(
    String studentId,
  ) async {
    try {
      final response = await getStudentById(studentId);

      if (!response['success']) {
        return response;
      }

      if (response['data'] == null) {
        return {
          'success': false,
          'error': 'Student not found',
          'message':
              'Student ID $studentId not found in database. Please check the ID or import student data first.',
        };
      }

      // Student exists, return their data for autofill
      return {
        'success': true,
        'data': response['data'],
        'message': 'Student found - form auto-filled',
        'needs_rfid': true, // Since we're in registration, they need RFID
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message':
            'Failed to retrieve student for registration: ${e.toString()}',
      };
    }
  }

  /// Update student
  static Future<Map<String, dynamic>> updateStudent({
    required String studentId,
    String? name,
    String? email,
    String? course,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (name != null) updates['name'] = name.trim();
      if (email != null) updates['email'] = email.trim().toLowerCase();
      if (course != null) updates['course'] = course.trim();

      if (updates.isEmpty) {
        return {
          'success': false,
          'error': 'No updates provided',
          'message': 'No fields to update',
        };
      }

      final response =
          await client
              .from(SupabaseConfig.studentInfoTable)
              .update(updates)
              .eq('student_id', studentId)
              .select()
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Student updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update student: ${e.toString()}',
      };
    }
  }

  /// Delete student
  static Future<Map<String, dynamic>> deleteStudent(String studentId) async {
    try {
      await client
          .from(SupabaseConfig.studentInfoTable)
          .delete()
          .eq('student_id', studentId);

      return {'success': true, 'message': 'Student deleted successfully'};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete student: ${e.toString()}',
      };
    }
  }

  /// Check if student ID exists
  static Future<bool> studentIdExists(String studentId) async {
    try {
      final response =
          await client
              .from(SupabaseConfig.studentInfoTable)
              .select('student_id')
              .eq('student_id', studentId)
              .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Check if email exists
  static Future<bool> emailExists(String email) async {
    try {
      final response =
          await client
              .from(SupabaseConfig.studentInfoTable)
              .select('email')
              .eq('email', email.toLowerCase())
              .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Validate CSV data before import
  static Map<String, dynamic> validateCSVData(List<Map<String, dynamic>> data) {
    List<String> errors = [];
    List<String> warnings = [];

    if (data.isEmpty) {
      return {
        'valid': false,
        'errors': ['CSV file is empty'],
        'warnings': [],
      };
    }

    // Check required columns
    final requiredColumns = ['student_id', 'name', 'email', 'course'];
    final firstRow = data.first;

    for (String column in requiredColumns) {
      if (!firstRow.containsKey(column)) {
        errors.add('Missing required column: $column');
      }
    }

    if (errors.isNotEmpty) {
      return {'valid': false, 'errors': errors, 'warnings': warnings};
    }

    // Validate each row
    Set<String> studentIds = {};
    Set<String> emails = {};

    for (int i = 0; i < data.length; i++) {
      final row = data[i];
      final rowNum = i + 1;

      // Check for required fields
      for (String column in requiredColumns) {
        final value = row[column];
        if (value == null || value.toString().trim().isEmpty) {
          errors.add('Row $rowNum: Missing $column');
        }
      }

      // Check for duplicates within CSV
      final studentId = row['student_id']?.toString().trim();
      if (studentId != null && studentId.isNotEmpty) {
        if (studentIds.contains(studentId)) {
          errors.add('Row $rowNum: Duplicate student ID: $studentId');
        } else {
          studentIds.add(studentId);
        }
      }

      final email = row['email']?.toString().trim().toLowerCase();
      if (email != null && email.isNotEmpty) {
        if (!_isValidEmail(email)) {
          errors.add('Row $rowNum: Invalid email format: $email');
        } else if (emails.contains(email)) {
          errors.add('Row $rowNum: Duplicate email: $email');
        } else {
          emails.add(email);
        }
      }
    }

    return {
      'valid': errors.isEmpty,
      'errors': errors,
      'warnings': warnings,
      'total_rows': data.length,
      'unique_student_ids': studentIds.length,
      'unique_emails': emails.length,
    };
  }

  /// Helper function to validate email format
  static bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  /// Helper function to validate EVSU email format
  static bool _isValidEvsuEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@evsu\.edu\.ph$',
    ).hasMatch(email.toLowerCase());
  }

  /// Helper function to generate password in EvsuStudentID format
  static String _generatePassword(String studentId) {
    return 'Evsu$studentId';
  }

  /// Helper function to hash password for storage
  static String _hashPassword(String password) {
    return EncryptionService.encryptPassword(password);
  }

  /// Helper function to verify password against stored hash
  static bool _verifyPassword(String password, String storedHash) {
    return EncryptionService.verifyPassword(password, storedHash);
  }

  /// Check if student ID exists in auth_students table
  static Future<bool> _authStudentIdExists(String studentId) async {
    try {
      final response =
          await client
              .from(SupabaseConfig.authStudentsTable)
              .select('student_id')
              .eq('student_id', studentId)
              .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Check if email exists in auth_students table
  static Future<bool> _authStudentEmailExists(String email) async {
    try {
      // Since emails are encrypted, we can't efficiently check for duplicates
      // We'll rely on the unique constraint in the database
      // For now, return false to allow registration
      // TODO: Implement a better duplicate checking mechanism
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Check if RFID ID exists in auth_students table
  static Future<bool> authStudentRfidExists(String rfidId) async {
    try {
      // Encrypt the RFID ID to match against stored encrypted values
      final encryptedData = EncryptionService.encryptUserData({
        'rfid_id': rfidId,
      });
      final encryptedRfid = encryptedData['rfid_id']?.toString() ?? '';

      final response =
          await client
              .from(SupabaseConfig.authStudentsTable)
              .select('rfid_id')
              .eq('rfid_id', encryptedRfid)
              .maybeSingle();

      return response != null;
    } catch (e) {
      print('Error checking RFID existence: $e');
      return false;
    }
  }

  /// Get student data by student_id from auth_students table (for ID replacement)
  static Future<Map<String, dynamic>> getStudentByStudentId(
    String studentId,
  ) async {
    try {
      await SupabaseService.initialize();

      // Encrypt the student_id to match against stored encrypted values
      final encryptedData = EncryptionService.encryptUserData({
        'student_id': studentId,
      });
      final encryptedStudentId = encryptedData['student_id']?.toString() ?? '';

      final response =
          await client
              .from(SupabaseConfig.authStudentsTable)
              .select('*')
              .eq('student_id', encryptedStudentId)
              .maybeSingle();

      if (response == null) {
        return {'success': false, 'message': 'Student not found', 'data': null};
      }

      // Decrypt the student data
      final decryptedData = EncryptionService.decryptUserData(response);

      return {
        'success': true,
        'data': {
          'auth_user_id': response['auth_user_id'],
          'student_id': decryptedData['student_id'],
          'name': decryptedData['name'],
          'email': decryptedData['email'],
          'course': decryptedData['course'],
          'rfid_id': decryptedData['rfid_id'],
          'balance': response['balance'],
          'is_active': response['is_active'],
          'created_at': response['created_at'],
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error fetching student data: ${e.toString()}',
        'data': null,
      };
    }
  }

  /// Replace RFID card for a student
  static Future<Map<String, dynamic>> replaceRFIDCard({
    required String studentId,
    required String newRfidId,
    String? studentName,
    String? oldRfidId,
  }) async {
    try {
      await SupabaseService.initialize();

      // Check if new RFID ID already exists
      final rfidExists = await authStudentRfidExists(newRfidId);
      if (rfidExists) {
        return {
          'success': false,
          'error': 'RFID ID already exists',
          'message': 'The new RFID ID is already registered to another student',
        };
      }

      // Encrypt both student_id and new rfid_id
      final encryptedStudentId =
          EncryptionService.encryptUserData({
            'student_id': studentId,
          })['student_id']?.toString() ??
          '';

      final encryptedNewRfidId =
          EncryptionService.encryptUserData({
            'rfid_id': newRfidId,
          })['rfid_id']?.toString() ??
          '';

      // Get old RFID if not provided
      String? actualOldRfidId = oldRfidId;
      String? actualStudentName = studentName;

      if (actualOldRfidId == null || actualStudentName == null) {
        // Fetch current student data to get old RFID and name
        final studentData = await getStudentByStudentId(studentId);
        if (studentData['success'] && studentData['data'] != null) {
          final data = studentData['data'];
          actualOldRfidId ??= data['rfid_id'];
          actualStudentName ??= data['name'];
        }
      }

      // Update the RFID ID in auth_students table
      await adminClient
          .from(SupabaseConfig.authStudentsTable)
          .update({
            'rfid_id': encryptedNewRfidId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('student_id', encryptedStudentId);

      // Insert into id_replacement table to track the replacement
      if (actualStudentName != null) {
        await adminClient.from(SupabaseConfig.idReplacementTable).insert({
          'student_id': studentId,
          'student_name': actualStudentName,
          'old_rfid_id': actualOldRfidId,
          'new_rfid_id': newRfidId,
          'issue_date': DateTime.now().toIso8601String(),
        });
      }

      return {'success': true, 'message': 'RFID card successfully replaced'};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error replacing RFID card: ${e.toString()}',
      };
    }
  }

  /// Get recent ID replacements (for displaying in Recent RFID Cards)
  static Future<Map<String, dynamic>> getRecentIdReplacements({
    int limit = 5,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await adminClient
          .from(SupabaseConfig.idReplacementTable)
          .select('*')
          .order('issue_date', ascending: false)
          .limit(limit);

      return {
        'success': true,
        'data': response,
        'message': 'Recent ID replacements retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error retrieving ID replacements: ${e.toString()}',
        'data': [],
      };
    }
  }

  // Authentication Operations

  /// Register student account with Supabase Auth and student table
  static Future<Map<String, dynamic>> registerStudentAccount({
    required String studentId,
    required String name,
    required String email,
    required String course,
    required String rfidId,
  }) async {
    try {
      // Validate EVSU email format
      if (!_isValidEvsuEmail(email)) {
        return {
          'success': false,
          'error': 'Invalid email format',
          'message': 'Email must be in @evsu.edu.ph format',
        };
      }

      // Check if student ID already exists in auth_students table
      final studentExists = await _authStudentIdExists(studentId);
      if (studentExists) {
        return {
          'success': false,
          'error': 'Student ID already exists',
          'message': 'Student ID $studentId is already registered',
        };
      }

      // Check if email already exists in auth_students table
      final emailExistsInDb = await _authStudentEmailExists(email);
      if (emailExistsInDb) {
        return {
          'success': false,
          'error': 'Email already exists',
          'message': 'Email $email is already registered',
        };
      }

      // Check if RFID ID already exists in auth_students table
      final rfidExists = await authStudentRfidExists(rfidId);
      if (rfidExists) {
        return {
          'success': false,
          'error': 'RFID ID already exists',
          'message': 'RFID ID is already registered',
        };
      }

      // Generate password
      final password = _generatePassword(studentId);
      final hashedPassword = _hashPassword(password);

      // Encrypt sensitive data
      final encryptedData = EncryptionService.encryptUserData({
        'name': name,
        'email': email.toLowerCase(),
        'course': course,
        'rfid_id': rfidId,
      });

      // Register with Supabase Auth
      print(
        'Debug: Registering with email: ${email.toLowerCase()} and password: $password',
      );
      final authResponse = await client.auth.signUp(
        email: email.toLowerCase(),
        password: password,
        data: {
          'student_id': studentId,
          'name': name,
          'course': course,
          'rfid_id': rfidId,
        },
      );

      print('Debug: Auth registration response user: ${authResponse.user?.id}');
      print(
        'Debug: Auth registration response session: ${authResponse.session?.accessToken}',
      );

      if (authResponse.user == null) {
        return {
          'success': false,
          'error': 'Auth registration failed',
          'message': 'Failed to create authentication account',
        };
      }

      // Wait a moment for the auth user to be fully created
      await Future.delayed(const Duration(milliseconds: 1000));

      // Re-check for duplicates right before insert to handle race conditions
      final studentExistsRecheck = await _authStudentIdExists(studentId);
      if (studentExistsRecheck) {
        // Clean up the auth user that was created
        try {
          await adminClient.auth.admin.deleteUser(authResponse.user!.id);
          print('Cleaned up orphaned auth user: ${authResponse.user!.id}');
        } catch (cleanupError) {
          print('Warning: Failed to clean up auth user: $cleanupError');
        }
        return {
          'success': false,
          'error': 'Student ID already exists',
          'message':
              'Student ID $studentId is already registered. Please try again.',
        };
      }

      // Verify the auth user exists before inserting into auth_students
      try {
        final userCheck = await client.auth.getUser();
        if (userCheck.user?.id != authResponse.user!.id) {
          throw Exception('Auth user verification failed');
        }
      } catch (e) {
        print('Auth user verification failed: $e');
        // Continue anyway - the user might exist but not be in current session
      }

      // Insert student data into auth_students table with encrypted data
      Map<String, dynamic> studentResponse;
      try {
        studentResponse =
            await client
                .from(SupabaseConfig.authStudentsTable)
                .insert({
                  'student_id': studentId,
                  'name': encryptedData['name'], // Encrypted
                  'email': encryptedData['email'], // Encrypted
                  'course': encryptedData['course'], // Encrypted
                  'rfid_id': encryptedData['rfid_id'], // Encrypted
                  'password': hashedPassword, // Hashed password
                  'auth_user_id': authResponse.user!.id,
                  'is_active': true,
                })
                .select()
                .single();
      } catch (insertError) {
        // If insert fails, clean up the auth user that was created
        String errorString = insertError.toString();
        print('Error inserting into auth_students: $errorString');

        // Try to clean up the auth user
        try {
          await adminClient.auth.admin.deleteUser(authResponse.user!.id);
          print(
            'Cleaned up orphaned auth user after insert failure: ${authResponse.user!.id}',
          );
        } catch (cleanupError) {
          print('Warning: Failed to clean up auth user: $cleanupError');
        }

        // Re-throw the error to be handled by outer catch block
        throw insertError;
      }

      // Check if student exists in student_info table, if not insert
      final existsInStudentInfo = await studentIdExists(studentId);
      if (!existsInStudentInfo) {
        try {
          await insertStudent(
            studentId: studentId,
            name: name,
            email: email.toLowerCase(),
            course: course,
          );
          print('DEBUG: Inserted student into student_info table: $studentId');
        } catch (e) {
          // Log error but don't fail registration if student_info insert fails
          print('WARNING: Failed to insert into student_info table: $e');
          // Continue with registration success
        }
      }

      return {
        'success': true,
        'data': {
          'auth_user': authResponse.user,
          'student_info': studentResponse,
          'password': password, // Include password for display purposes
        },
        'message':
            'Student account registered successfully! Password: $password',
      };
    } catch (e) {
      String errorMessage = e.toString();

      // Handle specific Supabase errors
      if (errorMessage.contains('duplicate key')) {
        // Check if auth user was created and needs cleanup
        // Note: We can't easily get the auth user ID here, but cleanup should have happened in the insert try-catch

        if (errorMessage.contains('student_id') ||
            errorMessage.contains('auth_students_pkey')) {
          return {
            'success': false,
            'error': 'Duplicate student ID',
            'message':
                'Student ID $studentId already exists in the database. The account may have been partially created. Please check and try again.',
          };
        } else if (errorMessage.contains('email') ||
            errorMessage.contains('auth_students_email')) {
          return {
            'success': false,
            'error': 'Duplicate email',
            'message':
                'Email $email already exists in the database. The account may have been partially created. Please check and try again.',
          };
        } else if (errorMessage.contains('rfid_id') ||
            errorMessage.contains('auth_students_rfid_id')) {
          return {
            'success': false,
            'error': 'Duplicate RFID ID',
            'message':
                'RFID ID $rfidId already exists in the database. The account may have been partially created. Please check and try again.',
          };
        }
      }

      if (errorMessage.contains('User already registered') ||
          errorMessage.contains('already registered')) {
        return {
          'success': false,
          'error': 'Email already registered',
          'message':
              'Email $email is already registered in authentication system. Please use a different email or contact support.',
        };
      }

      return {
        'success': false,
        'error': e.toString(),
        'message':
            'Failed to register student account: ${e.toString()}. If the issue persists, the account may have been partially created. Please check and try again.',
      };
    }
  }

  /// Register student with RFID (for existing students from CSV import)
  static Future<Map<String, dynamic>> registerStudentWithRFID({
    required String studentId,
    required String rfidCardId,
  }) async {
    try {
      // First check if student exists
      final studentResult = await getStudentById(studentId);
      if (!studentResult['success'] || studentResult['data'] == null) {
        return {
          'success': false,
          'error': 'Student not found',
          'message': 'Student ID $studentId not found in database',
        };
      }

      // For now, we'll create a simple success response
      // In a full implementation, you might want to add an RFID field to the table
      // or create a separate RFID assignments table
      return {
        'success': true,
        'data': {
          'student_id': studentId,
          'rfid_card': rfidCardId,
          'student_data': studentResult['data'],
        },
        'message': 'Student registered with RFID card successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to register student with RFID: ${e.toString()}',
      };
    }
  }

  /// Get database statistics
  static Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      final response = await SupabaseService.client
          .from(SupabaseConfig.studentInfoTable)
          .select('student_id, course')
          .order('created_at', ascending: false);

      // Count by course
      Map<String, int> courseCount = {};
      for (var student in response) {
        final course = student['course'].toString();
        courseCount[course] = (courseCount[course] ?? 0) + 1;
      }

      return {
        'success': true,
        'total_students': response.length,
        'course_breakdown': courseCount,
        'message': 'Statistics retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve statistics: ${e.toString()}',
      };
    }
  }

  // Balance Overview Operations

  /// Get total balance overview for students and service accounts
  static Future<Map<String, dynamic>> getBalanceOverview() async {
    try {
      await SupabaseService.initialize();

      // Get total student balances from auth_students table
      final studentsResponse = await adminClient
          .from(SupabaseConfig.authStudentsTable)
          .select('balance');

      double totalStudentBalance = 0.0;
      for (var student in studentsResponse) {
        final balance = (student['balance'] as num?)?.toDouble() ?? 0.0;
        totalStudentBalance += balance;
      }

      // Get total service account balances from service_accounts table
      final servicesResponse = await adminClient
          .from('service_accounts')
          .select('balance')
          .eq('is_active', true);

      double totalServiceBalance = 0.0;
      for (var service in servicesResponse) {
        final balance = (service['balance'] as num?)?.toDouble() ?? 0.0;
        totalServiceBalance += balance;
      }

      // Calculate total system balance
      final totalSystemBalance = totalStudentBalance + totalServiceBalance;

      return {
        'success': true,
        'data': {
          'total_student_balance': totalStudentBalance,
          'total_service_balance': totalServiceBalance,
          'total_system_balance': totalSystemBalance,
          'student_count': studentsResponse.length,
          'service_count': servicesResponse.length,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching balance overview: $e',
        'data': {
          'total_student_balance': 0.0,
          'total_service_balance': 0.0,
          'total_system_balance': 0.0,
          'student_count': 0,
          'service_count': 0,
        },
      };
    }
  }

  /// Get detailed balance breakdown by service accounts
  static Future<Map<String, dynamic>> getServiceBalanceBreakdown() async {
    try {
      await SupabaseService.initialize();

      final servicesResponse = await adminClient
          .from('service_accounts')
          .select('service_name, balance, is_active')
          .eq('is_active', true)
          .order('balance', ascending: false);

      List<Map<String, dynamic>> serviceBalances = [];
      double totalServiceBalance = 0.0;

      for (var service in servicesResponse) {
        final balance = (service['balance'] as num?)?.toDouble() ?? 0.0;
        totalServiceBalance += balance;

        serviceBalances.add({
          'service_name': service['service_name'] ?? 'Unknown',
          'balance': balance,
          'is_active': service['is_active'] ?? false,
        });
      }

      return {
        'success': true,
        'data': {
          'services': serviceBalances,
          'total_balance': totalServiceBalance,
          'count': serviceBalances.length,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching service balance breakdown: $e',
        'data': {'services': [], 'total_balance': 0.0, 'count': 0},
      };
    }
  }

  /// Get top-up analysis data with real transaction amounts and counts
  static Future<Map<String, dynamic>> getTopUpAnalysis({
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      await SupabaseService.initialize();

      // Build date filter
      final Map<String, dynamic> filter = {};
      if (start != null) {
        filter['created_at.gte'] = start.toIso8601String();
      }
      if (end != null) {
        filter['created_at.lt'] = end.toIso8601String();
      }

      // Get top-up transactions from top_up_transactions table
      // Only include transaction_type = 'top_up', exclude 'loan_disbursement'
      final topupQuery = client
          .from('top_up_transactions')
          .select('amount, created_at, transaction_type')
          .eq('transaction_type', 'top_up');
      if (filter.containsKey('created_at.gte')) {
        topupQuery.gte('created_at', filter['created_at.gte']);
      }
      if (filter.containsKey('created_at.lt')) {
        topupQuery.lt('created_at', filter['created_at.lt']);
      }
      final topups = await topupQuery;

      // Group by amount and count
      Map<double, int> amountCounts = {};
      for (var topup in topups) {
        final amount = (topup['amount'] as num).toDouble();
        amountCounts[amount] = (amountCounts[amount] ?? 0) + 1;
      }

      // Convert to list and sort by count (descending)
      List<Map<String, dynamic>> topupAnalysis =
          amountCounts.entries
              .map(
                (entry) => {
                  'amount': entry.key,
                  'count': entry.value,
                  'percentage': 0.0, // Will be calculated below
                },
              )
              .toList();

      // Sort by count descending and calculate percentages
      topupAnalysis.sort(
        (a, b) => (b['count'] as int).compareTo(a['count'] as int),
      );
      final totalTopups = topups.length;
      for (var item in topupAnalysis) {
        item['percentage'] =
            totalTopups > 0
                ? ((item['count'] as int) / totalTopups * 100)
                : 0.0;
      }

      return {
        'success': true,
        'data': {
          'topups': topupAnalysis.take(5).toList(), // Top 5
          'total_transactions': totalTopups,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching top-up analysis: $e',
        'data': {'topups': [], 'total_transactions': 0},
      };
    }
  }

  /// Get aggregated totals for manual cash top-ups vs GCash verification top-ups.
  ///
  /// Optional [start] and [end] parameters filter the date range (inclusive start, exclusive end).
  static Future<Map<String, dynamic>> getTopUpChannelTotals({
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      await SupabaseService.initialize();

      final Map<String, dynamic> filter = {};
      if (start != null) {
        filter['created_at.gte'] = start.toIso8601String();
      }
      if (end != null) {
        filter['created_at.lt'] = end.toIso8601String();
      }

      final manualQuery = client
          .from('top_up_transactions')
          .select('amount, created_at')
          .eq('transaction_type', 'top_up');
      if (filter.containsKey('created_at.gte')) {
        manualQuery.gte('created_at', filter['created_at.gte']);
      }
      if (filter.containsKey('created_at.lt')) {
        manualQuery.lt('created_at', filter['created_at.lt']);
      }
      final manualResults = await manualQuery;

      final gcashQuery = client
          .from('top_up_transactions')
          .select('amount, created_at')
          .eq('transaction_type', 'top_up_gcash');
      if (filter.containsKey('created_at.gte')) {
        gcashQuery.gte('created_at', filter['created_at.gte']);
      }
      if (filter.containsKey('created_at.lt')) {
        gcashQuery.lt('created_at', filter['created_at.lt']);
      }
      final gcashResults = await gcashQuery;

      double manualTotal = 0.0;
      for (final entry in manualResults) {
        manualTotal += (entry['amount'] as num?)?.toDouble() ?? 0.0;
      }

      double gcashTotal = 0.0;
      for (final entry in gcashResults) {
        gcashTotal += (entry['amount'] as num?)?.toDouble() ?? 0.0;
      }

      return {
        'success': true,
        'data': {
          'manual_total': manualTotal,
          'manual_count': manualResults.length,
          'gcash_total': gcashTotal,
          'gcash_count': gcashResults.length,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Error fetching top-up channel totals: ${e.toString()}',
        'data': {
          'manual_total': 0.0,
          'manual_count': 0,
          'gcash_total': 0.0,
          'gcash_count': 0,
        },
      };
    }
  }

  /// Get loan analysis data with real loan amounts and counts
  static Future<Map<String, dynamic>> getLoanAnalysis({
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      await SupabaseService.initialize();

      // Build date filter
      final Map<String, dynamic> filter = {};
      if (start != null) {
        filter['paid_at.gte'] = start.toIso8601String();
      }
      if (end != null) {
        filter['paid_at.lt'] = end.toIso8601String();
      }

      // Get paid loans from active_loans table
      final loanQuery = client
          .from('active_loans')
          .select('loan_amount, paid_at, status')
          .eq('status', 'paid');
      if (filter.containsKey('paid_at.gte')) {
        loanQuery.gte('paid_at', filter['paid_at.gte']);
      }
      if (filter.containsKey('paid_at.lt')) {
        loanQuery.lt('paid_at', filter['paid_at.lt']);
      }
      final loans = await loanQuery;

      // Group by amount and count
      Map<double, int> amountCounts = {};
      for (var loan in loans) {
        final amount = (loan['loan_amount'] as num?)?.toDouble() ?? 0.0;
        amountCounts[amount] = (amountCounts[amount] ?? 0) + 1;
      }

      // Convert to list and sort by count (descending)
      List<Map<String, dynamic>> loanAnalysis =
          amountCounts.entries
              .map(
                (entry) => {
                  'amount': entry.key,
                  'count': entry.value,
                  'percentage': 0.0, // Will be calculated below
                },
              )
              .toList();

      // Sort by count descending and calculate percentages
      loanAnalysis.sort(
        (a, b) => (b['count'] as int).compareTo(a['count'] as int),
      );
      final totalLoans = loans.length;
      for (var item in loanAnalysis) {
        item['percentage'] =
            totalLoans > 0 ? ((item['count'] as int) / totalLoans * 100) : 0.0;
      }

      return {
        'success': true,
        'data': {
          'loans': loanAnalysis.take(5).toList(), // Top 5
          'total_transactions': totalLoans,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching loan analysis: $e',
        'data': {'loans': [], 'total_transactions': 0},
      };
    }
  }

  /// Get top vendors by transaction count and revenue
  static Future<Map<String, dynamic>> getTopVendors({
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      await SupabaseService.initialize();

      print("DEBUG: Starting top vendors analysis");
      print("DEBUG: Date range - start: $start, end: $end");

      // Build date filter
      final Map<String, dynamic> filter = {};
      if (start != null) {
        filter['created_at.gte'] = start.toIso8601String();
      }
      if (end != null) {
        filter['created_at.lt'] = end.toIso8601String();
      }

      print("DEBUG: Date filter: $filter");

      // Get service transactions with service account info
      // Join service_transactions with service_accounts to get service names
      // Use specific foreign key relationship: service_transactions_service_account_id_fkey
      final serviceQuery = client
          .from('service_transactions')
          .select(
            'service_account_id, amount, created_at, service_accounts!service_transactions_service_account_id_fkey(service_name)',
          );
      if (filter.containsKey('created_at.gte')) {
        serviceQuery.gte('created_at', filter['created_at.gte']);
      }
      if (filter.containsKey('created_at.lt')) {
        serviceQuery.lt('created_at', filter['created_at.lt']);
      }

      print("DEBUG: Executing top vendors query on service_transactions table");
      final transactions = await serviceQuery;
      print(
        "DEBUG: Top vendors query returned ${transactions.length} transactions",
      );

      if (transactions.isNotEmpty) {
        print("DEBUG: First transaction sample: ${transactions.first}");
      }

      // Group by service_account_id
      Map<String, Map<String, dynamic>> serviceStats = {};
      for (var transaction in transactions) {
        final serviceAccountId =
            transaction['service_account_id']?.toString() ?? 'unknown';
        final serviceName =
            transaction['service_accounts']?['service_name']?.toString() ??
            'Unknown Service';
        final amount = (transaction['amount'] as num?)?.toDouble() ?? 0.0;

        if (!serviceStats.containsKey(serviceAccountId)) {
          serviceStats[serviceAccountId] = {
            'service_account_id': serviceAccountId,
            'service_name': serviceName,
            'total_revenue': 0.0,
            'transaction_count': 0,
          };
        }

        serviceStats[serviceAccountId]!['total_revenue'] += amount;
        serviceStats[serviceAccountId]!['transaction_count'] += 1;
      }

      // Convert to list and sort by transaction count (descending)
      List<Map<String, dynamic>> vendorAnalysis = serviceStats.values.toList();
      vendorAnalysis.sort(
        (a, b) => (b['transaction_count'] as int).compareTo(
          a['transaction_count'] as int,
        ),
      );

      return {
        'success': true,
        'data': {
          'vendors': vendorAnalysis.take(5).toList(), // Top 5
          'total_services': serviceStats.length,
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching top vendors: $e',
        'data': {'vendors': [], 'total_services': 0},
      };
    }
  }

  /// Get vendor transaction count analysis - which vendors have the most transactions
  static Future<Map<String, dynamic>> getVendorTransactionCountAnalysis({
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      await SupabaseService.initialize();

      print("DEBUG: Starting vendor transaction count analysis");
      print("DEBUG: Date range - start: $start, end: $end");

      // Build date filter
      final Map<String, dynamic> filter = {};
      if (start != null) {
        filter['created_at.gte'] = start.toIso8601String();
      }
      if (end != null) {
        filter['created_at.lt'] = end.toIso8601String();
      }

      print("DEBUG: Date filter: $filter");

      // Get all service transactions with service account info
      // Join service_transactions with service_accounts to get service names
      // Use specific foreign key relationship: service_transactions_service_account_id_fkey
      final serviceQuery = client
          .from('service_transactions')
          .select(
            'service_account_id, created_at, service_accounts!service_transactions_service_account_id_fkey(service_name)',
          );
      if (filter.containsKey('created_at.gte')) {
        serviceQuery.gte('created_at', filter['created_at.gte']);
      }
      if (filter.containsKey('created_at.lt')) {
        serviceQuery.lt('created_at', filter['created_at.lt']);
      }

      print("DEBUG: Executing query on service_transactions table");
      final transactions = await serviceQuery;
      print("DEBUG: Query returned ${transactions.length} transactions");

      if (transactions.isNotEmpty) {
        print("DEBUG: First transaction sample: ${transactions.first}");
      }

      // Group by service_account_id
      Map<String, Map<String, dynamic>> serviceStats = {};
      print("DEBUG: Starting to group transactions by service_account_id");

      for (var transaction in transactions) {
        final serviceAccountId =
            transaction['service_account_id']?.toString() ?? 'unknown';
        final serviceName =
            transaction['service_accounts']?['service_name']?.toString() ??
            'Unknown Service';

        print(
          "DEBUG: Processing transaction - serviceAccountId: $serviceAccountId, serviceName: $serviceName",
        );

        if (!serviceStats.containsKey(serviceAccountId)) {
          serviceStats[serviceAccountId] = {
            'service_account_id': serviceAccountId,
            'service_name': serviceName,
            'total_transactions': 0,
          };
          print(
            "DEBUG: Created new service stat for $serviceName (ID: $serviceAccountId)",
          );
        }

        serviceStats[serviceAccountId]!['total_transactions'] += 1;
      }

      print("DEBUG: Grouped into ${serviceStats.length} unique services");
      print("DEBUG: Service stats: $serviceStats");

      // Convert to list and sort by total transaction count (descending)
      List<Map<String, dynamic>> vendorAnalysis = serviceStats.values.toList();
      vendorAnalysis.sort(
        (a, b) => (b['total_transactions'] as int).compareTo(
          a['total_transactions'] as int,
        ),
      );

      final topVendors = vendorAnalysis.take(10).toList();
      print("DEBUG: Final vendor analysis - ${topVendors.length} vendors");
      print("DEBUG: Top vendors: $topVendors");

      return {
        'success': true,
        'data': {
          'vendors': topVendors, // Top 10
          'total_services': serviceStats.length,
        },
      };
    } catch (e) {
      print("DEBUG: Error in vendor transaction count analysis: $e");
      print("DEBUG: Stack trace: ${StackTrace.current}");
      return {
        'success': false,
        'message': 'Error fetching vendor transaction count analysis: $e',
        'data': {'vendors': [], 'total_services': 0},
      };
    }
  }

  // API Configuration Operations

  /// Get API configuration settings (for admin users)
  static Future<Map<String, dynamic>> getApiConfiguration() async {
    try {
      await SupabaseService.initialize();

      print("DEBUG: Fetching API configuration");

      // Use admin client to bypass RLS for admin operations
      final response = await adminClient
          .from('api_configuration')
          .select('*')
          .limit(1);

      if (response.isNotEmpty) {
        print("DEBUG: API configuration loaded: ${response.first}");
        final data = Map<String, dynamic>.from(response.first);
        // Ensure PayMongo keys present with defaults to avoid null checks in UI
        data.putIfAbsent('paymongo_enabled', () => false);
        data.putIfAbsent('paymongo_public_key', () => '');
        data.putIfAbsent('paymongo_secret_key', () => '');
        data.putIfAbsent('paymongo_webhook_secret', () => '');
        data.putIfAbsent('paymongo_provider', () => 'gcash');
        return {'success': true, 'data': data};
      } else {
        print("DEBUG: No API configuration found, returning defaults");
        return {
          'success': true,
          'data': {
            'enabled': false,
            'xpub_key': '',
            'wallet_hash': '',
            'webhook_url': '',
            // PayMongo defaults
            'paymongo_enabled': false,
            'paymongo_public_key': '',
            'paymongo_secret_key': '',
            'paymongo_webhook_secret': '',
            'paymongo_provider': 'gcash',
          },
        };
      }
    } catch (e) {
      print("DEBUG: Error fetching API configuration: $e");
      return {
        'success': false,
        'message': 'Error fetching API configuration: $e',
        'data': {
          'enabled': false,
          'xpub_key': '',
          'wallet_hash': '',
          'webhook_url': '',
          // PayMongo defaults
          'paymongo_enabled': false,
          'paymongo_public_key': '',
          'paymongo_secret_key': '',
          'paymongo_webhook_secret': '',
          'paymongo_provider': 'gcash',
        },
      };
    }
  }

  /// Save API configuration settings (for admin users)
  static Future<Map<String, dynamic>> saveApiConfiguration({
    required bool enabled,
    required String xpubKey,
    required String walletHash,
    required String webhookUrl,
  }) async {
    try {
      await SupabaseService.initialize();

      print("DEBUG: Saving API configuration");
      print(
        "DEBUG: enabled: $enabled, xpubKey: ${xpubKey.isNotEmpty ? '${xpubKey.substring(0, xpubKey.length > 10 ? 10 : xpubKey.length)}...' : 'empty'}, walletHash: ${walletHash.isNotEmpty ? '${walletHash.substring(0, walletHash.length > 10 ? 10 : walletHash.length)}...' : 'empty'}",
      );

      // Use admin client to bypass RLS for admin operations
      // First, check if any record exists
      final existingRecords = await adminClient
          .from('api_configuration')
          .select('id')
          .limit(1);

      if (existingRecords.isNotEmpty) {
        // Update existing record
        await adminClient
            .from('api_configuration')
            .update({
              'enabled': enabled,
              'xpub_key': xpubKey,
              'wallet_hash': walletHash,
              'webhook_url': webhookUrl,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existingRecords.first['id']);

        print("DEBUG: API configuration updated successfully");
        return {
          'success': true,
          'message': 'API configuration updated successfully',
        };
      } else {
        // Insert new record
        await adminClient.from('api_configuration').insert({
          'enabled': enabled,
          'xpub_key': xpubKey,
          'wallet_hash': walletHash,
          'webhook_url': webhookUrl,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        print("DEBUG: API configuration created successfully");
        return {
          'success': true,
          'message': 'API configuration created successfully',
        };
      }
    } catch (e) {
      print("DEBUG: Error saving API configuration: $e");
      return {
        'success': false,
        'message': 'Error saving API configuration: $e',
      };
    }
  }

  /// Get PayMongo configuration
  static Future<Map<String, dynamic>> getPaymongoConfiguration() async {
    try {
      await SupabaseService.initialize();

      final response = await adminClient
          .from('api_configuration')
          .select(
            'paymongo_enabled, paymongo_public_key, paymongo_secret_key, paymongo_webhook_secret, paymongo_provider',
          )
          .limit(1);

      if (response.isNotEmpty) {
        final data = Map<String, dynamic>.from(response.first);
        return {
          'success': true,
          'data': {
            'paymongo_enabled': data['paymongo_enabled'] ?? false,
            'paymongo_public_key': data['paymongo_public_key'] ?? '',
            'paymongo_secret_key': data['paymongo_secret_key'] ?? '',
            'paymongo_webhook_secret': data['paymongo_webhook_secret'] ?? '',
            'paymongo_provider': data['paymongo_provider'] ?? 'gcash',
          },
        };
      }

      return {
        'success': true,
        'data': {
          'paymongo_enabled': false,
          'paymongo_public_key': '',
          'paymongo_secret_key': '',
          'paymongo_webhook_secret': '',
          'paymongo_provider': 'gcash',
        },
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error fetching PayMongo configuration: $e',
      };
    }
  }

  /// Save PayMongo configuration
  static Future<Map<String, dynamic>> savePaymongoConfiguration({
    required bool enabled,
    required String publicKey,
    required String secretKey,
    required String webhookSecret,
    required String provider,
  }) async {
    try {
      await SupabaseService.initialize();

      // Check if record exists
      final existingRecords = await adminClient
          .from('api_configuration')
          .select('id')
          .limit(1);

      final payload = {
        'paymongo_enabled': enabled,
        'paymongo_public_key': publicKey,
        'paymongo_secret_key': secretKey,
        'paymongo_webhook_secret': webhookSecret,
        'paymongo_provider': provider,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (existingRecords.isNotEmpty) {
        await adminClient
            .from('api_configuration')
            .update(payload)
            .eq('id', existingRecords.first['id']);
      } else {
        await adminClient.from('api_configuration').insert({
          ...payload,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      return {
        'success': true,
        'message': 'PayMongo configuration saved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error saving PayMongo configuration: $e',
      };
    }
  }

  /// Check if Paytaca is enabled (for students - only reads enabled field)
  static Future<bool> isPaytacaEnabled() async {
    try {
      await SupabaseService.initialize();

      print("DEBUG: Checking Paytaca enabled status...");
      print("DEBUG: Current user: ${client.auth.currentUser?.id}");
      print(
        "DEBUG: Auth state: ${client.auth.currentSession?.user != null ? 'authenticated' : 'not authenticated'}",
      );

      // First try with regular client (for authenticated users)
      try {
        final response = await SupabaseService.client
            .from('api_configuration')
            .select('enabled')
            .limit(1);

        print("DEBUG: API configuration query response: $response");

        if (response.isNotEmpty) {
          final enabled = response.first['enabled'] == true;
          print("DEBUG: Paytaca enabled status: $enabled");
          return enabled;
        }
      } catch (clientError) {
        print("DEBUG: Regular client query failed: $clientError");

        // If regular client fails, try with admin client as fallback
        try {
          print("DEBUG: Trying with admin client as fallback...");
          final adminResponse = await adminClient
              .from('api_configuration')
              .select('enabled')
              .limit(1);

          print("DEBUG: Admin client query response: $adminResponse");

          if (adminResponse.isNotEmpty) {
            final enabled = adminResponse.first['enabled'] == true;
            print("DEBUG: Paytaca enabled status (via admin): $enabled");
            return enabled;
          }
        } catch (adminError) {
          print("DEBUG: Admin client query also failed: $adminError");
        }
      }

      print("DEBUG: No API configuration found, Paytaca disabled by default");
      return false;
    } catch (e) {
      print("DEBUG: Error checking Paytaca status: $e");
      print("DEBUG: Error details: ${e.toString()}");
      return false;
    }
  }

  // Transaction Operations

  /// Get service transactions with service account and student information
  static Future<Map<String, dynamic>> getServiceTransactions({
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async {
    try {
      await SupabaseService.initialize();

      final int fetchLimit = limit <= 0 ? 50 : limit;
      final int topupLimit = ((fetchLimit * 2) > 200 ? 200 : (fetchLimit * 2));
      final int withdrawalLimit = fetchLimit;

      print(
        "DEBUG: Fetching admin transactions (services, top-ups, loans) with limit $fetchLimit",
      );

      // Build service transactions query
      var serviceQuery = client
          .from('service_transactions')
          .select(
            '''
              id,
              total_amount,
              created_at,
              student_id,
              service_accounts!service_transactions_service_account_id_fkey(service_name)
            '''.trim(),
          );

      // Build top-up (including loan disbursements) transactions query
      final List<String> trackedTopupTypes = [
        'top_up',
        'top_up_gcash',
        'loan_disbursement',
      ];

      var topupQuery = client
          .from('top_up_transactions')
          .select(
            '''
              id,
              student_id,
              amount,
              previous_balance,
              new_balance,
              transaction_type,
              processed_by,
              notes,
              created_at
            '''.trim(),
          )
          .inFilter('transaction_type', trackedTopupTypes);

      var withdrawalQuery = adminClient
          .from('withdrawal_transactions')
          .select(
            '''
              id,
              student_id,
              service_account_id,
              amount,
              transaction_type,
              destination_service_id,
              metadata,
              created_at
            '''.trim(),
          );

      if (start != null) {
        final isoStart = start.toIso8601String();
        serviceQuery = serviceQuery.gte('created_at', isoStart);
        topupQuery = topupQuery.gte('created_at', isoStart);
        withdrawalQuery = withdrawalQuery.gte('created_at', isoStart);
      }

      if (end != null) {
        final isoEnd = end.toIso8601String();
        serviceQuery = serviceQuery.lt('created_at', isoEnd);
        topupQuery = topupQuery.lt('created_at', isoEnd);
        withdrawalQuery = withdrawalQuery.lt('created_at', isoEnd);
      }

      final serviceTransactions = await serviceQuery
          .order('created_at', ascending: false)
          .limit(fetchLimit);
      final topupTransactions = await topupQuery
          .order('created_at', ascending: false)
          .limit(topupLimit);
      final withdrawalTransactions = await withdrawalQuery
          .order('created_at', ascending: false)
          .limit(withdrawalLimit);
      print(
        "DEBUG: withdrawalTransactions fetched: ${withdrawalTransactions.length}",
      );

      print(
        "DEBUG: serviceTransactions fetched: ${serviceTransactions.length}",
      );
      print("DEBUG: topupTransactions fetched: ${topupTransactions.length}");

      if (topupTransactions.isNotEmpty) {
        final Map<String, int> topupTypeCounts = {};
        for (final transaction in topupTransactions) {
          final type =
              transaction['transaction_type']?.toString() ?? 'unknown_type';
          topupTypeCounts[type] = (topupTypeCounts[type] ?? 0) + 1;
        }
        print('DEBUG: topupTransactions type distribution: $topupTypeCounts');
      } else {
        print('DEBUG: No top_up_transactions returned by query');
      }

      final Set<String> studentIds = {};
      final Set<int> serviceAccountIds = {};

      for (final transaction in serviceTransactions) {
        final studentId = transaction['student_id']?.toString();
        if (studentId != null && studentId.isNotEmpty) {
          studentIds.add(studentId);
        }
      }

      for (final transaction in topupTransactions) {
        final studentId = transaction['student_id']?.toString();
        if (studentId != null && studentId.isNotEmpty) {
          studentIds.add(studentId);
        }
      }

      for (final transaction in withdrawalTransactions) {
        final studentId = transaction['student_id']?.toString();
        if (studentId != null && studentId.isNotEmpty) {
          studentIds.add(studentId);
        }

        final int? serviceAccountId = _coerceToInt(
          transaction['service_account_id'],
        );
        final int? destinationServiceId = _coerceToInt(
          transaction['destination_service_id'],
        );

        if (serviceAccountId != null) {
          serviceAccountIds.add(serviceAccountId);
        }

        if (destinationServiceId != null) {
          serviceAccountIds.add(destinationServiceId);
        }
      }

      // Build loan payments query
      var loanPaymentQuery = client
          .from('loan_payments')
          .select(
            '''
              id,
              loan_id,
              student_id,
              payment_amount,
              payment_type,
              remaining_balance,
              created_at,
              active_loans!loan_payments_loan_id_fkey(
                loan_plan_id,
                loan_plans!active_loans_loan_plan_id_fkey(name)
              )
            '''.trim(),
          );

      if (start != null) {
        final isoStart = start.toIso8601String();
        loanPaymentQuery = loanPaymentQuery.gte('created_at', isoStart);
      }

      if (end != null) {
        final isoEnd = end.toIso8601String();
        loanPaymentQuery = loanPaymentQuery.lt('created_at', isoEnd);
      }

      final loanPayments = await loanPaymentQuery
          .order('created_at', ascending: false)
          .limit(topupLimit);

      print("DEBUG: loanPayments fetched: ${loanPayments.length}");

      for (final payment in loanPayments) {
        final studentId = payment['student_id']?.toString();
        if (studentId != null && studentId.isNotEmpty) {
          studentIds.add(studentId);
        }
      }

      final studentNames = await _fetchStudentNames(studentIds);
      final serviceNames = await _fetchServiceNames(serviceAccountIds);

      final List<Map<String, dynamic>> combinedTransactions = [];

      for (final transaction in serviceTransactions) {
        final studentId = transaction['student_id']?.toString() ?? 'Unknown';
        final serviceName =
            transaction['service_accounts']?['service_name']?.toString() ??
            'Unknown Service';
        combinedTransactions.add({
          'id': transaction['id']?.toString() ?? 'Unknown',
          'amount': (transaction['total_amount'] as num?)?.toDouble() ?? 0.0,
          'created_at': transaction['created_at']?.toString() ?? '',
          'service_name': serviceName,
          'student_name': studentNames[studentId] ?? 'Student $studentId',
          'student_id': studentId,
          'status': 'completed',
          'category': 'transactions',
          'transaction_type': 'service_payment',
          'notes': null,
          'previous_balance': null,
          'new_balance': null,
          'processed_by': serviceName,
          'account_type': 'student',
        });
      }

      for (final transaction in topupTransactions) {
        final studentId = transaction['student_id']?.toString() ?? 'Unknown';
        final transactionType =
            transaction['transaction_type']?.toString() ?? 'top_up';
        final category =
            transactionType == 'loan_disbursement' ? 'loan' : 'top_up';
        final processedBy =
            transaction['processed_by']?.toString() ??
            (category == 'loan' ? 'Loan Program' : 'Top-up Desk');

        combinedTransactions.add({
          'id': transaction['id']?.toString() ?? 'Unknown',
          'amount': (transaction['amount'] as num?)?.toDouble() ?? 0.0,
          'created_at': transaction['created_at']?.toString() ?? '',
          'service_name': processedBy,
          'student_name': studentNames[studentId] ?? 'Student $studentId',
          'student_id': studentId,
          'status': 'completed',
          'category': category,
          'transaction_type': transactionType,
          'notes': transaction['notes']?.toString(),
          'previous_balance':
              (transaction['previous_balance'] as num?)?.toDouble(),
          'new_balance': (transaction['new_balance'] as num?)?.toDouble(),
          'processed_by': processedBy,
          'account_type': 'student',
        });
      }

      // Add loan payments to combined transactions
      for (final payment in loanPayments) {
        final studentId = payment['student_id']?.toString() ?? 'Unknown';
        final loanPlanName =
            payment['active_loans']?['loan_plans']?['name']?.toString() ??
            'Loan Payment';
        final paymentAmount =
            (payment['payment_amount'] as num?)?.toDouble() ?? 0.0;
        final remainingBalance =
            (payment['remaining_balance'] as num?)?.toDouble() ?? 0.0;
        // Calculate previous balance (payment amount + remaining balance)
        final previousBalance = paymentAmount + remainingBalance;

        combinedTransactions.add({
          'id': payment['id']?.toString() ?? 'Unknown',
          'amount': paymentAmount,
          'created_at': payment['created_at']?.toString() ?? '',
          'service_name': loanPlanName,
          'student_name': studentNames[studentId] ?? 'Student $studentId',
          'student_id': studentId,
          'status': 'completed',
          'category': 'loan',
          'transaction_type': 'loan_payment',
          'notes': null,
          'previous_balance': previousBalance,
          'new_balance': remainingBalance,
          'processed_by': 'Loan System',
          'account_type': 'student',
        });
      }

      for (final transaction in withdrawalTransactions) {
        final String? studentId = transaction['student_id']?.toString();
        final int? serviceAccountId = _coerceToInt(
          transaction['service_account_id'],
        );
        final int? destinationServiceId = _coerceToInt(
          transaction['destination_service_id'],
        );

        Map<String, dynamic>? metadata;
        final dynamic rawMetadata = transaction['metadata'];
        if (rawMetadata is Map) {
          metadata = Map<String, dynamic>.from(rawMetadata);
        }

        final bool isServiceWithdrawal = studentId == null || studentId.isEmpty;

        String primaryName;
        String primaryId;
        String accountType;

        if (!isServiceWithdrawal && studentId != null) {
          primaryName = studentNames[studentId] ?? 'Student $studentId';
          primaryId = studentId;
          accountType = 'student';
        } else if (serviceAccountId != null) {
          final serviceName =
              serviceNames[serviceAccountId] ??
              metadata?['service_name']?.toString() ??
              'Service #$serviceAccountId';
          primaryName = serviceName;
          primaryId = serviceAccountId.toString();
          accountType = 'service';
        } else {
          primaryName = 'Unknown Account';
          primaryId = 'N/A';
          accountType = 'service';
        }

        String vendorName =
            metadata?['destination_service_name']?.toString() ??
            metadata?['service_name']?.toString() ??
            'Admin Withdrawal';

        if (destinationServiceId != null) {
          vendorName =
              serviceNames[destinationServiceId] ??
              'Service #$destinationServiceId';
        } else if (isServiceWithdrawal) {
          final destinationType =
              metadata?['destination_type']?.toString() ?? 'admin';
          vendorName =
              destinationType.toLowerCase() == 'admin'
                  ? 'Admin Treasury'
                  : destinationType;
        }

        combinedTransactions.add({
          'id': transaction['id']?.toString() ?? 'Unknown',
          'amount': (transaction['amount'] as num?)?.toDouble() ?? 0.0,
          'created_at': transaction['created_at']?.toString() ?? '',
          'service_name': vendorName,
          'student_name': primaryName,
          'student_id': primaryId,
          'status': 'completed',
          'category': 'withdrawal',
          'transaction_type': (transaction['transaction_type']?.toString() ??
                  'withdrawal')
              .trim()
              .toLowerCase()
              .replaceAll(' ', '_'),
          'notes': metadata?['admin_notes']?.toString(),
          'previous_balance': null,
          'new_balance': null,
          'processed_by': metadata?['processed_by']?.toString() ?? vendorName,
          'account_type': accountType,
        });
      }

      combinedTransactions.sort((a, b) {
        final bTimestamp =
            DateTime.tryParse(b['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final aTimestamp =
            DateTime.tryParse(a['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTimestamp.compareTo(aTimestamp);
      });

      final int combinedTakeLimit =
          fetchLimit + topupLimit + topupLimit + withdrawalLimit;
      final List<Map<String, dynamic>> limitedTransactions =
          combinedTransactions.take(combinedTakeLimit).toList();

      final int topUpGcashCount =
          limitedTransactions.where((transaction) {
            return (transaction['transaction_type']?.toString() ?? '')
                    .toLowerCase() ==
                'top_up_gcash';
          }).length;
      print(
        'DEBUG: Combined transactions prepared: ${limitedTransactions.length} (top_up_gcash count: $topUpGcashCount)',
      );

      return {
        'success': true,
        'data': {
          'transactions': limitedTransactions,
          'total_count': combinedTransactions.length,
        },
      };
    } catch (e) {
      print("DEBUG: Error fetching combined admin transactions: $e");
      return {
        'success': false,
        'message': 'Error fetching service transactions: $e',
        'data': {'transactions': [], 'total_count': 0},
      };
    }
  }

  /// Get today's transaction statistics
  static Future<Map<String, dynamic>> getTodayTransactionStats() async {
    try {
      await SupabaseService.initialize();

      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      print("DEBUG: Fetching today's transaction stats");
      print("DEBUG: Start of day: $startOfDay, End of day: $endOfDay");

      // Get today's transactions
      final transactions = await client
          .from('service_transactions')
          .select('id, total_amount, created_at')
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String());

      final totalTransactions = transactions.length;
      final totalAmount = transactions.fold<double>(
        0.0,
        (sum, transaction) =>
            sum + ((transaction['total_amount'] as num?)?.toDouble() ?? 0.0),
      );

      print(
        "DEBUG: Today's stats - transactions: $totalTransactions, amount: $totalAmount",
      );

      return {
        'success': true,
        'data': {
          'total_transactions': totalTransactions,
          'total_amount': totalAmount,
          'successful_transactions': totalTransactions, // All are successful
        },
      };
    } catch (e) {
      print("DEBUG: Error fetching today's stats: $e");
      return {
        'success': false,
        'message': 'Error fetching today\'s stats: $e',
        'data': {
          'total_transactions': 0,
          'total_amount': 0.0,
          'successful_transactions': 0,
        },
      };
    }
  }

  // User Management Operations

  /// Get all users from auth_students table (which contains all registered users)
  static Future<Map<String, dynamic>> getAllUsers() async {
    try {
      // Get all users from auth_students table (this contains all registered users)
      final studentsResponse = await adminClient
          .from(SupabaseConfig.authStudentsTable)
          .select('*')
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> usersWithData = [];

      for (var studentData in studentsResponse) {
        try {
          // Decrypt the student data
          final decryptedData = EncryptionService.decryptUserData(studentData);

          // Add the decrypted data to our list
          usersWithData.add({
            'auth_user_id': studentData['auth_user_id'],
            'email': decryptedData['email'] ?? 'N/A',
            'created_at': studentData['created_at'],
            'updated_at': studentData['updated_at'],
            ...decryptedData,
          });
        } catch (e) {
          // Skip this user if there's an error
          print('Error processing user ${studentData['id']}: $e');
        }
      }

      return {
        'success': true,
        'data': usersWithData,
        'count': usersWithData.length,
        'message': 'Users retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve users: ${e.toString()}',
      };
    }
  }

  /// Delete user from auth_students table and auth.users via admin API
  static Future<Map<String, dynamic>> deleteUser(String email) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();
      if (normalizedEmail.isEmpty) {
        return {
          'success': false,
          'message': 'Email is required to delete a user',
        };
      }

      final encryptedEmail =
          EncryptionService.encryptUserData({
            'email': normalizedEmail,
          })['email'];

      if (encryptedEmail == null || encryptedEmail.toString().isEmpty) {
        return {
          'success': false,
          'message': 'Failed to encrypt email for lookup',
        };
      }

      // First, find the user in auth_students table by email
      final studentResponse =
          await adminClient
              .from(SupabaseConfig.authStudentsTable)
              .select('auth_user_id, email')
              .eq('email', encryptedEmail)
              .maybeSingle();

      if (studentResponse == null) {
        return {
          'success': false,
          'message': 'User not found in auth_students table',
        };
      }

      final authUserId = studentResponse['auth_user_id'];

      // Delete from auth_students table first
      await adminClient
          .from(SupabaseConfig.authStudentsTable)
          .delete()
          .eq('auth_user_id', authUserId);

      // Delete from auth.users using admin API
      bool authDeleted = false;
      try {
        // Use the admin API to delete the user
        await adminClient.auth.admin.deleteUser(authUserId);
        print('Successfully deleted user from auth.users: $authUserId');
        authDeleted = true;
      } catch (authError) {
        print('Admin API deletion failed: $authError');
        // Try alternative approach using direct SQL
        try {
          // Use RPC function to delete from auth.users
          await adminClient.rpc(
            'delete_auth_user',
            params: {'user_id': authUserId},
          );
          print('Successfully deleted user using RPC function');
          authDeleted = true;
        } catch (rpcError) {
          print('RPC deletion also failed: $rpcError');
          // Last resort - try direct table deletion (might not work due to RLS)
          try {
            await adminClient.from('auth.users').delete().eq('id', authUserId);
            print('Successfully deleted user using direct table deletion');
            authDeleted = true;
          } catch (directError) {
            print('Direct deletion also failed: $directError');
          }
        }
      }

      return {
        'success': true,
        'message':
            authDeleted
                ? 'User deleted successfully from both auth_students and auth.users tables'
                : 'User deleted from auth_students table (auth.users deletion may have failed - check logs)',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete user: ${e.toString()}',
      };
    }
  }

  /// Get user by email from auth_students table
  /// Get user by student ID (for admin use)
  static Future<Map<String, dynamic>> getUserByStudentId(
    String studentId,
  ) async {
    try {
      await SupabaseService.initialize();

      final response =
          await adminClient
              .from(SupabaseConfig.authStudentsTable)
              .select('*')
              .eq('student_id', studentId)
              .maybeSingle();

      if (response == null) {
        return {'success': false, 'message': 'Student not found'};
      }

      // Decrypt sensitive data
      final decryptedData = EncryptionService.decryptUserData(response);

      return {'success': true, 'data': decryptedData};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get user: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getUserByEmail(String email) async {
    try {
      // Encrypt the email to match against stored encrypted values
      final encryptedData = EncryptionService.encryptUserData({
        'email': email.toLowerCase(),
      });
      final encryptedEmail = encryptedData['email']?.toString() ?? '';

      // Get user from auth_students table using encrypted email
      final studentDataResponse =
          await adminClient
              .from(SupabaseConfig.authStudentsTable)
              .select('*')
              .eq('email', encryptedEmail)
              .maybeSingle();

      if (studentDataResponse == null) {
        return {
          'success': false,
          'message': 'User not found in auth_students table',
        };
      }

      // Decrypt the student data
      final decryptedData = EncryptionService.decryptUserData(
        studentDataResponse,
      );

      Map<String, dynamic> userData = {
        'auth_user_id': studentDataResponse['auth_user_id'],
        'email': decryptedData['email'] ?? 'N/A',
        'created_at': studentDataResponse['created_at'],
        'updated_at': studentDataResponse['updated_at'],
        ...decryptedData,
      };

      return {
        'success': true,
        'data': userData,
        'message': 'User retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve user: ${e.toString()}',
      };
    }
  }

  /// Get service account by email (case-insensitive, stored in plain text)
  static Future<Map<String, dynamic>> getServiceAccountByEmail(
    String email,
  ) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      final serviceResponse =
          await adminClient
              .from('service_accounts')
              .select('*')
              .ilike('email', normalizedEmail)
              .maybeSingle();

      if (serviceResponse == null) {
        return {
          'success': false,
          'message': 'Service account not found for email $email',
        };
      }

      return {
        'success': true,
        'data': serviceResponse,
        'message': 'Service account retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve service account: ${e.toString()}',
      };
    }
  }

  // OTP and Password Reset Operations

  /// Resend email confirmation link for auth_students
  /// This is used when the original confirmation link has expired
  static Future<Map<String, dynamic>> resendEmailConfirmation({
    required String email,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      bool emailExists = false;

      // Check if email exists in auth_students table
      final userResult = await getUserByEmail(normalizedEmail);
      if (userResult['success'] == true) {
        emailExists = true;
      } else {
        // Check service accounts table for non-student emails
        final serviceResult = await getServiceAccountByEmail(normalizedEmail);
        if (serviceResult['success'] == true) {
          emailExists = true;
        }
      }

      if (!emailExists) {
        return {
          'success': false,
          'message': 'Email not found. Please check your email address.',
        };
      }

      // Use Supabase Auth to resend confirmation email
      await client.auth.resend(type: OtpType.signup, email: normalizedEmail);

      return {
        'success': true,
        'message':
            'Confirmation email sent. Please check your inbox and click the confirmation link to activate your account.',
      };
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('already confirmed') ||
          errorString.contains('email already confirmed')) {
        return {
          'success': false,
          'message': 'Your email is already confirmed. You can login now.',
        };
      }
      return {
        'success': false,
        'message': 'Failed to send confirmation email. Please try again later.',
        'error': e.toString(),
      };
    }
  }

  /// Send OTP code to user's email for password reset
  static Future<Map<String, dynamic>> sendPasswordResetOTP({
    required String email,
  }) async {
    try {
      // Check if email exists in auth_students table
      final userResult = await getUserByEmail(email);

      if (!userResult['success']) {
        return {
          'success': false,
          'message': 'Email not found. Please check your email address.',
        };
      }

      // Use Supabase Auth to send password reset email with custom template
      // The custom template will show the token as OTP code
      await client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'evsucampuspay://reset-password', // Custom deep link
      );

      return {
        'success': true,
        'message':
            'Password reset email sent. Please check your inbox for the verification code.',
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            'Failed to send password reset email. Please try again later.',
        'error': e.toString(),
      };
    }
  }

  /// Verify OTP code for password reset using Supabase Auth token
  /// This establishes a recovery session that will be used to update the password
  static Future<Map<String, dynamic>> verifyPasswordResetOTP({
    required String email,
    required String otpCode,
  }) async {
    try {
      // Verify against Supabase Auth (recovery OTP)
      // This will create a recovery session if the token is valid
      // IMPORTANT: This token can only be used once, so we establish the session here
      // and it will be used in resetPasswordWithOTP
      await client.auth.verifyOTP(
        email: email,
        token: otpCode,
        type: OtpType.recovery,
      );

      // Check that we have an active session after verification
      final session = client.auth.currentSession;
      if (session == null) {
        return {
          'success': false,
          'message': 'Failed to establish recovery session. Please try again.',
        };
      }

      return {
        'success': true,
        'message': 'Code verified. You can now set your new password.',
      };
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('invalid') ||
          errorString.contains('expired') ||
          errorString.contains('token') ||
          errorString.contains('code')) {
        return {
          'success': false,
          'message':
              'Invalid or expired verification code. Please request a new reset email.',
          'error': e.toString(),
        };
      }
      return {
        'success': false,
        'message': 'Failed to verify code. Please try again.',
        'error': e.toString(),
      };
    }
  }

  /// Reset password using the recovery session established by verifyPasswordResetOTP
  /// IMPORTANT: verifyPasswordResetOTP must be called first to establish the recovery session
  /// The code is not needed here since verification already happened
  /// Updates both auth.users.password_hash (Supabase Auth) and auth_students.password
  static Future<Map<String, dynamic>> resetPasswordWithOTP({
    required String email,
    required String newPassword,
  }) async {
    try {
      // Check if we have an active recovery session from verifyPasswordResetOTP
      final session = client.auth.currentSession;
      if (session == null) {
        return {
          'success': false,
          'message':
              'No active recovery session found. Please verify the code first before resetting your password.',
        };
      }

      // Step 1: Update password in Supabase Auth (auth.users.password_hash)
      // This is the primary authentication system
      try {
        await client.auth.updateUser(UserAttributes(password: newPassword));
        print('DEBUG: Password updated in auth.users for email: $email');
      } catch (updateError) {
        final errorString = updateError.toString().toLowerCase();
        if (errorString.contains('session') ||
            errorString.contains('jwt') ||
            errorString.contains('expired') ||
            errorString.contains('invalid')) {
          return {
            'success': false,
            'message':
                'Recovery session expired. Please request a new reset email, verify the code, and set your password immediately.',
            'error': updateError.toString(),
          };
        }
        if (errorString.contains('password') && errorString.contains('least')) {
          return {
            'success': false,
            'message': 'Password too weak. Use at least 6 characters.',
            'error': updateError.toString(),
          };
        }
        rethrow;
      }

      // Step 2: Update password in auth_students table (mirror table)
      // This ensures consistency between Supabase Auth and your custom table
      try {
        final userResult = await getUserByEmail(email);
        if (userResult['success'] == true && userResult['data'] != null) {
          final userData = userResult['data'];
          final studentId = userData['student_id'];

          if (studentId != null) {
            // Hash the password using the same method as registration
            final hashedPassword = _hashPassword(newPassword);

            await adminClient
                .from(SupabaseConfig.authStudentsTable)
                .update({
                  'password': hashedPassword,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('student_id', studentId);

            print(
              'DEBUG: Password updated in auth_students table for student_id: $studentId',
            );
          } else {
            print(
              'WARNING: Student ID not found for email: $email - skipping auth_students update',
            );
          }
        } else {
          print(
            'WARNING: User not found in auth_students for email: $email - skipping mirror update',
          );
        }
      } catch (syncError) {
        // Log error but don't fail - auth.users is the source of truth
        print(
          'ERROR: Failed to sync password to auth_students after Auth update: $syncError',
        );
        // Continue anyway since Supabase Auth update succeeded
      }

      return {
        'success': true,
        'message':
            'Password has been reset. You can now login with your new password.',
      };
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('password') && errorString.contains('least')) {
        return {
          'success': false,
          'message': 'Password too weak. Use at least 6 characters.',
          'error': e.toString(),
        };
      }
      return {
        'success': false,
        'message': 'Failed to reset password. Please try again.',
        'error': e.toString(),
      };
    }
  }

  // Service Account Password Reset Operations

  /// Send OTP code to service account's email for password reset
  static Future<Map<String, dynamic>> sendServiceAccountPasswordResetOTP({
    required String email,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      // Check if email exists in service_accounts table
      final serviceAccountResult =
          await adminClient
              .from('service_accounts')
              .select('id, email, service_name, is_active')
              .eq('email', normalizedEmail)
              .maybeSingle();

      if (serviceAccountResult == null) {
        return {
          'success': false,
          'message': 'Email not found. Please check your email address.',
        };
      }

      // Check if account is active
      if (serviceAccountResult['is_active'] == false) {
        return {
          'success': false,
          'message':
              'This service account is deactivated. Please contact admin to reactivate your account.',
        };
      }

      // Use Supabase Auth to send password reset email with custom template
      // The custom template will show the token as OTP code
      await client.auth.resetPasswordForEmail(
        normalizedEmail,
        redirectTo: 'evsucampuspay://reset-password', // Custom deep link
      );

      return {
        'success': true,
        'message':
            'Password reset email sent. Please check your inbox for the verification code.',
      };
    } catch (e) {
      return {
        'success': false,
        'message':
            'Failed to send password reset email. Please try again later.',
        'error': e.toString(),
      };
    }
  }

  /// Verify OTP code for service account password reset using Supabase Auth token
  /// This establishes a recovery session that will be used to update the password
  static Future<Map<String, dynamic>> verifyServiceAccountPasswordResetOTP({
    required String email,
    required String otpCode,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      // Verify against Supabase Auth (recovery OTP)
      // This will create a recovery session if the token is valid
      // IMPORTANT: This token can only be used once, so we establish the session here
      // and it will be used in resetServiceAccountPasswordWithOTP
      await client.auth.verifyOTP(
        email: normalizedEmail,
        token: otpCode,
        type: OtpType.recovery,
      );

      // Check that we have an active session after verification
      final session = client.auth.currentSession;
      if (session == null) {
        return {
          'success': false,
          'message': 'Failed to establish recovery session. Please try again.',
        };
      }

      return {
        'success': true,
        'message': 'Code verified. You can now set your new password.',
      };
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('invalid') ||
          errorString.contains('expired') ||
          errorString.contains('token') ||
          errorString.contains('code')) {
        return {
          'success': false,
          'message':
              'Invalid or expired verification code. Please request a new reset email.',
          'error': e.toString(),
        };
      }
      return {
        'success': false,
        'message': 'Failed to verify code. Please try again.',
        'error': e.toString(),
      };
    }
  }

  /// Reset service account password using the recovery session established by verifyServiceAccountPasswordResetOTP
  /// IMPORTANT: verifyServiceAccountPasswordResetOTP must be called first to establish the recovery session
  /// The code is not needed here since verification already happened
  /// Updates both auth.users.password_hash (Supabase Auth) and service_accounts.password_hash
  static Future<Map<String, dynamic>> resetServiceAccountPasswordWithOTP({
    required String email,
    required String newPassword,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      // Check if we have an active recovery session from verifyServiceAccountPasswordResetOTP
      final session = client.auth.currentSession;
      if (session == null) {
        return {
          'success': false,
          'message':
              'No active recovery session found. Please verify the code first before resetting your password.',
        };
      }

      // Step 1: Update password in Supabase Auth (auth.users.password_hash)
      // This is the primary authentication system
      try {
        await client.auth.updateUser(UserAttributes(password: newPassword));
        print(
          'DEBUG: Password updated in auth.users for service account email: $normalizedEmail',
        );
      } catch (updateError) {
        final errorString = updateError.toString().toLowerCase();
        if (errorString.contains('session') ||
            errorString.contains('jwt') ||
            errorString.contains('expired') ||
            errorString.contains('invalid')) {
          return {
            'success': false,
            'message':
                'Recovery session expired. Please request a new reset email, verify the code, and set your password immediately.',
            'error': updateError.toString(),
          };
        }
        if (errorString.contains('password') && errorString.contains('least')) {
          return {
            'success': false,
            'message': 'Password too weak. Use at least 6 characters.',
            'error': updateError.toString(),
          };
        }
        rethrow;
      }

      // Step 2: Update password in service_accounts table (mirror table)
      // This ensures consistency between Supabase Auth and your custom table
      try {
        final serviceAccountResult =
            await adminClient
                .from('service_accounts')
                .select('id, email')
                .eq('email', normalizedEmail)
                .maybeSingle();

        if (serviceAccountResult != null) {
          final serviceAccountId = serviceAccountResult['id'];

          if (serviceAccountId != null) {
            // Hash the password using the same method as registration
            final hashedPassword = EncryptionService.hashPassword(newPassword);

            await adminClient
                .from('service_accounts')
                .update({
                  'password_hash': hashedPassword,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .eq('id', serviceAccountId);

            print(
              'DEBUG: Password updated in service_accounts table for id: $serviceAccountId',
            );
          } else {
            print(
              'WARNING: Service account ID not found for email: $normalizedEmail - skipping service_accounts update',
            );
          }
        } else {
          print(
            'WARNING: Service account not found for email: $normalizedEmail - skipping mirror update',
          );
        }
      } catch (syncError) {
        // Log error but don't fail - auth.users is the source of truth
        print(
          'ERROR: Failed to sync password to service_accounts after Auth update: $syncError',
        );
        // Continue anyway since Supabase Auth update succeeded
      }

      return {
        'success': true,
        'message':
            'Password has been reset. You can now login with your new password.',
      };
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('password') && errorString.contains('least')) {
        return {
          'success': false,
          'message': 'Password too weak. Use at least 6 characters.',
          'error': e.toString(),
        };
      }
      return {
        'success': false,
        'message': 'Failed to reset password. Please try again.',
        'error': e.toString(),
      };
    }
  }

  /// Update user password in both auth.users (Supabase Auth) and auth_students table
  /// Uses Supabase Auth for password verification and updates both systems
  static Future<Map<String, dynamic>> updateUserPassword({
    required String studentId,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await SupabaseService.initialize();

      // Step 1: Get user data from auth_students table (including email and auth_user_id)
      final userResponse =
          await adminClient
              .from(SupabaseConfig.authStudentsTable)
              .select('*')
              .eq('student_id', studentId)
              .maybeSingle();

      if (userResponse == null) {
        return {
          'success': false,
          'error': 'User not found',
          'message': 'No account found with this student ID',
        };
      }

      // Decrypt email from auth_students table
      final decryptedData = EncryptionService.decryptUserData(userResponse);
      final email = decryptedData['email']?.toString();
      final authUserId = userResponse['auth_user_id']?.toString();

      if (email == null || email.isEmpty) {
        return {
          'success': false,
          'error': 'User email not found',
          'message': 'User email not found. Please contact support.',
        };
      }

      if (authUserId == null || authUserId.isEmpty) {
        return {
          'success': false,
          'error': 'Auth user ID not found',
          'message':
              'Authentication user ID not found. Please contact support.',
        };
      }

      // Step 2: Verify current password and update in Supabase Auth
      try {
        // Check if user is already authenticated with matching auth_user_id
        final currentUser = client.auth.currentUser;
        final isAlreadyAuthenticated =
            currentUser != null && currentUser.id == authUserId;

        if (isAlreadyAuthenticated) {
          // User is already authenticated - verify current password by attempting sign in
          // We'll use a temporary sign-in to verify, then restore session
          try {
            final verifyResponse = await client.auth.signInWithPassword(
              email: email,
              password: currentPassword,
            );

            if (verifyResponse.user == null ||
                verifyResponse.user!.id != authUserId) {
              // Password verification failed
              return {
                'success': false,
                'error': 'Invalid current password',
                'message': 'Current password is incorrect. Please try again.',
              };
            }
          } catch (verifyError) {
            String verifyErrorString = verifyError.toString().toLowerCase();
            if (verifyErrorString.contains('invalid login credentials') ||
                verifyErrorString.contains('invalid_credentials')) {
              return {
                'success': false,
                'error': 'Invalid current password',
                'message': 'Current password is incorrect. Please try again.',
              };
            }
            rethrow;
          }
        } else {
          // User is not authenticated - sign in with current password to verify
          final verifyResponse = await client.auth.signInWithPassword(
            email: email,
            password: currentPassword,
          );

          if (verifyResponse.user == null) {
            return {
              'success': false,
              'error': 'Invalid current password',
              'message': 'Current password is incorrect. Please try again.',
            };
          }

          // Verify the authenticated user matches the auth_user_id
          if (verifyResponse.user!.id != authUserId) {
            await client.auth.signOut();
            return {
              'success': false,
              'error': 'Authentication mismatch',
              'message':
                  'Authentication verification failed. Please contact support.',
            };
          }
        }

        // Step 3: Update password in Supabase Auth (auth.users)
        // The user is now authenticated (either already was or just signed in)
        await client.auth.updateUser(UserAttributes(password: newPassword));

        print(
          'DEBUG: Password updated in auth.users for student_id: $studentId',
        );
      } catch (authError) {
        String errorString = authError.toString().toLowerCase();

        if (errorString.contains('invalid login credentials') ||
            errorString.contains('invalid_credentials') ||
            errorString.contains('invalid password')) {
          return {
            'success': false,
            'error': 'Invalid current password',
            'message': 'Current password is incorrect. Please try again.',
          };
        }

        if (errorString.contains('password should be at least') ||
            errorString.contains('password_too_short') ||
            errorString.contains('password is required')) {
          return {
            'success': false,
            'error': 'Password too weak',
            'message': 'New password must be at least 6 characters long.',
          };
        }

        // If Supabase Auth update fails, still try to update auth_students
        // but log the error and return failure
        print('ERROR: Failed to update password in auth.users: $authError');
        return {
          'success': false,
          'error': 'Failed to update password in authentication system',
          'message':
              'Failed to update password. Please try again or contact support.',
        };
      }

      // Step 4: Update hashed password in auth_students table (for consistency/backup)
      // Note: This is done after Supabase Auth update succeeds
      try {
        final hashedPassword = _hashPassword(newPassword);
        await adminClient
            .from(SupabaseConfig.authStudentsTable)
            .update({
              'password': hashedPassword,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('student_id', studentId);

        print(
          'DEBUG: Password updated in auth_students table for student_id: $studentId',
        );
      } catch (dbError) {
        print(
          'ERROR: Failed to update password in auth_students table: $dbError',
        );
        // Password is updated in auth.users, but not in auth_students
        // This is not ideal but won't break login since we use Supabase Auth
        // Log the error for debugging
      }

      // Step 5: Re-authenticate with new password to refresh session
      // This ensures the session is valid with the new password
      try {
        await client.auth.signInWithPassword(
          email: email,
          password: newPassword,
        );
        print('DEBUG: Re-authenticated with new password successfully');
      } catch (reauthError) {
        print(
          'WARNING: Failed to re-authenticate with new password: $reauthError',
        );
        // This is not critical - the password is updated, user can login again
        // The session might be invalid, but the password change was successful
      }

      return {
        'success': true,
        'message':
            'Password updated successfully! You can now use your new password to login.',
        'student_id': userResponse['student_id'],
      };
    } catch (e) {
      String errorMessage = e.toString();
      String errorString = errorMessage.toLowerCase();

      if (errorString.contains('invalid login credentials') ||
          errorString.contains('invalid_credentials') ||
          errorString.contains('invalid password')) {
        return {
          'success': false,
          'error': 'Invalid current password',
          'message': 'Current password is incorrect. Please try again.',
        };
      }

      if (errorString.contains('password should be at least') ||
          errorString.contains('password_too_short')) {
        return {
          'success': false,
          'error': 'Password too weak',
          'message': 'New password must be at least 6 characters long.',
        };
      }

      if (errorString.contains('user not found') ||
          errorString.contains('user_not_found')) {
        return {
          'success': false,
          'error': 'User not found',
          'message': 'No account found with this student ID.',
        };
      }

      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update password: ${e.toString()}',
      };
    }
  }

  // Tap to Pay Operations

  /// Update tap to pay status for a student
  static Future<Map<String, dynamic>> updateTapToPayStatus({
    required String studentId,
    required bool enabled,
  }) async {
    try {
      final response =
          await client
              .from(SupabaseConfig.authStudentsTable)
              .update({'taptopay': enabled})
              .eq('student_id', studentId)
              .select('taptopay')
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Tap to pay status updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update tap to pay status: ${e.toString()}',
      };
    }
  }

  /// Get tap to pay status for a student
  static Future<Map<String, dynamic>> getTapToPayStatus({
    required String studentId,
  }) async {
    try {
      final response =
          await client
              .from(SupabaseConfig.authStudentsTable)
              .select('taptopay')
              .eq('student_id', studentId)
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Tap to pay status retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get tap to pay status: ${e.toString()}',
      };
    }
  }

  /// Authenticate admin account
  static Future<Map<String, dynamic>> authenticateAdmin({
    required String username,
    required String password,
  }) async {
    try {
      // Call the authenticate_admin function in the database
      final response = await SupabaseService.client.rpc(
        'authenticate_admin',
        params: {'p_username': username, 'p_password': password},
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'data': response['admin_data'],
          'message': 'Admin authentication successful',
        };
      } else {
        return {
          'success': false,
          'error': 'Authentication failed',
          'message': response['message'] ?? 'Invalid username or password',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Admin authentication failed: ${e.toString()}',
      };
    }
  }

  /// Update admin credentials
  static Future<Map<String, dynamic>> updateAdminCredentials({
    required String currentUsername,
    required String currentPassword,
    required String newUsername,
    required String newPassword,
    required String newFullName,
    required String newEmail,
  }) async {
    try {
      // Call the update_admin_credentials function in the database
      final response = await SupabaseService.client.rpc(
        'update_admin_credentials',
        params: {
          'p_current_username': currentUsername,
          'p_current_password': currentPassword,
          'p_new_username': newUsername,
          'p_new_password': newPassword,
          'p_new_full_name': newFullName,
          'p_new_email': newEmail,
        },
      );

      if (response['success'] == true) {
        return {
          'success': true,
          'message': 'Admin credentials updated successfully',
        };
      } else {
        return {
          'success': false,
          'error': 'Update failed',
          'message':
              response['message'] ?? 'Failed to update admin credentials',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Admin credentials update failed: ${e.toString()}',
      };
    }
  }

  /// Ensure admin email exists (and is verified) in Supabase Auth
  static Future<Map<String, dynamic>> verifyAdminEmail({
    required String username,
    required String password,
  }) async {
    try {
      await SupabaseService.initialize();

      final authResult = await authenticateAdmin(
        username: username,
        password: password,
      );

      if (authResult['success'] != true) {
        return {
          'success': false,
          'message':
              authResult['message'] ??
              'Invalid credentials. Please check current username/password.',
        };
      }

      final adminRecord =
          await adminClient
              .from('admin_accounts')
              .select(
                'id, username, email, supabase_uid, email_verified, email_verified_at',
              )
              .limit(1)
              .maybeSingle();

      if (adminRecord == null) {
        return {'success': false, 'message': 'Admin account not found.'};
      }

      final adminId = adminRecord['id'];
      final email = (adminRecord['email'] ?? '').toString().trim();

      if (email.isEmpty) {
        return {
          'success': false,
          'message':
              'Admin email is not configured. Please set an email first.',
        };
      }

      final normalizedEmail = email.toLowerCase();

      Map<String, dynamic>? authUserRecord =
          await adminClient
              .from('auth.users')
              .select('id, email_confirmed_at')
              .eq('email', normalizedEmail)
              .maybeSingle();

      if (authUserRecord == null) {
        final createResponse = await adminClient.auth.admin.createUser(
          AdminUserAttributes(
            email: normalizedEmail,
            password: password,
            emailConfirm: false,
            userMetadata: {'role': 'admin'},
          ),
        );

        if (createResponse.user == null) {
          return {
            'success': false,
            'message': 'Failed to provision Supabase Auth user.',
          };
        }

        authUserRecord = {
          'id': createResponse.user!.id,
          'email_confirmed_at': createResponse.user!.emailConfirmedAt,
        };
      }

      final supabaseUid = authUserRecord['id']?.toString();
      if (supabaseUid == null) {
        return {
          'success': false,
          'message': 'Failed to determine Supabase Auth user ID.',
        };
      }

      final confirmedRaw = authUserRecord['email_confirmed_at'];
      DateTime? confirmedAt;
      if (confirmedRaw is DateTime) {
        confirmedAt = confirmedRaw;
      } else if (confirmedRaw is String && confirmedRaw.isNotEmpty) {
        confirmedAt = DateTime.tryParse(confirmedRaw);
      }

      final emailVerified = confirmedAt != null;

      final verifiedTimestamp = confirmedAt ?? DateTime.now();

      await adminClient
          .from('admin_accounts')
          .update({
            'supabase_uid': supabaseUid,
            'email_verified': emailVerified,
            'email_verified_at':
                emailVerified ? verifiedTimestamp.toIso8601String() : null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', adminId);

      return {
        'success': true,
        'supabase_uid': supabaseUid,
        'email_verified': emailVerified,
        'message':
            emailVerified
                ? 'Email already verified and linked to Supabase Auth.'
                : 'Verification email sent. Please check your inbox.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to verify email: ${e.toString()}',
        'error': e.toString(),
      };
    }
  }

  /// Get current admin information based on logged-in session
  static Future<Map<String, dynamic>> getCurrentAdminInfo() async {
    try {
      // Get logged-in admin username from session
      final currentUserData = SessionService.currentUserData;
      if (currentUserData == null ||
          SessionService.currentUserType != 'admin') {
        print('DEBUG [getCurrentAdminInfo]: No admin session found');
        return {
          'success': false,
          'error': 'No admin session',
          'message': 'No active admin session found. Please log in again.',
        };
      }

      // Get username from session (stored in 'student_id' field for admin)
      final loggedInUsername = currentUserData['student_id']?.toString();
      final loggedInId = currentUserData['id'];

      print(
        'DEBUG [getCurrentAdminInfo]: Current session - Username: $loggedInUsername, ID: $loggedInId',
      );

      if (loggedInUsername == null && loggedInId == null) {
        print('DEBUG [getCurrentAdminInfo]: No username or ID in session');
        return {
          'success': false,
          'error': 'Invalid session data',
          'message': 'Session data is incomplete. Please log in again.',
        };
      }

      // Query admin_accounts table matching logged-in admin
      var query = SupabaseService.client
          .from('admin_accounts')
          .select(
            'id, username, full_name, email, supabase_uid, email_verified, email_verified_at, role',
          );

      // Match by ID first (most reliable), then fallback to username
      if (loggedInId != null) {
        query = query.eq('id', loggedInId);
        print('DEBUG [getCurrentAdminInfo]: Querying by ID: $loggedInId');
      } else if (loggedInUsername != null && loggedInUsername.isNotEmpty) {
        query = query.eq('username', loggedInUsername);
        print(
          'DEBUG [getCurrentAdminInfo]: Querying by username: $loggedInUsername',
        );
      }

      final response = await query.maybeSingle();

      if (response == null) {
        print(
          'DEBUG [getCurrentAdminInfo]: Admin account not found in database',
        );
        return {
          'success': false,
          'error': 'Admin account not found',
          'message':
              'Admin account not found. Please contact support if this issue persists.',
        };
      }

      print('DEBUG [getCurrentAdminInfo]: Query successful');
      print('DEBUG [getCurrentAdminInfo]: Username: ${response['username']}');
      print('DEBUG [getCurrentAdminInfo]: ID: ${response['id']}');
      print('DEBUG [getCurrentAdminInfo]: Role: ${response['role']}');

      return {'success': true, 'data': response};
    } catch (e) {
      print('DEBUG [getCurrentAdminInfo]: Query failed');
      print('DEBUG [getCurrentAdminInfo]: Error: $e');
      print('DEBUG [getCurrentAdminInfo]: Error type: ${e.runtimeType}');

      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get admin info: ${e.toString()}',
      };
    }
  }

  /// Get admin account with role='admin' (for database reset operations)
  static Future<Map<String, dynamic>> getAdminAccountForReset() async {
    try {
      print(
        'DEBUG [getAdminAccountForReset]: Querying admin_accounts table for role=admin...',
      );
      final response =
          await SupabaseService.client
              .from('admin_accounts')
              .select(
                'id, username, full_name, email, supabase_uid, email_verified, email_verified_at, role',
              )
              .eq('role', 'admin')
              .eq('is_active', true)
              .limit(1)
              .maybeSingle();

      if (response == null) {
        print(
          'DEBUG [getAdminAccountForReset]: No admin account with role=admin found',
        );
        return {
          'success': false,
          'error': 'No admin account found',
          'message':
              'No active admin account found. Only users with role="admin" can reset the database.',
        };
      }

      print('DEBUG [getAdminAccountForReset]: Query successful');
      print(
        'DEBUG [getAdminAccountForReset]: Username: ${response['username']}',
      );
      print('DEBUG [getAdminAccountForReset]: ID: ${response['id']}');
      print('DEBUG [getAdminAccountForReset]: Role: ${response['role']}');

      return {'success': true, 'data': response};
    } catch (e) {
      print('DEBUG [getAdminAccountForReset]: Query failed');
      print('DEBUG [getAdminAccountForReset]: Error: $e');
      print('DEBUG [getAdminAccountForReset]: Error type: ${e.runtimeType}');

      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get admin account: ${e.toString()}',
      };
    }
  }

  /// Reset database - Delete all data and reset IDs (Admin only)
  /// This function requires admin password authentication for security
  static Future<Map<String, dynamic>> resetDatabase({
    required String adminPassword,
    required String adminUsername,
  }) async {
    try {
      print('DEBUG [resetDatabase]: Starting password verification');
      print('DEBUG [resetDatabase]: Username: $adminUsername');
      print('DEBUG [resetDatabase]: Password length: ${adminPassword.length}');

      // Use the same authentication method as login page
      print(
        'DEBUG [resetDatabase]: Calling authenticateAdmin (same as login)...',
      );
      final authResult = await authenticateAdmin(
        username: adminUsername,
        password: adminPassword,
      );

      print(
        'DEBUG [resetDatabase]: Authentication result: ${authResult['success']}',
      );

      if (!authResult['success']) {
        print('DEBUG [resetDatabase]: Authentication FAILED');
        print('DEBUG [resetDatabase]: Error: ${authResult['error']}');
        print('DEBUG [resetDatabase]: Message: ${authResult['message']}');
        return {
          'success': false,
          'error': 'Authentication failed',
          'message': 'Invalid admin password. Please try again.',
        };
      }

      print('DEBUG [resetDatabase]: Authentication SUCCESSFUL');
      print('DEBUG [resetDatabase]: Admin data: ${authResult['data']}');
      print('DEBUG [resetDatabase]: Proceeding with database reset...');

      // Call the reset_database function using admin client to bypass RLS
      print(
        'DEBUG [resetDatabase]: Calling reset_database_admin RPC with admin client...',
      );
      final response = await SupabaseService.adminClient.rpc(
        'reset_database_admin',
        params: {'admin_user': adminUsername},
      );

      print('DEBUG [resetDatabase]: RPC response received: $response');
      print('DEBUG [resetDatabase]: Response type: ${response.runtimeType}');

      // Check if response is a Map and has success field
      bool isSuccess = false;
      String? responseMessage;

      if (response is Map<String, dynamic>) {
        isSuccess = response['success'] == true;
        responseMessage = response['message']?.toString();
        print('DEBUG [resetDatabase]: Response success: $isSuccess');
        print('DEBUG [resetDatabase]: Response message: $responseMessage');
      } else {
        print('DEBUG [resetDatabase]: WARNING - Response is not a Map!');
        print('DEBUG [resetDatabase]: Response value: $response');
      }

      if (!isSuccess) {
        return {
          'success': false,
          'error': 'Database reset failed',
          'message':
              responseMessage ?? 'Database reset function returned failure',
          'data': response,
        };
      }

      // Log the admin activity (use admin client to bypass RLS)
      try {
        await SupabaseService.adminClient.from('admin_activity_log').insert({
          'admin_username': adminUsername,
          'action': 'Reset Database',
          'description':
              'All system tables were reset and IDs were reinitialized',
          'timestamp': DateTime.now().toIso8601String(),
        });
        print('DEBUG [resetDatabase]: Activity logged successfully');
      } catch (logError) {
        // Continue even if logging fails
        print('Warning: Failed to log admin activity: $logError');
      }

      return {
        'success': true,
        'message':
            responseMessage ??
            'Database reset successfully. All data deleted and IDs reset.',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Database reset failed: ${e.toString()}',
      };
    }
  }

  /// Reset database while preserving student accounts (only reset balances to 0)
  static Future<Map<String, dynamic>> resetDatabasePreserveStudents({
    required String adminPassword,
    required String adminUsername,
  }) async {
    try {
      print(
        'DEBUG [resetDatabasePreserveStudents]: Starting password verification',
      );
      print('DEBUG [resetDatabasePreserveStudents]: Username: $adminUsername');
      print(
        'DEBUG [resetDatabasePreserveStudents]: Password length: ${adminPassword.length}',
      );

      // Use the same authentication method as login page
      print(
        'DEBUG [resetDatabasePreserveStudents]: Calling authenticateAdmin (same as login)...',
      );
      final authResult = await authenticateAdmin(
        username: adminUsername,
        password: adminPassword,
      );

      print(
        'DEBUG [resetDatabasePreserveStudents]: Authentication result: ${authResult['success']}',
      );

      if (!authResult['success']) {
        print('DEBUG [resetDatabasePreserveStudents]: Authentication FAILED');
        print(
          'DEBUG [resetDatabasePreserveStudents]: Error: ${authResult['error']}',
        );
        print(
          'DEBUG [resetDatabasePreserveStudents]: Message: ${authResult['message']}',
        );
        return {
          'success': false,
          'error': 'Authentication failed',
          'message': 'Invalid admin password. Please try again.',
        };
      }

      print('DEBUG [resetDatabasePreserveStudents]: Authentication SUCCESSFUL');
      print(
        'DEBUG [resetDatabasePreserveStudents]: Admin data: ${authResult['data']}',
      );
      print(
        'DEBUG [resetDatabasePreserveStudents]: Proceeding with database reset (preserve students)...',
      );

      // Call the reset_database_preserve_students function using admin client to bypass RLS
      print(
        'DEBUG [resetDatabasePreserveStudents]: Calling reset_database_preserve_students RPC with admin client...',
      );
      final response = await SupabaseService.adminClient.rpc(
        'reset_database_preserve_students',
        params: {'admin_user': adminUsername},
      );

      print(
        'DEBUG [resetDatabasePreserveStudents]: RPC response received: $response',
      );
      print(
        'DEBUG [resetDatabasePreserveStudents]: Response type: ${response.runtimeType}',
      );

      // Check if response is a Map and has success field
      bool isSuccess = false;
      String? responseMessage;

      if (response is Map<String, dynamic>) {
        isSuccess = response['success'] == true;
        responseMessage = response['message']?.toString();
        print(
          'DEBUG [resetDatabasePreserveStudents]: Response success: $isSuccess',
        );
        print(
          'DEBUG [resetDatabasePreserveStudents]: Response message: $responseMessage',
        );
      } else {
        print(
          'DEBUG [resetDatabasePreserveStudents]: WARNING - Response is not a Map!',
        );
        print(
          'DEBUG [resetDatabasePreserveStudents]: Response value: $response',
        );
      }

      if (!isSuccess) {
        return {
          'success': false,
          'error': 'Database reset failed',
          'message':
              responseMessage ?? 'Database reset function returned failure',
          'data': response,
        };
      }

      // Log the admin activity (use admin client to bypass RLS)
      try {
        await SupabaseService.adminClient.from('admin_activity_log').insert({
          'admin_username': adminUsername,
          'action': 'Reset Database (Preserve Students & Service Accounts)',
          'description':
              'All system tables were reset except auth_students and service_accounts. Student and service account balances reset to 0.',
          'timestamp': DateTime.now().toIso8601String(),
        });
        print(
          'DEBUG [resetDatabasePreserveStudents]: Activity logged successfully',
        );
      } catch (logError) {
        // Continue even if logging fails
        print('Warning: Failed to log admin activity: $logError');
      }

      return {
        'success': true,
        'message':
            responseMessage ??
            'Database reset successfully. Student accounts and service accounts preserved, balances reset to 0.',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Database reset failed: ${e.toString()}',
      };
    }
  }

  /// Reset PostgreSQL sequences after data recovery to prevent duplicate key errors.
  /// Sets each sequence to continue from MAX(id) + 1 for all recovered tables.
  static Future<Map<String, dynamic>> resetSequencesAfterRecovery() async {
    try {
      await initialize();

      final response = await SupabaseService.adminClient.rpc(
        'reset_sequences_after_recovery',
      );

      bool isSuccess = false;
      String? responseMessage;

      if (response is Map<String, dynamic>) {
        isSuccess = response['success'] == true;
        responseMessage = response['message']?.toString();
      }

      if (!isSuccess) {
        return {
          'success': false,
          'error': 'Sequence reset failed',
          'message':
              responseMessage ?? 'Failed to reset sequences after recovery',
          'data': response,
        };
      }

      return {
        'success': true,
        'message':
            responseMessage ??
            'Sequences reset successfully. New inserts will continue from the highest ID.',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Sequence reset failed: ${e.toString()}',
      };
    }
  }

  // Backup & Recovery Helpers

  /// Fetches an entire table (all rows) using the admin client, bypassing RLS.
  /// Returns the rows, ordered column names, and row count.
  static Future<Map<String, dynamic>> fetchTableDump({
    required String tableName,
    int batchSize = 1000,
  }) async {
    try {
      await SupabaseService.initialize();
      final identifier = _splitTableIdentifier(tableName);
      final schema = identifier['schema']!;
      final table = identifier['table']!;

      if (table.isEmpty) {
        throw ArgumentError('tableName cannot be empty');
      }

      final tableReference = schema == 'public' ? table : '$schema.$table';
      final effectiveBatch = batchSize <= 0 ? 1000 : batchSize;
      final allRows = <Map<String, dynamic>>[];

      int rangeStart = 0;
      while (true) {
        final response = await adminClient
            .from(tableReference)
            .select('*')
            .range(rangeStart, rangeStart + effectiveBatch - 1);

        if (response is! List || response.isEmpty) {
          break;
        }

        final batch =
            response
                .map<Map<String, dynamic>>(
                  (row) => Map<String, dynamic>.from(row as Map),
                )
                .toList();

        allRows.addAll(batch);

        if (batch.length < effectiveBatch) {
          break;
        }

        rangeStart += effectiveBatch;
      }

      final columns = await getTableColumns(
        tableName: table,
        schema: schema,
        sampleRow: allRows.isNotEmpty ? allRows.first : null,
      );

      return {
        'success': true,
        'data': allRows,
        'columns': columns,
        'rowCount': allRows.length,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to export $tableName: ${e.toString()}',
      };
    }
  }

  /// Returns ordered column names for a table. Falls back to a provided sample row.
  static Future<List<String>> getTableColumns({
    required String tableName,
    String schema = 'public',
    Map<String, dynamic>? sampleRow,
  }) async {
    final normalizedTable = tableName.trim();
    final normalizedSchema = schema.trim().isEmpty ? 'public' : schema.trim();

    Future<List<String>> _loadUsingSample() async {
      try {
        final reference = _qualifyTableReference(
          normalizedSchema == 'public'
              ? normalizedTable
              : '$normalizedSchema.$normalizedTable',
        );
        final sample =
            await adminClient
                .from(reference)
                .select('*')
                .limit(1)
                .maybeSingle();
        if (sample != null && sample.isNotEmpty) {
          return sample.keys.map((key) => key.toString()).toList();
        }
      } catch (_) {
        // Ignore and fallback to provided sample/map
      }

      if (sampleRow != null && sampleRow.isNotEmpty) {
        return sampleRow.keys.map((key) => key.toString()).toList();
      }

      final fallback = _columnSchemaFallbacks[normalizedTable];
      return fallback ?? [];
    }

    try {
      await SupabaseService.initialize();
      final response = await adminClient
          .from('information_schema.columns')
          .select('column_name, ordinal_position')
          .eq('table_schema', normalizedSchema)
          .eq('table_name', normalizedTable)
          .order('ordinal_position', ascending: true);

      if (response is List && response.isNotEmpty) {
        return response
            .map<String>((row) => (row['column_name'] ?? '').toString())
            .where((name) => name.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // Continue to RPC fallback
    }

    try {
      final rpcResponse = await adminClient.rpc(
        'get_table_columns_admin',
        params: {
          'p_table_name': normalizedTable,
          'p_schema_name': normalizedSchema,
        },
      );
      if (rpcResponse is List && rpcResponse.isNotEmpty) {
        return rpcResponse
            .map<String>((row) => (row['column_name'] ?? '').toString())
            .where((name) => name.isNotEmpty)
            .toList();
      }
    } catch (_) {
      // Continue to sample fallback
    }

    return _loadUsingSample();
  }

  static Future<Map<String, dynamic>> insertRows({
    required String tableName,
    required List<Map<String, dynamic>> rows,
    int chunkSize = 500,
  }) async {
    if (rows.isEmpty) {
      return {'success': true, 'inserted': 0};
    }

    try {
      await SupabaseService.initialize();
      final reference = _qualifyTableReference(tableName);
      int inserted = 0;

      for (int i = 0; i < rows.length; i += chunkSize) {
        final end = (i + chunkSize) > rows.length ? rows.length : i + chunkSize;
        final chunk = rows.sublist(i, end);
        await adminClient.from(reference).insert(chunk);
        inserted += chunk.length;
      }

      return {
        'success': true,
        'inserted': inserted,
        'message': 'Inserted $inserted row(s) into $tableName',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Insert failed for $tableName: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deleteAllRows({
    required String tableName,
    String primaryKey = 'id',
  }) async {
    try {
      await SupabaseService.initialize();
      final reference = _qualifyTableReference(tableName);
      await adminClient.from(reference).delete().neq(primaryKey, -1);

      return {'success': true, 'message': 'Cleared table $tableName'};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to clear $tableName: ${e.toString()}',
      };
    }
  }

  static Future<Set<String>> fetchPrimaryKeyValues({
    required String tableName,
    required String primaryKey,
    int batchSize = 1000,
  }) async {
    final values = <String>{};

    try {
      await SupabaseService.initialize();
      final reference = _qualifyTableReference(tableName);
      int rangeStart = 0;

      while (true) {
        final response = await adminClient
            .from(reference)
            .select(primaryKey)
            .range(rangeStart, rangeStart + batchSize - 1);

        if (response is! List || response.isEmpty) {
          break;
        }

        for (final row in response) {
          final value = row[primaryKey];
          if (value != null) {
            values.add(value.toString());
          }
        }

        if (response.length < batchSize) {
          break;
        }

        rangeStart += batchSize;
      }
    } catch (_) {
      // Ignore errors and return collected values
    }

    return values;
  }

  static Future<Map<String, dynamic>> setIdentityGenerationMode({
    required String tableName,
    required String columnName,
    required bool generatedAlways,
  }) async {
    try {
      await SupabaseService.initialize();
      final response = await adminClient.rpc(
        'set_identity_generation_mode',
        params: {
          'p_table_name': tableName,
          'p_column_name': columnName,
          'p_mode': generatedAlways ? 'ALWAYS' : 'BY DEFAULT',
        },
      );

      if (response is Map<String, dynamic> && response['success'] != true) {
        return {
          'success': false,
          'error': response['message'],
          'message':
              response['message']?.toString() ??
              'Failed to update identity mode.',
        };
      }

      return {'success': true};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message':
            'Failed to update identity mode for $tableName.$columnName: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> toggleRecoveryTriggers({
    required bool enable,
  }) async {
    try {
      await SupabaseService.initialize();
      final response = await adminClient.rpc(
        'toggle_restore_triggers',
        params: {'p_enable': enable},
      );

      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          return {
            'success': true,
            'data': response,
            'message':
                enable
                    ? 'Foreign key triggers re-enabled.'
                    : 'Foreign key triggers disabled.',
          };
        }

        return {
          'success': false,
          'error': response,
          'message':
              response['message']?.toString() ?? 'Failed to toggle triggers.',
        };
      }

      return {
        'success': true,
        'data': response,
        'message':
            enable
                ? 'Foreign key triggers re-enabled.'
                : 'Foreign key triggers disabled.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to toggle triggers: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> runRecoveryIntegrityCheck({
    required Map<String, int> expectedCounts,
  }) async {
    try {
      await SupabaseService.initialize();
      final response = await adminClient.rpc(
        'run_recovery_integrity_check',
        params: {'expected_counts': expectedCounts},
      );

      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          return {
            'success': true,
            'data': response,
            'message': 'Integrity check completed.',
          };
        }

        return {
          'success': false,
          'data': response,
          'message':
              response['message']?.toString() ?? 'Integrity check failed.',
        };
      }

      return {
        'success': true,
        'data': response,
        'message': 'Integrity check completed.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Integrity check failed: ${e.toString()}',
      };
    }
  }

  static String _qualifyTableReference(String tableName) {
    final identifier = _splitTableIdentifier(tableName);
    final schema = identifier['schema']!;
    final table = identifier['table']!;
    return schema == 'public' ? table : '$schema.$table';
  }

  static Map<String, String> _splitTableIdentifier(String tableName) {
    final normalized = tableName.trim();
    if (normalized.contains('.')) {
      final parts = normalized.split('.');
      if (parts.length >= 2) {
        return {
          'schema': parts.first.trim().isEmpty ? 'public' : parts.first.trim(),
          'table': parts.last.trim(),
        };
      }
    }

    return {'schema': 'public', 'table': normalized};
  }

  // Service Accounts Operations

  /// Create a new service account
  static Future<Map<String, dynamic>> createServiceAccount({
    required String serviceName,
    required String serviceCategory,
    required String operationalType,
    int? mainServiceId,
    required String contactPerson,
    required String email,
    required String phone,
    required String username,
    required String password,
    String? scannerId,
    double commissionRate = 0.0,
    String? code,
  }) async {
    try {
      final normalizedEmail = email.trim().toLowerCase();

      // Step 1: Create user in auth.users using admin client
      // Check if user already exists in auth.users
      Map<String, dynamic>? authUserRecord;
      try {
        authUserRecord =
            await adminClient
                .from('auth.users')
                .select('id, email_confirmed_at')
                .eq('email', normalizedEmail)
                .maybeSingle();
      } catch (e) {
        // If query fails, continue to create new user
        print('DEBUG: Could not check existing auth user: $e');
      }

      // Create auth user if it doesn't exist
      if (authUserRecord == null) {
        try {
          // Use signUp instead of admin.createUser to require email confirmation
          final signUpResponse = await SupabaseService.client.auth.signUp(
            email: normalizedEmail,
            password: password,
            data: {
              'role': 'service_account',
              'service_name': serviceName.trim(),
              'username': username.trim(),
            },
          );

          if (signUpResponse.user == null) {
            return {
              'success': false,
              'error': 'Failed to create auth user',
              'message':
                  'Failed to create Supabase Auth user for service account. A confirmation email has been sent.',
            };
          }

          authUserRecord = {
            'id': signUpResponse.user!.id,
            'email_confirmed_at': signUpResponse.user!.emailConfirmedAt,
          };
        } catch (authError) {
          // If auth user creation fails, check if it's a duplicate
          final errorString = authError.toString().toLowerCase();
          if (errorString.contains('already registered') ||
              errorString.contains('already exists') ||
              errorString.contains('duplicate')) {
            return {
              'success': false,
              'error': authError.toString(),
              'message':
                  'Email already exists in auth system: $normalizedEmail',
            };
          }
          // Re-throw if it's a different error
          rethrow;
        }
      }

      // Step 2: Hash the password for service_accounts table
      final hashedPassword = EncryptionService.hashPassword(password);

      // Step 3: Prepare account data for service_accounts table
      Map<String, dynamic> accountData = {
        'service_name': serviceName.trim(),
        'service_category': serviceCategory,
        'operational_type': operationalType,
        'contact_person': contactPerson.trim(),
        'email': normalizedEmail,
        'phone': phone.trim(),
        'username': username.trim(), // Preserve original case
        'password_hash': hashedPassword,
        'commission_rate': commissionRate,
        'is_active': true,
      };

      // Add code if provided (auto-set for Campus Service Units)
      if (code != null && code.isNotEmpty) {
        accountData['code'] = code.trim();
      }

      // Add main service ID for sub accounts
      if (operationalType == 'Sub' && mainServiceId != null) {
        accountData['main_service_id'] = mainServiceId;
      }

      // Add scanner ID if provided
      if (scannerId != null && scannerId.isNotEmpty) {
        accountData['scanner_id'] = scannerId.trim();
      }

      // Only main accounts get balance
      if (operationalType == 'Main') {
        accountData['balance'] = 0.00;
      }

      // Step 4: Insert into service_accounts table
      final response =
          await adminClient
              .from('service_accounts')
              .insert(accountData)
              .select()
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Service account created successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create service account: ${e.toString()}',
      };
    }
  }

  /// Get all service accounts with hierarchy
  static Future<Map<String, dynamic>> getServiceAccounts() async {
    try {
      // Use the underlying table with proper RLS instead of the view
      final response = await SupabaseService.client
          .from('service_accounts')
          .select('''
            id,
            service_name,
            service_category,
            operational_type,
            contact_person,
            email,
            phone,
            username,
            scanner_id,
            balance,
            commission_rate,
            is_active,
            created_at,
            updated_at,
            main_service_id
          ''')
          .eq('is_active', true) // Only get active accounts
          .order('operational_type', ascending: true)
          .order('service_name', ascending: true);

      // Get main service names for sub accounts
      final mainServiceIds =
          response
              .where((account) => account['main_service_id'] != null)
              .map((account) => account['main_service_id'] as int)
              .toSet();

      Map<int, String> mainServiceNames = {};
      if (mainServiceIds.isNotEmpty) {
        final mainServices = await client
            .from('service_accounts')
            .select('id, service_name')
            .inFilter('id', mainServiceIds.toList());

        mainServiceNames = {
          for (var service in mainServices)
            service['id'] as int: service['service_name'] as String,
        };
      }

      // Add main service names to the response
      final enrichedResponse =
          response.map((account) {
            final accountMap = Map<String, dynamic>.from(account);
            if (account['main_service_id'] != null) {
              accountMap['main_service_name'] =
                  mainServiceNames[account['main_service_id']];
            }
            return accountMap;
          }).toList();

      return {
        'success': true,
        'data': enrichedResponse,
        'message': 'Service accounts retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get service accounts: ${e.toString()}',
      };
    }
  }

  /// Get all service accounts including inactive ones (for management)
  static Future<Map<String, dynamic>>
  getAllServiceAccountsForManagement() async {
    try {
      // Use the underlying table with proper RLS instead of the view
      final response = await SupabaseService.client
          .from('service_accounts')
          .select('''
            id,
            service_name,
            service_category,
            operational_type,
            contact_person,
            email,
            phone,
            username,
            scanner_id,
            balance,
            commission_rate,
            is_active,
            created_at,
            updated_at,
            main_service_id
          ''')
          // No filter - get ALL accounts (active and inactive)
          .order('is_active', ascending: false) // Active accounts first
          .order('operational_type', ascending: true)
          .order('service_name', ascending: true);

      // Get main service names for sub accounts
      final mainServiceIds =
          response
              .where((account) => account['main_service_id'] != null)
              .map((account) => account['main_service_id'] as int)
              .toSet();

      Map<int, String> mainServiceNames = {};
      if (mainServiceIds.isNotEmpty) {
        final mainServices = await client
            .from('service_accounts')
            .select('id, service_name')
            .inFilter('id', mainServiceIds.toList());

        mainServiceNames = {
          for (var service in mainServices)
            service['id'] as int: service['service_name'] as String,
        };
      }

      // Add main service names to the response
      final enrichedResponse =
          response.map((account) {
            final accountMap = Map<String, dynamic>.from(account);
            if (account['main_service_id'] != null) {
              accountMap['main_service_name'] =
                  mainServiceNames[account['main_service_id']];
            }
            return accountMap;
          }).toList();

      return {
        'success': true,
        'data': enrichedResponse,
        'message': 'Service accounts retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get service accounts: ${e.toString()}',
      };
    }
  }

  /// Get main service accounts only
  static Future<Map<String, dynamic>> getMainServiceAccounts() async {
    try {
      final response = await SupabaseService.client
          .from('service_accounts')
          .select('*')
          .eq('operational_type', 'Main')
          .eq('is_active', true)
          .order('service_name', ascending: true);

      return {
        'success': true,
        'data': response,
        'message': 'Main service accounts retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get main service accounts: ${e.toString()}',
      };
    }
  }

  /// Get sub accounts for a main service
  static Future<Map<String, dynamic>> getSubAccounts(int mainServiceId) async {
    try {
      final response = await SupabaseService.client
          .from('service_accounts')
          .select('*')
          .eq('main_service_id', mainServiceId)
          .eq('operational_type', 'Sub')
          .eq('is_active', true)
          .order('service_name', ascending: true);

      return {
        'success': true,
        'data': response,
        'message': 'Sub accounts retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get sub accounts: ${e.toString()}',
      };
    }
  }

  /// Transfer balance from sub account to main account
  static Future<Map<String, dynamic>> transferSubAccountBalance({
    required int subAccountId,
    required double amount,
  }) async {
    try {
      final response = await SupabaseService.client.rpc(
        'transfer_sub_account_balance',
        params: {'sub_account_id': subAccountId, 'amount': amount},
      );

      return {
        'success': true,
        'data': response,
        'message': 'Balance transferred successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to transfer balance: ${e.toString()}',
      };
    }
  }

  /// Get total balance for main account (including sub accounts)
  static Future<Map<String, dynamic>> getMainAccountTotalBalance(
    int mainAccountId,
  ) async {
    try {
      final response = await SupabaseService.client.rpc(
        'get_main_account_total_balance',
        params: {'main_account_id': mainAccountId},
      );

      return {
        'success': true,
        'data': {'total_balance': response},
        'message': 'Total balance retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get total balance: ${e.toString()}',
      };
    }
  }

  /// Update service account
  static Future<Map<String, dynamic>> updateServiceAccount({
    required int accountId,
    String? serviceName,
    String? contactPerson,
    String? email,
    String? phone,
    String? scannerId,
    double? commissionRate,
    bool? isActive,
    String? passwordHash,
  }) async {
    try {
      Map<String, dynamic> updates = {};
      if (serviceName != null) updates['service_name'] = serviceName.trim();
      if (contactPerson != null)
        updates['contact_person'] = contactPerson.trim();
      if (email != null) updates['email'] = email.trim().toLowerCase();
      if (phone != null) updates['phone'] = phone.trim();
      if (scannerId != null) updates['scanner_id'] = scannerId.trim();
      if (commissionRate != null) updates['commission_rate'] = commissionRate;
      if (isActive != null) updates['is_active'] = isActive;
      if (passwordHash != null) updates['password_hash'] = passwordHash;

      if (updates.isEmpty) {
        return {
          'success': false,
          'error': 'No updates provided',
          'message': 'No fields to update',
        };
      }

      final response =
          await client
              .from('service_accounts')
              .update(updates)
              .eq('id', accountId)
              .select()
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Service account updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update service account: ${e.toString()}',
      };
    }
  }

  /// Check if service account has transactions
  /// Returns quickly by only checking if any exist (limit 1)
  static Future<Map<String, dynamic>> checkServiceAccountHasTransactions({
    required int accountId,
    bool includeCount = false, // Optional: only get count if needed
  }) async {
    try {
      if (accountId <= 0) {
        return {
          'success': false,
          'error': 'Invalid account id',
          'message': 'Invalid service account id provided',
        };
      }

      // Fast check: only fetch one record to see if any transactions exist
      final transactions = await client
          .from('service_transactions')
          .select('id')
          .eq('service_account_id', accountId)
          .limit(1);

      final hasTransactions = transactions.isNotEmpty;
      int? count;

      // Only get full count if requested (slower operation)
      if (includeCount && hasTransactions) {
        try {
          final allTransactions = await client
              .from('service_transactions')
              .select('id')
              .eq('service_account_id', accountId);
          count = allTransactions.length;
        } catch (e) {
          // If count fails, just use hasTransactions flag
          print('Warning: Could not get transaction count: $e');
        }
      }

      return {
        'success': true,
        'has_transactions': hasTransactions,
        'transaction_count': count,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to check transactions: ${e.toString()}',
      };
    }
  }

  /// Delete service account
  static Future<Map<String, dynamic>> deleteServiceAccount({
    required int accountId,
  }) async {
    try {
      if (accountId <= 0) {
        return {
          'success': false,
          'error': 'Invalid account id',
          'message': 'Invalid service account id provided',
        };
      }

      // Fast check: only verify if transactions exist (limit 1 query - very fast)
      final transactionCheck = await checkServiceAccountHasTransactions(
        accountId: accountId,
        includeCount:
            false, // Don't count all transactions - just check if any exist
      );

      if (transactionCheck['success'] == true &&
          transactionCheck['has_transactions'] == true) {
        // Transactions exist - return error immediately without counting
        // (Counting can be slow if there are many transactions)
        return {
          'success': false,
          'error': 'Foreign key constraint',
          'message':
              'Cannot delete service account because it has associated transactions. Service accounts with transaction history cannot be deleted to maintain data integrity.',
          'has_transactions': true,
          'transaction_count': null, // Count not available (for performance)
        };
      }

      // Delete and return the deleted row to ensure only one row is affected
      final deleted =
          await client
              .from('service_accounts')
              .delete()
              .eq('id', accountId)
              .select('id, service_name')
              .maybeSingle();

      if (deleted == null) {
        return {
          'success': false,
          'error': 'Not found',
          'message': 'Service account not found or already deleted',
        };
      }

      return {
        'success': true,
        'data': deleted,
        'message':
            'Service account "${deleted['service_name']}" deleted successfully',
      };
    } catch (e) {
      // Handle foreign key constraint errors specifically
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('foreign key') ||
          errorString.contains('23503') ||
          errorString.contains('still referenced')) {
        return {
          'success': false,
          'error': 'Foreign key constraint',
          'message':
              'Cannot delete service account because it has associated transactions. Service accounts with transaction history cannot be deleted to maintain data integrity. Consider deactivating the account instead.',
          'has_transactions': true,
        };
      }

      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete service account: ${e.toString()}',
      };
    }
  }

  /// Authenticate service account (service_accounts table)
  static Future<Map<String, dynamic>> authenticateServiceAccount({
    required String username,
    required String password,
  }) async {
    try {
      print('DEBUG: Authenticating service account with username: $username');

      // First, check if account exists (without is_active filter) to detect deactivated accounts
      final accountCheck =
          await client
              .from('service_accounts')
              .select('id, is_active, password_hash')
              .ilike('username', username.trim())
              .maybeSingle();

      // If account exists but is inactive, return specific error
      if (accountCheck != null && accountCheck['is_active'] == false) {
        print('DEBUG: Service account found but is deactivated');
        return {
          'success': false,
          'error': 'Account deactivated',
          'message':
              'Your account is deactivated. Contact admin to reactivate your account.',
          'is_deactivated': true,
        };
      }

      // Find active service account by username
      final account =
          await client
              .from('service_accounts')
              .select('*')
              .ilike('username', username.trim())
              .eq('is_active', true)
              .maybeSingle();

      print(
        'DEBUG: Service account query result: ${account != null ? 'Found' : 'Not found'}',
      );
      if (account != null) {
        print('DEBUG: Service category: ${account['service_category']}');
      }

      if (account == null) {
        return {
          'success': false,
          'error': 'Account not found',
          'message': 'Invalid username or password',
        };
      }

      final passwordHash = account['password_hash']?.toString() ?? '';
      final isValid = EncryptionService.verifyPassword(password, passwordHash);

      print('DEBUG: Password validation result: $isValid');

      if (!isValid) {
        return {
          'success': false,
          'error': 'Invalid password',
          'message': 'Invalid username or password',
        };
      }

      // Check if email is confirmed before allowing login
      final email = account['email']?.toString();
      if (email != null && email.isNotEmpty) {
        try {
          // Try to sign in with password to check if email is confirmed
          // This will fail if email is not confirmed
          try {
            await client.auth.signInWithPassword(
              email: email,
              password: password,
            );
            // If sign-in succeeds, email is confirmed - sign out immediately
            await client.auth.signOut();
          } catch (signInError) {
            final errorString = signInError.toString().toLowerCase();
            // Check if error is about email not confirmed
            if (errorString.contains('email not confirmed') ||
                errorString.contains('email_not_confirmed') ||
                errorString.contains('confirm your email')) {
              return {
                'success': false,
                'error': 'Email not confirmed',
                'message':
                    'Please confirm your email before logging in. Check your inbox for the confirmation email.',
                'email': email,
              };
            }
            // If it's a different error (like wrong password), continue with password hash check
            // The password hash check below will catch invalid passwords
          }
        } catch (adminError) {
          // If we can't check email confirmation status, log it but continue
          // The login will proceed, but service account may need to confirm email
          print(
            'DEBUG: Could not check service account email confirmation status: $adminError',
          );
        }
      }

      // Return sanitized account data
      final Map<String, dynamic> sanitized = {
        'id': account['id'],
        'service_name': account['service_name'],
        'service_category': account['service_category'],
        'operational_type': account['operational_type'],
        'main_service_id': account['main_service_id'],
        'scanner_id': account['scanner_id'],
        'balance': account['balance'],
        'commission_rate': account['commission_rate'],
        'contact_person': account['contact_person'],
        'email': account['email'],
        'phone': account['phone'],
        'username': account['username'],
      };

      return {
        'success': true,
        'data': sanitized,
        'message': 'Service account authenticated',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Service authentication failed: ${e.toString()}',
      };
    }
  }

  // Payment Items CRUD (payment_items table)

  static Future<Map<String, dynamic>> getPaymentItems({
    required int serviceAccountId,
  }) async {
    try {
      final response = await SupabaseService.client
          .from('payment_items')
          .select('*')
          .eq('service_account_id', serviceAccountId)
          .eq('is_active', true)
          .order('category', ascending: true)
          .order('name', ascending: true);

      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load payment items: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> getEffectivePaymentItems({
    required int serviceAccountId,
    required String operationalType,
    int? mainServiceId,
  }) async {
    try {
      if (operationalType == 'Sub') {
        // Sub-accounts: Only show items they created themselves (filter by service_name)
        // Get the sub account's service name
        final subAccountResponse =
            await client
                .from('service_accounts')
                .select('service_name')
                .eq('id', serviceAccountId)
                .maybeSingle();

        final subAccountName = subAccountResponse?['service_name']?.toString();

        if (subAccountName != null && subAccountName.isNotEmpty) {
          // Get main service ID for filtering
          final mainId = mainServiceId ?? serviceAccountId;

          // Query items where service_account_id = main account AND service_name = sub account name
          final response = await client
              .from('payment_items')
              .select('*')
              .eq('service_account_id', mainId)
              .eq('service_name', subAccountName)
              .eq('is_active', true)
              .order('category', ascending: true)
              .order('name', ascending: true);

          return {'success': true, 'data': response};
        } else {
          // Fallback: if service_name not found, use old behavior
          return await getPaymentItems(serviceAccountId: serviceAccountId);
        }
      } else {
        // Main accounts: Show all items (main account + all sub-accounts)
        // First, get all sub-account IDs for this main account
        final subAccountsResponse = await client
            .from('service_accounts')
            .select('id')
            .eq('main_service_id', serviceAccountId)
            .eq('is_active', true);

        final List<int> accountIds = [serviceAccountId]; // Include main account
        if (subAccountsResponse is List) {
          for (final subAccount in subAccountsResponse) {
            final subId = subAccount['id'];
            if (subId != null) {
              accountIds.add(subId as int);
            }
          }
        }

        // Query payment items for main account and all sub-accounts
        final response = await client
            .from('payment_items')
            .select('*')
            .inFilter('service_account_id', accountIds)
            .eq('is_active', true)
            .order('category', ascending: true)
            .order('name', ascending: true);

        return {'success': true, 'data': response};
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load effective payment items: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> createPaymentItem({
    required int serviceAccountId,
    required String name,
    required String category,
    required double basePrice,
    bool hasSizes = false,
    Map<String, double>? sizeOptions,
    String?
    serviceName, // Service name for tracking creator (Campus Service Units only)
  }) async {
    try {
      final insertData = {
        'service_account_id': serviceAccountId,
        'name': name.trim(),
        'category': category.trim(),
        'base_price': basePrice,
        'has_sizes': hasSizes,
        if (hasSizes && sizeOptions != null) 'size_options': sizeOptions,
        'is_active': true,
        // Add service_name if provided (for Campus Service Units)
        if (serviceName != null && serviceName.isNotEmpty)
          'service_name': serviceName.trim(),
      };

      final response =
          await client
              .from('payment_items')
              .insert(insertData)
              .select()
              .single();

      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create payment item: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> updatePaymentItem({
    required int itemId,
    String? name,
    String? category,
    double? basePrice,
    bool? hasSizes,
    Map<String, double>? sizeOptions,
    bool? isActive,
    String? currentServiceName, // For sub-account validation (optional)
    String? operationalType, // For sub-account validation (optional)
  }) async {
    try {
      // For sub-accounts: verify they can only edit items they created
      if (operationalType == 'Sub' &&
          currentServiceName != null &&
          currentServiceName.isNotEmpty) {
        final itemResponse =
            await client
                .from('payment_items')
                .select('service_name')
                .eq('id', itemId)
                .maybeSingle();

        final itemServiceName = itemResponse?['service_name']?.toString();

        // If item has a service_name and it doesn't match current service name, deny update
        if (itemServiceName != null &&
            itemServiceName.isNotEmpty &&
            itemServiceName != currentServiceName) {
          return {
            'success': false,
            'error': 'Permission denied',
            'message':
                'You can only edit items you created. This item was created by $itemServiceName.',
          };
        }
      }

      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name.trim();
      if (category != null) updates['category'] = category.trim();
      if (basePrice != null) updates['base_price'] = basePrice;
      if (hasSizes != null) updates['has_sizes'] = hasSizes;
      if (sizeOptions != null) updates['size_options'] = sizeOptions;
      if (isActive != null) updates['is_active'] = isActive;

      if (updates.isEmpty) {
        return {
          'success': false,
          'error': 'No updates provided',
          'message': 'Nothing to update',
        };
      }

      final response =
          await client
              .from('payment_items')
              .update(updates)
              .eq('id', itemId)
              .select()
              .single();

      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update payment item: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> deletePaymentItem({
    required int itemId,
    String? currentServiceName, // For sub-account validation (optional)
    String? operationalType, // For sub-account validation (optional)
  }) async {
    try {
      // For sub-accounts: verify they can only delete items they created
      if (operationalType == 'Sub' &&
          currentServiceName != null &&
          currentServiceName.isNotEmpty) {
        final itemResponse =
            await client
                .from('payment_items')
                .select('service_name')
                .eq('id', itemId)
                .maybeSingle();

        final itemServiceName = itemResponse?['service_name']?.toString();

        // If item has a service_name and it doesn't match current service name, deny delete
        if (itemServiceName != null &&
            itemServiceName.isNotEmpty &&
            itemServiceName != currentServiceName) {
          return {
            'success': false,
            'error': 'Permission denied',
            'message':
                'You can only delete items you created. This item was created by $itemServiceName.',
          };
        }
      }

      await client.from('payment_items').delete().eq('id', itemId);
      return {'success': true};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to delete payment item: ${e.toString()}',
      };
    }
  }

  // Service Transactions
  static Future<Map<String, dynamic>> createServiceTransaction({
    required int serviceAccountId,
    required String operationalType,
    String? studentId,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    int? mainServiceId,
    Map<String, dynamic>? metadata,
    String? purpose,
    String? transactionCode,
  }) async {
    try {
      final insertData = {
        'service_account_id': serviceAccountId,
        'main_service_id':
            operationalType == 'Sub'
                ? (mainServiceId ?? serviceAccountId)
                : serviceAccountId,
        'student_id': studentId,
        'items': items,
        'total_amount': totalAmount,
        'metadata': metadata ?? {},
      };

      // Add purpose and transaction_code for Campus Service Units
      if (purpose != null && purpose.isNotEmpty) {
        insertData['purpose'] = purpose;
      }
      if (transactionCode != null && transactionCode.isNotEmpty) {
        insertData['transaction_code'] = transactionCode;
      }

      final response =
          await client
              .from('service_transactions')
              .insert(insertData)
              .select()
              .single();

      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create transaction: ${e.toString()}',
      };
    }
  }

  // Withdrawal Operations

  /// Get all active service accounts for withdraw destination options
  static Future<Map<String, dynamic>> getAllServiceAccounts() async {
    try {
      await SupabaseService.initialize();

      final response = await client
          .from('service_accounts')
          .select('id, service_name, service_category')
          .eq('is_active', true)
          .order('service_name');

      return {
        'success': true,
        'data': response,
        'message': 'Service accounts retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve service accounts: ${e.toString()}',
      };
    }
  }

  // Analytics Operations

  /// Get analytics data for performance dashboard
  static Future<Map<String, dynamic>> getAnalyticsData({
    DateTime? startDate,
    DateTime? endDate,
    String? serviceCategory,
  }) async {
    try {
      await SupabaseService.initialize();

      // Get date range (default to last 30 days if not provided)
      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // Get service accounts with transaction counts and revenue
      String serviceAccountsQuery = '''
        id,
        service_name,
        service_category,
        operational_type,
        balance,
        is_active,
        created_at
      ''';

      var serviceAccountsResponse = await client
          .from('service_accounts')
          .select(serviceAccountsQuery)
          .eq('is_active', true);

      // Apply category filter if provided
      if (serviceCategory != null && serviceCategory != 'all') {
        serviceAccountsResponse =
            serviceAccountsResponse
                .where(
                  (account) => account['service_category'] == serviceCategory,
                )
                .toList();
      }

      // Get transaction data for each service
      List<Map<String, dynamic>> analyticsData = [];

      for (var account in serviceAccountsResponse) {
        // Get transaction count and total revenue for this service
        final transactionsResponse = await client
            .from('service_transactions')
            .select('id, total_amount, created_at')
            .eq('service_account_id', account['id'])
            .gte('created_at', start.toIso8601String())
            .lte('created_at', end.toIso8601String());

        final transactionCount = transactionsResponse.length;
        final totalRevenue = transactionsResponse.fold<double>(
          0.0,
          (sum, transaction) => sum + (transaction['total_amount'] ?? 0.0),
        );

        analyticsData.add({
          'service_id': account['id'],
          'service_name': account['service_name'],
          'service_category': account['service_category'],
          'operational_type': account['operational_type'],
          'balance': account['balance'] ?? 0.0,
          'transaction_count': transactionCount,
          'total_revenue': totalRevenue,
          'is_active': account['is_active'],
          'created_at': account['created_at'],
        });
      }

      // Calculate overall metrics
      final totalTransactions = analyticsData.fold<int>(
        0,
        (sum, data) => sum + (data['transaction_count'] as int),
      );
      final totalRevenue = analyticsData.fold<double>(
        0.0,
        (sum, data) => sum + (data['total_revenue'] as double),
      );
      final activeServices =
          analyticsData.where((data) => data['is_active'] == true).length;

      return {
        'success': true,
        'data': {
          'overall_metrics': {
            'total_transactions': totalTransactions,
            'total_revenue': totalRevenue,
            'active_services': activeServices,
          },
          'service_data': analyticsData,
          'date_range': {
            'start': start.toIso8601String(),
            'end': end.toIso8601String(),
          },
        },
        'message': 'Analytics data retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get analytics data: ${e.toString()}',
      };
    }
  }

  /// Get top and lowest performing services
  static Future<Map<String, dynamic>> getPerformanceRankings({
    DateTime? startDate,
    DateTime? endDate,
    String? serviceCategory,
    int limit = 5,
  }) async {
    try {
      await SupabaseService.initialize();

      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // Get service performance data
      final analyticsResult = await getAnalyticsData(
        startDate: start,
        endDate: end,
        serviceCategory: serviceCategory,
      );

      if (!analyticsResult['success']) {
        return analyticsResult;
      }

      final serviceData = List<Map<String, dynamic>>.from(
        analyticsResult['data']['service_data'],
      );

      // Sort by revenue to get top and lowest performers
      serviceData.sort(
        (a, b) => (b['total_revenue'] as double).compareTo(
          a['total_revenue'] as double,
        ),
      );

      final topPerformers = serviceData.take(limit).toList();
      final lowestPerformers = serviceData.reversed.take(limit).toList();

      return {
        'success': true,
        'data': {
          'top_performers': topPerformers,
          'lowest_performers': lowestPerformers,
        },
        'message': 'Performance rankings retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get performance rankings: ${e.toString()}',
      };
    }
  }

  /// Get revenue trends over time
  static Future<Map<String, dynamic>> getRevenueTrends({
    DateTime? startDate,
    DateTime? endDate,
    String? serviceCategory,
    String period = 'day', // day, week, month
  }) async {
    try {
      await SupabaseService.initialize();

      final start =
          startDate ?? DateTime.now().subtract(const Duration(days: 30));
      final end = endDate ?? DateTime.now();

      // Get service accounts to filter by category
      var serviceAccountsResponse = await client
          .from('service_accounts')
          .select('id, service_category')
          .eq('is_active', true);

      if (serviceCategory != null && serviceCategory != 'all') {
        serviceAccountsResponse =
            serviceAccountsResponse
                .where(
                  (account) => account['service_category'] == serviceCategory,
                )
                .toList();
      }

      final serviceIds =
          serviceAccountsResponse.map((account) => account['id']).toList();

      if (serviceIds.isEmpty) {
        return {
          'success': true,
          'data': {'trends': []},
          'message': 'No service accounts found for the selected category',
        };
      }

      // Get transactions grouped by period
      // Note: dateFormat variable is kept for future use with database date formatting functions

      final trendsResponse = await client
          .from('service_transactions')
          .select('total_amount, created_at')
          .inFilter('service_account_id', serviceIds)
          .gte('created_at', start.toIso8601String())
          .lte('created_at', end.toIso8601String())
          .order('created_at');

      // Group by period and calculate totals
      Map<String, double> periodTotals = {};
      for (var transaction in trendsResponse) {
        final createdAt = DateTime.parse(transaction['created_at']);
        String periodKey;

        switch (period) {
          case 'day':
            periodKey =
                '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
            break;
          case 'week':
            periodKey = '${createdAt.year}-W${createdAt.day ~/ 7 + 1}';
            break;
          case 'month':
            periodKey =
                '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
            break;
          default:
            periodKey =
                '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        }

        periodTotals[periodKey] =
            (periodTotals[periodKey] ?? 0.0) +
            (transaction['total_amount'] ?? 0.0);
      }

      // Convert to list format for charts
      List<Map<String, dynamic>> trends =
          periodTotals.entries
              .map((entry) => {'period': entry.key, 'revenue': entry.value})
              .toList();

      trends.sort((a, b) => a['period'].compareTo(b['period']));

      return {
        'success': true,
        'data': {'trends': trends},
        'message': 'Revenue trends retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to get revenue trends: ${e.toString()}',
      };
    }
  }

  /// Process user withdrawal
  /// If withdrawing to Admin: deduct user balance only (admin doesn't increase)
  /// If withdrawing to Service: deduct user balance and add to service balance
  static Future<Map<String, dynamic>> processUserWithdrawal({
    required String studentId,
    required double amount,
    required String destinationType, // 'admin' or 'service'
    int? destinationServiceId, // Required if destinationType is 'service'
    String? destinationServiceName,
  }) async {
    try {
      await SupabaseService.initialize();

      if (amount <= 0) {
        return {
          'success': false,
          'message': 'Withdrawal amount must be greater than zero',
        };
      }

      // Get user's current balance
      final userResponse =
          await adminClient
              .from(SupabaseConfig.authStudentsTable)
              .select('balance')
              .eq('student_id', studentId)
              .single();

      final currentBalance =
          (userResponse['balance'] as num?)?.toDouble() ?? 0.0;

      if (currentBalance < amount) {
        return {
          'success': false,
          'message':
              'Insufficient balance. Current balance: ₱${currentBalance.toStringAsFixed(2)}',
        };
      }

      // Deduct from user balance
      final newUserBalance = currentBalance - amount;
      await adminClient
          .from(SupabaseConfig.authStudentsTable)
          .update({'balance': newUserBalance})
          .eq('student_id', studentId);

      String transactionType;
      Map<String, dynamic> metadata = {
        'destination_type': destinationType,
        'amount': amount,
      };

      // If withdrawing to service, add to service balance
      if (destinationType == 'service') {
        if (destinationServiceId == null) {
          return {
            'success': false,
            'message':
                'Destination service ID is required for service withdrawal',
          };
        }

        // Get service's current balance
        final serviceResponse =
            await adminClient
                .from('service_accounts')
                .select('balance')
                .eq('id', destinationServiceId)
                .single();

        final serviceBalance =
            (serviceResponse['balance'] as num?)?.toDouble() ?? 0.0;
        final newServiceBalance = serviceBalance + amount;

        // Update service balance
        await adminClient
            .from('service_accounts')
            .update({'balance': newServiceBalance})
            .eq('id', destinationServiceId);

        transactionType = 'Withdraw to Service';
        metadata['destination_service_id'] = destinationServiceId;
        metadata['destination_service_name'] =
            destinationServiceName ?? 'Unknown Service';
      } else {
        // Withdrawing to Admin - admin balance doesn't increase
        transactionType = 'Withdraw to Admin';
      }

      // Log the withdrawal transaction
      final transactionResponse =
          await adminClient
              .from('withdrawal_transactions')
              .insert({
                'student_id': studentId,
                'amount': amount,
                'transaction_type': transactionType,
                'destination_service_id': destinationServiceId,
                'metadata': metadata,
              })
              .select()
              .single();

      return {
        'success': true,
        'data': {
          'transaction': transactionResponse,
          'new_balance': newUserBalance,
        },
        'message': 'Withdrawal processed successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to process withdrawal: ${e.toString()}',
      };
    }
  }

  /// Process service account withdrawal (can only withdraw to Admin)
  static Future<Map<String, dynamic>> processServiceWithdrawal({
    required int serviceAccountId,
    required double amount,
  }) async {
    try {
      await SupabaseService.initialize();

      if (amount <= 0) {
        return {
          'success': false,
          'message': 'Withdrawal amount must be greater than zero',
        };
      }

      // Get service's current balance
      final serviceResponse =
          await adminClient
              .from('service_accounts')
              .select('balance, service_name')
              .eq('id', serviceAccountId)
              .single();

      final currentBalance =
          (serviceResponse['balance'] as num?)?.toDouble() ?? 0.0;
      final serviceName =
          serviceResponse['service_name']?.toString() ?? 'Unknown Service';

      if (currentBalance < amount) {
        return {
          'success': false,
          'message':
              'Insufficient balance. Current balance: ₱${currentBalance.toStringAsFixed(2)}',
        };
      }

      // Deduct from service balance
      final newServiceBalance = currentBalance - amount;
      await adminClient
          .from('service_accounts')
          .update({'balance': newServiceBalance})
          .eq('id', serviceAccountId);

      // Log the withdrawal transaction
      final transactionResponse =
          await adminClient
              .from('withdrawal_transactions')
              .insert({
                'service_account_id': serviceAccountId,
                'amount': amount,
                'transaction_type': 'Service Withdraw to Admin',
                'metadata': {
                  'service_account_id': serviceAccountId,
                  'service_name': serviceName,
                  'destination_type': 'admin',
                },
              })
              .select()
              .single();

      return {
        'success': true,
        'data': {
          'transaction': transactionResponse,
          'new_balance': newServiceBalance,
        },
        'message': 'Withdrawal processed successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to process withdrawal: ${e.toString()}',
      };
    }
  }

  /// Get withdrawal history for a user
  static Future<Map<String, dynamic>> getUserWithdrawalHistory({
    required String studentId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await adminClient
          .from('withdrawal_transactions')
          .select('*')
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'Withdrawal history retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve withdrawal history: ${e.toString()}',
      };
    }
  }

  /// Get withdrawal history for a service account
  static Future<Map<String, dynamic>> getServiceWithdrawalHistory({
    required int serviceAccountId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await adminClient
          .from('withdrawal_transactions')
          .select('*')
          .eq('service_account_id', serviceAccountId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'Withdrawal history retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve withdrawal history: ${e.toString()}',
      };
    }
  }

  /// Get all withdrawal transactions (for admin view)
  static Future<Map<String, dynamic>> getAllWithdrawalTransactions({
    DateTime? start,
    DateTime? end,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      var query = adminClient.from('withdrawal_transactions').select('*');

      if (start != null) {
        query = query.gte('created_at', start.toIso8601String());
      }

      if (end != null) {
        query = query.lt('created_at', end.toIso8601String());
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'All withdrawal transactions retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message':
            'Failed to retrieve withdrawal transactions: ${e.toString()}',
      };
    }
  }

  // ================================================================
  // WITHDRAWAL REQUEST OPERATIONS (Admin Approval System)
  // ================================================================

  /// Create a withdrawal request (pending admin approval)
  /// Validates balance but does not deduct it until approved
  static Future<Map<String, dynamic>> createWithdrawalRequest({
    required String studentId,
    required double amount,
    required String transferType, // 'Gcash' or 'Cash'
    String? gcashNumber,
    String? gcashAccountName,
  }) async {
    try {
      await SupabaseService.initialize();

      if (amount <= 0) {
        return {
          'success': false,
          'message': 'Withdrawal amount must be greater than zero',
        };
      }

      // Validate transfer type
      if (transferType != 'Gcash' && transferType != 'Cash') {
        return {
          'success': false,
          'message': 'Invalid transfer type. Must be Gcash or Cash',
        };
      }

      // Validate Gcash fields if transfer type is Gcash
      if (transferType == 'Gcash') {
        if (gcashNumber == null || gcashNumber.trim().isEmpty) {
          return {
            'success': false,
            'message': 'GCash number is required for GCash withdrawals',
          };
        }
        if (gcashAccountName == null || gcashAccountName.trim().isEmpty) {
          return {
            'success': false,
            'message': 'GCash account name is required for GCash withdrawals',
          };
        }
      }

      // Get user's current balance to validate
      final userResponse =
          await adminClient
              .from(SupabaseConfig.authStudentsTable)
              .select('balance')
              .eq('student_id', studentId)
              .single();

      final currentBalance =
          (userResponse['balance'] as num?)?.toDouble() ?? 0.0;

      if (currentBalance < amount) {
        return {
          'success': false,
          'message':
              'Insufficient balance. Current balance: ₱${currentBalance.toStringAsFixed(2)}',
        };
      }

      // Create withdrawal request with status 'Pending'
      final requestResponse =
          await adminClient
              .from('withdrawal_requests')
              .insert({
                'student_id': studentId,
                'amount': amount,
                'transfer_type': transferType,
                'gcash_number': transferType == 'Gcash' ? gcashNumber : null,
                'gcash_account_name':
                    transferType == 'Gcash' ? gcashAccountName : null,
                'status': 'Pending',
              })
              .select()
              .single();

      return {
        'success': true,
        'data': requestResponse,
        'message':
            'Withdrawal request submitted successfully. Waiting for admin approval.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to create withdrawal request: ${e.toString()}',
      };
    }
  }

  /// Get withdrawal requests for a user
  static Future<Map<String, dynamic>> getUserWithdrawalRequests({
    required String studentId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await adminClient
          .from('withdrawal_requests')
          .select('*')
          .eq('student_id', studentId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'Withdrawal requests retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve withdrawal requests: ${e.toString()}',
      };
    }
  }

  /// Get all withdrawal requests (for admin view)
  static Future<Map<String, dynamic>> getAllWithdrawalRequests({
    String? status, // Filter by status: 'Pending', 'Approved', 'Rejected'
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      var query = adminClient.from('withdrawal_requests').select('*');

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'Withdrawal requests retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to retrieve withdrawal requests: ${e.toString()}',
      };
    }
  }

  /// Approve a withdrawal request (admin function)
  /// Deducts balance and creates a withdrawal transaction
  static Future<Map<String, dynamic>> approveWithdrawalRequest({
    required int requestId,
    required String processedBy,
    String? adminNotes,
  }) async {
    try {
      await SupabaseService.initialize();

      // Get the withdrawal request
      final requestResponse =
          await adminClient
              .from('withdrawal_requests')
              .select('*')
              .eq('id', requestId)
              .single();

      final studentId = requestResponse['student_id']?.toString();
      final amount = (requestResponse['amount'] as num?)?.toDouble() ?? 0.0;
      final transferType = requestResponse['transfer_type']?.toString() ?? '';
      final status = requestResponse['status']?.toString() ?? '';

      if (status != 'Pending') {
        return {
          'success': false,
          'message': 'Withdrawal request is not pending',
        };
      }

      if (studentId == null) {
        return {'success': false, 'message': 'Student ID not found in request'};
      }

      // Get user's current balance
      final userResponse =
          await adminClient
              .from(SupabaseConfig.authStudentsTable)
              .select('balance')
              .eq('student_id', studentId)
              .single();

      final currentBalance =
          (userResponse['balance'] as num?)?.toDouble() ?? 0.0;

      // If balance is insufficient, auto-reject the request
      if (currentBalance < amount) {
        // Auto-reject the request due to insufficient balance
        await adminClient
            .from('withdrawal_requests')
            .update({
              'status': 'Rejected',
              'processed_at': DateTime.now().toIso8601String(),
              'processed_by': processedBy,
              'admin_notes':
                  'Auto-rejected: Insufficient balance. Current balance: ₱${currentBalance.toStringAsFixed(2)}, Requested: ₱${amount.toStringAsFixed(2)}',
            })
            .eq('id', requestId);

        return {
          'success': false,
          'auto_rejected': true,
          'message':
              'Request auto-rejected due to insufficient balance. Current balance: ₱${currentBalance.toStringAsFixed(2)}, Requested: ₱${amount.toStringAsFixed(2)}',
          'current_balance': currentBalance,
          'requested_amount': amount,
        };
      }

      // Deduct from user balance
      final newUserBalance = currentBalance - amount;
      await adminClient
          .from(SupabaseConfig.authStudentsTable)
          .update({'balance': newUserBalance})
          .eq('student_id', studentId);

      // Create withdrawal transaction record
      final transactionResponse =
          await adminClient
              .from('withdrawal_transactions')
              .insert({
                'student_id': studentId,
                'amount': amount,
                'transaction_type': 'Withdraw to Admin',
                'metadata': {
                  'transfer_type': transferType,
                  'gcash_number': requestResponse['gcash_number'],
                  'gcash_account_name': requestResponse['gcash_account_name'],
                  'request_id': requestId,
                },
              })
              .select()
              .single();

      // Update withdrawal request status
      await adminClient
          .from('withdrawal_requests')
          .update({
            'status': 'Approved',
            'processed_at': DateTime.now().toIso8601String(),
            'processed_by': processedBy,
            'admin_notes': adminNotes,
          })
          .eq('id', requestId);

      return {
        'success': true,
        'data': {
          'transaction': transactionResponse,
          'new_balance': newUserBalance,
        },
        'message': 'Withdrawal request approved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to approve withdrawal request: ${e.toString()}',
      };
    }
  }

  /// Reject a withdrawal request (admin function)
  /// Updates status but does not deduct balance
  static Future<Map<String, dynamic>> rejectWithdrawalRequest({
    required int requestId,
    required String processedBy,
    String? adminNotes,
  }) async {
    try {
      await SupabaseService.initialize();

      // Get the withdrawal request
      final requestResponse =
          await adminClient
              .from('withdrawal_requests')
              .select('*')
              .eq('id', requestId)
              .single();

      final status = requestResponse['status']?.toString() ?? '';

      if (status != 'Pending') {
        return {
          'success': false,
          'message': 'Withdrawal request is not pending',
        };
      }

      // Update withdrawal request status
      await adminClient
          .from('withdrawal_requests')
          .update({
            'status': 'Rejected',
            'processed_at': DateTime.now().toIso8601String(),
            'processed_by': processedBy,
            'admin_notes': adminNotes,
          })
          .eq('id', requestId);

      return {
        'success': true,
        'message': 'Withdrawal request rejected successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to reject withdrawal request: ${e.toString()}',
      };
    }
  }

  // ================================================================
  // SERVICE WITHDRAWAL REQUEST OPERATIONS (Admin Approval System)
  // ================================================================

  /// Create a service withdrawal request (pending admin approval)
  /// Validates balance but does not deduct it until approved
  static Future<Map<String, dynamic>> createServiceWithdrawalRequest({
    required int serviceAccountId,
    required double amount,
  }) async {
    try {
      await SupabaseService.initialize();

      if (amount <= 0) {
        return {
          'success': false,
          'message': 'Withdrawal amount must be greater than zero',
        };
      }

      // Get service's current balance to validate
      final serviceResponse =
          await adminClient
              .from('service_accounts')
              .select('balance, service_name')
              .eq('id', serviceAccountId)
              .single();

      final currentBalance =
          (serviceResponse['balance'] as num?)?.toDouble() ?? 0.0;

      if (currentBalance < amount) {
        return {
          'success': false,
          'message':
              'Insufficient balance. Current balance: ₱${currentBalance.toStringAsFixed(2)}',
        };
      }

      // Create service withdrawal request with status 'Pending'
      final requestResponse =
          await adminClient
              .from('service_withdrawal_requests')
              .insert({
                'service_account_id': serviceAccountId,
                'amount': amount,
                'status': 'Pending',
              })
              .select()
              .single();

      return {
        'success': true,
        'data': requestResponse,
        'message':
            'Withdrawal request submitted successfully. Waiting for admin approval.',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message':
            'Failed to create service withdrawal request: ${e.toString()}',
      };
    }
  }

  /// Get service withdrawal requests for a service account
  static Future<Map<String, dynamic>> getServiceWithdrawalRequests({
    required int serviceAccountId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await adminClient
          .from('service_withdrawal_requests')
          .select('*')
          .eq('service_account_id', serviceAccountId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'Service withdrawal requests retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message':
            'Failed to retrieve service withdrawal requests: ${e.toString()}',
      };
    }
  }

  /// Get all service withdrawal requests (for admin view)
  static Future<Map<String, dynamic>> getAllServiceWithdrawalRequests({
    String? status, // Filter by status: 'Pending', 'Approved', 'Rejected'
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      var query = adminClient.from('service_withdrawal_requests').select('*');

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'Service withdrawal requests retrieved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message':
            'Failed to retrieve service withdrawal requests: ${e.toString()}',
      };
    }
  }

  /// Approve a service withdrawal request (admin function)
  /// Deducts balance and creates withdrawal transaction
  static Future<Map<String, dynamic>> approveServiceWithdrawalRequest({
    required int requestId,
    required String processedBy,
    String? adminNotes,
  }) async {
    try {
      await SupabaseService.initialize();

      // Get the service withdrawal request
      final requestResponse =
          await adminClient
              .from('service_withdrawal_requests')
              .select('*')
              .eq('id', requestId)
              .single();

      final serviceAccountId = requestResponse['service_account_id'] as int?;
      final amount = (requestResponse['amount'] as num?)?.toDouble() ?? 0.0;
      final status = requestResponse['status']?.toString() ?? '';

      if (status != 'Pending') {
        return {
          'success': false,
          'message': 'Service withdrawal request is not pending',
        };
      }

      if (serviceAccountId == null) {
        return {
          'success': false,
          'message': 'Service account ID not found in request',
        };
      }

      // Get service's current balance
      final serviceResponse =
          await adminClient
              .from('service_accounts')
              .select('balance, service_name')
              .eq('id', serviceAccountId)
              .single();

      final currentBalance =
          (serviceResponse['balance'] as num?)?.toDouble() ?? 0.0;
      final serviceName =
          serviceResponse['service_name']?.toString() ?? 'Unknown Service';

      // If balance is insufficient, auto-reject the request
      if (currentBalance < amount) {
        // Auto-reject the request due to insufficient balance
        await adminClient
            .from('service_withdrawal_requests')
            .update({
              'status': 'Rejected',
              'processed_at': DateTime.now().toIso8601String(),
              'processed_by': processedBy,
              'admin_notes':
                  'Auto-rejected: Insufficient balance. Current balance: ₱${currentBalance.toStringAsFixed(2)}, Requested: ₱${amount.toStringAsFixed(2)}',
            })
            .eq('id', requestId);

        return {
          'success': false,
          'auto_rejected': true,
          'message':
              'Request auto-rejected due to insufficient balance. Current balance: ₱${currentBalance.toStringAsFixed(2)}, Requested: ₱${amount.toStringAsFixed(2)}',
          'current_balance': currentBalance,
          'requested_amount': amount,
        };
      }

      // Deduct from service balance
      final newServiceBalance = currentBalance - amount;
      await adminClient
          .from('service_accounts')
          .update({'balance': newServiceBalance})
          .eq('id', serviceAccountId);

      // Create withdrawal transaction record
      final transactionResponse =
          await adminClient
              .from('withdrawal_transactions')
              .insert({
                'service_account_id': serviceAccountId,
                'amount': amount,
                'transaction_type': 'Service Withdraw to Admin',
                'metadata': {
                  'service_account_id': serviceAccountId,
                  'service_name': serviceName,
                  'destination_type': 'admin',
                  'request_id': requestId,
                },
              })
              .select()
              .single();

      // Update service withdrawal request status
      await adminClient
          .from('service_withdrawal_requests')
          .update({
            'status': 'Approved',
            'processed_at': DateTime.now().toIso8601String(),
            'processed_by': processedBy,
            'admin_notes': adminNotes,
          })
          .eq('id', requestId);

      return {
        'success': true,
        'data': {
          'transaction': transactionResponse,
          'new_balance': newServiceBalance,
        },
        'message': 'Service withdrawal request approved successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message':
            'Failed to approve service withdrawal request: ${e.toString()}',
      };
    }
  }

  /// Reject a service withdrawal request (admin function)
  /// Updates status but does not deduct balance
  static Future<Map<String, dynamic>> rejectServiceWithdrawalRequest({
    required int requestId,
    required String processedBy,
    String? adminNotes,
  }) async {
    try {
      await SupabaseService.initialize();

      // Get the service withdrawal request
      final requestResponse =
          await adminClient
              .from('service_withdrawal_requests')
              .select('*')
              .eq('id', requestId)
              .single();

      final status = requestResponse['status']?.toString() ?? '';

      if (status != 'Pending') {
        return {
          'success': false,
          'message': 'Service withdrawal request is not pending',
        };
      }

      // Update service withdrawal request status
      await adminClient
          .from('service_withdrawal_requests')
          .update({
            'status': 'Rejected',
            'processed_at': DateTime.now().toIso8601String(),
            'processed_by': processedBy,
            'admin_notes': adminNotes,
          })
          .eq('id', requestId);

      return {
        'success': true,
        'message': 'Service withdrawal request rejected successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message':
            'Failed to reject service withdrawal request: ${e.toString()}',
      };
    }
  }

  // Analytics / Income calculations
  /// Compute income summary within an optional date range [start, end).
  /// - Top-up Income: sum of admin_earn column from top_up_transactions table (includes all top-up types: top_up, top_up_gcash, top_up_services)
  /// - Loan Income: sum of interest repaid (from paid loans' interest_amount)
  /// - Total Income: Top-up Income + Loan Income
  static Future<Map<String, dynamic>> getIncomeSummary({
    DateTime? start,
    DateTime? end,
  }) async {
    try {
      await SupabaseService.initialize();

      // Build date filters
      final Map<String, dynamic> topupFilter = {};
      final Map<String, dynamic> loanFilter = {'status': 'paid'};

      if (start != null) {
        topupFilter['created_at.gte'] = start.toIso8601String();
        loanFilter['paid_at.gte'] = start.toIso8601String();
      }
      if (end != null) {
        topupFilter['created_at.lt'] = end.toIso8601String();
        loanFilter['paid_at.lt'] = end.toIso8601String();
      }

      // Fetch top-ups in range - use admin_earn column instead of calculating fees
      // Include all top-up transaction types: top_up, top_up_gcash, top_up_services
      final topupQuery = client
          .from('top_up_transactions')
          .select('admin_earn, created_at, transaction_type')
          .inFilter('transaction_type', [
            'top_up',
            'top_up_gcash',
            'top_up_services',
          ]);
      if (topupFilter.containsKey('created_at.gte')) {
        topupQuery.gte('created_at', topupFilter['created_at.gte']);
      }
      if (topupFilter.containsKey('created_at.lt')) {
        topupQuery.lt('created_at', topupFilter['created_at.lt']);
      }
      final topups = await topupQuery;

      // Sum admin_earn from all top-up transactions
      // admin_earn column stores the actual admin commission earned per transaction
      double topUpIncome = 0.0;
      for (final t in topups) {
        final double adminEarn = (t['admin_earn'] as num?)?.toDouble() ?? 0.0;
        topUpIncome += adminEarn;
      }

      // Fetch paid loans in range; use interest_amount as interest repaid
      final loanQuery = client
          .from('active_loans')
          .select('interest_amount, paid_at, status')
          .eq('status', 'paid');
      if (loanFilter.containsKey('paid_at.gte')) {
        loanQuery.gte('paid_at', loanFilter['paid_at.gte']);
      }
      if (loanFilter.containsKey('paid_at.lt')) {
        loanQuery.lt('paid_at', loanFilter['paid_at.lt']);
      }
      final loans = await loanQuery;

      double loanIncome = 0.0;
      for (final l in loans) {
        final double interest =
            (l['interest_amount'] as num?)?.toDouble() ?? 0.0;
        loanIncome += interest;
      }

      final totalIncome = topUpIncome + loanIncome;

      return {
        'success': true,
        'data': {
          'top_up_income': _roundToTwoDecimals(topUpIncome),
          'loan_income': _roundToTwoDecimals(loanIncome),
          'total_income': _roundToTwoDecimals(totalIncome),
          'counts': {'topups': topups.length, 'paid_loans': loans.length},
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to compute income summary: ${e.toString()}',
      };
    }
  }

  static int? _coerceToInt(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static Future<Map<String, String>> _fetchStudentNames(
    Set<String> studentIds,
  ) async {
    if (studentIds.isEmpty) {
      return {};
    }

    try {
      final response = await adminClient
          .from('auth_students')
          .select('student_id, name')
          .inFilter('student_id', studentIds.toList());

      final Map<String, String> names = {};

      for (final row in response) {
        final id = row['student_id']?.toString();
        if (id == null || id.isEmpty) {
          continue;
        }

        String name = row['name']?.toString().trim() ?? '';

        if (name.isNotEmpty && EncryptionService.looksLikeEncryptedData(name)) {
          try {
            name = EncryptionService.decryptData(name).trim();
          } catch (decryptionError) {
            print(
              'DEBUG: Failed to decrypt student name for $id: $decryptionError',
            );
          }
        }

        if (name.isEmpty) {
          name = 'Student $id';
        }

        names[id] = name;
      }

      return names;
    } catch (e) {
      print('DEBUG: Error fetching student names for transactions: $e');
      return {};
    }
  }

  static Future<Map<int, String>> _fetchServiceNames(
    Set<int> serviceIds,
  ) async {
    if (serviceIds.isEmpty) {
      return {};
    }

    try {
      final response = await adminClient
          .from('service_accounts')
          .select('id, service_name')
          .inFilter('id', serviceIds.toList());

      final Map<int, String> names = {};

      for (final row in response) {
        final int? id = _coerceToInt(row['id']);
        if (id == null) {
          continue;
        }

        final rawName = row['service_name']?.toString().trim() ?? '';
        names[id] = rawName.isEmpty ? 'Service #$id' : rawName;
      }

      return names;
    } catch (e) {
      print('DEBUG: Error fetching service names for transactions: $e');
      return {};
    }
  }

  static double _roundToTwoDecimals(double value) {
    return (value * 100).roundToDouble() / 100.0;
  }

  // Feedback System Methods

  /// Submit feedback from service account or user
  static Future<Map<String, dynamic>> submitFeedback({
    required String userType, // 'user' or 'service_account'
    required String accountUsername,
    required String message,
  }) async {
    try {
      await SupabaseService.initialize();

      // Validate inputs
      if (userType != 'user' && userType != 'service_account') {
        return {
          'success': false,
          'message': 'Invalid user type. Must be "user" or "service_account"',
        };
      }

      if (message.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Feedback message cannot be empty',
        };
      }

      if (accountUsername.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Account username cannot be empty',
        };
      }

      // Insert feedback
      final response =
          await SupabaseService.client
              .from('feedback')
              .insert({
                'user_type': userType,
                'account_username': accountUsername.trim(),
                'message': message.trim(),
              })
              .select()
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Feedback submitted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to submit feedback: ${e.toString()}',
      };
    }
  }

  /// Get feedback for service accounts (can view all feedback)
  static Future<Map<String, dynamic>> getFeedbackForServiceAccount({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await SupabaseService.client
          .from('feedback')
          .select('id, user_type, account_username, message, created_at')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'Feedback loaded successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load feedback: ${e.toString()}',
      };
    }
  }

  /// Get feedback for users (can only view their own feedback)
  static Future<Map<String, dynamic>> getFeedbackForUser({
    required String username,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await SupabaseService.client
          .from('feedback')
          .select('id, user_type, account_username, message, created_at')
          .eq('user_type', 'user')
          .eq('account_username', username)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'User feedback loaded successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load user feedback: ${e.toString()}',
      };
    }
  }

  // Commission Settings Methods

  /// Get commission settings (vendor and admin commission percentages)
  static Future<Map<String, dynamic>> getCommissionSettings() async {
    try {
      await SupabaseService.initialize();
      // Try using RPC function first
      try {
        final response = await SupabaseService.client.rpc(
          'get_commission_settings',
        );
        if (response != null && response['success'] == true) {
          return {'success': true, 'data': response['data']};
        }
      } catch (_) {
        // Fallback to direct table access if RPC fails
      }

      // Fallback: Direct table access
      final response =
          await SupabaseService.client
              .from('commission_settings')
              .select('*')
              .order('updated_at', ascending: false)
              .limit(1)
              .maybeSingle();

      if (response == null) {
        // Return defaults if no settings exist
        return {
          'success': true,
          'data': {
            'vendor_commission': 1.00,
            'admin_commission': 0.50,
            'updated_at': DateTime.now().toIso8601String(),
          },
        };
      }

      return {
        'success': true,
        'data': {
          'id': response['id'],
          'vendor_commission':
              (response['vendor_commission'] as num?)?.toDouble() ?? 1.00,
          'admin_commission':
              (response['admin_commission'] as num?)?.toDouble() ?? 0.50,
          'updated_at': response['updated_at'],
          'created_at': response['created_at'],
        },
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load commission settings: ${e.toString()}',
        'data': {'vendor_commission': 1.00, 'admin_commission': 0.50},
      };
    }
  }

  /// Update commission settings
  static Future<Map<String, dynamic>> updateCommissionSettings({
    required double vendorCommission,
    required double adminCommission,
  }) async {
    try {
      await SupabaseService.initialize();

      // Validate commission values
      if (vendorCommission < 0 || vendorCommission > 100) {
        return {
          'success': false,
          'error': 'INVALID_VENDOR_COMMISSION',
          'message': 'Vendor commission must be between 0.00 and 100.00',
        };
      }

      if (adminCommission < 0 || adminCommission > 100) {
        return {
          'success': false,
          'error': 'INVALID_ADMIN_COMMISSION',
          'message': 'Admin commission must be between 0.00 and 100.00',
        };
      }

      // Try using RPC function first
      try {
        final response = await SupabaseService.client.rpc(
          'update_commission_settings',
          params: {
            'p_vendor_commission': vendorCommission,
            'p_admin_commission': adminCommission,
          },
        );

        if (response != null && response['success'] == true) {
          return {
            'success': true,
            'data': response['data'],
            'message':
                response['message'] ??
                'Commission settings updated successfully',
          };
        } else {
          throw Exception(
            response['message'] ?? 'Failed to update commission settings',
          );
        }
      } catch (e) {
        // Fallback to direct table upsert if RPC fails
        final payload = {
          'vendor_commission': vendorCommission,
          'admin_commission': adminCommission,
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Get existing row or create new one
        final existing =
            await SupabaseService.client
                .from('commission_settings')
                .select('id')
                .limit(1)
                .maybeSingle();

        final response =
            existing != null
                ? await SupabaseService.adminClient
                    .from('commission_settings')
                    .update(payload)
                    .eq('id', existing['id'])
                    .select()
                    .single()
                : await SupabaseService.adminClient
                    .from('commission_settings')
                    .insert(payload)
                    .select()
                    .single();

        return {
          'success': true,
          'data': response,
          'message': 'Commission settings updated successfully',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update commission settings: ${e.toString()}',
      };
    }
  }
}

// Scanner Device APIs for service account scanner management
extension ScannerDeviceApis on SupabaseService {
  /// Get scanner device information for a service account
  static Future<Map<String, dynamic>> getServiceAccountScanner({
    required String username,
  }) async {
    try {
      print("DEBUG: Querying service_accounts for username: $username");

      // Get service account with scanner information
      final serviceResponse =
          await SupabaseService.client
              .from('service_accounts')
              .select('id, service_name, scanner_id')
              .eq('username', username)
              .eq('is_active', true)
              .maybeSingle();

      print("DEBUG: Service account query result: $serviceResponse");

      if (serviceResponse == null) {
        return {
          'success': false,
          'message': 'Service account not found or inactive',
        };
      }

      final String? scannerId = serviceResponse['scanner_id'];
      print("DEBUG: Scanner ID from service account: $scannerId");

      if (scannerId == null || scannerId.isEmpty) {
        return {
          'success': false,
          'message': 'No scanner assigned to this service account',
          'service_account': serviceResponse,
        };
      }

      print("DEBUG: Found scanner_id '$scannerId' for service account");

      // Get scanner device details
      print("DEBUG: Querying scanner_devices for scanner_id: $scannerId");

      // First try to get the scanner device (regardless of status since it's assigned to this service)
      final scannerResponse =
          await SupabaseService.client
              .from('scanner_devices')
              .select('*')
              .eq('scanner_id', scannerId)
              .maybeSingle();

      print("DEBUG: Scanner device query result: $scannerResponse");

      if (scannerResponse == null) {
        print("DEBUG: Scanner device not found in scanner_devices table");
        return {
          'success': false,
          'message': 'Scanner device not found in database',
          'service_account': serviceResponse,
        };
      }

      // Check if this scanner is assigned to the current service
      final assignedServiceId = scannerResponse['assigned_service_id'];
      final currentServiceId = serviceResponse['id'];

      print(
        "DEBUG: Scanner assigned_service_id: $assignedServiceId, current service id: $currentServiceId",
      );

      if (assignedServiceId != null && assignedServiceId != currentServiceId) {
        return {
          'success': false,
          'message': 'Scanner is assigned to a different service',
          'service_account': serviceResponse,
        };
      }

      return {
        'success': true,
        'message': 'Scanner information retrieved successfully',
        'service_account': serviceResponse,
        'scanner_device': scannerResponse,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get scanner information: ${e.toString()}',
      };
    }
  }

  /// Get all available scanners (not assigned)
  static Future<Map<String, dynamic>> getAvailableScanners() async {
    try {
      final response = await SupabaseService.client
          .from('scanner_devices')
          .select('*')
          .eq('status', 'Available')
          .order('scanner_id');

      return {
        'success': true,
        'message': 'Available scanners retrieved successfully',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get available scanners: ${e.toString()}',
      };
    }
  }

  /// Get all scanner assignments (for admin view)
  static Future<Map<String, dynamic>> getScannerAssignments() async {
    try {
      final response = await SupabaseService.client
          .from('scanner_assignments')
          .select('*')
          .order('scanner_id');

      return {
        'success': true,
        'message': 'Scanner assignments retrieved successfully',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to get scanner assignments: ${e.toString()}',
      };
    }
  }

  /// Assign scanner to service account
  static Future<Map<String, dynamic>> assignScannerToService({
    required String scannerId,
    required int serviceAccountId,
  }) async {
    try {
      // Call the database function to assign scanner
      final response = await SupabaseService.client.rpc(
        'assign_scanner_to_service',
        params: {
          'scanner_device_id': scannerId,
          'service_account_id': serviceAccountId,
        },
      );

      return {
        'success': true,
        'message': 'Scanner assigned successfully',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to assign scanner: ${e.toString()}',
      };
    }
  }

  /// Unassign scanner from service
  static Future<Map<String, dynamic>> unassignScannerFromService({
    required String scannerId,
  }) async {
    try {
      // Call the database function to unassign scanner
      final response = await SupabaseService.client.rpc(
        'unassign_scanner_from_service',
        params: {'scanner_device_id': scannerId},
      );

      return {
        'success': true,
        'message': 'Scanner unassigned successfully',
        'data': response,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to unassign scanner: ${e.toString()}',
      };
    }
  }

  /// Quick assign scanner to service by username (for testing/debugging)
  static Future<Map<String, dynamic>> quickAssignScannerToServiceByUsername({
    required String username,
    required String scannerId,
  }) async {
    try {
      print("DEBUG: Quick assigning $scannerId to service username: $username");

      // First ensure the scanner exists in scanner_devices table
      await ensureScannerExists(scannerId);

      // Get the service account ID
      final serviceResponse =
          await SupabaseService.client
              .from('service_accounts')
              .select('id')
              .eq('username', username)
              .eq('is_active', true)
              .maybeSingle();

      if (serviceResponse == null) {
        return {
          'success': false,
          'message': 'Service account not found: $username',
        };
      }

      int serviceAccountId = serviceResponse['id'];
      print("DEBUG: Found service account ID: $serviceAccountId");

      // Assign the scanner
      return await assignScannerToService(
        scannerId: scannerId,
        serviceAccountId: serviceAccountId,
      );
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to assign scanner: ${e.toString()}',
      };
    }
  }

  /// Ensure scanner exists in scanner_devices table
  static Future<void> ensureScannerExists(String scannerId) async {
    try {
      print("DEBUG: Ensuring scanner $scannerId exists in database");

      // Check if scanner already exists
      final existingScanner =
          await SupabaseService.client
              .from('scanner_devices')
              .select('*')
              .eq('scanner_id', scannerId)
              .maybeSingle();

      if (existingScanner != null) {
        print("DEBUG: Scanner $scannerId already exists: $existingScanner");
        return;
      }

      // Create the scanner if it doesn't exist
      final scannerNumber = scannerId.replaceAll('EvsuPay', '');
      final newScanner =
          await SupabaseService.client
              .from('scanner_devices')
              .insert({
                'scanner_id': scannerId,
                'device_name': 'RFID Bluetooth Scanner $scannerNumber',
                'device_type': 'RFID_Bluetooth_Scanner',
                'model': 'ESP32 RFID',
                'serial_number': 'ESP${scannerNumber.padLeft(3, '0')}',
                'status': 'Available',
                'notes': 'Auto-created for testing',
              })
              .select()
              .single();

      print("DEBUG: Created new scanner: $newScanner");
    } catch (e) {
      print("DEBUG: Error ensuring scanner exists: $e");
    }
  }

  /// Fix scanner assignment sync between service_accounts and scanner_devices
  static Future<Map<String, dynamic>> fixScannerAssignmentSync({
    required String scannerId,
    required int serviceAccountId,
  }) async {
    try {
      print(
        "DEBUG: Fixing scanner assignment sync for $scannerId and service $serviceAccountId",
      );

      // Ensure scanner exists first
      await ensureScannerExists(scannerId);

      // Update scanner_devices table to match service_accounts assignment
      final updateResult =
          await SupabaseService.client
              .from('scanner_devices')
              .update({
                'status': 'Assigned',
                'assigned_service_id': serviceAccountId,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('scanner_id', scannerId)
              .select()
              .single();

      print("DEBUG: Fixed scanner assignment sync: $updateResult");

      return {
        'success': true,
        'message': 'Scanner assignment sync fixed',
        'data': updateResult,
      };
    } catch (e) {
      print("DEBUG: Error fixing scanner assignment sync: $e");
      return {
        'success': false,
        'message': 'Failed to fix scanner assignment sync: ${e.toString()}',
      };
    }
  }
}

// Loaning APIs (placeholders for now)
extension LoaningApis on SupabaseService {
  /// Get loan settings (interest, allowed terms, limits)
  static Future<Map<String, dynamic>> getLoanSettings() async {
    try {
      final response =
          await SupabaseService.client
              .from('loan_settings')
              .select('*')
              .limit(1)
              .maybeSingle();

      if (response == null) {
        // default settings if none exist yet
        return {
          'success': true,
          'data': {
            'interest_rate_percent': 5.0,
            'allowed_terms_days': [3, 7, 30],
            'per_student_max': 1000.0,
            'total_pool_max': 20000.0,
            'default_interest_per_day_percent': 0.5,
            'default_late_fee_per_day_percent': 0.1,
          },
        };
      }

      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load loan settings: ${e.toString()}',
      };
    }
  }

  /// Update loan settings
  static Future<Map<String, dynamic>> updateLoanSettings({
    required double interestRatePercent,
    required List<int> allowedTermsDays,
    required double perStudentMax,
    required double totalPoolMax,
    double? defaultInterestPerDayPercent,
    double? defaultLateFeePerDayPercent,
  }) async {
    try {
      final payload = {
        'interest_rate_percent': interestRatePercent,
        'allowed_terms_days': allowedTermsDays,
        'per_student_max': perStudentMax,
        'total_pool_max': totalPoolMax,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (defaultInterestPerDayPercent != null) {
        payload['default_interest_per_day_percent'] =
            defaultInterestPerDayPercent;
      }
      if (defaultLateFeePerDayPercent != null) {
        payload['default_late_fee_per_day_percent'] =
            defaultLateFeePerDayPercent;
      }

      // upsert single row settings
      final response =
          await SupabaseService.client
              .from('loan_settings')
              .upsert(payload, onConflict: 'id')
              .select()
              .maybeSingle();

      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update loan settings: ${e.toString()}',
      };
    }
  }

  /// List active loans with basic student info
  static Future<Map<String, dynamic>> getActiveLoans() async {
    try {
      final response = await SupabaseService.client
          .from('loans')
          .select(
            'id, student_id, student_name, amount, term_days, interest_rate_percent, due_date, status',
          )
          .neq('status', 'settled')
          .order('created_at', ascending: false);

      return {'success': true, 'data': response};
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load loans: ${e.toString()}',
      };
    }
  }

  // Feedback System Methods

  /// Test method to verify class structure
  static Future<bool> testMethod() async {
    return true;
  }

  /// Submit feedback from service account or user
  static Future<Map<String, dynamic>> submitFeedback({
    required String userType, // 'user' or 'service_account'
    required String accountUsername,
    required String message,
  }) async {
    try {
      await SupabaseService.initialize();

      // Validate inputs
      if (userType != 'user' && userType != 'service_account') {
        return {
          'success': false,
          'message': 'Invalid user type. Must be "user" or "service_account"',
        };
      }

      if (message.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Feedback message cannot be empty',
        };
      }

      if (accountUsername.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Account username cannot be empty',
        };
      }

      // Insert feedback
      final response =
          await SupabaseService.client
              .from('feedback')
              .insert({
                'user_type': userType,
                'account_username': accountUsername.trim(),
                'message': message.trim(),
              })
              .select()
              .single();

      return {
        'success': true,
        'data': response,
        'message': 'Feedback submitted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to submit feedback: ${e.toString()}',
      };
    }
  }

  /// Get feedback for service accounts (can view all feedback)
  static Future<Map<String, dynamic>> getFeedbackForServiceAccount({
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await SupabaseService.client
          .from('feedback')
          .select('id, user_type, account_username, message, created_at')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'Feedback loaded successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load feedback: ${e.toString()}',
      };
    }
  }

  /// Get feedback for users (can only view their own feedback)
  static Future<Map<String, dynamic>> getFeedbackForUser({
    required String username,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      await SupabaseService.initialize();

      final response = await SupabaseService.client
          .from('feedback')
          .select('id, user_type, account_username, message, created_at')
          .eq('user_type', 'user')
          .eq('account_username', username)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return {
        'success': true,
        'data': response,
        'message': 'User feedback loaded successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to load user feedback: ${e.toString()}',
      };
    }
  }
}

// Analytics / Income calculations
