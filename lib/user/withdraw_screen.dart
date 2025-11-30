import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({Key? key}) : super(key: key);

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _gcashNumberController = TextEditingController();
  final TextEditingController _gcashAccountNameController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _selectedDestinationType = 'admin'; // 'admin' or 'service'
  String _selectedTransferType =
      'Cash'; // 'Gcash' or 'Cash' (for admin withdrawal)
  int? _selectedServiceId;
  String? _selectedServiceName;
  List<Map<String, dynamic>> _serviceAccounts = [];
  bool _isLoading = false;
  bool _isProcessing = false;
  double _currentBalance = 0.0;

  static const Color evsuRed = Color(0xFFB91C1C);
  static const Color evsuRedDark = Color(0xFF7F1D1D);

  @override
  void initState() {
    super.initState();
    _loadServiceAccounts();
    _loadCurrentBalance();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _gcashNumberController.dispose();
    _gcashAccountNameController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentBalance() async {
    final balance = SessionService.currentUserData?['balance'];
    if (balance != null) {
      setState(() {
        _currentBalance = (balance as num).toDouble();
      });
    }
  }

  Future<void> _loadServiceAccounts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await SupabaseService.getAllServiceAccounts();

      if (result['success'] == true && result['data'] != null) {
        // Filter to only show Vendor accounts (exclude Campus Service Units and School Org)
        final allAccounts = List<Map<String, dynamic>>.from(result['data']);
        final vendorAccounts =
            allAccounts.where((service) {
              final serviceCategory =
                  service['service_category']?.toString() ?? '';
              // Only allow Vendor category for withdrawals/transfers
              return serviceCategory == 'Vendor';
            }).toList();

        setState(() {
          _serviceAccounts = vendorAccounts;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'Failed to load service accounts',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _processWithdrawal() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate service selection if withdrawing to service
    if (_selectedDestinationType == 'service' && _selectedServiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a vendor account'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final studentId =
          SessionService.currentUserData?['student_id']?.toString();

      if (studentId == null) {
        throw Exception('Student ID not found in session');
      }

      final amount = double.parse(_amountController.text);

      Map<String, dynamic> result;

      if (_selectedDestinationType == 'admin') {
        // Create withdrawal request (pending admin approval)
        result = await SupabaseService.createWithdrawalRequest(
          studentId: studentId,
          amount: amount,
          transferType: _selectedTransferType,
          gcashNumber:
              _selectedTransferType == 'Gcash'
                  ? _gcashNumberController.text.trim()
                  : null,
          gcashAccountName:
              _selectedTransferType == 'Gcash'
                  ? _gcashAccountNameController.text.trim()
                  : null,
        );
      } else {
        // Process immediate withdrawal to service (existing flow)
        result = await SupabaseService.processUserWithdrawal(
          studentId: studentId,
          amount: amount,
          destinationType: _selectedDestinationType,
          destinationServiceId: _selectedServiceId,
          destinationServiceName: _selectedServiceName,
        );
      }

      setState(() {
        _isProcessing = false;
      });

      if (result['success'] == true) {
        // Update session balance only if it was an immediate withdrawal (service)
        if (_selectedDestinationType == 'service') {
          await SessionService.refreshUserData();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ??
                    (_selectedDestinationType == 'admin'
                        ? 'Withdrawal request submitted successfully'
                        : 'Withdrawal successful'),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );

          // Return true to indicate successful withdrawal/request
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Withdrawal failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
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
          'Withdraw Funds',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: evsuRed,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
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

                      // Amount Input
                      _buildAmountInput(),

                      const SizedBox(height: 24),

                      // Destination Selection
                      _buildDestinationSelection(),

                      const SizedBox(height: 24),

                      // Transfer Type Selection (if admin selected)
                      if (_selectedDestinationType == 'admin')
                        _buildTransferTypeSelection(),

                      if (_selectedDestinationType == 'admin')
                        const SizedBox(height: 24),

                      // GCash Details (if Gcash selected)
                      if (_selectedDestinationType == 'admin' &&
                          _selectedTransferType == 'Gcash')
                        _buildGcashDetails(),

                      if (_selectedDestinationType == 'admin' &&
                          _selectedTransferType == 'Gcash')
                        const SizedBox(height: 24),

                      // Service Selection (if service destination selected)
                      if (_selectedDestinationType == 'service')
                        _buildServiceSelection(),

                      if (_selectedDestinationType == 'service')
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
            helperText: 'Minimum withdrawal amount: ₱50.00',
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
            if (amount < 50) {
              return 'Minimum withdrawal amount is ₱50.00';
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

  Widget _buildDestinationSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Withdrawal Method',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                title: const Text(
                  'Withdraw via Admin',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  'Request withdrawal via Gcash or Cash (requires admin approval)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: 'admin',
                groupValue: _selectedDestinationType,
                activeColor: evsuRed,
                onChanged: (value) {
                  setState(() {
                    _selectedDestinationType = value!;
                    _selectedServiceId = null;
                    _selectedServiceName = null;
                    // Reset transfer type to Cash when switching to admin
                    _selectedTransferType = 'Cash';
                  });
                },
              ),
              Divider(height: 1, color: Colors.grey[300]),
              RadioListTile<String>(
                title: const Text(
                  'Transfer to Vendor',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  'Immediate transfer to a vendor service account',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: 'service',
                groupValue: _selectedDestinationType,
                activeColor: evsuRed,
                onChanged: (value) {
                  setState(() {
                    _selectedDestinationType = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransferTypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transfer Type',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              RadioListTile<String>(
                title: const Text(
                  'Gcash',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  'Receive funds via Gcash transfer',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: 'Gcash',
                groupValue: _selectedTransferType,
                activeColor: evsuRed,
                onChanged: (value) {
                  setState(() {
                    _selectedTransferType = value!;
                  });
                },
              ),
              Divider(height: 1, color: Colors.grey[300]),
              RadioListTile<String>(
                title: const Text(
                  'Cash (Onsite)',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  'Pick up cash from admin office',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                value: 'Cash',
                groupValue: _selectedTransferType,
                activeColor: evsuRed,
                onChanged: (value) {
                  setState(() {
                    _selectedTransferType = value!;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGcashDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GCash Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _gcashNumberController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.phone, color: evsuRed),
            labelText: 'GCash Number',
            hintText: '09XXXXXXXXX',
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
            if (_selectedTransferType == 'Gcash') {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your GCash number';
              }
              // Basic validation for GCash number (should be 11 digits, starts with 09)
              if (!RegExp(r'^09\d{9}$').hasMatch(value.trim())) {
                return 'Please enter a valid GCash number (09XXXXXXXXX)';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _gcashAccountNameController,
          keyboardType: TextInputType.name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.person, color: evsuRed),
            labelText: 'GCash Account Name',
            hintText: 'Account holder name',
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
            if (_selectedTransferType == 'Gcash') {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your GCash account name';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildServiceSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Vendor',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child:
              _serviceAccounts.isEmpty
                  ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No vendors available',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  )
                  : DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      hint: const Text('Choose a vendor'),
                      value: _selectedServiceId,
                      icon: const Icon(Icons.arrow_drop_down, color: evsuRed),
                      items:
                          _serviceAccounts.map((service) {
                            final serviceId = service['id'] as int;
                            final serviceName =
                                service['service_name']?.toString() ??
                                'Unknown';
                            final serviceCategory =
                                service['service_category']?.toString() ?? '';

                            return DropdownMenuItem<int>(
                              value: serviceId,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    serviceName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (serviceCategory.isNotEmpty)
                                    Text(
                                      serviceCategory,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedServiceId = value;
                          _selectedServiceName =
                              _serviceAccounts
                                  .firstWhere(
                                    (s) => s['id'] == value,
                                  )['service_name']
                                  ?.toString();
                        });
                      },
                    ),
                  ),
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
                  _selectedDestinationType == 'admin'
                      ? _selectedTransferType == 'Gcash'
                          ? '• Your withdrawal request will be reviewed by admin.\n'
                              '• Once approved, funds will be transferred to your GCash account.\n'
                              '• You will be notified when the request is processed.'
                          : '• Your withdrawal request will be reviewed by admin.\n'
                              '• Once approved, visit the Admin office to collect your cash.\n'
                              '• You will be notified when ready for pickup.'
                      : '• You can only transfer funds to Vendor accounts.\n'
                          '• Campus Service Units and School Organizations cannot receive direct transfers.\n'
                          '• This transaction cannot be reversed.',
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
              : Text(
                _selectedDestinationType == 'admin'
                    ? 'Submit Withdrawal Request'
                    : 'Process Withdrawal',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
    );
  }
}
