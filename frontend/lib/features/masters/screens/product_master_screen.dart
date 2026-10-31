import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/finished_product_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/figma_metric_card.dart';
import '../../../core/widgets/bulk_upload_dialog.dart';
import '../../../core/widgets/bulk_upload_history_dialog.dart';
import '../../../shared/providers/app_state_providers.dart';

class ProductMasterScreen extends ConsumerStatefulWidget {
  const ProductMasterScreen({super.key});

  @override
  ConsumerState<ProductMasterScreen> createState() => _ProductMasterScreenState();
}

class _ProductMasterScreenState extends ConsumerState<ProductMasterScreen> {
  String _searchQuery = '';
  String _selectedCategoryFilter = 'ALL';
  String _stockFilter = 'ALL';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  int _pageSize = 25;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadFinishedProducts();
      ref.read(databaseServiceProvider).loadCategories();
      ref.read(databaseServiceProvider).loadUnits();
    });
  }

  void _openAddEditDialog([FinishedProduct? existing]) {
    final db = ref.read(databaseServiceProvider);
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final codeCtrl = TextEditingController(
      text: existing?.itemCode ?? 'DLX-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
    );
    final stockCtrl = TextEditingController(
      text: isEdit ? existing.currentStock.toString() : '0',
    );
    final minCtrl = TextEditingController(
      text: existing?.minimumStock.toString() ?? '5',
    );
    final costCtrl = TextEditingController(
      text: existing?.costPrice.toString() ?? '1500',
    );
    final transportCtrl = TextEditingController(
      text: existing?.transportationCharge.toString() ?? '0',
    );
    final dealerCtrl = TextEditingController(
      text: existing?.dealerSellingPrice.toString() ?? '2500',
    );
    final custCtrl = TextEditingController(
      text: existing?.customerSellingPrice.toString() ?? '3200',
    );

    String selectedCategory = (existing?.categoryId != null && db.categories.any((c) => c.id == existing!.categoryId))
        ? existing!.categoryId
        : (db.categories.isNotEmpty ? db.categories.first.id : '');
    String selectedUnitId = (existing?.unitId != null && db.units.any((u) => u.id == existing!.unitId))
        ? existing!.unitId!
        : (db.units.isNotEmpty ? db.units.first.id : '');
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
              title: Text(isEdit ? 'Edit Product Item' : 'Product / Item Entry', style: AppTextStyles.h2),
              content: Container(
                constraints: BoxConstraints(maxWidth: 580, maxHeight: MediaQuery.of(ctx).size.height * 0.72),
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
                                    validator: (v) => Validators.requiredField(v, 'Product name required'),
                                    decoration: const InputDecoration(
                                      labelText: 'Product / Item Name *',
                                      hintText: 'E.g., Aarix Wall Sconce Light',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: codeCtrl,
                                    validator: (v) => Validators.requiredField(v, 'SKU / Code required'),
                                    decoration: const InputDecoration(
                                      labelText: 'SKU / Code *',
                                      hintText: 'E.g., DLX-WSC-01',
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
                                    controller: costCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.positiveNumber,
                                    decoration: const InputDecoration(
                                      labelText: 'Purchase / Cost Price (₹) *',
                                      hintText: 'Purchase landed or production cost',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: transportCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.nonNegativeNumber,
                                    decoration: const InputDecoration(
                                      labelText: 'Transportation Charge (₹)',
                                      hintText: 'Freight per unit',
                                      prefixIcon: Icon(Icons.local_shipping_outlined, size: 18),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: dealerCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.positiveNumber,
                                    decoration: const InputDecoration(
                                      labelText: 'Dealer Price (₹) *',
                                      hintText: 'B2B price',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: custCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.positiveNumber,
                                    decoration: const InputDecoration(
                                      labelText: 'Customer Price (₹) *',
                                      hintText: 'Retail MRP',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: stockCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.nonNegativeNumber,
                                    decoration: InputDecoration(
                                      labelText: isEdit ? 'Current Stock *' : 'Opening Stock *',
                                      hintText: 'Initial stock units',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextFormField(
                                    controller: minCtrl,
                                    keyboardType: TextInputType.number,
                                    validator: Validators.nonNegativeNumber,
                                    decoration: const InputDecoration(
                                      labelText: 'Minimum Alert Stock *',
                                      hintText: 'Low stock warning threshold',
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
                                        validator: (v) => Validators.requiredField(v, 'Product name required'),
                                        decoration: const InputDecoration(
                                          labelText: 'Product / Item Name *',
                                          hintText: 'E.g., Aarix Wall Sconce Light',
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
                                          hintText: 'E.g., DLX-WSC-01',
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
                                        controller: costCtrl,
                                        keyboardType: TextInputType.number,
                                        validator: Validators.positiveNumber,
                                        decoration: const InputDecoration(
                                          labelText: 'Purchase / Cost Price (₹) *',
                                          hintText: 'Purchase landed or production cost',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: dealerCtrl,
                                        keyboardType: TextInputType.number,
                                        validator: Validators.positiveNumber,
                                        decoration: const InputDecoration(
                                          labelText: 'Dealer Price (₹) *',
                                          hintText: 'B2B price',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: custCtrl,
                                        keyboardType: TextInputType.number,
                                        validator: Validators.positiveNumber,
                                        decoration: const InputDecoration(
                                          labelText: 'Customer Price (₹) *',
                                          hintText: 'Retail MRP',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: stockCtrl,
                                        keyboardType: TextInputType.number,
                                        validator: Validators.nonNegativeNumber,
                                        decoration: InputDecoration(
                                          labelText: isEdit ? 'Current Stock *' : 'Opening Stock *',
                                          hintText: 'Initial stock units',
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
                                          labelText: 'Minimum Alert Stock *',
                                          hintText: 'Low stock warning threshold',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: transportCtrl,
                                        keyboardType: TextInputType.number,
                                        validator: Validators.nonNegativeNumber,
                                        decoration: const InputDecoration(
                                          labelText: 'Trans. Charge (₹)',
                                          hintText: 'Freight per unit',
                                          prefixIcon: Icon(Icons.local_shipping_outlined, size: 18),
                                        ),
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
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(),
                ),
                ErpButton(
                  text: isEdit ? 'Update Product' : 'Save Product',
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
                          final costVal = double.tryParse(costCtrl.text.trim()) ?? 0.0;
                          final transportVal = double.tryParse(transportCtrl.text.trim()) ?? 0.0;
                          final dealerVal = double.tryParse(dealerCtrl.text.trim()) ?? 0.0;
                          final custVal = double.tryParse(custCtrl.text.trim()) ?? 0.0;
                          final catObj = db.categories.firstWhere(
                            (c) => c.id == selectedCategory,
                            orElse: () => db.categories.first,
                          );
                          final unitObj = db.units.firstWhere(
                            (u) => u.id == selectedUnitId,
                            orElse: () => db.units.first,
                          );

                          try {
                            if (isEdit) {
                              await db.updateFinishedProductAsync(existing.copyWith(
                                name: nameCtrl.text.trim(),
                                itemCode: codeCtrl.text.trim(),
                                categoryId: catObj.id,
                                categoryName: catObj.name,
                                unitId: unitObj.id,
                                unit: unitObj.symbol,
                                currentStock: stockVal,
                                minimumStock: minVal,
                                costPrice: costVal,
                                transportationCharge: transportVal,
                                dealerSellingPrice: dealerVal,
                                customerSellingPrice: custVal,
                                updatedAt: DateTime.now(),
                              ));
                            } else {
                              final newFp = FinishedProduct(
                                id: IdGenerator.generateId('FP'),
                                name: nameCtrl.text.trim(),
                                itemCode: codeCtrl.text.trim(),
                                categoryId: catObj.id,
                                categoryName: catObj.name,
                                unitId: unitObj.id,
                                unit: unitObj.symbol,
                                currentStock: stockVal,
                                openingStock: stockVal,
                                minimumStock: minVal,
                                costPrice: costVal,
                                transportationCharge: transportVal,
                                dealerSellingPrice: dealerVal,
                                customerSellingPrice: custVal,
                                gstPercent: 18.0,
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                              );
                              await db.addFinishedProductAsync(newFp);
                            }

                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isEdit ? 'Product updated successfully!' : 'Product created successfully!'),
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

  void _confirmDelete(FinishedProduct fp) {
    bool isDeleting = false;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Text('Delete Product Item', style: AppTextStyles.h2),
              content: Text(
                'Are you sure you want to delete "${fp.name}" (${fp.itemCode})? This cannot be undone.',
                style: AppTextStyles.bodyMedium,
              ),
              actions: [
                ErpButton(
                  text: 'Cancel',
                  isOutlined: true,
                  onPressed: isDeleting ? null : () => Navigator.of(ctx).pop(),
                ),
                ErpButton(
                  text: 'Delete',
                  isDanger: true,
                  isLoading: isDeleting,
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDlgState(() => isDeleting = true);
                          try {
                            await ref.read(databaseServiceProvider).deleteFinishedProductAsync(fp.id);
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Product "${fp.name}" deleted successfully!'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          } catch (e) {
                            setDlgState(() => isDeleting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to delete: $e'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
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

  Widget _buildCategoryChip(String catName) {
    final lower = catName.toLowerCase();
    if (lower.contains('table') || lower.contains('lamp')) {
      return ErpStatusBadge.categoryPurple(catName);
    } else if (lower.contains('pendant')) {
      return ErpStatusBadge.categoryBlue(catName);
    } else if (lower.contains('chandel')) {
      return ErpStatusBadge.categoryOrange(catName);
    } else if (lower.contains('track')) {
      return ErpStatusBadge.categoryTeal(catName);
    } else if (lower.contains('profile') || lower.contains('strip')) {
      return ErpStatusBadge.categoryGreen(catName);
    } else {
      return ErpStatusBadge.categoryNeutral(catName);
    }
  }

  Widget _buildControlsRow(List<DropdownMenuItem<String>> categoryFilterItems) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 450;
        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ErpSearchInput(
                hintText: 'Search by name, SKU, barcode...',
                initialValue: _searchQuery,
                onChanged: (val) => setState(() {
                  _searchQuery = val;
                  _currentPage = 0;
                }),
              ),
              const SizedBox(height: 10),
              ErpFilterDropdown<String>(
                value: _selectedCategoryFilter,
                width: double.infinity,
                isExpanded: true,
                items: categoryFilterItems,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategoryFilter = val;
                      _currentPage = 0;
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              ErpFilterDropdown<String>(
                value: _stockFilter,
                width: double.infinity,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Collections')),
                  DropdownMenuItem(value: 'LOW', child: Text('Low Stock Alert')),
                  DropdownMenuItem(value: 'IN_STOCK', child: Text('In Stock')),
                  DropdownMenuItem(value: 'OUT_OF_STOCK', child: Text('Out of Stock')),
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
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 280,
              child: ErpSearchInput(
                hintText: 'Search by name, SKU, barcode...',
                initialValue: _searchQuery,
                onChanged: (val) => setState(() {
                  _searchQuery = val;
                  _currentPage = 0;
                }),
              ),
            ),
            ErpFilterDropdown<String>(
              value: _selectedCategoryFilter,
              items: categoryFilterItems,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedCategoryFilter = val;
                    _currentPage = 0;
                  });
                }
              },
            ),
            ErpFilterDropdown<String>(
              value: _stockFilter,
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('All Collections')),
                DropdownMenuItem(value: 'LOW', child: Text('Low Stock Alert')),
                DropdownMenuItem(value: 'IN_STOCK', child: Text('In Stock')),
                DropdownMenuItem(value: 'OUT_OF_STOCK', child: Text('Out of Stock')),
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

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);
    final products = db.finishedProducts.where((fp) {
      if (fp.isDeleted) return false;
      final query = _searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matches = fp.name.toLowerCase().contains(query) ||
            fp.itemCode.toLowerCase().contains(query) ||
            fp.categoryName.toLowerCase().contains(query) ||
            fp.unit.toLowerCase().contains(query);
        if (!matches) return false;
      }
      if (_selectedCategoryFilter != 'ALL' && fp.categoryId != _selectedCategoryFilter && fp.categoryName != _selectedCategoryFilter) {
        return false;
      }
      if (_stockFilter == 'LOW' && !fp.isLowStock) return false;
      if (_stockFilter == 'OUT_OF_STOCK' && fp.currentStock > 0) return false;
      if (_stockFilter == 'IN_STOCK' && fp.currentStock <= 0) return false;
      if (_startDate != null && fp.createdAt.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))) return false;
      if (_endDate != null && fp.createdAt.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) return false;
      return true;
    }).toList();

    final totalRecords = products.length;
    final safePageSize = _pageSize <= 0 ? 25 : _pageSize;
    final totalPages = (totalRecords <= 0) ? 1 : (totalRecords / safePageSize).ceil();
    final maxPage = totalPages > 0 ? totalPages - 1 : 0;
    final safeCurrentPage = _currentPage.clamp(0, maxPage);
    final startIndex = safeCurrentPage * safePageSize;
    final endIndex = (startIndex + safePageSize).clamp(0, totalRecords);
    final pagedProducts = totalRecords == 0 ? <FinishedProduct>[] : products.sublist(startIndex, endIndex);

    final categoryFilterItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
      ...db.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
    ];

    final totalProductsCount = db.finishedProducts.where((p) => !p.isDeleted).length;
    final activeProductsCount = db.finishedProducts.where((p) => !p.isDeleted && p.currentStock > 0).length;
    final lowStockCount = db.finishedProducts.where((p) => !p.isDeleted && p.isLowStock && p.currentStock > 0).length;
    final outOfStockCount = db.finishedProducts.where((p) => !p.isDeleted && p.currentStock <= 0).length;
    final totalCategoriesCount = db.categories.length;

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.inventory_2_outlined,
            title: 'Products Master',
            badgeText: 'FINISHED GOODS',
            actions: [
              ErpButton(
                text: 'Upload History',
                icon: Icons.history,
                isOutlined: true,
                onPressed: () => BulkUploadHistoryDialog.show(context, masterFilter: 'Finished Products'),
              ),
              ErpButton(
                text: 'Bulk Upload',
                icon: Icons.upload_file,
                isOutlined: true,
                onPressed: () => BulkUploadDialog.show(context, BulkUploadMasterType.finishedProduct),
              ),
              ErpButton(
                text: 'Add Product',
                icon: Icons.add,
                onPressed: () => _openAddEditDialog(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 5 Summary Metric Cards (Matching Figma Screenshot 2)
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth > 850
                  ? (constraints.maxWidth - (4 * 12)) / 5
                  : (constraints.maxWidth > 550 ? (constraints.maxWidth - 12) / 2 : double.infinity);
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.primary,
                      title: 'Total Products',
                      value: '$totalProductsCount',
                      subtext: 'All Products',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.arrow_circle_down_outlined,
                      iconColor: AppColors.success,
                      title: 'Active Products',
                      value: '$activeProductsCount',
                      subtext: 'Enabled',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.warning_amber_rounded,
                      iconColor: lowStockCount > 0 ? AppColors.danger : AppColors.success,
                      title: 'Low Stock Items',
                      value: '$lowStockCount',
                      subtext: lowStockCount > 0 ? '$lowStockCount of $totalProductsCount need reorder' : 'Healthy stock levels',
                      subtextColor: lowStockCount > 0 ? AppColors.danger : AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.cancel_outlined,
                      iconColor: outOfStockCount > 0 ? AppColors.danger : AppColors.success,
                      title: 'Out of Stock',
                      value: '$outOfStockCount',
                      subtext: outOfStockCount > 0 ? '$outOfStockCount of $totalProductsCount zero stock' : 'No stockouts',
                      subtextColor: outOfStockCount > 0 ? AppColors.danger : AppColors.success,
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.category_outlined,
                      iconColor: AppColors.categoryGold,
                      title: 'Total Categories',
                      value: '$totalCategoriesCount',
                      subtext: 'Categories',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

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
                _buildControlsRow(categoryFilterItems),
                const SizedBox(height: 16),
                ErpDataTable(
            columns: const [
              ErpColumn(title: 'PRODUCT NAME'),
              ErpColumn(title: 'SKU / CODE'),
              ErpColumn(title: 'CATEGORY'),
              ErpColumn(title: 'UNIT'),
              ErpColumn(title: 'STOCK', isNumeric: true),
              ErpColumn(title: 'DEALER PRICE', isNumeric: true),
              ErpColumn(title: 'CUSTOMER PRICE', isNumeric: true),
              ErpColumn(title: 'STATUS'),
              ErpColumn(title: 'ACTIONS'),
            ],
            rows: pagedProducts.map((fp) {
              return [
                // Product Name + Category Subtitle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fp.name,
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: const Color(0xFF1E293B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (fp.categoryName.isNotEmpty)
                      Text(
                        fp.categoryName,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                Text(fp.itemCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                _buildCategoryChip(fp.categoryName),
                Text(fp.unit, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                // Stock Column with Bold Quantity + Status subtitle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${Formatters.formatNumber(fp.currentStock)} ${fp.unit}',
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: const Color(0xFF1E293B)),
                    ),
                    Text(
                      'Min: ${Formatters.formatNumber(fp.minimumStock)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Text(
                  Formatters.formatCurrency(fp.dealerSellingPrice),
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: const Color(0xFF1E293B)),
                ),
                Text(
                  Formatters.formatCurrency(fp.customerSellingPrice),
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: const Color(0xFF1E293B)),
                ),
                fp.isLowStock
                    ? ErpStatusBadge.warning('Low Stock')
                    : (fp.currentStock <= 0 ? ErpStatusBadge.danger('Out of Stock') : ErpStatusBadge.success('Active')),
                // Previous Single Action Button
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (action) {
                    switch (action) {
                      case 'edit':
                        _openAddEditDialog(fp);
                        break;
                      case 'delete':
                        _confirmDelete(fp);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Product'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                          SizedBox(width: 8),
                          Text('Delete Product'),
                        ],
                      ),
                    ),
                  ],
                ),
              ];
            }).toList(),
          ),
          const SizedBox(height: 16),
          ErpPaginationBar(
                  currentPage: safeCurrentPage,
                  pageSize: safePageSize,
                  totalRecords: totalRecords,
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
