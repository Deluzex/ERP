import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/finished_product_model.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/utils/formatters.dart';
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
import '../../../shared/services/mock_database_service.dart';

class FinishedProductStockScreen extends ConsumerStatefulWidget {
  const FinishedProductStockScreen({super.key});

  @override
  ConsumerState<FinishedProductStockScreen> createState() => _FinishedProductStockScreenState();
}

// This is class ant
class _FinishedProductStockScreenState extends ConsumerState<FinishedProductStockScreen> {
  String _searchQuery = '';
  String? _selectedCategory;
  String _stockFilter = 'ALL';
  int _currentPage = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final db = ref.read(databaseServiceProvider);
      db.loadFinishedProducts();
      db.loadPurchases();
    });
  }

  double _getLatestTransportationCharge(FinishedProduct fp, MockDatabaseService db) {
    final sortedPurchases = List<Purchase>.from(db.purchases)
      ..sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

    for (final purchase in sortedPurchases) {
      if (purchase.status == PurchaseStatus.cancelled) continue;
      for (final item in purchase.items) {
        final matches = (item.itemType == PurchaseItemType.finishedProduct) &&
            (item.finishedProductId == fp.id ||
                (item.finishedProductCode != null && item.finishedProductCode == fp.itemCode) ||
                item.itemId == fp.id);
        if (matches) {
          if (item.transportationCost > 0) {
            return item.transportationCost;
          }
          if (purchase.transportationCharges > 0 && purchase.items.length == 1) {
            return purchase.transportationCharges;
          }
          return 0.0;
        }
      }
    }
    return fp.transportationCharge;
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
                constraints: BoxConstraints(maxWidth: 620, maxHeight: MediaQuery.of(context).size.height * 0.72),
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
                    ErpToast.showSuccess(
                      context,
                      'Product updated successfully!',
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
      final matchesCategory = _selectedCategory == null || fp.categoryId == _selectedCategory;
      if (_stockFilter == 'LOW' && !fp.isLowStock) return false;
      if (_stockFilter == 'OUT_OF_STOCK' && fp.currentStock > 0) return false;
      if (_stockFilter == 'IN_STOCK' && fp.currentStock <= 0) return false;
      return matchesSearch && matchesCategory;
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.inventory_2_outlined,
            title: 'Finished Product Stock',
            badgeText: 'FINISHED GOODS',
            subtitle: 'Manage finished goods catalog, multi-tier pricing, and stock levels',
            // action: LayoutBuilder(
            //   builder: (context, actionBox) {
            //     final isMobile = actionBox.maxWidth < 520;
            //     return SizedBox(
            //       width: isMobile ? double.infinity : null,
            //       child: ErpButton(
            //         text: 'Refresh Stock',
            //         icon: Icons.refresh,
            //         isOutlined: true,
            //         onPressed: () => db.loadFinishedProducts(forceRefresh: true),
            //       ),
            //     );
            //   },
            // ),
          ),
          const SizedBox(height: 18),

          // 4 Key Metrics
          LayoutBuilder(
            builder: (context, constraints) {
              final activeProds = db.finishedProducts.where((p) => !p.isDeleted).toList();
              final totalUnits = activeProds.fold(0.0, (sum, p) => sum + p.currentStock);
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
                      icon: Icons.inventory_2_rounded,
                      iconColor: AppColors.primary,
                      title: 'Finished Goods Value',
                      value: Formatters.formatCurrency(db.finishedProductStockValue),
                      subtext: 'Total Inventory Assets',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.primary,
                      title: 'Product SKUs',
                      value: '${activeProds.length}',
                      subtext: 'Active Catalog SKUs',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.warning_amber_rounded,
                      iconColor: db.lowStockFinishedProducts.isNotEmpty ? AppColors.danger : AppColors.success,
                      title: 'Low Stock Items',
                      value: '${db.lowStockFinishedProducts.length}',
                      subtext: db.lowStockFinishedProducts.isNotEmpty ? 'Below minimum buffer' : 'Adequate buffer',
                      subtextColor: db.lowStockFinishedProducts.isNotEmpty ? AppColors.danger : AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: AppColors.success,
                      title: 'Total Stock Units',
                      value: Formatters.formatNumber(totalUnits),
                      subtext: 'Units on Hand',
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
                            hintText: 'Search product by name, SKU or category...',
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
                            hintText: 'Search product by name, SKU or category...',
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
                    final totalCount = products.length;
                    final maxPage = (totalCount / _pageSize).ceil();
                    final effectivePage = maxPage == 0 ? 0 : min(_currentPage, maxPage - 1);
                    final startIdx = effectivePage * _pageSize;
                    final endIdx = min(startIdx + _pageSize, totalCount);
                    final paginatedProducts = totalCount == 0 ? <FinishedProduct>[] : products.sublist(startIdx, endIdx);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ErpDataTable(
                          columns: const [
                            ErpColumn(title: 'SKU Code'),
                            ErpColumn(title: 'Product Name'),
                            ErpColumn(title: 'Category'),
                            ErpColumn(title: 'Current Stock', isNumeric: true),
                            ErpColumn(title: 'Cost Price', isNumeric: true),
                            ErpColumn(title: 'Transportation Charges', isNumeric: true),
                            ErpColumn(title: 'Dealer Price', isNumeric: true),
                            ErpColumn(title: 'Customer Price', isNumeric: true),
                            ErpColumn(title: 'Inventory Value', isNumeric: true),
                            ErpColumn(title: 'Status'),
                            ErpColumn(title: 'Actions'),
                          ],
                          rows: paginatedProducts.map((fp) {
                            final transportCharge = _getLatestTransportationCharge(fp, db);
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
                              Text(Formatters.formatCurrency(transportCharge), style: AppTextStyles.bodySmall),
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
                        if (totalCount > 0) ...[
                          const SizedBox(height: 16),
                          ErpPaginationBar(
                            currentPage: effectivePage,
                            pageSize: _pageSize,
                            totalRecords: totalCount,
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
