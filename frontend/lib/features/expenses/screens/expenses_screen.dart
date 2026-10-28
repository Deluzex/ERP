import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/category_unit_model.dart';
import '../../../core/models/expense_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/figma_metric_card.dart';
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
    Future.microtask(() {
      ref.read(databaseServiceProvider).loadExpenses();
      ref.read(databaseServiceProvider).loadExpenseCategories();
    });
  }

  /// Resolves a stored payment method value (a Category Master payment mode
  /// code, or a legacy label from older records) to its display name.
  String _paymentMethodDisplay(String stored, List<PaymentModeMasterItem> modes) {
    for (final mode in modes) {
      if (mode.code == stored) return mode.name;
    }
    return stored;
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

    // Payment Method options follow the Payment Modes tab of Category Master;
    // new records default to the first active mode. Legacy labels ('Bank
    // Transfer') on existing records stay selectable via a fallback entry.
    final activePaymentModes = db.paymentModeMasterList.where((m) => m.isActive).toList();
    String paymentMethod = existing?.paymentMethod ??
        (activePaymentModes.isNotEmpty ? activePaymentModes.first.code : 'Bank Transfer');

    // Expense Category options follow the Expense Categories tab of Category
    // Master (every active entry, including user-added ones). Entries without
    // a linked backend expense key save under the canonical 'other' key, so
    // backend validation and stored categories stay valid. Items are keyed by
    // master id, so several entries may map to the same expense key.
    final activeCategoryMasters = db.expenseCategoryMasterList.where((m) => m.isActive).toList();
    ExpenseCategory categoryForMaster(ExpenseCategoryMasterItem master) {
      final key = master.linkedKey?.trim() ?? '';
      if (key.isEmpty) return ExpenseCategory.other;
      for (final c in ExpenseCategory.values) {
        if (c.name == key) return c;
      }
      return ExpenseCategory.other;
    }

    String legacyCategoryId(ExpenseCategory c) => 'legacy:${c.name}';
    final categoriesByItemId = <String, ExpenseCategory>{};
    final categoryItems = <DropdownMenuItem<String>>[];
    final seenMasterIds = <String>{};
    for (final master in activeCategoryMasters) {
      if (!seenMasterIds.add(master.id)) continue;
      categoriesByItemId[master.id] = categoryForMaster(master);
      categoryItems.add(DropdownMenuItem(
        value: master.id,
        child: Text(master.name, overflow: TextOverflow.ellipsis),
      ));
    }
    if (categoryItems.isEmpty) {
      for (final c in ExpenseCategory.values) {
        categoriesByItemId[legacyCategoryId(c)] = c;
        categoryItems.add(DropdownMenuItem(value: legacyCategoryId(c), child: Text(c.name.toUpperCase())));
      }
    }
    // Preselect the master entry matching the current category: entries with
    // an explicit linked key win, then any mapped entry, and finally a legacy
    // label entry keeps the current selection valid.
    String selectedCategoryId = legacyCategoryId(category);
    bool matched = false;
    for (final master in activeCategoryMasters) {
      if ((master.linkedKey?.trim() ?? '').isNotEmpty && categoryForMaster(master) == category) {
        selectedCategoryId = master.id;
        matched = true;
        break;
      }
    }
    if (!matched) {
      for (final item in categoryItems) {
        if (categoriesByItemId[item.value!] == category) {
          selectedCategoryId = item.value!;
          matched = true;
          break;
        }
      }
    }
    if (!matched) {
      categoriesByItemId[selectedCategoryId] = category;
      categoryItems.add(DropdownMenuItem(value: selectedCategoryId, child: Text(category.name.toUpperCase())));
    }

    final paymentMethodItems = <DropdownMenuItem<String>>[
      if (activePaymentModes.isNotEmpty)
        for (final mode in activePaymentModes)
          DropdownMenuItem(value: mode.code, child: Text(mode.name, overflow: TextOverflow.ellipsis))
      else ...[
        const DropdownMenuItem(value: 'Cash', child: Text('Cash')),
        const DropdownMenuItem(value: 'Bank Transfer', child: Text('Bank Transfer (NEFT/RTGS)')),
        const DropdownMenuItem(value: 'UPI', child: Text('UPI / QR')),
        const DropdownMenuItem(value: 'Cheque', child: Text('Cheque')),
        const DropdownMenuItem(value: 'Company Card', child: Text('Corporate Card')),
      ],
    ];
    if (paymentMethodItems.every((item) => item.value != paymentMethod)) {
      paymentMethodItems.add(DropdownMenuItem(value: paymentMethod, child: Text(paymentMethod)));
    }
    String? selectedProjId = existing?.projectId;
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
                                DropdownButtonFormField<String>(
                                  value: selectedCategoryId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Expense Category *'),
                                  items: categoryItems,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setDlgState(() {
                                        selectedCategoryId = val;
                                        category = categoriesByItemId[val] ?? category;
                                      });
                                    }
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
                                  items: paymentMethodItems,
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
                                    child: DropdownButtonFormField<String>(
                                      value: selectedCategoryId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(labelText: 'Expense Category *'),
                                      items: categoryItems,
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDlgState(() {
                                            selectedCategoryId = val;
                                            category = categoriesByItemId[val] ?? category;
                                          });
                                        }
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
                                      items: paymentMethodItems,
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
          ErpSectionHeaderCard(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Expense Management',
            badgeText: 'OVERHEADS & DISBURSEMENTS',
            action: ErpButton(
              text: 'Record Expense',
              icon: Icons.add,
              onPressed: () => _openAddEditExpenseDialog(),
            ),
          ),
          const SizedBox(height: 20),

          // KPI Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 1100
                  ? (constraints.maxWidth - 36) / 4
                  : (constraints.maxWidth > 650 ? (constraints.maxWidth - 12) / 2 : double.infinity);

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      title: 'Total Expenses',
                      value: Formatters.formatCurrency(totalExp),
                      subtext: '${filteredExpenses.length} Logged records',
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: AppColors.primary,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      title: 'Project Expenses',
                      value: Formatters.formatCurrency(projectExp),
                      subtext: '${filteredExpenses.where((e) => e.projectId != null).length} Site projects',
                      icon: Icons.business_outlined,
                      iconColor: AppColors.purple,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      title: 'Production Expenses',
                      value: Formatters.formatCurrency(prodExp),
                      subtext: '${filteredExpenses.where((e) => e.productionId != null).length} Manufacturing jobs',
                      icon: Icons.precision_manufacturing_outlined,
                      iconColor: AppColors.warning,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      title: 'Operational Overhead',
                      value: Formatters.formatCurrency(opsExp),
                      subtext: 'General utilities & admin',
                      icon: Icons.apartment_outlined,
                      iconColor: AppColors.info,
                    ),
                  ),
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
              dataRowMinHeight: 58,
              dataRowMaxHeight: 68,
              columnSpacing: 16,
              horizontalMargin: 16,
              columns: const [
                ErpColumn(title: 'Voucher No', width: 130),
                ErpColumn(title: 'Date', width: 110),
                ErpColumn(title: 'Expense Title & Category', width: 220),
                ErpColumn(title: 'Linked Project / Production', width: 200),
                ErpColumn(title: 'Paid By & Method', width: 170),
                ErpColumn(title: 'Amount', isNumeric: true, width: 120),
                ErpColumn(title: 'Status', width: 110),
                ErpColumn(title: 'Actions', width: 90),
              ],
              rows: filteredExpenses.map((exp) {
                return [
                  Text(exp.expenseNumber, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, fontSize: 12.5)),
                  Text(Formatters.formatDate(exp.expenseDate), style: AppTextStyles.bodySmall),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(exp.expenseName, style: AppTextStyles.bodyBold.copyWith(fontSize: 12.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(exp.categoryLabel, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 200),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (exp.projectName != null)
                          Text('Proj: ${exp.projectName}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.purple), maxLines: 1, overflow: TextOverflow.ellipsis)
                        else if (exp.productionNumber != null)
                          Text('Prod: ${exp.productionNumber}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppColors.warning), maxLines: 1, overflow: TextOverflow.ellipsis)
                        else
                          const Text('Operational Overhead', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 170),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(exp.paidBy, style: AppTextStyles.bodyMedium.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(_paymentMethodDisplay(exp.paymentMethod, db.paymentModeMasterList), style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(Formatters.formatCurrency(exp.amount), style: AppTextStyles.bodyBold.copyWith(fontSize: 12.5)),
                  ),
                  ErpStatusBadge.success(exp.paymentStatus.name.toUpperCase()),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: AppColors.info, size: 18),
                        tooltip: 'Edit Expense',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                        onPressed: () => _openAddEditExpenseDialog(exp),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                        tooltip: 'Delete Expense',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
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
}

