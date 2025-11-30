import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';

class ServiceWithdrawScreen extends StatefulWidget {
  const ServiceWithdrawScreen({Key? key}) : super(key: key);

  @override
  State<ServiceWithdrawScreen> createState() => _ServiceWithdrawScreenState();
}

class _ServiceWithdrawScreenState extends State<ServiceWithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isProcessing = false;
  double _currentBalance = 0.0;

  static const Color evsuRed = Color(0xFFB91C1C);
  static const Color evsuRedDark = Color(0xFF7F1D1D);

  @override
  void initState() {
    super.initState();
    _loadCurrentBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentBalance() async {
    try {
      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString();
      if (serviceIdStr == null || serviceIdStr.isEmpty) {
        print('DEBUG ServiceWithdraw: service_id not found in session');
        return;
      }

      final serviceId = int.tryParse(serviceIdStr);
      if (serviceId == null) {
        print('DEBUG ServiceWithdraw: invalid service_id: $serviceIdStr');
        return;
      }

      // Fetch balance directly from database
      final row =
          await SupabaseService.client
              .from('service_accounts')
              .select('balance')
              .eq('id', serviceId)
              .maybeSingle();

      if (row != null) {
        final balance = double.tryParse(row['balance']?.toString() ?? '0');
        if (balance != null) {
          setState(() {
            _currentBalance = balance;
          });
          // Also update session data for consistency
          if (SessionService.currentUserData != null) {
            SessionService.currentUserData!['balance'] = balance.toString();
          }
        }
      } else {
        print('DEBUG ServiceWithdraw: service account not found in database');
      }
    } catch (e) {
      print('DEBUG ServiceWithdraw: error loading balance: $e');
      // Fallback to session data if available
      final balance = SessionService.currentUserData?['balance'];
      if (balance != null) {
        setState(() {
          _currentBalance = (balance as num).toDouble();
        });
      }
    }
  }

  /// Check if current time is within working hours (8am-5pm PH time)
  bool _isWithinWorkingHours() {
    // Get current time in PH timezone (UTC+8)
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final currentHour = now.hour;

    // Working hours: 8am (8) to 5pm (17)
    return currentHour >= 8 && currentHour < 17;
  }

  Future<void> _processWithdrawal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check if within working hours
    if (!_isWithinWorkingHours()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Withdrawals are only available during working hours (8:00 AM - 5:00 PM PH time)',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final serviceIdStr =
          SessionService.currentUserData?['service_id']?.toString();

      if (serviceIdStr == null || serviceIdStr.isEmpty) {
        throw Exception('Service account ID not found in session');
      }

      final serviceId = int.tryParse(serviceIdStr);
      if (serviceId == null) {
        throw Exception('Invalid service account ID');
      }

      final amount = double.parse(_amountController.text);

      // Create withdrawal request instead of direct withdrawal
      final result = await SupabaseService.createServiceWithdrawalRequest(
        serviceAccountId: serviceId,
        amount: amount,
      );

      setState(() {
        _isProcessing = false;
      });

      if (result['success'] == true) {
        if (mounted) {
          // Show success modal dialog
          await _showSuccessDialog(
            result['message'] ?? 'Withdrawal request submitted successfully',
            amount,
          );

          // Return true to indicate successful request submission
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          // Show error modal dialog
          await _showErrorDialog(
            result['message'] ?? 'Failed to submit withdrawal request',
          );
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        // Show error modal dialog
        await _showErrorDialog('Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWeb = screenWidth > 600;
    final horizontalPadding = isWeb ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Withdraw to Admin',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: evsuRed,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(horizontalPadding),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Current Balance Card
              _buildBalanceCard(),

              const SizedBox(height: 24),

              // Destination Info Card
              _buildDestinationInfoCard(),

              const SizedBox(height: 24),

              // Amount Input
              _buildAmountInput(),

              const SizedBox(height: 24),

              // Information Card
              _buildInformationCard(),

              const SizedBox(height: 32),

              // Submit Button
              _buildSubmitButton(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [evsuRed, evsuRedDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: evsuRed.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Available Balance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₱${_currentBalance.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: evsuRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: evsuRed,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Withdraw to Admin',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Cash out your service balance',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Withdrawal Amount',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
            prefixText: '₱ ',
            hintText: '0.00',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: evsuRed, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter an amount';
            }
            final amount = double.tryParse(value);
            if (amount == null || amount <= 0) {
              return 'Please enter a valid amount';
            }
            if (amount > _currentBalance) {
              return 'Insufficient balance';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildInformationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Information',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[900],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Withdrawals are only available during working hours (8:00 AM - 5:00 PM PH time).\n'
                  '• Service accounts can only withdraw to Admin.\n'
                  '• Your withdrawal request will be reviewed by admin.\n'
                  '• The amount will be deducted from your balance once approved.\n'
                  '• Admin balance will NOT increase (cash out).\n'
                  '• Please visit the Admin office to collect your withdrawal after approval.\n'
                  '• You will be notified once your request is processed.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[900],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isProcessing ? null : _processWithdrawal,
      style: ElevatedButton.styleFrom(
        backgroundColor: evsuRed,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child:
          _isProcessing
              ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
              : const Text(
                'Submit Withdrawal Request',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
    );
  }

  /// Show success dialog modal
  Future<void> _showSuccessDialog(String message, double amount) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Request Submitted',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.green.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Withdrawal Amount',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₱${amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.green.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your withdrawal request is pending admin approval. You will be notified once it is processed.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: evsuRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show error dialog modal
  Future<void> _showErrorDialog(String message) async {
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.red.shade700,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Request Failed',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: const TextStyle(fontSize: 15)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Please check your balance and try again. If the problem persists, contact admin support.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                            height: 1.4,
                          ),
                        ),
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
                'Close',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: evsuRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}
