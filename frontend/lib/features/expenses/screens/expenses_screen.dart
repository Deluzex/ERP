import 'dart:math';
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
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/figma_metric_card.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'ALL';
  String _selectedProjectId = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  int _pageSize = 10;

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

    final activePaymentModes = db.paymentModeMasterList.where((m) => m.isActive).toList();
    String paymentMethod = existing?.paymentMethod ??
        (activePaymentModes.isNotEmpty ? activePaymentModes.first.code : 'Bank Transfer');

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

  void _showExpenseDetailsDialog(Expense exp, MockDatabaseService db) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isMobile = MediaQuery.of(ctx).size.width < 600;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: isMobile ? double.infinity : 540,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFD97706), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(exp.expenseNumber, style: AppTextStyles.h2.copyWith(fontSize: 16)),
                              Text(exp.categoryLabel, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  _buildDetailRow('Expense Title', exp.expenseName),
                  _buildDetailRow('Date', Formatters.formatDate(exp.expenseDate)),
                  _buildDetailRow('Amount', Formatters.formatCurrency(exp.amount), isBold: true, valueColor: AppColors.primary),
                  _buildDetailRow('Payment Status', exp.paymentStatus.name.toUpperCase()),
                  _buildDetailRow('Paid By', exp.paidBy),
                  _buildDetailRow('Payment Method', _paymentMethodDisplay(exp.paymentMethod, db.paymentModeMasterList)),
                  if (exp.vendorPayee != null && exp.vendorPayee!.isNotEmpty)
                    _buildDetailRow('Payee / Vendor', exp.vendorPayee!),
                  if (exp.expenseReference != null && exp.expenseReference!.isNotEmpty)
                    _buildDetailRow('Reference / Bill No', exp.expenseReference!),
                  if (exp.projectName != null && exp.projectName!.isNotEmpty)
                    _buildDetailRow('Linked Project', exp.projectName!, valueColor: AppColors.purple),
                  if (exp.productionNumber != null && exp.productionNumber!.isNotEmpty)
                    _buildDetailRow('Linked Production', exp.productionNumber!, valueColor: AppColors.warning),
                  if (exp.receiptAttachmentName != null && exp.receiptAttachmentName!.isNotEmpty)
                    _buildDetailRow('Attachment', exp.receiptAttachmentName!),
                  if (exp.description != null && exp.description!.isNotEmpty)
                    _buildDetailRow('Description', exp.description!),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ErpButton(
                        text: 'Close',
                        isOutlined: true,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      const SizedBox(width: 10),
                      ErpButton(
                        text: 'Edit Expense',
                        icon: Icons.edit_outlined,
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openAddEditExpenseDialog(exp);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: (isBold ? AppTextStyles.bodyBold : AppTextStyles.bodyMedium).copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
          ),
        ],
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

  Widget _buildResponsiveMetricRow(BuildContext context, List<Widget> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final double cardWidth;
        if (width < 600) {
          cardWidth = width;
        } else if (width < 1050) {
          cardWidth = (width - 12) / 2;
        } else {
          cardWidth = (width - (12 * (cards.length - 1))) / cards.length;
        }
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
        );
      },
    );
  }

  Widget _buildControlsRow(MockDatabaseService db) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 750;
        final projectItems = [
          const DropdownMenuItem(value: 'ALL', child: Text('All Projects')),
          ...db.projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, overflow: TextOverflow.ellipsis))),
        ];
        final categoryItems = [
          const DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
          ...ExpenseCategory.values.map((c) => DropdownMenuItem(value: c.name, child: Text(c.name.toUpperCase()))),
        ];

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ErpSearchInput(
                hintText: 'Search expenses by name, voucher no, payee, project, paid by...',
                initialValue: _searchQuery,
                onChanged: (val) => setState(() {
                  _searchQuery = val;
                  _currentPage = 0;
                }),
              ),
              const SizedBox(height: 10),
              ErpFilterDropdown<String>(
                value: _selectedCategory,
                width: double.infinity,
                isExpanded: true,
                items: categoryItems,
                onChanged: (val) => setState(() {
                  _selectedCategory = val ?? 'ALL';
                  _currentPage = 0;
                }),
              ),
              const SizedBox(height: 10),
              ErpFilterDropdown<String>(
                value: _selectedProjectId,
                width: double.infinity,
                isExpanded: true,
                items: projectItems,
                onChanged: (val) => setState(() {
                  _selectedProjectId = val ?? 'ALL';
                  _currentPage = 0;
                }),
              ),
              const SizedBox(height: 10),
              ErpDateFilterBox(
                startDate: _startDate,
                endDate: _endDate,
                onDateRangeSelected: (start, end) => setState(() {
                  _startDate = start;
                  _endDate = end;
                  _currentPage = 0;
                }),
              ),
            ],
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 320,
              child: ErpSearchInput(
                hintText: 'Search expenses by name, voucher no, payee...',
                initialValue: _searchQuery,
                onChanged: (val) => setState(() {
                  _searchQuery = val;
                  _currentPage = 0;
                }),
              ),
            ),
            ErpFilterDropdown<String>(
              value: _selectedCategory,
              width: 180,
              isExpanded: true,
              items: categoryItems,
              onChanged: (val) => setState(() {
                _selectedCategory = val ?? 'ALL';
                _currentPage = 0;
              }),
            ),
            ErpFilterDropdown<String>(
              value: _selectedProjectId,
              width: 180,
              isExpanded: true,
              items: projectItems,
              onChanged: (val) => setState(() {
                _selectedProjectId = val ?? 'ALL';
                _currentPage = 0;
              }),
            ),
            ErpDateFilterBox(
              startDate: _startDate,
              endDate: _endDate,
              onDateRangeSelected: (start, end) => setState(() {
                _startDate = start;
                _endDate = end;
                _currentPage = 0;
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildExpensesTable(List<Expense> expenses, MockDatabaseService db) {
    if (expenses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(48),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No expenses found matching the filter criteria.', style: AppTextStyles.bodyMedium),
          ],
        ),
      );
    }

    return ErpDataTable(
      dataRowMinHeight: 56,
      dataRowMaxHeight: 66,
      columns: const [
        ErpColumn(title: 'Voucher No', width: 130),
        ErpColumn(title: 'Date', width: 110),
        ErpColumn(title: 'Expense Title & Category', width: 220),
        ErpColumn(title: 'Linked Project / Production', width: 200),
        ErpColumn(title: 'Paid By & Method', width: 170),
        ErpColumn(title: 'Amount', isNumeric: true, width: 120),
        ErpColumn(title: 'Status', width: 100),
        ErpColumn(title: 'Actions', width: 90, alignment: Alignment.center),
      ],
      rows: expenses.map((exp) {
        return [
          InkWell(
            onTap: () => _showExpenseDetailsDialog(exp, db),
            child: Text(
              exp.expenseNumber,
              style: AppTextStyles.bodyBold.copyWith(
                color: AppColors.primary,
                fontSize: 12.5,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Text(Formatters.formatDate(exp.expenseDate), style: AppTextStyles.bodySmall),
          SizedBox(
            width: 220,
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
          SizedBox(
            width: 200,
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
          SizedBox(
            width: 170,
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
          Text(Formatters.formatCurrency(exp.amount), style: AppTextStyles.bodyBold.copyWith(fontSize: 12.5)),
          ErpStatusBadge.success(exp.paymentStatus.name.toUpperCase()),
          PopupMenuButton<String>(
            tooltip: 'Actions',
            icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onSelected: (action) {
              if (action == 'view') {
                _showExpenseDetailsDialog(exp, db);
              } else if (action == 'edit') {
                _openAddEditExpenseDialog(exp);
              } else if (action == 'delete') {
                _confirmDeleteExpense(exp);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF475569)),
                    SizedBox(width: 8),
                    Text('View Details', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Edit Expense', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Delete Expense', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.danger)),
                  ],
                ),
              ),
            ],
          ),
        ];
      }).toList(),
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

      final matchCat = _selectedCategory == 'ALL' || e.category.name.toLowerCase() == _selectedCategory.toLowerCase();
      final matchProj = _selectedProjectId == 'ALL' || e.projectId == _selectedProjectId;

      if (_startDate != null && e.expenseDate.isBefore(_startDate!)) return false;
      if (_endDate != null && e.expenseDate.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) return false;

      return matchQuery && matchCat && matchProj;
    }).toList();

    // Overall KPI figures (always reflect full dataset)
    final double totalExp = db.expenses.fold(0.0, (s, e) => s + e.amount);
    final double projectExp = db.expenses.where((e) => e.projectId != null).fold(0.0, (s, e) => s + e.amount);
    final double prodExp = db.expenses.where((e) => e.productionId != null).fold(0.0, (s, e) => s + e.amount);
    final double opsExp = db.expenses.where((e) => e.projectId == null && e.productionId == null).fold(0.0, (s, e) => s + e.amount);

    final totalCount = filteredExpenses.length;
    final maxPage = (totalCount == 0) ? 0 : (totalCount - 1) ~/ _pageSize;
    final safeCurrentPage = _currentPage.clamp(0, maxPage);
    final startIndex = safeCurrentPage * _pageSize;
    final endIndex = min(startIndex + _pageSize, totalCount);
    final pageExpenses = (startIndex < totalCount) ? filteredExpenses.sublist(startIndex, endIndex) : <Expense>[];

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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

          // Overall KPI Cards
          _buildResponsiveMetricRow(context, [
            FigmaMetricCard(
              title: 'Total Expenses',
              value: Formatters.formatCurrency(totalExp),
              subtext: '${db.expenses.length} Logged records',
              icon: Icons.account_balance_wallet_outlined,
              iconColor: AppColors.primary,
            ),
            FigmaMetricCard(
              title: 'Project Expenses',
              value: Formatters.formatCurrency(projectExp),
              subtext: '${db.expenses.where((e) => e.projectId != null).length} Site projects',
              icon: Icons.business_outlined,
              iconColor: AppColors.purple,
            ),
            FigmaMetricCard(
              title: 'Production Expenses',
              value: Formatters.formatCurrency(prodExp),
              subtext: '${db.expenses.where((e) => e.productionId != null).length} Manufacturing jobs',
              icon: Icons.precision_manufacturing_outlined,
              iconColor: AppColors.warning,
            ),
            FigmaMetricCard(
              title: 'Operational Overhead',
              value: Formatters.formatCurrency(opsExp),
              subtext: '${db.expenses.where((e) => e.projectId == null && e.productionId == null).length} General & admin utilities',
              icon: Icons.apartment_outlined,
              iconColor: AppColors.info,
            ),
          ]),
          const SizedBox(height: 20),

          // White Container Card enclosing Filters, Table & Pagination
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildControlsRow(db),
                const SizedBox(height: 16),
                _buildExpensesTable(pageExpenses, db),
                const SizedBox(height: 16),
                ErpPaginationBar(
                  currentPage: safeCurrentPage,
                  pageSize: _pageSize,
                  totalRecords: totalCount,
                  onPageChanged: (newPage) => setState(() => _currentPage = newPage),
                  onPageSizeChanged: (newSize) => setState(() {
                    _pageSize = newSize;
                    _currentPage = 0;
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
