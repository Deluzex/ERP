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

/// Official GST state codes for statutory Place of Supply selection.
/// The delivery destination is a structured selection, never derived from
/// free-text address strings.
const Map<String, String> _gstStateCodes = {
  'Jammu and Kashmir': '01',
  'Himachal Pradesh': '02',
  'Punjab': '03',
  'Chandigarh': '04',
  'Uttarakhand': '05',
  'Haryana': '06',
  'Delhi': '07',
  'Rajasthan': '08',
  'Uttar Pradesh': '09',
  'Bihar': '10',
  'Sikkim': '11',
  'Arunachal Pradesh': '12',
  'Nagaland': '13',
  'Manipur': '14',
  'Mizoram': '15',
  'Tripura': '16',
  'Meghalaya': '17',
  'Assam': '18',
  'West Bengal': '19',
  'Jharkhand': '20',
  'Odisha': '21',
  'Chhattisgarh': '22',
  'Madhya Pradesh': '23',
  'Gujarat': '24',
  'Dadra and Nagar Haveli and Daman and Diu': '26',
  'Maharashtra': '27',
  'Karnataka': '29',
  'Goa': '30',
  'Lakshadweep': '31',
  'Kerala': '32',
  'Tamil Nadu': '33',
  'Puducherry': '34',
  'Andaman and Nicobar Islands': '35',
  'Telangana': '36',
  'Andhra Pradesh': '37',
  'Ladakh': '38',
};

/// Official state code for a known state name, or null when unverifiable.
String? _gstCodeForStateName(String stateName) {
  final want = stateName.trim().toLowerCase();
  if (want.isEmpty) return null;
  for (final entry in _gstStateCodes.entries) {
    if (entry.key.toLowerCase() == want) return entry.value;
  }
  return null;
}

/// Canonical display name of a known state name, or null when unverifiable.
String? _canonicalStateName(String stateName) {
  final want = stateName.trim().toLowerCase();
  if (want.isEmpty) return null;
  for (final entry in _gstStateCodes.entries) {
    if (entry.key.toLowerCase() == want) return entry.key;
  }
  return null;
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
  bool _isTaxManuallySelected = false;
  // Statutory Place of Supply destination for direct-dispatch quotations
  // without a linked project (null = party registered location default).
  String? _deliveryPosState;

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Await party / product / project loads so the initial statutory GST
      // classification resolves against Place of Supply data, not empty masters.
      await Future.wait([
        db.loadRawMaterials(),
        db.loadFinishedProducts(),
        db.loadCustomers(),
        db.loadDealers(),
        db.loadArchitects(),
        db.loadProjects(),
      ]);
      if (mounted) {
        setState(() {
          _resolveTaxClassification();
        });
      }
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
      _resolveTaxClassification();
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

  void _resolveTaxClassification() {

    if (_isTaxManuallySelected) return;

    final db = ref.read(databaseServiceProvider);

    // Revisions inherit the parent quotation's statutory regime (backend rule:
    // createQuotationRevision saves with parent.isInterStateTax without re-resolving).
    if (_isRevision && _sourceQuotation != null) {
      _isInterStateTax = _sourceQuotation!.isInterStateTax;
      return;
    }

    // 1. If project is selected, project site location authoritatively governs Place of Supply (Section 10 IGST Act)
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

    // 1b. Explicit delivery destination for direct-dispatch quotations without a
    // linked project (Section 10(1) IGST Act: goods movement terminates here).
    // Mirrors backend resolvePlaceOfSupply priority: explicit POS > project > party.
    if (_selectedProjectId == null) {
      final destinationName = _deliveryPosState?.trim();
      final destinationCode =
          destinationName != null && destinationName.isNotEmpty ? _gstCodeForStateName(destinationName) : null;
      if (destinationCode != null) {
        _isInterStateTax = (destinationCode != '24');
        return;
      }
    }

    // 2. Fall back to party registered location if no project
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
        partyStateCode = d.stateCode.trim();
      }
    } else if (_partyType == PartyType.architect) {
      final a = db.architects.where((x) => x.id == _selectedPartyId).firstOrNull;
      if (a != null) {
        partyGst = a.gstNumber.trim();
        partyState = a.state.trim().toLowerCase();
        partyStateCode = a.stateCode.trim();
      }
    }

    // GSTIN 2-digit prefix is highest fidelity indicator for registered entities
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

    // Default intra-state (seller registered in Gujarat 24)
    _isInterStateTax = false;
  }

  String _getPlaceOfSupplyDescription(MockDatabaseService db) {
    if (_selectedProjectId != null) {
      final project = db.projects.where((p) => p.id == _selectedProjectId).firstOrNull;
      if (project != null) {
        final state = project.siteState ?? '';
        final code = project.siteStateCode ?? '';
        final stateDisp = state.isNotEmpty ? state : (code.isNotEmpty ? 'Code $code' : 'Unresolved');
        return 'Project Site: ${project.name} ($stateDisp${code.isNotEmpty && state.isNotEmpty ? " - State Code $code" : ""})';
      }
    }
    if (_selectedProjectId == null) {
      final destinationName = _deliveryPosState?.trim();
      if (destinationName != null && destinationName.isNotEmpty) {
        final code = _gstCodeForStateName(destinationName);
        return 'Delivery Destination: $destinationName${code != null ? " - Code $code" : " (Unverified)"}';
      }
    }
    if (_partyType == PartyType.customer) {
      final c = db.customers.where((x) => x.id == _selectedPartyId).firstOrNull;
      return 'Customer: ${c?.name ?? "Client"} (${c?.state.isNotEmpty == true ? c!.state : "Gujarat"} - Code ${c?.stateCode ?? "24"})';
    } else if (_partyType == PartyType.dealer) {
      final d = db.dealers.where((x) => x.id == _selectedPartyId).firstOrNull;
      return 'Dealer: ${d?.name ?? "Dealer"} (${d?.state.isNotEmpty == true ? d!.state : "Gujarat"})';
    } else {
      final a = db.architects.where((x) => x.id == _selectedPartyId).firstOrNull;
      return 'Architect: ${a?.name ?? "Architect"} (${a?.state.isNotEmpty == true ? a!.state : "Gujarat"})';
    }
  }

  void _autoFillPartyDetails(String partyId, PartyType type, MockDatabaseService db) {
    // Destination defaults to the party's GST-registered state so the
    // classification is unchanged unless the delivery destination differs.
    _deliveryPosState = null;
    if (type == PartyType.customer) {
      final c = db.customers.where((cust) => cust.id == partyId).firstOrNull;
      if (c != null) {
        _contactPersonCtrl.text = 'Mr./Ms. Client Representative';
        _mobileCtrl.text = c.mobile;
        _emailCtrl.text = c.email;
        _gstNumberCtrl.text = c.gstNumber;
        _billingAddressCtrl.text = c.address;
        _shippingAddressCtrl.text = c.address;
        _deliveryPosState = _canonicalStateName(c.state);
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
        _deliveryPosState = _canonicalStateName(d.state);
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
        _deliveryPosState = _canonicalStateName(a.state);
      }
    }
    _resolveTaxClassification();
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

  Future<void> _saveQuotation(bool isDraft) async {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one product row.'), backgroundColor: AppColors.danger),
      );
      return;
    }
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final db = ref.read(databaseServiceProvider);

    if (_selectedProjectId != null) {
      final p = db.projects.where((prj) => prj.id == _selectedProjectId).firstOrNull;
      if (p != null) {
        final siteState = p.siteState?.trim();
        final siteCode = p.siteStateCode?.trim();
        if ((siteState == null || siteState.isEmpty) && (siteCode == null || siteCode.isEmpty)) {
          setState(() => _isSubmitting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot finalize quotation: Project Place of Supply site state is unresolved. Please update the project site location in Project Master before proceeding.'),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
      }
    }

    _resolveTaxClassification();

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
        // Explicit Place of Supply travels with the sale when a delivery
        // destination governs the classification (no linked project). The
        // backend validates isInterStateTax against this statutory input.
        final destinationName = _selectedProjectId == null ? _deliveryPosState?.trim() : null;
        final destinationCode =
            destinationName != null && destinationName.isNotEmpty ? _gstCodeForStateName(destinationName) : null;
        await db.createQuotationAsync(
          quotation,
          placeOfSupplyState: destinationCode != null ? destinationName : null,
          placeOfSupplyStateCode: destinationCode,
        );
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
            // 1. Header & Actions
            LayoutBuilder(
              builder: (context, constraints) {
                final isStacked = constraints.maxWidth < 850;
                final titleBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isRevision) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Quotation Revision (Rev $_revisionNumber)',
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      _isRevision
                          ? 'Creating revision for ${_sourceQuotation?.invoiceNumber}. Old version will be superseded.'
                          : 'Commercial estimate with finished product lines (Zero stock impact until confirmed)',
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
                  LayoutBuilder(
                    builder: (context, partyBox) {
                      final isNarrow = partyBox.maxWidth < 750;

                      final radioGroup = Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
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
                                      _resolveTaxClassification();
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
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
                                      _resolveTaxClassification();
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
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
                                      _resolveTaxClassification();
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      );

                      final dropdownField = DropdownButtonFormField<String>(
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
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            radioGroup,
                            const SizedBox(height: 12),
                            dropdownField,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(flex: 3, child: radioGroup),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: dropdownField),
                        ],
                      );
                    },
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
                              setState(() {
                                _selectedProjectId = val;
                                _resolveTaxClassification();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          value: _deliveryPosState,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Place of Supply (Delivery Destination)',
                            helperText: _selectedProjectId != null
                                ? 'Linked project site governs Place of Supply'
                                : (_isRevision
                                    ? 'Revision inherits the original quotation tax regime'
                                    : 'Defaults to party registered location'),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(value: null, child: Text('Party Registered Location (Default)')),
                            ..._gstStateCodes.keys.map(
                              (s) => DropdownMenuItem<String?>(
                                value: s,
                                child: Text('$s (${_gstStateCodes[s]})', maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                          onChanged: (_selectedProjectId != null || _isRevision)
                              ? null
                              : (val) {
                                  setState(() {
                                    _deliveryPosState = val;
                                    _resolveTaxClassification();
                                  });
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
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (ctx, idx) {
                      final item = _items[idx];
                      final isRm = item.itemType == PurchaseItemType.rawMaterial;
                      final typeColor = isRm ? Colors.amber.shade800 : Colors.teal.shade700;
                      final bgColor = isRm ? Colors.amber.withValues(alpha: 0.03) : Colors.teal.withValues(alpha: 0.03);
                      final borderColor = isRm ? Colors.amber.withValues(alpha: 0.35) : Colors.teal.withValues(alpha: 0.3);

                      return Container(
                        key: ValueKey('item_card_${idx}_${item.itemId}_${item.itemType.name}'),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor, width: 1.2),
                        ),
                        child: LayoutBuilder(
                          builder: (context, itemConstraints) {
                            final isItemNarrow = itemConstraints.maxWidth < 900;

                            // Item Type Dropdown
                            final typeSelector = SizedBox(
                              width: 160,
                              child: DropdownButtonFormField<PurchaseItemType>(
                                value: item.itemType,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: 'Item Type',
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  fillColor: isRm ? Colors.amber.withValues(alpha: 0.08) : Colors.teal.withValues(alpha: 0.08),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: PurchaseItemType.finishedProduct,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.inventory_2_outlined, size: 14, color: Colors.teal.shade700),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Text('Fin Good', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.teal.shade700), overflow: TextOverflow.ellipsis),
                                        ),
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
                                        Flexible(
                                          child: Text('Raw Mat', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade800), overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ),
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
                                      item.availableStockSnapshot = rm.currentStock;
                                      item.productDescription = _generateRmDescription(rm);
                                    });
                                  } else if (newType == PurchaseItemType.finishedProduct && db.finishedProducts.isNotEmpty) {
                                    final fp = db.finishedProducts.first;
                                    setState(() {
                                      item.itemType = PurchaseItemType.finishedProduct;
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
                              ),
                            );

                            // Master Item Picker Dropdown
                            final itemPicker = isRm
                                ? DropdownButtonFormField<String>(
                                    key: ValueKey('rm_picker_${idx}_${item.itemId}'),
                                    value: db.rawMaterials.any((r) => r.id == item.itemId)
                                        ? item.itemId
                                        : (db.rawMaterials.isNotEmpty ? db.rawMaterials.first.id : null),
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Raw Material Master *',
                                      prefixIcon: Icon(Icons.grain, size: 18),
                                    ),
                                    items: db.rawMaterials.map((rm) {
                                      return DropdownMenuItem(
                                        value: rm.id,
                                        child: Text(
                                          '${rm.name} (${rm.itemCode}) — Stock: ${rm.currentStock} ${rm.unit}',
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
                                          item.availableStockSnapshot = rm.currentStock;
                                          item.productDescription = _generateRmDescription(rm);
                                        });
                                      }
                                    },
                                  )
                                : DropdownButtonFormField<String>(
                                    key: ValueKey('fp_picker_${idx}_${item.itemId}'),
                                    value: db.finishedProducts.any((p) => p.id == item.itemId)
                                        ? item.itemId
                                        : (db.finishedProducts.isNotEmpty ? db.finishedProducts.first.id : null),
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Finished Product Master *',
                                      prefixIcon: Icon(Icons.inventory_2_outlined, size: 18),
                                    ),
                                    items: db.finishedProducts.map((fp) {
                                      return DropdownMenuItem(
                                        value: fp.id,
                                        child: Text(
                                          '${fp.name} (${fp.itemCode}) — Stock: ${fp.availableStock} ${fp.unit}',
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
                              key: ValueKey('qty_${idx}_${item.itemId}_${item.quantity}'),
                              initialValue: item.quantity.toString(),
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Quantity (${item.unit})',
                                prefixIcon: const Icon(Icons.numbers, size: 16),
                              ),
                              onChanged: (val) => setState(() => item.quantity = double.tryParse(val) ?? 1.0),
                            );

                            final rateField = TextFormField(
                              key: ValueKey('rate_${idx}_${item.itemId}_${item.rate}'),
                              initialValue: item.rate.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Unit Rate (₹)',
                                prefixIcon: Icon(Icons.currency_rupee, size: 16),
                              ),
                              onChanged: (val) => setState(() => item.rate = double.tryParse(val) ?? 0.0),
                            );

                            final discountField = TextFormField(
                              key: ValueKey('discount_${idx}_${item.itemId}_${item.discount}'),
                              initialValue: item.discount.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Discount (₹)',
                                prefixIcon: Icon(Icons.discount_outlined, size: 16),
                              ),
                              onChanged: (val) => setState(() => item.discount = double.tryParse(val) ?? 0.0),
                            );

                            final gstField = TextFormField(
                              key: ValueKey('gst_${idx}_${item.itemId}_${item.gstPercent}'),
                              initialValue: item.gstPercent.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'GST %',
                                prefixIcon: Icon(Icons.percent, size: 16),
                              ),
                              onChanged: (val) => setState(() => item.gstPercent = double.tryParse(val) ?? 18.0),
                            );

                            final lineTotalDisplay = Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Line Total', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                                  Text(
                                    Formatters.formatCurrency(item.lineTotal),
                                    style: AppTextStyles.bodyBold.copyWith(fontSize: 14, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            );

                            final actionButtons = Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
                                  tooltip: 'Duplicate Row',
                                  onPressed: () => _duplicateRow(idx),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 18, color: _items.length > 1 ? AppColors.danger : Colors.grey.shade400),
                                  tooltip: _items.length > 1 ? 'Remove Row' : 'At least one line item required',
                                  onPressed: _items.length > 1 ? () => _removeRow(idx) : null,
                                ),
                              ],
                            );

                            final descriptionField = TextFormField(
                              key: ValueKey('desc_${idx}_${item.itemId}_${item.itemType.name}_${item.productDescription.hashCode}'),
                              initialValue: item.productDescription,
                              decoration: const InputDecoration(
                                labelText: 'Item Description / Custom Specifications for Quote PDF',
                                hintText: 'E.g. 3000K Warm White, DALI dimmable driver, or custom raw material grade specifications...',
                                isDense: true,
                              ),
                              onChanged: (val) => item.productDescription = val,
                            );

                            if (isItemNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: typeColor,
                                        child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                      const SizedBox(width: 8),
                                      typeSelector,
                                      const Spacer(),
                                      actionButtons,
                                    ],
                                  ),
                                  const SizedBox(height: 10),
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
                                      const SizedBox(width: 8),
                                      lineTotalDisplay,
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  descriptionField,
                                ],
                              );
                            }

                            // Desktop 2-tier layout: Top tier has full-width picker; bottom tier has numeric fields
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 13,
                                      backgroundColor: typeColor,
                                      child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                    const SizedBox(width: 10),
                                    typeSelector,
                                    const SizedBox(width: 12),
                                    Expanded(child: itemPicker),
                                    const SizedBox(width: 12),
                                    actionButtons,
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const SizedBox(width: 36), // Align with picker
                                    Expanded(flex: 3, child: qtyField),
                                    const SizedBox(width: 12),
                                    Expanded(flex: 3, child: rateField),
                                    const SizedBox(width: 12),
                                    Expanded(flex: 3, child: discountField),
                                    const SizedBox(width: 12),
                                    Expanded(flex: 2, child: gstField),
                                    const SizedBox(width: 16),
                                    lineTotalDisplay,
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.only(left: 36),
                                  child: descriptionField,
                                ),
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
            LayoutBuilder(
              builder: (context, totalsConstraints) {
                final isNarrowTotals = totalsConstraints.maxWidth < 850;

                final termsCard = Container(
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
                      LayoutBuilder(
                        builder: (context, headerConstraints) {
                          final isNarrowHeader = headerConstraints.maxWidth < 360;
                          final title = Text(
                            'Quotation Totals',
                            style: AppTextStyles.h3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                          final chip = InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Row(
                                    children: [
                                      const Icon(Icons.lock_outline, color: AppColors.primary, size: 20),
                                      const SizedBox(width: 8),
                                      const Text('Statutory Tax Classification'),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Tax classification is automatically determined per GST Section 10 Place of Supply rules:',
                                        style: AppTextStyles.bodyMedium,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '• Seller Location: Gujarat (State Code 24)\n'
                                        '• Place of Supply: ${_getPlaceOfSupplyDescription(db)}\n'
                                        '• Tax Regime: ${_isInterStateTax ? "Inter-State (IGST 18%)" : "Intra-State (CGST 9% + SGST 9%)"}',
                                        style: AppTextStyles.bodySmall.copyWith(fontFamily: 'monospace', height: 1.5),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: Colors.amber.shade300),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'Manual switching is prohibited to prevent compliance violations.',
                                                style: AppTextStyles.caption.copyWith(color: Colors.amber.shade900),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _isInterStateTax ? Colors.purple.withValues(alpha: 0.12) : Colors.blue.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _isInterStateTax ? Colors.purple.shade300 : Colors.blue.shade300,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.lock,
                                    size: 12,
                                    color: _isInterStateTax ? Colors.purple.shade700 : Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isInterStateTax ? 'Inter-State (IGST 18%)' : 'Intra-State (CGST+SGST)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: _isInterStateTax ? Colors.purple.shade900 : Colors.blue.shade900,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.info_outline,
                                    size: 12,
                                    color: _isInterStateTax ? Colors.purple.shade600 : Colors.blue.shade600,
                                  ),
                                ],
                              ),
                            ),
                          );

                          return SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                title,
                                chip,
                              ],
                            ),
                          );
                        },
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
                );

                if (isNarrowTotals) {
                  return Column(
                    children: [
                      termsCard,
                      const SizedBox(height: 20),
                      summaryCard,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: termsCard),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: summaryCard),
                  ],
                );
              },
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
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
