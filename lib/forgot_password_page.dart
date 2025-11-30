import 'package:flutter/material.dart';
import 'services/supabase_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController codeController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  bool isLoading = false;
  bool otpSent = false;
  bool otpVerified = false;

  @override
  void dispose() {
    emailController.dispose();
    codeController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  /// Send OTP code to user's email
  Future<void> _sendOTP() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showErrorDialog('Please enter your email address');
      return;
    }

    // Check if it's an EVSU email (for students) or any email (for service accounts)
    final isEvsuEmail = _isValidEvsuEmail(email);

    if (!isEvsuEmail) {
      // For non-EVSU emails, try service account first
      // If it fails, show error
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Try service account first (works for any email)
      var result = await SupabaseService.sendServiceAccountPasswordResetOTP(
        email: email,
      );

      // If service account fails and it's an EVSU email, try student account
      if (!result['success'] && isEvsuEmail) {
        result = await SupabaseService.sendPasswordResetOTP(email: email);
      }

      if (result['success']) {
        setState(() {
          otpSent = true;
          isLoading = false;
        });

        _showSuccessDialog(
          'OTP Code Sent',
          'A verification code has been sent to your email address. Please check your inbox and enter the code below.',
        );
      } else {
        setState(() {
          isLoading = false;
        });
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('Failed to send OTP. Please try again later.');
    }
  }

  /// Verify OTP code
  Future<void> _verifyOTP() async {
    final email = emailController.text.trim();
    final otpCode = codeController.text.trim();

    if (otpCode.isEmpty) {
      _showErrorDialog('Please enter the verification code from your email');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Try service account first
      var result = await SupabaseService.verifyServiceAccountPasswordResetOTP(
        email: email,
        otpCode: otpCode,
      );

      // If service account fails and it's an EVSU email, try student account
      if (!result['success'] && _isValidEvsuEmail(email)) {
        result = await SupabaseService.verifyPasswordResetOTP(
          email: email,
          otpCode: otpCode,
        );
      }

      if (result['success']) {
        setState(() {
          otpVerified = true;
          isLoading = false;
        });

        _showSuccessDialog(
          'OTP Verified',
          'Your OTP code has been verified successfully. You can now set your new password.',
        );
      } else {
        setState(() {
          isLoading = false;
        });
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('Failed to verify OTP. Please try again.');
    }
  }

  /// Reset password using the recovery session from verified OTP
  /// Note: OTP must be verified first (otpVerified must be true)
  Future<void> _resetPassword() async {
    // Ensure OTP was verified before allowing password reset
    if (!otpVerified) {
      _showErrorDialog(
        'Please verify the code first before setting a new password.',
      );
      return;
    }

    final email = emailController.text.trim();
    final newPassword = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showErrorDialog('Please enter and confirm your new password');
      return;
    }

    if (newPassword != confirmPassword) {
      _showErrorDialog('Passwords do not match. Please try again.');
      return;
    }

    if (newPassword.length < 6) {
      _showErrorDialog('Password must be at least 6 characters long');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Code is not needed here - recovery session was established during verification
      // Try service account first
      var result = await SupabaseService.resetServiceAccountPasswordWithOTP(
        email: email,
        newPassword: newPassword,
      );

      // If service account fails and it's an EVSU email, try student account
      if (!result['success'] && _isValidEvsuEmail(email)) {
        result = await SupabaseService.resetPasswordWithOTP(
          email: email,
          newPassword: newPassword,
        );
      }

      if (result['success']) {
        setState(() {
          isLoading = false;
        });

        _showPasswordResetSuccessDialog();
      } else {
        setState(() {
          isLoading = false;
        });
        _showErrorDialog(result['message']);
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorDialog('Failed to reset password. Please try again.');
    }
  }

  /// Validate EVSU email format
  bool _isValidEvsuEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@evsu\.edu\.ph$',
    ).hasMatch(email.toLowerCase());
  }

  /// Show error dialog
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Error'),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  /// Show success dialog
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 8),
                Text(title),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  /// Show password reset success dialog
  void _showPasswordResetSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Title
                  Text(
                    'Password Reset',
                    style: TextStyle(
                      fontSize:
                          MediaQuery.of(context).size.width < 400 ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF333333),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Message
                  Flexible(
                    child: Text(
                      'Your password has been reset successfully! You can now login with your new password.',
                      style: TextStyle(
                        fontSize:
                            MediaQuery.of(context).size.width < 400 ? 14 : 16,
                        color: const Color(0xFF666666),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.06,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close dialog
                        Navigator.pop(context); // Go back to login page
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB01212),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        'Go to Login',
                        style: TextStyle(
                          fontSize:
                              MediaQuery.of(context).size.width < 400 ? 14 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  /// Reset the form
  void _resetForm() {
    setState(() {
      otpSent = false;
      otpVerified = false;
      emailController.clear();
      codeController.clear();
      passwordController.clear();
      confirmPasswordController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color evsuRed = Color(0xFFB01212);
    // Footer size: make it larger (~40% of screen width) and shaped with a wide curve
    final double _footerHeight = MediaQuery.of(context).size.width * 0.40;
    final double _curveDepth = _footerHeight * 0.6; // tall, smooth curve

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset:
          false, // Prevents keyboard from affecting bottom element
      body: Stack(
        children: [
          // Main content with proper bottom padding
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    const Text(
                      'Forgot Password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: evsuRed,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Email
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 14,
                          color: evsuRed.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      enabled: !otpSent,
                      decoration: InputDecoration(
                        hintText: 'Enter your email address',
                        prefixIcon: const Icon(Icons.email, color: evsuRed),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(
                            color: evsuRed,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: evsuRed),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Get OTP Button (only show if OTP not sent)
                    if (!otpSent) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _sendOTP,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: evsuRed,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text(
                                    'Get OTP Code',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                        ),
                      ),
                    ],

                    // OTP Code Field (only show if OTP sent)
                    if (otpSent) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Verification Code',
                          style: TextStyle(
                            fontSize: 14,
                            color: evsuRed.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        enabled: !otpVerified,
                        decoration: InputDecoration(
                          hintText: 'Enter the code from your email',
                          prefixIcon: const Icon(
                            Icons.verified,
                            color: evsuRed,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: evsuRed,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: evsuRed),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Verify OTP Button (only show if OTP sent but not verified)
                      if (!otpVerified) ...[
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _verifyOTP,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child:
                                isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Text(
                                      'Verify OTP',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ],

                    // Password Fields (only show if OTP verified)
                    if (otpVerified) ...[
                      // New Password
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'New Password',
                          style: TextStyle(
                            fontSize: 14,
                            color: evsuRed.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: passwordController,
                        obscureText: !isPasswordVisible,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: 'Enter new password',
                          prefixIcon: const Icon(Icons.lock, color: evsuRed),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: evsuRed,
                            ),
                            onPressed: () {
                              setState(
                                () => isPasswordVisible = !isPasswordVisible,
                              );
                            },
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: evsuRed,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: evsuRed),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Confirm Password
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Confirm Password',
                          style: TextStyle(
                            fontSize: 14,
                            color: evsuRed.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: !isConfirmPasswordVisible,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          hintText: 'Re-enter new password',
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: evsuRed,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              isConfirmPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: evsuRed,
                            ),
                            onPressed: () {
                              setState(
                                () =>
                                    isConfirmPasswordVisible =
                                        !isConfirmPasswordVisible,
                              );
                            },
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(
                              color: evsuRed,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: evsuRed),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Confirm Password Reset Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _resetPassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child:
                              isLoading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text(
                                    'Confirm & Reset Password',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Action Buttons
                    Row(
                      children: [
                        if (otpSent || otpVerified) ...[
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: evsuRed,
                                side: const BorderSide(
                                  color: evsuRed,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: _resetForm,
                              child: const Text(
                                'Start Over',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                        ],
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: evsuRed,
                              side: const BorderSide(color: evsuRed, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom decorative bump - positioned to stick to actual bottom including system areas
          // Footer is now provided by Scaffold.bottomNavigationBar
        ],
      ),
      bottomNavigationBar: ClipPath(
        clipper: _BottomCurveClipper(curveDepth: _curveDepth),
        child: Container(
          height: _footerHeight + MediaQuery.of(context).padding.bottom,
          color: evsuRed,
        ),
      ),
    );
  }
}

class _BottomCurveClipper extends CustomClipper<Path> {
  _BottomCurveClipper({required this.curveDepth});

  final double curveDepth;

  @override
  Path getClip(Size size) {
    final Path path = Path();

    // Start from bottom-left
    path.moveTo(0, size.height);
    // Left edge up to start of curved top edge
    path.lineTo(0, size.height - curveDepth);
    // Draw a wide upward curve across the top of the footer
    path.quadraticBezierTo(
      size.width / 2,
      size.height - curveDepth - (curveDepth * 0.8),
      size.width,
      size.height - curveDepth,
    );
    // Right edge down to bottom-right
    path.lineTo(size.width, size.height);
    // Close back to start
    path.close();

    return path;
  }

  @override
  bool shouldReclip(_BottomCurveClipper oldClipper) {
    return oldClipper.curveDepth != curveDepth;
  }
}
