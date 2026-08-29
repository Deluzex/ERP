import 'purchase_model.dart';

enum PartyType {
  customer,
  dealer,
}

enum SalesDocumentType {
  invoice,
  quotation,
  salesOrder,
  salesReturn,
}

enum SaleStatus {
  draft,
  active,
  partialPaid,
  paid,
  completed,
  cancelled,
}

class SaleLineItem {
  final String finishedProductId;
  final String finishedProductName;
  final String finishedProductCode;
  final double quantity;
  final String unit;
  final double rate;
  final double discountAmount;
  final double gstPercent;
  final double lineTotal;

  SaleLineItem({
    required this.finishedProductId,
    required this.finishedProductName,
    required this.finishedProductCode,
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

class Sale {
  final String id;
  final String invoiceNumber; // e.g. INV-2026-001
  final SalesDocumentType documentType;
  final PartyType partyType;
  final String partyId; // Customer ID or Dealer ID
  final String partyName;
  final String? projectId;
  final String? projectName;
  final String? architectId;
  final String? architectName;
  final DateTime saleDate;
  final List<SaleLineItem> items;
  final double subtotalAmount;
  final double discountAmount;
  final double gstAmount;
  final double totalAmount;
  final double paidAmount;
  final double pendingAmount;
  final PaymentMode paymentMode;
  final SaleStatus status;
  final double architectCommissionAmount;
  final String? notes;
  final DateTime createdAt;

  Sale({
    required this.id,
    required this.invoiceNumber,
    required this.documentType,
    required this.partyType,
    required this.partyId,
    required this.partyName,
    this.projectId,
    this.projectName,
    this.architectId,
    this.architectName,
    required this.saleDate,
    required this.items,
    required this.subtotalAmount,
    this.discountAmount = 0.0,
    required this.gstAmount,
    required this.totalAmount,
    this.paidAmount = 0.0,
    required this.pendingAmount,
    required this.paymentMode,
    required this.status,
    this.architectCommissionAmount = 0.0,
    this.notes,
    required this.createdAt,
  });

  String get statusLabel {
    switch (status) {
      case SaleStatus.draft:
        return 'Draft';
      case SaleStatus.active:
        return 'Active';
      case SaleStatus.partialPaid:
        return 'Partially Paid';
      case SaleStatus.paid:
        return 'Paid';
      case SaleStatus.completed:
        return 'Completed';
      case SaleStatus.cancelled:
        return 'Cancelled';
    }
  }

  Sale copyWith({
    String? id,
    String? invoiceNumber,
    SalesDocumentType? documentType,
    PartyType? partyType,
    String? partyId,
    String? partyName,
    String? projectId,
    String? projectName,
    String? architectId,
    String? architectName,
    DateTime? saleDate,
    List<SaleLineItem>? items,
    double? subtotalAmount,
    double? discountAmount,
    double? gstAmount,
    double? totalAmount,
    double? paidAmount,
    double? pendingAmount,
    PaymentMode? paymentMode,
    SaleStatus? status,
    double? architectCommissionAmount,
    String? notes,
    DateTime? createdAt,
  }) {
    return Sale(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      documentType: documentType ?? this.documentType,
      partyType: partyType ?? this.partyType,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      architectId: architectId ?? this.architectId,
      architectName: architectName ?? this.architectName,
      saleDate: saleDate ?? this.saleDate,
      items: items ?? this.items,
      subtotalAmount: subtotalAmount ?? this.subtotalAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      gstAmount: gstAmount ?? this.gstAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      pendingAmount: pendingAmount ?? this.pendingAmount,
      paymentMode: paymentMode ?? this.paymentMode,
      status: status ?? this.status,
      architectCommissionAmount: architectCommissionAmount ?? this.architectCommissionAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
