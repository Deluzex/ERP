enum PurchaseStatus {
  draft,
  saved,
  partialPaid,
  paid,
  cancelled,
}

enum PurchaseItemType {
  rawMaterial,
  finishedProduct,
}

enum PaymentMode {
  cash,
  bankTransfer,
  cheque,
  upi,
  credit,
  creditNote,
}

class PurchaseLineItem {
  final PurchaseItemType itemType;
  final String? rawMaterialId;
  final String? rawMaterialName;
  final String? rawMaterialCode;
  final String? finishedProductId;
  final String? finishedProductName;
  final String? finishedProductCode;
  final double quantity;
  final String unit;
  final double rate;
  final double discountAmount;
  final double gstPercent;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double lineTotal;

  PurchaseLineItem({
    this.itemType = PurchaseItemType.rawMaterial,
    this.rawMaterialId,
    this.rawMaterialName,
    this.rawMaterialCode,
    this.finishedProductId,
    this.finishedProductName,
    this.finishedProductCode,
    required this.quantity,
    required this.unit,
    required this.rate,
    this.discountAmount = 0.0,
    this.gstPercent = 18.0,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    required this.lineTotal,
  })  : taxableAmount = taxableAmount ?? ((quantity * rate) - discountAmount).clamp(0.0, double.infinity),
        cgstAmount = cgstAmount ?? ((((quantity * rate) - discountAmount) * (gstPercent / 2)) / 100.0),
        sgstAmount = sgstAmount ?? ((((quantity * rate) - discountAmount) * (gstPercent / 2)) / 100.0),
        igstAmount = igstAmount ?? 0.0;

  String get displayName => itemType == PurchaseItemType.finishedProduct
      ? (finishedProductName ?? 'Finished Product')
      : (rawMaterialName ?? 'Raw Material');

  String get displayCode => itemType == PurchaseItemType.finishedProduct
      ? (finishedProductCode ?? '')
      : (rawMaterialCode ?? '');

  String get itemId => itemType == PurchaseItemType.finishedProduct
      ? (finishedProductId ?? '')
      : (rawMaterialId ?? '');

  static double calculateLineTotal({
    required double quantity,
    required double rate,
    double discountAmount = 0.0,
    double gstPercent = 18.0,
  }) {
    final subtotal = (quantity * rate) - discountAmount;
    final gstAmount = (subtotal * gstPercent) / 100.0;
    return subtotal + gstAmount;
  }

  PurchaseLineItem copyWith({
    PurchaseItemType? itemType,
    String? rawMaterialId,
    String? rawMaterialName,
    String? rawMaterialCode,
    String? finishedProductId,
    String? finishedProductName,
    String? finishedProductCode,
    double? quantity,
    String? unit,
    double? rate,
    double? discountAmount,
    double? gstPercent,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    double? lineTotal,
  }) {
    return PurchaseLineItem(
      itemType: itemType ?? this.itemType,
      rawMaterialId: rawMaterialId ?? this.rawMaterialId,
      rawMaterialName: rawMaterialName ?? this.rawMaterialName,
      rawMaterialCode: rawMaterialCode ?? this.rawMaterialCode,
      finishedProductId: finishedProductId ?? this.finishedProductId,
      finishedProductName: finishedProductName ?? this.finishedProductName,
      finishedProductCode: finishedProductCode ?? this.finishedProductCode,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      rate: rate ?? this.rate,
      discountAmount: discountAmount ?? this.discountAmount,
      gstPercent: gstPercent ?? this.gstPercent,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstAmount: igstAmount ?? this.igstAmount,
      lineTotal: lineTotal ?? this.lineTotal,
    );
  }

  factory PurchaseLineItem.fromJson(Map<String, dynamic> json) {
    return PurchaseLineItem(
      itemType: _parsePurchaseItemType(json['itemType'] ?? json['item_type']),
      rawMaterialId: json['rawMaterialId']?.toString() ?? json['raw_material_id']?.toString(),
      rawMaterialName: json['rawMaterialName']?.toString() ?? json['raw_material_name']?.toString(),
      rawMaterialCode: json['rawMaterialCode']?.toString() ?? json['raw_material_code']?.toString(),
      finishedProductId: json['finishedProductId']?.toString() ?? json['finished_product_id']?.toString(),
      finishedProductName: json['finishedProductName']?.toString() ?? json['finished_product_name']?.toString(),
      finishedProductCode: json['finishedProductCode']?.toString() ?? json['finished_product_code']?.toString(),
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      unit: json['unit']?.toString() ?? 'kg',
      rate: double.tryParse(json['rate']?.toString() ?? '0') ?? 0.0,
      discountAmount: double.tryParse(json['discountAmount']?.toString() ?? json['discount_amount']?.toString() ?? '0') ?? 0.0,
      gstPercent: double.tryParse(json['gstPercent']?.toString() ?? json['gst_percent']?.toString() ?? '18') ?? 18.0,
      taxableAmount: double.tryParse(json['taxableAmount']?.toString() ?? json['taxable_amount']?.toString() ?? '0'),
      cgstAmount: double.tryParse(json['cgstAmount']?.toString() ?? json['cgst_amount']?.toString() ?? '0'),
      sgstAmount: double.tryParse(json['sgstAmount']?.toString() ?? json['sgst_amount']?.toString() ?? '0'),
      igstAmount: double.tryParse(json['igstAmount']?.toString() ?? json['igst_amount']?.toString() ?? '0'),
      lineTotal: double.tryParse(json['lineTotal']?.toString() ?? json['line_total']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemType': itemType.name,
      if (rawMaterialId != null) 'rawMaterialId': rawMaterialId,
      if (rawMaterialName != null) 'rawMaterialName': rawMaterialName,
      if (rawMaterialCode != null) 'rawMaterialCode': rawMaterialCode,
      if (finishedProductId != null) 'finishedProductId': finishedProductId,
      if (finishedProductName != null) 'finishedProductName': finishedProductName,
      if (finishedProductCode != null) 'finishedProductCode': finishedProductCode,
      'quantity': quantity,
      'unit': unit,
      'rate': rate,
      'discountAmount': discountAmount,
      'gstPercent': gstPercent,
      'taxableAmount': taxableAmount,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'igstAmount': igstAmount,
      'lineTotal': lineTotal,
    };
  }
}

class Purchase {
  final String id;
  final String purchaseNumber; // e.g. PO-2026-001
  final DateTime purchaseDate;
  final String vendorId;
  final String vendorName;
  final String? vendorCompanyName;
  final String vendorInvoiceNumber;
  final DateTime invoiceDate;
  final PurchaseItemType purchaseType;
  final List<PurchaseLineItem> items;
  final double subtotalAmount;
  final double discountAmount;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double gstAmount;
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final PaymentMode paymentMode;
  final PurchaseStatus status;
  final String? notes;
  final String? attachmentUrl;
  final String? projectId;
  final String? projectName;
  final DateTime createdAt;

  Purchase({
    required this.id,
    required this.purchaseNumber,
    required this.purchaseDate,
    required this.vendorId,
    required this.vendorName,
    this.vendorCompanyName,
    required this.vendorInvoiceNumber,
    required this.invoiceDate,
    this.purchaseType = PurchaseItemType.rawMaterial,
    required this.items,
    double? subtotalAmount,
    this.discountAmount = 0.0,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    double? gstAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.paymentMode,
    required this.status,
    this.notes,
    this.attachmentUrl,
    this.projectId,
    this.projectName,
    required this.createdAt,
  })  : subtotalAmount = subtotalAmount ?? totalAmount,
        taxableAmount = taxableAmount ?? (totalAmount / 1.18),
        cgstAmount = cgstAmount ?? ((totalAmount - (totalAmount / 1.18)) / 2),
        sgstAmount = sgstAmount ?? ((totalAmount - (totalAmount / 1.18)) / 2),
        igstAmount = igstAmount ?? 0.0,
        gstAmount = gstAmount ?? (totalAmount - (totalAmount / 1.18));

  String get statusLabel {
    switch (status) {
      case PurchaseStatus.draft:
        return 'Draft';
      case PurchaseStatus.saved:
        return 'Saved';
      case PurchaseStatus.partialPaid:
        return 'Partially Paid';
      case PurchaseStatus.paid:
        return 'Paid';
      case PurchaseStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get purchaseTypeLabel => purchaseType == PurchaseItemType.finishedProduct
      ? 'Finished Product Purchase'
      : 'Raw Material Purchase';

  bool get isFinishedProductPurchase => purchaseType == PurchaseItemType.finishedProduct;
  bool get isInterStateTax => igstAmount > 0;

  Purchase copyWith({
    String? id,
    String? purchaseNumber,
    DateTime? purchaseDate,
    String? vendorId,
    String? vendorName,
    String? vendorCompanyName,
    String? vendorInvoiceNumber,
    DateTime? invoiceDate,
    PurchaseItemType? purchaseType,
    List<PurchaseLineItem>? items,
    double? subtotalAmount,
    double? discountAmount,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    double? gstAmount,
    double? totalAmount,
    double? paidAmount,
    double? pendingAmount,
    PaymentMode? paymentMode,
    PurchaseStatus? status,
    String? notes,
    String? attachmentUrl,
    String? projectId,
    String? projectName,
    DateTime? createdAt,
  }) {
    return Purchase(
      id: id ?? this.id,
      purchaseNumber: purchaseNumber ?? this.purchaseNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      vendorCompanyName: vendorCompanyName ?? this.vendorCompanyName,
      vendorInvoiceNumber: vendorInvoiceNumber ?? this.vendorInvoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      purchaseType: purchaseType ?? this.purchaseType,
      items: items ?? this.items,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstAmount: igstAmount ?? this.igstAmount,
      gstAmount: gstAmount ?? this.gstAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Purchase.fromJson(Map<String, dynamic> json) {
    var rawItems = json['items'] as List<dynamic>? ?? [];
    List<PurchaseLineItem> parsedItems = rawItems
        .map((i) => PurchaseLineItem.fromJson(i as Map<String, dynamic>))
        .toList();

    return Purchase(
      id: json['id']?.toString() ?? '',
      purchaseNumber: json['purchaseNumber']?.toString() ?? json['purchase_number']?.toString() ?? '',
      purchaseDate: json['purchaseDate'] != null
          ? DateTime.tryParse(json['purchaseDate'].toString()) ?? DateTime.now()
          : (json['purchase_date'] != null ? DateTime.tryParse(json['purchase_date'].toString()) ?? DateTime.now() : DateTime.now()),
      vendorId: json['vendorId']?.toString() ?? json['vendor_id']?.toString() ?? '',
      vendorName: json['vendorName']?.toString() ?? json['vendor_name']?.toString() ?? '',
      vendorCompanyName: json['vendorCompanyName']?.toString() ?? json['vendor_company_name']?.toString(),
      vendorInvoiceNumber: json['vendorInvoiceNumber']?.toString() ?? json['vendor_invoice_number']?.toString() ?? '',
      invoiceDate: json['invoiceDate'] != null
          ? DateTime.tryParse(json['invoiceDate'].toString()) ?? DateTime.now()
          : (json['invoice_date'] != null ? DateTime.tryParse(json['invoice_date'].toString()) ?? DateTime.now() : DateTime.now()),
      purchaseType: _parsePurchaseItemType(json['purchaseType'] ?? json['purchase_type']),
      items: parsedItems,
      subtotalAmount: double.tryParse(json['subtotalAmount']?.toString() ?? json['subtotal_amount']?.toString() ?? '0'),
      discountAmount: double.tryParse(json['discountAmount']?.toString() ?? json['discount_amount']?.toString() ?? '0') ?? 0.0,
      taxableAmount: double.tryParse(json['taxableAmount']?.toString() ?? json['taxable_amount']?.toString() ?? '0'),
      cgstAmount: double.tryParse(json['cgstAmount']?.toString() ?? json['cgst_amount']?.toString() ?? '0'),
      sgstAmount: double.tryParse(json['sgstAmount']?.toString() ?? json['sgst_amount']?.toString() ?? '0'),
      igstAmount: double.tryParse(json['igstAmount']?.toString() ?? json['igst_amount']?.toString() ?? '0'),
      gstAmount: double.tryParse(json['gstAmount']?.toString() ?? json['gst_amount']?.toString() ?? '0'),
      totalAmount: double.tryParse(json['totalAmount']?.toString() ?? json['total_amount']?.toString() ?? '0') ?? 0.0,
      paidAmount: double.tryParse(json['paidAmount']?.toString() ?? json['paid_amount']?.toString() ?? '0') ?? 0.0,
      pendingAmount: double.tryParse(json['pendingAmount']?.toString() ?? json['pending_amount']?.toString() ?? '0') ?? 0.0,
      paymentMode: _parsePaymentMode(json['paymentMode'] ?? json['payment_mode']),
      status: _parsePurchaseStatus(json['status']),
      notes: json['notes']?.toString(),
      attachmentUrl: json['attachmentUrl']?.toString() ?? json['attachment_url']?.toString(),
      projectId: json['projectId']?.toString() ?? json['project_id']?.toString(),
      projectName: json['projectName']?.toString() ?? json['project_name']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vendorId': vendorId,
      'vendorName': vendorName,
      'vendorInvoiceNumber': vendorInvoiceNumber,
      'purchaseDate': purchaseDate.toIso8601String(),
      'invoiceDate': invoiceDate.toIso8601String(),
      'purchaseType': purchaseType.name,
      'items': items.map((i) => i.toJson()).toList(),
      'subtotalAmount': subtotalAmount,
      'discountAmount': discountAmount,
      'taxableAmount': taxableAmount,
      'cgstAmount': cgstAmount,
      'sgstAmount': sgstAmount,
      'igstAmount': igstAmount,
      'gstAmount': gstAmount,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'pendingAmount': pendingAmount,
      'paymentMode': paymentMode.name,
      'status': status.name,
      if (notes != null) 'notes': notes,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (projectId != null) 'projectId': projectId,
      if (projectName != null) 'projectName': projectName,
    };
  }
}

PurchaseStatus _parsePurchaseStatus(dynamic val) {
  final str = val?.toString();
  switch (str) {
    case 'draft':
      return PurchaseStatus.draft;
    case 'saved':
      return PurchaseStatus.saved;
    case 'partialPaid':
      return PurchaseStatus.partialPaid;
    case 'paid':
      return PurchaseStatus.paid;
    case 'cancelled':
      return PurchaseStatus.cancelled;
    default:
      return PurchaseStatus.saved;
  }
}

PurchaseItemType _parsePurchaseItemType(dynamic val) {
  final str = val?.toString();
  switch (str) {
    case 'finishedProduct':
      return PurchaseItemType.finishedProduct;
    case 'rawMaterial':
    default:
      return PurchaseItemType.rawMaterial;
  }
}

PaymentMode _parsePaymentMode(dynamic val) {
  final str = val?.toString();
  switch (str) {
    case 'cash':
      return PaymentMode.cash;
    case 'bankTransfer':
      return PaymentMode.bankTransfer;
    case 'cheque':
      return PaymentMode.cheque;
    case 'upi':
      return PaymentMode.upi;
    case 'credit':
      return PaymentMode.credit;
    case 'creditNote':
      return PaymentMode.creditNote;
    default:
      return PaymentMode.credit;
  }
}
