// E-wallet Payment Configuration Screen
// Purpose: Admin can manage top-up amounts and QR codes for e-wallet payments
// Data is stored in top_up_qr table and images in E-wallet_QR storage bucket
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/supabase_service.dart';

class ApiConfigurationScreen extends StatefulWidget {
  const ApiConfigurationScreen({super.key});

  @override
  State<ApiConfigurationScreen> createState() => _ApiConfigurationScreenState();
}

class _ApiConfigurationScreenState extends State<ApiConfigurationScreen> {
  static const Color evsuRed = Color(0xFFB91C1C);

  // Controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // State variables
  bool _isLoading = false;
  List<Map<String, dynamic>> _topUpOptions = [];
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // Edit mode
  bool _isEditMode = false;
  int? _editingId;

  @override
  void initState() {
    super.initState();
    _loadTopUpOptions();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Load all top-up QR options from database
  Future<void> _loadTopUpOptions() async {
    setState(() => _isLoading = true);
    try {
      final response = await SupabaseService.adminClient
          .from('top_up_qr')
          .select('*')
          .order('amount', ascending: true);

      setState(() {
        _topUpOptions = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading top-up options: $e");
      final errorMessage = _getUserFriendlyErrorMessage(e);
      _showErrorDialog(errorMessage);
      setState(() => _isLoading = false);
    }
  }

  /// Pick image from gallery
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      final errorMessage = _getUserFriendlyErrorMessage(e);
      _showErrorDialog(errorMessage);
    }
  }

  /// Upload QR image to storage bucket
  Future<String?> _uploadQrImage(File imageFile, double amount) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileName =
          'qr_${amount.toStringAsFixed(0)}_${DateTime.now().millisecondsSinceEpoch}.png';

      await SupabaseService.adminClient.storage
          .from('E-wallet_QR')
          .uploadBinary(fileName, bytes);

      // Get public URL
      final publicUrl = SupabaseService.adminClient.storage
          .from('E-wallet_QR')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      print("Error uploading QR image: $e");
      final errorMessage = _getUserFriendlyErrorMessage(e);
      _showErrorDialog(errorMessage);
      return null;
    }
  }

  /// Delete QR image from storage
  Future<void> _deleteQrImage(String imageUrl) async {
    try {
      // Extract filename from URL
      // URL format: https://[project].supabase.co/storage/v1/object/public/E-wallet_QR/[filename]
      // or: E-wallet_QR/[filename]
      String fileName = '';

      if (imageUrl.contains('/storage/v1/object/public/')) {
        // Full URL format - extract path after 'E-wallet_QR' or 'E-wallet_QR'
        final parts = imageUrl.split('/storage/v1/object/public/');
        if (parts.length > 1) {
          final pathAfterBucket = parts[1];
          // Remove bucket name and get just the filename
          if (pathAfterBucket.startsWith('E-wallet_QR/')) {
            fileName = pathAfterBucket.replaceFirst('E-wallet_QR/', '');
          } else if (pathAfterBucket.startsWith('E-wallet%20QR/')) {
            fileName = pathAfterBucket.replaceFirst('E-wallet%20QR/', '');
          } else {
            // Try to find the filename directly
            final pathParts = pathAfterBucket.split('/');
            if (pathParts.length > 1) {
              fileName = pathParts.sublist(1).join('/');
            } else {
              fileName = pathParts.last;
            }
          }
        }
      } else if (imageUrl.contains('E-wallet_QR/') ||
          imageUrl.contains('E-wallet%20QR/')) {
        // Direct path format
        fileName = imageUrl
            .replaceFirst('E-wallet_QR/', '')
            .replaceFirst('E-wallet%20QR/', '');
      } else {
        // Assume it's just the filename
        fileName = imageUrl.split('/').last;
      }

      // Decode URL encoding if present
      fileName = Uri.decodeComponent(fileName);

      if (fileName.isNotEmpty) {
        print('DEBUG: Deleting QR image from storage: $fileName');
        await SupabaseService.adminClient.storage.from('E-wallet_QR').remove([
          fileName,
        ]);
        print('DEBUG: Successfully deleted QR image from storage');
      } else {
        print('WARNING: Could not extract file path from imageUrl: $imageUrl');
      }
    } catch (e) {
      print("Error deleting QR image: $e");
      rethrow; // Re-throw to allow caller to handle
    }
  }

  /// Save new top-up option
  Future<void> _saveTopUpOption() async {
    if (_amountController.text.isEmpty) {
      _showToast('Please enter an amount');
      return;
    }

    if (_selectedImage == null && !_isEditMode) {
      _showToast('Please select a QR code image');
      return;
    }

    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showToast('Please enter a valid amount');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? qrImageUrl;

      // Upload new image if selected
      if (_selectedImage != null) {
        qrImageUrl = await _uploadQrImage(_selectedImage!, amount);
        if (qrImageUrl == null) {
          setState(() => _isLoading = false);
          return;
        }
      }

      if (_isEditMode && _editingId != null) {
        // Update existing record
        final updateData = {
          'amount': amount,
          'description': _descriptionController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Only update image if new one was selected
        if (qrImageUrl != null) {
          // Delete old image from storage
          final oldOption = _topUpOptions.firstWhere(
            (o) => o['id'] == _editingId,
          );
          if (oldOption['qr_image_url'] != null &&
              oldOption['qr_image_url'].toString().isNotEmpty) {
            try {
              await _deleteQrImage(oldOption['qr_image_url'].toString());
              print('DEBUG: Successfully deleted old QR image from storage');
            } catch (storageError) {
              print('WARNING: Failed to delete old QR image: $storageError');
              // Continue with update even if old image deletion fails
            }
          }
          updateData['qr_image_url'] = qrImageUrl;
        }

        await SupabaseService.adminClient
            .from('top_up_qr')
            .update(updateData)
            .eq('id', _editingId!);

        _showToast('Top-up option updated successfully');
      } else {
        // Insert new record
        await SupabaseService.adminClient.from('top_up_qr').insert({
          'amount': amount,
          'description': _descriptionController.text.trim(),
          'qr_image_url': qrImageUrl,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
        });

        _showToast('Top-up option added successfully');
      }

      // Clear form and reload
      _clearForm();
      await _loadTopUpOptions();
    } catch (e) {
      print("Error saving top-up option: $e");
      final errorMessage = _getUserFriendlyErrorMessage(e);
      _showErrorDialog(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Delete top-up option
  Future<void> _deleteTopUpOption(int id, String? imageUrl) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Top-Up Option'),
            content: const Text(
              'Are you sure you want to delete this top-up option?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      // Delete image from storage bucket first
      if (imageUrl != null && imageUrl.toString().isNotEmpty) {
        try {
          await _deleteQrImage(imageUrl.toString());
          print('DEBUG: Successfully deleted QR image from storage');
        } catch (storageError) {
          print(
            'WARNING: Failed to delete QR image from storage: $storageError',
          );
          // Continue with database deletion even if storage deletion fails
        }
      }

      // Delete record from database
      await SupabaseService.adminClient.from('top_up_qr').delete().eq('id', id);

      _showToast('Top-up option deleted successfully');
      await _loadTopUpOptions();
    } catch (e) {
      print("Error deleting top-up option: $e");
      final errorMessage = _getUserFriendlyErrorMessage(e);
      _showErrorDialog(errorMessage);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Edit top-up option
  void _editTopUpOption(Map<String, dynamic> option) {
    setState(() {
      _isEditMode = true;
      _editingId = option['id'];
      _amountController.text = option['amount'].toString();
      _descriptionController.text = option['description']?.toString() ?? '';
      // Don't set _selectedImage here - user can choose to keep existing or change
      // The form will show "Tap to change QR code image" when in edit mode
      _selectedImage = null;
    });

    // Scroll to top to show the form
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 300),
      );
    });
  }

  /// Clear form
  void _clearForm() {
    setState(() {
      _amountController.clear();
      _descriptionController.clear();
      _selectedImage = null;
      _isEditMode = false;
      _editingId = null;
    });
  }

  /// Toggle active status
  Future<void> _toggleActiveStatus(int id, bool currentStatus) async {
    try {
      await SupabaseService.adminClient
          .from('top_up_qr')
          .update({
            'is_active': !currentStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      await _loadTopUpOptions();
    } catch (e) {
      final errorMessage = _getUserFriendlyErrorMessage(e);
      _showErrorDialog(errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'E-wallet Payment Configuration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: evsuRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeaderCard(),
                    const SizedBox(height: 24),
                    _buildAddEditForm(),
                    const SizedBox(height: 24),
                    _buildTopUpOptionsList(),
                  ],
                ),
              ),
    );
  }

  Widget _buildHeaderCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isSmallPhone = screenWidth < 360;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [evsuRed, evsuRed.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: evsuRed.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 6 : 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.qr_code,
                  color: Colors.white,
                  size: isMobile ? 20 : 24,
                ),
              ),
              SizedBox(width: isMobile ? 8 : 12),
              Expanded(
                child: Text(
                  'E-wallet Top-Up Management',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isSmallPhone ? 16 : (isMobile ? 18 : 20),
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            'Manage QR codes for different top-up amounts. Students will see these options when they want to top up their balance.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: isMobile ? 13 : 14,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isMobile ? 10 : 12),
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white70,
                  size: isMobile ? 18 : 20,
                ),
                SizedBox(width: isMobile ? 6 : 8),
                Expanded(
                  child: Text(
                    'Total Options: ${_topUpOptions.length} | Active: ${_topUpOptions.where((o) => o['is_active'] == true).length}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isMobile ? 12 : 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddEditForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _isEditMode ? 'Edit Top-Up Option' : 'Add New Top-Up Option',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                if (_isEditMode)
                  TextButton.icon(
                    onPressed: _clearForm,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Amount Field
            const Text(
              'Top-Up Amount (₱)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                hintText: 'Enter amount (e.g., 100.00)',
                prefixIcon: const Icon(Icons.attach_money, color: evsuRed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: evsuRed, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Description Field
            const Text(
              'Description (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                hintText: 'e.g., Recommended for students',
                prefixIcon: const Icon(Icons.description, color: evsuRed),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: evsuRed, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // QR Code Image
            const Text(
              'QR Code Image',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),

            if (_selectedImage != null)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        width: double.infinity,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        onPressed: () => setState(() => _selectedImage = null),
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_isEditMode && _editingId != null)
              // Show current image when editing
              Builder(
                builder: (context) {
                  final currentOption = _topUpOptions.firstWhere(
                    (o) => o['id'] == _editingId,
                    orElse: () => <String, dynamic>{},
                  );
                  final currentImageUrl = currentOption['qr_image_url'];

                  if (currentImageUrl != null &&
                      currentImageUrl.toString().isNotEmpty) {
                    return GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                currentImageUrl.toString(),
                                width: double.infinity,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[100],
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.broken_image,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Failed to load image',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: const BorderRadius.only(
                                    bottomLeft: Radius.circular(8),
                                    bottomRight: Radius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Tap to change QR code image',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        height: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_2,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No QR image - Tap to upload',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                },
              )
            else
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to upload QR code image',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveTopUpOption,
                icon: Icon(_isEditMode ? Icons.save : Icons.add),
                label: Text(_isEditMode ? 'Update Option' : 'Add Option'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: evsuRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopUpOptionsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Existing Top-Up Options',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),

            if (_topUpOptions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No top-up options yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first top-up option above',
                        style: TextStyle(color: Colors.grey[500], fontSize: 14),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _topUpOptions.length,
                itemBuilder: (context, index) {
                  final option = _topUpOptions[index];
                  return _buildTopUpOptionCard(option);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopUpOptionCard(Map<String, dynamic> option) {
    final amount = (option['amount'] as num).toDouble();
    final isActive = option['is_active'] ?? true;
    final qrImageUrl = option['qr_image_url'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? evsuRed.withOpacity(0.3) : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          // QR Code Image
          if (qrImageUrl != null)
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  qrImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.broken_image, color: Colors.grey[400]);
                  },
                ),
              ),
            )
          else
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.qr_code, color: Colors.grey[400], size: 40),
            ),

          const SizedBox(width: 16),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '₱${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isActive ? evsuRed : Colors.grey,
                  ),
                ),
                if (option['description'] != null &&
                    option['description'].toString().isNotEmpty)
                  Text(
                    option['description'],
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green[50] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isActive ? Colors.green[700] : Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Actions
          Column(
            children: [
              IconButton(
                onPressed: () => _toggleActiveStatus(option['id'], isActive),
                icon: Icon(
                  isActive ? Icons.visibility : Icons.visibility_off,
                  color: isActive ? Colors.green : Colors.grey,
                ),
                tooltip: isActive ? 'Deactivate' : 'Activate',
              ),
              IconButton(
                onPressed: () => _editTopUpOption(option),
                icon: const Icon(Icons.edit, color: Colors.blue),
                tooltip: 'Edit',
              ),
              IconButton(
                onPressed: () => _deleteTopUpOption(option['id'], qrImageUrl),
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Get user-friendly error message from exception
  String _getUserFriendlyErrorMessage(dynamic error) {
    // Check for SocketException (no internet connection)
    if (error is SocketException) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Convert error to string for pattern matching
    final errorString = error.toString().toLowerCase();
    
    // Check for ClientException with SocketException (common network error pattern)
    if (errorString.contains('clientexception') && 
        (errorString.contains('socketexception') ||
         errorString.contains('failed host lookup') ||
         errorString.contains('network is unreachable'))) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Check for SocketException patterns in error string
    if (errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('no internet') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timed out')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Check for timeout errors
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return 'Request timed out. Please check your connection and try again.';
    }

    // Check for ClientException (general network errors)
    if (errorString.contains('clientexception')) {
      return 'Network error. Please check your connection and try again.';
    }

    // Check for Supabase-specific errors
    if (errorString.contains('postgres') || errorString.contains('database')) {
      return 'Database error. Please try again later.';
    }

    // Default error message
    return 'An error occurred. Please try again.';
  }

  /// Show error dialog with user-friendly message
  void _showErrorDialog(String message) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red.shade700,
              size: isMobile ? 24 : 28,
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Expanded(
              child: Text(
                'Error',
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? MediaQuery.of(context).size.width * 0.8 : 400,
          ),
          child: SingleChildScrollView(
            child: Text(
              message,
              style: TextStyle(fontSize: isMobile ? 14 : 16),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: evsuRed,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : 24,
                vertical: isMobile ? 10 : 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'OK',
              style: TextStyle(fontSize: isMobile ? 14 : 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: evsuRed,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
