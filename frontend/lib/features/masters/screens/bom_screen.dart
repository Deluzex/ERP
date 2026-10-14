import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/bom_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_data_table.dart';
import '../../../core/widgets/erp_filter_controls.dart';
import '../../../core/widgets/erp_pagination_bar.dart';
import '../../../core/widgets/erp_status_badge.dart';
import '../../../shared/providers/app_state_providers.dart';

class _BomItemDraft {
  String rawMaterialId;
  String rawMaterialName;
  String rawMaterialCode;
  String unit;
  double quantityPerUnit;
  double wastagePercent;
  double unitCost;
  final TextEditingController qtyCtrl;
  final TextEditingController wastageCtrl;
  final TextEditingController unitCostCtrl;

  _BomItemDraft({
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.rawMaterialCode,
    required this.unit,
    required this.quantityPerUnit,
    this.wastagePercent = 0.0,
    required this.unitCost,
  })  : qtyCtrl = TextEditingController(
          text: quantityPerUnit % 1 == 0 ? quantityPerUnit.toInt().toString() : quantityPerUnit.toString(),
        ),
        wastageCtrl = TextEditingController(
          text: wastagePercent % 1 == 0 ? wastagePercent.toInt().toString() : wastagePercent.toString(),
        ),
        unitCostCtrl = TextEditingController(
          text: unitCost % 1 == 0 ? unitCost.toInt().toString() : unitCost.toString(),
        );

  void updateQuantity(double qty) {
    quantityPerUnit = qty;
    final text = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
    if (qtyCtrl.text != text) {
      qtyCtrl.text = text;
    }
  }

  void updateWastage(double w) {
    wastagePercent = w;
    final text = w % 1 == 0 ? w.toInt().toString() : w.toString();
    if (wastageCtrl.text != text) {
      wastageCtrl.text = text;
    }
  }

  void updateUnitCost(double cost) {
    unitCost = cost;
    final text = cost % 1 == 0 ? cost.toInt().toString() : cost.toString();
    if (unitCostCtrl.text != text) {
      unitCostCtrl.text = text;
    }
  }

  void dispose() {
    qtyCtrl.dispose();
    wastageCtrl.dispose();
    unitCostCtrl.dispose();
  }

  double get quantityWithWastage =>
      quantityPerUnit * (1.0 + (wastagePercent / 100.0));

  double get lineCost => quantityWithWastage * unitCost;
}

class BomScreen extends ConsumerStatefulWidget {
  const BomScreen({super.key});

  @override
  ConsumerState<BomScreen> createState() => _BomScreenState();
}

class _BomScreenState extends ConsumerState<BomScreen> {
  // Navigation / View state
  bool _isCreateMode = false;
  BillOfMaterial? _editingBom;

  // Filter & Search states for BOM List
  String _searchQuery = '';
  String _selectedProductFilter = 'ALL';
  String _statusFilter = 'ALL';
  int _currentPage = 0;
  int _pageSize = 10;

  // Form controllers for Create / Edit view
  final _formKey = GlobalKey<FormState>();
  final _bomNumberCtrl = TextEditingController();
  final _bomNameCtrl = TextEditingController();
  final _prodQtyCtrl = TextEditingController(text: '1');
  final _unitCtrl = TextEditingController();
  final _productCodeCtrl = TextEditingController();
  String? _selectedProductId;
  String _selectedStatus = 'Active';
  final List<_BomItemDraft> _draftItems = [];

  static String _normalizeStatus(String? s) {
    if (s == null) return 'Active';
    final lower = s.trim().toLowerCase();
    if (lower == 'draft') return 'Draft';
    if (lower == 'inactive') return 'Inactive';
    return 'Active';
  }

  @override
  void dispose() {
    _bomNumberCtrl.dispose();
    _bomNameCtrl.dispose();
    _prodQtyCtrl.dispose();
    _unitCtrl.dispose();
    _productCodeCtrl.dispose();
    for (final item in _draftItems) {
      item.dispose();
    }
    super.dispose();
  }

  void _startCreate() {
    final db = ref.read(databaseServiceProvider);
    _editingBom = null;
    for (final item in _draftItems) {
      item.dispose();
    }
    _draftItems.clear();

    final nextNum = 'BOM-${(db.boms.length + 1).toString().padLeft(3, '0')}';
    _bomNumberCtrl.text = nextNum;
    _prodQtyCtrl.text = '1';
    _selectedStatus = 'Active';

    if (db.finishedProducts.isNotEmpty) {
      final firstProd = db.finishedProducts.first;
      _selectedProductId = firstProd.id;
      _productCodeCtrl.text = firstProd.itemCode;
      _unitCtrl.text = firstProd.unit;
      _bomNameCtrl.text = '${firstProd.name} Recipe';
    } else {
      _selectedProductId = null;
      _productCodeCtrl.text = '';
      _unitCtrl.text = 'PCS';
      _bomNameCtrl.text = '';
    }

    setState(() {
      _isCreateMode = true;
    });
  }

  void _startEdit(BillOfMaterial bom) {
    _editingBom = bom;
    for (final item in _draftItems) {
      item.dispose();
    }
    _draftItems.clear();
    for (final itm in bom.items) {
      _draftItems.add(_BomItemDraft(
        rawMaterialId: itm.rawMaterialId,
        rawMaterialName: itm.safeName,
        rawMaterialCode: itm.safeCode,
        unit: itm.safeUnit,
        quantityPerUnit: itm.quantityPerUnit,
        wastagePercent: itm.wastagePercent,
        unitCost: itm.unitCost,
      ));
    }

    _bomNumberCtrl.text = bom.id;
    _bomNameCtrl.text = bom.safeName;
    _selectedProductId = bom.finishedProductId;
    _productCodeCtrl.text = bom.safeProductCode;
    _prodQtyCtrl.text = bom.outputQuantity % 1 == 0
        ? bom.outputQuantity.toInt().toString()
        : bom.outputQuantity.toString();
    _selectedStatus = _normalizeStatus(bom.safeStatus);

    final db = ref.read(databaseServiceProvider);
    final prod = db.finishedProducts.where((p) => p.id == bom.finishedProductId).firstOrNull;
    _unitCtrl.text = prod?.unit ?? 'PCS';

    setState(() {
      _isCreateMode = true;
    });
  }

  void _openChangeStatusDialog(BillOfMaterial bom) {
    String selected = _normalizeStatus(bom.safeStatus);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.published_with_changes, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Update BOM Status', style: AppTextStyles.h2),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change recipe status for "${bom.safeName}" (${bom.id}):',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 16),
                _buildStatusOption(
                  title: 'Active',
                  subtitle: 'Recipe is approved and available for manufacturing orders',
                  color: AppColors.success,
                  isSelected: selected == 'Active',
                  onTap: () => setDlgState(() => selected = 'Active'),
                ),
                const SizedBox(height: 10),
                _buildStatusOption(
                  title: 'Draft',
                  subtitle: 'Work-in-progress recipe, pending formulation sign-off',
                  color: AppColors.warning,
                  isSelected: selected == 'Draft',
                  onTap: () => setDlgState(() => selected = 'Draft'),
                ),
                const SizedBox(height: 10),
                _buildStatusOption(
                  title: 'Inactive',
                  subtitle: 'Archived formula, disabled for new production runs',
                  color: AppColors.danger,
                  isSelected: selected == 'Inactive',
                  onTap: () => setDlgState(() => selected = 'Inactive'),
                ),
              ],
            ),
          ),
          actions: [
            ErpButton(
              text: 'Cancel',
              isOutlined: true,
              onPressed: () => Navigator.pop(ctx),
            ),
            ErpButton(
              text: 'Update Status',
              onPressed: () {
                final db = ref.read(databaseServiceProvider);
                db.updateBom(bom.copyWith(
                  status: selected,
                  isActive: selected == 'Active',
                  updatedAt: DateTime.now(),
                ));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('BOM "${bom.safeName}" status updated to $selected!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openViewBomDialog(BillOfMaterial bom) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text('BOM Recipe: ${bom.id}', style: AppTextStyles.h2),
              ],
            ),
            _buildStatusBadge(bom.safeStatus),
          ],
        ),
        content: Container(
          constraints: const BoxConstraints(maxWidth: 750),
          width: double.infinity,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Recipe Overview Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('RECIPE NAME', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(bom.safeName, style: AppTextStyles.bodyBold),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('FINISHED PRODUCT', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('${bom.safeProductName} (${bom.safeProductCode})', style: AppTextStyles.bodyMedium),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BATCH QTY', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('${Formatters.formatNumber(bom.outputQuantity)} Units', style: AppTextStyles.bodyBold),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Cost Summary Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Est. Cost / Unit: ${Formatters.formatCurrency(bom.totalMaterialCostPerUnit)}',
                          style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryDark)),
                      Text('Total Batch Cost: ${Formatters.formatCurrency(bom.totalBatchMaterialCost)}',
                          style: AppTextStyles.bodyBold.copyWith(color: AppColors.primaryDark)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Components Table
                Text('Raw Material Components (${bom.items.length})', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppColors.background),
                    columns: const [
                      DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Component', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Code', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Qty/Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Unit', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Wastage %', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Qty w/ Wastage', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Rate', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Line Total', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: bom.items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final itm = entry.value;
                      return DataRow(
                        cells: [
                          DataCell(Text('${i + 1}')),
                          DataCell(Text(itm.safeName)),
                          DataCell(Text(itm.safeCode, style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600))),
                          DataCell(Text(Formatters.formatNumber(itm.quantityPerUnit))),
                          DataCell(Text(itm.safeUnit)),
                          DataCell(Text('${Formatters.formatNumber(itm.wastagePercent)}%')),
                          DataCell(Text(Formatters.formatNumber(itm.quantityWithWastage), style: AppTextStyles.bodyBold)),
                          DataCell(Text(Formatters.formatCurrency(itm.unitCost))),
                          DataCell(Text(Formatters.formatCurrency(itm.totalCostPerFinishedUnit), style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          ErpButton(
            text: 'Close',
            isOutlined: true,
            onPressed: () => Navigator.pop(ctx),
          ),
          ErpButton(
            text: 'Edit Recipe',
            icon: Icons.edit_outlined,
            isOutlined: true,
            onPressed: () {
              Navigator.pop(ctx);
              _startEdit(bom);
            },
          ),
          ErpButton(
            text: 'Produce',
            icon: Icons.precision_manufacturing_rounded,
            onPressed: () {
              Navigator.pop(ctx);
              _onProduce(bom);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOption({
    required String title,
    required String subtitle,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? color : AppColors.textMuted,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyBold.copyWith(color: isSelected ? color : AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveBom() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProductId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a finished product.')),
      );
      return;
    }
    if (_draftItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one raw material to the BOM recipe.')),
      );
      return;
    }

    final db = ref.read(databaseServiceProvider);
    final prod = db.finishedProducts.firstWhere((p) => p.id == _selectedProductId);
    final outputQty = double.tryParse(_prodQtyCtrl.text.trim()) ?? 1.0;
    final isEdit = _editingBom != null;
    final statusToSave = isEdit ? _selectedStatus : 'Active';

    final bomItems = _draftItems.map((d) {
      return BomItem(
        id: IdGenerator.generateId('BOM-ITM'),
        rawMaterialId: d.rawMaterialId,
        rawMaterialName: d.rawMaterialName,
        rawMaterialCode: d.rawMaterialCode,
        quantityPerUnit: d.quantityPerUnit,
        wastagePercent: d.wastagePercent,
        unit: d.unit,
        unitCost: d.unitCost,
      );
    }).toList();

    if (isEdit) {
      db.updateBom(_editingBom!.copyWith(
        name: _bomNameCtrl.text.trim(),
        outputQuantity: outputQty,
        status: statusToSave,
        isActive: statusToSave == 'Active',
        items: bomItems,
        updatedAt: DateTime.now(),
      ));
    } else {
      db.addBom(BillOfMaterial(
        id: _bomNumberCtrl.text.trim().isNotEmpty
            ? _bomNumberCtrl.text.trim()
            : IdGenerator.generateId('BOM'),
        finishedProductId: prod.id,
        finishedProductName: prod.name,
        finishedProductCode: prod.itemCode,
        name: _bomNameCtrl.text.trim(),
        outputQuantity: outputQty,
        status: statusToSave,
        isActive: true,
        items: bomItems,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    setState(() {
      _isCreateMode = false;
      _editingBom = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isEdit ? 'BOM updated successfully!' : 'BOM created successfully!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _confirmDeleteBom(BillOfMaterial bom) {
    final db = ref.read(databaseServiceProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete BOM Recipe', style: AppTextStyles.h2.copyWith(color: AppColors.danger)),
        content: Text(
          'Are you sure you want to delete recipe "${bom.safeName}" (${bom.id}) for product "${bom.safeProductName}"?\n\n'
          'This will remove the automated bill of materials linkage.',
        ),
        actions: [
          ErpButton(
            text: 'Cancel',
            isOutlined: true,
            onPressed: () => Navigator.pop(ctx),
          ),
          ErpButton(
            text: 'Delete',
            isDanger: true,
            onPressed: () {
              db.deleteBom(bom.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('BOM recipe deleted successfully!'), backgroundColor: AppColors.danger),
              );
            },
          ),
        ],
      ),
    );
  }

  void _onProduce(BillOfMaterial bom) {
    ref.read(selectedProductionProductIdProvider.notifier).state = bom.finishedProductId;
    ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.createProduction;
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
    final unusedRm = db.rawMaterials.where((rm) => !_draftItems.any((d) => d.rawMaterialId == rm.id)).firstOrNull ?? db.rawMaterials.first;
    String? selectedRmId = unusedRm.id;
    final qtyCtrl = TextEditingController(text: '1');
    final wastageCtrl = TextEditingController(text: '0');
    final unitCostCtrl = TextEditingController(
      text: unusedRm.defaultPurchasePrice % 1 == 0
          ? unusedRm.defaultPurchasePrice.toInt().toString()
          : unusedRm.defaultPurchasePrice.toString(),
    );

    final draft = await showDialog<_BomItemDraft>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final selectedRm = db.rawMaterials.firstWhere(
            (r) => r.id == selectedRmId,
            orElse: () => db.rawMaterials.first,
          );
          final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
          final wastage = double.tryParse(wastageCtrl.text.trim()) ?? 0.0;
          final unitCost = double.tryParse(unitCostCtrl.text.trim()) ?? 0.0;
          final batchOutputQty = double.tryParse(_prodQtyCtrl.text.trim()) ?? 1.0;

          final qtyWithWastage = qty * (1.0 + (wastage / 100.0));
          final lineCost = qtyWithWastage * unitCost;
          final batchCost = lineCost * batchOutputQty;
          final isStockShort = selectedRm.currentStock < (qtyWithWastage * batchOutputQty);

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
                        'Select component and specify quantity needed per finished good',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: Container(
              constraints: const BoxConstraints(maxWidth: 520),
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
                        initialValue: selectedRmId,
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
                              unitCostCtrl.text = chosen.defaultPurchasePrice % 1 == 0
                                  ? chosen.defaultPurchasePrice.toInt().toString()
                                  : chosen.defaultPurchasePrice.toString();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Current Stock Status Pill (matching create_production_screen)
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
                                    ? 'Low Stock: Available ${Formatters.formatNumber(selectedRm.currentStock)} ${selectedRm.unit} (Batch req: ${Formatters.formatNumber(qtyWithWastage * batchOutputQty)} ${selectedRm.unit})'
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

                      // Quantity, Wastage % and Unit Cost
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              controller: qtyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: Validators.positiveNumber,
                              decoration: InputDecoration(
                                labelText: 'Req. Qty (${selectedRm.unit}) *',
                                prefixIcon: const Icon(Icons.numbers, size: 20),
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: wastageCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return null;
                                final num = double.tryParse(v.trim());
                                if (num == null || num < 0) return 'Invalid';
                                return null;
                              },
                              decoration: const InputDecoration(
                                labelText: 'Wastage %',
                                suffixText: '%',
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 4,
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

                      // Cost Preview Card (matching create_production_screen)
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
                                Text('Qty Incl. Wastage:', style: AppTextStyles.bodySmall),
                                Text(
                                  '${Formatters.formatNumber(qtyWithWastage)} ${selectedRm.unit}',
                                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText, fontSize: 13),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text('Cost per Unit:', style: AppTextStyles.bodySmall),
                                Text(
                                  Formatters.formatCurrency(lineCost),
                                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, fontSize: 13),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Batch Total Cost:', style: AppTextStyles.bodySmall),
                                Text(
                                  Formatters.formatCurrency(batchCost),
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
                text: 'Add Raw Material',
                icon: Icons.add,
                onPressed: () {
                  if (!dialogFormKey.currentState!.validate()) return;
                  FocusScope.of(ctx).unfocus();
                  final chosenRm = db.rawMaterials.firstWhere((r) => r.id == selectedRmId);
                  final enteredQty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                  final enteredWastage = double.tryParse(wastageCtrl.text.trim()) ?? 0.0;
                  final enteredCost = double.tryParse(unitCostCtrl.text.trim()) ?? chosenRm.defaultPurchasePrice;

                  Navigator.of(ctx).pop(_BomItemDraft(
                    rawMaterialId: chosenRm.id,
                    rawMaterialName: chosenRm.name,
                    rawMaterialCode: chosenRm.itemCode,
                    unit: chosenRm.unit,
                    quantityPerUnit: enteredQty,
                    wastagePercent: enteredWastage,
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
        final existingIndex = _draftItems.indexWhere((u) => u.rawMaterialId == draft.rawMaterialId);
        if (existingIndex != -1) {
          _draftItems[existingIndex].updateQuantity(_draftItems[existingIndex].quantityPerUnit + draft.quantityPerUnit);
          _draftItems[existingIndex].updateWastage(draft.wastagePercent);
          _draftItems[existingIndex].updateUnitCost(draft.unitCost);
          draft.dispose();
        } else {
          _draftItems.add(draft);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCreateMode) {
      return _buildCreateEditView();
    }
    return _buildListView();
  }

  // ===========================================================================
  // VIEW 1: BOM LIST (MATCHING PROJECT ERP THEME)
  // ===========================================================================
  Widget _buildListView() {
    final db = ref.watch(databaseServiceProvider);

    final filteredBoms = db.boms.where((b) {
      final q = _searchQuery.trim().toLowerCase();
      final matchQuery = q.isEmpty ||
          b.id.toLowerCase().contains(q) ||
          b.safeName.toLowerCase().contains(q) ||
          b.safeProductName.toLowerCase().contains(q) ||
          b.safeProductCode.toLowerCase().contains(q);

      final matchProduct = _selectedProductFilter == 'ALL' ||
          b.finishedProductId == _selectedProductFilter;

      final currentStat = _normalizeStatus(b.safeStatus).toUpperCase();
      final matchStatus = _statusFilter == 'ALL' ||
          currentStat == _statusFilter.toUpperCase();

      return matchQuery && matchProduct && matchStatus;
    }).toList();

    // Metrics for the 4 KPI cards
    final totalBoms = db.boms.length;
    final activeBoms = db.boms.where((b) => _normalizeStatus(b.safeStatus) == 'Active').length;
    final draftBoms = db.boms.where((b) => _normalizeStatus(b.safeStatus) == 'Draft').length;
    final inactiveBoms = db.boms.where((b) => _normalizeStatus(b.safeStatus) == 'Inactive').length;

    // Pagination slice
    final totalRecords = filteredBoms.length;
    final safePageSize = _pageSize <= 0 ? 10 : _pageSize;
    final totalPages = (totalRecords <= 0) ? 1 : (totalRecords / safePageSize).ceil();
    final maxPage = totalPages > 0 ? totalPages - 1 : 0;
    final safeCurrentPage = _currentPage.clamp(0, maxPage);
    final startIndex = safeCurrentPage * safePageSize;
    final endIndex = (startIndex + safePageSize).clamp(0, totalRecords);
    final pagedBoms = totalRecords == 0 ? <BillOfMaterial>[] : filteredBoms.sublist(startIndex, endIndex);

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & + Create BOM button
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('BOM Master', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text(
                      'Manage manufacturing recipes, raw material consumption, and wastage per finished product',
                      style: AppTextStyles.subtitle,
                    ),
                    const SizedBox(height: 12),
                    ErpButton(
                      text: 'Create BOM',
                      icon: Icons.add,
                      onPressed: _startCreate,
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('BOM Master', style: AppTextStyles.h1),
                        const SizedBox(height: 4),
                        Text(
                          'Manage manufacturing recipes, raw material consumption, and wastage per finished product',
                          style: AppTextStyles.subtitle,
                        ),
                      ],
                    ),
                  ),
                  ErpButton(
                    text: 'Create BOM',
                    icon: Icons.add,
                    onPressed: _startCreate,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // 4 Metric Summary Cards in standard ERP style
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 900;
              if (isSmall) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(width: (constraints.maxWidth - 12) / 2, child: _buildKpiCard('Total BOMs', totalBoms.toString(), Icons.inventory_2_outlined, AppColors.primary)),
                    SizedBox(width: (constraints.maxWidth - 12) / 2, child: _buildKpiCard('Active BOMs', activeBoms.toString(), Icons.check_circle_outline, AppColors.success)),
                    SizedBox(width: (constraints.maxWidth - 12) / 2, child: _buildKpiCard('Draft BOMs', draftBoms.toString(), Icons.edit_note_outlined, AppColors.warning)),
                    SizedBox(width: (constraints.maxWidth - 12) / 2, child: _buildKpiCard('Inactive BOMs', inactiveBoms.toString(), Icons.cancel_outlined, AppColors.danger)),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: _buildKpiCard('Total BOMs', totalBoms.toString(), Icons.inventory_2_outlined, AppColors.primary)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildKpiCard('Active BOMs', activeBoms.toString(), Icons.check_circle_outline, AppColors.success)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildKpiCard('Draft BOMs', draftBoms.toString(), Icons.edit_note_outlined, AppColors.warning)),
                  const SizedBox(width: 14),
                  Expanded(child: _buildKpiCard('Inactive BOMs', inactiveBoms.toString(), Icons.cancel_outlined, AppColors.danger)),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Standard ERP Filter Controls Bar
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: ErpSearchInput(
                  hintText: 'Search by BOM #, recipe name, product...',
                  initialValue: _searchQuery,
                  onChanged: (v) => setState(() {
                    _searchQuery = v;
                    _currentPage = 0;
                  }),
                ),
              ),
              ErpFilterDropdown<String>(
                value: _selectedProductFilter,
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text('All Products')),
                  ...db.finishedProducts.map((p) {
                    return DropdownMenuItem<String>(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _selectedProductFilter = v;
                      _currentPage = 0;
                    });
                  }
                },
              ),
              ErpFilterDropdown<String>(
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('All Status')),
                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                  DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
                  DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _statusFilter = v;
                      _currentPage = 0;
                    });
                  }
                },
              ),
              ErpButton(
                text: 'Reset',
                icon: Icons.refresh,
                isOutlined: true,
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedProductFilter = 'ALL';
                    _statusFilter = 'ALL';
                    _currentPage = 0;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // BOM Recipes Data Table
          if (filteredBoms.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 48),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.description_outlined, size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  Text('No BOM recipes found matching your query.', style: AppTextStyles.bodyBold),
                  const SizedBox(height: 6),
                  Text('Click "Create BOM" above to register a manufacturing recipe.', style: AppTextStyles.caption),
                ],
              ),
            )
          else ...[
            ErpDataTable(
              columns: const [
                ErpColumn(title: 'BOM No.'),
                ErpColumn(title: 'BOM Name'),
                ErpColumn(title: 'Finished Product'),
                ErpColumn(title: 'Product Code'),
                ErpColumn(title: 'Total Material Cost', isNumeric: true),
                ErpColumn(title: 'Est. Cost / Unit', isNumeric: true),
                ErpColumn(title: 'Status'),
                ErpColumn(title: 'Created Date'),
                ErpColumn(title: 'Actions'),
              ],
              rows: pagedBoms.map((bom) {
                return [
                  // BOM No.
                  Text(
                    bom.id,
                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                  ),

                  // BOM Name (Plain text, details opened via action button)
                  Text(
                    bom.safeName,
                    style: AppTextStyles.bodyBold,
                  ),

                  // Finished Product
                  Text(
                    bom.safeProductName,
                    style: AppTextStyles.bodyMedium,
                  ),

                  // Product Code
                  Text(
                    bom.safeProductCode,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  // Total Material Cost
                  Text(
                    Formatters.formatCurrency(bom.totalBatchMaterialCost),
                    style: AppTextStyles.bodyMedium,
                  ),

                  // Est. Cost / Unit
                  Text(
                    Formatters.formatCurrency(bom.totalMaterialCostPerUnit),
                    style: AppTextStyles.bodyBold,
                  ),

                  // Status (non-clickable static badge)
                  _buildStatusBadge(bom.safeStatus),

                  // Created Date
                  Text(
                    Formatters.formatDate(bom.createdAt),
                    style: AppTextStyles.caption,
                  ),

                  // Actions: Single unified edit_note action menu matching Masters standard
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (action) {
                      switch (action) {
                        case 'view':
                          _openViewBomDialog(bom);
                          break;
                        case 'produce':
                          _onProduce(bom);
                          break;
                        case 'status':
                          _openChangeStatusDialog(bom);
                          break;
                        case 'edit':
                          _startEdit(bom);
                          break;
                        case 'delete':
                          _confirmDeleteBom(bom);
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
                            Text('View BOM Details'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'produce',
                        child: Row(
                          children: [
                            Icon(Icons.precision_manufacturing_rounded, color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text('Produce / Create Production'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'status',
                        child: Row(
                          children: [
                            Icon(Icons.published_with_changes, color: AppColors.primary, size: 18),
                            SizedBox(width: 8),
                            Text('Update Status'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('Edit Recipe'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                            SizedBox(width: 8),
                            Text('Delete Recipe', style: TextStyle(color: AppColors.danger)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ];
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Standard ERP Pagination Bar
            ErpPaginationBar(
              currentPage: safeCurrentPage,
              pageSize: safePageSize,
              totalRecords: totalRecords,
              onPageChanged: (page) => setState(() => _currentPage = page),
              onPageSizeChanged: (size) => setState(() {
                _pageSize = size;
                _currentPage = 0;
              }),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // VIEW 2: CREATE / EDIT BOM (MATCHING PROJECT ERP THEME)
  // ===========================================================================
  Widget _buildCreateEditView() {
    final db = ref.watch(databaseServiceProvider);
    final isEdit = _editingBom != null;

    final batchOutputQty = double.tryParse(_prodQtyCtrl.text.trim()) ?? 1.0;
    final totalMaterialCost = _draftItems.fold(0.0, (sum, i) => sum + i.lineCost);
    final costPerUnit = batchOutputQty > 0 ? (totalMaterialCost / batchOutputQty) : totalMaterialCost;

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit Bill of Materials (BOM)' : 'Create Bill of Materials (BOM)',
                        style: AppTextStyles.h1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Define raw materials and components required to manufacture this finished product',
                        style: AppTextStyles.subtitle,
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    ErpButton(
                      text: 'Back',
                      icon: Icons.arrow_back,
                      isOutlined: true,
                      onPressed: () => setState(() => _isCreateMode = false),
                    ),
                    const SizedBox(width: 10),
                    ErpButton(
                      text: isEdit ? 'Update BOM' : 'Save BOM',
                      icon: Icons.check,
                      onPressed: _saveBom,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Card 1: BOM Details
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadius.lgBorderRadius,
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('BOM Details', style: AppTextStyles.h3),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // BOM Number
                      Expanded(
                        child: TextFormField(
                          controller: _bomNumberCtrl,
                          decoration: const InputDecoration(labelText: 'BOM Number *'),
                          validator: (v) => Validators.requiredField(v, 'BOM number required'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // BOM Name
                      Expanded(
                        flex: isEdit ? 2 : 3,
                        child: TextFormField(
                          controller: _bomNameCtrl,
                          decoration: const InputDecoration(labelText: 'BOM Recipe Name *'),
                          validator: (v) => Validators.requiredField(v, 'BOM name required'),
                        ),
                      ),
                      // Status is ONLY displayed while Editing an existing BOM
                      if (isEdit) ...[
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _normalizeStatus(_selectedStatus),
                            decoration: const InputDecoration(labelText: 'Status'),
                            items: const [
                              DropdownMenuItem(value: 'Active', child: Text('Active')),
                              DropdownMenuItem(value: 'Draft', child: Text('Draft')),
                              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                            ],
                            onChanged: (v) => setState(() => _selectedStatus = _normalizeStatus(v)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Finished Product Picker
                      Expanded(
                        flex: 2,
                        child: _buildFinishedProductPicker(db),
                      ),
                      const SizedBox(width: 16),
                      // Product Code (Read-only)
                      Expanded(
                        child: TextFormField(
                          controller: _productCodeCtrl,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Product Code / SKU',
                            filled: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Production Quantity
                      Expanded(
                        child: TextFormField(
                          controller: _prodQtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Batch Qty *',
                            suffixText: _unitCtrl.text.isNotEmpty ? _unitCtrl.text : 'PCS',
                          ),
                          validator: (v) => Validators.positiveNumber(v, 'Valid quantity required'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Card 2: Raw Material Details
            Container(
              padding: const EdgeInsets.all(20),
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
                      final title = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: AppRadius.smBorderRadius,
                            ),
                            child: const Icon(Icons.grain, color: AppColors.primaryDark, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Text('Raw Material Details', style: AppTextStyles.h3),
                        ],
                      );
                      final button = ErpButton(
                        text: 'Add Raw Material',
                        icon: Icons.grain,
                        isOutlined: true,
                        onPressed: _showAddRawMaterialDialog,
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

                  if (_draftItems.isEmpty)
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
                            'Click "Add Raw Material" above to specify components for this manufacturing recipe.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                          ),
                          const SizedBox(height: 14),
                          ErpButton(
                            text: 'Add Raw Material',
                            icon: Icons.grain,
                            isOutlined: true,
                            onPressed: _showAddRawMaterialDialog,
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
                          children: List.generate(_draftItems.length, (index) {
                            final item = _draftItems[index];
                            final rm = db.rawMaterials.firstWhere(
                              (r) => r.id == item.rawMaterialId,
                              orElse: () => db.rawMaterials.first,
                            );
                            final totalBatchReq = item.quantityWithWastage * batchOutputQty;
                            final isStockShort = rm.currentStock < totalBatchReq;

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
                                  // Dropdown to select/switch Raw Material
                                  SizedBox(
                                    width: 290,
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
                                            item.unitCostCtrl.text = selected.defaultPurchasePrice % 1 == 0
                                                ? selected.defaultPurchasePrice.toInt().toString()
                                                : selected.defaultPurchasePrice.toString();
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Current Stock Status Pill (matching create_production_screen)
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
                                                    ? 'Avail: ${Formatters.formatNumber(rm.currentStock)} ${rm.unit} (Short: ${Formatters.formatNumber(totalBatchReq - rm.currentStock)})'
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

                                  // Required Qty Input
                                  SizedBox(
                                    width: 125,
                                    child: TextFormField(
                                      controller: item.qtyCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      validator: Validators.positiveNumber,
                                      decoration: InputDecoration(labelText: 'Req. Qty (${item.unit})'),
                                      onChanged: (v) {
                                        final num = double.tryParse(v.trim()) ?? 0.0;
                                        setState(() {
                                          item.quantityPerUnit = num;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Wastage % Input
                                  SizedBox(
                                    width: 100,
                                    child: TextFormField(
                                      controller: item.wastageCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      decoration: const InputDecoration(labelText: 'Wastage (%)', suffixText: '%'),
                                      onChanged: (v) {
                                        final num = double.tryParse(v.trim()) ?? 0.0;
                                        setState(() {
                                          item.wastagePercent = num;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),

                                  // Unit Cost Input
                                  SizedBox(
                                    width: 115,
                                    child: TextFormField(
                                      controller: item.unitCostCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      validator: Validators.positiveNumber,
                                      decoration: const InputDecoration(labelText: 'Unit Cost (₹)'),
                                      onChanged: (v) {
                                        final num = double.tryParse(v.trim()) ?? 0.0;
                                        setState(() {
                                          item.unitCost = num;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Per Product / Unit Calculation Card (matching create_production_screen)
                                  Container(
                                    width: 210,
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
                                                'Qty + Wastage:',
                                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              '${Formatters.formatNumber(item.quantityWithWastage)} ${item.unit}',
                                              style: AppTextStyles.bodyBold.copyWith(color: AppColors.successText, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Cost / Unit:',
                                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontSize: 11),
                                            ),
                                            Text(
                                              Formatters.formatCurrency(item.lineCost),
                                              style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Batch Total Cost
                                  SizedBox(
                                    width: 110,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Batch Total', style: AppTextStyles.bodySmall),
                                        Text(
                                          Formatters.formatCurrency(item.lineCost * batchOutputQty),
                                          style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Delete Action
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                    tooltip: 'Remove component',
                                    onPressed: () {
                                      setState(() {
                                        item.dispose();
                                        _draftItems.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    // Per Product BOM Recipe Summary Banner (matching create_production_screen)
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
                                  'Per Finished Product Recipe Calculation',
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
                              'Recipe Material Cost: ${Formatters.formatCurrency(costPerUnit)} / ${_unitCtrl.text.isNotEmpty ? _unitCtrl.text : "Unit"}  ·  Batch Total: ${Formatters.formatCurrency(totalMaterialCost)}',
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

            // Bottom Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ErpButton(
                  text: 'Cancel',
                  isOutlined: true,
                  onPressed: () => setState(() => _isCreateMode = false),
                ),
                const SizedBox(width: 12),
                ErpButton(
                  text: isEdit ? 'Update BOM' : 'Save BOM',
                  icon: Icons.check,
                  onPressed: _saveBom,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedProductPicker(dynamic db) {
    final list = db.finishedProducts as List;
    final hasSelected = list.any((p) => p.id == _selectedProductId);
    final effectiveValue = hasSelected ? _selectedProductId : (list.isNotEmpty ? list.first.id : null);

    return DropdownButtonFormField<String>(
      value: effectiveValue,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Finished Product *'),
      items: [
        ...list.map((p) {
          return DropdownMenuItem<String>(
            value: p.id,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.precision_manufacturing_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Flexible(child: Text('${p.name} (${p.itemCode})', overflow: TextOverflow.ellipsis)),
              ],
            ),
          );
        }),
        if (_selectedProductId != null && !hasSelected)
          DropdownMenuItem<String>(
            value: _selectedProductId,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.precision_manufacturing_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Flexible(child: Text(_editingBom?.safeProductName ?? _selectedProductId!, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ),
      ],
      validator: (v) => v == null ? 'Please select a finished product' : null,
      onChanged: _editingBom != null
          ? null // Locked on edit
          : (val) {
              if (val != null) {
                final chosen = list.firstWhere((p) => p.id == val);
                setState(() {
                  _selectedProductId = chosen.id;
                  _productCodeCtrl.text = chosen.itemCode;
                  _unitCtrl.text = chosen.unit;
                  _bomNameCtrl.text = '${chosen.name} Recipe';
                });
              }
            },
    );
  }

  Widget _buildStatusBadge(String status) {
    final normalized = _normalizeStatus(status);
    switch (normalized.toUpperCase()) {
      case 'ACTIVE':
        return ErpStatusBadge.success('ACTIVE');
      case 'DRAFT':
        return ErpStatusBadge.warning('DRAFT');
      case 'INACTIVE':
      default:
        return ErpStatusBadge.danger('INACTIVE');
    }
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textMuted)),
                const SizedBox(height: 3),
                Text(value, style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
