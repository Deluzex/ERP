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
}
