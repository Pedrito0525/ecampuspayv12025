import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';

class SecurityPrivacyScreen extends StatefulWidget {
  const SecurityPrivacyScreen({super.key});

  @override
  State<SecurityPrivacyScreen> createState() => _SecurityPrivacyScreenState();
}

class _SecurityPrivacyScreenState extends State<SecurityPrivacyScreen> {
  static const Color evsuRed = Color(0xFFB91C1C);

  // State variables for security settings
  bool _tapToPayEnabled = true;
  bool _isLoading = false;

  // Password change form controllers
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isChangingPassword = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _loadTapToPayStatus();
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Security & Privacy',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: evsuRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Security Section
            _buildSecuritySection('Payment Security', [
              _SecurityItem(
                icon: Icons.tap_and_play,
                title: 'Tap to Pay',
                subtitle: 'Enable quick payments with RFID tap',
                isSwitch: true,
                value: _tapToPayEnabled,
                onChanged: (value) => _toggleTapToPay(value),
                isLoading: _isLoading,
              ),
            ]),

            const SizedBox(height: 24),

            // Account Security Section
            _buildSecuritySection('Account Security', [
              _SecurityItem(
                icon: Icons.lock_outline,
                title: 'Change Password',
                subtitle: 'Update your account password',
                onTap: () => _showChangePasswordDialog(),
              ),
            ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection(String title, List<_SecurityItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        Container(
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
          child: Column(
            children:
                items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Column(
                    children: [
                      _buildSecurityItem(item),
                      if (index < items.length - 1)
                        Divider(height: 1, color: Colors.grey[200]),
                    ],
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityItem(_SecurityItem item) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: evsuRed.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(item.icon, color: evsuRed, size: 22),
      ),
      title: Text(
        item.title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      subtitle: Text(
        item.subtitle,
        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
      ),
      trailing:
          item.isSwitch
              ? item.isLoading ?? false
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(evsuRed),
                    ),
                  )
                  : Switch(
                    value: item.value ?? false,
                    onChanged: item.onChanged,
                    activeColor: evsuRed,
                  )
              : const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Colors.grey,
              ),
      onTap: item.isSwitch ? null : item.onTap,
    );
  }

  void _toggleTapToPay(bool value) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Update the taptopay status in the database
      final result = await SupabaseService.updateTapToPayStatus(
        studentId: SessionService.currentUserStudentId,
        enabled: value,
      );

      if (result['success']) {
        setState(() {
          _tapToPayEnabled = value;
        });
        _showTapToPayConfirmation(value);
      } else {
        _showErrorSnackBar(
          result['message'] ?? 'Failed to update tap to pay status',
        );
      }
    } catch (e) {
      _showErrorSnackBar('Error updating tap to pay: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showTapToPayConfirmation(bool enabled) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Tap to Pay has been enabled. You can now make quick payments with RFID tap.'
              : 'Tap to Pay has been disabled. RFID tap payments are no longer available.',
        ),
        backgroundColor: enabled ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadTapToPayStatus() async {
    try {
      final result = await SupabaseService.getTapToPayStatus(
        studentId: SessionService.currentUserStudentId,
      );

      if (result['success']) {
        setState(() {
          _tapToPayEnabled = result['data']['taptopay'] ?? true;
        });
      }
    } catch (e) {
      print('Error loading tap to pay status: $e');
      // Keep default value if loading fails
    }
  }

  void _showChangePasswordDialog() {
    // Clear form fields
    _currentPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _showCurrentPassword = false;
    _showNewPassword = false;
    _showConfirmPassword = false;

    // Check if it's a very small screen (phone)
    final isSmallScreen = MediaQuery.of(context).size.height < 600;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) =>
                    isSmallScreen
                        ? _buildFullScreenDialog(setDialogState)
                        : Dialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.8,
                              maxWidth: MediaQuery.of(context).size.width * 0.9,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Header
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: const BoxDecoration(
                                    color: evsuRed,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(16),
                                      topRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.lock_outline,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                        child: Text(
                                          'Change Password',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed:
                                            _isChangingPassword
                                                ? null
                                                : () => Navigator.pop(context),
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ),

                                // Content
                                Flexible(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Enter your current password and choose a new password.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(height: 24),

                                        // Current Password Field
                                        _buildPasswordField(
                                          controller:
                                              _currentPasswordController,
                                          label: 'Current Password',
                                          isVisible: _showCurrentPassword,
                                          onToggleVisibility: () {
                                            setDialogState(() {
                                              _showCurrentPassword =
                                                  !_showCurrentPassword;
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 20),

                                        // New Password Field
                                        _buildPasswordField(
                                          controller: _newPasswordController,
                                          label: 'New Password',
                                          isVisible: _showNewPassword,
                                          onToggleVisibility: () {
                                            setDialogState(() {
                                              _showNewPassword =
                                                  !_showNewPassword;
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 20),

                                        // Confirm Password Field
                                        _buildPasswordField(
                                          controller:
                                              _confirmPasswordController,
                                          label: 'Confirm New Password',
                                          isVisible: _showConfirmPassword,
                                          onToggleVisibility: () {
                                            setDialogState(() {
                                              _showConfirmPassword =
                                                  !_showConfirmPassword;
                                            });
                                          },
                                        ),
                                        const SizedBox(height: 16),

                                        // Password Requirements
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.blue.shade200,
                                            ),
                                          ),
                                          child: const Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Password Requirements:',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                '• At least 6 characters long\n• Mix of letters and numbers recommended',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.blue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Actions
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade50,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed:
                                              _isChangingPassword
                                                  ? null
                                                  : () =>
                                                      Navigator.pop(context),
                                          style: OutlinedButton.styleFrom(
                                            side: const BorderSide(
                                              color: evsuRed,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: const Text(
                                            'Cancel',
                                            style: TextStyle(color: evsuRed),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed:
                                              _isChangingPassword
                                                  ? null
                                                  : () => _changePassword(
                                                    setDialogState,
                                                  ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: evsuRed,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child:
                                              _isChangingPassword
                                                  ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          color: Colors.white,
                                                          strokeWidth: 2,
                                                        ),
                                                  )
                                                  : const Text(
                                                    'Change Password',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
          ),
    );
  }

  Widget _buildFullScreenDialog(StateSetter setDialogState) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Change Password'),
        backgroundColor: evsuRed,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: _isChangingPassword ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your current password and choose a new password.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Current Password Field
            _buildPasswordField(
              controller: _currentPasswordController,
              label: 'Current Password',
              isVisible: _showCurrentPassword,
              onToggleVisibility: () {
                setDialogState(() {
                  _showCurrentPassword = !_showCurrentPassword;
                });
              },
            ),
            const SizedBox(height: 24),

            // New Password Field
            _buildPasswordField(
              controller: _newPasswordController,
              label: 'New Password',
              isVisible: _showNewPassword,
              onToggleVisibility: () {
                setDialogState(() {
                  _showNewPassword = !_showNewPassword;
                });
              },
            ),
            const SizedBox(height: 24),

            // Confirm Password Field
            _buildPasswordField(
              controller: _confirmPasswordController,
              label: 'Confirm New Password',
              isVisible: _showConfirmPassword,
              onToggleVisibility: () {
                setDialogState(() {
                  _showConfirmPassword = !_showConfirmPassword;
                });
              },
            ),
            const SizedBox(height: 20),

            // Password Requirements
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Password Requirements:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• At least 6 characters long\n• Mix of letters and numbers recommended',
                    style: TextStyle(fontSize: 13, color: Colors.blue),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isChangingPassword
                            ? null
                            : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: evsuRed),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: evsuRed, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _isChangingPassword
                            ? null
                            : () => _changePassword(setDialogState),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: evsuRed,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isChangingPassword
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Change Password',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: !isVisible,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Enter $label',
            hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: evsuRed,
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility_off : Icons.visibility,
                color: evsuRed,
                size: 20,
              ),
              onPressed: onToggleVisibility,
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: evsuRed, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Future<void> _changePassword(StateSetter setDialogState) async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // Validation
    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showErrorSnackBar('Please fill in all fields');
      return;
    }

    if (newPassword.length < 6) {
      _showErrorSnackBar('New password must be at least 6 characters long');
      return;
    }

    if (newPassword != confirmPassword) {
      _showErrorSnackBar('New password and confirm password do not match');
      return;
    }

    if (currentPassword == newPassword) {
      _showErrorSnackBar(
        'New password must be different from current password',
      );
      return;
    }

    setDialogState(() {
      _isChangingPassword = true;
    });

    try {
      // Get current user student ID
      final currentUserStudentId = SessionService.currentUserStudentId;
      if (currentUserStudentId.isEmpty) {
        throw Exception('User student ID not found. Please log in again.');
      }

      // Update password
      final result = await SupabaseService.updateUserPassword(
        studentId: currentUserStudentId,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      setDialogState(() {
        _isChangingPassword = false;
      });

      if (result['success']) {
        // Refresh user session data to ensure it's up to date
        try {
          await SessionService.refreshUserData();
        } catch (e) {
          print(
            'Warning: Failed to refresh user data after password change: $e',
          );
          // Not critical - password is updated, user can continue
        }

        Navigator.pop(context); // Close dialog
        _showSuccessSnackBar(
          'Password changed successfully! Your session has been updated.',
        );

        // Clear form
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        _showErrorSnackBar(result['message'] ?? 'Failed to change password');
      }
    } catch (e) {
      setDialogState(() {
        _isChangingPassword = false;
      });
      _showErrorSnackBar('Error: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class _SecurityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSwitch;
  final bool? value;
  final Function(bool)? onChanged;
  final VoidCallback? onTap;
  final bool? isLoading;

  _SecurityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isSwitch = false,
    this.value,
    this.onChanged,
    this.onTap,
    this.isLoading,
  });
}
