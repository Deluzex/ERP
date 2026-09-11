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
import '../../../core/widgets/document_ocr_uploader.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';

class _QuotationItemDraft {
  String finishedProductId;
  String finishedProductName;
  String finishedProductCode;
  String productDescription;
  String unit;
  double quantity;
  double rate;
  double discount;
  double gstPercent;
  double availableStockSnapshot;

  _QuotationItemDraft({
    required this.finishedProductId,
    required this.finishedProductName,
    required this.finishedProductCode,
    this.productDescription = '',
    required this.unit,
    this.quantity = 1.0,
    this.rate = 1000.0,
    this.discount = 0.0,
    this.gstPercent = 18.0,
    this.availableStockSnapshot = 0.0,
  });

  double get taxableAmount => ((quantity * rate) - discount).clamp(0.0, double.infinity);
  double get gstAmount => taxableAmount * (gstPercent / 100.0);
  double get lineTotal => taxableAmount + gstAmount;

  _QuotationItemDraft copy() {
    return _QuotationItemDraft(
      finishedProductId: finishedProductId,
      finishedProductName: finishedProductName,
      finishedProductCode: finishedProductCode,
      productDescription: productDescription,
      unit: unit,
      quantity: quantity,
      rate: rate,
      discount: discount,
      gstPercent: gstPercent,
      availableStockSnapshot: availableStockSnapshot,
    );
  }
}

class CreateQuotationScreen extends ConsumerStatefulWidget {
  const CreateQuotationScreen({super.key});

  @override
  ConsumerState<CreateQuotationScreen> createState() => _CreateQuotationScreenState();
}

class _CreateQuotationScreenState extends ConsumerState<CreateQuotationScreen> {
  final _formKey = GlobalKey<FormState>();

  PartyType _partyType = PartyType.customer;
  String? _selectedPartyId;
  String? _selectedProjectId;
  String _salesExecutive = 'Alex Sterling';
  bool _isInterStateTax = false; // Intra-State (CGST+SGST) vs Inter-State (IGST)

  // Customer autofill controllers
  final _contactPersonCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _gstNumberCtrl = TextEditingController();
  final _billingAddressCtrl = TextEditingController();
  final _shippingAddressCtrl = TextEditingController();

  DateTime _quotationDate = DateTime.now();
  DateTime _validTill = DateTime.now().add(const Duration(days: 30));

  final _notesCtrl = TextEditingController();
  final _termsCtrl = TextEditingController(
    text: '1. Prices are valid for 30 days from the quotation date.\n2. Payment terms: 50% advance along with confirmed Purchase Order, balance before dispatch.\n3. Standard 3-Year comprehensive manufacturer warranty on all luminaires & LED drivers.\n4. Freight charges will be billed as actuals or FOB Mumbai.',
  );

  final List<_QuotationItemDraft> _items = [];
  Sale? _sourceQuotation;
  bool _isRevision = false;
  int _revisionNumber = 0;

  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseServiceProvider);
    final sourceId = ref.read(salesCreateSourceDocIdProvider);

    if (sourceId != null) {
      _sourceQuotation = db.sales.where((s) => s.id == sourceId).firstOrNull;
      if (_sourceQuotation != null) {
        _isRevision = true;
        _revisionNumber = _sourceQuotation!.revisionNumber + 1;
        _partyType = _sourceQuotation!.partyType;
        _selectedPartyId = _sourceQuotation!.partyId;
        _selectedProjectId = _sourceQuotation!.projectId;
        _contactPersonCtrl.text = _sourceQuotation!.customerContactPerson ?? '';
        _mobileCtrl.text = _sourceQuotation!.customerMobile ?? '';
        _emailCtrl.text = _sourceQuotation!.customerEmail ?? '';
        _gstNumberCtrl.text = _sourceQuotation!.customerGstNumber ?? '';
        _billingAddressCtrl.text = _sourceQuotation!.billingAddress ?? '';
        _shippingAddressCtrl.text = _sourceQuotation!.shippingAddress ?? '';
        _notesCtrl.text = _sourceQuotation!.notes ?? '';
        if (_sourceQuotation!.termsAndConditions != null) {
          _termsCtrl.text = _sourceQuotation!.termsAndConditions!;
        }

        for (final item in _sourceQuotation!.items) {
          final fp = db.finishedProducts.where((p) => p.id == item.finishedProductId).firstOrNull;
          _items.add(_QuotationItemDraft(
            finishedProductId: item.finishedProductId,
            finishedProductName: item.finishedProductName,
            finishedProductCode: item.finishedProductCode,
            productDescription: item.productDescription,
            unit: item.unit,
            quantity: item.quantity,
            rate: item.rate,
            discount: item.discountAmount,
            gstPercent: item.gstPercent,
            availableStockSnapshot: fp?.availableStock ?? 0.0,
          ));
        }
      }
    }

    if (_items.isEmpty) {
      if (db.customers.isNotEmpty) {
        _selectedPartyId = db.customers.first.id;
        _autoFillPartyDetails(db.customers.first.id, PartyType.customer, db);
      }
      if (db.finishedProducts.isNotEmpty) {
        final fp = db.finishedProducts.first;
        _items.add(_QuotationItemDraft(
          finishedProductId: fp.id,
          finishedProductName: fp.name,
          finishedProductCode: fp.itemCode,
          productDescription: 'Architectural luminaire with high-efficiency driver',
          unit: fp.unit,
          quantity: 10.0,
          rate: fp.customerSellingPrice,
          discount: 0.0,
          gstPercent: fp.gstPercent,
          availableStockSnapshot: fp.availableStock,
        ));
      }
    }
  }

  void _autoFillPartyDetails(String partyId, PartyType type, MockDatabaseService db) {
    if (type == PartyType.customer) {
      final c = db.customers.where((cust) => cust.id == partyId).firstOrNull;
      if (c != null) {
        _contactPersonCtrl.text = 'Mr./Ms. Client Representative';
        _mobileCtrl.text = c.mobile;
        _emailCtrl.text = c.email;
        _gstNumberCtrl.text = c.gstNumber;
        _billingAddressCtrl.text = c.address;
        _shippingAddressCtrl.text = c.address;
      }
    } else if (type == PartyType.dealer) {
      final d = db.dealers.where((dlr) => dlr.id == partyId).firstOrNull;
      if (d != null) {
        _contactPersonCtrl.text = d.contactPerson;
        _mobileCtrl.text = d.mobile;
        _emailCtrl.text = d.email;
        _gstNumberCtrl.text = d.gstNumber;
        _billingAddressCtrl.text = d.address;
        _shippingAddressCtrl.text = d.address;
      }
    } else if (type == PartyType.architect) {
      final a = db.architects.where((arc) => arc.id == partyId).firstOrNull;
      if (a != null) {
        _contactPersonCtrl.text = a.name;
        _mobileCtrl.text = a.mobile;
        _emailCtrl.text = a.email;
        _gstNumberCtrl.text = a.gstNumber;
        _billingAddressCtrl.text = a.address;
        _shippingAddressCtrl.text = a.address;
      }
    }
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

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.h2),
              ErpButton(
                text: 'Scan & Upload (OCR)',
                icon: Icons.document_scanner_outlined,
                isOutlined: true,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ocrCtx) => Dialog(
                      backgroundColor: Colors.transparent,
                      child: SizedBox(
                        width: 800,
                        height: 600,
                        child: DocumentOcrUploader(
                          docType: partyType == PartyType.customer
                              ? OcrDocType.customerDoc
                              : (partyType == PartyType.dealer ? OcrDocType.customerDoc : OcrDocType.architectDoc),
                          onCancel: () => Navigator.of(ocrCtx).pop(),
                          onConfirm: (data) {
                            nameCtrl.text = data['Customer Name'] ?? data['Company Name'] ?? data['Dealer Name'] ?? data['Architect Name'] ?? nameCtrl.text;
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
                              decoration: const InputDecoration(labelText: 'Registered Entity Name'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: contactPersonCtrl,
                              validator: (v) => Validators.requiredField(v, 'Contact person required'),
                              decoration: const InputDecoration(labelText: 'Contact Person *'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (partyType == PartyType.architect) ...[
                      TextFormField(
                        controller: companyCtrl,
                        decoration: const InputDecoration(labelText: 'Studio / Firm Name', hintText: 'E.g., Sanjay Puri Architects'),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: mobileCtrl,
                            validator: Validators.mobile,
                            decoration: const InputDecoration(labelText: 'Mobile Number *'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: emailCtrl,
                            validator: Validators.email,
                            decoration: const InputDecoration(labelText: 'Email Address'),
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
                            decoration: const InputDecoration(labelText: 'GST Number'),
                          ),
                        ),
                        if (partyType == PartyType.architect) ...[
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: commissionRateCtrl,
                              keyboardType: TextInputType.number,
                              validator: Validators.nonNegativeNumber,
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
                      decoration: InputDecoration(
                        labelText: partyType == PartyType.customer
                            ? 'Site / Billing Address'
                            : (partyType == PartyType.dealer ? 'Showroom / Business Address' : 'Studio / Office Address'),
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
              text: 'Save & Select',
              icon: Icons.check_circle_outline,
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(ctx).pop();

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
                  db.addCustomer(newCust);
                  setState(() {
                    _selectedPartyId = newCust.id;
                    _autoFillPartyDetails(newCust.id, PartyType.customer, db);
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
                  db.addDealer(newDealer);
                  setState(() {
                    _selectedPartyId = newDealer.id;
                    _autoFillPartyDetails(newDealer.id, PartyType.dealer, db);
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
                  db.addArchitect(newArch);
                  setState(() {
                    _selectedPartyId = newArch.id;
                    _autoFillPartyDetails(newArch.id, PartyType.architect, db);
                  });
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${partyType == PartyType.customer ? 'Customer' : partyType == PartyType.dealer ? 'Dealer' : 'Architect'} created and added to master successfully!'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _openQuickAddProjectDialog() {
    final db = ref.read(databaseServiceProvider);
    final nameCtrl = TextEditingController();
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
                            const DropdownMenuItem(value: null, child: Text('None (Direct Architect Specification)')),
                            ...db.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis))),
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
                      notes: notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                      createdAt: DateTime.now(),
                    );

                    db.addProject(newProj);
                    setState(() {
                      _selectedProjectId = newProj.id;
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Project created and added to Project Master successfully!'),
                        backgroundColor: AppColors.success,
                      ),
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

  void _addNewProductRow() {
    final db = ref.read(databaseServiceProvider);
    if (db.finishedProducts.isEmpty) return;
    final fp = db.finishedProducts.first;
    setState(() {
      _items.add(_QuotationItemDraft(
        finishedProductId: fp.id,
        finishedProductName: fp.name,
        finishedProductCode: fp.itemCode,
        productDescription: 'Standard specification luminaire',
        unit: fp.unit,
        quantity: 1.0,
        rate: _partyType == PartyType.customer ? fp.customerSellingPrice : fp.dealerSellingPrice,
        discount: 0.0,
        gstPercent: fp.gstPercent,
        availableStockSnapshot: fp.availableStock,
      ));
    });
  }

  void _duplicateRow(int index) {
    setState(() {
      _items.insert(index + 1, _items[index].copy());
    });
  }

  void _removeRow(int index) {
    if (_items.length > 1) {
      setState(() => _items.removeAt(index));
    }
  }

  double get _subtotalAmount => _items.fold(0.0, (sum, i) => sum + (i.quantity * i.rate));
  double get _totalDiscount => _items.fold(0.0, (sum, i) => sum + i.discount);
  double get _totalTaxable => (_subtotalAmount - _totalDiscount).clamp(0.0, double.infinity);
  double get _totalGst => _items.fold(0.0, (sum, i) => sum + i.gstAmount);
  double get _grandTotal => _totalTaxable + _totalGst;

  void _saveQuotation(bool isDraft) {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product row.'), backgroundColor: AppColors.danger),
      );
      return;
    }

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
    String? archId;
    if (_partyType == PartyType.architect) {
      final a = db.architects.where((arc) => arc.id == _selectedPartyId).firstOrNull;
      archName = a?.name;
      archId = a?.id;
    }

    // Generate quotation number (DLZ/QT/2026/0105 or DLZ/QT/2026/0103-R1)
    String quoteNumber;
    if (_isRevision && _sourceQuotation != null) {
      final base = _sourceQuotation!.invoiceNumber.split('-R')[0];
      quoteNumber = '$base-R$_revisionNumber';
    } else {
      quoteNumber = 'DLZ/QT/2026/${db.nextQuotationNumber.toString().padLeft(4, '0')}';
    }

    final lineItems = _items.map((i) {
      final cgst = _isInterStateTax ? 0.0 : (i.gstAmount / 2);
      final sgst = _isInterStateTax ? 0.0 : (i.gstAmount / 2);
      final igst = _isInterStateTax ? i.gstAmount : 0.0;

      return SaleLineItem(
        finishedProductId: i.finishedProductId,
        finishedProductName: i.finishedProductName,
        finishedProductCode: i.finishedProductCode,
        productDescription: i.productDescription,
        quantity: i.quantity,
        unit: i.unit,
        rate: i.rate,
        discountAmount: i.discount,
        gstPercent: i.gstPercent,
        taxableAmount: i.taxableAmount,
        cgstAmount: cgst,
        sgstAmount: sgst,
        igstAmount: igst,
        lineTotal: i.lineTotal,
      );
    }).toList();

    final quotation = Sale(
      id: IdGenerator.generateId('QT'),
      invoiceNumber: quoteNumber,
      documentType: SalesDocumentType.quotation,
      partyType: _partyType,
      partyId: _selectedPartyId ?? 'CUST-001',
      partyName: partyName,
      customerContactPerson: _contactPersonCtrl.text.trim(),
      customerMobile: _mobileCtrl.text.trim(),
      customerEmail: _emailCtrl.text.trim(),
      customerGstNumber: _gstNumberCtrl.text.trim(),
      billingAddress: _billingAddressCtrl.text.trim(),
      shippingAddress: _shippingAddressCtrl.text.trim(),
      projectId: _selectedProjectId,
      projectName: projName,
      architectId: archId,
      architectName: archName,
      salesExecutive: _salesExecutive,
      saleDate: _quotationDate,
      validUntil: _validTill,
      revisionNumber: _revisionNumber,
      originalQuotationId: _sourceQuotation?.originalQuotationId ?? _sourceQuotation?.id,
      parentQuotationId: _sourceQuotation?.id,
      parentQuotationNumber: _sourceQuotation?.invoiceNumber,
      quotationStatus: isDraft ? QuotationStatus.draft : QuotationStatus.sent,
      items: lineItems,
      subtotalAmount: _subtotalAmount,
      discountAmount: _totalDiscount,
      taxableAmount: _totalTaxable,
      cgstAmount: _isInterStateTax ? 0.0 : (_totalGst / 2),
      sgstAmount: _isInterStateTax ? 0.0 : (_totalGst / 2),
      igstAmount: _isInterStateTax ? _totalGst : 0.0,
      isInterStateTax: _isInterStateTax,
      gstAmount: _totalGst,
      totalAmount: _grandTotal,
      paidAmount: 0.0,
      pendingAmount: _grandTotal,
      paymentMode: PaymentMode.bankTransfer,
      status: SaleStatus.draft,
      termsAndConditions: _termsCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      createdAt: DateTime.now(),
      activityLogs: [
        DocumentActivityLog(
          id: IdGenerator.generateId('LOG'),
          action: _isRevision ? 'Revision Created ($quoteNumber)' : (isDraft ? 'Quotation Draft Saved' : 'Quotation Created & Sent'),
          performedBy: db.currentUser.name,
          timestamp: DateTime.now(),
          details: 'Physical and reserved stock unchanged per quotation rule.',
        ),
      ],
    );

    if (_isRevision && _sourceQuotation != null) {
      db.createQuotationRevision(_sourceQuotation!.id, quotation);
    } else {
      db.createQuotation(quotation);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isRevision
            ? 'Quotation Revision $quoteNumber created! Old version marked as Superseded.'
            : (isDraft ? 'Quotation Draft Saved ($quoteNumber)' : 'Quotation $quoteNumber Created and Sent to Client!')),
        backgroundColor: AppColors.success,
      ),
    );

    ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.quotations;
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
            // 1. Header & Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isRevision ? 'Create Quotation Revision (Rev $_revisionNumber)' : 'Create New Quotation', style: AppTextStyles.h1),
                    const SizedBox(height: 4),
                    Text(
                      _isRevision
                          ? 'Creating revision for ${_sourceQuotation?.invoiceNumber}. Old version will be superseded.'
                          : 'Commercial estimate with finished product lines (Zero stock impact until confirmed)',
                      style: AppTextStyles.subtitle,
                    ),
                  ],
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    ErpButton(
                      text: 'Cancel',
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.quotations,
                    ),
                    ErpButton(
                      text: 'Save as Draft',
                      isOutlined: true,
                      onPressed: () => _saveQuotation(true),
                    ),
                    ErpButton(
                      text: 'Save & Mark Sent',
                      icon: Icons.send_outlined,
                      onPressed: () => _saveQuotation(false),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 2. Customer & Project Selection Card
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
                  Text('Customer & Commercial Details', style: AppTextStyles.h3),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Expanded(
                              child: RadioListTile<PartyType>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Direct Customer'),
                                value: PartyType.customer,
                                groupValue: _partyType,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _partyType = val;
                                      _selectedProjectId = null;
                                      _selectedPartyId = db.customers.isNotEmpty ? db.customers.first.id : null;
                                      if (_selectedPartyId != null) {
                                        _autoFillPartyDetails(_selectedPartyId!, PartyType.customer, db);
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<PartyType>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Dealer Channel'),
                                value: PartyType.dealer,
                                groupValue: _partyType,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _partyType = val;
                                      _selectedProjectId = null;
                                      _selectedPartyId = db.dealers.isNotEmpty ? db.dealers.first.id : null;
                                      if (_selectedPartyId != null) {
                                        _autoFillPartyDetails(_selectedPartyId!, PartyType.dealer, db);
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<PartyType>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Architect'),
                                value: PartyType.architect,
                                groupValue: _partyType,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _partyType = val;
                                      _selectedPartyId = db.architects.isNotEmpty ? db.architects.first.id : null;
                                      if (_selectedPartyId != null) {
                                        _autoFillPartyDetails(_selectedPartyId!, PartyType.architect, db);
                                      }
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
                        flex: 2,
                        child: DropdownButtonFormField<String>(
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
                          items: [
                            DropdownMenuItem<String>(
                              value: '__ADD_NEW__',
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
                            const DropdownMenuItem<String>(
                              enabled: false,
                              value: '__DIVIDER__',
                              child: Divider(height: 1),
                            ),
                            if (_partyType == PartyType.customer)
                              ...db.customers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis)))
                            else if (_partyType == PartyType.dealer)
                              ...db.dealers.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis)))
                            else
                              ...db.architects.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} (${a.companyName})', maxLines: 1, overflow: TextOverflow.ellipsis))),
                          ],
                          onChanged: (val) {
                            if (val == '__ADD_NEW__') {
                              _openQuickAddPartyDialog(_partyType);
                              return;
                            }
                            if (val == '__DIVIDER__') return;
                            setState(() {
                              _selectedPartyId = val;
                              if (val != null) {
                                _autoFillPartyDetails(val, _partyType, db);
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Customer Autofill Fields Grid
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _contactPersonCtrl,
                          decoration: const InputDecoration(labelText: 'Contact Person'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _mobileCtrl,
                          decoration: const InputDecoration(labelText: 'Mobile Number'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email Address'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _gstNumberCtrl,
                          decoration: const InputDecoration(labelText: 'Client GST Number'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _billingAddressCtrl,
                          decoration: const InputDecoration(labelText: 'Billing Address'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _shippingAddressCtrl,
                          decoration: const InputDecoration(labelText: 'Shipping / Site Address'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Project & Validity Row
                  Row(
                    children: [
                      if (_partyType == PartyType.architect) ...[
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            value: (_selectedProjectId != null && db.projects.any((p) => p.id == _selectedProjectId))
                                ? _selectedProjectId
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Linked Project (Optional)'),
                            items: [
                              DropdownMenuItem<String?>(
                                value: '__ADD_PROJECT__',
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
                              const DropdownMenuItem<String?>(
                                enabled: false,
                                value: '__DIVIDER_PROJECT__',
                                child: Divider(height: 1),
                              ),
                              const DropdownMenuItem<String?>(value: null, child: Text('None (Direct Site)')),
                              ...db.projects.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis))),
                            ],
                            onChanged: (val) {
                              if (val == '__ADD_PROJECT__') {
                                _openQuickAddProjectDialog();
                                return;
                              }
                              if (val == '__DIVIDER_PROJECT__') return;
                              setState(() => _selectedProjectId = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Valid Till',
                            suffixIcon: const Icon(Icons.calendar_today, size: 18),
                            hintText: Formatters.formatDate(_validTill),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _validTill,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 180)),
                            );
                            if (picked != null) setState(() => _validTill = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Product Line Items Card
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
                          Text('Product Line Items', style: AppTextStyles.h3),
                          const SizedBox(height: 2),
                          Text('Product data is loaded from Finished Product Masters. Stock is NOT reduced at quotation.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                        ],
                      ),
                      ErpButton(
                        text: 'Add Product Row',
                        icon: Icons.add,
                        isOutlined: true,
                        onPressed: _addNewProductRow,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Line Items List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const Divider(height: 24),
                    itemBuilder: (ctx, idx) {
                      final item = _items[idx];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor: AppColors.primaryLight,
                                  child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                ),
                                const SizedBox(width: 12),
                                // Product Picker
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    value: db.finishedProducts.any((p) => p.id == item.finishedProductId)
                                        ? item.finishedProductId
                                        : (db.finishedProducts.isNotEmpty ? db.finishedProducts.first.id : null),
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Finished Product *'),
                                    items: db.finishedProducts.map((fp) {
                                      return DropdownMenuItem(
                                        value: fp.id,
                                        child: Text('${fp.name} (${fp.itemCode}) - Avail: ${fp.availableStock} ${fp.unit}'),
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
                                          item.availableStockSnapshot = fp.availableStock;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Quantity
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    initialValue: item.quantity.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(labelText: 'Quantity (${item.unit})'),
                                    onChanged: (val) => setState(() => item.quantity = double.tryParse(val) ?? 1.0),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Unit Price / Rate
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    initialValue: item.rate.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Unit Rate (₹)'),
                                    onChanged: (val) => setState(() => item.rate = double.tryParse(val) ?? 0.0),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Discount
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    initialValue: item.discount.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Discount (₹)'),
                                    onChanged: (val) => setState(() => item.discount = double.tryParse(val) ?? 0.0),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // GST %
                                Expanded(
                                  flex: 1,
                                  child: TextFormField(
                                    initialValue: item.gstPercent.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'GST %'),
                                    onChanged: (val) => setState(() => item.gstPercent = double.tryParse(val) ?? 18.0),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Line Total & Action Buttons
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('Line Total', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                                    Text(Formatters.formatCurrency(item.lineTotal), style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
                                  tooltip: 'Duplicate Row',
                                  onPressed: () => _duplicateRow(idx),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                                  tooltip: 'Remove Row',
                                  onPressed: () => _removeRow(idx),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: item.productDescription,
                              decoration: const InputDecoration(
                                labelText: 'Product Description / Custom Specifications for Quote PDF',
                                isDense: true,
                              ),
                              onChanged: (val) => item.productDescription = val,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Totals & Terms Card
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Terms and Notes
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
                        Text('Terms & Conditions & Commercial Notes', style: AppTextStyles.h3),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _termsCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: 'Terms & Conditions (Printed on PDF)'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _notesCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Internal Sales Notes'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                // Right: Financial Summary Box
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Quotation Totals', style: AppTextStyles.h3),
                            ChoiceChip(
                              label: Text(_isInterStateTax ? 'Inter-State (IGST 18%)' : 'Intra-State (CGST+SGST)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              selected: _isInterStateTax,
                              selectedColor: Colors.purple.withOpacity(0.15),
                              onSelected: (val) => setState(() => _isInterStateTax = val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildSummaryRow('Subtotal Amount', Formatters.formatCurrency(_subtotalAmount)),
                        if (_totalDiscount > 0)
                          _buildSummaryRow('Total Discount', '- ${Formatters.formatCurrency(_totalDiscount)}', color: AppColors.dangerText),
                        _buildSummaryRow('Taxable Amount', Formatters.formatCurrency(_totalTaxable)),
                        if (!_isInterStateTax) ...[
                          _buildSummaryRow('CGST (9%)', Formatters.formatCurrency(_totalGst / 2)),
                          _buildSummaryRow('SGST (9%)', Formatters.formatCurrency(_totalGst / 2)),
                        ] else ...[
                          _buildSummaryRow('IGST (18%)', Formatters.formatCurrency(_totalGst), color: Colors.purple),
                        ],
                        const Divider(height: 20),
                        _buildSummaryRow('Grand Total', Formatters.formatCurrency(_grandTotal), isBold: true, fontSize: 16, color: AppColors.primary),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.info.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: AppColors.info, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Quotation rule active: Physical & reserved inventory remain untouched until order confirmation.',
                                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.info),
                                ),
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

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: Colors.grey.shade700)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color ?? Colors.black87)),
        ],
      ),
    );
  }
}
