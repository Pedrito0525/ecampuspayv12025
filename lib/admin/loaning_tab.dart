import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/encryption_service.dart';

class LoaningTab extends StatefulWidget {
  const LoaningTab({super.key});

  @override
  State<LoaningTab> createState() => _LoaningTabState();
}

class _LoaningTabState extends State<LoaningTab> {
  static const Color evsuRed = Color(0xFFB91C1C);

  bool _loading = true;
  String? _error;

  // Loan system defaults
  double _defaultInterestRate = 1.5; // Default interest rate percentage
  double _defaultPenaltyRate =
      0.5; // Default penalty rate percentage per day overdue

  // Loan plans (admin-defined loan products)
  List<Map<String, dynamic>> _loanPlans = [];

  // Active loans
  List<Map<String, dynamic>> _activeLoans = [];

  // Loan plan form controllers
  final _planAmountController = TextEditingController();
  final _planTermController = TextEditingController();
  final _planInterestController = TextEditingController();
  final _planPenaltyController = TextEditingController();
  final _planNameController = TextEditingController();
  final _planMinTopupController = TextEditingController();

  // Loan application form controllers
  final _studentIdController = TextEditingController();
  final _studentNameController = TextEditingController();
  final _loanAmountController = TextEditingController();

  bool _planStatusActive = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _planAmountController.dispose();
    _planTermController.dispose();
    _planInterestController.dispose();
    _planPenaltyController.dispose();
    _planNameController.dispose();
    _planMinTopupController.dispose();
    _studentIdController.dispose();
    _studentNameController.dispose();
    _loanAmountController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await SupabaseService.initialize();

      // Load loan plans from database
      final loanPlansResponse = await SupabaseService.client
          .from('loan_plans')
          .select('*')
          .order('created_at', ascending: false);

      _loanPlans = List<Map<String, dynamic>>.from(loanPlansResponse);

      // Load active loans from database with student names (exclude paid loans)
      final activeLoansResponse = await SupabaseService.client
          .from('active_loans')
          .select('''
            *,
            loan_plans!inner(name)
          ''')
          .neq('status', 'paid')
          .order('created_at', ascending: false);

      // Transform the data to include student names
      _activeLoans = [];
      for (final loan in activeLoansResponse) {
        // Get student name from auth_students
        try {
          final studentResponse =
              await SupabaseService.client
                  .from('auth_students')
                  .select('name')
                  .eq('student_id', loan['student_id'])
                  .single();

          // Decrypt the student name
          String studentName =
              studentResponse['name']?.toString() ?? 'Unknown Student';

          try {
            // Check if the name looks encrypted and decrypt it
            if (EncryptionService.looksLikeEncryptedData(studentName)) {
              studentName = EncryptionService.decryptData(studentName);
            }
          } catch (e) {
            print('Failed to decrypt student name: $e');
            // Keep the original name if decryption fails
          }

          _activeLoans.add({...loan, 'student_name': studentName});
        } catch (e) {
          // If student not found, use student_id as name
          _activeLoans.add({...loan, 'student_name': loan['student_id']});
        }
      }
    } catch (e) {
      _error = e.toString();
      print('Error loading loan data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: evsuRed,
        elevation: 0,
        title: const Text(
          'Loaning Management',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 12),
            Text(
              'Failed to load loaning data',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadData,
              style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 1000;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLoanPlansCard(),
              const SizedBox(height: 16),
              _buildActiveLoansCard(isWide: isWide),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoanPlansCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Loan Plans',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _openLoanPlanForm(),
                  style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                  label: const Text(
                    'Add Plan',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loanPlans.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'No loan plans yet. Create one to offer to users.',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Plan Name')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Term (days)')),
                    DataColumn(label: Text('Interest %')),
                    DataColumn(label: Text('Penalty %')),
                    DataColumn(label: Text('Min. Top-up')),
                    DataColumn(label: Text('Total Repayable')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows:
                      _loanPlans.asMap().entries.map((entry) {
                        final i = entry.key;
                        final plan = entry.value;
                        final amount = (plan['amount'] as num).toDouble();
                        final interestRate =
                            (plan['interest_rate'] as num).toDouble();
                        final termDays = plan['term_days'] as int;
                        final minTopup = (plan['min_topup'] as num).toDouble();
                        final status = plan['status'] as String;
                        final totalRepayable =
                            amount + (amount * interestRate / 100);

                        return DataRow(
                          cells: [
                            DataCell(Text(plan['name'] ?? 'Unnamed Plan')),
                            DataCell(Text('₱${amount.toStringAsFixed(2)}')),
                            DataCell(Text('$termDays days')),
                            DataCell(
                              Text('${interestRate.toStringAsFixed(1)}%'),
                            ),
                            DataCell(
                              Text(
                                '${(plan['penalty_rate'] as num).toStringAsFixed(1)}%/day',
                              ),
                            ),
                            DataCell(Text('₱${minTopup.toStringAsFixed(0)}')),
                            DataCell(
                              Text('₱${totalRepayable.toStringAsFixed(2)}'),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      status == 'active'
                                          ? Colors.green[100]
                                          : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color:
                                        status == 'active'
                                            ? Colors.green[700]
                                            : Colors.grey[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed:
                                        () => _openLoanPlanForm(
                                          existing: plan,
                                          index: i,
                                        ),
                                    icon: const Icon(Icons.edit, size: 18),
                                  ),
                                  IconButton(
                                    tooltip:
                                        status == 'active'
                                            ? 'Deactivate'
                                            : 'Activate',
                                    onPressed: () => _togglePlanStatus(i),
                                    icon: Icon(
                                      status == 'active'
                                          ? Icons.pause_circle
                                          : Icons.play_circle,
                                      size: 18,
                                      color:
                                          status == 'active'
                                              ? Colors.orange
                                              : Colors.green,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: () => _deleteLoanPlan(i),
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveLoansCard({required bool isWide}) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Active Loans',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_activeLoans.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'No active loans found',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Student ID')),
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Loan Amount')),
                    DataColumn(label: Text('Interest')),
                    DataColumn(label: Text('Penalty')),
                    DataColumn(label: Text('Total Due')),
                    DataColumn(label: Text('Due Date')),
                    DataColumn(label: Text('Days Left')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows:
                      _activeLoans.map((loan) {
                        final dueDate = DateTime.parse(loan['due_date']);
                        final now = DateTime.now();
                        final daysLeft = dueDate.difference(now).inDays;
                        final isOverdue = daysLeft < 0;

                        return DataRow(
                          cells: [
                            DataCell(Text(loan['student_id'])),
                            DataCell(Text(loan['student_name'])),
                            DataCell(
                              Text(
                                '₱${(loan['loan_amount'] as num).toStringAsFixed(2)}',
                              ),
                            ),
                            DataCell(
                              Text(
                                '₱${(loan['interest_amount'] as num).toStringAsFixed(2)}',
                              ),
                            ),
                            DataCell(
                              Text(
                                '₱${(loan['penalty_amount'] as num).toStringAsFixed(2)}',
                              ),
                            ),
                            DataCell(
                              Text(
                                '₱${(loan['total_amount'] as num).toStringAsFixed(2)}',
                              ),
                            ),
                            DataCell(Text(_formatDate(dueDate))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isOverdue
                                          ? Colors.red[100]
                                          : daysLeft <= 2
                                          ? Colors.orange[100]
                                          : Colors.green[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  isOverdue
                                      ? '${(-daysLeft)} overdue'
                                      : '$daysLeft days',
                                  style: TextStyle(
                                    color:
                                        isOverdue
                                            ? Colors.red[700]
                                            : daysLeft <= 2
                                            ? Colors.orange[700]
                                            : Colors.green[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue[100],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  (loan['status'] as String).toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Mark as Paid',
                                    onPressed: () => _markLoanAsPaid(loan),
                                    icon: const Icon(
                                      Icons.payment,
                                      size: 18,
                                      color: Colors.green,
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'View Details',
                                    onPressed: () => _viewLoanDetails(loan),
                                    icon: const Icon(
                                      Icons.visibility,
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // --------- LOAN PLAN CRUD ---------
  void _openLoanPlanForm({Map<String, dynamic>? existing, int? index}) {
    final isEdit = existing != null && index != null;

    if (isEdit) {
      _planNameController.text = existing['name'] ?? '';
      _planAmountController.text = existing['amount'].toString();
      _planTermController.text = existing['term_days'].toString();
      _planInterestController.text = existing['interest_rate'].toString();
      _planPenaltyController.text = existing['penalty_rate'].toString();
      _planMinTopupController.text = existing['min_topup'].toString();
      _planStatusActive = existing['status'] == 'active';
    } else {
      _planNameController.clear();
      _planAmountController.text = '500';
      _planTermController.text = '7';
      _planInterestController.text = _defaultInterestRate.toString();
      _planPenaltyController.text = _defaultPenaltyRate.toString();
      _planMinTopupController.text = '300';
      _planStatusActive = true;
    }

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setLocal) => AlertDialog(
                  title: Text(isEdit ? 'Edit Loan Plan' : 'Create Loan Plan'),
                  content: SizedBox(
                    width: 500,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: _planNameController,
                            decoration: const InputDecoration(
                              labelText: 'Plan Name',
                              border: OutlineInputBorder(),
                              hintText: 'e.g., Quick Cash - ₱500',
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _planAmountController,
                                  decoration: const InputDecoration(
                                    labelText: 'Loan Amount (₱)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _planTermController,
                                  decoration: const InputDecoration(
                                    labelText: 'Term (days)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _planInterestController,
                                  decoration: const InputDecoration(
                                    labelText: 'Interest Rate (%)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _planPenaltyController,
                                  decoration: const InputDecoration(
                                    labelText: 'Penalty Rate (%/day)',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _planMinTopupController,
                            decoration: const InputDecoration(
                              labelText: 'Minimum Top-up Requirement (₱)',
                              border: OutlineInputBorder(),
                              helperText:
                                  'Students need this amount in total top-ups to be eligible',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            value: _planStatusActive,
                            onChanged:
                                (value) =>
                                    setLocal(() => _planStatusActive = value),
                            title: const Text('Active Plan'),
                            subtitle: Text(
                              _planStatusActive
                                  ? 'Available to users'
                                  : 'Hidden from users',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final validation = _validatePlanForm();
                        if (validation != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(validation),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        await _saveLoanPlan(isEdit, index);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                      child: Text(
                        isEdit ? 'Save Changes' : 'Create Plan',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  String? _validatePlanForm() {
    if (_planNameController.text.trim().isEmpty) {
      return 'Plan name is required';
    }

    final amount = double.tryParse(_planAmountController.text.trim());
    if (amount == null || amount <= 0) {
      return 'Valid loan amount is required';
    }

    final termDays = int.tryParse(_planTermController.text.trim());
    if (termDays == null || termDays <= 0) {
      return 'Valid term in days is required';
    }

    final interestRate = double.tryParse(_planInterestController.text.trim());
    if (interestRate == null || interestRate < 0) {
      return 'Valid interest rate is required';
    }

    final penaltyRate = double.tryParse(_planPenaltyController.text.trim());
    if (penaltyRate == null || penaltyRate < 0) {
      return 'Valid penalty rate is required';
    }

    final minTopup = double.tryParse(_planMinTopupController.text.trim());
    if (minTopup == null || minTopup < 0) {
      return 'Valid minimum top-up amount is required';
    }

    return null;
  }

  Future<void> _saveLoanPlan(bool isEdit, int? index) async {
    try {
      final planData = {
        'name': _planNameController.text.trim(),
        'amount': double.parse(_planAmountController.text.trim()),
        'term_days': int.parse(_planTermController.text.trim()),
        'interest_rate': double.parse(_planInterestController.text.trim()),
        'penalty_rate': double.parse(_planPenaltyController.text.trim()),
        'min_topup': double.parse(_planMinTopupController.text.trim()),
        'status': _planStatusActive ? 'active' : 'inactive',
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isEdit && index != null) {
        // Update existing plan
        final planId = _loanPlans[index]['id'];
        await SupabaseService.client
            .from('loan_plans')
            .update(planData)
            .eq('id', planId);

        // Update local data
        _loanPlans[index] = {..._loanPlans[index], ...planData};
      } else {
        // Create new plan
        planData['created_at'] = DateTime.now().toIso8601String();
        final response =
            await SupabaseService.client
                .from('loan_plans')
                .insert(planData)
                .select()
                .single();

        // Add to local data
        _loanPlans.insert(0, response);
      }

      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEdit
                ? 'Loan plan updated successfully'
                : 'Loan plan created successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving loan plan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _togglePlanStatus(int index) async {
    try {
      final currentStatus = _loanPlans[index]['status'];
      final newStatus = currentStatus == 'active' ? 'inactive' : 'active';
      final planId = _loanPlans[index]['id'];

      await SupabaseService.client
          .from('loan_plans')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', planId);

      setState(() {
        _loanPlans[index]['status'] = newStatus;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Loan plan ${newStatus == 'active' ? 'activated' : 'deactivated'} successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating loan plan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteLoanPlan(int index) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Loan Plan'),
            content: const Text(
              'Are you sure you want to delete this loan plan? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _performDeleteLoanPlan(index);
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _performDeleteLoanPlan(int index) async {
    try {
      final planId = _loanPlans[index]['id'];
      final planName = _loanPlans[index]['name'] ?? 'this plan';

      // Check if there are any unpaid loans using this plan
      final unpaidLoansCount =
          await SupabaseService.client
              .from('active_loans')
              .select('id')
              .eq('loan_plan_id', planId)
              .neq('status', 'paid')
              .count();

      if (unpaidLoansCount.count > 0) {
        // Show proper modal dialog instead of SnackBar
        if (!mounted) return;
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange[700], size: 28),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Cannot Delete Loan Plan')),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cannot delete "$planName" because there ${unpaidLoansCount.count == 1 ? 'is' : 'are'} ${unpaidLoansCount.count} active loan${unpaidLoansCount.count == 1 ? '' : 's'} still using this plan.',
                      style: const TextStyle(fontSize: 15),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'All loans must be fully paid before this plan can be deleted.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(backgroundColor: evsuRed),
                    child: const Text(
                      'Understood',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
        );
        return;
      }

      await SupabaseService.client.from('loan_plans').delete().eq('id', planId);

      setState(() {
        _loanPlans.removeAt(index);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loan plan deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting loan plan: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // --------- LOAN MANAGEMENT ---------
  void _markLoanAsPaid(Map<String, dynamic> loan) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Mark Loan as Paid'),
            content: Text(
              'Mark loan for ${loan['student_name']} (₱${(loan['total_amount'] as num).toStringAsFixed(2)}) as paid?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await _performMarkLoanAsPaid(loan);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text(
                  'Mark as Paid',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _performMarkLoanAsPaid(Map<String, dynamic> loan) async {
    try {
      final loanId = loan['id'];

      // Mark loan as paid in database
      await SupabaseService.client
          .from('active_loans')
          .update({
            'status': 'paid',
            'paid_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', loanId);

      // Record payment
      await SupabaseService.client.from('loan_payments').insert({
        'loan_id': loanId,
        'student_id': loan['student_id'],
        'payment_amount': loan['total_amount'],
        'payment_type': 'full',
        'remaining_balance': 0,
      });

      // Remove from local list
      setState(() {
        _activeLoans.removeWhere((l) => l['id'] == loan['id']);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loan marked as paid successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking loan as paid: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _viewLoanDetails(Map<String, dynamic> loan) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Loan Details - ${loan['student_name']}'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDetailRow('Student ID', loan['student_id']),
                  _buildDetailRow('Student Name', loan['student_name']),
                  _buildDetailRow(
                    'Loan Amount',
                    '₱${(loan['loan_amount'] as num).toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    'Interest Amount',
                    '₱${(loan['interest_amount'] as num).toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    'Penalty Amount',
                    '₱${(loan['penalty_amount'] as num).toStringAsFixed(2)}',
                  ),
                  _buildDetailRow(
                    'Total Amount',
                    '₱${(loan['total_amount'] as num).toStringAsFixed(2)}',
                  ),
                  _buildDetailRow('Term', '${loan['term_days']} days'),
                  _buildDetailRow(
                    'Due Date',
                    _formatDate(DateTime.parse(loan['due_date'])),
                  ),
                  _buildDetailRow(
                    'Status',
                    (loan['status'] as String).toUpperCase(),
                  ),
                  _buildDetailRow(
                    'Applied Date',
                    _formatDate(DateTime.parse(loan['created_at'])),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
