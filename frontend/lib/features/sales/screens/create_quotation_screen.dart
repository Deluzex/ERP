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
import '../../../core/models/finished_product_model.dart';
import '../../../core/models/project_model.dart';
import '../../../core/models/purchase_model.dart';
import '../../../core/models/raw_material_model.dart';
import '../../../core/models/sale_model.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/erp_section_header_card.dart';
import '../../../core/widgets/document_ocr_uploader.dart';
import '../../../core/widgets/erp_button.dart';
import '../../../shared/providers/app_state_providers.dart';
import '../../../shared/services/mock_database_service.dart';

class _QuotationItemDraft {
  PurchaseItemType itemType;
  String itemId;
  String itemName;
  String itemCode;
  String productDescription;
  String unit;
  double quantity;
  double rate;
  double discount;
  double gstPercent;
  double availableStockSnapshot;

  _QuotationItemDraft({
    this.itemType = PurchaseItemType.finishedProduct,
    required this.itemId,
    required this.itemName,
    required this.itemCode,
    this.productDescription = '',
    required this.unit,
    this.quantity = 1.0,
    this.rate = 1000.0,
    this.discount = 0.0,
    this.gstPercent = 18.0,
    this.availableStockSnapshot = 0.0,
  });

  String get finishedProductId => itemType == PurchaseItemType.finishedProduct ? itemId : '';
  set finishedProductId(String val) {
    if (itemType == PurchaseItemType.finishedProduct) itemId = val;
  }

  String get finishedProductName => itemType == PurchaseItemType.finishedProduct ? itemName : '';
  set finishedProductName(String val) {
    if (itemType == PurchaseItemType.finishedProduct) itemName = val;
  }

  String get finishedProductCode => itemType == PurchaseItemType.finishedProduct ? itemCode : '';
  set finishedProductCode(String val) {
    if (itemType == PurchaseItemType.finishedProduct) itemCode = val;
  }

  String? get rawMaterialId => itemType == PurchaseItemType.rawMaterial ? itemId : null;
  String? get rawMaterialName => itemType == PurchaseItemType.rawMaterial ? itemName : null;
  String? get rawMaterialCode => itemType == PurchaseItemType.rawMaterial ? itemCode : null;

  double get taxableAmount => ((quantity * rate) - discount).clamp(0.0, double.infinity);
  double get gstAmount => taxableAmount * (gstPercent / 100.0);
  double get lineTotal => taxableAmount + gstAmount;

  _QuotationItemDraft copy() {
    return _QuotationItemDraft(
      itemType: itemType,
      itemId: itemId,
      itemName: itemName,
      itemCode: itemCode,
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

String _generateFpDescription(FinishedProduct fp) {
  final buffer = StringBuffer(fp.name);
  if (fp.itemCode.isNotEmpty) buffer.write(' (${fp.itemCode})');
  if (fp.categoryName.isNotEmpty) buffer.write(' — Category: ${fp.categoryName}');
  if (fp.hsnSacCode != null && fp.hsnSacCode!.isNotEmpty) buffer.write(' | HSN: ${fp.hsnSacCode}');
  buffer.write(' | Unit: ${fp.unit}');
  return buffer.toString();
}

String _generateRmDescription(RawMaterial rm) {
  final buffer = StringBuffer(rm.name);
  if (rm.itemCode.isNotEmpty) buffer.write(' (${rm.itemCode})');
  if (rm.categoryName.isNotEmpty) buffer.write(' — Category: ${rm.categoryName}');
  if (rm.hsnSacCode != null && rm.hsnSacCode!.isNotEmpty) buffer.write(' | HSN: ${rm.hsnSacCode}');
  buffer.write(' | Unit: ${rm.unit}');
  return buffer.toString();
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
  bool _isSubmitting = false;
  int _revisionNumber = 0;

  @override
  void initState() {
    super.initState();
    final db = ref.read(databaseServiceProvider);
    final sourceId = ref.read(salesCreateSourceDocIdProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      db.loadRawMaterials();
      db.loadFinishedProducts();
      db.loadCustomers();
      db.loadDealers();
      db.loadArchitects();
      db.loadProjects();
    });

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
          final isRm = item.itemType == PurchaseItemType.rawMaterial;
          final id = isRm ? (item.rawMaterialId ?? item.finishedProductId) : item.finishedProductId;
          final name = isRm ? (item.rawMaterialName ?? item.finishedProductName) : item.finishedProductName;
          final code = isRm ? (item.rawMaterialCode ?? item.finishedProductCode) : item.finishedProductCode;
          double stock = 0.0;
          if (isRm) {
            final rm = db.rawMaterials.where((m) => m.id == id).firstOrNull;
            stock = rm?.currentStock ?? 0.0;
          } else {
            final fp = db.finishedProducts.where((p) => p.id == id).firstOrNull;
            stock = fp?.availableStock ?? 0.0;
          }

          _items.add(_QuotationItemDraft(
            itemType: item.itemType,
            itemId: id,
            itemName: name,
            itemCode: code,
            productDescription: item.productDescription,
            unit: item.unit,
            quantity: item.quantity,
            rate: item.rate,
            discount: item.discountAmount,
            gstPercent: item.gstPercent,
            availableStockSnapshot: stock,
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
          itemType: PurchaseItemType.finishedProduct,
          itemId: fp.id,
          itemName: fp.name,
          itemCode: fp.itemCode,
          productDescription: _generateFpDescription(fp),
          unit: fp.unit,
          quantity: 10.0,
          rate: fp.customerSellingPrice,
          discount: 0.0,
          gstPercent: fp.gstPercent,
          availableStockSnapshot: fp.availableStock,
        ));
      } else if (db.rawMaterials.isNotEmpty) {
        final rm = db.rawMaterials.first;
        _items.add(_QuotationItemDraft(
          itemType: PurchaseItemType.rawMaterial,
          itemId: rm.id,
          itemName: rm.name,
          itemCode: rm.itemCode,
          productDescription: _generateRmDescription(rm),
          unit: rm.unit,
          quantity: 10.0,
          rate: rm.defaultPurchasePrice,
          discount: 0.0,
          gstPercent: rm.gstPercent,
          availableStockSnapshot: rm.currentStock,
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
                onPressed: () {
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
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                Navigator.of(ctx).pop();

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
                      _autoFillPartyDetails(saved.id, PartyType.customer, db);
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
                      _autoFillPartyDetails(saved.id, PartyType.dealer, db);
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
                      _autoFillPartyDetails(saved.id, PartyType.architect, db);
                    });
                  }

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${partyType == PartyType.customer ? 'Customer' : partyType == PartyType.dealer ? 'Dealer' : 'Architect'} created and added to master successfully!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to save: $e'), backgroundColor: AppColors.danger),
                  );
                }
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
    if (db.finishedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Finished Products available in master.'), backgroundColor: AppColors.warning),
      );
      return;
    }
    final fp = db.finishedProducts.first;
    setState(() {
      _items.add(_QuotationItemDraft(
        itemType: PurchaseItemType.finishedProduct,
        itemId: fp.id,
        itemName: fp.name,
        itemCode: fp.itemCode,
        productDescription: _generateFpDescription(fp),
        unit: fp.unit,
        quantity: 1.0,
        rate: _partyType == PartyType.customer ? fp.customerSellingPrice : fp.dealerSellingPrice,
        discount: 0.0,
        gstPercent: fp.gstPercent,
        availableStockSnapshot: fp.availableStock,
      ));
    });
  }

  void _addNewRawMaterialRow() {
    final db = ref.read(databaseServiceProvider);
    if (db.rawMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Raw Materials available in master.'), backgroundColor: AppColors.warning),
      );
      return;
    }
    final rm = db.rawMaterials.first;
    setState(() {
      _items.add(_QuotationItemDraft(
        itemType: PurchaseItemType.rawMaterial,
        itemId: rm.id,
        itemName: rm.name,
        itemCode: rm.itemCode,
        productDescription: _generateRmDescription(rm),
        unit: rm.unit,
        quantity: 1.0,
        rate: rm.defaultPurchasePrice,
        discount: 0.0,
        gstPercent: rm.gstPercent,
        availableStockSnapshot: rm.currentStock,
      ));
    });
  }

  void _duplicateRow(int index) {
    if (index >= 0 && index < _items.length) {
      setState(() {
        _items.insert(index + 1, _items[index].copy());
      });
    }
  }

  void _removeRow(int index) {
    if (_items.length > 1) {
      setState(() => _items.removeAt(index));
    }
  }

  Widget _buildItemActionButton({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color backgroundColor,
    required Color borderColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: iconColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double get _subtotalAmount => _items.fold(0.0, (sum, i) => sum + (i.quantity * i.rate));
  double get _totalDiscount => _items.fold(0.0, (sum, i) => sum + i.discount);
  double get _totalTaxable => _items.fold(0.0, (sum, i) => sum + i.taxableAmount);
  double get _totalGst => _items.fold(0.0, (sum, i) => sum + i.gstAmount);
  double get _grandTotal => _totalTaxable + _totalGst;

  Future<void> _saveQuotation(bool isDraft) async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item row.'), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

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
        itemType: i.itemType,
        rawMaterialId: i.itemType == PurchaseItemType.rawMaterial ? i.itemId : null,
        rawMaterialName: i.itemType == PurchaseItemType.rawMaterial ? i.itemName : null,
        rawMaterialCode: i.itemType == PurchaseItemType.rawMaterial ? i.itemCode : null,
        finishedProductId: i.itemType == PurchaseItemType.finishedProduct ? i.itemId : '',
        finishedProductName: i.itemType == PurchaseItemType.finishedProduct ? i.itemName : '',
        finishedProductCode: i.itemType == PurchaseItemType.finishedProduct ? i.itemCode : '',
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

    try {
      if (_isRevision && _sourceQuotation != null) {
        await db.createQuotationRevisionAsync(_sourceQuotation!.id, quotation);
      } else {
        await db.createQuotationAsync(quotation);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isRevision
              ? 'Quotation Revision $quoteNumber created! Old version marked as Superseded.'
              : (isDraft ? 'Quotation Draft Saved ($quoteNumber)' : 'Quotation $quoteNumber Created and Sent to Client!')),
          backgroundColor: AppColors.success,
        ),
      );

      ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.quotations;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save quotation: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
            // Responsive Page Header Card
            ErpSectionHeaderCard(
              icon: Icons.request_quote_outlined,
              title: _isRevision ? 'Create Quotation Revision (Rev $_revisionNumber)' : 'Create New Quotation',
              badgeText: _isRevision ? 'REVISION' : 'NEW QUOTATION',
              subtitle: _isRevision
                  ? 'Creating revision for ${_sourceQuotation?.invoiceNumber}. Old version will be superseded.'
                  : 'Commercial estimate with finished goods or raw materials (Zero stock impact until confirmed)',
              action: LayoutBuilder(
                builder: (context, actionBox) {
                  final isMobile = actionBox.maxWidth < 600;
                  if (isMobile) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ErpButton(
                            text: 'Save & Mark Sent',
                            icon: Icons.send_outlined,
                            onPressed: () => _saveQuotation(false),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ErpButton(
                            text: 'Save as Draft',
                            isOutlined: true,
                            onPressed: () => _saveQuotation(true),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ErpButton(
                            text: 'Cancel',
                            isOutlined: true,
                            onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.quotations,
                          ),
                        ),
                      ],
                    );
                  }
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ErpButton(
                        text: 'Cancel',
                        isOutlined: true,
                        onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.quotations,
                      ),
                      const SizedBox(width: 8),
                      ErpButton(
                        text: 'Save as Draft',
                        isOutlined: true,
                        onPressed: () => _saveQuotation(true),
                      ),
                      const SizedBox(width: 8),
                      ErpButton(
                        text: 'Save & Mark Sent',
                        icon: Icons.send_outlined,
                        onPressed: () => _saveQuotation(false),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // 1. Client / Party Selection Card
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person_pin_outlined, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Customer & Party Information', style: AppTextStyles.h3),
                            const SizedBox(height: 2),
                            Text(
                              'Select target client or dealer to auto-fill commercial terms & GST parameters',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  LayoutBuilder(
                    builder: (context, partyConstraints) {
                      final isNarrow = partyConstraints.maxWidth < 650;
                      final partyTypeField = DropdownButtonFormField<PartyType>(
                        value: _partyType,
                        decoration: const InputDecoration(labelText: 'Party Category *'),
                        items: const [
                          DropdownMenuItem(value: PartyType.customer, child: Text('End Customer / Client')),
                          DropdownMenuItem(value: PartyType.dealer, child: Text('Authorized Dealer / Distributor')),
                          DropdownMenuItem(value: PartyType.architect, child: Text('Architect / Specifier')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _partyType = val;
                              _selectedPartyId = null;
                            });
                          }
                        },
                      );

                      final partyPicker = Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedPartyId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: _partyType == PartyType.customer
                                    ? 'Select Customer *'
                                    : (_partyType == PartyType.dealer ? 'Select Dealer *' : 'Select Architect *'),
                              ),
                              items: _partyType == PartyType.customer
                                  ? db.customers.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.mobile})', maxLines: 1, overflow: TextOverflow.ellipsis))).toList()
                                  : (_partyType == PartyType.dealer
                                      ? db.dealers.map((d) => DropdownMenuItem(value: d.id, child: Text('${d.name} (${d.mobile})', maxLines: 1, overflow: TextOverflow.ellipsis))).toList()
                                      : db.architects.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.name} - ${a.companyName}', maxLines: 1, overflow: TextOverflow.ellipsis))).toList()),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedPartyId = val;
                                    _autoFillPartyDetails(val, _partyType, db);
                                  });
                                }
                              },
                              validator: (val) => val == null ? 'Please select a party' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Quick Add ${_partyType.name.toUpperCase()}',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _openQuickAddPartyDialog(_partyType),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Icons.person_add_alt_1, size: 20, color: AppColors.primary),
                              ),
                            ),
                          ),
                        ],
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            partyTypeField,
                            const SizedBox(height: 12),
                            partyPicker,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 2, child: partyTypeField),
                          const SizedBox(width: 16),
                          Expanded(flex: 3, child: partyPicker),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Auto-filled details in 3 responsive columns
                  LayoutBuilder(
                    builder: (context, fieldBox) {
                      final isNarrow = fieldBox.maxWidth < 700;
                      final contactField = TextFormField(
                        controller: _contactPersonCtrl,
                        decoration: const InputDecoration(labelText: 'Contact Person Name'),
                      );
                      final mobileField = TextFormField(
                        controller: _mobileCtrl,
                        decoration: const InputDecoration(labelText: 'Mobile / Phone Number'),
                      );
                      final emailField = TextFormField(
                        controller: _emailCtrl,
                        decoration: const InputDecoration(labelText: 'Email Address'),
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            contactField,
                            const SizedBox(height: 12),
                            mobileField,
                            const SizedBox(height: 12),
                            emailField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: contactField),
                          const SizedBox(width: 12),
                          Expanded(child: mobileField),
                          const SizedBox(width: 12),
                          Expanded(child: emailField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  LayoutBuilder(
                    builder: (context, addrBox) {
                      final isNarrow = addrBox.maxWidth < 700;
                      final gstField = TextFormField(
                        controller: _gstNumberCtrl,
                        decoration: const InputDecoration(labelText: 'GSTIN Number (Auto-verified)'),
                      );
                      final billingField = TextFormField(
                        controller: _billingAddressCtrl,
                        decoration: const InputDecoration(labelText: 'Billing Address'),
                      );
                      final shippingField = TextFormField(
                        controller: _shippingAddressCtrl,
                        decoration: const InputDecoration(labelText: 'Shipping / Site Delivery Address'),
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            gstField,
                            const SizedBox(height: 12),
                            billingField,
                            const SizedBox(height: 12),
                            shippingField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 1, child: gstField),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: billingField),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: shippingField),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Project Linking & Quotation Header Details Card
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
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.assignment_outlined, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Project Association & Quotation Terms', style: AppTextStyles.h3),
                            const SizedBox(height: 2),
                            Text(
                              'Tag to ongoing project or site, assign owner, and set proposal validity',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  LayoutBuilder(
                    builder: (context, projBox) {
                      final isNarrow = projBox.maxWidth < 650;
                      final projectPicker = Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedProjectId,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Linked Project (Optional)'),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('No Project / Direct Quotation')),
                                ...db.projects.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.projectCode})', maxLines: 1, overflow: TextOverflow.ellipsis))),
                              ],
                              onChanged: (val) => setState(() => _selectedProjectId = val),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Quick Add Project',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: _openQuickAddProjectDialog,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Icons.create_new_folder_outlined, size: 20, color: AppColors.primary),
                              ),
                            ),
                          ),
                        ],
                      );

                      final salesExecField = TextFormField(
                        initialValue: _salesExecutive,
                        decoration: const InputDecoration(labelText: 'Assigned Sales Executive *'),
                        onChanged: (v) => _salesExecutive = v,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            projectPicker,
                            const SizedBox(height: 12),
                            salesExecField,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(flex: 3, child: projectPicker),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: salesExecField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Quotation Date',
                            suffixIcon: const Icon(Icons.calendar_month, size: 18),
                            hintText: Formatters.formatDate(_quotationDate),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _quotationDate,
                              firstDate: DateTime.now().subtract(const Duration(days: 30)),
                              lastDate: DateTime.now().add(const Duration(days: 90)),
                            );
                            if (picked != null) setState(() => _quotationDate = picked);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
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

            // 3. Product & Raw Material Line Items Card
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
                      final isNarrow = constraints.maxWidth < 750;
                      final headerText = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Quotation Line Items', style: AppTextStyles.h3),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${_items.length} ${_items.length == 1 ? 'Item' : 'Items'}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add Finished Goods or Raw Materials. Zero physical or reserved stock impact until order confirmation.',
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                          ),
                        ],
                      );

                      final buttons = Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          ErpButton(
                            text: 'Add Finished Good',
                            icon: Icons.inventory_2_outlined,
                            isOutlined: true,
                            onPressed: _addNewProductRow,
                          ),
                          ErpButton(
                            text: 'Add Raw Material',
                            icon: Icons.grain,
                            isOutlined: true,
                            onPressed: _addNewRawMaterialRow,
                          ),
                        ],
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            headerText,
                            const SizedBox(height: 12),
                            buttons,
                          ],
                        );
                      }
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: headerText),
                          const SizedBox(width: 12),
                          buttons,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Line Items List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    itemBuilder: (ctx, idx) {
                      final item = _items[idx];
                      final isRm = item.itemType == PurchaseItemType.rawMaterial;
                      final typeColor = isRm ? Colors.amber.shade800 : Colors.teal.shade700;
                      final typeBgColor = isRm ? Colors.amber.withValues(alpha: 0.1) : Colors.teal.withValues(alpha: 0.1);

                      return Container(
                        key: ValueKey('item_card_${idx}_${item.itemId}_${item.itemType.name}'),
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x05000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, itemConstraints) {
                            final isItemNarrow = itemConstraints.maxWidth < 800;

                            // Item Type Dropdown Selector
                            final typeSelector = Container(
                              height: 32,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: typeBgColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: typeColor.withValues(alpha: 0.4)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<PurchaseItemType>(
                                  value: item.itemType,
                                  isDense: true,
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: typeColor),
                                  icon: Icon(Icons.arrow_drop_down, size: 16, color: typeColor),
                                  items: [
                                    DropdownMenuItem(
                                      value: PurchaseItemType.finishedProduct,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.inventory_2_outlined, size: 14, color: Colors.teal.shade700),
                                          const SizedBox(width: 4),
                                          Text('Fin Good', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade700)),
                                        ],
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: PurchaseItemType.rawMaterial,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.grain, size: 14, color: Colors.amber.shade800),
                                          const SizedBox(width: 4),
                                          Text('Raw Mat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
                                        ],
                                      ),
                                    ),
                                  ],
                                  onChanged: (newType) {
                                    if (newType == null || newType == item.itemType) return;
                                    if (newType == PurchaseItemType.rawMaterial) {
                                      if (db.rawMaterials.isNotEmpty) {
                                        final rm = db.rawMaterials.first;
                                        setState(() {
                                          item.itemType = newType;
                                          item.itemId = rm.id;
                                          item.itemName = rm.name;
                                          item.itemCode = rm.itemCode;
                                          item.unit = rm.unit;
                                          item.rate = rm.defaultPurchasePrice;
                                          item.discount = 0.0;
                                          item.gstPercent = rm.gstPercent;
                                          item.availableStockSnapshot = rm.currentStock;
                                          item.productDescription = _generateRmDescription(rm);
                                        });
                                      }
                                    } else {
                                      if (db.finishedProducts.isNotEmpty) {
                                        final fp = db.finishedProducts.first;
                                        setState(() {
                                          item.itemType = newType;
                                          item.itemId = fp.id;
                                          item.itemName = fp.name;
                                          item.itemCode = fp.itemCode;
                                          item.unit = fp.unit;
                                          item.rate = _partyType == PartyType.customer ? fp.customerSellingPrice : fp.dealerSellingPrice;
                                          item.discount = 0.0;
                                          item.gstPercent = fp.gstPercent;
                                          item.availableStockSnapshot = fp.availableStock;
                                          item.productDescription = _generateFpDescription(fp);
                                        });
                                      }
                                    }
                                  },
                                ),
                              ),
                            );

                            final itemPicker = isRm
                                ? DropdownButtonFormField<String>(
                                    key: ValueKey('rm_picker_${item.itemId}_${item.itemType.name}'),
                                    value: db.rawMaterials.any((m) => m.id == item.itemId)
                                        ? item.itemId
                                        : (db.rawMaterials.isNotEmpty ? db.rawMaterials.first.id : null),
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Raw Material *',
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    items: db.rawMaterials.map((rm) {
                                      return DropdownMenuItem(
                                        value: rm.id,
                                        child: Text(
                                          '${rm.name} (${rm.itemCode}) - Stock: ${rm.currentStock} ${rm.unit}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        final rm = db.rawMaterials.firstWhere((m) => m.id == val);
                                        setState(() {
                                          item.itemId = rm.id;
                                          item.itemName = rm.name;
                                          item.itemCode = rm.itemCode;
                                          item.unit = rm.unit;
                                          item.rate = rm.defaultPurchasePrice;
                                          item.gstPercent = rm.gstPercent;
                                          item.availableStockSnapshot = rm.currentStock;
                                          item.productDescription = _generateRmDescription(rm);
                                        });
                                      }
                                    },
                                  )
                                : DropdownButtonFormField<String>(
                                    key: ValueKey('fp_picker_${item.itemId}_${item.itemType.name}'),
                                    value: db.finishedProducts.any((p) => p.id == item.itemId)
                                        ? item.itemId
                                        : (db.finishedProducts.isNotEmpty ? db.finishedProducts.first.id : null),
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Finished Product *',
                                      filled: true,
                                      fillColor: Colors.white,
                                    ),
                                    items: db.finishedProducts.map((fp) {
                                      return DropdownMenuItem(
                                        value: fp.id,
                                        child: Text(
                                          '${fp.name} (${fp.itemCode}) - Avail: ${fp.availableStock} ${fp.unit}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        final fp = db.finishedProducts.firstWhere((p) => p.id == val);
                                        setState(() {
                                          item.itemId = fp.id;
                                          item.itemName = fp.name;
                                          item.itemCode = fp.itemCode;
                                          item.unit = fp.unit;
                                          item.rate = _partyType == PartyType.customer ? fp.customerSellingPrice : fp.dealerSellingPrice;
                                          item.gstPercent = fp.gstPercent;
                                          item.availableStockSnapshot = fp.availableStock;
                                          item.productDescription = _generateFpDescription(fp);
                                        });
                                      }
                                    },
                                  );

                            final qtyField = TextFormField(
                              initialValue: item.quantity.toString(),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantity (${item.unit})',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onChanged: (val) => setState(() => item.quantity = double.tryParse(val) ?? 1.0),
                            );

                            final rateField = TextFormField(
                              initialValue: item.rate.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Unit Rate (₹)',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onChanged: (val) => setState(() => item.rate = double.tryParse(val) ?? 0.0),
                            );

                            final discountField = TextFormField(
                              initialValue: item.discount.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Discount (₹)',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onChanged: (val) => setState(() => item.discount = double.tryParse(val) ?? 0.0),
                            );

                            final gstField = TextFormField(
                              initialValue: item.gstPercent.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'GST %',
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onChanged: (val) => setState(() => item.gstPercent = double.tryParse(val) ?? 18.0),
                            );

                            final isMobileItemHeader = itemConstraints.maxWidth < 580;
                            final isExtraSmall = itemConstraints.maxWidth < 420;

                            final itemHeader = isMobileItemHeader
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primarySoft,
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                                            ),
                                            child: Text(
                                              'ITEM #${idx + 1}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.primaryDark,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          typeSelector,
                                          if (item.itemCode.isNotEmpty && !isExtraSmall) ...[
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item.itemCode,
                                                  style: const TextStyle(fontSize: 10, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              _buildItemActionButton(
                                                icon: Icons.copy_outlined,
                                                label: isExtraSmall ? '' : 'Copy',
                                                iconColor: const Color(0xFF475569),
                                                backgroundColor: const Color(0xFFF1F5F9),
                                                borderColor: const Color(0xFFCBD5E1),
                                                onTap: () => _duplicateRow(idx),
                                              ),
                                              const SizedBox(width: 6),
                                              _buildItemActionButton(
                                                icon: Icons.delete_outline,
                                                label: isExtraSmall ? '' : 'Delete',
                                                iconColor: AppColors.danger,
                                                backgroundColor: const Color(0xFFFEF2F2),
                                                borderColor: const Color(0xFFFECACA),
                                                onTap: () => _removeRow(idx),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFE2E8F0)),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Line Total: ',
                                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, fontWeight: FontWeight.w500),
                                            ),
                                            Text(
                                              Formatters.formatCurrency(item.lineTotal),
                                              style: AppTextStyles.bodyBold.copyWith(fontSize: 14, color: AppColors.primaryDark),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySoft,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
                                        ),
                                        child: Text(
                                          'ITEM #${idx + 1}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primaryDark,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      typeSelector,
                                      if (item.itemCode.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.itemCode,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text('Line Total: ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                                          Text(
                                            Formatters.formatCurrency(item.lineTotal),
                                            style: AppTextStyles.bodyBold.copyWith(fontSize: 14, color: AppColors.primaryDark),
                                          ),
                                          const SizedBox(width: 12),
                                          _buildItemActionButton(
                                            icon: Icons.copy_outlined,
                                            label: 'Copy',
                                            iconColor: const Color(0xFF475569),
                                            backgroundColor: const Color(0xFFF1F5F9),
                                            borderColor: const Color(0xFFCBD5E1),
                                            onTap: () => _duplicateRow(idx),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildItemActionButton(
                                            icon: Icons.delete_outline,
                                            label: 'Delete',
                                            iconColor: AppColors.danger,
                                            backgroundColor: const Color(0xFFFEF2F2),
                                            borderColor: const Color(0xFFFECACA),
                                            onTap: () => _removeRow(idx),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );

                            final productDescriptionBox = Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x04000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.description_outlined, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      const Expanded(
                                        child: Text(
                                          'Item Description & Custom Specifications',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.primaryDark,
                                            letterSpacing: 0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySoft,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                        ),
                                        child: const Text(
                                          'PRINTS ON PDF',
                                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    initialValue: item.productDescription,
                                    maxLines: 2,
                                    minLines: 1,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'Enter custom product specifications, technical details, color temp, or client notes...',
                                      hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                    ),
                                    onChanged: (val) => item.productDescription = val,
                                  ),
                                ],
                              ),
                            );

                            final boxesArea = Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9), // Single clean soft grey area
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: isItemNarrow
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        itemPicker,
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(child: qtyField),
                                            const SizedBox(width: 8),
                                            Expanded(child: rateField),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(child: discountField),
                                            const SizedBox(width: 8),
                                            Expanded(child: gstField),
                                          ],
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(flex: 3, child: itemPicker),
                                        const SizedBox(width: 10),
                                        Expanded(flex: 1, child: qtyField),
                                        const SizedBox(width: 10),
                                        Expanded(flex: 1, child: rateField),
                                        const SizedBox(width: 10),
                                        Expanded(flex: 1, child: discountField),
                                        const SizedBox(width: 10),
                                        Expanded(flex: 1, child: gstField),
                                      ],
                                    ),
                            );

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                itemHeader,
                                boxesArea,
                                productDescriptionBox,
                              ],
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Totals & Terms Card
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
                    builder: (context, termsBox) {
                      final isNarrow = termsBox.maxWidth < 800;

                      final termsAndNotesArea = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Terms & Conditions & Commercial Notes', style: AppTextStyles.h3),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _termsCtrl,
                            maxLines: 4,
                            minLines: 3,
                            decoration: const InputDecoration(labelText: 'Terms & Conditions (Printed on PDF)'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _notesCtrl,
                            maxLines: 2,
                            minLines: 2,
                            decoration: const InputDecoration(labelText: 'Internal Sales Notes'),
                          ),
                        ],
                      );

                      final financialSummary = Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x06000000),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, headerBox) {
                                final isHeaderNarrow = headerBox.maxWidth < 360;
                                final title = Text(
                                  'Financial Summary',
                                  style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                                final taxToggle = Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () => setState(() => _isInterStateTax = !_isInterStateTax),
                                    borderRadius: BorderRadius.circular(20),
                                    splashColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    hoverColor: AppColors.primarySoft.withValues(alpha: 0.4),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 250),
                                      curve: Curves.easeInOut,
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _isInterStateTax ? AppColors.primarySoft : Colors.white,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: _isInterStateTax ? AppColors.primary : AppColors.border,
                                          width: 1.0,
                                        ),
                                        boxShadow: _isInterStateTax
                                            ? [
                                                BoxShadow(
                                                  color: AppColors.primary.withValues(alpha: 0.15),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : null,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            _isInterStateTax ? Icons.swap_horiz_rounded : Icons.location_on_outlined,
                                            size: 13,
                                            color: _isInterStateTax ? AppColors.primary : AppColors.textMuted,
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            _isInterStateTax ? 'Inter-State (IGST)' : 'Intra-State (CGST+SGST)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: _isInterStateTax ? FontWeight.w700 : FontWeight.w600,
                                              color: _isInterStateTax ? AppColors.primaryDark : AppColors.textSecondary,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );

                                if (isHeaderNarrow) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      title,
                                      const SizedBox(height: 8),
                                      taxToggle,
                                    ],
                                  );
                                }
                                return Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: title),
                                    const SizedBox(width: 8),
                                    taxToggle,
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildSummaryRow('Subtotal Amount', Formatters.formatCurrency(_subtotalAmount)),
                            const SizedBox(height: 8),
                            _buildSummaryRow('Total Discount', '- ${Formatters.formatCurrency(_totalDiscount)}', color: AppColors.dangerText),
                            const SizedBox(height: 8),
                            _buildSummaryRow('Taxable Amount', Formatters.formatCurrency(_totalTaxable)),
                            const SizedBox(height: 8),
                            if (_isInterStateTax)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primarySoft,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                                ),
                                child: _buildSummaryRow('IGST (18%)', Formatters.formatCurrency(_totalGst), color: AppColors.primaryDark),
                              )
                            else ...[
                              _buildSummaryRow('CGST (9%)', Formatters.formatCurrency(_totalGst / 2)),
                              const SizedBox(height: 8),
                              _buildSummaryRow('SGST (9%)', Formatters.formatCurrency(_totalGst / 2)),
                            ],
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),
                            _buildSummaryRow('Grand Total', Formatters.formatCurrency(_grandTotal), isBold: true, fontSize: 16, color: AppColors.primary),
                          ],
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            termsAndNotesArea,
                            const SizedBox(height: 20),
                            financialSummary,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: termsAndNotesArea),
                          const SizedBox(width: 24),
                          Expanded(flex: 2, child: financialSummary),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bottom Actions Card
            LayoutBuilder(
              builder: (context, actionBox) {
                final isMobile = actionBox.maxWidth < 600;
                if (isMobile) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: ErpButton(
                          text: _isRevision ? 'Publish Revision' : 'Save & Mark Sent',
                          icon: Icons.send_outlined,
                          isLoading: _isSubmitting,
                          onPressed: () => _saveQuotation(false),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ErpButton(
                          text: 'Save as Draft',
                          isOutlined: true,
                          isLoading: _isSubmitting,
                          onPressed: () => _saveQuotation(true),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ErpButton(
                          text: 'Cancel',
                          isOutlined: true,
                          onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.quotations,
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ErpButton(
                      text: 'Cancel',
                      isOutlined: true,
                      onPressed: () => ref.read(currentNavSectionProvider.notifier).state = ErpNavSection.quotations,
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: 'Save as Draft',
                      isOutlined: true,
                      isLoading: _isSubmitting,
                      onPressed: () => _saveQuotation(true),
                    ),
                    const SizedBox(width: 12),
                    ErpButton(
                      text: _isRevision ? 'Publish Revision' : 'Save & Mark Sent',
                      icon: Icons.send_outlined,
                      isLoading: _isSubmitting,
                      onPressed: () => _saveQuotation(false),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, double fontSize = 13, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color ?? AppColors.textPrimary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
