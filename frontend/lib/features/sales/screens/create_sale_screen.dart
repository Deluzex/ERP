import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../shared/providers/app_state_providers.dart';

class _SaleLineItemDraft {
  String finishedProductId;
  String finishedProductName;
  String finishedProductCode;
  String unit;
  double quantity;
  double rate;
  double discount;
  double gstPercent;

  _SaleLineItemDraft({
    required this.finishedProductId,
    required this.finishedProductName,
    required this.finishedProductCode,
    required this.unit,
    this.quantity = 1.0,
    this.rate = 1000.0,
    this.discount = 0.0,
    this.gstPercent = 18.0,
  });

  double get lineTotal => SaleLineItem.calculateLineTotal(
        quantity: quantity,
        rate: rate,
        discountAmount: discount,
        gstPercent: gstPercent,
      );
}

class CreateSaleScreen extends ConsumerStatefulWidget {
  const CreateSaleScreen({super.key});

  @override
  ConsumerState<CreateSaleScreen> createState() => _CreateSaleScreenState();
}

class _CreateSaleScreenState extends ConsumerState<CreateSaleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _paidAmountCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  PartyType _partyType = PartyType.customer;
  String? _selectedPartyId;
  String? _selectedProjectId;
  String? _selectedArchitectId;
  DateTime _saleDate = DateTime.now();
  PaymentMode _paymentMode = PaymentMode.bankTransfer;
  final List<_SaleLineItemDraft> _items = [];

  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseServiceProvider);
    if (db.customers.isNotEmpty) {
      _selectedPartyId = db.customers.first.id;
    }
    if (db.finishedProducts.isNotEmpty) {
      final fp = db.finishedProducts.first;
      _items.add(_SaleLineItemDraft(
        finishedProductId: fp.id,
        finishedProductName: fp.name,
        finishedProductCode: fp.itemCode,
        unit: fp.unit,
        quantity: 10.0,
        rate: _partyType == PartyType.customer ? fp.customerSellingPrice : fp.dealerSellingPrice,
        discount: 0.0,
        gstPercent: fp.gstPercent,
      ));
    }
  }

  void _addNewLineItem() {
    final db = ref.read(databaseServiceProvider);
    if (db.finishedProducts.isEmpty) return;
    final fp = db.finishedProducts.first;
    setState(() {
      _items.add(_SaleLineItemDraft(
        finishedProductId: fp.id,
        finishedProductName: fp.name,
        finishedProductCode: fp.itemCode,
        unit: fp.unit,
        quantity: 1.0,
        rate: _partyType == PartyType.customer ? fp.customerSellingPrice : fp.dealerSellingPrice,
        gstPercent: fp.gstPercent,
      ));
    });
  }

  void _removeLineItem(int index) {
    if (_items.length > 1) {
      setState(() => _items.removeAt(index));
    }
  }

  double get _subtotalAmount => _items.fold(0.0, (sum, i) => sum + (i.quantity * i.rate));
  double get _totalDiscount => _items.fold(0.0, (sum, i) => sum + i.discount);
  double get _totalGst => _items.fold(0.0, (sum, i) => sum + (((i.quantity * i.rate) - i.discount) * (i.gstPercent / 100.0)));
  double get _totalAmount => _items.fold(0.0, (sum, item) => sum + item.lineTotal);
  double get _paidAmount => double.tryParse(_paidAmountCtrl.text.trim()) ?? 0.0;
  double get _pendingAmount => (_totalAmount - _paidAmount).clamp(0.0, double.infinity);

  double get _calculatedCommission {
    if (_selectedArchitectId == null) return 0.0;
    final db = ref.read(databaseServiceProvider);
    final arch = db.architects.firstWhere((a) => a.id == _selectedArchitectId, orElse: () => db.architects.first);
    final baseAmount = _subtotalAmount - _totalDiscount;
    return (baseAmount * arch.defaultCommissionRate) / 100.0;
  }

  void _createInvoice(bool isDraft) {
    if (!_formKey.currentState!.validate()) return;
    final db = ref.read(databaseServiceProvider);

    // Validate finished product inventory
    if (!isDraft) {
      for (final item in _items) {
        final fp = db.finishedProducts.firstWhere((p) => p.id == item.finishedProductId, orElse: () => db.finishedProducts.first);
        if (fp.currentStock < item.quantity) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Insufficient stock for ${fp.name}! Available: ${fp.currentStock} ${fp.unit}, Invoiced: ${item.quantity} ${fp.unit}'),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
      }
    }

    String partyName = '';
    if (_partyType == PartyType.customer) {
      final c = db.customers.firstWhere((cust) => cust.id == _selectedPartyId, orElse: () => db.customers.first);
      partyName = c.name;
    } else {
      final d = db.dealers.firstWhere((dlr) => dlr.id == _selectedPartyId, orElse: () => db.dealers.first);
      partyName = d.name;
    }

    String? projName;
    if (_selectedProjectId != null) {
      final p = db.projects.firstWhere((prj) => prj.id == _selectedProjectId, orElse: () => db.projects.first);
      projName = p.name;
    }

    String? archName;
    if (_selectedArchitectId != null) {
      final a = db.architects.firstWhere((arc) => arc.id == _selectedArchitectId, orElse: () => db.architects.first);
      archName = a.name;
    }

    final saleItems = _items.map((i) {
      return SaleLineItem(
        finishedProductId: i.finishedProductId,
        finishedProductName: i.finishedProductName,
        finishedProductCode: i.finishedProductCode,
        quantity: i.quantity,
        unit: i.unit,
        rate: i.rate,
        discountAmount: i.discount,
        gstPercent: i.gstPercent,
        lineTotal: i.lineTotal,
      );
    }).toList();

    SaleStatus status;
    if (isDraft) {
      status = SaleStatus.draft;
    } else if (_paidAmount >= _totalAmount) {
      status = SaleStatus.paid;
    } else if (_paidAmount > 0) {
      status = SaleStatus.partialPaid;
    } else {
      status = SaleStatus.active;
    }

    final sale = Sale(
      id: IdGenerator.generateId('SALE'),
      invoiceNumber: IdGenerator.generateDocNumber('INV', db.nextSalesNumber),
      documentType: SalesDocumentType.invoice,
      partyType: _partyType,
      partyId: _selectedPartyId!,
      partyName: partyName,
      projectId: _selectedProjectId,
      projectName: projName,
      architectId: _selectedArchitectId,
      architectName: archName,
      saleDate: _saleDate,
      items: saleItems,
      subtotalAmount: _subtotalAmount,
      discountAmount: _totalDiscount,
      gstAmount: _totalGst,
      totalAmount: _totalAmount,
      paidAmount: _paidAmount,
      pendingAmount: _pendingAmount,
      paymentMode: _paymentMode,
      status: status,
      architectCommissionAmount: _calculatedCommission,
      notes: _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    db.createSale(sale);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isDraft ? 'Draft Sale Saved' : 'Invoice Created! Finished Product stock deducted & commission generated.'),
        backgroundColor: AppColors.success,
      ),
    );

    ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesInvoiceList;
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
                    Text('Create Sales Invoice', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text('Dispatch finished products, link project/architect, and record revenue', style: AppTextStyles.subtitle),
                  ],
                ),
                Row(
                  children: [
                    ErpButton(
                      text: 'Cancel',
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesInvoiceList,
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: 'Save Draft',
                      isOutlined: true,
                      onPressed: () => _createInvoice(true),
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: 'Create Invoice & Dispatch',
                      icon: Icons.receipt_long_outlined,
                      onPressed: () => _createInvoice(false),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Party & Billing Card
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
                  Text('Customer / Dealer & Project Association', style: AppTextStyles.h3),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: RadioListTile<PartyType>(
                                title: const Text('Direct Customer'),
                                value: PartyType.customer,
                                groupValue: _partyType,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _partyType = val;
                                      _selectedPartyId = db.customers.isNotEmpty ? db.customers.first.id : null;
                                    });
                                  }
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<PartyType>(
                                title: const Text('Dealer Channel'),
                                value: PartyType.dealer,
                                groupValue: _partyType,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _partyType = val;
                                      _selectedPartyId = db.dealers.isNotEmpty ? db.dealers.first.id : null;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedPartyId,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _partyType == PartyType.customer ? 'Select Customer *' : 'Select Dealer *',
                          ),
                          items: _partyType == PartyType.customer
                              ? db.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis))).toList()
                              : db.dealers.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (val) => setState(() => _selectedPartyId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _selectedProjectId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Linked Project (Optional)'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('No Project Link')),
                            ...db.projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (val) => setState(() => _selectedProjectId = val),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _selectedArchitectId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Linked Architect (Optional Commission)'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('No Architect Link')),
                            ...db.architects.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.defaultCommissionRate}%)', maxLines: 1, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (val) => setState(() => _selectedArchitectId = val),
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

            // Products Table Card
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
                      Text('Finished Products Invoiced', style: AppTextStyles.h3),
                      ErpButton(
                        text: 'Add Product',
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
                                // Product dropdown
                                SizedBox(
                                  width: 280,
                                  child: DropdownButtonFormField<String>(
                                    value: item.finishedProductId,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Product'),
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
                                        final fp = db.finishedProducts.firstWhere((p) => p.id == val);
                                        setState(() {
                                          item.finishedProductId = fp.id;
                                          item.finishedProductName = fp.name;
                                          item.finishedProductCode = fp.itemCode;
                                          item.unit = fp.unit;
                                          item.rate = _partyType == PartyType.customer ? fp.customerSellingPrice : fp.dealerSellingPrice;
                                          item.gstPercent = fp.gstPercent;
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
                                const SizedBox(width: 14),

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

                                // Delete
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

            // Financial Summary & Commission
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
                        Text('Sale Notes & Dispatch Instructions', style: AppTextStyles.h3),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(hintText: 'Enter dispatch address, site contact, or warranty notes...'),
                        ),
                        if (_selectedArchitectId != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.purpleLight,
                              borderRadius: AppRadius.smBorderRadius,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.stars_rounded, color: AppColors.purple, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Architect Commission Generated: ${Formatters.formatCurrency(_calculatedCommission)}',
                                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.purple),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                        Text('Invoice Total', style: AppTextStyles.h3),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Subtotal:', style: AppTextStyles.bodyMedium),
                            Text(Formatters.formatCurrency(_subtotalAmount), style: AppTextStyles.bodyBold),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Discount:', style: AppTextStyles.bodyMedium),
                            Text('- ${Formatters.formatCurrency(_totalDiscount)}', style: AppTextStyles.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('GST Tax (18%):', style: AppTextStyles.bodyMedium),
                            Text(Formatters.formatCurrency(_totalGst), style: AppTextStyles.bodySmall),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Grand Total:', style: AppTextStyles.bodyBold),
                            Text(Formatters.formatCurrency(_totalAmount), style: AppTextStyles.h2),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _paidAmountCtrl,
                          keyboardType: TextInputType.number,
                          validator: Validators.nonNegativeNumber,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(labelText: 'Received Paid Amount (₹)'),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Customer Outstanding:', style: AppTextStyles.bodyMedium),
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
