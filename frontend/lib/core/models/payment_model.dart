import 'purchase_model.dart';

enum PaymentType {
  customerPayment,
  dealerPayment,
  vendorPayment,
  commissionPayment,
}

class ErpPayment {
  final String id;
  final String paymentNumber; // e.g. PAY-2026-001
  final PaymentType paymentType;
  final String partyId;
  final String partyName;
  final String? referenceDocumentId; // Invoice ID, Purchase ID, Commission ID
  final String? referenceDocumentNumber;
  final double amount;
  final PaymentMode paymentMode;
  final DateTime paymentDate;
  final String? transactionReference; // Cheque No / UPI Ref / Bank Ref
  final String? notes;
  final DateTime createdAt;
  final String? paymentStatus;
  final String? attachmentUrl;
  final bool isFullPayment;
  final double? totalDocumentAmount;
  final double? remainingAmount;
  final String? projectId;
  final String? projectName;

  ErpPayment({
    required this.id,
    required this.paymentNumber,
    required this.paymentType,
    required this.partyId,
    required this.partyName,
    this.referenceDocumentId,
    this.referenceDocumentNumber,
    required this.amount,
    required this.paymentMode,
    required this.paymentDate,
    this.transactionReference,
    this.notes,
    required this.createdAt,
    this.paymentStatus,
    this.attachmentUrl,
    this.isFullPayment = false,
    this.totalDocumentAmount,
    this.remainingAmount,
    this.projectId,
    this.projectName,
  });

  String get typeLabel {
    switch (paymentType) {
      case PaymentType.customerPayment:
        return 'Customer Receipt';
      case PaymentType.dealerPayment:
        return 'Dealer Receipt';
      case PaymentType.vendorPayment:
        return 'Vendor Payment';
      case PaymentType.commissionPayment:
        return 'Commission Payout';
    }
  }

  String get entryModeLabel => isFullPayment ? 'Full Payment' : 'Partial Payment';

  factory ErpPayment.fromJson(Map<String, dynamic> json) {
    PaymentType parseType(dynamic val) {
      final s = val?.toString();
      if (s == 'customerPayment' || s == 'customerReceipt') return PaymentType.customerPayment;
      if (s == 'dealerPayment') return PaymentType.dealerPayment;
      if (s == 'vendorPayment') return PaymentType.vendorPayment;
      if (s == 'commissionPayment') return PaymentType.commissionPayment;
      return PaymentType.customerPayment;
    }

    PaymentMode parseMode(dynamic val) {
      final s = val?.toString();
      for (final mode in PaymentMode.values) {
        if (mode.name.toLowerCase() == s?.toLowerCase()) return mode;
      }
      return PaymentMode.bankTransfer;
    }

    return ErpPayment(
      id: json['id']?.toString() ?? '',
      paymentNumber: json['paymentNumber']?.toString() ?? '',
      paymentType: parseType(json['paymentType']),
      partyId: json['partyId']?.toString() ?? '',
      partyName: json['partyName']?.toString() ?? '',
      referenceDocumentId: json['referenceDocumentId']?.toString(),
      referenceDocumentNumber: json['referenceDocumentNumber']?.toString(),
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      paymentMode: parseMode(json['paymentMode']),
      paymentDate: json['paymentDate'] != null ? DateTime.tryParse(json['paymentDate'].toString()) ?? DateTime.now() : DateTime.now(),
      transactionReference: json['transactionReference']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
      paymentStatus: json['paymentStatus']?.toString() ?? 'completed',
      attachmentUrl: json['attachmentUrl']?.toString(),
      isFullPayment: json['isFullPayment'] == true,
      totalDocumentAmount: json['totalDocumentAmount'] != null ? double.tryParse(json['totalDocumentAmount'].toString()) : null,
      remainingAmount: json['remainingAmount'] != null ? double.tryParse(json['remainingAmount'].toString()) : null,
      projectId: json['projectId']?.toString(),
      projectName: json['projectName']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paymentNumber': paymentNumber,
      'paymentType': paymentType.name,
      'partyId': partyId,
      'partyName': partyName,
      if (referenceDocumentId != null) 'referenceDocumentId': referenceDocumentId,
      if (referenceDocumentNumber != null) 'referenceDocumentNumber': referenceDocumentNumber,
      'amount': amount,
      'paymentMode': paymentMode.name,
      'paymentDate': paymentDate.toIso8601String(),
      if (transactionReference != null) 'transactionReference': transactionReference,
      if (notes != null) 'notes': notes,
      'paymentStatus': paymentStatus ?? 'completed',
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      'isFullPayment': isFullPayment,
      if (totalDocumentAmount != null) 'totalDocumentAmount': totalDocumentAmount,
      if (remainingAmount != null) 'remainingAmount': remainingAmount,
      if (projectId != null) 'projectId': projectId,
      if (projectName != null) 'projectName': projectName,
    };
  }

  ErpPayment copyWith({
    String? id,
    String? paymentNumber,
    PaymentType? paymentType,
    String? partyId,
    String? partyName,
    String? referenceDocumentId,
    String? referenceDocumentNumber,
    double? amount,
    PaymentMode? paymentMode,
    DateTime? paymentDate,
    String? transactionReference,
    String? notes,
    DateTime? createdAt,
    String? paymentStatus,
    String? attachmentUrl,
    bool? isFullPayment,
    double? totalDocumentAmount,
    double? remainingAmount,
    String? projectId,
    String? projectName,
  }) {
    return ErpPayment(
      id: id ?? this.id,
      paymentNumber: paymentNumber ?? this.paymentNumber,
      paymentType: paymentType ?? this.paymentType,
      partyId: partyId ?? this.partyId,
      partyName: partyName ?? this.partyName,
      referenceDocumentId: referenceDocumentId ?? this.referenceDocumentId,
      referenceDocumentNumber: referenceDocumentNumber ?? this.referenceDocumentNumber,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      paymentDate: paymentDate ?? this.paymentDate,
      transactionReference: transactionReference ?? this.transactionReference,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      isFullPayment: isFullPayment ?? this.isFullPayment,
      totalDocumentAmount: totalDocumentAmount ?? this.totalDocumentAmount,
      remainingAmount: remainingAmount ?? this.remainingAmount,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
    );
  }
}
