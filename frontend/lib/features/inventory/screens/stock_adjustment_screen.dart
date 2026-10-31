import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/stock_adjustment_model.dart';
import '../../../core/models/stock_movement_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/figma_metric_card.dart';
import '../../../core/widgets/stock_movement_icons.dart';
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/erp_toast.dart';
import '../../../shared/providers/app_state_providers.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  ConsumerState<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;
  int _currentPage = 0;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(databaseServiceProvider).loadStockAdjustments();
    });
  }

  void _openCreateAdjustmentDialog() {
    final db = ref.read(databaseServiceProvider);
    ItemType selectedItemType = ItemType.finishedProduct;
    String selectedItemId = db.finishedProducts.isNotEmpty ? db.finishedProducts.first.id : '';
    AdjustmentReason selectedReason = AdjustmentReason.damagedGoods;
    bool isReduction = true;
    final adjQtyCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            double currentStock = 0.0;
            String unit = 'PCS';
            String itemName = '';
            String itemCode = '';

            if (selectedItemType == ItemType.rawMaterial) {
              final rm = db.rawMaterials.firstWhere((r) => r.id == selectedItemId, orElse: () => db.rawMaterials.first);
              currentStock = rm.currentStock;
              unit = rm.unit;
              itemName = rm.name;
              itemCode = rm.itemCode;
            } else {
              final fp = db.finishedProducts.firstWhere((f) => f.id == selectedItemId, orElse: () => db.finishedProducts.first);
              currentStock = fp.currentStock;
              unit = fp.unit;
              itemName = fp.name;
              itemCode = fp.itemCode;
            }

            final rawQty = double.tryParse(adjQtyCtrl.text.trim())?.abs() ?? 0.0;
            final effectiveDiff = isReduction ? -rawQty : rawQty;
            final newResultingStock = currentStock + (adjQtyCtrl.text.trim().isEmpty ? 0.0 : effectiveDiff);

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Text('Record Stock Adjustment', style: AppTextStyles.h2),
              content: Container(
                constraints: const BoxConstraints(maxWidth: 520),
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
                            final isNarrow = constraints.maxWidth < 450;
                            if (isNarrow) {
                              return Column(
                                children: [
                                  RadioListTile<ItemType>(
                                    title: const Text('Finished Product'),
                                    value: ItemType.finishedProduct,
                                    groupValue: selectedItemType,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDlgState(() {
                                          selectedItemType = val;
                                          selectedItemId = db.finishedProducts.isNotEmpty ? db.finishedProducts.first.id : '';
                                        });
                                      }
                                    },
                                  ),
                                  RadioListTile<ItemType>(
                                    title: const Text('Raw Material'),
                                    value: ItemType.rawMaterial,
                                    groupValue: selectedItemType,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDlgState(() {
                                          selectedItemType = val;
                                          selectedItemId = db.rawMaterials.isNotEmpty ? db.rawMaterials.first.id : '';
                                        });
                                      }
                                    },
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: RadioListTile<ItemType>(
                                    title: const Text('Finished Product'),
                                    value: ItemType.finishedProduct,
                                    groupValue: selectedItemType,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDlgState(() {
                                          selectedItemType = val;
                                          selectedItemId = db.finishedProducts.isNotEmpty ? db.finishedProducts.first.id : '';
                                        });
                                      }
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: RadioListTile<ItemType>(
                                    title: const Text('Raw Material'),
                                    value: ItemType.rawMaterial,
                                    groupValue: selectedItemType,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDlgState(() {
                                          selectedItemType = val;
                                          selectedItemId = db.rawMaterials.isNotEmpty ? db.rawMaterials.first.id : '';
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedItemId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Select Item *'),
                          items: selectedItemType == ItemType.rawMaterial
                              ? db.rawMaterials.map((rm) {
                                  return DropdownMenuItem(
                                    value: rm.id,
                                    child: Text('${rm.itemCode} - ${rm.name} (Stock: ${rm.currentStock} ${rm.unit})', overflow: TextOverflow.ellipsis),
                                  );
                                }).toList()
                              : db.finishedProducts.map((fp) {
                                  return DropdownMenuItem(
                                    value: fp.id,
                                    child: Text('${fp.itemCode} - ${fp.name} (Stock: ${fp.currentStock} ${fp.unit})', overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                          onChanged: (val) {
                            if (val != null) setDlgState(() => selectedItemId = val);
                          },
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Current Recorded Stock:', style: AppTextStyles.bodyMedium),
                              Text(
                                '${Formatters.formatNumber(currentStock)} $unit',
                                style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Adjustment Mode Toggle (Excess / Addition and Damage / Reduction buttons commented out)
                        // Row(
                        //   children: [
                        //     Expanded(
                        //       child: InkWell(
                        //         onTap: () => setDlgState(() => isReduction = true),
                        //         borderRadius: BorderRadius.circular(8),
                        //         child: Container(
                        //           padding: const EdgeInsets.symmetric(vertical: 9),
                        //           decoration: BoxDecoration(
                        //             color: isReduction ? const Color(0xFFFEF2F2) : Colors.transparent,
                        //             borderRadius: BorderRadius.circular(8),
                        //             border: Border.all(
                        //               color: isReduction ? const Color(0xFFEF4444) : AppColors.border,
                        //               width: isReduction ? 1.5 : 1,
                        //             ),
                        //           ),
                        //           child: Row(
                        //             mainAxisAlignment: MainAxisAlignment.center,
                        //             children: [
                        //               Icon(
                        //                 Icons.remove_circle_outline,
                        //                 size: 16,
                        //                 color: isReduction ? const Color(0xFFEF4444) : AppColors.textSecondary,
                        //               ),
                        //               const SizedBox(width: 6),
                        //               Text(
                        //                 'Damage / Reduction (-)',
                        //                 style: AppTextStyles.bodyBold.copyWith(
                        //                   fontSize: 12,
                        //                   color: isReduction ? const Color(0xFFEF4444) : AppColors.textSecondary,
                        //                 ),
                        //               ),
                        //             ],
                        //           ),
                        //         ),
                        //       ),
                        //     ),
                        //     const SizedBox(width: 10),
                        //     Expanded(
                        //       child: InkWell(
                        //         onTap: () => setDlgState(() => isReduction = false),
                        //         borderRadius: BorderRadius.circular(8),
                        //         child: Container(
                        //           padding: const EdgeInsets.symmetric(vertical: 9),
                        //           decoration: BoxDecoration(
                        //             color: !isReduction ? const Color(0xFFF0FDF4) : Colors.transparent,
                        //             borderRadius: BorderRadius.circular(8),
                        //             border: Border.all(
                        //               color: !isReduction ? const Color(0xFF16A34A) : AppColors.border,
                        //               width: !isReduction ? 1.5 : 1,
                        //             ),
                        //           ),
                        //           child: Row(
                        //             mainAxisAlignment: MainAxisAlignment.center,
                        //             children: [
                        //               Icon(
                        //                 Icons.add_circle_outline,
                        //                 size: 16,
                        //                 color: !isReduction ? const Color(0xFF16A34A) : AppColors.textSecondary,
                        //               ),
                        //               const SizedBox(width: 6),
                        //               Text(
                        //                 'Excess / Addition (+)',
                        //                 style: AppTextStyles.bodyBold.copyWith(
                        //                   fontSize: 12,
                        //                   color: !isReduction ? const Color(0xFF16A34A) : AppColors.textSecondary,
                        //                 ),
                        //               ),
                        //             ],
                        //           ),
                        //         ),
                        //       ),
                        //     ),
                        //   ],
                        // ),
                        // const SizedBox(height: 14),

                        TextFormField(
                          controller: adjQtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Please enter damage pieces';
                            }
                            final parsed = double.tryParse(v.trim());
                            if (parsed == null) return 'Please enter a valid number';
                            if (parsed.abs() == 0) return 'Damage quantity cannot be 0';
                            return null;
                          },
                          onChanged: (_) => setDlgState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Damage Pieces ($unit) *',
                            hintText: 'Enter damage pieces to deduct (e.g. 20)',
                          ),
                        ),
                        if (adjQtyCtrl.text.trim().isNotEmpty && double.tryParse(adjQtyCtrl.text.trim()) != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isReduction ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isReduction ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Resulting Stock After Adjustment:',
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                    ),
                                    Text(
                                      '${Formatters.formatNumber(newResultingStock)} $unit',
                                      style: AppTextStyles.bodyBold.copyWith(
                                        fontSize: 15,
                                        color: newResultingStock < 0 ? const Color(0xFFDC2626) : const Color(0xFF111827),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: isReduction ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                                    ),
                                  ),
                                  child: Text(
                                    '${effectiveDiff >= 0 ? "+" : ""}${Formatters.formatNumber(effectiveDiff)} $unit',
                                    style: AppTextStyles.bodyBold.copyWith(
                                      fontSize: 12,
                                      color: isReduction ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        DropdownButtonFormField<AdjustmentReason>(
                          value: selectedReason,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Reason for Adjustment *'),
                          items: AdjustmentReason.values.map((r) {
                            return DropdownMenuItem(
                              value: r,
                              child: Text(r.toString().split('.').last.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}').toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDlgState(() {
                                selectedReason = val;
                                if (val == AdjustmentReason.damagedGoods ||
                                    val == AdjustmentReason.theftOrLoss ||
                                    val == AdjustmentReason.expiry ||
                                    val == AdjustmentReason.internalConsumption) {
                                  isReduction = true;
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: remarksCtrl,
                          validator: (v) => Validators.requiredField(v, 'Remarks are required for audit reconciliation'),
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Audit Remarks / Reason *',
                            hintText: 'E.g., Physical count during quarterly audit variance',
                          ),
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
                  text: 'Save Adjustment & Update Stock',
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    final rawVal = double.parse(adjQtyCtrl.text.trim()).abs();
                    final adjDiff = isReduction ? -rawVal : rawVal;
                    final targetQty = currentStock + adjDiff;

                    final adjustment = StockAdjustment(
                      id: IdGenerator.generateId('ADJ'),
                      adjustmentNumber: IdGenerator.generateDocNumber('ADJ', db.nextAdjustmentNumber),
                      adjustmentDate: DateTime.now(),
                      itemId: selectedItemId,
                      itemName: itemName,
                      itemCode: itemCode,
                      itemType: selectedItemType,
                      currentStockBefore: currentStock,
                      adjustedStockAfter: targetQty,
                      adjustmentQuantity: adjDiff,
                      unit: unit,
                      reason: selectedReason,
                      remarks: remarksCtrl.text.trim(),
                      performedBy: db.currentUser.name,
                      createdAt: DateTime.now(),
                    );

                    db.performStockAdjustmentAsync(adjustment);
                    Navigator.of(ctx).pop();
                    ErpToast.showSuccess(
                      context,
                      'Stock adjustment ${adjustment.adjustmentNumber} recorded successfully!',
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
    final adjustments = db.stockAdjustments.where((adj) {
      final query = _searchQuery.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          adj.adjustmentNumber.toLowerCase().contains(query) ||
          adj.itemName.toLowerCase().contains(query) ||
          adj.itemCode.toLowerCase().contains(query) ||
          adj.reasonLabel.toLowerCase().contains(query) ||
          adj.performedBy.toLowerCase().contains(query) ||
          (adj.remarks != null && adj.remarks!.toLowerCase().contains(query));

      if (_startDate != null &&
          adj.adjustmentDate.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day))) {
        return false;
      }
      if (_endDate != null &&
          adj.adjustmentDate.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59))) {
        return false;
      }

      return matchesQuery;
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSectionHeaderCard(
            icon: Icons.tune_rounded,
            title: 'Stock Adjustments',
            badgeText: 'AUDIT & RECONCILIATION',
            subtitle: 'Reconcile physical stock counts, log damages, and record audited corrections',
            action: LayoutBuilder(
              builder: (context, actionBox) {
                final isMobile = actionBox.maxWidth < 520;
                return SizedBox(
                  width: isMobile ? double.infinity : null,
                  child: ErpButton(
                    text: 'New Stock Adjustment',
                    icon: Icons.tune_rounded,
                    onPressed: _openCreateAdjustmentDialog,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // 3 Key Metrics
          LayoutBuilder(
            builder: (context, constraints) {
              final increases = db.stockAdjustments.where((a) => a.adjustmentQuantity > 0).length;
              final reductions = db.stockAdjustments.where((a) => a.adjustmentQuantity < 0).length;
              final cardWidth = constraints.maxWidth > 850
                  ? (constraints.maxWidth - (2 * 12)) / 3
                  : (constraints.maxWidth > 550 ? (constraints.maxWidth - 12) / 2 : double.infinity);
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      icon: Icons.tune_rounded,
                      iconColor: AppColors.primary,
                      title: 'Total Adjustments',
                      value: '${adjustments.length}',
                      subtext: 'Audited Corrections',
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      iconWidget: const StockInIcon(size: 16, color: Color(0xFF16A34A)),
                      title: 'Stock Increases',
                      value: '$increases',
                      subtext: 'Physical Count Surplus',
                      subtextColor: const Color(0xFF16A34A),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: FigmaMetricCard(
                      iconWidget: const StockOutIcon(size: 16, color: Color(0xFFEF4444)),
                      title: 'Stock Reductions / Damage',
                      value: '$reductions',
                      subtext: 'Shortages & Damages',
                      subtextColor: const Color(0xFFEF4444),
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
                            hintText: 'Search adjustments by number, item, reason...',
                            value: _searchQuery,
                            onChanged: (val) => setState(() {
                              _searchQuery = val;
                              _currentPage = 0;
                            }),
                          ),
                          const SizedBox(height: 10),
                          ErpDateFilterBox(
                            startDate: _startDate,
                            endDate: _endDate,
                            width: double.infinity,
                            onDateRangeSelected: (start, end) {
                              setState(() {
                                _startDate = start;
                                _endDate = end;
                                _currentPage = 0;
                              });
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
                            hintText: 'Search adjustments by number, item, reason...',
                            value: _searchQuery,
                            onChanged: (val) => setState(() {
                              _searchQuery = val;
                              _currentPage = 0;
                            }),
                          ),
                        ),
                        ErpDateFilterBox(
                          startDate: _startDate,
                          endDate: _endDate,
                          onDateRangeSelected: (start, end) {
                            setState(() {
                              _startDate = start;
                              _endDate = end;
                              _currentPage = 0;
                            });
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Data Table of adjustments
                Builder(
                  builder: (context) {
                    final totalRecords = adjustments.length;
                    final startIndex = _currentPage * _pageSize;
                    final pageAdjustments = (startIndex < totalRecords)
                        ? adjustments.sublist(startIndex, min(startIndex + _pageSize, totalRecords))
                        : <StockAdjustment>[];

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ErpDataTable(
                          columns: const [
                            ErpColumn(title: 'Date'),
                            ErpColumn(title: 'Adjustment No'),
                            ErpColumn(title: 'Item Details'),
                            ErpColumn(title: 'Item Type'),
                            ErpColumn(title: 'Before Stock', isNumeric: true),
                            ErpColumn(title: 'Adjustment', isNumeric: true),
                            ErpColumn(title: 'Final Stock', isNumeric: true),
                            ErpColumn(title: 'Reason'),
                            ErpColumn(title: 'Remarks'),
                            ErpColumn(title: 'Performed By'),
                          ],
                          rows: pageAdjustments.map((adj) {
                            final isPositive = adj.adjustmentQuantity > 0;
                            return [
                              Text(Formatters.formatDate(adj.adjustmentDate), style: AppTextStyles.bodySmall),
                              Text(adj.adjustmentNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(adj.itemCode, style: AppTextStyles.bodyBold.copyWith(fontSize: 11)),
                                  Text(adj.itemName, style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                                ],
                              ),
                              Text(
                                adj.itemType == ItemType.rawMaterial ? 'Raw Material' : 'Finished Product',
                                style: AppTextStyles.bodySmall,
                              ),
                              Text('${adj.currentStockBefore} ${adj.unit}', style: AppTextStyles.bodySmall),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  isPositive
                                      ? const StockInIcon(size: 16, color: Color(0xFF16A34A))
                                      : const StockOutIcon(size: 16, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${isPositive ? "+" : ""}${adj.adjustmentQuantity} ${adj.unit}',
                                    style: AppTextStyles.bodyBold.copyWith(
                                      color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                              Text('${adj.adjustedStockAfter} ${adj.unit}', style: AppTextStyles.bodyBold),
                              ErpStatusBadge(
                                label: adj.reasonLabel,
                                backgroundColor: AppColors.neutralLight,
                                textColor: AppColors.textPrimary,
                              ),
                              Text(adj.remarks ?? '-', style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(adj.performedBy, style: AppTextStyles.bodySmall),
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
