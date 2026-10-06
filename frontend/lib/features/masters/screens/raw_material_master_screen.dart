import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/raw_material_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

class RawMaterialMasterScreen extends ConsumerStatefulWidget {
  const RawMaterialMasterScreen({super.key});

  @override
  ConsumerState<RawMaterialMasterScreen> createState() => _RawMaterialMasterScreenState();
}

class _RawMaterialMasterScreenState extends ConsumerState<RawMaterialMasterScreen> {
  String _searchQuery = '';
  String? _selectedCategoryFilter;
  bool _lowStockOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadRawMaterials();
      ref.read(databaseServiceProvider).loadCategories();
      ref.read(databaseServiceProvider).loadUnits();
      ref.read(databaseServiceProvider).loadVendors();
    });
  }

  void _openAddEditDialog([RawMaterial? existing]) {
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(
      text: existing?.itemCode ?? 'RAW-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    );
    final stockCtrl = TextEditingController(
      text: isEdit ? existing.currentStock.toString() : '0',
    );
    final priceCtrl = TextEditingController(
      text: existing?.defaultPurchasePrice.toString() ?? '100',
    );
    final minCtrl = TextEditingController(
      text: existing?.minimumStock.toString() ?? '10',
    );

    String selectedCategory = (existing?.categoryId != null && db.categories.any((c) => c.id == existing!.categoryId))
        ? existing!.categoryId
        : (db.categories.isNotEmpty ? db.categories.first.id : '');
    String selectedUnitId = (existing?.unitId != null && db.units.any((u) => u.id == existing!.unitId))
        ? existing!.unitId!
        : (db.units.isNotEmpty ? db.units.first.id : '');
    String? selectedVendorId = (existing?.preferredVendorIds.isNotEmpty == true &&
            db.vendors.any((v) => v.id == existing!.preferredVendorIds.first))
        ? existing!.preferredVendorIds.first
        : null;
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
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Text(isEdit ? 'Edit Raw Material' : 'Raw Material Entry', style: AppTextStyles.h2),
              content: Container(
                constraints: const BoxConstraints(maxWidth: 580),
                width: double.infinity,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
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
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 500;
                            if (isNarrow) {
                              return Column(
                                children: [
                                  TextFormField(
                                    controller: nameCtrl,
                                    validator: (v) => Validators.requiredField(v, 'Material name required'),
                                    decoration: const InputDecoration(
                                      labelText: 'Material Name *',
                                      hintText: 'E.g., Aluminum Profile 6063',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: codeCtrl,
                                    validator: (v) => Validators.requiredField(v, 'SKU / Code required'),
                                    decoration: const InputDecoration(
                                      labelText: 'SKU / Code *',
                                      hintText: 'E.g., RAW-ALU-01',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: selectedCategory.isNotEmpty ? selectedCategory : null,
                                    decoration: const InputDecoration(labelText: 'Category *'),
                                    items: db.categories.map((c) {
                                      return DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis));
                                    }).toList(),
                                    onChanged: isSubmitting ? null : (val) {
                                      if (val != null) setDlgState(() => selectedCategory = val);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    initialValue: selectedUnitId.isNotEmpty ? selectedUnitId : null,
                                    decoration: const InputDecoration(labelText: 'Unit of Measurement (UOM) *'),
                                    items: db.units.map((u) {
                                      return DropdownMenuItem(value: u.id, child: Text('${u.name} (${u.symbol})', overflow: TextOverflow.ellipsis));
                                    }).toList(),
                                    onChanged: isSubmitting ? null : (val) {
                                      if (val != null) setDlgState(() => selectedUnitId = val);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: priceCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.positiveNumber,
                                    decoration: const InputDecoration(
                                      labelText: 'Unit Price (₹) *',
                                      hintText: 'Purchase price per unit',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: stockCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.nonNegativeNumber,
                                    decoration: const InputDecoration(
                                      labelText: 'Current Stock *',
                                      hintText: 'Available inventory count',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: minCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.nonNegativeNumber,
                                    decoration: const InputDecoration(
                                      labelText: 'Min Level *',
                                      hintText: 'Threshold trigger',
                                    ),
                                  ),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextFormField(
                                        controller: nameCtrl,
                                        validator: (v) => Validators.requiredField(v, 'Material name required'),
                                        decoration: const InputDecoration(
                                          labelText: 'Material Name *',
                                          hintText: 'E.g., Aluminum Profile 6063',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: TextFormField(
                                        controller: codeCtrl,
                                        validator: (v) => Validators.requiredField(v, 'SKU / Code required'),
                                        decoration: const InputDecoration(
                                          labelText: 'SKU / Code *',
                                          hintText: 'E.g., RAW-ALU-01',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        initialValue: selectedCategory.isNotEmpty ? selectedCategory : null,
                                        decoration: const InputDecoration(labelText: 'Category *'),
                                        items: db.categories.map((c) {
                                          return DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis));
                                        }).toList(),
                                        onChanged: isSubmitting ? null : (val) {
                                          if (val != null) setDlgState(() => selectedCategory = val);
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        initialValue: selectedUnitId.isNotEmpty ? selectedUnitId : null,
                                        decoration: const InputDecoration(labelText: 'Unit of Measurement (UOM) *'),
                                        items: db.units.map((u) {
                                          return DropdownMenuItem(value: u.id, child: Text('${u.name} (${u.symbol})', overflow: TextOverflow.ellipsis));
                                        }).toList(),
                                        onChanged: isSubmitting ? null : (val) {
                                          if (val != null) setDlgState(() => selectedUnitId = val);
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
                                        controller: priceCtrl,
                                        keyboardType: TextInputType.number,
                                        validator: Validators.positiveNumber,
                                        decoration: const InputDecoration(
                                          labelText: 'Unit Price (₹) *',
                                          hintText: 'Purchase price per unit',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: stockCtrl,
                                        keyboardType: TextInputType.number,
                                        validator: Validators.nonNegativeNumber,
                                        decoration: const InputDecoration(
                                          labelText: 'Current Stock *',
                                          hintText: 'Available inventory count',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: minCtrl,
                                        keyboardType: TextInputType.number,
                                        validator: Validators.nonNegativeNumber,
                                        decoration: const InputDecoration(
                                          labelText: 'Min Level *',
                                          hintText: 'Threshold trigger',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),

                        // Supplier / Vendor Info
                        DropdownButtonFormField<String?>(
                          isExpanded: true,
                          initialValue: selectedVendorId,
                          decoration: const InputDecoration(
                            labelText: 'Preferred Supplier / Vendor',
                            hintText: 'Select default procurement source',
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('No Preferred Vendor Assigned', overflow: TextOverflow.ellipsis)),
                            ...db.vendors.where((v) => !v.isDeleted).map((v) {
                              return DropdownMenuItem(value: v.id, child: Text('${v.name} (${v.id})', overflow: TextOverflow.ellipsis));
                            }),
                          ],
                          onChanged: isSubmitting ? null : (val) => setDlgState(() => selectedVendorId = val),
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
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                ),
                ErpButton(
                  text: isEdit ? 'Update Material' : 'Save Material',
                  isLoading: isSubmitting,
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDlgState(() {
                            isSubmitting = true;
                            serverError = null;
                          });

                          final stockVal = double.tryParse(stockCtrl.text.trim()) ?? 0.0;
                          final minVal = double.tryParse(minCtrl.text.trim()) ?? 0.0;
                          final priceVal = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                          final catObj = db.categories.firstWhere(
                            (c) => c.id == selectedCategory,
                            orElse: () => db.categories.first,
                          );
                          final unitObj = db.units.firstWhere(
                            (u) => u.id == selectedUnitId,
                            orElse: () => db.units.first,
                          );
                          final prefVendor = selectedVendorId != null
                              ? db.vendors.firstWhere((v) => v.id == selectedVendorId)
                              : null;
                          final prefVendorIds = prefVendor != null ? [prefVendor.id] : <String>[];
                          final prefVendorNames = prefVendor != null ? [prefVendor.name] : <String>[];

                          try {
                            if (isEdit) {
                              await db.updateRawMaterialAsync(existing.copyWith(
                                name: nameCtrl.text.trim(),
                                itemCode: codeCtrl.text.trim(),
                                categoryId: catObj.id,
                                categoryName: catObj.name,
                                unitId: unitObj.id,
                                unit: unitObj.symbol,
                                currentStock: stockVal,
                                minimumStock: minVal,
                                defaultPurchasePrice: priceVal,
                                preferredVendorIds: prefVendorIds,
                                preferredVendorNames: prefVendorNames,
                                updatedAt: DateTime.now(),
                              ));
                            } else {
                              final newRm = RawMaterial(
                                id: IdGenerator.generateId('RM'),
                                name: nameCtrl.text.trim(),
                                itemCode: codeCtrl.text.trim(),
                                categoryId: catObj.id,
                                categoryName: catObj.name,
                                unitId: unitObj.id,
                                unit: unitObj.symbol,
                                currentStock: stockVal,
                                openingStock: stockVal,
                                minimumStock: minVal,
                                reorderLevel: minVal * 1.5,
                                defaultPurchasePrice: priceVal,
                                gstPercent: 18.0,
                                preferredVendorIds: prefVendorIds,
                                preferredVendorNames: prefVendorNames,
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                              );
                              await db.addRawMaterialAsync(newRm);
                            }

                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEdit ? 'Raw material updated successfully!' : 'Raw material created successfully!'),
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

  void _confirmDelete(RawMaterial rm) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Delete Raw Material', style: AppTextStyles.h2),
          content: Text(
            'Are you sure you want to delete "${rm.name}" (${rm.itemCode})? This cannot be undone.',
            style: AppTextStyles.bodyMedium,
          ),
          actions: [
            ErpButton(
              text: 'Cancel',
              isOutlined: true,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            ErpButton(
              text: 'Delete',
              isDanger: true,
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  await ref.read(databaseServiceProvider).deleteRawMaterialAsync(rm.id);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Raw material "${rm.name}" deleted successfully!'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete "${rm.name}": $e'), backgroundColor: AppColors.danger),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final materials = db.rawMaterials.where((rm) {
      if (rm.isDeleted) return false;
      final query = _searchQuery.trim().toLowerCase();
      return query.isEmpty ||
          rm.name.toLowerCase().contains(query) ||
          rm.itemCode.toLowerCase().contains(query) ||
          rm.categoryName.toLowerCase().contains(query) ||
          rm.unit.toLowerCase().contains(query) ||
          rm.preferredVendorNames.any((v) => v.toLowerCase().contains(query));
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        Text('Raw Material Master', style: AppTextStyles.h1),
                        const SizedBox(height: 4),
                        Text(
                          'Configure raw materials, specifications, pricing, UOM, and supplier information',
                          style: AppTextStyles.subtitle,
                        ),
                      ],
                    ),
                  ),
                  ErpButton(
                    text: 'Add Raw Material',
                    icon: Icons.add,
                    onPressed: () => _openAddEditDialog(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'Search raw materials by name, SKU/code, category, UOM, or vendor...',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          const SizedBox(height: 20),

          // Data Table
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'SKU / Code'),
              ErpColumn(title: 'Material Name'),
              ErpColumn(title: 'Category'),
              ErpColumn(title: 'UOM'),
              ErpColumn(title: 'Unit Price (₹)', isNumeric: true),
              ErpColumn(title: 'Current Stock', isNumeric: true),
              ErpColumn(title: 'Supplier / Vendor'),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Actions'),
            ],
            rows: materials.map((rm) {
              final vendorDisplay = rm.preferredVendorNames.isNotEmpty
                  ? rm.preferredVendorNames.join(', ')
                  : 'Unassigned';

              return [
                Text(rm.itemCode, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                Text(rm.name, style: AppTextStyles.bodyBold),
                Text(rm.categoryName, style: AppTextStyles.bodySmall),
                Text(rm.unit, style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                Text(Formatters.formatCurrency(rm.defaultPurchasePrice), style: AppTextStyles.bodyMedium),
                Text(
                  '${Formatters.formatNumber(rm.currentStock)} ${rm.unit}',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: rm.isLowStock ? AppColors.dangerText : AppColors.textPrimary,
                  ),
                ),
                Text(vendorDisplay, style: AppTextStyles.bodySmall),
                rm.isLowStock
                    ? ErpStatusBadge.danger('LOW STOCK')
                    : ErpStatusBadge.success('AVAILABLE'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Material',
                      onPressed: () => _openAddEditDialog(rm),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                      tooltip: 'Delete Material',
                      onPressed: () => _confirmDelete(rm),
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
