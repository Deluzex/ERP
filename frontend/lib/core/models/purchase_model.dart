enum PurchaseStatus {
  draft,
  saved,
  partialPaid,
  paid,
  cancelled,
}

enum PaymentMode {
  cash,
  bankTransfer,
  cheque,
  upi,
  credit,
}

class PurchaseLineItem {
  final String rawMaterialId;
  final String rawMaterialName;
  final String rawMaterialCode;
  final double quantity;
  final String unit;
  final double rate;
  final double discountAmount;
  final double gstPercent;
  final double lineTotal;

  PurchaseLineItem({
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.rawMaterialCode,
    required this.quantity,
    required this.unit,
    required this.rate,
    this.discountAmount = 0.0,
    this.gstPercent = 18.0,
    required this.lineTotal,
  });

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
}

class Purchase {
  final String id;
  final String purchaseNumber; // e.g. PO-2026-001
  final DateTime purchaseDate;
  final String vendorId;
  final String vendorName;
  final String vendorInvoiceNumber;
  final DateTime invoiceDate;
  final List<PurchaseLineItem> items;
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final PaymentMode paymentMode;
  final PurchaseStatus status;
  final String? notes;
  final DateTime createdAt;

  Purchase({
    required this.id,
    required this.purchaseNumber,
    required this.purchaseDate,
    required this.vendorId,
    required this.vendorName,
    required this.vendorInvoiceNumber,
    required this.invoiceDate,
    required this.items,
    required this.totalAmount,
    required this.paidAmount,
    required this.pendingAmount,
    required this.paymentMode,
    required this.status,
    this.notes,
    required this.createdAt,
  });

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

  Purchase copyWith({
    String? id,
    String? purchaseNumber,
    DateTime? purchaseDate,
    String? vendorId,
    String? vendorName,
    String? vendorInvoiceNumber,
    DateTime? invoiceDate,
    List<PurchaseLineItem>? items,
    double? totalAmount,
    double? paidAmount,
    double? pendingAmount,
    PaymentMode? paymentMode,
    PurchaseStatus? status,
    String? notes,
    DateTime? createdAt,
  }) {
    return Purchase(
      id: id ?? this.id,
      purchaseNumber: purchaseNumber ?? this.purchaseNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      vendorInvoiceNumber: vendorInvoiceNumber ?? this.vendorInvoiceNumber,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      items: items ?? this.items,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
