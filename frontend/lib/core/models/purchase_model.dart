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
}
