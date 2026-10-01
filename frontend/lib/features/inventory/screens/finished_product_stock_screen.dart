import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/finished_product_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

class FinishedProductStockScreen extends ConsumerStatefulWidget {
  const FinishedProductStockScreen({super.key});

  @override
  ConsumerState<FinishedProductStockScreen> createState() => _FinishedProductStockScreenState();
}

// This is class ant
class _FinishedProductStockScreenState extends ConsumerState<FinishedProductStockScreen> {
  String _searchQuery = '';
  bool _showOnlyLowStock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadFinishedProducts();
    });
  }

  void _openEditDialog(FinishedProduct existing) {
    final db = ref.read(databaseServiceProvider);
    final nameCtrl = TextEditingController(text: existing.name);
    final codeCtrl = TextEditingController(text: existing.itemCode);
    final stockCtrl = TextEditingController(text: existing.currentStock.toString());
    final minCtrl = TextEditingController(text: existing.minimumStock.toString());
    final costCtrl = TextEditingController(text: existing.costPrice.toString());
    final dealerCtrl = TextEditingController(text: existing.dealerSellingPrice.toString());
    final custCtrl = TextEditingController(text: existing.customerSellingPrice.toString());
    String selectedCategory = existing.categoryId;
    String selectedUnit = existing.unit;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Text('Edit Finished Product', style: AppTextStyles.h2),
              content: Container(
                constraints: const BoxConstraints(maxWidth: 580),
                width: double.infinity,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          validator: (v) => Validators.requiredField(v, 'Product name required'),
                          decoration: const InputDecoration(labelText: 'Product Name *', hintText: 'E.g., Aarix Wall Sconce Light'),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 500;
                            if (isNarrow) {
                              return Column(
                                children: [
                                  TextFormField(
                                    controller: codeCtrl,
                                    validator: (v) => Validators.requiredField(v, 'Item code required'),
                                    decoration: const InputDecoration(labelText: 'SKU / Item Code *', hintText: 'DLX-WL-01'),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: selectedCategory.isNotEmpty ? selectedCategory : null,
                                    decoration: const InputDecoration(labelText: 'Category'),
                                    items: db.categories.map((cat) {
                                      return DropdownMenuItem(value: cat.id, child: Text(cat.name, style: AppTextStyles.bodyMedium));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setDlgState(() => selectedCategory = val);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    value: selectedUnit,
                                    decoration: const InputDecoration(labelText: 'Unit'),
                                    items: db.units.map((u) {
                                      return DropdownMenuItem(value: u.symbol, child: Text('${u.name} (${u.symbol})'));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setDlgState(() => selectedUnit = val);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: stockCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.nonNegativeNumber,
                                    decoration: const InputDecoration(labelText: 'Current Stock *'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: minCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.nonNegativeNumber,
                                    decoration: const InputDecoration(labelText: 'Min Stock Level *'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: costCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.positiveNumber,
                                    decoration: const InputDecoration(labelText: 'Cost Price (₹) *'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: dealerCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.positiveNumber,
                                    decoration: const InputDecoration(labelText: 'Dealer Price (₹) *'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: custCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.positiveNumber,
                                    decoration: const InputDecoration(labelText: 'Customer Price (₹) *'),
                                  ),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: codeCtrl,
                                        validator: (v) => Validators.requiredField(v, 'Item code required'),
                                        decoration: const InputDecoration(labelText: 'SKU / Item Code *', hintText: 'DLX-WL-01'),
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
                                        decoration: const InputDecoration(labelText: 'Current Stock *'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: minCtrl,
                                        keyboardType: TextInputType.number,
                                        validator: Validators.nonNegativeNumber,
                                        decoration: const InputDecoration(labelText: 'Min Stock Level *'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: costCtrl,
                                        keyboardType: TextInputType.number,
                                        validator: Validators.positiveNumber,
                                        decoration: const InputDecoration(labelText: 'Cost Price (₹) *'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: dealerCtrl,
                                        keyboardType: TextInputType.number,
                                        validator: Validators.positiveNumber,
                                        decoration: const InputDecoration(labelText: 'Dealer Price (₹) *'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: custCtrl,
                                        keyboardType: TextInputType.number,
                                        validator: Validators.positiveNumber,
                                        decoration: const InputDecoration(labelText: 'Customer Price (₹) *'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
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
                  text: 'Update Product',
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final stockVal = double.tryParse(stockCtrl.text.trim()) ?? 0.0;
                    final minVal = double.tryParse(minCtrl.text.trim()) ?? 0.0;
                    final costVal = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                    final dealerVal = double.tryParse(dealerCtrl.text.trim()) ?? 0.0;
                    final custVal = double.tryParse(custCtrl.text.trim()) ?? 0.0;
                    final catObj = db.categories.firstWhere((c) => c.id == selectedCategory, orElse: () => db.categories.first);

                    db.updateFinishedProductAsync(existing.copyWith(
                      name: nameCtrl.text.trim(),
                      itemCode: codeCtrl.text.trim(),
                      categoryId: catObj.id,
                      categoryName: catObj.name,
                      unit: selectedUnit,
                      currentStock: stockVal,
                      minimumStock: minVal,
                      costPrice: costVal,
                      dealerSellingPrice: dealerVal,
                      customerSellingPrice: custVal,
                      updatedAt: DateTime.now(),
                    ));
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Product updated successfully!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
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
    final products = db.finishedProducts.where((fp) {
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          fp.name.toLowerCase().contains(query) ||
          fp.itemCode.toLowerCase().contains(query) ||
          fp.categoryName.toLowerCase().contains(query) ||
          fp.unit.toLowerCase().contains(query);
      final matchesLow = !_showOnlyLowStock || fp.isLowStock;
      return matchesSearch && matchesLow;
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Finished Product Stock', style: AppTextStyles.h1),
              const SizedBox(height: 4),
              Text(
                'Manage finished goods catalog, multi-tier pricing, and stock levels',
                style: AppTextStyles.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filter bar
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              if (isSmall) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        hintText: 'Search product by name, SKU or category...',
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilterChip(
                      label: Text('Low Stock (${db.lowStockFinishedProducts.length})'),
                      selected: _showOnlyLowStock,
                      onSelected: (val) => setState(() => _showOnlyLowStock = val),
                      selectedColor: AppColors.dangerLight,
                      checkmarkColor: AppColors.dangerText,
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        hintText: 'Search product by name, SKU or category...',
                        prefixIcon: Icon(Icons.search, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilterChip(
                    label: Text('Low Stock (${db.lowStockFinishedProducts.length})'),
                    selected: _showOnlyLowStock,
                    onSelected: (val) => setState(() => _showOnlyLowStock = val),
                    selectedColor: AppColors.dangerLight,
                    checkmarkColor: AppColors.dangerText,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Data Table
          ErpDataTable(
            columns: const [
              ErpColumn(title: 'SKU Code'),
              ErpColumn(title: 'Product Name'),
              ErpColumn(title: 'Category'),
              ErpColumn(title: 'Current Stock', isNumeric: true),
              ErpColumn(title: 'Cost Price', isNumeric: true),
              ErpColumn(title: 'Dealer Price', isNumeric: true),
              ErpColumn(title: 'Customer Price', isNumeric: true),
              ErpColumn(title: 'Inventory Value', isNumeric: true),
              ErpColumn(title: 'Status'),
              ErpColumn(title: 'Actions'),
            ],
            rows: products.map((fp) {
              return [
                Text(fp.itemCode, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                Text(fp.name, style: AppTextStyles.bodyMedium),
                Text(fp.categoryName, style: AppTextStyles.bodySmall),
                Text(
                  '${Formatters.formatNumber(fp.currentStock)} ${fp.unit}',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: fp.isLowStock ? AppColors.dangerText : AppColors.textPrimary,
                  ),
                ),
                Text(Formatters.formatCurrency(fp.costPrice), style: AppTextStyles.bodySmall),
                Text(Formatters.formatCurrency(fp.dealerSellingPrice), style: AppTextStyles.bodyMedium),
                Text(Formatters.formatCurrency(fp.customerSellingPrice), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                Text(Formatters.formatCurrency(fp.totalValuation), style: AppTextStyles.bodyBold),
                fp.isLowStock ? ErpStatusBadge.danger('LOW STOCK') : ErpStatusBadge.success('AVAILABLE'),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Product',
                      onPressed: () => _openEditDialog(fp),
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
