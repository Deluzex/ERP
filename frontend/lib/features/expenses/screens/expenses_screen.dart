import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/expense_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _searchQuery = '';
  ExpenseCategory? _selectedCategory;
  ExpensePaymentStatus? _selectedStatus;
  String? _selectedProjectId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(databaseServiceProvider).loadExpenses());
  }

  void _openAddEditExpenseDialog([Expense? existing]) {
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;

    final nameCtrl = TextEditingController(text: existing?.expenseName ?? '');
    final amountCtrl = TextEditingController(text: existing != null ? existing.amount.toString() : '');
    final paidByCtrl = TextEditingController(text: existing?.paidBy ?? db.currentUser.name);
    final payeeCtrl = TextEditingController(text: existing?.vendorPayee ?? '');
    final refCtrl = TextEditingController(text: existing?.expenseReference ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final receiptCtrl = TextEditingController(text: existing?.receiptAttachmentName ?? '');

    DateTime expenseDate = existing?.expenseDate ?? DateTime.now();
    ExpenseCategory category = existing?.category ?? ExpenseCategory.transportation;
    ExpensePaymentStatus paymentStatus = existing?.paymentStatus ?? ExpensePaymentStatus.paid;
    String paymentMethod = existing?.paymentMethod ?? 'Bank Transfer';
    String? selectedProjId = existing?.projectId;
    String? selectedPurchId = existing?.purchaseId;
    String? selectedProdId = existing?.productionId;

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(isEdit ? 'Edit Expense Record' : 'Record Business Expense', style: AppTextStyles.h2),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              width: double.infinity,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 500;
                          if (isNarrow) {
                            return Column(
                              children: [
                                TextFormField(
                                  controller: nameCtrl,
                                  validator: (v) => Validators.requiredField(v, 'Expense Title required'),
                                  decoration: const InputDecoration(labelText: 'Expense Name / Title *', hintText: 'e.g. Crane Transport at Site'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: amountCtrl,
                                  keyboardType: TextInputType.number,
                                  validator: (v) => Validators.positiveNumber(v, 'Amount required'),
                                  decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixText: '₹ '),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<ExpenseCategory>(
                                  value: category,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Expense Category *'),
                                  items: ExpenseCategory.values.map((c) {
                                    return DropdownMenuItem(value: c, child: Text(c.name.toUpperCase()));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setDlgState(() => category = val);
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<ExpensePaymentStatus>(
                                  value: paymentStatus,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Payment Status'),
                                  items: ExpensePaymentStatus.values.map((s) {
                                    return DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setDlgState(() => paymentStatus = val);
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: paidByCtrl,
                                  validator: (v) => Validators.requiredField(v, 'Paid By required'),
                                  decoration: const InputDecoration(labelText: 'Paid By (Staff / Executive) *'),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: paymentMethod,
                                  decoration: const InputDecoration(labelText: 'Payment Method'),
                                  items: const [
                                    DropdownMenuItem(value: 'Cash', child: Text('Cash', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer (NEFT/RTGS)', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'UPI', child: Text('UPI / QR', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'Cheque', child: Text('Cheque', overflow: TextOverflow.ellipsis)),
                                    DropdownMenuItem(value: 'Company Card', child: Text('Corporate Card', overflow: TextOverflow.ellipsis)),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setDlgState(() => paymentMethod = val);
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: payeeCtrl,
                                  decoration: const InputDecoration(labelText: 'Vendor / Payee / Contractor (Optional)', hintText: 'e.g. QuickMove Logistics'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: refCtrl,
                                  decoration: const InputDecoration(labelText: 'Voucher / Bill Reference No', hintText: 'e.g. INV-9921 / AWB-4412'),
                                ),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: TextFormField(
                                      controller: nameCtrl,
                                      validator: (v) => Validators.requiredField(v, 'Expense Title required'),
                                      decoration: const InputDecoration(labelText: 'Expense Name / Title *', hintText: 'e.g. Crane Transport at Site'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: amountCtrl,
                                      keyboardType: TextInputType.number,
                                      validator: (v) => Validators.positiveNumber(v, 'Amount required'),
                                      decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixText: '₹ '),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<ExpenseCategory>(
                                      value: category,
                                      isExpanded: true,
                                      decoration: const InputDecoration(labelText: 'Expense Category *'),
                                      items: ExpenseCategory.values.map((c) {
                                        return DropdownMenuItem(value: c, child: Text(c.name.toUpperCase()));
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setDlgState(() => category = val);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<ExpensePaymentStatus>(
                                      value: paymentStatus,
                                      isExpanded: true,
                                      decoration: const InputDecoration(labelText: 'Payment Status'),
                                      items: ExpensePaymentStatus.values.map((s) {
                                        return DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()));
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) setDlgState(() => paymentStatus = val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: paidByCtrl,
                                      validator: (v) => Validators.requiredField(v, 'Paid By required'),
                                      decoration: const InputDecoration(labelText: 'Paid By (Staff / Executive) *'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: paymentMethod,
                                      decoration: const InputDecoration(labelText: 'Payment Method'),
                                      items: const [
                                        DropdownMenuItem(value: 'Cash', child: Text('Cash', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer (NEFT/RTGS)', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'UPI', child: Text('UPI / QR', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'Cheque', child: Text('Cheque', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: 'Company Card', child: Text('Corporate Card', overflow: TextOverflow.ellipsis)),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) setDlgState(() => paymentMethod = val);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: payeeCtrl,
                                      decoration: const InputDecoration(labelText: 'Vendor / Payee / Contractor (Optional)', hintText: 'e.g. QuickMove Logistics'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: refCtrl,
                                      decoration: const InputDecoration(labelText: 'Voucher / Bill Reference No', hintText: 'e.g. INV-9921 / AWB-4412'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Optional ERP Module Linkages
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Module Linkages (Optional for Costing Analysis)', style: AppTextStyles.bodyBold.copyWith(fontSize: 11)),
                            const SizedBox(height: 8),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final isNarrow = constraints.maxWidth < 450;
                                if (isNarrow) {
                                  return Column(
                                    children: [
                                      DropdownButtonFormField<String?>(
                                        value: selectedProjId,
                                        isExpanded: true,
                                        decoration: const InputDecoration(labelText: 'Related Project'),
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('None (General Expense)')),
                                          ...db.projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                                        ],
                                        onChanged: (val) => setDlgState(() => selectedProjId = val),
                                      ),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<String?>(
                                        value: selectedProdId,
                                        isExpanded: true,
                                        decoration: const InputDecoration(labelText: 'Related Production'),
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('None')),
                                          ...db.productionOrders.map((o) => DropdownMenuItem(value: o.id, child: Text('${o.productionNumber} (${o.finishedProductName})', overflow: TextOverflow.ellipsis))),
                                        ],
                                        onChanged: (val) => setDlgState(() => selectedProdId = val),
                                      ),
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String?>(
                                        value: selectedProjId,
                                        isExpanded: true,
                                        decoration: const InputDecoration(labelText: 'Related Project'),
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('None (General Expense)')),
                                          ...db.projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                                        ],
                                        onChanged: (val) => setDlgState(() => selectedProjId = val),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonFormField<String?>(
                                        value: selectedProdId,
                                        isExpanded: true,
                                        decoration: const InputDecoration(labelText: 'Related Production'),
                                        items: [
                                          const DropdownMenuItem(value: null, child: Text('None')),
                                          ...db.productionOrders.map((o) => DropdownMenuItem(value: o.id, child: Text('${o.productionNumber} (${o.finishedProductName})', overflow: TextOverflow.ellipsis))),
                                        ],
                                        onChanged: (val) => setDlgState(() => selectedProdId = val),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Description / Purpose Notes', hintText: 'Details of what this expense covered...'),
                      ),
                      const SizedBox(height: 12),

                      TextFormField(
                        controller: receiptCtrl,
                        decoration: const InputDecoration(labelText: 'Receipt / Attachment Document Name', hintText: 'e.g. Receipt_0045.pdf'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              ErpButton(
                text: 'Cancel',
                isOutlined: true,
                onPressed: () => Navigator.pop(ctx),
              ),
              ErpButton(
                text: isEdit ? 'Update Expense' : 'Save Expense',
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  String? projName;
                  if (selectedProjId != null) {
                    projName = db.projects.where((p) => p.id == selectedProjId).firstOrNull?.name;
                  }
                  String? prodNum;
                  if (selectedProdId != null) {
                    prodNum = db.productionOrders.where((o) => o.id == selectedProdId).firstOrNull?.productionNumber;
                  }

                  if (isEdit) {
                    db.updateExpenseAsync(existing.copyWith(
                      expenseName: nameCtrl.text.trim(),
                      amount: amt,
                      category: category,
                      paidBy: paidByCtrl.text.trim(),
                      paymentMethod: paymentMethod,
                      vendorPayee: payeeCtrl.text.trim().isNotEmpty ? payeeCtrl.text.trim() : null,
                      projectId: selectedProjId,
                      projectName: projName,
                      productionId: selectedProdId,
                      productionNumber: prodNum,
                      expenseReference: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
                      description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                      receiptAttachmentName: receiptCtrl.text.trim().isNotEmpty ? receiptCtrl.text.trim() : null,
                      paymentStatus: paymentStatus,
                    ));
                  } else {
                    db.createExpenseAsync(Expense(
                      id: IdGenerator.generateId('EXP'),
                      expenseNumber: IdGenerator.generateDocNumber('EXP', db.nextExpenseNumber),
                      expenseDate: expenseDate,
                      expenseName: nameCtrl.text.trim(),
                      category: category,
                      amount: amt,
                      paidBy: paidByCtrl.text.trim(),
                      paymentMethod: paymentMethod,
                      vendorPayee: payeeCtrl.text.trim().isNotEmpty ? payeeCtrl.text.trim() : null,
                      projectId: selectedProjId,
                      projectName: projName,
                      productionId: selectedProdId,
                      productionNumber: prodNum,
                      expenseReference: refCtrl.text.trim().isNotEmpty ? refCtrl.text.trim() : null,
                      description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                      receiptAttachmentName: receiptCtrl.text.trim().isNotEmpty ? receiptCtrl.text.trim() : null,
                      paymentStatus: paymentStatus,
                      createdBy: db.currentUser.name,
                      createdAt: DateTime.now(),
                    ));
                  }

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit ? 'Expense updated successfully!' : 'Expense recorded successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDeleteExpense(Expense expense) {
    final db = ref.read(databaseServiceProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Expense', style: AppTextStyles.h2.copyWith(color: AppColors.danger)),
        content: Text('Are you sure you want to delete expense "${expense.expenseName}" (${Formatters.formatCurrency(expense.amount)})?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ErpButton(
            text: 'Delete',
            isDanger: true,
            onPressed: () {
              db.deleteExpense(expense.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Expense deleted successfully!'), backgroundColor: AppColors.danger),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);

    final filteredExpenses = db.expenses.where((e) {
      final q = _searchQuery.trim().toLowerCase();
      final matchQuery = q.isEmpty ||
          e.expenseName.toLowerCase().contains(q) ||
          e.expenseNumber.toLowerCase().contains(q) ||
          (e.vendorPayee != null && e.vendorPayee!.toLowerCase().contains(q)) ||
          (e.projectName != null && e.projectName!.toLowerCase().contains(q)) ||
          e.paidBy.toLowerCase().contains(q);

      final matchCat = _selectedCategory == null || e.category == _selectedCategory;
      final matchStatus = _selectedStatus == null || e.paymentStatus == _selectedStatus;
      final matchProj = _selectedProjectId == null || e.projectId == _selectedProjectId;

      return matchQuery && matchCat && matchStatus && matchProj;
    }).toList();

    double totalExp = db.expenses.fold(0.0, (s, e) => s + e.amount);
    double projectExp = db.expenses.where((e) => e.projectId != null).fold(0.0, (s, e) => s + e.amount);
    double prodExp = db.expenses.where((e) => e.productionId != null).fold(0.0, (s, e) => s + e.amount);
    double opsExp = totalExp - projectExp - prodExp;

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: isSmall ? double.infinity : constraints.maxWidth - 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Expense Management', style: AppTextStyles.h1),
                        const SizedBox(height: 4),
                        Text('Track operational, project site, labour, utility, and maintenance overheads', style: AppTextStyles.subtitle),
                      ],
                    ),
                  ),
                  ErpButton(
                    text: 'Record Expense',
                    icon: Icons.add,
                    onPressed: () => _openAddEditExpenseDialog(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              if (width < 600) {
                return Column(
                  children: [
                    _buildKpiCard('Total Expenses', Formatters.formatCurrency(totalExp), Icons.account_balance_wallet_outlined, AppColors.primary),
                    const SizedBox(height: 12),
                    _buildKpiCard('Project Expenses', Formatters.formatCurrency(projectExp), Icons.business_outlined, AppColors.purple),
                    const SizedBox(height: 12),
                    _buildKpiCard('Production Expenses', Formatters.formatCurrency(prodExp), Icons.precision_manufacturing_outlined, AppColors.warning),
                    const SizedBox(height: 12),
                    _buildKpiCard('Operational Overhead', Formatters.formatCurrency(opsExp), Icons.apartment_outlined, AppColors.info),
                  ],
                );
              } else if (width < 1050) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildKpiCard('Total Expenses', Formatters.formatCurrency(totalExp), Icons.account_balance_wallet_outlined, AppColors.primary)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildKpiCard('Project Expenses', Formatters.formatCurrency(projectExp), Icons.business_outlined, AppColors.purple)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildKpiCard('Production Expenses', Formatters.formatCurrency(prodExp), Icons.precision_manufacturing_outlined, AppColors.warning)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildKpiCard('Operational Overhead', Formatters.formatCurrency(opsExp), Icons.apartment_outlined, AppColors.info)),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _buildKpiCard('Total Expenses', Formatters.formatCurrency(totalExp), Icons.account_balance_wallet_outlined, AppColors.primary)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildKpiCard('Project Expenses', Formatters.formatCurrency(projectExp), Icons.business_outlined, AppColors.purple)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildKpiCard('Production Expenses', Formatters.formatCurrency(prodExp), Icons.precision_manufacturing_outlined, AppColors.warning)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildKpiCard('Operational Overhead', Formatters.formatCurrency(opsExp), Icons.apartment_outlined, AppColors.info)),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Filters Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 700;
              if (isSmall) {
                return Column(
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: const InputDecoration(
                        hintText: 'Search expenses by name, voucher no, payee, project, paid by...',
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<ExpenseCategory?>(
                      value: _selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Filter Category'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Categories')),
                        ...ExpenseCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name.toUpperCase()))),
                      ],
                      onChanged: (v) => setState(() => _selectedCategory = v),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      value: _selectedProjectId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Filter Project'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Projects')),
                        ...db.projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() => _selectedProjectId = v),
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      onChanged: (v) => setState(() => _searchQuery = v),
                      decoration: const InputDecoration(
                        hintText: 'Search expenses by name, voucher no, payee, project, paid by...',
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<ExpenseCategory?>(
                      value: _selectedCategory,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Filter Category'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Categories')),
                        ...ExpenseCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name.toUpperCase()))),
                      ],
                      onChanged: (v) => setState(() => _selectedCategory = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _selectedProjectId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Filter Project'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Projects')),
                        ...db.projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setState(() => _selectedProjectId = v),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Expenses Table
          if (filteredExpenses.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: const Text('No expenses found matching the filter criteria.'),
            )
          else
            ErpDataTable(
              columns: const [
                ErpColumn(title: 'Voucher No'),
                ErpColumn(title: 'Date'),
                ErpColumn(title: 'Expense Title & Category'),
                ErpColumn(title: 'Linked Project / Production'),
                ErpColumn(title: 'Paid By & Method'),
                ErpColumn(title: 'Amount', isNumeric: true),
                ErpColumn(title: 'Status'),
                ErpColumn(title: 'Actions'),
              ],
              rows: filteredExpenses.map((exp) {
                return [
                  Text(exp.expenseNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                  Text(Formatters.formatDate(exp.expenseDate), style: AppTextStyles.bodySmall),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exp.expenseName, style: AppTextStyles.bodyBold),
                      Text(exp.categoryLabel, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (exp.projectName != null)
                        Text('Proj: ${exp.projectName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.purple))
                      else if (exp.productionNumber != null)
                        Text('Prod: ${exp.productionNumber}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.warning))
                      else
                        const Text('Operational', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(exp.paidBy, style: AppTextStyles.bodyMedium),
                      Text(exp.paymentMethod, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10.5)),
                    ],
                  ),
                  Text(Formatters.formatCurrency(exp.amount), style: AppTextStyles.bodyBold),
                  ErpStatusBadge.success(exp.paymentStatus.name.toUpperCase()),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _openAddEditExpenseDialog(exp),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                        onPressed: () => _confirmDeleteExpense(exp),
                      ),
                    ],
                  ),
                ];
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: AppTextStyles.h2.copyWith(fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
