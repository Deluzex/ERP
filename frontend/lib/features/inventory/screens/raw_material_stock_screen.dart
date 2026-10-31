import 'dart:math';
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
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/figma_metric_card.dart';
import '../../../core/widgets/erp_toast.dart';
import '../../../shared/providers/app_state_providers.dart';

class RawMaterialStockScreen extends ConsumerStatefulWidget {
  const RawMaterialStockScreen({super.key});

  @override
  ConsumerState<RawMaterialStockScreen> createState() => _RawMaterialStockScreenState();
}

class _RawMaterialStockScreenState extends ConsumerState<RawMaterialStockScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  String _stockFilter = 'ALL';
  int _currentPage = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadRawMaterials();
    });
  }

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
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Text(isEdit ? 'Edit Raw Material' : 'Add Raw Material', style: AppTextStyles.h2),
              content: Container(
                constraints: BoxConstraints(maxWidth: 540, maxHeight: MediaQuery.of(context).size.height * 0.72),
                width: double.infinity,
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
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 500;
                            if (isNarrow) {
                              return Column(
                                children: [
                                  TextFormField(
                                    controller: codeCtrl,
                                    validator: (v) => Validators.requiredField(v, 'Item code required'),
                                    decoration: const InputDecoration(labelText: 'Item Code *', hintText: 'RAW-AL-01'),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: selectedCategory.isNotEmpty ? selectedCategory : null,
                                    decoration: const InputDecoration(labelText: 'Category'),
                                    items: db.categories.map((cat) {
                                      return DropdownMenuItem(value: cat.id, child: Text(cat.name, style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setDlgState(() => selectedCategory = val);
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    isExpanded: true,
                                    value: selectedUnit,
                                    decoration: const InputDecoration(labelText: 'Unit'),
                                    items: db.units.map((u) {
                                      return DropdownMenuItem(
                                        value: u.symbol,
                                        child: Text('${u.name} (${u.symbol})', overflow: TextOverflow.ellipsis, maxLines: 1),
                                      );
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
                                    decoration: InputDecoration(labelText: isEdit ? 'Current Stock' : 'Opening Stock *'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: minCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.nonNegativeNumber,
                                    decoration: const InputDecoration(labelText: 'Minimum Stock Level *'),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: priceCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.nonNegativeNumber,
                                    decoration: const InputDecoration(labelText: 'Default Purchase Price (₹) *'),
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
                                        decoration: const InputDecoration(labelText: 'Item Code *', hintText: 'RAW-AL-01'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        value: selectedCategory.isNotEmpty ? selectedCategory : null,
                                        decoration: const InputDecoration(labelText: 'Category'),
                                        items: db.categories.map((cat) {
                                          return DropdownMenuItem(value: cat.id, child: Text(cat.name, style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis));
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
                                        isExpanded: true,
                                        value: selectedUnit,
                                        decoration: const InputDecoration(labelText: 'Unit'),
                                        items: db.units.map((u) {
                                          return DropdownMenuItem(
                                            value: u.symbol,
                                            child: Text('${u.name} (${u.symbol})', overflow: TextOverflow.ellipsis, maxLines: 1),
                                          );
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
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          isExpanded: true,
                          value: selectedVendorId,
                          decoration: const InputDecoration(labelText: 'Preferred Vendor'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('None', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ...db.vendors.map((v) {
                              return DropdownMenuItem(value: v.id, child: Text(v.name, maxLines: 1, overflow: TextOverflow.ellipsis));
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
                      db.updateRawMaterialAsync(existing.copyWith(
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
                        preferredVendorIds: prefVendorIds,
                        preferredVendorNames: prefVendorNames,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      );
                      db.addRawMaterialAsync(newRm);
                    }
                    Navigator.of(ctx).pop();
                    ErpToast.showSuccess(
                      context,
                      isEdit ? 'Raw material updated successfully!' : 'Raw material created successfully!',
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
    final rawMaterials = db.rawMaterials.where((rm) {
      final query = _searchQuery.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          rm.name.toLowerCase().contains(query) ||
          rm.itemCode.toLowerCase().contains(query) ||
          rm.categoryName.toLowerCase().contains(query) ||
          rm.unit.toLowerCase().contains(query) ||
          rm.preferredVendorNames.any((v) => v.toLowerCase().contains(query));
      final matchesCategory = _selectedCategory == null || rm.categoryId == _selectedCategory;
      if (_stockFilter == 'LOW' && !rm.isLowStock) return false;
      if (_stockFilter == 'OUT_OF_STOCK' && rm.currentStock > 0) return false;
      if (_stockFilter == 'IN_STOCK' && rm.currentStock <= 0) return false;
      return matchesSearch && matchesCategory;
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.layers_outlined,
            title: 'Raw Material Stock',
            badgeText: 'INVENTORY ASSETS',
            subtitle: 'Manage raw material quantities, thresholds, and valuations',
            action: LayoutBuilder(
              builder: (context, actionBox) {
                final isMobile = actionBox.maxWidth < 520;
                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ErpButton(
                          text: 'Add Raw Material',
                          icon: Icons.add,
                          onPressed: () => _openAddEditDialog(),
                        ),
                      ),
                      // const SizedBox(height: 8),
                      // SizedBox(
                      //   width: double.infinity,
                      //   child: ErpButton(
                      //     text: 'Refresh',
                      //     icon: Icons.refresh,
                      //     isOutlined: true,
                      //     onPressed: () => db.loadRawMaterials(forceRefresh: true),
                      //   ),
                      // ),
                    ],
                  );
                }
                return Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ErpButton(
                      text: 'Add Raw Material',
                      icon: Icons.add,
                      onPressed: () => _openAddEditDialog(),
                    ),
                    // ErpButton(
                    //   text: 'Refresh',
                    //   icon: Icons.refresh,
                    //   isOutlined: true,
                    //   onPressed: () => db.loadRawMaterials(forceRefresh: true),
                    // ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // 4 Key Metrics
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 850
                  ? (constraints.maxWidth - (3 * 12)) / 4
                  : (constraints.maxWidth > 550 ? (constraints.maxWidth - 12) / 2 : double.infinity);
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.account_balance_wallet_outlined,
                      iconColor: AppColors.primary,
                      title: 'Raw Material Valuation',
                      value: Formatters.formatCurrency(db.rawMaterialStockValue),
                      subtext: 'Total Inventory Assets',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.category_outlined,
                      iconColor: AppColors.primary,
                      title: 'Total Materials',
                      value: '${db.rawMaterials.where((r) => !r.isDeleted).length}',
                      subtext: 'Active Catalog Items',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.warning_amber_rounded,
                      iconColor: db.lowStockRawMaterials.isNotEmpty ? AppColors.danger : AppColors.success,
                      title: 'Low Stock Alert',
                      value: '${db.lowStockRawMaterials.length}',
                      subtext: db.lowStockRawMaterials.isNotEmpty ? 'Critical restocking required' : 'Adequate buffer level',
                      subtextColor: db.lowStockRawMaterials.isNotEmpty ? AppColors.danger : AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.folder_open_outlined,
                      iconColor: AppColors.primary,
                      title: 'Categories',
                      value: '${db.categories.length}',
                      subtext: 'Active Classifications',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Table enclosed in card container
          Container(
            padding: const EdgeInsets.all(20),
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
                // Modern Filter Controls Bar (Responsive: vertical stack on mobile, horizontal wrap on desktop)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 450;
                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ErpSearchInput(
                            hintText: 'Search raw material by name, code, category...',
                            value: _searchQuery,
                            onChanged: (val) => setState(() {
                              _searchQuery = val;
                              _currentPage = 0;
                            }),
                          ),
                          const SizedBox(height: 10),
                          ErpFilterDropdown<String?>(
                            label: 'Category',
                            value: _selectedCategory,
                            width: double.infinity,
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem(value: null, child: Text('All Categories')),
                              ...db.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                            ],
                            onChanged: (val) => setState(() {
                              _selectedCategory = val;
                              _currentPage = 0;
                            }),
                          ),
                          const SizedBox(height: 10),
                          ErpFilterDropdown<String>(
                            label: 'Stock Status',
                            value: _stockFilter,
                            width: double.infinity,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'ALL', child: Text('All Stock Levels')),
                              DropdownMenuItem(value: 'LOW', child: Text('Low Stock Alert')),
                              DropdownMenuItem(value: 'IN_STOCK', child: Text('In Stock')),
                              DropdownMenuItem(value: 'OUT_OF_STOCK', child: Text('Out of Stock (Zero)')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _stockFilter = val;
                                  _currentPage = 0;
                                });
                              }
                            },
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
                            hintText: 'Search raw material by name, code, category...',
                            value: _searchQuery,
                            onChanged: (val) => setState(() {
                              _searchQuery = val;
                              _currentPage = 0;
                            }),
                          ),
                        ),
                        ErpFilterDropdown<String?>(
                          label: 'Category',
                          value: _selectedCategory,
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Categories')),
                            ...db.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (val) => setState(() {
                            _selectedCategory = val;
                            _currentPage = 0;
                          }),
                        ),
                        ErpFilterDropdown<String>(
                          label: 'Stock Status',
                          value: _stockFilter,
                          items: const [
                            DropdownMenuItem(value: 'ALL', child: Text('All Stock Levels')),
                            DropdownMenuItem(value: 'LOW', child: Text('Low Stock Alert')),
                            DropdownMenuItem(value: 'IN_STOCK', child: Text('In Stock')),
                            DropdownMenuItem(value: 'OUT_OF_STOCK', child: Text('Out of Stock (Zero)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _stockFilter = val;
                                _currentPage = 0;
                              });
                            }
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Data Table
                Builder(
                  builder: (context) {
                    final totalRecords = rawMaterials.length;
                    final startIndex = _currentPage * _pageSize;
                    final pageRawMaterials = (startIndex < totalRecords)
                        ? rawMaterials.sublist(startIndex, min(startIndex + _pageSize, totalRecords))
                        : <RawMaterial>[];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                          rows: pageRawMaterials.map((rm) {
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
                        if (totalRecords > 0) ...[
                          const SizedBox(height: 16),
                          ErpPaginationBar(
                            currentPage: _currentPage,
                            pageSize: _pageSize,
                            totalRecords: totalRecords,
                            onPageChanged: (newPage) => setState(() => _currentPage = newPage),
                            onPageSizeChanged: (newSize) => setState(() {
                              _pageSize = newSize;
                              _currentPage = 0;
                            }),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
