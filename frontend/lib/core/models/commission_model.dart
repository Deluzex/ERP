enum CommissionStatus {
  generated,
  approved,
  paid,
  rejected,
}

class ArchitectCommission {
  final String id;
  final String commissionNumber; // e.g. COM-2026-001
  final String architectId;
  final String architectName;
  final String saleInvoiceId;
  final String saleInvoiceNumber;
  final String? projectId;
  final String? projectName;
  final double saleAmount;
  final double commissionRate; // e.g. 5.0%
  final double commissionAmount;
  final CommissionStatus status;
  final DateTime generatedDate;
  final DateTime? approvedDate;
  final DateTime? paidDate;
  final String? paymentReference;
  final String? notes;

  ArchitectCommission({
    required this.id,
    required this.commissionNumber,
    required this.architectId,
    required this.architectName,
    required this.saleInvoiceId,
    required this.saleInvoiceNumber,
    this.projectId,
    this.projectName,
    required this.saleAmount,
    required this.commissionRate,
    required this.commissionAmount,
    required this.status,
    required this.generatedDate,
    this.approvedDate,
    this.paidDate,
    this.paymentReference,
    this.notes,
  });

  String get statusLabel {
    switch (status) {
      case CommissionStatus.generated:
        return 'Generated / Pending Review';
      case CommissionStatus.approved:
        return 'Approved';
      case CommissionStatus.paid:
        return 'Paid';
      case CommissionStatus.rejected:
        return 'Rejected';
    }
  }

  ArchitectCommission copyWith({
    String? id,
    String? commissionNumber,
    String? architectId,
    String? architectName,
    String? saleInvoiceId,
    String? saleInvoiceNumber,
    String? projectId,
    String? projectName,
    double? saleAmount,
    double? commissionRate,
    double? commissionAmount,
    CommissionStatus? status,
    DateTime? generatedDate,
    DateTime? approvedDate,
    DateTime? paidDate,
    String? paymentReference,
    String? notes,
  }) {
    return ArchitectCommission(
      id: id ?? this.id,
      commissionNumber: commissionNumber ?? this.commissionNumber,
      architectId: architectId ?? this.architectId,
      architectName: architectName ?? this.architectName,
      saleInvoiceId: saleInvoiceId ?? this.saleInvoiceId,
      saleInvoiceNumber: saleInvoiceNumber ?? this.saleInvoiceNumber,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      saleAmount: saleAmount ?? this.saleAmount,
      commissionRate: commissionRate ?? this.commissionRate,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      status: status ?? this.status,
      generatedDate: generatedDate ?? this.generatedDate,
      approvedDate: approvedDate ?? this.approvedDate,
      paidDate: paidDate ?? this.paidDate,
      paymentReference: paymentReference ?? this.paymentReference,
      notes: notes ?? this.notes,
    );
  }
}
