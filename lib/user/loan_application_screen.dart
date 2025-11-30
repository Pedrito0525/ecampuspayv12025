import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ocr_service.dart';
import '../services/loan_image_service.dart';
import '../services/loan_eligibility_service.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';

class LoanApplicationScreen extends StatefulWidget {
  final Map<String, dynamic> loanPlan;
  final VoidCallback? onLoanSubmitted;

  const LoanApplicationScreen({
    super.key,
    required this.loanPlan,
    this.onLoanSubmitted,
  });

  @override
  State<LoanApplicationScreen> createState() => _LoanApplicationScreenState();
}

class _LoanApplicationScreenState extends State<LoanApplicationScreen> {
  static const Color evsuRed = Color(0xFFB91C1C);

  bool _agreedToTerms = false;
  File? _selectedImage;
  bool _isProcessing = false;
  Map<String, dynamic>? _ocrData;
  Map<String, dynamic>? _eligibilityResult;
  bool _showExampleImage = false;

  @override
  Widget build(BuildContext context) {
    final amount = (widget.loanPlan['amount'] as num).toDouble();
    final interestRate = (widget.loanPlan['interest_rate'] as num).toDouble();
    final totalRepayable = amount + (amount * interestRate / 100);
    final termDays = widget.loanPlan['term_days'] as int;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: evsuRed,
        title: const Text(
          'Loan Application',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Loan Plan Summary
            _buildLoanPlanSummary(
              amount,
              totalRepayable,
              termDays,
              interestRate,
            ),

            const SizedBox(height: 24),

            // Step 1: Loan Agreement
            _buildLoanAgreementSection(),

            const SizedBox(height: 24),

            // Step 2: Upload Enrollment Screenshot
            if (_agreedToTerms) _buildUploadSection(),

            const SizedBox(height: 24),

            // Step 3: OCR Results (if image uploaded)
            if (_ocrData != null) _buildOCRResultsSection(),

            const SizedBox(height: 24),

            // Step 4: Eligibility Check Results
            if (_eligibilityResult != null) _buildEligibilityResultsSection(),

            const SizedBox(height: 24),

            // Submit Button
            if (_agreedToTerms &&
                _selectedImage != null &&
                _eligibilityResult != null)
              _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanPlanSummary(
    double amount,
    double totalRepayable,
    int termDays,
    double interestRate,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.loanPlan['name'] as String,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Loan Amount:'),
                Text(
                  '₱${amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Interest Rate:'),
                Text('${interestRate.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [const Text('Term:'), Text('$termDays days')],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Repayable:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₱${totalRepayable.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: evsuRed,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoanAgreementSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Loan Terms & Conditions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              '1. I understand that this is a short-term loan with interest.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '2. I agree to repay the loan amount plus interest within the specified term.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '3. Late payments will incur penalty fees as specified.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '4. I confirm that I am officially enrolled for the current academic year and semester.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '5. I understand that failure to repay may affect my account status.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _agreedToTerms,
              onChanged: (value) {
                setState(() {
                  _agreedToTerms = value ?? false;
                });
              },
              title: const Text('I Agree to the Loan Terms'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload Enrollment Screenshot',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Instructions with example format
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Screenshot Format Guide',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Capture ONLY the enrollment subjects section:\n'
                    '✓ Include: "Subjects Enrolled", Status, AY, Semester, Subject codes\n'
                    '✗ Exclude: Navigation menu, links (app.evsu.edu.ph), profile picture\n'
                    '✗ Exclude: Browser address bar, bookmarks, other tabs',
                    style: TextStyle(fontSize: 13, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.crop_free,
                          color: Colors.orange.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cut your photo to match this example image. No link.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Example: Screenshot should show "Subjects Enrolled" card with status, AY 2025-2026 Sem: 1, and subject codes like IT 413, IT 433',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () {
                            setState(() {
                              _showExampleImage = !_showExampleImage;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade300),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _showExampleImage
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  size: 16,
                                  color: Colors.blue.shade700,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _showExampleImage
                                      ? 'Hide Example Image'
                                      : 'Show Example Image',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_showExampleImage) ...[
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.blue.shade300,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.asset(
                                'assets/student_portal.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    color: Colors.grey.shade200,
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.image_not_supported,
                                          size: 48,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Example image not found',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '📸 This is the correct format. Capture only this section!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedImage == null)
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Select Screenshot'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: evsuRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Make sure to capture only the enrollment section\n(no links, navigation menu, or browser bars)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Change Image'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isProcessing ? null : _processImage,
                          icon: const Icon(Icons.scanner),
                          label: const Text('Scan Image'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: evsuRed,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOCRResultsSection() {
    if (_ocrData == null) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'OCR Scan Results',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildOCRResultItem(
              'Name',
              _ocrData!['name']?.toString() ?? 'Not found',
            ),
            _buildOCRResultItem(
              'Status',
              _ocrData!['status']?.toString() ?? 'Not found',
            ),
            _buildOCRResultItem(
              'Academic Year',
              _ocrData!['academic_year']?.toString() ?? 'Not found',
            ),
            _buildOCRResultItem(
              'Semester',
              _ocrData!['semester']?.toString() ?? 'Not found',
            ),
            _buildOCRResultItem(
              'Subjects',
              (_ocrData!['subjects'] as List<dynamic>?)?.length.toString() ??
                  '0',
            ),
            _buildOCRResultItem(
              'Confidence',
              '${((_ocrData!['confidence'] as num?)?.toDouble() ?? 0.0) * 100}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOCRResultItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Not found' : value,
              style: TextStyle(
                color: value.isEmpty ? Colors.red : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEligibilityResultsSection() {
    if (_eligibilityResult == null) return const SizedBox.shrink();

    final isEligible = _eligibilityResult!['is_eligible'] as bool? ?? false;
    final checks = _eligibilityResult!['checks'] as Map<String, bool>? ?? {};
    final rejectionReason =
        _eligibilityResult!['rejection_reason'] as String? ?? '';

    return Card(
      elevation: 2,
      color: isEligible ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isEligible ? Icons.check_circle : Icons.cancel,
                  color:
                      isEligible ? Colors.green.shade700 : Colors.red.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  isEligible
                      ? 'Eligibility Check Passed'
                      : 'Eligibility Check Failed',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color:
                        isEligible
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildCheckItem('Status Check', checks['status'] ?? false),
            _buildCheckItem(
              'Academic Year Match',
              checks['academic_year'] ?? false,
            ),
            _buildCheckItem('Semester Match', checks['semester'] ?? false),
            _buildCheckItem('Name Match', checks['name'] ?? false),
            _buildCheckItem('Subjects Found', checks['subjects'] ?? false),
            _buildCheckItem('OCR Confidence', checks['confidence'] ?? false),
            if (!isEligible && rejectionReason.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Reason: $rejectionReason',
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String label, bool passed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check : Icons.close,
            color: passed ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: passed ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final isEligible = _eligibilityResult!['is_eligible'] as bool? ?? false;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isEligible && !_isProcessing ? _submitLoanApplication : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEligible ? evsuRed : Colors.grey,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child:
            _isProcessing
                ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Text(
                  isEligible
                      ? 'Submit Loan Application'
                      : 'Cannot Submit - Eligibility Failed',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _ocrData = null;
        _eligibilityResult = null;
      });
    }
  }

  Future<void> _processImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Step 1: Extract text using OCR
      final ocrText = await OCRService.extractTextFromImage(_selectedImage!);

      // Debug: Print OCR text to help troubleshoot
      print('DEBUG: OCR Text extracted (length: ${ocrText.length}):');
      print(ocrText.substring(0, ocrText.length > 500 ? 500 : ocrText.length));

      if (ocrText.isEmpty || ocrText.trim().length < 10) {
        throw Exception(
          'Could not extract text from image. Please ensure the image is clear and contains readable text.',
        );
      }

      // Step 2: Extract enrollment data from OCR text
      final ocrData = await OCRService.extractEnrollmentData(ocrText);

      // Step 2.5: Validate image format (check for links/URLs)
      if (ocrData['has_links'] == true) {
        final validationError =
            ocrData['validation_error'] as String? ??
            'Screenshot contains links or URLs. Please capture only the enrollment subjects section.';
        if (mounted) {
          await _showLinkErrorDialog(validationError);
          setState(() {
            _selectedImage = null;
            _ocrData = null;
            _eligibilityResult = null;
          });
        }
        return;
      }

      if (ocrData['validation_error']?.toString().isNotEmpty == true) {
        if (mounted) {
          await _showLinkErrorDialog(ocrData['validation_error'].toString());
          setState(() {
            _selectedImage = null;
            _ocrData = null;
            _eligibilityResult = null;
          });
        }
        return;
      }

      // Debug: Print extracted data
      print('DEBUG: Extracted OCR Data:');
      print('Name: ${ocrData['name']}');
      print('Status: ${ocrData['status']}');
      print('Academic Year: ${ocrData['academic_year']}');
      print('Semester: ${ocrData['semester']}');
      print('Subjects: ${ocrData['subjects']}');
      print('Confidence: ${ocrData['confidence']}');

      setState(() {
        _ocrData = ocrData;
      });

      // Step 3: Check eligibility
      final studentId = SessionService.currentUserStudentId;
      if (studentId.isEmpty) {
        throw Exception('Student ID not found');
      }

      final eligibilityResult = await LoanEligibilityService.checkEligibility(
        ocrData: ocrData,
        studentId: studentId,
      );

      setState(() {
        _eligibilityResult = eligibilityResult;
      });
    } catch (e) {
      print('ERROR: Image processing failed: $e');
      print('ERROR Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing image: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _submitLoanApplication() async {
    if (_selectedImage == null ||
        _ocrData == null ||
        _eligibilityResult == null) {
      return;
    }

    final isEligible = _eligibilityResult!['is_eligible'] as bool? ?? false;
    if (!isEligible) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot submit: Eligibility check failed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await SupabaseService.initialize();
      final studentId = SessionService.currentUserStudentId;
      final loanPlanId = widget.loanPlan['id'] as int;

      // Step 1: Upload image to Supabase storage
      final imageUrl = await LoanImageService.uploadLoanProofImage(
        _selectedImage!,
        studentId,
        loanPlanId,
      );

      // Step 2: Save loan application to database
      final applicationData = {
        'student_id': studentId,
        'loan_plan_id': loanPlanId,
        'ocr_name': _ocrData!['name']?.toString(),
        'ocr_status': _ocrData!['status']?.toString(),
        'ocr_academic_year': _ocrData!['academic_year']?.toString(),
        'ocr_semester': _ocrData!['semester']?.toString(),
        'ocr_subjects': (_ocrData!['subjects'] as List<dynamic>?)?.join(', '),
        'ocr_date': _ocrData!['date']?.toString(),
        'ocr_confidence': _ocrData!['confidence'],
        'ocr_raw_text': _ocrData!['raw_text']?.toString(),
        'upload_image_url': imageUrl,
        'decision': 'approved', // Auto-approved since eligibility passed
        'rejection_reason': null,
      };

      final insertResponse =
          await SupabaseService.client
              .from('loan_applications')
              .insert(applicationData)
              .select('id')
              .single();

      final applicationId = insertResponse['id'] as int;

      // Step 3: If approved, create the loan in active_loans and add to balance
      if (isEligible) {
        final response = await SupabaseService.client.rpc(
          'apply_for_loan_with_auto_approval',
          params: {
            'p_student_id': studentId,
            'p_loan_plan_id': loanPlanId,
            'p_application_id': applicationId,
          },
        );

        if (response != null && (response as Map)['success'] == true) {
          // Refresh user data to update balance
          await SessionService.refreshUserData();

          // Call callback to refresh active loans in parent widget
          widget.onLoanSubmitted?.call();

          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Loan application approved and processed successfully!',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Failed to process loan application');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting application: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _showLinkErrorDialog(String message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade700, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Invalid Screenshot Format',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.red.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red.shade900,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'What to do:',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildInstructionItem(
                        '✓ Capture ONLY the enrollment subjects section',
                      ),
                      _buildInstructionItem(
                        '✓ Include: Status, Academic Year, Semester, Subject codes',
                      ),
                      _buildInstructionItem(
                        '✗ Remove: Browser address bar, navigation menu, links',
                      ),
                      _buildInstructionItem(
                        '✗ Remove: Profile picture, bookmarks, other tabs',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'I Understand',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: evsuRed,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstructionItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 28),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade900,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
