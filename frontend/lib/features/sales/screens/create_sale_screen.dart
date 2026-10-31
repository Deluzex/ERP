import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_radius.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/models/architect_model.dart';
import '../../../core/models/customer_model.dart';
import '../../../core/models/dealer_model.dart';
import '../../../core/models/project_model.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/document_ocr_uploader.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../core/widgets/erp_toast.dart';
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
  DateTime _saleDate = DateTime.now();
  PaymentMode _paymentMode = PaymentMode.bankTransfer;
  final List<_SaleLineItemDraft> _items = [];

  bool _isInterStateTax = false;
  int? _partyDropdownVersion = 0;
  int get partyDropdownVersion => _partyDropdownVersion ?? 0;
  int? _projectDropdownVersion = 0;
  int get projectDropdownVersion => _projectDropdownVersion ?? 0;

  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseServiceProvider);
    if (db.customers.isNotEmpty) {
      _selectedPartyId = db.customers.first.id;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _resolveTaxClassification();
        });
      }
    });
  }

  void _resolveTaxClassification() {
    final db = ref.read(databaseServiceProvider);

    // 1. If project is selected, project site location authoritatively governs Place of Supply
    if (_selectedProjectId != null) {
      final project = db.projects.where((p) => p.id == _selectedProjectId).firstOrNull;
      if (project != null) {
        final siteState = project.siteState?.trim().toLowerCase();
        final siteCode = project.siteStateCode?.trim();

        if ((siteState != null && siteState.isNotEmpty) || (siteCode != null && siteCode.isNotEmpty)) {
          final isGujarat = siteCode == '24' || siteState == 'gujarat';
          _isInterStateTax = !isGujarat;
          return;
        }
      }
    }

    // 2. Fall back to party location
    String? partyGst;
    String? partyState;
    String? partyStateCode;

    if (_partyType == PartyType.customer) {
      final c = db.customers.where((x) => x.id == _selectedPartyId).firstOrNull;
      if (c != null) {
        partyGst = c.gstNumber.trim();
        partyState = c.state.trim().toLowerCase();
        partyStateCode = c.stateCode.trim();
      }
    } else if (_partyType == PartyType.dealer) {
      final d = db.dealers.where((x) => x.id == _selectedPartyId).firstOrNull;
      if (d != null) {
        partyGst = d.gstNumber.trim();
        partyState = d.state.trim().toLowerCase();
      }
    } else if (_partyType == PartyType.architect) {
      final a = db.architects.where((x) => x.id == _selectedPartyId).firstOrNull;
      if (a != null) {
        partyGst = a.gstNumber.trim();
        partyState = a.state.trim().toLowerCase();
      }
    }

    if (partyGst != null && partyGst.length >= 2) {
      final prefix = partyGst.substring(0, 2);
      if (RegExp(r'^\d{2}$').hasMatch(prefix)) {
        _isInterStateTax = (prefix != '24');
        return;
      }
    }

    if (partyStateCode != null && partyStateCode.isNotEmpty) {
      _isInterStateTax = (partyStateCode != '24');
      return;
    }

    if (partyState != null && partyState.isNotEmpty) {
      _isInterStateTax = (partyState != 'gujarat');
      return;
    }

    _isInterStateTax = false;
  }

  Future<void> _showAddProductDialog() async {
    final db = ref.read(databaseServiceProvider);
    if (db.finishedProducts.isEmpty) {
ErpToast.showWarning(context, 'No finished products found in catalog.');
      return;
    }

    final dialogFormKey = GlobalKey<FormState>();
    String? selectedProductId = db.finishedProducts.first.id;
    final firstFp = db.finishedProducts.first;
    final initialRate = _partyType == PartyType.customer ? firstFp.customerSellingPrice : firstFp.dealerSellingPrice;

    final qtyCtrl = TextEditingController(text: '1');
    final rateCtrl = TextEditingController(text: initialRate.toStringAsFixed(0));
    final discountCtrl = TextEditingController(text: '0');
    final gstCtrl = TextEditingController(text: firstFp.gstPercent.toString());

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final selectedFp = db.finishedProducts.firstWhere(
            (p) => p.id == selectedProductId,
            orElse: () => db.finishedProducts.first,
          );
          final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
          final rate = double.tryParse(rateCtrl.text.trim()) ?? 0.0;
          final discount = double.tryParse(discountCtrl.text.trim()) ?? 0.0;
          final gstPercent = double.tryParse(gstCtrl.text.trim()) ?? selectedFp.gstPercent;

          final taxable = ((qty * rate) - discount).clamp(0.0, double.infinity);
          final gstAmount = taxable * (gstPercent / 100.0);
          final lineTotal = taxable + gstAmount;
          final isStockShort = selectedFp.currentStock < qty;

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
                  child: const Icon(Icons.inventory_2_outlined, color: AppColors.primaryDark, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add Product', style: AppTextStyles.h3),
                      Text(
                        'Select product item and specify dispatch quantity & pricing',
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
                      // Product Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedProductId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Product *',
                          prefixIcon: Icon(Icons.category_outlined, size: 20),
                        ),
                        items: db.finishedProducts.map((fp) {
                          return DropdownMenuItem(
                            value: fp.id,
                            child: Text(
                              '${fp.itemCode} - ${fp.name} (Stock: ${Formatters.formatNumber(fp.currentStock)} ${fp.unit})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            final chosen = db.finishedProducts.firstWhere((p) => p.id == val);
                            setDlgState(() {
                              selectedProductId = chosen.id;
                              final newRate = _partyType == PartyType.customer
                                  ? chosen.customerSellingPrice
                                  : chosen.dealerSellingPrice;
                              rateCtrl.text = newRate.toStringAsFixed(0);
                              gstCtrl.text = chosen.gstPercent.toString();
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
                                    ? 'Low Stock: Available ${Formatters.formatNumber(selectedFp.currentStock)} ${selectedFp.unit} (Short by ${Formatters.formatNumber(qty - selectedFp.currentStock)} ${selectedFp.unit})'
                                    : 'Available in Stock: ${Formatters.formatNumber(selectedFp.currentStock)} ${selectedFp.unit}',
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

                      // Quantity and Rate
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: qtyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: Validators.positiveNumber,
                              decoration: InputDecoration(
                                labelText: 'Quantity (${selectedFp.unit}) *',
                                prefixIcon: const Icon(Icons.numbers, size: 20),
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: rateCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: Validators.positiveNumber,
                              decoration: const InputDecoration(
                                labelText: 'Rate (₹) *',
                                prefixIcon: Icon(Icons.currency_rupee, size: 20),
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Discount and GST%
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: discountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Discount (₹)',
                                prefixIcon: Icon(Icons.discount_outlined, size: 20),
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: gstCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: Validators.positiveNumber,
                              decoration: const InputDecoration(
                                labelText: 'GST (%) *',
                                prefixIcon: Icon(Icons.percent, size: 20),
                              ),
                              onChanged: (_) => setDlgState(() {}),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Cost / Line Total Preview Card
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
                                Text('Line Total (inc. Tax):', style: AppTextStyles.bodySmall),
                                Text(
                                  Formatters.formatCurrency(lineTotal),
                                  style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary, fontSize: 16),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Taxable: ${Formatters.formatCurrency(taxable)}', style: AppTextStyles.bodySmall),
                                Text('GST (${gstPercent.toStringAsFixed(0)}%): ${Formatters.formatCurrency(gstAmount)}', style: AppTextStyles.bodySmall),
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
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              ErpButton(
                text: 'Add to Order',
                icon: Icons.add,
                onPressed: () {
                  if (!dialogFormKey.currentState!.validate()) return;
                  setState(() {
                    _items.add(_SaleLineItemDraft(
                      finishedProductId: selectedFp.id,
                      finishedProductName: selectedFp.name,
                      finishedProductCode: selectedFp.itemCode,
                      unit: selectedFp.unit,
                      quantity: qty,
                      rate: rate,
                      discount: discount,
                      gstPercent: gstPercent,
                    ));
                  });
                  Navigator.of(ctx).pop();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _removeLineItem(int index) {
    setState(() => _items.removeAt(index));
  }

  double get _subtotalAmount => _items.fold(0.0, (sum, i) => sum + (i.quantity * i.rate));
  double get _totalDiscount => _items.fold(0.0, (sum, i) => sum + i.discount);
  double get _totalGst => _items.fold(0.0, (sum, i) => sum + (((i.quantity * i.rate) - i.discount) * (i.gstPercent / 100.0)));
  double get _totalAmount => _items.fold(0.0, (sum, item) => sum + item.lineTotal);
  double get _paidAmount => double.tryParse(_paidAmountCtrl.text.trim()) ?? 0.0;
  double get _pendingAmount => (_totalAmount - _paidAmount).clamp(0.0, double.infinity);

  double get _calculatedCommission {
    if (_partyType != PartyType.architect || _selectedPartyId == null) return 0.0;
    final db = ref.read(databaseServiceProvider);
    final arch = db.architects.firstWhere((a) => a.id == _selectedPartyId, orElse: () => db.architects.first);
    final baseAmount = _subtotalAmount - _totalDiscount;
    return (baseAmount * arch.defaultCommissionRate) / 100.0;
  }

  void _openQuickAddPartyDialog(PartyType partyType) {
    final db = ref.read(databaseServiceProvider);
    final nameCtrl = TextEditingController();
    final companyCtrl = TextEditingController();
    final contactPersonCtrl = TextEditingController();
    final mobileCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final gstCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final commissionRateCtrl = TextEditingController(text: '5.0');
    final formKey = GlobalKey<FormState>();

    String title;
    String nameLabel;
    String nameHint;
    switch (partyType) {
      case PartyType.customer:
        title = 'Add Customer Master';
        nameLabel = 'Customer Name / Estate *';
        nameHint = 'E.g., Oberoi Sky City Residences';
        break;
      case PartyType.dealer:
        title = 'Add Dealer Master';
        nameLabel = 'Dealer Trading Name *';
        nameHint = 'E.g., Luxe Lightings & Decor Studio';
        break;
      case PartyType.architect:
        title = 'Add Architect Master';
        nameLabel = 'Architect Name *';
        nameHint = 'E.g., Ar. Sanjay Puri';
        break;
    }

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(title, style: AppTextStyles.h2),
                  ErpButton(
                    text: 'Scan & Upload (OCR)',
                    icon: Icons.document_scanner_outlined,
                    isOutlined: true,
                    onPressed: isSaving
                        ? null
                        : () {
                            showDialog(
                              context: context,
                              builder: (ocrCtx) => Dialog(
                                backgroundColor: Colors.transparent,
                                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 860, maxHeight: 720),
                                  width: double.infinity,
                                  height: MediaQuery.of(context).size.height * 0.88,
                                  child: DocumentOcrUploader(
                                    docType: partyType == PartyType.customer
                                        ? OcrDocType.customerDoc
                                        : (partyType == PartyType.dealer ? OcrDocType.customerDoc : OcrDocType.architectDoc),
                                    onCancel: () => Navigator.of(ocrCtx).pop(),
                                    onConfirm: (data) {
                                      nameCtrl.text = data['Customer Name'] ?? data['Company Name'] ?? data['Dealer Name'] ?? data['Architect Name'] ?? nameCtrl.text;
                                      companyCtrl.text = data['Company Name'] ?? companyCtrl.text;
                                      contactPersonCtrl.text = data['Contact Person'] ?? contactPersonCtrl.text;
                                      mobileCtrl.text = data['Mobile'] ?? mobileCtrl.text;
                                      emailCtrl.text = data['Email'] ?? emailCtrl.text;
                                      addressCtrl.text = data['Address'] ?? addressCtrl.text;
                                      gstCtrl.text = data['GSTIN'] ?? data['GST Number'] ?? gstCtrl.text;
                                      Navigator.of(ocrCtx).pop();
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                  ),
                ],
              ),
              content: Container(
                constraints: const BoxConstraints(maxWidth: 540),
                width: double.infinity,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          validator: (v) => Validators.requiredField(v, '$nameLabel required'),
                          decoration: InputDecoration(labelText: nameLabel, hintText: nameHint),
                        ),
                        const SizedBox(height: 12),
                        if (partyType == PartyType.dealer) ...[
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: companyCtrl,
                                  validator: (v) => Validators.requiredField(v, 'Registered entity name required'),
                                  decoration: const InputDecoration(labelText: 'Registered Entity Name *', hintText: 'E.g., Luxe Furnishings LLP'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: contactPersonCtrl,
                                  validator: (v) => Validators.requiredField(v, 'Contact person required'),
                                  decoration: const InputDecoration(labelText: 'Contact Person *', hintText: 'E.g., Ramesh Shah'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (partyType == PartyType.architect) ...[
                          TextFormField(
                            controller: companyCtrl,
                            validator: (v) => Validators.requiredField(v, 'Studio / Firm name required'),
                            decoration: const InputDecoration(labelText: 'Studio / Firm Name *', hintText: 'E.g., Sanjay Puri Architects'),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: mobileCtrl,
                                validator: Validators.mobile,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(labelText: 'Mobile Number *', hintText: 'E.g., 9876543210'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: emailCtrl,
                                validator: Validators.requiredEmailAddress,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(labelText: 'Email Address *', hintText: 'name@example.com'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: gstCtrl,
                                validator: (v) => Validators.gst(v, false),
                                decoration: const InputDecoration(
                                  labelText: 'GST Number (Optional, 15 chars)',
                                  hintText: '24AAAAA0000A1Z5',
                                ),
                              ),
                            ),
                            if (partyType == PartyType.architect) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: commissionRateCtrl,
                                  keyboardType: TextInputType.number,
                                  validator: (v) => Validators.percentage(v, 'Must be between 0% and 100%'),
                                  decoration: const InputDecoration(labelText: 'Default Commission Rate (%) *'),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: addressCtrl,
                          maxLines: 2,
                          validator: (v) => Validators.requiredField(
                            v,
                            partyType == PartyType.customer
                                ? 'Site / Billing Address required'
                                : (partyType == PartyType.dealer ? 'Showroom / Business Address required' : 'Studio / Office Address required'),
                          ),
                          decoration: InputDecoration(
                            labelText: partyType == PartyType.customer
                                ? 'Site / Billing Address *'
                                : (partyType == PartyType.dealer ? 'Showroom / Business Address *' : 'Studio / Office Address *'),
                            hintText: 'Enter complete postal address with locality and city',
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
                  onPressed: isSaving ? null : () => Navigator.of(ctx).pop(),
                ),
                ErpButton(
                  text: 'Save & Select',
                  icon: Icons.check_circle_outline,
                  isLoading: isSaving,
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) {
                            ErpToast.showError(ctx, 'Please fill in all required fields marked with *');
                            return;
                          }

                          setDlgState(() => isSaving = true);

                          try {
                            if (partyType == PartyType.customer) {
                              final newCust = Customer(
                                id: IdGenerator.generateId('CUST'),
                                name: nameCtrl.text.trim(),
                                mobile: mobileCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                gstNumber: gstCtrl.text.trim(),
                                address: addressCtrl.text.trim(),
                                outstandingAmount: 0.0,
                                createdAt: DateTime.now(),
                              );
                              final saved = await db.addCustomerAsync(newCust);
                              if (!mounted) return;
                              setState(() {
                                _selectedPartyId = saved.id;
                              _resolveTaxClassification();
                              });
                            } else if (partyType == PartyType.dealer) {
                              final newDealer = Dealer(
                                id: IdGenerator.generateId('DLR'),
                                name: nameCtrl.text.trim(),
                                companyName: companyCtrl.text.trim().isNotEmpty ? companyCtrl.text.trim() : nameCtrl.text.trim(),
                                contactPerson: contactPersonCtrl.text.trim(),
                                mobile: mobileCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                gstNumber: gstCtrl.text.trim(),
                                address: addressCtrl.text.trim(),
                                outstandingAmount: 0.0,
                                createdAt: DateTime.now(),
                              );
                              final saved = await db.addDealerAsync(newDealer);
                              if (!mounted) return;
                              setState(() {
                                _selectedPartyId = saved.id;
                              _resolveTaxClassification();
                              });
                            } else if (partyType == PartyType.architect) {
                              final newArch = Architect(
                                id: IdGenerator.generateId('ARCH'),
                                name: nameCtrl.text.trim(),
                                companyName: companyCtrl.text.trim().isNotEmpty ? companyCtrl.text.trim() : nameCtrl.text.trim(),
                                mobile: mobileCtrl.text.trim(),
                                email: emailCtrl.text.trim(),
                                gstNumber: gstCtrl.text.trim(),
                                address: addressCtrl.text.trim(),
                                defaultCommissionRate: double.tryParse(commissionRateCtrl.text.trim()) ?? 5.0,
                                totalCommissionEarned: 0.0,
                                pendingCommission: 0.0,
                                approvedCommission: 0.0,
                                paidCommission: 0.0,
                                createdAt: DateTime.now(),
                              );
                              final saved = await db.addArchitectAsync(newArch);
                              if (!mounted) return;
                              setState(() {
                                _selectedPartyId = saved.id;
                              _resolveTaxClassification();
                              });
                            }

                            if (ctx.mounted && Navigator.of(ctx).canPop()) {
                              Navigator.of(ctx).pop();
                            }

                            if (!mounted) return;
                            ErpToast.showSuccess(
                              context,
                              '${partyType == PartyType.customer ? 'Customer' : partyType == PartyType.dealer ? 'Dealer' : 'Architect'} created and added to master successfully!',
                            );
                          } catch (e) {
                            setDlgState(() => isSaving = false);
                            final msg = e.toString().replaceAll('Exception: ', '').trim();
                            if (ctx.mounted) {
                              ErpToast.showError(ctx, 'Failed to save: $msg');
                            }
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

  void _openQuickAddProjectDialog() {
    final db = ref.read(databaseServiceProvider);
    final nameCtrl = TextEditingController();
    final siteStateCtrl = TextEditingController(text: 'Gujarat');
    final sitePincodeCtrl = TextEditingController();
    final siteAddressCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? selectedCustId;
    ProjectStatus status = ProjectStatus.active;

    final currentArch = _partyType == PartyType.architect
        ? db.architects.where((a) => a.id == _selectedPartyId).firstOrNull
        : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Add Project Master', style: AppTextStyles.h2),
                  if (currentArch != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: AppRadius.smBorderRadius,
                      ),
                      child: Text('Architect: ${currentArch.name}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.primary)),
                    ),
                ],
              ),
              content: SizedBox(
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          validator: (v) => Validators.requiredField(v, 'Project name required'),
                          decoration: const InputDecoration(labelText: 'Project Name *', hintText: 'E.g., Oberoi Sky City Tower D'),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          value: selectedCustId,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Linked Client / Customer (Optional)'),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('None (Direct Architect Specification)')),
                            ...db.customers.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (val) => setDlgState(() => selectedCustId = val),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<ProjectStatus>(
                          value: status,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Project Status *'),
                          items: ProjectStatus.values.map((s) {
                            return DropdownMenuItem(value: s, child: Text(s.toString().split('.').last.toUpperCase()));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setDlgState(() => status = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: siteStateCtrl,
                          validator: (v) => Validators.requiredField(v, 'Site state is required for GST determination'),
                          decoration: const InputDecoration(
                            labelText: 'Site State (Place of Supply) *',
                            hintText: 'e.g. Gujarat, Maharashtra',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: sitePincodeCtrl,
                          validator: (v) => v != null && v.trim().isNotEmpty ? Validators.pincode(v) : null,
                          decoration: const InputDecoration(
                            labelText: 'Site PIN Code (Optional)',
                            hintText: 'e.g. 380001',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: siteAddressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Site Address (Optional)',
                            hintText: 'Full project construction address',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Project Notes / Scope (Optional)'),
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
                  text: 'Save Project',
                  icon: Icons.check_circle_outline,
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.of(ctx).pop();

                    String? custName;
                    if (selectedCustId != null) {
                      custName = db.customers.where((c) => c.id == selectedCustId).firstOrNull?.name;
                    }

                    final stateName = siteStateCtrl.text.trim();
                    final isGujarat = stateName.toLowerCase() == 'gujarat' || stateName == '24';
                    final newProj = Project(
                      id: IdGenerator.generateId('PRJ'),
                      name: nameCtrl.text.trim(),
                      customerId: selectedCustId,
                      customerName: custName,
                      architectId: currentArch?.id,
                      architectName: currentArch?.name,
                      startDate: DateTime.now(),
                      expectedCompletionDate: DateTime.now().add(const Duration(days: 90)),
                      status: status,
                      siteState: stateName.isNotEmpty ? stateName : null,
                      siteStateCode: isGujarat ? '24' : (stateName.toLowerCase() == 'maharashtra' ? '27' : null),
                      sitePincode: sitePincodeCtrl.text.trim().isNotEmpty ? sitePincodeCtrl.text.trim() : null,
                      siteAddress: siteAddressCtrl.text.trim().isNotEmpty ? siteAddressCtrl.text.trim() : null,
                      posVerified: stateName.isNotEmpty,
                      notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                      createdAt: DateTime.now(),
                    );

                    db.addProject(newProj);
                    setState(() {
                      _selectedProjectId = newProj.id;
                      _resolveTaxClassification();
                    });

ErpToast.showSuccess(context, 'Project created and added to Project Master successfully!');
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createInvoice(bool isDraft) async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
ErpToast.showError(context, 'Please add at least one finished product to invoice.');
      return;
    }
    final db = ref.read(databaseServiceProvider);

    if (_selectedProjectId != null) {
      final p = db.projects.where((prj) => prj.id == _selectedProjectId).firstOrNull;
      if (p != null) {
        final siteState = p.siteState?.trim();
        final siteCode = p.siteStateCode?.trim();
        if ((siteState == null || siteState.isEmpty) && (siteCode == null || siteCode.isEmpty)) {
ErpToast.showError(context, 'Cannot finalize sale: Project Place of Supply site state is unresolved. Please update the project site location in Project Master before proceeding.');
          return;
        }
      }
    }

    _resolveTaxClassification();

    // Validate finished product inventory
    if (!isDraft) {
      for (final item in _items) {
        final fp = db.finishedProducts.firstWhere((p) => p.id == item.finishedProductId, orElse: () => db.finishedProducts.first);
        if (fp.currentStock < item.quantity) {
ErpToast.showError(context, 'Insufficient stock for ${fp.name}! Available: ${fp.currentStock} ${fp.unit}, Invoiced: ${item.quantity} ${fp.unit}');
          return;
        }
      }
    }

    String partyName = '';
    if (_partyType == PartyType.customer) {
      final c = db.customers.firstWhere((cust) => cust.id == _selectedPartyId, orElse: () => db.customers.first);
      partyName = c.name;
    } else if (_partyType == PartyType.dealer) {
      final d = db.dealers.firstWhere((dlr) => dlr.id == _selectedPartyId, orElse: () => db.dealers.first);
      partyName = d.name;
    } else {
      final a = db.architects.firstWhere((arc) => arc.id == _selectedPartyId, orElse: () => db.architects.first);
      partyName = '${a.name} (${a.companyName})';
    }

    String? projName;
    if (_selectedProjectId != null) {
      final p = db.projects.firstWhere((prj) => prj.id == _selectedProjectId, orElse: () => db.projects.first);
      projName = p.name;
    }

    String? archName;
    String? archId;
    if (_partyType == PartyType.architect) {
      final a = db.architects.firstWhere((arc) => arc.id == _selectedPartyId, orElse: () => db.architects.first);
      archName = a.name;
      archId = a.id;
    }

    final saleItems = _items.map((i) {
      final taxable = ((i.quantity * i.rate) - i.discount).clamp(0.0, double.infinity);
      final gst = taxable * (i.gstPercent / 100.0);
      final cgst = _isInterStateTax ? 0.0 : (gst / 2);
      final sgst = _isInterStateTax ? 0.0 : (gst / 2);
      final igst = _isInterStateTax ? gst : 0.0;

      return SaleLineItem(
        finishedProductId: i.finishedProductId,
        finishedProductName: i.finishedProductName,
        finishedProductCode: i.finishedProductCode,
        quantity: i.quantity,
        unit: i.unit,
        rate: i.rate,
        discountAmount: i.discount,
        gstPercent: i.gstPercent,
        taxableAmount: taxable,
        cgstAmount: cgst,
        sgstAmount: sgst,
        igstAmount: igst,
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
      architectId: archId,
      architectName: archName,
      saleDate: _saleDate,
      items: saleItems,
      subtotalAmount: _subtotalAmount,
      discountAmount: _totalDiscount,
      taxableAmount: _subtotalAmount - _totalDiscount,
      cgstAmount: _isInterStateTax ? 0.0 : (_totalGst / 2),
      sgstAmount: _isInterStateTax ? 0.0 : (_totalGst / 2),
      igstAmount: _isInterStateTax ? _totalGst : 0.0,
      isInterStateTax: _isInterStateTax,
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

    try {
      if (isDraft) {
        // Direct-sale API always executes immediately (stock deduction + payment); drafts stay local-only.
        db.createSale(sale);
      } else {
        await db.createDirectSaleAsync(sale);
      }

      if (!mounted) return;
ErpToast.showSuccess(context, isDraft ? 'Draft Sale Saved' : 'Invoice Created! Finished Product stock deducted & commission generated.');

      ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesInvoiceList;
    } catch (e) {
      if (!mounted) return;
ErpToast.showError(context, 'Failed to create sale: $e');
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
            ErpSectionHeaderCard(
                icon: Icons.point_of_sale_outlined,
                title: 'Create Sales Invoice',
                badgeText: 'DIRECT SALE / INVOICE',
                action: LayoutBuilder(
                  builder: (context, actionBox) {
                    final isMobile = actionBox.maxWidth < 520;
                    if (isMobile) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: ErpButton(
                              text: 'Create Invoice & Dispatch',
                              icon: Icons.receipt_long_outlined,
                              onPressed: () => _createInvoice(false),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ErpButton(
                              text: 'Save Draft',
                              isOutlined: true,
                              onPressed: () => _createInvoice(true),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ErpButton(
                              text: 'Cancel',
                              isOutlined: true,
                              onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesInvoiceList,
                            ),
                          ),
                        ],
                      );
                    }
                    return Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        ErpButton(
                          text: 'Cancel',
                          isOutlined: true,
                          onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.salesInvoiceList,
                        ),
                        ErpButton(
                          text: 'Save Draft',
                          isOutlined: true,
                          onPressed: () => _createInvoice(true),
                        ),
                        ErpButton(
                          text: 'Create Invoice & Dispatch',
                          icon: Icons.receipt_long_outlined,
                          onPressed: () => _createInvoice(false),
                        ),
                      ],
                    );
                  },
                ),
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
                  LayoutBuilder(
                    builder: (context, partyBox) {
                      final isNarrow = partyBox.maxWidth < 750;

                      final partyTypeDropdown = DropdownButtonFormField<PartyType>(
                        value: _partyType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Customer / Channel Type *',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: PartyType.customer,
                            child: Text('Direct Customer'),
                          ),
                          DropdownMenuItem(
                            value: PartyType.dealer,
                            child: Text('Dealer Channel'),
                          ),
                          DropdownMenuItem(
                            value: PartyType.architect,
                            child: Text('Architect'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null && val != _partyType) {
                            setState(() {
                              _partyType = val;
                              _selectedProjectId = null;
                              if (val == PartyType.customer) {
                                _selectedPartyId = db.customers.isNotEmpty ? db.customers.first.id : null;
                              } else if (val == PartyType.dealer) {
                                _selectedPartyId = db.dealers.isNotEmpty ? db.dealers.first.id : null;
                              } else {
                                _selectedPartyId = db.architects.isNotEmpty ? db.architects.first.id : null;
                              }
                              _resolveTaxClassification();
                            });
                          }
                        },
                      );

                      final dropdownField = DropdownButtonFormField<String?>(
                        key: ValueKey('sale_party_${_partyType}_${_selectedPartyId}_$partyDropdownVersion'),
                        value: ((_partyType == PartyType.customer && db.customers.any((c) => c.id == _selectedPartyId)) ||
                                (_partyType == PartyType.dealer && db.dealers.any((d) => d.id == _selectedPartyId)) ||
                                (_partyType == PartyType.architect && db.architects.any((a) => a.id == _selectedPartyId)))
                            ? _selectedPartyId
                            : null,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _partyType == PartyType.customer
                              ? 'Select Customer *'
                              : _partyType == PartyType.dealer
                                  ? 'Select Dealer *'
                                  : 'Select Architect *',
                        ),
                        selectedItemBuilder: (context) {
                          return [
                            Text(
                              _selectedPartyId != null
                                  ? (_partyType == PartyType.customer
                                      ? db.customers.where((c) => c.id == _selectedPartyId).firstOrNull?.name ?? ''
                                      : _partyType == PartyType.dealer
                                          ? db.dealers.where((d) => d.id == _selectedPartyId).firstOrNull?.name ?? ''
                                          : db.architects.where((a) => a.id == _selectedPartyId).firstOrNull?.name ?? '')
                                  : '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_partyType == PartyType.customer)
                              ...db.customers.map((c) => Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis))
                            else if (_partyType == PartyType.dealer)
                              ...db.dealers.map((d) => Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis))
                            else
                              ...db.architects.map((a) => Text('${a.name} (${a.companyName})', maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ];
                        },
                        items: [
                          DropdownMenuItem<String?>(
                            value: '__ADD_NEW__',
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(bottom: 4),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.add_circle, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    _partyType == PartyType.customer
                                        ? '+ Add New Customer'
                                        : _partyType == PartyType.dealer
                                            ? '+ Add New Dealer'
                                            : '+ Add New Architect',
                                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_partyType == PartyType.customer)
                            ...db.customers.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis)))
                          else if (_partyType == PartyType.dealer)
                            ...db.dealers.map((d) => DropdownMenuItem<String?>(value: d.id, child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis)))
                          else
                            ...db.architects.map((a) => DropdownMenuItem<String?>(value: a.id, child: Text('${a.name} (${a.companyName})', maxLines: 1, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (val) {
                          if (val == '__ADD_NEW__') {
                            setState(() {
                              _partyDropdownVersion = partyDropdownVersion + 1;
                            });
                            _openQuickAddPartyDialog(_partyType);
                            return;
                          }
                          setState(() {
                            _selectedPartyId = val;
                            _resolveTaxClassification();
                          });
                        },
                      );

                      final projectField = DropdownButtonFormField<String?>(
                        key: ValueKey('sale_proj_${_selectedProjectId}_$projectDropdownVersion'),
                        value: (_selectedProjectId != null && db.projects.any((p) => p.id == _selectedProjectId))
                            ? _selectedProjectId
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Linked Project (Optional)'),
                        selectedItemBuilder: (context) {
                          return [
                            Text(
                              _selectedProjectId != null
                                  ? db.projects.where((p) => p.id == _selectedProjectId).firstOrNull?.name ?? ''
                                  : 'None (Direct Site)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Text('None (Direct Site)', maxLines: 1, overflow: TextOverflow.ellipsis),
                            ...db.projects.map((p) => Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ];
                        },
                        items: [
                          DropdownMenuItem<String?>(
                            value: '__ADD_PROJECT__',
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.only(bottom: 4),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.add_circle, size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    '+ Add New Project',
                                    style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const DropdownMenuItem<String?>(value: null, child: Text('None (Direct Site)')),
                          ...db.projects.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (val) {
                          if (val == '__ADD_PROJECT__') {
                            setState(() {
                              _projectDropdownVersion = projectDropdownVersion + 1;
                            });
                            _openQuickAddProjectDialog();
                            return;
                          }
                          setState(() {
                            _selectedProjectId = val;
                            _resolveTaxClassification();
                          });
                        },
                      );

                      final paymentModeField = DropdownButtonFormField<PaymentMode>(
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
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            partyTypeDropdown,
                            const SizedBox(height: 12),
                            dropdownField,
                            if (_partyType == PartyType.architect) ...[
                              const SizedBox(height: 12),
                              projectField,
                            ],
                            const SizedBox(height: 12),
                            paymentModeField,
                          ],
                        );
                      }

                      if (_partyType == PartyType.architect) {
                        return Row(
                          children: [
                            Expanded(flex: 2, child: partyTypeDropdown),
                            const SizedBox(width: 16),
                            Expanded(flex: 3, child: dropdownField),
                            const SizedBox(width: 16),
                            Expanded(flex: 3, child: projectField),
                            const SizedBox(width: 16),
                            Expanded(flex: 2, child: paymentModeField),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(flex: 2, child: partyTypeDropdown),
                          const SizedBox(width: 16),
                          Expanded(flex: 3, child: dropdownField),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: paymentModeField),
                        ],
                      );
                    },
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
                  LayoutBuilder(
                    builder: (context, headerConstraints) {
                      final isNarrow = headerConstraints.maxWidth < 520;
                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Finished Products Invoiced', style: AppTextStyles.h3),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ErpButton(
                                text: 'Add Product',
                                icon: Icons.add,
                                isOutlined: true,
                                onPressed: _showAddProductDialog,
                              ),
                            ),
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('Finished Products Invoiced', style: AppTextStyles.h3)),
                          const SizedBox(width: 8),
                          ErpButton(
                            text: 'Add Product',
                            icon: Icons.add,
                            isOutlined: true,
                            onPressed: _showAddProductDialog,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (_items.isEmpty) {
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: AppRadius.smBorderRadius,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textMuted),
                              const SizedBox(height: 8),
                              Text('No products added to this invoice yet.', style: AppTextStyles.subtitle),
                              const SizedBox(height: 12),
                              ErpButton(
                                text: 'Add First Product',
                                icon: Icons.add,
                                isOutlined: true,
                                onPressed: _showAddProductDialog,
                              ),
                            ],
                          ),
                        );
                      }

                      final isMobileItems = constraints.maxWidth < 750;

                      if (isMobileItems) {
                        return Column(
                          children: List.generate(_items.length, (index) {
                            final item = _items[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: AppRadius.mdBorderRadius,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.1),
                                          borderRadius: AppRadius.smBorderRadius,
                                        ),
                                        child: Text(
                                          'Item #${index + 1}',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 20),
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _removeLineItem(index),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    value: db.finishedProducts.any((p) => p.id == item.finishedProductId)
                                        ? item.finishedProductId
                                        : (db.finishedProducts.isNotEmpty ? db.finishedProducts.first.id : null),
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
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
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
                                      Expanded(
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
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
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
                                      Expanded(
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
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: AppRadius.smBorderRadius,
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Line Total', style: AppTextStyles.bodySmall),
                                        Text(
                                          Formatters.formatCurrency(item.lineTotal),
                                          style: AppTextStyles.bodyBold.copyWith(color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        );
                      }

                      const minTableWidth = 950.0;
                      final effectiveWidth = math.max(constraints.maxWidth, minTableWidth);

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: effectiveWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: List.generate(_items.length, (index) {
                              final item = _items[index];
                              return Container(
                                width: effectiveWidth,
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: AppRadius.smBorderRadius,
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Product dropdown
                                    SizedBox(
                                      width: 280,
                                      child: DropdownButtonFormField<String>(
                                        value: db.finishedProducts.any((p) => p.id == item.finishedProductId)
                                            ? item.finishedProductId
                                            : (db.finishedProducts.isNotEmpty ? db.finishedProducts.first.id : null),
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
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Financial Summary & Commission
            LayoutBuilder(
              builder: (context, summaryConstraints) {
                final isNarrowSummary = summaryConstraints.maxWidth < 800;

                final notesCard = Container(
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
                      if (_partyType == PartyType.architect && _selectedPartyId != null) ...[
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
                );

                final totalsCard = Container(
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
                          Expanded(child: Text('Subtotal:', style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Text(Formatters.formatCurrency(_subtotalAmount), style: AppTextStyles.bodyBold),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('Discount:', style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Text('- ${Formatters.formatCurrency(_totalDiscount)}', style: AppTextStyles.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (!_isInterStateTax) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('CGST (9%):', style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text(Formatters.formatCurrency(_totalGst / 2), style: AppTextStyles.bodySmall),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('SGST (9%):', style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text(Formatters.formatCurrency(_totalGst / 2), style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text('IGST (18%):', style: AppTextStyles.bodyMedium.copyWith(color: Colors.purple), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Text(Formatters.formatCurrency(_totalGst), style: AppTextStyles.bodySmall.copyWith(color: Colors.purple, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('Grand Total:', style: AppTextStyles.bodyBold, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
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
                          Expanded(child: Text('Customer Outstanding:', style: AppTextStyles.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
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
                );

                if (isNarrowSummary) {
                  return Column(
                    children: [
                      notesCard,
                      const SizedBox(height: 16),
                      totalsCard,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: notesCard),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: totalsCard),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
