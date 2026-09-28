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
import '../../../core/widgets/erp_button.dart';
import '../../../shared/providers/app_state_providers.dart';

class _SoItemDraft {
  String finishedProductId;
  String finishedProductName;
  String finishedProductCode;
  String unit;
  double quantity;
  double rate;
  double discount;
  double gstPercent;
  double availableStock;

  _SoItemDraft({
    required this.finishedProductId,
    required this.finishedProductName,
    required this.finishedProductCode,
    required this.unit,
    this.quantity = 10.0,
    this.rate = 1000.0,
    this.discount = 0.0,
    this.gstPercent = 18.0,
    this.availableStock = 0.0,
  });

  double get taxableAmount => ((quantity * rate) - discount).clamp(0.0, double.infinity);
  double get gstAmount => taxableAmount * (gstPercent / 100.0);
  double get lineTotal => taxableAmount + gstAmount;
}

class CreateSalesOrderScreen extends ConsumerStatefulWidget {
  const CreateSalesOrderScreen({super.key});

  @override
  ConsumerState<CreateSalesOrderScreen> createState() => _CreateSalesOrderScreenState();
}

class _CreateSalesOrderScreenState extends ConsumerState<CreateSalesOrderScreen> {
  final _formKey = GlobalKey<FormState>();

  PartyType _partyType = PartyType.customer;
  String? _selectedPartyId;
  String? _selectedProjectId;
  String? _selectedArchitectId;
  DateTime _orderDate = DateTime.now();
  DateTime _deliveryDate = DateTime.now().add(const Duration(days: 14));
  PaymentMode _paymentMode = PaymentMode.bankTransfer;

  final _notesCtrl = TextEditingController();
  final List<_SoItemDraft> _items = [];

  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseServiceProvider);
    if (db.customers.isNotEmpty) {
      _selectedPartyId = db.customers.first.id;
    }
    if (db.finishedProducts.isNotEmpty) {
      final fp = db.finishedProducts.first;
      _items.add(_SoItemDraft(
        finishedProductId: fp.id,
        finishedProductName: fp.name,
        finishedProductCode: fp.itemCode,
        unit: fp.unit,
        quantity: 10.0,
        rate: fp.customerSellingPrice,
        discount: 0.0,
        gstPercent: fp.gstPercent,
        availableStock: fp.availableStock,
      ));
    }
  }

  void _addNewRow() {
    final db = ref.read(databaseServiceProvider);
    if (db.finishedProducts.isEmpty) return;
    final fp = db.finishedProducts.first;
    setState(() {
      _items.add(_SoItemDraft(
        finishedProductId: fp.id,
        finishedProductName: fp.name,
        finishedProductCode: fp.itemCode,
        unit: fp.unit,
        quantity: 5.0,
        rate: _partyType == PartyType.customer ? fp.customerSellingPrice : fp.dealerSellingPrice,
        discount: 0.0,
        gstPercent: fp.gstPercent,
        availableStock: fp.availableStock,
      ));
    });
  }

  void _removeRow(int idx) {
    if (_items.length > 1) {
      setState(() => _items.removeAt(idx));
    }
  }

  double get _subtotalAmount => _items.fold(0.0, (sum, i) => sum + (i.quantity * i.rate));
  double get _totalDiscount => _items.fold(0.0, (sum, i) => sum + i.discount);
  double get _totalTaxable => (_subtotalAmount - _totalDiscount).clamp(0.0, double.infinity);
  double get _totalGst => _items.fold(0.0, (sum, i) => sum + i.gstAmount);
  double get _grandTotal => _totalTaxable + _totalGst;

  Future<void> _createSalesOrder() async {
    if (!_formKey.currentState!.validate()) return;
    final db = ref.read(databaseServiceProvider);

    String partyName = '';
    if (_partyType == PartyType.customer) {
      final c = db.customers.where((cust) => cust.id == _selectedPartyId).firstOrNull;
      partyName = c?.name ?? 'Customer';
    } else if (_partyType == PartyType.dealer) {
      final d = db.dealers.where((dlr) => dlr.id == _selectedPartyId).firstOrNull;
      partyName = d?.name ?? 'Dealer';
    } else {
      final a = db.architects.where((arc) => arc.id == _selectedPartyId).firstOrNull;
      partyName = a != null ? '${a.name} (${a.companyName})' : 'Architect';
    }

    String? projName;
    if (_selectedProjectId != null) {
      final p = db.projects.where((prj) => prj.id == _selectedProjectId).firstOrNull;
      projName = p?.name;
    }

    String? archName;
    if (_selectedArchitectId != null) {
      final a = db.architects.where((arc) => arc.id == _selectedArchitectId).firstOrNull;
      archName = a?.name;
    }

    final soNumber = 'DLZ/SO/2026/${db.nextSalesOrderNumber.toString().padLeft(4, '0')}';

    final lineItems = _items.map((i) {
      return SaleLineItem(
        finishedProductId: i.finishedProductId,
        finishedProductName: i.finishedProductName,
        finishedProductCode: i.finishedProductCode,
        quantity: i.quantity,
        unit: i.unit,
        rate: i.rate,
        discountAmount: i.discount,
        gstPercent: i.gstPercent,
        taxableAmount: i.taxableAmount,
        cgstAmount: i.gstAmount / 2,
        sgstAmount: i.gstAmount / 2,
        igstAmount: 0.0,
        lineTotal: i.lineTotal,
      );
    }).toList();

    final so = Sale(
      id: IdGenerator.generateId('SO'),
      invoiceNumber: soNumber,
      documentType: SalesDocumentType.salesOrder,
      partyType: _partyType,
      partyId: _selectedPartyId!,
      partyName: partyName,
      projectId: _selectedProjectId,
      projectName: projName,
      architectId: _selectedArchitectId,
      architectName: archName,
      salesExecutive: db.currentUser.name,
      salesOrderNumber: soNumber,
      saleDate: _orderDate,
      deliveryDate: _deliveryDate,
      items: lineItems,
      subtotalAmount: _subtotalAmount,
      discountAmount: _totalDiscount,
      taxableAmount: _totalTaxable,
      cgstAmount: _totalGst / 2,
      sgstAmount: _totalGst / 2,
      igstAmount: 0.0,
      gstAmount: _totalGst,
      totalAmount: _grandTotal,
      paidAmount: 0.0,
      pendingAmount: _grandTotal,
      paymentMode: _paymentMode,
      status: SaleStatus.active,
      notes: _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      final createdSO = await db.createSalesOrderAsync(so, autoAllocate: true);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sales Order ${createdSO.invoiceNumber} created! Automated inventory check & reservation applied.'),
          backgroundColor: AppColors.success,
        ),
      );

      ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesOrders;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create sales order: $e'), backgroundColor: AppColors.danger),
      );
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
                final isStacked = constraints.maxWidth < 750;
                final titleBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create Sales Order', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text(
                      'Direct confirmed order with automated stock reservation & production shortage creation',
                      style: AppTextStyles.subtitle,
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ErpButton(
                      text: 'Cancel',
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesOrders,
                    ),
                    ErpButton(
                      text: 'Create & Allocate Stock',
                      icon: Icons.check,
                      onPressed: _createSalesOrder,
                    ),
                  ],
                );

                if (isStacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 16),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 16),
                    actionButtons,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Party & Order Info Card
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
                  Text('Customer & Delivery Scheduling', style: AppTextStyles.h3),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, partyConstraints) {
                      final isNarrow = partyConstraints.maxWidth < 750;

                      final partyDropdown = DropdownButtonFormField<String>(
                        value: ((_partyType == PartyType.customer && db.customers.any((c) => c.id == _selectedPartyId)) ||
                                (_partyType == PartyType.dealer && db.dealers.any((d) => d.id == _selectedPartyId)) ||
                                (_partyType == PartyType.architect && db.architects.any((a) => a.id == _selectedPartyId)))
                            ? _selectedPartyId
                            : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _partyType == PartyType.customer
                              ? 'Customer *'
                              : _partyType == PartyType.dealer
                                  ? 'Dealer *'
                                  : 'Architect *',
                        ),
                        items: _partyType == PartyType.customer
                            ? db.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList()
                            : _partyType == PartyType.dealer
                                ? db.dealers.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList()
                                : db.architects.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.companyName})'))).toList(),
                        onChanged: (val) => setState(() => _selectedPartyId = val),
                      );

                      final projectDropdown = DropdownButtonFormField<String?>(
                        value: (_selectedProjectId != null && db.projects.any((p) => p.id == _selectedProjectId))
                            ? _selectedProjectId
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Linked Project (Optional)'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('None (Direct Site)')),
                          ...db.projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                        ],
                        onChanged: (val) => setState(() => _selectedProjectId = val),
                      );

                      final dateField = TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Expected Delivery Date',
                          suffixIcon: const Icon(Icons.calendar_today, size: 18),
                          hintText: Formatters.formatDate(_deliveryDate),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _deliveryDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 180)),
                          );
                          if (picked != null) setState(() => _deliveryDate = picked);
                        },
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            partyDropdown,
                            const SizedBox(height: 12),
                            projectDropdown,
                            const SizedBox(height: 12),
                            dateField,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: partyDropdown),
                          const SizedBox(width: 16),
                          Expanded(child: projectDropdown),
                          const SizedBox(width: 16),
                          Expanded(child: dateField),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Line Items Card
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
                    builder: (context, headerConstraints) {
                      final isNarrowHeader = headerConstraints.maxWidth < 420;
                      if (isNarrowHeader) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ordered Products & Real-time Stock Check', style: AppTextStyles.h3),
                            const SizedBox(height: 8),
                            ErpButton(text: 'Add Product Row', icon: Icons.add, isOutlined: true, onPressed: _addNewRow),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('Ordered Products & Real-time Stock Check', style: AppTextStyles.h3)),
                          const SizedBox(width: 8),
                          ErpButton(text: 'Add Product Row', icon: Icons.add, isOutlined: true, onPressed: _addNewRow),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 20),
                    itemBuilder: (ctx, idx) {
                      final item = _items[idx];
                      final isShortage = item.quantity > item.availableStock;

                      return LayoutBuilder(
                        builder: (context, rowConstraints) {
                          final isStacked = rowConstraints.maxWidth < 800;

                          final productDropdown = DropdownButtonFormField<String>(
                            value: db.finishedProducts.any((p) => p.id == item.finishedProductId)
                                ? item.finishedProductId
                                : (db.finishedProducts.isNotEmpty ? db.finishedProducts.first.id : null),
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Finished Product *'),
                            items: db.finishedProducts.map((fp) {
                              return DropdownMenuItem(
                                value: fp.id,
                                child: Text('${fp.name} (${fp.itemCode}) - Usable Avail: ${fp.availableStock} ${fp.unit}'),
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
                                  item.rate = fp.customerSellingPrice;
                                  item.gstPercent = fp.gstPercent;
                                  item.availableStock = fp.availableStock;
                                });
                              }
                            },
                          );

                          final stockBadge = Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isShortage ? AppColors.warning.withValues(alpha: 0.1) : AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: isShortage ? AppColors.warning : AppColors.success),
                            ),
                            child: Text(
                              isShortage ? 'Shortage: ${(item.quantity - item.availableStock).toInt()} (Auto Prod)' : 'In Stock (${item.availableStock.toInt()})',
                              style: TextStyle(
                                color: isShortage ? AppColors.warningText : AppColors.successText,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );

                          final qtyField = TextFormField(
                            initialValue: item.quantity.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Ordered Qty'),
                            onChanged: (val) => setState(() => item.quantity = double.tryParse(val) ?? 1.0),
                          );

                          final rateField = TextFormField(
                            initialValue: item.rate.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Rate (₹)'),
                            onChanged: (val) => setState(() => item.rate = double.tryParse(val) ?? 0.0),
                          );

                          final discountField = TextFormField(
                            initialValue: item.discount.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Discount (₹)'),
                            onChanged: (val) => setState(() => item.discount = double.tryParse(val) ?? 0.0),
                          );

                          final totalPill = Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('Total', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                                  Text(Formatters.formatCurrency(item.lineTotal), style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                                ],
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                                onPressed: () => _removeRow(idx),
                              ),
                            ],
                          );

                          if (isStacked) {
                            final isVeryNarrow = rowConstraints.maxWidth < 450;
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isShortage ? AppColors.warning.withValues(alpha: 0.04) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isShortage ? AppColors.warning.withValues(alpha: 0.4) : Colors.grey.shade200),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  productDropdown,
                                  const SizedBox(height: 8),
                                  stockBadge,
                                  const SizedBox(height: 12),
                                  if (isVeryNarrow) ...[
                                    qtyField,
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(child: rateField),
                                        const SizedBox(width: 8),
                                        Expanded(child: discountField),
                                      ],
                                    ),
                                  ] else
                                    Row(
                                      children: [
                                        Expanded(child: qtyField),
                                        const SizedBox(width: 8),
                                        Expanded(child: rateField),
                                        const SizedBox(width: 8),
                                        Expanded(child: discountField),
                                      ],
                                    ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [totalPill],
                                  ),
                                ],
                              ),
                            );
                          }

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isShortage ? AppColors.warning.withValues(alpha: 0.04) : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isShortage ? AppColors.warning.withValues(alpha: 0.4) : Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Expanded(flex: 3, child: productDropdown),
                                const SizedBox(width: 8),
                                stockBadge,
                                const SizedBox(width: 12),
                                Expanded(flex: 1, child: qtyField),
                                const SizedBox(width: 12),
                                Expanded(flex: 1, child: rateField),
                                const SizedBox(width: 12),
                                Expanded(flex: 1, child: discountField),
                                const SizedBox(width: 16),
                                totalPill,
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Summary Totals
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                width: double.infinity,
                padding: AppSpacing.cardPadding,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.lgBorderRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text('Subtotal:')),
                        Text(Formatters.formatCurrency(_subtotalAmount)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(child: Text('GST Taxes:')),
                        Text(Formatters.formatCurrency(_totalGst)),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text('Total Order Amount:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        ),
                        const SizedBox(width: 8),
                        Text(Formatters.formatCurrency(_grandTotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
