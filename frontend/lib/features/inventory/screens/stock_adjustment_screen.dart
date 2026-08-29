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
import '../../../core/widgets/erp_data_table.dart';
import '../../../shared/providers/app_state_providers.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  const StockAdjustmentScreen({super.key});

  @override
  ConsumerState<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  void _openCreateAdjustmentDialog() {
    final db = ref.read(databaseServiceProvider);
    ItemType selectedItemType = ItemType.finishedProduct;
    String selectedItemId = db.finishedProducts.isNotEmpty ? db.finishedProducts.first.id : '';
    AdjustmentReason selectedReason = AdjustmentReason.physicalCountMismatch;
    final newQtyCtrl = TextEditingController();
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

            final parsedNewQty = double.tryParse(newQtyCtrl.text.trim()) ?? currentStock;
            final diff = parsedNewQty - currentStock;

            return AlertDialog(
              title: Text('Record Stock Adjustment', style: AppTextStyles.h2),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<ItemType>(
                                title: const Text('Finished Product'),
                                value: ItemType.finishedProduct,
                                groupValue: selectedItemType,
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
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedItemId,
                          decoration: const InputDecoration(labelText: 'Select Item *'),
                          items: selectedItemType == ItemType.rawMaterial
                              ? db.rawMaterials.map((rm) {
                                  return DropdownMenuItem(
                                    value: rm.id,
                                    child: Text('${rm.itemCode} - ${rm.name} (Stock: ${rm.currentStock} ${rm.unit})'),
                                  );
                                }).toList()
                              : db.finishedProducts.map((fp) {
                                  return DropdownMenuItem(
                                    value: fp.id,
                                    child: Text('${fp.itemCode} - ${fp.name} (Stock: ${fp.currentStock} ${fp.unit})'),
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
                        TextFormField(
                          controller: newQtyCtrl,
                          keyboardType: TextInputType.number,
                          validator: Validators.nonNegativeNumber,
                          onChanged: (_) => setDlgState(() {}),
                          decoration: InputDecoration(
                            labelText: 'New Actual Physical Stock ($unit) *',
                            hintText: 'Enter physical count',
                          ),
                        ),
                        if (newQtyCtrl.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Adjustment Quantity: ${diff >= 0 ? "+${Formatters.formatNumber(diff)}" : Formatters.formatNumber(diff)} $unit',
                            style: AppTextStyles.bodyBold.copyWith(
                              color: diff >= 0 ? AppColors.successText : AppColors.dangerText,
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        DropdownButtonFormField<AdjustmentReason>(
                          value: selectedReason,
                          decoration: const InputDecoration(labelText: 'Reason for Adjustment *'),
                          items: AdjustmentReason.values.map((r) {
                            return DropdownMenuItem(
                              value: r,
                              child: Text(r.toString().split('.').last.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}').toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDlgState(() => selectedReason = val);
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
                    final targetQty = double.parse(newQtyCtrl.text.trim());
                    final adjDiff = targetQty - currentStock;

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

                    db.performStockAdjustment(adjustment);
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
                  Text('Stock Adjustments', style: AppTextStyles.h1),
                  const SizedBox(height: 4),
                  Text('Reconcile physical stock counts, log damages, and record audited corrections', style: AppTextStyles.subtitle),
                ],
              ),
              ErpButton(
                text: 'New Stock Adjustment',
                icon: Icons.tune_rounded,
                onPressed: _openCreateAdjustmentDialog,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Data Table of adjustments
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
            rows: db.stockAdjustments.map((adj) {
              return [
                Text(Formatters.formatDateTime(adj.adjustmentDate), style: AppTextStyles.bodySmall),
                Text(adj.adjustmentNumber, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(adj.itemCode, style: AppTextStyles.bodyBold.copyWith(fontSize: 12)),
                    Text(adj.itemName, style: AppTextStyles.bodySmall),
                  ],
                ),
                Text(adj.itemType == ItemType.rawMaterial ? 'Raw Material' : 'Finished Product', style: AppTextStyles.bodySmall),
                Text('${Formatters.formatNumber(adj.currentStockBefore)} ${adj.unit}', style: AppTextStyles.bodySmall),
                Text(
                  '${adj.adjustmentQuantity >= 0 ? "+" : ""}${Formatters.formatNumber(adj.adjustmentQuantity)} ${adj.unit}',
                  style: AppTextStyles.bodyBold.copyWith(
                    color: adj.adjustmentQuantity >= 0 ? AppColors.successText : AppColors.dangerText,
                  ),
                ),
                Text('${Formatters.formatNumber(adj.adjustedStockAfter)} ${adj.unit}', style: AppTextStyles.bodyBold),
                Text(adj.reasonLabel, style: AppTextStyles.bodyMedium),
                Text(adj.remarks, style: AppTextStyles.bodySmall),
                Text(adj.performedBy, style: AppTextStyles.bodySmall),
              ];
            }).toList(),
          ),
        ],
      ),
    );
  }
}
