import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../shared/providers/app_state_providers.dart';

class CreatePurchaseScreen extends ConsumerStatefulWidget {
  const CreatePurchaseScreen({super.key});

  @override
  ConsumerState<CreatePurchaseScreen> createState() => _CreatePurchaseScreenState();
}

class _LineItemDraft {
  String rawMaterialId;
  String rawMaterialName;
  String rawMaterialCode;
  String unit;
  double quantity;
  double rate;
  double discount;
  double gstPercent;

  _LineItemDraft({
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.rawMaterialCode,
    required this.unit,
    this.quantity = 1.0,
    this.rate = 100.0,
    this.discount = 0.0,
    this.gstPercent = 18.0,
  });

  double get lineTotal => PurchaseLineItem.calculateLineTotal(
        quantity: quantity,
        rate: rate,
        discountAmount: discount,
        gstPercent: gstPercent,
      );
}

class _CreatePurchaseScreenState extends ConsumerState<CreatePurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _vendorInvoiceCtrl = TextEditingController();
  final _paidAmountCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  String? _selectedVendorId;
  DateTime _purchaseDate = DateTime.now();
  DateTime _invoiceDate = DateTime.now();
  PaymentMode _paymentMode = PaymentMode.bankTransfer;
  final List<_LineItemDraft> _items = [];

  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseServiceProvider);
    if (db.vendors.isNotEmpty) {
      _selectedVendorId = db.vendors.first.id;
    }
    if (db.rawMaterials.isNotEmpty) {
      final firstRm = db.rawMaterials.first;
      _items.add(_LineItemDraft(
        rawMaterialId: firstRm.id,
        rawMaterialName: firstRm.name,
        rawMaterialCode: firstRm.itemCode,
        unit: firstRm.unit,
        quantity: 100.0,
        rate: firstRm.defaultPurchasePrice,
        discount: 0.0,
        gstPercent: firstRm.gstPercent,
      ));
    }
  }

  void _addNewLineItem() {
    final db = ref.read(databaseServiceProvider);
    if (db.rawMaterials.isEmpty) return;
    final firstRm = db.rawMaterials.first;
    setState(() {
      _items.add(_LineItemDraft(
        rawMaterialId: firstRm.id,
        rawMaterialName: firstRm.name,
        rawMaterialCode: firstRm.itemCode,
        unit: firstRm.unit,
        quantity: 10.0,
        rate: firstRm.defaultPurchasePrice,
      ));
    });
  }

  void _removeLineItem(int index) {
    if (_items.length > 1) {
      setState(() => _items.removeAt(index));
    }
  }

  double get _totalAmount => _items.fold(0.0, (sum, item) => sum + item.lineTotal);
  double get _paidAmount => double.tryParse(_paidAmountCtrl.text.trim()) ?? 0.0;
  double get _pendingAmount => (_totalAmount - _paidAmount).clamp(0.0, double.infinity);

  void _savePurchase(bool isDraft) {
    if (!_formKey.currentState!.validate()) return;
    final db = ref.read(databaseServiceProvider);
    final vendor = db.vendors.firstWhere((v) => v.id == _selectedVendorId, orElse: () => db.vendors.first);

    final purchaseItems = _items.map((draft) {
      return PurchaseLineItem(
        rawMaterialId: draft.rawMaterialId,
        rawMaterialName: draft.rawMaterialName,
        rawMaterialCode: draft.rawMaterialCode,
        quantity: draft.quantity,
        unit: draft.unit,
        rate: draft.rate,
        discountAmount: draft.discount,
        gstPercent: draft.gstPercent,
        lineTotal: draft.lineTotal,
      );
    }).toList();

    PurchaseStatus status;
    if (isDraft) {
      status = PurchaseStatus.draft;
    } else if (_paidAmount >= _totalAmount) {
      status = PurchaseStatus.paid;
    } else if (_paidAmount > 0) {
      status = PurchaseStatus.partialPaid;
    } else {
      status = PurchaseStatus.saved;
    }

    final purchase = Purchase(
      id: IdGenerator.generateId('PUR'),
      purchaseNumber: IdGenerator.generateDocNumber('PO', db.nextPurchaseNumber),
      purchaseDate: _purchaseDate,
      vendorId: vendor.id,
      vendorName: vendor.name,
      vendorInvoiceNumber: _vendorInvoiceCtrl.text.trim().isNotEmpty ? _vendorInvoiceCtrl.text.trim() : 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      invoiceDate: _invoiceDate,
      items: purchaseItems,
      totalAmount: _totalAmount,
      paidAmount: _paidAmount,
      pendingAmount: _pendingAmount,
      paymentMode: _paymentMode,
      status: status,
      notes: _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    db.createPurchase(purchase);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isDraft ? 'Draft Purchase Order Saved' : 'Purchase Saved & Raw Material Stock Updated Successfully!'),
        backgroundColor: AppColors.success,
      ),
    );

    ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.purchaseList;
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
                    Text('Create Purchase Order', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text('Inward raw materials, record vendor invoice, and update stock ledger', style: AppTextStyles.subtitle),
                  ],
                ),
                Row(
                  children: [
                    ErpButton(
                      text: 'Cancel',
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.purchaseList,
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: 'Save Draft',
                      isOutlined: true,
                      onPressed: () => _savePurchase(true),
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: 'Save & Inward Stock',
                      icon: Icons.check,
                      onPressed: () => _savePurchase(false),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Vendor & Header Card
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
                  Text('Vendor & Invoice Details', style: AppTextStyles.h3),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedVendorId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Select Vendor *'),
                          items: db.vendors.where((v) => !v.isDeleted).map((v) {
                            return DropdownMenuItem(
                              value: v.id,
                              child: Text(
                                v.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedVendorId = val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _vendorInvoiceCtrl,
                          validator: (v) => Validators.requiredField(v, 'Vendor invoice number required'),
                          decoration: const InputDecoration(
                            labelText: 'Vendor Invoice Number *',
                            hintText: 'E.g. APEX/2026/901',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          controller: TextEditingController(text: Formatters.formatDate(_purchaseDate)),
                          decoration: const InputDecoration(labelText: 'Purchase Date', suffixIcon: Icon(Icons.calendar_today, size: 16)),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _purchaseDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) setState(() => _purchaseDate = date);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          controller: TextEditingController(text: Formatters.formatDate(_invoiceDate)),
                          decoration: const InputDecoration(labelText: 'Vendor Invoice Date', suffixIcon: Icon(Icons.calendar_today, size: 16)),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _invoiceDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) setState(() => _invoiceDate = date);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<PaymentMode>(
                          value: _paymentMode,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Payment Mode'),
                          items: PaymentMode.values.map((mode) {
                            return DropdownMenuItem(
                              value: mode,
                              child: Text(mode.toString().split('.').last.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _paymentMode = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Line Items Table Card
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
                      Text('Raw Materials Ordered', style: AppTextStyles.h3),
                      ErpButton(
                        text: 'Add Raw Material',
                        icon: Icons.add,
                        isOutlined: true,
                        onPressed: _addNewLineItem,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width < 1100 ? 980 : MediaQuery.of(context).size.width - 320,
                      ),
                      child: Column(
                        children: List.generate(_items.length, (index) {
                          final item = _items[index];
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
                                // Material Dropdown
                                SizedBox(
                                  width: 280,
                                  child: DropdownButtonFormField<String>(
                                    value: item.rawMaterialId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Raw Material'),
                                    items: db.rawMaterials.map((rm) {
                                      return DropdownMenuItem(
                                        value: rm.id,
                                        child: Text(
                                          '${rm.itemCode} - ${rm.name}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        final rm = db.rawMaterials.firstWhere((r) => r.id == val);
                                        setState(() {
                                          item.rawMaterialId = rm.id;
                                          item.rawMaterialName = rm.name;
                                          item.rawMaterialCode = rm.itemCode;
                                          item.unit = rm.unit;
                                          item.rate = rm.defaultPurchasePrice;
                                          item.gstPercent = rm.gstPercent;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Quantity
                                SizedBox(
                                  width: 110,
                                  child: TextFormField(
                                    initialValue: item.quantity.toString(),
                                    keyboardType: TextInputType.number,
                                    validator: Validators.positiveNumber,
                                    decoration: InputDecoration(labelText: 'Qty (${item.unit})'),
                                    onChanged: (v) {
                                      final num = double.tryParse(v) ?? 0.0;
                                      setState(() => item.quantity = num);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Rate
                                SizedBox(
                                  width: 110,
                                  child: TextFormField(
                                    initialValue: item.rate.toString(),
                                    keyboardType: TextInputType.number,
                                    validator: Validators.positiveNumber,
                                    decoration: const InputDecoration(labelText: 'Rate (₹)'),
                                    onChanged: (v) {
                                      final num = double.tryParse(v) ?? 0.0;
                                      setState(() => item.rate = num);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Discount
                                SizedBox(
                                  width: 110,
                                  child: TextFormField(
                                    initialValue: item.discount.toString(),
                                    keyboardType: TextInputType.number,
                                    validator: Validators.nonNegativeNumber,
                                    decoration: const InputDecoration(labelText: 'Discount (₹)'),
                                    onChanged: (v) {
                                      final num = double.tryParse(v) ?? 0.0;
                                      setState(() => item.discount = num);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // GST %
                                SizedBox(
                                  width: 80,
                                  child: TextFormField(
                                    initialValue: item.gstPercent.toString(),
                                    keyboardType: TextInputType.number,
                                    validator: Validators.nonNegativeNumber,
                                    decoration: const InputDecoration(labelText: 'GST %'),
                                    onChanged: (v) {
                                      final num = double.tryParse(v) ?? 0.0;
                                      setState(() => item.gstPercent = num);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Line Total
                                SizedBox(
                                  width: 120,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('Line Total', style: AppTextStyles.bodySmall),
                                      Text(
                                        Formatters.formatCurrency(item.lineTotal),
                                        style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Delete button
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                  onPressed: () => _removeLineItem(index),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Summary & Payment Card
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
                        Text('Purchase Notes & Terms', style: AppTextStyles.h3),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(hintText: 'Enter purchase terms, delivery notes or inspection instructions...'),
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
                        Text('Financial Summary', style: AppTextStyles.h3),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total Amount:', style: AppTextStyles.bodyMedium),
                            Text(Formatters.formatCurrency(_totalAmount), style: AppTextStyles.h2),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _paidAmountCtrl,
                          keyboardType: TextInputType.number,
                          validator: Validators.nonNegativeNumber,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Paid Amount (₹)'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pending Amount:', style: AppTextStyles.bodyMedium),
                            Text(
                              Formatters.formatCurrency(_pendingAmount),
                              style: AppTextStyles.bodyBold.copyWith(
                                color: _pendingAmount > 0 ? AppColors.dangerText : AppColors.successText,
                              ),
                            ),
                          ],
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
