import '../../../core/widgets/erp_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/category_unit_model.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../shared/providers/app_state_providers.dart';

class CategoriesUnitsScreen extends ConsumerStatefulWidget {
  const CategoriesUnitsScreen({super.key});

  @override
  ConsumerState<CategoriesUnitsScreen> createState() => _CategoriesUnitsScreenState();
}

class _CategoriesUnitsScreenState extends ConsumerState<CategoriesUnitsScreen> {
  int _activeTab = 0; // 0: Item Categories, 1: Expense Categories, 2: Payment Modes, 3: Units of Measure
  String _searchQuery = '';

  // Pagination for each tab
  int _catCurrentPage = 0;
  int _catPageSize = 10;

  int _expCurrentPage = 0;
  int _expPageSize = 10;

  int _pmCurrentPage = 0;
  int _pmPageSize = 10;

  int _unitCurrentPage = 0;
  int _unitPageSize = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadCategories();
      ref.read(databaseServiceProvider).loadUnits();
      ref.read(databaseServiceProvider).loadExpenseCategories();
    });
  }

  // -------------------------------------------------------------
  // TAB 0: ITEM CATEGORIES DIALOGS
  // -------------------------------------------------------------
  void _openAddCategoryDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? serverError;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dlgCtx, setDlgState) {
            return AlertDialog(
              title: Text('Add Item Category', style: AppTextStyles.h2),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (serverError != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(serverError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      TextFormField(
                        controller: nameCtrl,
                        validator: (v) => Validators.requiredField(v, 'Category name required'),
                        decoration: const InputDecoration(labelText: 'Category Name *', hintText: 'E.g., Chandeliers & Pendants'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Description', hintText: 'Category scope and details'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ErpButton(
                  text: 'Cancel',
                  isOutlined: true,
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                ),
                ErpButton(
                  text: 'Save Category',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDlgState(() {
                            isSubmitting = true;
                            serverError = null;
                          });
                          final db = ref.read(databaseServiceProvider);
                          try {
                            await db.addCategoryAsync(
                              name: nameCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
ErpToast.showSuccess(context, 'Item category "${nameCtrl.text.trim()}" added successfully!');
                            }
                          } catch (e) {
                            setDlgState(() {
                              serverError = e.toString().replaceFirst('Exception: ', '');
                              isSubmitting = false;
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openEditCategoryDialog(ItemCategory category) {
    final nameCtrl = TextEditingController(text: category.name);
    final descCtrl = TextEditingController(text: category.description);
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? serverError;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dlgCtx, setDlgState) {
            return AlertDialog(
              title: Text('Edit Item Category', style: AppTextStyles.h2),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (serverError != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(serverError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      TextFormField(
                        controller: nameCtrl,
                        validator: (v) => Validators.requiredField(v, 'Category name required'),
                        decoration: const InputDecoration(labelText: 'Category Name *', hintText: 'E.g., Chandeliers & Pendants'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Description', hintText: 'Category scope and details'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ErpButton(
                  text: 'Cancel',
                  isOutlined: true,
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                ),
                ErpButton(
                  text: 'Update Category',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDlgState(() {
                            isSubmitting = true;
                            serverError = null;
                          });
                          final db = ref.read(databaseServiceProvider);
                          try {
                            await db.updateCategoryAsync(
                              id: category.id,
                              name: nameCtrl.text.trim(),
                              description: descCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
ErpToast.showSuccess(context, 'Category "${nameCtrl.text.trim()}" updated successfully!');
                            }
                          } catch (e) {
                            setDlgState(() {
                              serverError = e.toString().replaceFirst('Exception: ', '');
                              isSubmitting = false;
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 1: EXPENSE CATEGORIES DIALOGS
  // -------------------------------------------------------------
  void _openAddExpenseCategoryDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? serverError;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          title: Text('Add Expense Category', style: AppTextStyles.h2),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (serverError != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(serverError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  TextFormField(
                    controller: nameCtrl,
                    validator: (v) => Validators.requiredField(v, 'Category name required'),
                    decoration: const InputDecoration(labelText: 'Expense Category Name *', hintText: 'E.g., Site Scaffolding & Rigging'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description', hintText: 'Operational scope and usage description'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ErpButton(
              text: 'Cancel',
              isOutlined: true,
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
            ),
            ErpButton(
              text: 'Save Expense Category',
              isLoading: isSubmitting,
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDlgState(() {
                        isSubmitting = true;
                        serverError = null;
                      });
                      final messenger = ScaffoldMessenger.of(context);
                      final db = ref.read(databaseServiceProvider);
                      final name = nameCtrl.text.trim();
                      String cleanCode = name
                          .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
                          .replaceAll(RegExp(r'^_+|_+$'), '')
                          .toUpperCase();
                      if (cleanCode.isEmpty) {
                        cleanCode = 'EXP_${DateTime.now().millisecondsSinceEpoch}';
                      }
                      try {
                        await db.addExpenseCategoryAsync(
                          name: name,
                          code: cleanCode,
                          description: descCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
ErpToast.showSuccess(context, 'Expense category "$name" added successfully!');
                        }
                      } catch (e) {
                        setDlgState(() {
                          serverError = e.toString().replaceFirst('Exception: ', '');
                          isSubmitting = false;
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _openEditExpenseCategoryDialog(ExpenseCategoryMasterItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final descCtrl = TextEditingController(text: item.description);
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? serverError;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          title: Text('Edit Expense Category', style: AppTextStyles.h2),
          content: SizedBox(
            width: 440,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (serverError != null) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(serverError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  TextFormField(
                    controller: nameCtrl,
                    validator: (v) => Validators.requiredField(v, 'Category name required'),
                    decoration: const InputDecoration(labelText: 'Expense Category Name *'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ErpButton(
              text: 'Cancel',
              isOutlined: true,
              onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
            ),
            ErpButton(
              text: 'Update Category',
              isLoading: isSubmitting,
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDlgState(() {
                        isSubmitting = true;
                        serverError = null;
                      });
                      final messenger = ScaffoldMessenger.of(context);
                      final db = ref.read(databaseServiceProvider);
                      final name = nameCtrl.text.trim();
                      String cleanCode = item.code.isNotEmpty
                          ? item.code
                          : name
                              .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
                              .replaceAll(RegExp(r'^_+|_+$'), '')
                              .toUpperCase();
                      if (cleanCode.isEmpty) {
                        cleanCode = 'EXP_${DateTime.now().millisecondsSinceEpoch}';
                      }
                      try {
                        await db.updateExpenseCategoryAsync(
                          id: item.id,
                          name: name,
                          code: cleanCode,
                          description: descCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.of(ctx).pop();
                        if (mounted) {
ErpToast.showSuccess(context, 'Expense category "$name" updated successfully!');
                        }
                      } catch (e) {
                        setDlgState(() {
                          serverError = e.toString().replaceFirst('Exception: ', '');
                          isSubmitting = false;
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 2: PAYMENT MODES DIALOGS
  // -------------------------------------------------------------
  void _openAddPaymentModeDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Payment Mode', style: AppTextStyles.h2),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  validator: (v) => Validators.requiredField(v, 'Payment mode name required'),
                  decoration: const InputDecoration(labelText: 'Payment Mode Name *', hintText: 'E.g., Bank Transfer / NEFT / RTGS'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description', hintText: 'Settlement rules and tracking details'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ErpButton(
            text: 'Cancel',
            isOutlined: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ErpButton(
            text: 'Save Payment Mode',
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final messenger = ScaffoldMessenger.of(context);
              final db = ref.read(databaseServiceProvider);
              final name = nameCtrl.text.trim();
              final code = name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toUpperCase();
              await db.addPaymentModeAsync(
                name: name,
                code: code,
                type: 'General',
                description: descCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
ErpToast.showSuccess(context, 'Payment mode "$name" added successfully!');
              }
            },
          ),
        ],
      ),
    );
  }

  void _openEditPaymentModeDialog(PaymentModeMasterItem item) {
    final nameCtrl = TextEditingController(text: item.name);
    final descCtrl = TextEditingController(text: item.description);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Payment Mode', style: AppTextStyles.h2),
        content: SizedBox(
          width: 440,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  validator: (v) => Validators.requiredField(v, 'Payment mode name required'),
                  decoration: const InputDecoration(labelText: 'Payment Mode Name *'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ErpButton(
            text: 'Cancel',
            isOutlined: true,
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ErpButton(
            text: 'Update Payment Mode',
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final messenger = ScaffoldMessenger.of(context);
              final db = ref.read(databaseServiceProvider);
              final name = nameCtrl.text.trim();
              final code = item.code.isNotEmpty ? item.code : name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_').toUpperCase();
              await db.updatePaymentModeAsync(
                id: item.id,
                name: name,
                code: code,
                type: item.type,
                description: descCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
ErpToast.showSuccess(context, 'Payment mode "$name" updated successfully!');
              }
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 3: UNITS OF MEASURE DIALOGS
  // -------------------------------------------------------------
  void _openAddUnitDialog() {
    final nameCtrl = TextEditingController();
    final symbolCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? serverError;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dlgCtx, setDlgState) {
            return AlertDialog(
              title: Text('Add Measurement Unit', style: AppTextStyles.h2),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (serverError != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(serverError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      TextFormField(
                        controller: nameCtrl,
                        validator: (v) => Validators.requiredField(v, 'Unit name required'),
                        decoration: const InputDecoration(labelText: 'Unit Name *', hintText: 'E.g., Square Feet / Bundles'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: symbolCtrl,
                        validator: (v) => Validators.requiredField(v, 'Symbol required'),
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Symbol *', hintText: 'E.g., SQFT / BDL'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ErpButton(
                  text: 'Cancel',
                  isOutlined: true,
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                ),
                ErpButton(
                  text: 'Save Unit',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDlgState(() {
                            isSubmitting = true;
                            serverError = null;
                          });
                          final db = ref.read(databaseServiceProvider);
                          try {
                            await db.addUnitAsync(
                              name: nameCtrl.text.trim(),
                              symbol: symbolCtrl.text.trim().toUpperCase(),
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
ErpToast.showSuccess(context, 'Unit "${symbolCtrl.text.trim().toUpperCase()}" added successfully!');
                            }
                          } catch (e) {
                            setDlgState(() {
                              serverError = e.toString().replaceFirst('Exception: ', '');
                              isSubmitting = false;
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openEditUnitDialog(MeasurementUnit unit) {
    final nameCtrl = TextEditingController(text: unit.name);
    final symbolCtrl = TextEditingController(text: unit.symbol);
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;
    String? serverError;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dlgCtx, setDlgState) {
            return AlertDialog(
              title: Text('Edit Measurement Unit', style: AppTextStyles.h2),
              content: SizedBox(
                width: 440,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (serverError != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(serverError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.danger)),
                              ),
                            ],
                          ),
                        ),
                      ],
                      TextFormField(
                        controller: nameCtrl,
                        validator: (v) => Validators.requiredField(v, 'Unit name required'),
                        decoration: const InputDecoration(labelText: 'Unit Name *', hintText: 'E.g., Meters / Pieces / Kilograms'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: symbolCtrl,
                        validator: (v) => Validators.requiredField(v, 'Symbol required'),
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(labelText: 'Symbol *', hintText: 'E.g., MTR / PCS / KG'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ErpButton(
                  text: 'Cancel',
                  isOutlined: true,
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                ),
                ErpButton(
                  text: 'Update Unit',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDlgState(() {
                            isSubmitting = true;
                            serverError = null;
                          });
                          final db = ref.read(databaseServiceProvider);
                          try {
                            await db.updateUnitAsync(
                              id: unit.id,
                              name: nameCtrl.text.trim(),
                              symbol: symbolCtrl.text.trim().toUpperCase(),
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
ErpToast.showSuccess(context, 'Unit "${symbolCtrl.text.trim().toUpperCase()}" updated successfully!');
                            }
                          } catch (e) {
                            setDlgState(() {
                              serverError = e.toString().replaceFirst('Exception: ', '');
                              isSubmitting = false;
                            });
                          }
                        },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final query = _searchQuery.trim().toLowerCase();

    // 1. Item Categories
    final categories = db.categories.where((c) {
      return query.isEmpty ||
          c.name.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query);
    }).toList();

    // 2. Expense Categories
    final expenseCategories = db.expenseCategoryMasterList.where((e) {
      return query.isEmpty ||
          e.name.toLowerCase().contains(query) ||
          e.code.toLowerCase().contains(query) ||
          e.description.toLowerCase().contains(query);
    }).toList();

    // 3. Payment Modes
    final paymentModes = db.paymentModeMasterList.where((p) {
      return query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.code.toLowerCase().contains(query) ||
          p.type.toLowerCase().contains(query) ||
          p.description.toLowerCase().contains(query);
    }).toList();

    // 4. Units
    final units = db.units.where((u) {
      return query.isEmpty ||
          u.name.toLowerCase().contains(query) ||
          u.symbol.toLowerCase().contains(query);
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.category_rounded,
            title: 'Category & Unit Masters',
            badgeText: 'TAXONOMY & ATTRIBUTES',
          ),
          const SizedBox(height: 20),

          // Top Modern Segmented Tab Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTabButton(
                  index: 0,
                  label: 'Item Categories',
                  count: db.categories.length,
                  icon: Icons.category_outlined,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  index: 1,
                  label: 'Expense Categories',
                  count: db.expenseCategoryMasterList.length,
                  icon: Icons.receipt_long_outlined,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  index: 2,
                  label: 'Payment Modes',
                  count: db.paymentModeMasterList.length,
                  icon: Icons.payments_outlined,
                ),
                const SizedBox(width: 8),
                _buildTabButton(
                  index: 3,
                  label: 'Units of Measure',
                  count: db.units.length,
                  icon: Icons.straighten_outlined,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Search Input Bar
          SizedBox(
            width: 380,
            child: ErpSearchInput(
              hintText: _getSearchHint(),
              initialValue: _searchQuery,
              onChanged: (val) => setState(() {
                _searchQuery = val;
                _catCurrentPage = 0;
                _expCurrentPage = 0;
                _pmCurrentPage = 0;
                _unitCurrentPage = 0;
              }),
            ),
          ),
          const SizedBox(height: 18),

          // Active Tab Content
          if (_activeTab == 0)
            _buildItemCategoriesTab(context, db, categories)
          else if (_activeTab == 1)
            _buildExpenseCategoriesTab(context, db, expenseCategories)
          else if (_activeTab == 2)
            _buildPaymentModesTab(context, db, paymentModes)
          else
            _buildUnitsTab(context, db, units),
        ],
      ),
    );
  }

  String _getSearchHint() {
    switch (_activeTab) {
      case 0:
        return 'Search item categories by name, scope...';
      case 1:
        return 'Search expense categories by name, code...';
      case 2:
        return 'Search payment modes by name, instrument...';
      case 3:
      default:
        return 'Search measurement units by name, symbol...';
    }
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required int count,
    required IconData icon,
  }) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() {
        _activeTab = index;
        _searchQuery = '';
      }),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.22) : AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // TAB 0: ITEM CATEGORIES CONTENT
  // -------------------------------------------------------------
  Widget _buildItemCategoriesTab(BuildContext context, dynamic db, List<ItemCategory> categories) {
    final totalRecords = categories.length;
    final safePageSize = _catPageSize <= 0 ? 10 : _catPageSize;
    final totalPages = (totalRecords <= 0) ? 1 : (totalRecords / safePageSize).ceil();
    final maxPage = totalPages > 0 ? totalPages - 1 : 0;
    final safeCurrentPage = _catCurrentPage.clamp(0, maxPage);
    final startIndex = safeCurrentPage * safePageSize;
    final endIndex = (startIndex + safePageSize).clamp(0, totalRecords);
    final pagedCategories = totalRecords == 0 ? <ItemCategory>[] : categories.sublist(startIndex, endIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0 ? constraints.maxWidth : 1000.0;
        final nameWidth = 260.0;
        final actionsWidth = 90.0;
        final tableOverhead = 112.0;
        final descWidth = (availableWidth - nameWidth - actionsWidth - tableOverhead).clamp(240.0, double.infinity);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item Categories (${categories.length})',
                  style: AppTextStyles.h3,
                ),
                ErpButton(
                  text: 'Add Category',
                  icon: Icons.add,
                  onPressed: _openAddCategoryDialog,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ErpDataTable(
              columns: const [
                ErpColumn(title: 'Category Name'),
                ErpColumn(title: 'Description'),
                ErpColumn(title: 'Actions', width: 90, alignment: Alignment.center),
              ],
              rows: pagedCategories.map((c) {
                return [
                  SizedBox(
                    width: nameWidth,
                    child: Text(
                      c.name,
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: const Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: descWidth,
                    child: Text(
                      c.description.trim().isNotEmpty ? c.description : '-',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: actionsWidth,
                    child: Center(
                      child: PopupMenuButton<String>(
                        tooltip: 'Actions',
                        icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (action) {
                          if (action == 'edit') {
                            _openEditCategoryDialog(c);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Text('Edit Category'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              }).toList(),
            ),
            const SizedBox(height: 14),
            ErpPaginationBar(
              currentPage: safeCurrentPage,
              pageSize: safePageSize,
              totalRecords: totalRecords,
              pageSizeOptions: const [5, 10, 20, 50],
              onPageChanged: (newPage) => setState(() => _catCurrentPage = newPage),
              onPageSizeChanged: (newSize) => setState(() {
                _catPageSize = newSize;
                _catCurrentPage = 0;
              }),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 1: EXPENSE CATEGORIES CONTENT
  // -------------------------------------------------------------
  Widget _buildExpenseCategoriesTab(BuildContext context, dynamic db, List<ExpenseCategoryMasterItem> expenseCategories) {
    final totalRecords = expenseCategories.length;
    final safePageSize = _expPageSize <= 0 ? 10 : _expPageSize;
    final totalPages = (totalRecords <= 0) ? 1 : (totalRecords / safePageSize).ceil();
    final maxPage = totalPages > 0 ? totalPages - 1 : 0;
    final safeCurrentPage = _expCurrentPage.clamp(0, maxPage);
    final startIndex = safeCurrentPage * safePageSize;
    final endIndex = (startIndex + safePageSize).clamp(0, totalRecords);
    final pagedExpenses = totalRecords == 0 ? <ExpenseCategoryMasterItem>[] : expenseCategories.sublist(startIndex, endIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0 ? constraints.maxWidth : 1000.0;
        final nameWidth = 260.0;
        final actionsWidth = 90.0;
        final tableOverhead = 112.0;
        final descWidth = (availableWidth - nameWidth - actionsWidth - tableOverhead).clamp(240.0, double.infinity);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Expense Categories (${expenseCategories.length})',
                  style: AppTextStyles.h3,
                ),
                ErpButton(
                  text: 'Add Expense Category',
                  icon: Icons.add,
                  onPressed: _openAddExpenseCategoryDialog,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ErpDataTable(
              columns: const [
                ErpColumn(title: 'Category Name'),
                ErpColumn(title: 'Description'),
                ErpColumn(title: 'Actions', width: 90, alignment: Alignment.center),
              ],
              rows: pagedExpenses.map((exp) {
                return [
                  SizedBox(
                    width: nameWidth,
                    child: Text(
                      exp.name,
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: const Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: descWidth,
                    child: Text(
                      exp.description.trim().isNotEmpty ? exp.description : '-',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: actionsWidth,
                    child: Center(
                      child: PopupMenuButton<String>(
                        tooltip: 'Actions',
                        icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (action) {
                          if (action == 'edit') {
                            _openEditExpenseCategoryDialog(exp);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Text('Edit Expense Category'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              }).toList(),
            ),
            const SizedBox(height: 14),
            ErpPaginationBar(
              currentPage: safeCurrentPage,
              pageSize: safePageSize,
              totalRecords: totalRecords,
              pageSizeOptions: const [5, 10, 20, 50],
              onPageChanged: (newPage) => setState(() => _expCurrentPage = newPage),
              onPageSizeChanged: (newSize) => setState(() {
                _expPageSize = newSize;
                _expCurrentPage = 0;
              }),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 2: PAYMENT MODES CONTENT
  // -------------------------------------------------------------
  Widget _buildPaymentModesTab(BuildContext context, dynamic db, List<PaymentModeMasterItem> paymentModes) {
    final totalRecords = paymentModes.length;
    final safePageSize = _pmPageSize <= 0 ? 10 : _pmPageSize;
    final totalPages = (totalRecords <= 0) ? 1 : (totalRecords / safePageSize).ceil();
    final maxPage = totalPages > 0 ? totalPages - 1 : 0;
    final safeCurrentPage = _pmCurrentPage.clamp(0, maxPage);
    final startIndex = safeCurrentPage * safePageSize;
    final endIndex = (startIndex + safePageSize).clamp(0, totalRecords);
    final pagedPaymentModes = totalRecords == 0 ? <PaymentModeMasterItem>[] : paymentModes.sublist(startIndex, endIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0 ? constraints.maxWidth : 1000.0;
        final nameWidth = 260.0;
        final actionsWidth = 90.0;
        final tableOverhead = 112.0;
        final descWidth = (availableWidth - nameWidth - actionsWidth - tableOverhead).clamp(240.0, double.infinity);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Modes (${paymentModes.length})',
                  style: AppTextStyles.h3,
                ),
                ErpButton(
                  text: 'Add Payment Mode',
                  icon: Icons.add,
                  onPressed: _openAddPaymentModeDialog,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ErpDataTable(
              columns: const [
                ErpColumn(title: 'Payment Mode Name'),
                ErpColumn(title: 'Description'),
                ErpColumn(title: 'Actions', width: 90, alignment: Alignment.center),
              ],
              rows: pagedPaymentModes.map((pm) {
                return [
                  SizedBox(
                    width: nameWidth,
                    child: Text(
                      pm.name,
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: const Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: descWidth,
                    child: Text(
                      pm.description.trim().isNotEmpty ? pm.description : '-',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: actionsWidth,
                    child: Center(
                      child: PopupMenuButton<String>(
                        tooltip: 'Actions',
                        icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (action) {
                          if (action == 'edit') {
                            _openEditPaymentModeDialog(pm);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Text('Edit Payment Mode'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              }).toList(),
            ),
            const SizedBox(height: 14),
            ErpPaginationBar(
              currentPage: safeCurrentPage,
              pageSize: safePageSize,
              totalRecords: totalRecords,
              pageSizeOptions: const [5, 10, 20, 50],
              onPageChanged: (newPage) => setState(() => _pmCurrentPage = newPage),
              onPageSizeChanged: (newSize) => setState(() {
                _pmPageSize = newSize;
                _pmCurrentPage = 0;
              }),
            ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // TAB 3: UNITS OF MEASURE CONTENT
  // -------------------------------------------------------------
  Widget _buildUnitsTab(BuildContext context, dynamic db, List<MeasurementUnit> units) {
    final totalRecords = units.length;
    final safePageSize = _unitPageSize <= 0 ? 10 : _unitPageSize;
    final totalPages = (totalRecords <= 0) ? 1 : (totalRecords / safePageSize).ceil();
    final maxPage = totalPages > 0 ? totalPages - 1 : 0;
    final safeCurrentPage = _unitCurrentPage.clamp(0, maxPage);
    final startIndex = safeCurrentPage * safePageSize;
    final endIndex = (startIndex + safePageSize).clamp(0, totalRecords);
    final pagedUnits = totalRecords == 0 ? <MeasurementUnit>[] : units.sublist(startIndex, endIndex);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0 ? constraints.maxWidth : 1000.0;
        final nameWidth = 320.0;
        final actionsWidth = 90.0;
        final tableOverhead = 112.0;
        final symbolColWidth = (availableWidth - nameWidth - actionsWidth - tableOverhead).clamp(240.0, double.infinity);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Units of Measure (${units.length})',
                  style: AppTextStyles.h3,
                ),
                ErpButton(
                  text: 'Add Unit',
                  icon: Icons.add,
                  onPressed: _openAddUnitDialog,
                ),
              ],
            ),
            const SizedBox(height: 14),
            ErpDataTable(
              columns: const [
                ErpColumn(title: 'Unit Name'),
                ErpColumn(title: 'Standard Symbol'),
                ErpColumn(title: 'Actions', width: 90, alignment: Alignment.center),
              ],
              rows: pagedUnits.map((u) {
                return [
                  SizedBox(
                    width: nameWidth,
                    child: Text(
                      u.name,
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: const Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: symbolColWidth,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          u.symbol,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: actionsWidth,
                    child: Center(
                      child: PopupMenuButton<String>(
                        tooltip: 'Actions',
                        icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (action) {
                          if (action == 'edit') {
                            _openEditUnitDialog(u);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Text('Edit Unit'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              }).toList(),
            ),
            const SizedBox(height: 14),
            ErpPaginationBar(
              currentPage: safeCurrentPage,
              pageSize: safePageSize,
              totalRecords: totalRecords,
              pageSizeOptions: const [5, 10, 20, 50],
              onPageChanged: (newPage) => setState(() => _unitCurrentPage = newPage),
              onPageSizeChanged: (newSize) => setState(() {
                _unitPageSize = newSize;
                _unitCurrentPage = 0;
              }),
            ),
          ],
        );
      },
    );
  }
}
