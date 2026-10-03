import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/production_model.dart';
import '../../../core/models/raw_material_model.dart';
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

  List<({RawMaterial rm, double requiredQty, double availableStock, double deficit})> get _lowStockItems {
    final db = ref.read(databaseServiceProvider);
    final List<({RawMaterial rm, double requiredQty, double availableStock, double deficit})> list = [];
    for (final usage in _rawMaterialsUsed) {
      final rmIndex = db.rawMaterials.indexWhere((r) => r.id == usage.rawMaterialId);
      if (rmIndex != -1) {
        final rm = db.rawMaterials[rmIndex];
        if (rm.currentStock < usage.quantityUsed) {
          list.add((
            rm: rm,
            requiredQty: usage.quantityUsed,
            availableStock: rm.currentStock,
            deficit: usage.quantityUsed - rm.currentStock,
          ));
        }
      }
    }
    return list;
  }

  bool get _hasLowStockWarning => _lowStockItems.isNotEmpty;

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
  }

  @override
  void dispose() {
    _actualQtyCtrl.dispose();
    _labourCostCtrl.dispose();
    _otherExpensesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _showAddRawMaterialDialog() async {
    final db = ref.read(databaseServiceProvider);
    if (db.rawMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No raw materials found in inventory catalog.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final dialogFormKey = GlobalKey<FormState>();
    String? selectedRmId = db.rawMaterials.first.id;
    final firstRm = db.rawMaterials.first;
    final qtyCtrl = TextEditingController(text: '10');
    final unitCostCtrl = TextEditingController(text: firstRm.defaultPurchasePrice.toString());

    final draft = await showDialog<_RawMaterialUsageDraft>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final selectedRm = db.rawMaterials.firstWhere(
            (r) => r.id == selectedRmId,
            orElse: () => db.rawMaterials.first,
          );
          final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
          final unitCost = double.tryParse(unitCostCtrl.text.trim()) ?? 0.0;
          final lineTotal = qty * unitCost;
          final prodQty = _actualQty > 0 ? _actualQty : 1.0;
          final perUnitCost = lineTotal / prodQty;
          final isStockShort = selectedRm.currentStock < qty;

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppRadius.smBorderRadius,
                  ),
                  child: const Icon(Icons.grain, color: AppColors.primaryDark, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Raw Material', style: AppTextStyles.h3),
                      Text(
                        'Select component and specify batch quantity to consume',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              width: double.infinity,
              child: Form(
                key: dialogFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Raw Material Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedRmId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Raw Material *',
                          prefixIcon: Icon(Icons.inventory_2_outlined, size: 20),
                        ),
                        items: db.rawMaterials.map((rm) {
                          return DropdownMenuItem(
                            value: rm.id,
                            child: Text(
                              '${rm.itemCode} - ${rm.name} (Stock: ${Formatters.formatNumber(rm.currentStock)} ${rm.unit})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final chosen = db.rawMaterials.firstWhere((r) => r.id == val);
                            setDlgState(() {
                              selectedRmId = chosen.id;
                              unitCostCtrl.text = chosen.defaultPurchasePrice.toString();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Current Stock Status Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isStockShort ? AppColors.dangerLight : AppColors.successLight,
                          borderRadius: AppRadius.smBorderRadius,
                          border: Border.all(
                            color: isStockShort ? AppColors.danger : AppColors.success,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isStockShort ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                              size: 18,
                              color: isStockShort ? AppColors.dangerText : AppColors.successText,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isStockShort
                                    ? 'Low Stock: Available ${Formatters.formatNumber(selectedRm.currentStock)} ${selectedRm.unit} (Short by ${Formatters.formatNumber(qty - selectedRm.currentStock)} ${selectedRm.unit})'
                                    : 'Available in Stock: ${Formatters.formatNumber(selectedRm.currentStock)} ${selectedRm.unit}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isStockShort ? AppColors.dangerText : AppColors.successText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Quantity and Unit Cost
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: qtyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: Validators.positiveNumber,
                              decoration: InputDecoration(
                                labelText: 'Quantity (${selectedRm.unit}) *',
                                prefixIcon: const Icon(Icons.numbers, size: 20),
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: unitCostCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: Validators.positiveNumber,
                              decoration: const InputDecoration(
                                labelText: 'Unit Cost (₹) *',
                                prefixIcon: Icon(Icons.currency_rupee, size: 20),
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Cost Preview Card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: AppRadius.smBorderRadius,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Line Total Cost:', style: AppTextStyles.bodySmall),
                                Text(
                                  Formatters.formatCurrency(lineTotal),
                                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, fontSize: 15),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Per Finished Good:', style: AppTextStyles.bodySmall),
                                Text(
                                  '${Formatters.formatCurrency(perUnitCost)} / unit',
                                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.textPrimary, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            actions: [
              ErpButton(
                text: 'Cancel',
                isOutlined: true,
                onPressed: () {
                  FocusScope.of(ctx).unfocus();
                  Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(width: 8),
              ErpButton(
                text: 'Add to Order',
                icon: Icons.add,
                onPressed: () {
                  if (!dialogFormKey.currentState!.validate()) return;
                  FocusScope.of(ctx).unfocus();
                  final chosenRm = db.rawMaterials.firstWhere((r) => r.id == selectedRmId);
                  final enteredQty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                  final enteredCost = double.tryParse(unitCostCtrl.text.trim()) ?? chosenRm.defaultPurchasePrice;

                  Navigator.of(ctx).pop(_RawMaterialUsageDraft(
                    rawMaterialId: chosenRm.id,
                    rawMaterialName: chosenRm.name,
                    rawMaterialCode: chosenRm.itemCode,
                    unit: chosenRm.unit,
                    quantityUsed: enteredQty,
                    unitCost: enteredCost,
                  ));
                },
              ),
            ],
          );
        },
      ),
    );

    if (draft != null && mounted) {
      setState(() {
        final existingIndex = _rawMaterialsUsed.indexWhere((u) => u.rawMaterialId == draft.rawMaterialId);
        if (existingIndex != -1) {
          _rawMaterialsUsed[existingIndex].quantityUsed += draft.quantityUsed;
          _rawMaterialsUsed[existingIndex].unitCost = draft.unitCost;
        } else {
          _rawMaterialsUsed.add(draft);
        }
      });
    }
  }

  void _addRawMaterial() {
    _showAddRawMaterialDialog();
  }

  void _removeRawMaterial(int index) {
    setState(() => _rawMaterialsUsed.removeAt(index));
  }

  double get _rawMaterialCost => _rawMaterialsUsed.fold(0.0, (sum, item) => sum + item.totalCost);
  double get _labourCost => double.tryParse(_labourCostCtrl.text.trim()) ?? 0.0;
  double get _otherExpenses => double.tryParse(_otherExpensesCtrl.text.trim()) ?? 0.0;
  double get _totalProductionCost => _rawMaterialCost + _labourCost + _otherExpenses;
  double get _actualQty => double.tryParse(_actualQtyCtrl.text.trim()) ?? 1.0;
  double get _costPerUnit => _actualQty > 0 ? _totalProductionCost / _actualQty : 0.0;

  String? _submittingAction;
  bool get _isSavingPlanned => _submittingAction == 'planned';
  bool get _isCompleting => _submittingAction == 'complete';
  bool get _isSubmitting => _submittingAction != null;

  Future<void> _completeProduction() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_rawMaterialsUsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one raw material before submitting the production order.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final db = ref.read(databaseServiceProvider);
    final fp = db.finishedProducts.firstWhere((p) => p.id == _selectedFinishedProductId, orElse: () => db.finishedProducts.first);

    // 2. Strict Low Stock Blocking Validation (mentor directive)
    if (_hasLowStockWarning) {
      final shortList = _lowStockItems;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdBorderRadius),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Cannot Save Production Order', style: TextStyle(color: AppColors.danger, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Insufficient raw material stock. You cannot save or produce this batch until required components are in stock:'),
              const SizedBox(height: 12),
              ...shortList.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: AppRadius.smBorderRadius,
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${s.rm.itemCode} - ${s.rm.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Text(
                      'Available: ${Formatters.formatNumber(s.availableStock)} ${s.rm.unit} | Required: ${Formatters.formatNumber(s.requiredQty)} ${s.rm.unit} (Short by: ${Formatters.formatNumber(s.deficit)} ${s.rm.unit})',
                      style: const TextStyle(color: AppColors.dangerText, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 6),
              const Text(
                'Please inward required items via Purchase Module or reduce batch quantity.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          actions: [
            ErpButton(
              text: 'OK, I Understand',
              isOutlined: true,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
      );
      return;
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

    setState(() => _submittingAction = 'complete');
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
        setState(() => _submittingAction = null);
      }
    }
  }

  Future<void> _saveAsPlanned() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_rawMaterialsUsed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one raw material before submitting the production order.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final db = ref.read(databaseServiceProvider);
    final fp = db.finishedProducts.firstWhere((p) => p.id == _selectedFinishedProductId, orElse: () => db.finishedProducts.first);

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
      actualQuantityProduced: 0.0,
      rawMaterialsUsed: usageList,
      rawMaterialCost: _rawMaterialCost,
      labourCost: _labourCost,
      otherExpenses: _otherExpenses,
      totalProductionCost: _totalProductionCost,
      costPerUnit: _costPerUnit,
      productionDate: DateTime.now(),
      status: ProductionStatus.planned,
      notes: _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    setState(() => _submittingAction = 'planned');
    try {
      await db.completeProductionOrderAsync(order);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Production Order saved as Waiting Approval (Planned). Stock has not been deducted.'),
          backgroundColor: AppColors.primary,
        ),
      );
      ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionOrders;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving production order: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submittingAction = null);
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
            LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 650;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: isSmall ? double.infinity : constraints.maxWidth - 460),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Create Production Order', style: AppTextStyles.h1),
                          const SizedBox(height: 4),
                          Text('Consume raw materials, record labor & overhead expenses, and output finished goods', style: AppTextStyles.subtitle),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        ErpButton(
                          text: 'Cancel',
                          isOutlined: true,
                          onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionOrders,
                        ),
                        ErpButton(
                          text: 'Save as Waiting Approval',
                          icon: Icons.hourglass_top_outlined,
                          isOutlined: true,
                          isLoading: _isSavingPlanned == true,
                          onPressed: _isSubmitting ? null : _saveAsPlanned,
                        ),
                        ErpButton(
                          text: 'Complete & Produce Stock',
                          icon: Icons.check_circle_outline,
                          isLoading: _isCompleting == true,
                          onPressed: _isSubmitting ? null : _completeProduction,
                        ),
                      ],
                    ),
                  ],
                );
              },
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 550;
                      if (isNarrow) {
                        return Column(
                          children: [
                            DropdownButtonFormField<String>(
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
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _actualQtyCtrl,
                              keyboardType: TextInputType.number,
                              validator: Validators.positiveNumber,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(labelText: 'Production Quantity *'),
                            ),
                          ],
                        );
                      }
                      return Row(
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
                      );
                    },
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 650;
                      final title = Text('Raw Materials Consumed', style: AppTextStyles.h3);
                      final button = ErpButton(
                        text: 'Add Raw Material',
                        icon: Icons.grain,
                        isOutlined: true,
                        onPressed: _addRawMaterial,
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            title,
                            const SizedBox(height: 10),
                            button,
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          title,
                          button,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_rawMaterialsUsed.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: AppRadius.smBorderRadius,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.grain, size: 36, color: AppColors.textMuted),
                          const SizedBox(height: 10),
                          Text('No raw materials added yet', style: AppTextStyles.bodyBold),
                          const SizedBox(height: 4),
                          Text(
                            'Click "Add Raw Material" above to select components for this production batch.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 14),
                          ErpButton(
                            text: 'Add Raw Material',
                            icon: Icons.grain,
                            isOutlined: true,
                            onPressed: _addRawMaterial,
                          ),
                        ],
                      ),
                    )
                  else ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width < 1300 ? 1280 : MediaQuery.of(context).size.width - 320,
                      ),
                      child: Column(
                        children: List.generate(_rawMaterialsUsed.length, (index) {
                          final item = _rawMaterialsUsed[index];
                          final prodQty = _actualQty > 0 ? _actualQty : 1.0;
                          final perUnitQty = item.quantityUsed / prodQty;
                          final perUnitCost = item.totalCost / prodQty;
                          final rm = db.rawMaterials.firstWhere(
                            (r) => r.id == item.rawMaterialId,
                            orElse: () => db.rawMaterials.first,
                          );
                          final isStockShort = rm.currentStock < item.quantityUsed;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isStockShort ? AppColors.dangerLight.withValues(alpha: 0.2) : AppColors.surfaceMuted,
                              borderRadius: AppRadius.smBorderRadius,
                              border: Border.all(
                                color: isStockShort ? AppColors.danger : AppColors.border,
                                width: isStockShort ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 320,
                                  child: DropdownButtonFormField<String>(
                                    value: item.rawMaterialId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Raw Material'),
                                    items: db.rawMaterials.map((r) {
                                      return DropdownMenuItem(
                                        value: r.id,
                                        child: Text(
                                          '${r.itemCode} - ${r.name} (Stock: ${Formatters.formatNumber(r.currentStock)} ${r.unit})',
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

                                // Current Stock Status Pill (matching popup)
                                Container(
                                  width: 190,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isStockShort ? AppColors.dangerLight : AppColors.successLight,
                                    borderRadius: AppRadius.smBorderRadius,
                                    border: Border.all(
                                      color: isStockShort ? AppColors.danger : AppColors.success,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isStockShort ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                                        size: 16,
                                        color: isStockShort ? AppColors.dangerText : AppColors.successText,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              isStockShort ? 'Low Stock' : 'In Stock',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: isStockShort ? AppColors.dangerText : AppColors.successText,
                                              ),
                                            ),
                                            Text(
                                              isStockShort
                                                  ? 'Avail: ${Formatters.formatNumber(rm.currentStock)} ${rm.unit} (Short: ${Formatters.formatNumber(item.quantityUsed - rm.currentStock)})'
                                                  : 'Avail: ${Formatters.formatNumber(rm.currentStock)} ${rm.unit}',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: isStockShort ? AppColors.dangerText : AppColors.successText,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
                                  width: 220,
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
                                          Expanded(
                                            child: Text(
                                              'Per Product:',
                                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
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
                    child: LayoutBuilder(
                      builder: (context, bannerBox) {
                        final isNarrow = bannerBox.maxWidth < 650;
                        final leftBlock = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calculate_outlined, color: AppColors.primaryDark, size: 22),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                'Per Product Raw Material Calculation',
                                style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryDark),
                              ),
                            ),
                          ],
                        );

                        final rightPill = Container(
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
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              leftBlock,
                              const SizedBox(height: 10),
                              rightPill,
                            ],
                          );
                        }

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: leftBlock),
                            const SizedBox(width: 12),
                            rightPill,
                          ],
                        );
                      },
                    ),
                  ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Costing & Overhead Breakdown
            LayoutBuilder(
              builder: (context, costBox) {
                final isStacked = costBox.maxWidth < 800;

                final labourCard = Container(
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
                      LayoutBuilder(
                        builder: (context, fieldBox) {
                          final isFieldStacked = fieldBox.maxWidth < 500;
                          final labourField = TextFormField(
                            controller: _labourCostCtrl,
                            keyboardType: TextInputType.number,
                            validator: Validators.nonNegativeNumber,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Direct Labour Cost (₹) *'),
                          );
                          final otherField = TextFormField(
                            controller: _otherExpensesCtrl,
                            keyboardType: TextInputType.number,
                            validator: Validators.nonNegativeNumber,
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(labelText: 'Other Expenses / Overheads (₹) *'),
                          );

                          if (isFieldStacked) {
                            return Column(
                              children: [
                                labourField,
                                const SizedBox(height: 16),
                                otherField,
                              ],
                            );
                          }

                          return Row(
                            children: [
                              Expanded(child: labourField),
                              const SizedBox(width: 16),
                              Expanded(child: otherField),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                );

                final summaryCard = Container(
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Raw Material Cost:', style: AppTextStyles.bodyMedium),
                                Text(
                                  '(${Formatters.formatCurrency(_actualQty > 0 ? _rawMaterialCost / _actualQty : 0.0)} / unit)',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(Formatters.formatCurrency(_rawMaterialCost), style: AppTextStyles.bodyBold),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Labour Cost:', style: AppTextStyles.bodyMedium),
                                Text(
                                  '(${Formatters.formatCurrency(_actualQty > 0 ? _labourCost / _actualQty : 0.0)} / unit)',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(Formatters.formatCurrency(_labourCost), style: AppTextStyles.bodyBold),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Other Expenses:', style: AppTextStyles.bodyMedium),
                                Text(
                                  '(${Formatters.formatCurrency(_actualQty > 0 ? _otherExpenses / _actualQty : 0.0)} / unit)',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(Formatters.formatCurrency(_otherExpenses), style: AppTextStyles.bodyBold),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('Total Production Cost:', style: AppTextStyles.bodyBold)),
                          const SizedBox(width: 8),
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
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Cost per Product:', style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryDark)),
                                  Text('Materials + Labour + Overheads', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              Formatters.formatCurrency(_costPerUnit),
                              style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryDark, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );

                if (isStacked) {
                  return Column(
                    children: [
                      labourCard,
                      const SizedBox(height: 16),
                      summaryCard,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: labourCard),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: summaryCard),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            // Bottom Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ErpButton(
                  text: 'Cancel',
                  isOutlined: true,
                  onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.productionOrders,
                ),
                const SizedBox(width: 10),
                ErpButton(
                  text: 'Save as Waiting Approval',
                  icon: Icons.hourglass_top_outlined,
                  isOutlined: true,
                  isLoading: _isSavingPlanned == true,
                  onPressed: _isSubmitting ? null : _saveAsPlanned,
                ),
                const SizedBox(width: 10),
                ErpButton(
                  text: 'Complete & Produce Stock',
                  icon: Icons.check_circle_outline,
                  isLoading: _isCompleting == true,
                  onPressed: _isSubmitting ? null : _completeProduction,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
