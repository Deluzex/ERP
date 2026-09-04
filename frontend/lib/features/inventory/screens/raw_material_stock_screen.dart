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

class RawMaterialStockScreen extends ConsumerStatefulWidget {
  const RawMaterialStockScreen({super.key});

  @override
  ConsumerState<RawMaterialStockScreen> createState() => _RawMaterialStockScreenState();
}

class _RawMaterialStockScreenState extends ConsumerState<RawMaterialStockScreen> {
  String _searchQuery = '';
  bool _showOnlyLowStock = false;

  void _openAddEditDialog([RawMaterial? existing]) {
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(text: existing?.itemCode ?? 'RAW-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}');
    final stockCtrl = TextEditingController(text: existing?.currentStock.toString() ?? '0');
    final minCtrl = TextEditingController(text: existing?.minimumStock.toString() ?? '10');
    final priceCtrl = TextEditingController(text: existing?.defaultPurchasePrice.toString() ?? '100');
    String selectedCategory = existing?.categoryId ?? (db.categories.isNotEmpty ? db.categories.first.id : '');
    String selectedUnit = existing?.unit ?? (db.units.isNotEmpty ? db.units.first.symbol : 'PCS');
    String? selectedVendorId = existing?.preferredVendorIds.isNotEmpty == true ? existing!.preferredVendorIds.first : null;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Raw Material' : 'Add Raw Material', style: AppTextStyles.h2),
              content: SizedBox(
                width: 540,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          validator: (v) => Validators.requiredField(v, 'Material name required'),
                          decoration: const InputDecoration(labelText: 'Material Name *', hintText: 'E.g., Aluminum Profile 6063'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: codeCtrl,
                                validator: (v) => Validators.requiredField(v, 'Item code required'),
                                decoration: const InputDecoration(labelText: 'Item Code *', hintText: 'RAW-AL-01'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedCategory.isNotEmpty ? selectedCategory : null,
                                decoration: const InputDecoration(labelText: 'Category'),
                                items: db.categories.map((cat) {
                                  return DropdownMenuItem(value: cat.id, child: Text(cat.name, style: AppTextStyles.bodyMedium));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setDlgState(() => selectedCategory = val);
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: selectedUnit,
                                decoration: const InputDecoration(labelText: 'Unit'),
                                items: db.units.map((u) {
                                  return DropdownMenuItem(value: u.symbol, child: Text('${u.name} (${u.symbol})'));
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) setDlgState(() => selectedUnit = val);
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: stockCtrl,
                                keyboardType: TextInputType.number,
                                validator: Validators.nonNegativeNumber,
                                decoration: InputDecoration(labelText: isEdit ? 'Current Stock' : 'Opening Stock *'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: minCtrl,
                                keyboardType: TextInputType.number,
                                validator: Validators.nonNegativeNumber,
                                decoration: const InputDecoration(labelText: 'Minimum Stock Level *'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: priceCtrl,
                                keyboardType: TextInputType.number,
                                validator: Validators.nonNegativeNumber,
                                decoration: const InputDecoration(labelText: 'Default Purchase Price (₹) *'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          value: selectedVendorId,
                          decoration: const InputDecoration(labelText: 'Preferred Vendor'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('None')),
                            ...db.vendors.map((v) {
                              return DropdownMenuItem(value: v.id, child: Text(v.name));
                            }),
                          ],
                          onChanged: (val) => setDlgState(() => selectedVendorId = val),
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
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
                ErpButton(
                  text: isEdit ? 'Update Material' : 'Save Material',
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final stockVal = double.tryParse(stockCtrl.text.trim()) ?? 0.0;
                    final minVal = double.tryParse(minCtrl.text.trim()) ?? 0.0;
                    final priceVal = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                    final catObj = db.categories.firstWhere((c) => c.id == selectedCategory, orElse: () => db.categories.first);
                    final prefVendor = selectedVendorId != null
                        ? db.vendors.firstWhere((v) => v.id == selectedVendorId)
                        : null;
                    final prefVendorIds = prefVendor != null ? [prefVendor.id] : <String>[];
                    final prefVendorNames = prefVendor != null ? [prefVendor.name] : <String>[];

                    if (isEdit) {
                      db.updateRawMaterial(existing.copyWith(
                        name: nameCtrl.text.trim(),
                        itemCode: codeCtrl.text.trim(),
                        categoryId: catObj.id,
                        categoryName: catObj.name,
                        unit: selectedUnit,
                        currentStock: stockVal,
                        minimumStock: minVal,
                        defaultPurchasePrice: priceVal,
                        updatedAt: DateTime.now(),
                      ));
                    } else {
                      final newRm = RawMaterial(
                        id: IdGenerator.generateId('RM'),
                        name: nameCtrl.text.trim(),
                        itemCode: codeCtrl.text.trim(),
                        categoryId: catObj.id,
                        categoryName: catObj.name,
                        unit: selectedUnit,
                        currentStock: stockVal,
                        openingStock: stockVal,
                        minimumStock: minVal,
                        reorderLevel: minVal * 1.5,
                        defaultPurchasePrice: priceVal,
                        gstPercent: 18.0,
                        preferredVendorIds: [],
                        preferredVendorNames: [],
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      db.addRawMaterial(newRm);
                    }
                    Navigator.of(ctx).pop();
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
    final rawMaterials = db.rawMaterials.where((rm) {
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          rm.name.toLowerCase().contains(query) ||
          rm.itemCode.toLowerCase().contains(query) ||
          rm.categoryName.toLowerCase().contains(query) ||
          rm.unit.toLowerCase().contains(query) ||
          rm.preferredVendorNames.any((v) => v.toLowerCase().contains(query));
      final matchesLow = !_showOnlyLowStock || rm.isLowStock;
      return matchesSearch && matchesLow;
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Raw Material Stock', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Manage raw material quantities, thresholds, and valuations', style: AppTextStyles.subtitle),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filter bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: const InputDecoration(
                    hintText: 'Search raw material by name, code, category, or vendor...',
                    prefixIcon: Icon(Icons.search, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              FilterChip(
                label: Text('Low Stock Only (${db.lowStockRawMaterials.length})'),
                selected: _showOnlyLowStock,
                onSelected: (val) => setState(() => _showOnlyLowStock = val),
                selectedColor: AppColors.dangerLight,
                checkmarkColor: AppColors.dangerText,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Data Table
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'Item Code'),
              ErpColumn(title: 'Material Name'),
              ErpColumn(title: 'Category'),
              ErpColumn(title: 'Current Stock', isNumeric: true),
              ErpColumn(title: 'Min Stock', isNumeric: true),
              ErpColumn(title: 'Purchase Rate', isNumeric: true),
              ErpColumn(title: 'Total Value', isNumeric: true),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Actions'),
            ],
            rows: rawMaterials.map((rm) {
              return [
                Text(rm.itemCode, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                Text(rm.name, style: AppTextStyles.bodyMedium),
                Text(rm.categoryName, style: AppTextStyles.bodySmall),
                Text(
                  '${Formatters.formatNumber(rm.currentStock)} ${rm.unit}',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: rm.isLowStock ? AppColors.dangerText : AppColors.textPrimary,
                  ),
                ),
                Text('${Formatters.formatNumber(rm.minimumStock)} ${rm.unit}', style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(rm.defaultPurchasePrice), style: AppTextStyles.bodyMedium),
                Text(Formatters.formatCurrency(rm.totalValuation), style: AppTextStyles.bodyBold),
                rm.isLowStock ? ErpStatusBadge.danger('LOW STOCK') : ErpStatusBadge.success('IN STOCK'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Material',
                      onPressed: () => _openAddEditDialog(rm),
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
