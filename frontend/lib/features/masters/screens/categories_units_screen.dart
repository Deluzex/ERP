import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/category_unit_model.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../shared/providers/app_state_providers.dart';

class CategoriesUnitsScreen extends ConsumerStatefulWidget {
  const CategoriesUnitsScreen({super.key});

  @override
  ConsumerState<CategoriesUnitsScreen> createState() => _CategoriesUnitsScreenState();
}

class _CategoriesUnitsScreenState extends ConsumerState<CategoriesUnitsScreen> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadCategories();
      ref.read(databaseServiceProvider).loadUnits();
    });
  }

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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Category "${nameCtrl.text.trim()}" created successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Unit "${symbolCtrl.text.trim().toUpperCase()}" created successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Category "${nameCtrl.text.trim()}" updated successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Unit "${symbolCtrl.text.trim().toUpperCase()}" updated successfully!'),
                                  backgroundColor: AppColors.success,
                                ),
                              );
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

    final categories = db.categories.where((c) {
      return query.isEmpty ||
          c.name.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query);
    }).toList();

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
          Text('Categories & Measurement Units', style: AppTextStyles.h1),
          const SizedBox(height: 4),
          Text('Configure product classifications and standardized measurement units (PCS, MTR, KG, etc.)', style: AppTextStyles.subtitle),
          const SizedBox(height: 24),

          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search categories and units by name, symbol or description...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              final hasBoundedWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0;
              final availableWidth = hasBoundedWidth ? constraints.maxWidth : 1000.0;
              final nameColWidth = 260.0;
              final descColWidth = (availableWidth - nameColWidth - 170.0).clamp(240.0, double.infinity);

              final categoriesSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Item Categories (${categories.length})',
                          style: AppTextStyles.h3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ErpButton(
                        text: 'Add Category',
                        icon: Icons.add,
                        isOutlined: true,
                        onPressed: _openAddCategoryDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ErpDataTable(
                    columns: const [
                      ErpColumn(title: 'Category Name'),
                      ErpColumn(title: 'Description'),
                      ErpColumn(title: 'Actions'),
                    ],
                    rows: categories.map((c) {
                      return [
                        SizedBox(
                          width: nameColWidth,
                          child: Text(c.name, style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        SizedBox(
                          width: descColWidth,
                          child: Text(
                            c.description.trim().isNotEmpty ? c.description : '-',
                            style: AppTextStyles.bodySmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit Category',
                              onPressed: () => _openEditCategoryDialog(c),
                            ),
                          ],
                        ),
                      ];
                    }).toList(),
                  ),
                ],
              );

              final unitsSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Units of Measure (${units.length})',
                          style: AppTextStyles.h3,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ErpButton(
                        text: 'Add Unit',
                        icon: Icons.add,
                        isOutlined: true,
                        onPressed: _openAddUnitDialog,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ErpDataTable(
                    columns: const [
                      ErpColumn(title: 'Unit Name'),
                      ErpColumn(title: 'Standard Symbol'),
                      ErpColumn(title: 'Actions'),
                    ],
                    rows: units.map((u) {
                      return [
                        SizedBox(
                          width: nameColWidth,
                          child: Text(u.name, style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        SizedBox(
                          width: descColWidth,
                          child: Text(u.symbol, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit Unit',
                              onPressed: () => _openEditUnitDialog(u),
                            ),
                          ],
                        ),
                      ];
                    }).toList(),
                  ),
                ],
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  categoriesSection,
                  const SizedBox(height: 36),
                  unitsSection,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
