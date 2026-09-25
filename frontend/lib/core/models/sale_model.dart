import 'purchase_model.dart';

enum PartyType {
  customer,
  dealer,
  architect,
}

enum SalesDocumentType {
  quotation,
  proformaInvoice,
  salesOrder,
  delivery,
  invoice,
  salesReturn,
}

enum SaleStatus {
  draft,
  active,
  partialPaid,
  paid,
  overdue,
  completed,
  cancelled,
}

enum QuotationStatus {
  draft,
  sent,
  accepted,
  approved,
  rejected,
  expired,
  superseded,
  converted,
  cancelled,
}

enum ProformaStatus {
  draft,
  issued,
  partialPaid,
  paid,
  cancelled,
  converted,
}

enum SalesOrderStatus {
  draft,
  pending,
  confirmed,
  stockAllocationPending,
  productionPending,
  inProduction,
  readyForDispatch,
  partiallyDelivered,
  dispatched,
  delivered,
  completed,
  done,
  onHold,
  cancelled,
}

enum DeliveryStatus {
  draft,
  dispatched,
  delivered,
  cancelled,
}

enum SalesReturnStatus {
  draft,
  submitted,
  itemsReceived,
  inspection,
  approved,
  completed,
  rejected,
  pending,
  requested,
}

enum ReturnCondition {
  resalable,
  damaged,
  scrap,
  goodCondition,
  repairable,
}

enum RefundStatus {
  notRequired,
  pending,
  approved,
  processed,
  cancelled,
}

enum ReturnType {
  fullReturn,
  partialReturn,
}

enum InvoiceReturnIndicator {
  noReturn,
  partiallyReturned,
  fullyReturned,
}

enum ReturnFinancialAction {
  creditNote,
  refund,
  adjustOutstanding,
}

class DocumentActivityLog {
  final String id;
  final String action;
  final String performedBy;
  final DateTime timestamp;
  final String? details;
  final String? statusBefore;
  final String? statusAfter;

  DocumentActivityLog({
    required this.id,
    required this.action,
    required this.performedBy,
    required this.timestamp,
    this.details,
    this.statusBefore,
    this.statusAfter,
  });
}

class SaleLineItem {
  final String finishedProductId;
  final String finishedProductName;
  final String finishedProductCode;
  final String productDescription;
  final double quantity; // Ordered / Quoted / Invoiced qty
  final double reservedQuantity;
  final double producedQuantity;
  final double deliveredQuantity;
  final double invoicedQuantity;
  final double returnedQuantity;
  final String unit;
  final double rate;
  final double discountAmount;
  final double gstPercent;
  final double taxableAmount;
  final double cgstAmount;
  final double sgstAmount;
  final double igstAmount;
  final double lineTotal;
  final String? productCondition;
  final ReturnCondition? returnCondition;

  SaleLineItem({
    required this.finishedProductId,
    required this.finishedProductName,
    required this.finishedProductCode,
    this.productDescription = '',
    required this.quantity,
    this.reservedQuantity = 0.0,
    this.producedQuantity = 0.0,
    this.deliveredQuantity = 0.0,
    this.invoicedQuantity = 0.0,
    this.returnedQuantity = 0.0,
    required this.unit,
    required this.rate,
    this.discountAmount = 0.0,
    this.gstPercent = 18.0,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    required this.lineTotal,
    this.productCondition,
    this.returnCondition,
  })  : taxableAmount = taxableAmount ?? ((quantity * rate) - discountAmount).clamp(0.0, double.infinity),
        cgstAmount = cgstAmount ?? ((((quantity * rate) - discountAmount) * (gstPercent / 2)) / 100.0),
        sgstAmount = sgstAmount ?? ((((quantity * rate) - discountAmount) * (gstPercent / 2)) / 100.0),
        igstAmount = igstAmount ?? 0.0;

  double get pendingQuantity => (quantity - deliveredQuantity).clamp(0.0, double.infinity);
  double get shortageQuantity => (quantity - reservedQuantity).clamp(0.0, double.infinity);

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

  factory SaleLineItem.fromJson(Map<String, dynamic> json) {
    return SaleLineItem(
      finishedProductId: json['finishedProductId']?.toString() ?? '',
      finishedProductName: json['finishedProductName']?.toString() ?? '',
      finishedProductCode: json['finishedProductCode']?.toString() ?? '',
      productDescription: json['productDescription']?.toString() ?? '',
      quantity: double.tryParse(json['quantity']?.toString() ?? '0') ?? 0.0,
      reservedQuantity: double.tryParse(json['reservedQuantity']?.toString() ?? '0') ?? 0.0,
      producedQuantity: double.tryParse(json['producedQuantity']?.toString() ?? '0') ?? 0.0,
      deliveredQuantity: double.tryParse(json['deliveredQuantity']?.toString() ?? '0') ?? 0.0,
      invoicedQuantity: double.tryParse(json['invoicedQuantity']?.toString() ?? '0') ?? 0.0,
      returnedQuantity: double.tryParse(json['returnedQuantity']?.toString() ?? '0') ?? 0.0,
      unit: json['unit']?.toString() ?? 'pcs',
      rate: double.tryParse(json['rate']?.toString() ?? '0') ?? 0.0,
      discountAmount: double.tryParse(json['discountAmount']?.toString() ?? '0') ?? 0.0,
      gstPercent: double.tryParse(json['gstPercent']?.toString() ?? '18') ?? 18.0,
      taxableAmount: double.tryParse(json['taxableAmount']?.toString() ?? '0'),
      cgstAmount: double.tryParse(json['cgstAmount']?.toString() ?? '0'),
      sgstAmount: double.tryParse(json['sgstAmount']?.toString() ?? '0'),
      igstAmount: double.tryParse(json['igstAmount']?.toString() ?? '0'),
      lineTotal: double.tryParse(json['lineTotal']?.toString() ?? '0') ?? 0.0,
      productCondition: json['productCondition']?.toString(),
      returnCondition: _enumFromName<ReturnCondition>(json['returnCondition'], ReturnCondition.values),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'finishedProductId': finishedProductId,
      if (finishedProductName.isNotEmpty) 'finishedProductName': finishedProductName,
      if (finishedProductCode.isNotEmpty) 'finishedProductCode': finishedProductCode,
      if (productDescription.isNotEmpty) 'productDescription': productDescription,
      'quantity': quantity,
      'rate': rate,
      'discountAmount': discountAmount,
      'gstPercent': gstPercent,
      if (returnCondition != null) 'returnCondition': returnCondition!.name,
    };
  }

  SaleLineItem copyWith({
    String? finishedProductId,
    String? finishedProductName,
    String? finishedProductCode,
    String? productDescription,
    double? quantity,
    double? reservedQuantity,
    double? producedQuantity,
    double? deliveredQuantity,
    double? invoicedQuantity,
    double? returnedQuantity,
    String? unit,
    double? rate,
    double? discountAmount,
    double? gstPercent,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    double? lineTotal,
    String? productCondition,
    ReturnCondition? returnCondition,
  }) {
    return SaleLineItem(
      finishedProductId: finishedProductId ?? this.finishedProductId,
      finishedProductName: finishedProductName ?? this.finishedProductName,
      finishedProductCode: finishedProductCode ?? this.finishedProductCode,
      productDescription: productDescription ?? this.productDescription,
      quantity: quantity ?? this.quantity,
      reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      producedQuantity: producedQuantity ?? this.producedQuantity,
      deliveredQuantity: deliveredQuantity ?? this.deliveredQuantity,
      invoicedQuantity: invoicedQuantity ?? this.invoicedQuantity,
      returnedQuantity: returnedQuantity ?? this.returnedQuantity,
      unit: unit ?? this.unit,
      rate: rate ?? this.rate,
      discountAmount: discountAmount ?? this.discountAmount,
      gstPercent: gstPercent ?? this.gstPercent,
      taxableAmount: taxableAmount ?? this.taxableAmount,
      cgstAmount: cgstAmount ?? this.cgstAmount,
      sgstAmount: sgstAmount ?? this.sgstAmount,
      igstAmount: igstAmount ?? this.igstAmount,
      lineTotal: lineTotal ?? this.lineTotal,
      productCondition: productCondition ?? this.productCondition,
      returnCondition: returnCondition ?? this.returnCondition,
    );
  }
}

class Sale {
  final String id;
  final String invoiceNumber; // Unique document code e.g. QT-2026-001, PI-2026-001, SO-2026-001, INV-2026-001
  final SalesDocumentType documentType;
  final PartyType partyType;
  final String partyId; // Customer ID or Dealer ID
  final String partyName;
  final String? customerContactPerson;
  final String? customerMobile;
  final String? customerEmail;
  final String? customerGstNumber;
  final String? billingAddress;
  final String? shippingAddress;
  final String? projectId;
  final String? projectName;
  final String? architectId;
  final String? architectName;
  final String? salesExecutive;
  final DateTime saleDate;
  final List<SaleLineItem> items;
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
  final SaleStatus status;
  final double architectCommissionAmount;
  final String? notes;
  final String? termsAndConditions;
  final String? bankDetails;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? validUntil;
  
  // Lineage and Revision Tracking
  final int revisionNumber;
  final String? originalQuotationId;
  final String? parentQuotationId;
  final String? parentQuotationNumber;
  final QuotationStatus? quotationStatus;
  
  final ProformaStatus? proformaStatus;
  final String? proformaReferenceId;
  final String? proformaNumber;

  final String? salesOrderNumber;
  final String? salesOrderReferenceId;
  final DateTime? deliveryDate;
  final SalesOrderStatus? salesOrderStatus;
  
  final DeliveryStatus? deliveryStatus;
  final String? deliveryNumber;
  final String? vehicleNumber;
  final String? driverContact;
  final String? courierName;
  final String? trackingNumber;
  final DateTime? expectedDeliveryDate;
  final String? courierContact;
  final String? dispatchNotes;
  
  // Architect-Customer dual linkage
  final bool isArchitectCustomer;
  final String? linkedArchitectCustomerId;
  
  // Inter-State vs Intra-State GST Tax mode
  final bool isInterStateTax;
  
  final List<String> linkedDeliveryIds;
  final List<String> linkedProductionOrderIds;
  final List<String> linkedPaymentIds;

  final SalesReturnStatus? salesReturnStatus;
  final ReturnCondition? returnCondition;
  final ReturnFinancialAction? returnFinancialAction;
  final ReturnType? returnType;
  final RefundStatus? refundStatus;
  final double refundAmount;
  final PaymentMode? refundPaymentMode;
  final String? refundTransactionRef;
  final DateTime? refundDate;
  final bool isProcessed;
  final List<String> linkedStockMovementIds;
  final List<String> linkedStockAdjustmentIds;
  final List<String> linkedReturnIds;
  final String? linkedRefundPaymentId;
  final double commissionAdjustmentAmount;
  final double projectAdjustmentAmount;
  final String? createdBy;
  final String? originalInvoiceId;
  final String? originalInvoiceNumber;
  final String? returnReason;
  final String? quotationReferenceId;
  final String? attachmentUrl;
  final List<DocumentActivityLog> activityLogs;

  Sale({
    required this.id,
    required this.invoiceNumber,
    required this.documentType,
    required this.partyType,
    required this.partyId,
    required this.partyName,
    this.customerContactPerson,
    this.customerMobile,
    this.customerEmail,
    this.customerGstNumber,
    this.billingAddress,
    this.shippingAddress,
    this.projectId,
    this.projectName,
    this.architectId,
    this.architectName,
    this.salesExecutive,
    required this.saleDate,
    required this.items,
    required this.subtotalAmount,
    this.discountAmount = 0.0,
    double? taxableAmount,
    double? cgstAmount,
    double? sgstAmount,
    double? igstAmount,
    required this.gstAmount,
    required this.totalAmount,
    this.paidAmount = 0.0,
    required this.pendingAmount,
    required this.paymentMode,
    required this.status,
    this.architectCommissionAmount = 0.0,
    this.notes,
    this.termsAndConditions,
    this.bankDetails,
    required this.createdAt,
    this.updatedAt,
    this.validUntil,
    this.revisionNumber = 0,
    this.originalQuotationId,
    this.parentQuotationId,
    this.parentQuotationNumber,
    this.quotationStatus,
    this.proformaStatus,
    this.proformaReferenceId,
    this.proformaNumber,
    this.salesOrderNumber,
    this.salesOrderReferenceId,
    this.deliveryDate,
    this.salesOrderStatus,
    this.deliveryStatus,
    this.deliveryNumber,
    this.vehicleNumber,
    this.driverContact,
    this.courierName,
    this.trackingNumber,
    this.expectedDeliveryDate,
    this.courierContact,
    this.dispatchNotes,
    this.isArchitectCustomer = false,
    this.linkedArchitectCustomerId,
    this.isInterStateTax = false,
    this.linkedDeliveryIds = const [],
    this.linkedProductionOrderIds = const [],
    this.linkedPaymentIds = const [],
    this.salesReturnStatus,
    this.returnCondition,
    this.returnFinancialAction,
    this.returnType,
    this.refundStatus,
    this.refundAmount = 0.0,
    this.refundPaymentMode,
    this.refundTransactionRef,
    this.refundDate,
    this.isProcessed = false,
    this.linkedStockMovementIds = const [],
    this.linkedStockAdjustmentIds = const [],
    this.linkedReturnIds = const [],
    this.linkedRefundPaymentId,
    this.commissionAdjustmentAmount = 0.0,
    this.projectAdjustmentAmount = 0.0,
    this.createdBy,
    this.originalInvoiceId,
    this.originalInvoiceNumber,
    this.returnReason,
    this.quotationReferenceId,
    this.attachmentUrl,
    this.activityLogs = const [],
  })  : taxableAmount = taxableAmount ?? (subtotalAmount - discountAmount).clamp(0.0, double.infinity),
        cgstAmount = cgstAmount ?? (isInterStateTax ? 0.0 : gstAmount / 2),
        sgstAmount = sgstAmount ?? (isInterStateTax ? 0.0 : gstAmount / 2),
        igstAmount = igstAmount ?? (isInterStateTax ? gstAmount : 0.0);

  String get statusLabel {
    switch (documentType) {
      case SalesDocumentType.quotation:
        return quotationStatusLabel;
      case SalesDocumentType.proformaInvoice:
        return proformaStatusLabel;
      case SalesDocumentType.salesOrder:
        return salesOrderStatusLabel;
      case SalesDocumentType.delivery:
        return deliveryStatusLabel;
      case SalesDocumentType.salesReturn:
        return salesReturnStatusLabel;
      case SalesDocumentType.invoice:
        switch (status) {
          case SaleStatus.draft:
            return 'Draft';
          case SaleStatus.active:
            return 'Issued / Active';
          case SaleStatus.partialPaid:
            return 'Partially Paid';
          case SaleStatus.paid:
            return 'Paid';
          case SaleStatus.overdue:
            return 'Overdue';
          case SaleStatus.completed:
            return 'Completed';
          case SaleStatus.cancelled:
            return 'Cancelled';
        }
    }
  }

  String get quotationStatusLabel {
    switch (quotationStatus ?? QuotationStatus.draft) {
      case QuotationStatus.draft:
        return 'Draft';
      case QuotationStatus.sent:
        return 'Sent';
      case QuotationStatus.accepted:
      case QuotationStatus.approved:
        return 'Accepted';
      case QuotationStatus.rejected:
        return 'Rejected';
      case QuotationStatus.expired:
        return 'Expired';
      case QuotationStatus.superseded:
        return 'Superseded (Rev $revisionNumber)';
      case QuotationStatus.converted:
        return 'Converted';
      case QuotationStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get proformaStatusLabel {
    switch (proformaStatus ?? ProformaStatus.draft) {
      case ProformaStatus.draft:
        return 'Draft';
      case ProformaStatus.issued:
        return 'Issued';
      case ProformaStatus.partialPaid:
        return 'Partially Paid';
      case ProformaStatus.paid:
        return 'Paid';
      case ProformaStatus.converted:
        return 'Converted to SO';
      case ProformaStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get salesOrderStatusLabel {
    switch (salesOrderStatus ?? SalesOrderStatus.draft) {
      case SalesOrderStatus.draft:
        return 'Draft';
      case SalesOrderStatus.pending:
        return 'Pending';
      case SalesOrderStatus.confirmed:
        return 'Confirmed';
      case SalesOrderStatus.stockAllocationPending:
        return 'Allocation Pending';
      case SalesOrderStatus.productionPending:
      case SalesOrderStatus.inProduction:
        return 'In Production';
      case SalesOrderStatus.readyForDispatch:
        return 'Ready for Dispatch';
      case SalesOrderStatus.partiallyDelivered:
        return 'Partially Delivered';
      case SalesOrderStatus.dispatched:
        return 'Dispatched';
      case SalesOrderStatus.delivered:
        return 'Delivered';
      case SalesOrderStatus.completed:
      case SalesOrderStatus.done:
        return 'Completed';
      case SalesOrderStatus.onHold:
        return 'On Hold';
      case SalesOrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get deliveryStatusLabel {
    switch (deliveryStatus ?? DeliveryStatus.draft) {
      case DeliveryStatus.draft:
        return 'Draft';
      case DeliveryStatus.dispatched:
        return 'Dispatched';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get salesReturnStatusLabel {
    switch (salesReturnStatus ?? SalesReturnStatus.draft) {
      case SalesReturnStatus.draft:
        return 'Draft';
      case SalesReturnStatus.submitted:
        return 'Submitted';
      case SalesReturnStatus.itemsReceived:
        return 'Items Received';
      case SalesReturnStatus.inspection:
        return 'Under Inspection';
      case SalesReturnStatus.approved:
        return 'Approved';
      case SalesReturnStatus.completed:
        return 'Completed';
      case SalesReturnStatus.rejected:
        return 'Rejected';
      case SalesReturnStatus.pending:
        return 'Pending Review';
      case SalesReturnStatus.requested:
        return 'Requested';
    }
  }

  String? get qaNotes => notes;
  String? get referenceDocumentId => originalInvoiceId ?? salesOrderReferenceId ?? proformaReferenceId ?? quotationReferenceId;

  String get refundStatusLabel {
    switch (refundStatus ?? RefundStatus.notRequired) {
      case RefundStatus.notRequired:
        return 'Not Required';
      case RefundStatus.pending:
        return 'Refund Pending';
      case RefundStatus.approved:
        return 'Refund Approved';
      case RefundStatus.processed:
        return 'Refund Processed';
      case RefundStatus.cancelled:
        return 'Refund Cancelled';
    }
  }

  double get totalReturnedQuantity => items.fold(0.0, (sum, i) => sum + i.returnedQuantity);

  InvoiceReturnIndicator get invoiceReturnStatus {
    final totalInvoiced = items.fold(0.0, (sum, i) => sum + i.quantity);
    final totalRet = totalReturnedQuantity;
    if (totalRet <= 0) return InvoiceReturnIndicator.noReturn;
    if (totalRet >= totalInvoiced && totalInvoiced > 0) return InvoiceReturnIndicator.fullyReturned;
    return InvoiceReturnIndicator.partiallyReturned;
  }

  String get invoiceReturnStatusLabel {
    switch (invoiceReturnStatus) {
      case InvoiceReturnIndicator.noReturn:
        return 'No Return';
      case InvoiceReturnIndicator.partiallyReturned:
        return 'Partially Returned';
      case InvoiceReturnIndicator.fullyReturned:
        return 'Fully Returned';
    }
  }

  bool get isQuotationValid =>
      validUntil == null || validUntil!.isAfter(DateTime.now().subtract(const Duration(days: 1)));

  Sale copyWith({
    String? id,
    String? invoiceNumber,
    SalesDocumentType? documentType,
    PartyType? partyType,
    String? partyId,
    String? partyName,
    String? customerContactPerson,
    String? customerMobile,
    String? customerEmail,
    String? customerGstNumber,
    String? billingAddress,
    String? shippingAddress,
    String? projectId,
    String? projectName,
    String? architectId,
    String? architectName,
    String? salesExecutive,
    DateTime? saleDate,
    List<SaleLineItem>? items,
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
    SaleStatus? status,
    double? architectCommissionAmount,
    String? notes,
    String? termsAndConditions,
    String? bankDetails,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? validUntil,
    int? revisionNumber,
    String? originalQuotationId,
    String? parentQuotationId,
    String? parentQuotationNumber,
    QuotationStatus? quotationStatus,
    ProformaStatus? proformaStatus,
    String? proformaReferenceId,
    String? proformaNumber,
    String? salesOrderNumber,
    String? salesOrderReferenceId,
    DateTime? deliveryDate,
    SalesOrderStatus? salesOrderStatus,
    DeliveryStatus? deliveryStatus,
    String? deliveryNumber,
    String? vehicleNumber,
    String? driverContact,
    String? courierName,
    String? trackingNumber,
    DateTime? expectedDeliveryDate,
    String? courierContact,
    String? dispatchNotes,
    bool? isArchitectCustomer,
    String? linkedArchitectCustomerId,
    bool? isInterStateTax,
    List<String>? linkedDeliveryIds,
    List<String>? linkedProductionOrderIds,
    List<String>? linkedPaymentIds,
    SalesReturnStatus? salesReturnStatus,
    ReturnCondition? returnCondition,
    ReturnFinancialAction? returnFinancialAction,
    ReturnType? returnType,
    RefundStatus? refundStatus,
    double? refundAmount,
    PaymentMode? refundPaymentMode,
    String? refundTransactionRef,
    DateTime? refundDate,
    bool? isProcessed,
    List<String>? linkedStockMovementIds,
    List<String>? linkedStockAdjustmentIds,
    List<String>? linkedReturnIds,
    String? linkedRefundPaymentId,
    double? commissionAdjustmentAmount,
    double? projectAdjustmentAmount,
    String? createdBy,
    String? originalInvoiceId,
    String? originalInvoiceNumber,
    String? returnReason,
    String? quotationReferenceId,
    String? attachmentUrl,
    List<DocumentActivityLog>? activityLogs,
  }) {
    return Sale(
      id: id ?? this.id,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      documentType: documentType ?? this.documentType,
      partyType: partyType ?? this.partyType,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      customerContactPerson: customerContactPerson ?? this.customerContactPerson,
      customerMobile: customerMobile ?? this.customerMobile,
      customerEmail: customerEmail ?? this.customerEmail,
      customerGstNumber: customerGstNumber ?? this.customerGstNumber,
      billingAddress: billingAddress ?? this.billingAddress,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      architectId: architectId ?? this.architectId,
      architectName: architectName ?? this.architectName,
      salesExecutive: salesExecutive ?? this.salesExecutive,
      saleDate: saleDate ?? this.saleDate,
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
      architectCommissionAmount: architectCommissionAmount ?? this.architectCommissionAmount,
      notes: notes ?? this.notes,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      bankDetails: bankDetails ?? this.bankDetails,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      validUntil: validUntil ?? this.validUntil,
      revisionNumber: revisionNumber ?? this.revisionNumber,
      originalQuotationId: originalQuotationId ?? this.originalQuotationId,
      parentQuotationId: parentQuotationId ?? this.parentQuotationId,
      parentQuotationNumber: parentQuotationNumber ?? this.parentQuotationNumber,
      quotationStatus: quotationStatus ?? this.quotationStatus,
      proformaStatus: proformaStatus ?? this.proformaStatus,
      proformaReferenceId: proformaReferenceId ?? this.proformaReferenceId,
      proformaNumber: proformaNumber ?? this.proformaNumber,
      salesOrderNumber: salesOrderNumber ?? this.salesOrderNumber,
      salesOrderReferenceId: salesOrderReferenceId ?? this.salesOrderReferenceId,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      salesOrderStatus: salesOrderStatus ?? this.salesOrderStatus,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      deliveryNumber: deliveryNumber ?? this.deliveryNumber,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      driverContact: driverContact ?? this.driverContact,
      courierName: courierName ?? this.courierName,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
      courierContact: courierContact ?? this.courierContact,
      dispatchNotes: dispatchNotes ?? this.dispatchNotes,
      isArchitectCustomer: isArchitectCustomer ?? this.isArchitectCustomer,
      linkedArchitectCustomerId: linkedArchitectCustomerId ?? this.linkedArchitectCustomerId,
      isInterStateTax: isInterStateTax ?? this.isInterStateTax,
      linkedDeliveryIds: linkedDeliveryIds ?? this.linkedDeliveryIds,
      linkedProductionOrderIds: linkedProductionOrderIds ?? this.linkedProductionOrderIds,
      linkedPaymentIds: linkedPaymentIds ?? this.linkedPaymentIds,
      salesReturnStatus: salesReturnStatus ?? this.salesReturnStatus,
      returnCondition: returnCondition ?? this.returnCondition,
      returnFinancialAction: returnFinancialAction ?? this.returnFinancialAction,
      returnType: returnType ?? this.returnType,
      refundStatus: refundStatus ?? this.refundStatus,
      refundAmount: refundAmount ?? this.refundAmount,
      refundPaymentMode: refundPaymentMode ?? this.refundPaymentMode,
      refundTransactionRef: refundTransactionRef ?? this.refundTransactionRef,
      refundDate: refundDate ?? this.refundDate,
      isProcessed: isProcessed ?? this.isProcessed,
      linkedStockMovementIds: linkedStockMovementIds ?? this.linkedStockMovementIds,
      linkedStockAdjustmentIds: linkedStockAdjustmentIds ?? this.linkedStockAdjustmentIds,
      linkedReturnIds: linkedReturnIds ?? this.linkedReturnIds,
      linkedRefundPaymentId: linkedRefundPaymentId ?? this.linkedRefundPaymentId,
      commissionAdjustmentAmount: commissionAdjustmentAmount ?? this.commissionAdjustmentAmount,
      projectAdjustmentAmount: projectAdjustmentAmount ?? this.projectAdjustmentAmount,
      createdBy: createdBy ?? this.createdBy,
      originalInvoiceId: originalInvoiceId ?? this.originalInvoiceId,
      originalInvoiceNumber: originalInvoiceNumber ?? this.originalInvoiceNumber,
      returnReason: returnReason ?? this.returnReason,
      quotationReferenceId: quotationReferenceId ?? this.quotationReferenceId,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      activityLogs: activityLogs ?? this.activityLogs,
    );
  }

  factory Sale.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final parsedItems = rawItems
        .map((i) => SaleLineItem.fromJson(i as Map<String, dynamic>))
        .toList();

    DateTime? parseDate(dynamic val) => val != null ? DateTime.tryParse(val.toString()) : null;

    return Sale(
      id: json['id']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      documentType: _enumFromName<SalesDocumentType>(json['documentType'], SalesDocumentType.values) ?? SalesDocumentType.quotation,
      partyType: _enumFromName<PartyType>(json['partyType'], PartyType.values) ?? PartyType.customer,
      partyId: json['partyId']?.toString() ?? '',
      partyName: json['partyName']?.toString() ?? '',
      customerContactPerson: json['customerContactPerson']?.toString(),
      customerMobile: json['customerMobile']?.toString(),
      customerEmail: json['customerEmail']?.toString(),
      customerGstNumber: json['customerGstNumber']?.toString(),
      billingAddress: json['billingAddress']?.toString(),
      shippingAddress: json['shippingAddress']?.toString(),
      projectId: json['projectId']?.toString(),
      projectName: json['projectName']?.toString(),
      architectId: json['architectId']?.toString(),
      architectName: json['architectName']?.toString(),
      salesExecutive: json['salesExecutive']?.toString(),
      saleDate: parseDate(json['saleDate']) ?? DateTime.now(),
      items: parsedItems,
      subtotalAmount: double.tryParse(json['subtotalAmount']?.toString() ?? '0') ?? 0.0,
      discountAmount: double.tryParse(json['discountAmount']?.toString() ?? '0') ?? 0.0,
      taxableAmount: double.tryParse(json['taxableAmount']?.toString() ?? '0'),
      cgstAmount: double.tryParse(json['cgstAmount']?.toString() ?? '0'),
      sgstAmount: double.tryParse(json['sgstAmount']?.toString() ?? '0'),
      igstAmount: double.tryParse(json['igstAmount']?.toString() ?? '0'),
      gstAmount: double.tryParse(json['gstAmount']?.toString() ?? '0') ?? 0.0,
      totalAmount: double.tryParse(json['totalAmount']?.toString() ?? '0') ?? 0.0,
      paidAmount: double.tryParse(json['paidAmount']?.toString() ?? '0') ?? 0.0,
      pendingAmount: double.tryParse(json['pendingAmount']?.toString() ?? '0') ?? 0.0,
      paymentMode: _enumFromName<PaymentMode>(json['paymentMode'], PaymentMode.values) ?? PaymentMode.credit,
      status: _enumFromName<SaleStatus>(json['status'], SaleStatus.values) ?? SaleStatus.draft,
      architectCommissionAmount: double.tryParse(json['architectCommissionAmount']?.toString() ?? '0') ?? 0.0,
      notes: json['notes']?.toString(),
      termsAndConditions: json['termsAndConditions']?.toString(),
      bankDetails: json['bankDetails']?.toString(),
      createdAt: parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(json['updatedAt']),
      validUntil: parseDate(json['validUntil']),
      revisionNumber: int.tryParse(json['revisionNumber']?.toString() ?? '0') ?? 0,
      originalQuotationId: json['originalQuotationId']?.toString(),
      parentQuotationId: json['parentQuotationId']?.toString(),
      parentQuotationNumber: json['parentQuotationNumber']?.toString(),
      quotationStatus: _enumFromName<QuotationStatus>(json['quotationStatus'], QuotationStatus.values),
      proformaStatus: _enumFromName<ProformaStatus>(json['proformaStatus'], ProformaStatus.values),
      proformaReferenceId: json['proformaReferenceId']?.toString(),
      proformaNumber: json['proformaNumber']?.toString(),
      salesOrderNumber: json['salesOrderNumber']?.toString(),
      salesOrderReferenceId: json['salesOrderReferenceId']?.toString(),
      deliveryDate: parseDate(json['deliveryDate']),
      salesOrderStatus: _enumFromName<SalesOrderStatus>(json['salesOrderStatus'], SalesOrderStatus.values),
      deliveryStatus: _enumFromName<DeliveryStatus>(json['deliveryStatus'], DeliveryStatus.values),
      deliveryNumber: json['deliveryNumber']?.toString(),
      vehicleNumber: json['vehicleNumber']?.toString(),
      driverContact: json['driverContact']?.toString(),
      courierName: json['courierName']?.toString(),
      trackingNumber: json['trackingNumber']?.toString(),
      expectedDeliveryDate: parseDate(json['expectedDeliveryDate']),
      courierContact: json['courierContact']?.toString(),
      dispatchNotes: json['dispatchNotes']?.toString(),
      isInterStateTax: json['isInterStateTax'] == true || json['isInterStateTax']?.toString() == 'true',
      salesReturnStatus: _enumFromName<SalesReturnStatus>(json['salesReturnStatus'], SalesReturnStatus.values),
      returnCondition: _enumFromName<ReturnCondition>(json['returnCondition'], ReturnCondition.values),
      returnFinancialAction: _enumFromName<ReturnFinancialAction>(json['returnFinancialAction'], ReturnFinancialAction.values),
      returnType: _enumFromName<ReturnType>(json['returnType'], ReturnType.values),
      refundStatus: _enumFromName<RefundStatus>(json['refundStatus'], RefundStatus.values),
      refundAmount: double.tryParse(json['refundAmount']?.toString() ?? '0') ?? 0.0,
      refundPaymentMode: _enumFromName<PaymentMode>(json['refundPaymentMode'], PaymentMode.values),
      refundTransactionRef: json['refundTransactionRef']?.toString(),
      refundDate: parseDate(json['refundDate']),
      isProcessed: json['isProcessed'] == true || json['isProcessed']?.toString() == 'true',
      createdBy: json['createdBy']?.toString(),
      originalInvoiceId: json['originalInvoiceId']?.toString(),
      originalInvoiceNumber: json['originalInvoiceNumber']?.toString(),
      returnReason: json['returnReason']?.toString(),
      quotationReferenceId: json['quotationReferenceId']?.toString(),
      attachmentUrl: json['attachmentUrl']?.toString(),
    );
  }
}

/// Parses a backend enum string into its matching Dart enum value by name,
/// returning null when absent or unrecognized (caller supplies the default).
T? _enumFromName<T extends Enum>(dynamic val, List<T> values) {
  if (val == null) return null;
  final str = val.toString();
  for (final v in values) {
    if (v.name == str) return v;
  }
  return null;
}
