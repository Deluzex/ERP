import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/production_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../shared/providers/app_state_providers.dart';

class _RawMaterialUsageDraft {
  String rawMaterialId;
  String rawMaterialName;
  String rawMaterialCode;
  String unit;
  double quantityUsed;
  double unitCost;

  _RawMaterialUsageDraft({
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.rawMaterialCode,
    required this.unit,
    required this.quantityUsed,
    required this.unitCost,
  });

  double get totalCost => quantityUsed * unitCost;
}

class CreateProductionScreen extends ConsumerStatefulWidget {
  const CreateProductionScreen({super.key});

  @override
  ConsumerState<CreateProductionScreen> createState() => _CreateProductionScreenState();
}

class _CreateProductionScreenState extends ConsumerState<CreateProductionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _actualQtyCtrl = TextEditingController(text: '20');
  final _labourCostCtrl = TextEditingController(text: '3000');
  final _otherExpensesCtrl = TextEditingController(text: '1200');
  final _notesCtrl = TextEditingController();

  String? _selectedFinishedProductId;
  final List<_RawMaterialUsageDraft> _rawMaterialsUsed = [];
  bool _overrideStockValidation = false;

  bool get _hasLowStockWarning {
    final db = ref.read(databaseServiceProvider);
    for (final usage in _rawMaterialsUsed) {
      final rmIndex = db.rawMaterials.indexWhere((r) => r.id == usage.rawMaterialId);
      if (rmIndex != -1) {
        final rm = db.rawMaterials[rmIndex];
        if (rm.currentStock < usage.quantityUsed) {
          return true;
        }
      }
    }
    return false;
  }

  void _calculateBomRequirements() {
    final db = ref.read(databaseServiceProvider);
    if (_selectedFinishedProductId == null) return;
    final prodQty = double.tryParse(_actualQtyCtrl.text.trim()) ?? 0.0;

    setState(() {
      _rawMaterialsUsed.clear();
      // Every finished good unit requires:
      // - 1.2 units of first Raw Material
      // - 0.7 units of second Raw Material
      if (db.rawMaterials.isNotEmpty) {
        final rm1 = db.rawMaterials[0];
        _rawMaterialsUsed.add(_RawMaterialUsageDraft(
          rawMaterialId: rm1.id,
          rawMaterialName: rm1.name,
          rawMaterialCode: rm1.itemCode,
          unit: rm1.unit,
          quantityUsed: prodQty * 1.2,
          unitCost: rm1.defaultPurchasePrice,
        ));
        
        if (db.rawMaterials.length > 1) {
          final rm2 = db.rawMaterials[1];
          _rawMaterialsUsed.add(_RawMaterialUsageDraft(
            rawMaterialId: rm2.id,
            rawMaterialName: rm2.name,
            rawMaterialCode: rm2.itemCode,
            unit: rm2.unit,
            quantityUsed: prodQty * 0.7,
            unitCost: rm2.defaultPurchasePrice,
          ));
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseServiceProvider);
    if (db.finishedProducts.isNotEmpty) {
      _selectedFinishedProductId = db.finishedProducts.first.id;
    }
    
    _actualQtyCtrl.addListener(() {
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateBomRequirements();
    });
  }

  void _addRawMaterial() {
    final db = ref.read(databaseServiceProvider);
    if (db.rawMaterials.isEmpty) return;
    final rm = db.rawMaterials.first;
    setState(() {
      _rawMaterialsUsed.add(_RawMaterialUsageDraft(
        rawMaterialId: rm.id,
        rawMaterialName: rm.name,
        rawMaterialCode: rm.itemCode,
        unit: rm.unit,
        quantityUsed: 10.0,
        unitCost: rm.defaultPurchasePrice,
      ));
    });
  }

  void _removeRawMaterial(int index) {
    if (_rawMaterialsUsed.length > 1) {
      setState(() => _rawMaterialsUsed.removeAt(index));
    }
  }

  double get _rawMaterialCost => _rawMaterialsUsed.fold(0.0, (sum, item) => sum + item.totalCost);
  double get _labourCost => double.tryParse(_labourCostCtrl.text.trim()) ?? 0.0;
  double get _otherExpenses => double.tryParse(_otherExpensesCtrl.text.trim()) ?? 0.0;
  double get _totalProductionCost => _rawMaterialCost + _labourCost + _otherExpenses;
  double get _actualQty => double.tryParse(_actualQtyCtrl.text.trim()) ?? 1.0;
  double get _costPerUnit => _actualQty > 0 ? _totalProductionCost / _actualQty : 0.0;

  bool _isSubmitting = false;

  Future<void> _completeProduction() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    final db = ref.read(databaseServiceProvider);
    final fp = db.finishedProducts.firstWhere((p) => p.id == _selectedFinishedProductId, orElse: () => db.finishedProducts.first);

    // Check available raw material stock
    for (final usage in _rawMaterialsUsed) {
      final rm = db.rawMaterials.firstWhere((r) => r.id == usage.rawMaterialId, orElse: () => db.rawMaterials.first);
      if (rm.currentStock < usage.quantityUsed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Insufficient stock for ${rm.name}! Available: ${rm.currentStock} ${rm.unit}, Required: ${usage.quantityUsed} ${rm.unit}'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }

    final usageList = _rawMaterialsUsed.map((u) {
      return ProductionRawMaterialUsage(
        rawMaterialId: u.rawMaterialId,
        rawMaterialName: u.rawMaterialName,
        rawMaterialCode: u.rawMaterialCode,
        quantityUsed: u.quantityUsed,
        unit: u.unit,
        unitCost: u.unitCost,
        totalCost: u.totalCost,
      );
    }).toList();

    final order = ProductionOrder(
      id: IdGenerator.generateId('PRD'),
      productionNumber: IdGenerator.generateDocNumber('PRD', db.nextProductionNumber),
      finishedProductId: fp.id,
      finishedProductName: fp.name,
      finishedProductCode: fp.itemCode,
      unit: fp.unit,
      plannedQuantity: _actualQty,
      actualQuantityProduced: _actualQty,
      rawMaterialsUsed: usageList,
      rawMaterialCost: _rawMaterialCost,
      labourCost: _labourCost,
      otherExpenses: _otherExpenses,
      totalProductionCost: _totalProductionCost,
      costPerUnit: _costPerUnit,
      productionDate: DateTime.now(),
      status: ProductionStatus.completed,
      notes: _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    setState(() => _isSubmitting = true);
    try {
      await db.completeProductionOrderAsync(order);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Production Completed! ${Formatters.formatNumber(_actualQty)} ${fp.unit} added to Finished Goods stock.'),
          backgroundColor: AppColors.success,
        ),
      );
      ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionOrders;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error completing production: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseServiceProvider);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Production Order', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text('Consume raw materials, record labor & overhead expenses, and output finished goods', style: AppTextStyles.subtitle),
                  ],
                ),
                Row(
                  children: [
                    ErpButton(
                      text: 'Cancel',
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionOrders,
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: 'Complete & Produce Stock',
                      icon: Icons.check_circle_outline,
                      onPressed: _completeProduction,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Product & Quantities Card
            Container(
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Finished Product to Produce', style: AppTextStyles.h3),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: _selectedFinishedProductId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Finished Product *'),
                          items: db.finishedProducts.map((fp) {
                            return DropdownMenuItem(
                              value: fp.id,
                              child: Text(
                                '${fp.itemCode} - ${fp.name} (Stock: ${fp.currentStock} ${fp.unit})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedFinishedProductId = val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _actualQtyCtrl,
                          keyboardType: TextInputType.number,
                          validator: Validators.positiveNumber,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Production Quantity *'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Raw Material Consumption Table
            Container(
              padding: AppSpacing.cardPadding,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Raw Materials Consumed', style: AppTextStyles.h3),
                      ErpButton(
                        text: 'Add Raw Material',
                        icon: Icons.add,
                        isOutlined: true,
                        onPressed: _addRawMaterial,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width < 1200 ? 980 : MediaQuery.of(context).size.width - 320,
                      ),
                      child: Column(
                        children: List.generate(_rawMaterialsUsed.length, (index) {
                          final item = _rawMaterialsUsed[index];
                          final prodQty = _actualQty > 0 ? _actualQty : 1.0;
                          final perUnitQty = item.quantityUsed / prodQty;
                          final perUnitCost = item.totalCost / prodQty;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: AppRadius.smBorderRadius,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 260,
                                  child: DropdownButtonFormField<String>(
                                    value: item.rawMaterialId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Raw Material'),
                                    items: db.rawMaterials.map((r) {
                                      return DropdownMenuItem(
                                        value: r.id,
                                        child: Text(
                                          '${r.itemCode} - ${r.name}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        final selected = db.rawMaterials.firstWhere((r) => r.id == val);
                                        setState(() {
                                          item.rawMaterialId = selected.id;
                                          item.rawMaterialName = selected.name;
                                          item.rawMaterialCode = selected.itemCode;
                                          item.unit = selected.unit;
                                          item.unitCost = selected.defaultPurchasePrice;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 130,
                                  child: TextFormField(
                                    initialValue: item.quantityUsed.toString(),
                                    keyboardType: TextInputType.number,
                                    validator: Validators.positiveNumber,
                                    decoration: InputDecoration(labelText: 'Total Qty (${item.unit})'),
                                    onChanged: (v) {
                                      final num = double.tryParse(v) ?? 0.0;
                                      setState(() => item.quantityUsed = num);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 120,
                                  child: TextFormField(
                                    initialValue: item.unitCost.toString(),
                                    keyboardType: TextInputType.number,
                                    validator: Validators.positiveNumber,
                                    decoration: const InputDecoration(labelText: 'Unit Cost (₹)'),
                                    onChanged: (v) {
                                      final num = double.tryParse(v) ?? 0.0;
                                      setState(() => item.unitCost = num);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 14),

                                // Per Product Raw Material Calculation Card
                                Container(
                                  width: 190,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: AppRadius.smBorderRadius,
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Per Product:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
                                          Text(
                                            Formatters.formatCurrency(perUnitCost),
                                            style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${perUnitQty.toStringAsFixed(2)} ${item.unit} / unit',
                                        style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 14),
                                SizedBox(
                                  width: 110,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Total Cost', style: AppTextStyles.bodySmall),
                                      Text(
                                        Formatters.formatCurrency(item.totalCost),
                                        style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                  onPressed: () => _removeRawMaterial(index),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  // Per Product BOM Recipe Summary Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: AppRadius.smBorderRadius,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calculate_outlined, color: AppColors.primaryDark, size: 22),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Per Product Raw Material Calculation',
                                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryDark),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'Raw Material Cost: ${Formatters.formatCurrency(_actualQty > 0 ? _rawMaterialCost / _actualQty : 0.0)} / unit',
                            style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Costing & Overhead Breakdown
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: AppSpacing.cardPadding,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.lgBorderRadius,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Labour & Additional Overhead Expenses', style: AppTextStyles.h3),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _labourCostCtrl,
                                keyboardType: TextInputType.number,
                                validator: Validators.nonNegativeNumber,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(labelText: 'Direct Labour Cost (₹) *'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _otherExpensesCtrl,
                                keyboardType: TextInputType.number,
                                validator: Validators.nonNegativeNumber,
                                onChanged: (_) => setState(() {}),
                                decoration: const InputDecoration(labelText: 'Other Expenses / Overheads (₹) *'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: AppSpacing.cardPadding,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.lgBorderRadius,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Production Costing Summary', style: AppTextStyles.h3),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Raw Material Cost:', style: AppTextStyles.bodyMedium),
                                Text(
                                  '(${Formatters.formatCurrency(_actualQty > 0 ? _rawMaterialCost / _actualQty : 0.0)} / unit)',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                            Text(Formatters.formatCurrency(_rawMaterialCost), style: AppTextStyles.bodyBold),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Labour Cost:', style: AppTextStyles.bodyMedium),
                                Text(
                                  '(${Formatters.formatCurrency(_actualQty > 0 ? _labourCost / _actualQty : 0.0)} / unit)',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                            Text(Formatters.formatCurrency(_labourCost), style: AppTextStyles.bodyBold),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Other Expenses:', style: AppTextStyles.bodyMedium),
                                Text(
                                  '(${Formatters.formatCurrency(_actualQty > 0 ? _otherExpenses / _actualQty : 0.0)} / unit)',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                            Text(Formatters.formatCurrency(_otherExpenses), style: AppTextStyles.bodyBold),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Production Cost:', style: AppTextStyles.bodyBold),
                            Text(Formatters.formatCurrency(_totalProductionCost), style: AppTextStyles.h2),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primarySoft,
                            borderRadius: AppRadius.smBorderRadius,
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Cost per Product:', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryDark)),
                                  Text('Materials + Labour + Overheads', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
                                ],
                              ),
                              Text(
                                Formatters.formatCurrency(_costPerUnit),
                                style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryDark, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
