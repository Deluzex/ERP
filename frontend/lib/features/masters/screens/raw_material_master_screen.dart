import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/raw_material_model.dart';
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

class RawMaterialMasterScreen extends ConsumerStatefulWidget {
  const RawMaterialMasterScreen({super.key});

  @override
  ConsumerState<RawMaterialMasterScreen> createState() => _RawMaterialMasterScreenState();
}

class _RawMaterialMasterScreenState extends ConsumerState<RawMaterialMasterScreen> {
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
    final transportCtrl = TextEditingController(
      text: existing?.transportationCharge.toString() ?? '0',
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
                                      labelText: 'Purchase Cost (₹) *',
                                      hintText: 'Purchase / landed cost per unit',
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
                                          labelText: 'Purchase Cost (₹) *',
                                          hintText: 'Base cost per unit',
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
                          final transportVal = double.tryParse(transportCtrl.text.trim()) ?? 0.0;
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
                                transportationCharge: transportVal,
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
                                transportationCharge: transportVal,
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

  Widget _buildCategoryChip(String catName) {
    final lower = catName.toLowerCase();
    if (lower.contains('metal') || lower.contains('aluminum') || lower.contains('alu')) {
      return ErpStatusBadge.categoryPurple(catName);
    } else if (lower.contains('glass') || lower.contains('acrylic')) {
      return ErpStatusBadge.categoryBlue(catName);
    } else if (lower.contains('wire') || lower.contains('cable') || lower.contains('driver')) {
      return ErpStatusBadge.categoryOrange(catName);
    } else if (lower.contains('led') || lower.contains('chip') || lower.contains('pcb')) {
      return ErpStatusBadge.categoryTeal(catName);
    } else if (lower.contains('screws') || lower.contains('fastener')) {
      return ErpStatusBadge.categoryGreen(catName);
    } else {
      return ErpStatusBadge.categoryNeutral(catName);
    }
  }

  Widget _buildControlsRow(List<DropdownMenuItem<String>> categoryFilterItems) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;
        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ErpSearchInput(
                hintText: 'Search raw materials by SKU, name, vendor...',
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
                hintText: 'Search raw materials by SKU, name, vendor...',
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
    final materials = db.rawMaterials.where((rm) {
      if (rm.isDeleted) return false;
      final query = _searchQuery.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matches = rm.name.toLowerCase().contains(query) ||
            rm.itemCode.toLowerCase().contains(query) ||
            rm.categoryName.toLowerCase().contains(query) ||
            rm.unit.toLowerCase().contains(query) ||
            rm.preferredVendorNames.any((v) => v.toLowerCase().contains(query));
        if (!matches) return false;
      }
      if (_selectedCategoryFilter != 'ALL' && rm.categoryId != _selectedCategoryFilter && rm.categoryName != _selectedCategoryFilter) {
        return false;
      }
      if (_stockFilter == 'LOW' && !rm.isLowStock) return false;
      if (_stockFilter == 'OUT_OF_STOCK' && rm.currentStock > 0) return false;
      if (_stockFilter == 'IN_STOCK' && rm.currentStock <= 0) return false;
      if (_startDate != null && rm.createdAt.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))) return false;
      if (_endDate != null && rm.createdAt.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) return false;
      return true;
    }).toList();

    final totalRecords = materials.length;
    final safePageSize = _pageSize <= 0 ? 25 : _pageSize;
    final totalPages = (totalRecords <= 0) ? 1 : (totalRecords / safePageSize).ceil();
    final maxPage = totalPages > 0 ? totalPages - 1 : 0;
    final safeCurrentPage = _currentPage.clamp(0, maxPage);
    final startIndex = safeCurrentPage * safePageSize;
    final endIndex = (startIndex + safePageSize).clamp(0, totalRecords);
    final pagedMaterials = totalRecords == 0 ? <RawMaterial>[] : materials.sublist(startIndex, endIndex);

    final categoryFilterItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
      ...db.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
    ];

    final totalRawMaterialsCount = db.rawMaterials.where((m) => !m.isDeleted).length;
    final inStockCount = db.rawMaterials.where((m) => !m.isDeleted && m.currentStock > 0).length;
    final lowStockCount = db.rawMaterials.where((m) => !m.isDeleted && m.isLowStock && m.currentStock > 0).length;
    final outOfStockCount = db.rawMaterials.where((m) => !m.isDeleted && m.currentStock <= 0).length;
    final totalCategoriesCount = db.categories.length;

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.grain_rounded,
            title: 'Raw Materials Master',
            badgeText: 'COMPONENTS & INGREDIENTS',
            actions: [
              ErpButton(
                text: 'Upload History',
                icon: Icons.history,
                isOutlined: true,
                onPressed: () => BulkUploadHistoryDialog.show(context, masterFilter: 'Raw Materials'),
              ),
              ErpButton(
                text: 'Bulk Upload',
                icon: Icons.upload_file,
                isOutlined: true,
                onPressed: () => BulkUploadDialog.show(context, BulkUploadMasterType.rawMaterial),
              ),
              ErpButton(
                text: 'Add Material',
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
                      title: 'Total Materials',
                      value: '$totalRawMaterialsCount',
                      subtext: 'All Raw Materials',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.arrow_circle_down_outlined,
                      iconColor: AppColors.success,
                      title: 'In Stock',
                      value: '$inStockCount',
                      subtext: 'Available',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.warning_amber_rounded,
                      iconColor: lowStockCount > 0 ? AppColors.danger : AppColors.success,
                      title: 'Low Stock Items',
                      value: '$lowStockCount',
                      subtext: lowStockCount > 0 ? '$lowStockCount of $totalRawMaterialsCount need reorder' : 'Healthy stock levels',
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
                      subtext: outOfStockCount > 0 ? '$outOfStockCount of $totalRawMaterialsCount zero stock' : 'No stockouts',
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
              ErpColumn(title: 'MATERIAL NAME'),
              ErpColumn(title: 'SKU / CODE'),
              ErpColumn(title: 'CATEGORY'),
              ErpColumn(title: 'UNIT'),
              ErpColumn(title: 'STOCK', isNumeric: true),
              ErpColumn(title: 'UNIT PRICE', isNumeric: true),
              ErpColumn(title: 'STATUS'),
              ErpColumn(title: 'ACTIONS'),
            ],
            rows: pagedMaterials.map((rm) {
              return [
                // Material Name + Category Subtitle (Clickable to detail page)
                InkWell(
                  onTap: () => ref.read(activeRecordDetailsStackProvider.notifier).push(rm.id, 'rawMaterial', ErpNavSection.rawMaterials),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rm.name,
                        style: AppTextStyles.bodyBold.copyWith(
                          fontSize: 13,
                          color: const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (rm.categoryName.isNotEmpty)
                        Text(
                          rm.categoryName,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Text(rm.itemCode, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
                _buildCategoryChip(rm.categoryName),
                Text(rm.unit, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                // Stock Column with Bold Quantity + Min Stock subtitle
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${Formatters.formatNumber(rm.currentStock)} ${rm.unit}',
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: const Color(0xFF1E293B)),
                    ),
                    Text(
                      'Min: ${Formatters.formatNumber(rm.minimumStock)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Text(
                  Formatters.formatCurrency(rm.defaultPurchasePrice),
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 13, color: const Color(0xFF1E293B)),
                ),
                rm.isLowStock
                    ? ErpStatusBadge.warning('Low Stock')
                    : (rm.currentStock <= 0 ? ErpStatusBadge.danger('Out of Stock') : ErpStatusBadge.success('In Stock')),
                // Previous Single Action Button
                PopupMenuButton<String>(
                  tooltip: 'Actions',
                  icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onSelected: (action) {
                    switch (action) {
                      case 'view':
                        ref.read(activeRecordDetailsStackProvider.notifier).push(rm.id, 'rawMaterial', ErpNavSection.rawMaterials);
                        break;
                      case 'edit':
                        _openAddEditDialog(rm);
                        break;
                      case 'delete':
                        _confirmDelete(rm);
                        break;
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('View Material Details'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                          SizedBox(width: 8),
                          Text('Edit Material'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                          SizedBox(width: 8),
                          Text('Delete Material', style: TextStyle(color: AppColors.danger)),
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
