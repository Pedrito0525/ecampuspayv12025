import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// Service for uploading loan proof images to Supabase storage
class LoanImageService {
  static const String bucketName = 'loan_proof_image';

  /// Upload image to Supabase storage bucket
  static Future<String> uploadLoanProofImage(
    File imageFile,
    String studentId,
    int loanPlanId,
  ) async {
    try {
      await SupabaseService.initialize();
      
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${studentId}_${loanPlanId}_$timestamp.jpg';
      final filePath = '$studentId/$fileName';

      // Read image file as bytes
      final imageBytes = await imageFile.readAsBytes();

      // Upload to Supabase storage
      await SupabaseService.client.storage
          .from(bucketName)
          .uploadBinary(
            filePath,
            imageBytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      // Get public URL
      final url = SupabaseService.client.storage
          .from(bucketName)
          .getPublicUrl(filePath);

      return url;
    } catch (e) {
      throw Exception('Failed to upload image: $e');
    }
  }

  /// Ensure bucket exists (call this once during app initialization)
  static Future<void> ensureBucketExists() async {
    try {
      await SupabaseService.initialize();
      
      // Try to list buckets to check if it exists
      final buckets = await SupabaseService.client.storage.listBuckets();
      final bucketExists = buckets.any((bucket) => bucket.name == bucketName);

      if (!bucketExists) {
        // Note: Bucket creation typically requires admin privileges
        // This should be done manually in Supabase dashboard or via admin API
        throw Exception(
          'Bucket "$bucketName" does not exist. Please create it in Supabase dashboard.',
        );
      }
    } catch (e) {
      print('Warning: Could not verify bucket existence: $e');
      // Don't throw - bucket might exist but we don't have permission to list
    }
  }
}

