import 'package:file_picker/file_picker.dart';
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
  PurchaseItemType itemType;
  String itemId; // rawMaterialId or finishedProductId
  String itemName;
  String itemCode;
  String unit;
  double quantity;
  double rate;
  double discount;
  double gstPercent;

  _LineItemDraft({
    this.itemType = PurchaseItemType.rawMaterial,
    required this.itemId,
    required this.itemName,
    required this.itemCode,
    required this.unit,
    this.quantity = 1.0,
    this.rate = 100.0,
    this.discount = 0.0,
    this.gstPercent = 18.0,
  });

  double get subtotal => (quantity * rate) - discount;

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
  String? _selectedProjectId;
  DateTime _purchaseDate = DateTime.now();
  DateTime _invoiceDate = DateTime.now();
  PaymentMode _paymentMode = PaymentMode.bankTransfer;
  bool _isInterStateTax = false; // False = Intra-State (CGST + SGST), True = Inter-State (IGST)
  final List<_LineItemDraft> _items = [];
  String? _attachmentName;
  String? _attachmentSize;
  bool _isSubmitting = false;

  Future<void> _pickAttachmentFile() async {
    try {
      final result = await FilePickerPlatform.instance.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
      );
      if (result.isNotEmpty) {
        final file = result.first;
        setState(() {
          _attachmentName = file.name;
          _attachmentSize = 'Uploaded File';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open storage: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

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
        itemType: PurchaseItemType.rawMaterial,
        itemId: firstRm.id,
        itemName: firstRm.name,
        itemCode: firstRm.itemCode,
        unit: firstRm.unit,
        quantity: 100.0,
        rate: firstRm.defaultPurchasePrice,
        discount: 0.0,
        gstPercent: firstRm.gstPercent,
      ));
    }
  }

  void _addNewLineItem({PurchaseItemType itemType = PurchaseItemType.rawMaterial}) {
    final db = ref.read(databaseServiceProvider);
    if (itemType == PurchaseItemType.rawMaterial) {
      if (db.rawMaterials.isEmpty) return;
      final firstRm = db.rawMaterials.first;
      setState(() {
        _items.add(_LineItemDraft(
          itemType: PurchaseItemType.rawMaterial,
          itemId: firstRm.id,
          itemName: firstRm.name,
          itemCode: firstRm.itemCode,
          unit: firstRm.unit,
          quantity: 10.0,
          rate: firstRm.defaultPurchasePrice,
          gstPercent: firstRm.gstPercent,
        ));
      });
    } else {
      if (db.finishedProducts.isEmpty) return;
      final firstFp = db.finishedProducts.first;
      setState(() {
        _items.add(_LineItemDraft(
          itemType: PurchaseItemType.finishedProduct,
          itemId: firstFp.id,
          itemName: firstFp.name,
          itemCode: firstFp.itemCode,
          unit: firstFp.unit,
          quantity: 10.0,
          rate: firstFp.costPrice,
          gstPercent: firstFp.gstPercent,
        ));
      });
    }
  }

  void _removeLineItem(int index) {
    if (_items.length > 1) {
      setState(() => _items.removeAt(index));
    }
  }

  double get _subtotalAmount => _items.fold(0.0, (sum, i) => sum + i.subtotal);
  double get _cgstAmount => _isInterStateTax ? 0.0 : _items.fold(0.0, (sum, i) => sum + ((i.subtotal * (i.gstPercent / 2.0)) / 100.0));
  double get _sgstAmount => _isInterStateTax ? 0.0 : _items.fold(0.0, (sum, i) => sum + ((i.subtotal * (i.gstPercent / 2.0)) / 100.0));
  double get _igstAmount => _isInterStateTax ? _items.fold(0.0, (sum, i) => sum + ((i.subtotal * i.gstPercent) / 100.0)) : 0.0;
  double get _gstTotal => _cgstAmount + _sgstAmount + _igstAmount;
  double get _totalAmount => _subtotalAmount + _gstTotal;
  double get _paidAmount => double.tryParse(_paidAmountCtrl.text.trim()) ?? 0.0;
  double get _pendingAmount => (_totalAmount - _paidAmount).clamp(0.0, double.infinity);

  Future<void> _savePurchase(bool isDraft) async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item to purchase order')),
      );
      return;
    }

    final db = ref.read(databaseServiceProvider);
    final vendor = db.vendors.firstWhere((v) => v.id == _selectedVendorId, orElse: () => db.vendors.first);

    final project = _selectedProjectId != null
        ? db.projects.where((p) => p.id == _selectedProjectId).firstOrNull
        : null;

    final purchaseItems = _items.map((draft) {
      final sub = draft.subtotal;
      final taxAmt = draft.lineTotal - sub;
      final cgst = _isInterStateTax ? 0.0 : (taxAmt / 2.0);
      final sgst = _isInterStateTax ? 0.0 : (taxAmt / 2.0);
      final igst = _isInterStateTax ? taxAmt : 0.0;

      return PurchaseLineItem(
        itemType: draft.itemType,
        rawMaterialId: draft.itemType == PurchaseItemType.rawMaterial ? draft.itemId : null,
        rawMaterialName: draft.itemType == PurchaseItemType.rawMaterial ? draft.itemName : null,
        rawMaterialCode: draft.itemType == PurchaseItemType.rawMaterial ? draft.itemCode : null,
        finishedProductId: draft.itemType == PurchaseItemType.finishedProduct ? draft.itemId : null,
        finishedProductName: draft.itemType == PurchaseItemType.finishedProduct ? draft.itemName : null,
        finishedProductCode: draft.itemType == PurchaseItemType.finishedProduct ? draft.itemCode : null,
        quantity: draft.quantity,
        unit: draft.unit,
        rate: draft.rate,
        discountAmount: draft.discount,
        gstPercent: draft.gstPercent,
        cgstAmount: cgst,
        sgstAmount: sgst,
        igstAmount: igst,
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
      vendorInvoiceNumber: _vendorInvoiceCtrl.text.trim().isNotEmpty
          ? _vendorInvoiceCtrl.text.trim()
          : 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      invoiceDate: _invoiceDate,
      items: purchaseItems,
      totalAmount: _totalAmount,
      paidAmount: _paidAmount,
      pendingAmount: _pendingAmount,
      paymentMode: _paymentMode,
      status: status,
      notes: _notesCtrl.text.trim(),
      projectId: project?.id,
      projectName: project?.name,
      cgstAmount: _cgstAmount,
      sgstAmount: _sgstAmount,
      igstAmount: _igstAmount,
      createdAt: DateTime.now(),
    );

    setState(() => _isSubmitting = true);
    try {
      await db.createPurchaseAsync(purchase);

      if (mounted) {
        final containsFinished = purchaseItems.any((it) => it.itemType == PurchaseItemType.finishedProduct);
        final containsRaw = purchaseItems.any((it) => it.itemType == PurchaseItemType.rawMaterial);
        String stockMsg = 'Stock updated!';
        if (containsFinished && containsRaw) {
          stockMsg = 'Raw Material & Finished Goods stock successfully updated!';
        } else if (containsFinished) {
          stockMsg = 'Finished Goods stock inwarded directly to Finished Inventory!';
        } else {
          stockMsg = 'Raw Material stock inwarded to Raw Materials inventory!';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isDraft ? 'Draft Purchase Order Saved' : 'Purchase Saved! $stockMsg'),
            backgroundColor: AppColors.success,
          ),
        );

        ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.purchaseList;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving purchase: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
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
                    Text('Create Purchase Order', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text('Inward Raw Materials or Finished Goods directly into stock with GST tax breakup',
                        style: AppTextStyles.subtitle),
                  ],
                ),
                Row(
                  children: [
                    ErpButton(
                      text: 'Cancel',
                      isOutlined: true,
                      onPressed: _isSubmitting
                          ? null
                          : () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.purchaseList,
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: 'Save Draft',
                      isOutlined: true,
                      onPressed: _isSubmitting ? null : () => _savePurchase(true),
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: _isSubmitting ? 'Saving & Inwarding...' : 'Save & Inward Stock',
                      icon: _isSubmitting ? null : Icons.check,
                      onPressed: _isSubmitting ? null : () => _savePurchase(false),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Vendor & Invoice Details', style: AppTextStyles.h3),
                      // GST Tax Region Selector
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isInterStateTax ? Colors.purple.withOpacity(0.08) : Colors.blue.withOpacity(0.08),
                          borderRadius: AppRadius.smBorderRadius,
                          border: Border.all(
                            color: _isInterStateTax ? Colors.purple.withOpacity(0.3) : Colors.blue.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isInterStateTax ? Icons.map_outlined : Icons.location_on_outlined,
                              size: 16,
                              color: _isInterStateTax ? Colors.purple : Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tax Mode:',
                              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Intra-State (CGST + SGST)'),
                              selected: !_isInterStateTax,
                              selectedColor: AppColors.primary.withOpacity(0.15),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: !_isInterStateTax ? FontWeight.bold : FontWeight.normal,
                                color: !_isInterStateTax ? AppColors.primary : AppColors.textMuted,
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _isInterStateTax = false);
                              },
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Inter-State (IGST)'),
                              selected: _isInterStateTax,
                              selectedColor: Colors.purple.withOpacity(0.15),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: _isInterStateTax ? FontWeight.bold : FontWeight.normal,
                                color: _isInterStateTax ? Colors.purple : AppColors.textMuted,
                              ),
                              onSelected: (val) {
                                if (val) setState(() => _isInterStateTax = true);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _selectedVendorId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Select Vendor *'),
                          items: db.vendors.where((v) => !v.isDeleted).map((v) {
                            return DropdownMenuItem(
                              value: v.id,
                              child: Text(
                                '${v.name} (${v.mobile})',
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
                        flex: 2,
                        child: TextFormField(
                          controller: _vendorInvoiceCtrl,
                          validator: (v) => Validators.requiredField(v, 'Vendor invoice number required'),
                          decoration: const InputDecoration(
                            labelText: 'Vendor Invoice Number *',
                            hintText: 'E.g. APEX/2026/901',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String?>(
                          value: _selectedProjectId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Link to Project (Optional)',
                            hintText: 'General / No Project',
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('General Inventory (No Project)')),
                            ...db.projects.map((p) => DropdownMenuItem(
                                  value: p.id,
                                  child: Text(p.name),
                                )),
                          ],
                          onChanged: (val) => setState(() => _selectedProjectId = val),
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
                          decoration: const InputDecoration(
                              labelText: 'Purchase Date', suffixIcon: Icon(Icons.calendar_today, size: 16)),
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
                          decoration: const InputDecoration(
                              labelText: 'Vendor Invoice Date', suffixIcon: Icon(Icons.calendar_today, size: 16)),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Items Ordered (Raw Materials & Finished Goods)', style: AppTextStyles.h3),
                          const SizedBox(height: 4),
                          Text('Direct Finished Product purchases are added to Finished Goods stock directly',
                              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                      Row(
                        children: [
                          ErpButton(
                            text: 'Add Raw Material',
                            icon: Icons.grain,
                            isOutlined: true,
                            onPressed: () => _addNewLineItem(itemType: PurchaseItemType.rawMaterial),
                          ),
                          const SizedBox(width: 10),
                          ErpButton(
                            text: 'Add Finished Good',
                            icon: Icons.inventory_2,
                            isOutlined: true,
                            onPressed: () => _addNewLineItem(itemType: PurchaseItemType.finishedProduct),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width < 1200 ? 1050 : MediaQuery.of(context).size.width - 320,
                      ),
                      child: Column(
                        children: List.generate(_items.length, (index) {
                          final item = _items[index];
                          final isFp = item.itemType == PurchaseItemType.finishedProduct;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isFp ? Colors.teal.withOpacity(0.04) : AppColors.surfaceMuted,
                              borderRadius: AppRadius.smBorderRadius,
                              border: Border.all(
                                color: isFp ? Colors.teal.withOpacity(0.2) : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Type badge / toggle
                                SizedBox(
                                  width: 130,
                                  child: DropdownButtonFormField<PurchaseItemType>(
                                    value: item.itemType,
                                    isExpanded: true,
                                    decoration: InputDecoration(
                                      labelText: 'Item Type',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      fillColor: isFp ? Colors.teal.withOpacity(0.1) : null,
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: PurchaseItemType.rawMaterial,
                                        child: Text('Raw Mat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                      DropdownMenuItem(
                                        value: PurchaseItemType.finishedProduct,
                                        child: Text('Fin Good', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal)),
                                      ),
                                    ],
                                    onChanged: (newType) {
                                      if (newType == null || newType == item.itemType) return;
                                      if (newType == PurchaseItemType.rawMaterial && db.rawMaterials.isNotEmpty) {
                                        final rm = db.rawMaterials.first;
                                        setState(() {
                                          item.itemType = PurchaseItemType.rawMaterial;
                                          item.itemId = rm.id;
                                          item.itemName = rm.name;
                                          item.itemCode = rm.itemCode;
                                          item.unit = rm.unit;
                                          item.rate = rm.defaultPurchasePrice;
                                          item.gstPercent = rm.gstPercent;
                                        });
                                      } else if (newType == PurchaseItemType.finishedProduct && db.finishedProducts.isNotEmpty) {
                                        final fp = db.finishedProducts.first;
                                        setState(() {
                                          item.itemType = PurchaseItemType.finishedProduct;
                                          item.itemId = fp.id;
                                          item.itemName = fp.name;
                                          item.itemCode = fp.itemCode;
                                          item.unit = fp.unit;
                                          item.rate = fp.costPrice;
                                          item.gstPercent = fp.gstPercent;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Material/Product Dropdown
                                SizedBox(
                                  width: 250,
                                  child: isFp
                                      ? DropdownButtonFormField<String>(
                                          value: item.itemId,
                                          isExpanded: true,
                                          decoration: const InputDecoration(labelText: 'Finished Product *'),
                                          items: db.finishedProducts.map((fp) {
                                            return DropdownMenuItem(
                                              value: fp.id,
                                              child: Text(
                                                '${fp.itemCode} - ${fp.name}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              final fp = db.finishedProducts.firstWhere((f) => f.id == val);
                                              setState(() {
                                                item.itemId = fp.id;
                                                item.itemName = fp.name;
                                                item.itemCode = fp.itemCode;
                                                item.unit = fp.unit;
                                                item.rate = fp.costPrice;
                                                item.gstPercent = fp.gstPercent;
                                              });
                                            }
                                          },
                                        )
                                      : DropdownButtonFormField<String>(
                                          value: item.itemId,
                                          isExpanded: true,
                                          decoration: const InputDecoration(labelText: 'Raw Material *'),
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
                                                item.itemId = rm.id;
                                                item.itemName = rm.name;
                                                item.itemCode = rm.itemCode;
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
                                  width: 100,
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
                                  width: 100,
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
                                  width: 90,
                                  child: TextFormField(
                                    initialValue: item.discount.toString(),
                                    keyboardType: TextInputType.number,
                                    validator: Validators.nonNegativeNumber,
                                    decoration: const InputDecoration(labelText: 'Disc (₹)'),
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
                  flex: 1,
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
                        Text('Invoice / Proof Attachment', style: AppTextStyles.h3),
                        const SizedBox(height: 6),
                        Text('Attach bill or vendor document from device storage',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 16),
                        _attachmentName != null
                            ? Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: AppRadius.smBorderRadius,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.description, color: AppColors.primary, size: 28),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_attachmentName!,
                                              style: AppTextStyles.bodyBold, overflow: TextOverflow.ellipsis),
                                          Text('Size: ${_attachmentSize ?? 'Uploaded File'}',
                                              style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: AppColors.danger, size: 20),
                                      onPressed: () => setState(() {
                                        _attachmentName = null;
                                        _attachmentSize = null;
                                      }),
                                    ),
                                  ],
                                ),
                              )
                            : Material(
                                color: AppColors.surfaceMuted,
                                borderRadius: AppRadius.mdBorderRadius,
                                child: InkWell(
                                  onTap: _pickAttachmentFile,
                                  borderRadius: AppRadius.mdBorderRadius,
                                  child: Container(
                                    height: 90,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                                      borderRadius: AppRadius.mdBorderRadius,
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.cloud_upload_outlined, color: AppColors.primary),
                                          const SizedBox(width: 10),
                                          Text('Click to Upload from Storage',
                                              style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'Purchase Notes / Remarks',
                            hintText: 'Enter any vendor comments or inward instructions',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),
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
                        Text('Financial & Tax Summary', style: AppTextStyles.h3),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Taxable Subtotal:', style: AppTextStyles.bodyMedium),
                            Text(Formatters.formatCurrency(_subtotalAmount), style: AppTextStyles.bodyBold),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!_isInterStateTax) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('CGST Amount:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                              Text(Formatters.formatCurrency(_cgstAmount),
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('SGST Amount:', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                              Text(Formatters.formatCurrency(_sgstAmount),
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                            ],
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('IGST (Inter-State Tax):',
                                  style: AppTextStyles.bodySmall.copyWith(color: Colors.purple)),
                              Text(Formatters.formatCurrency(_igstAmount),
                                  style: AppTextStyles.bodySmall.copyWith(color: Colors.purple, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Grand Total:', style: AppTextStyles.h3),
                            Text(Formatters.formatCurrency(_totalAmount),
                                style: AppTextStyles.h2.copyWith(color: AppColors.primary)),
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
