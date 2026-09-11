enum ExpenseCategory {
  transportation,
  courier,
  fuel,
  labour,
  electricity,
  maintenance,
  officeExpense,
  productionExpense,
  projectExpense,
  other,
}

enum ExpensePaymentStatus {
  paid,
  partial,
  pending,
}

class Expense {
  final String id;
  final String expenseNumber; // e.g. EXP-2026-001
  final DateTime expenseDate;
  final String expenseName;
  final ExpenseCategory category;
  final double amount;
  final String paidBy;
  final String paymentMethod; // Cash, Bank Transfer, UPI, Cheque, Company Card
  final String? vendorPayee;
  final String? projectId;
  final String? projectName;
  final String? purchaseId;
  final String? purchaseNumber;
  final String? productionId;
  final String? productionNumber;
  final String? expenseReference;
  final String? description;
  final String? receiptAttachmentName;
  final ExpensePaymentStatus paymentStatus;
  final String createdBy;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.expenseNumber,
    required this.expenseDate,
    required this.expenseName,
    required this.category,
    required this.amount,
    required this.paidBy,
    required this.paymentMethod,
    this.vendorPayee,
    this.projectId,
    this.projectName,
    this.purchaseId,
    this.purchaseNumber,
    this.productionId,
    this.productionNumber,
    this.expenseReference,
    this.description,
    this.receiptAttachmentName,
    this.paymentStatus = ExpensePaymentStatus.paid,
    required this.createdBy,
    required this.createdAt,
  });

  String get categoryLabel {
    switch (category) {
      case ExpenseCategory.transportation:
        return 'Transportation';
      case ExpenseCategory.courier:
        return 'Courier & Freight';
      case ExpenseCategory.fuel:
        return 'Fuel & Travel';
      case ExpenseCategory.labour:
        return 'Direct Labour / Contractor';
      case ExpenseCategory.electricity:
        return 'Electricity & Utilities';
      case ExpenseCategory.maintenance:
        return 'Plant & Machinery Maintenance';
      case ExpenseCategory.officeExpense:
        return 'Office & Administrative';
      case ExpenseCategory.productionExpense:
        return 'Production Expense';
      case ExpenseCategory.projectExpense:
        return 'Project Site Expense';
      case ExpenseCategory.other:
        return 'Other Operational Expense';
    }
  }

  String get categoryName => categoryLabel;
  String get paymentMode => paymentMethod;

  String get paymentStatusLabel {
    switch (paymentStatus) {
      case ExpensePaymentStatus.paid:
        return 'Paid';
      case ExpensePaymentStatus.partial:
        return 'Partially Paid';
      case ExpensePaymentStatus.pending:
        return 'Pending';
    }
  }

  Expense copyWith({
    String? id,
    String? expenseNumber,
    DateTime? expenseDate,
    String? expenseName,
    ExpenseCategory? category,
    double? amount,
    String? paidBy,
    String? paymentMethod,
    String? vendorPayee,
    String? projectId,
    String? projectName,
    String? purchaseId,
    String? purchaseNumber,
    String? productionId,
    String? productionNumber,
    String? expenseReference,
    String? description,
    String? receiptAttachmentName,
    ExpensePaymentStatus? paymentStatus,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      expenseNumber: expenseNumber ?? this.expenseNumber,
      expenseDate: expenseDate ?? this.expenseDate,
      expenseName: expenseName ?? this.expenseName,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      vendorPayee: vendorPayee ?? this.vendorPayee,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      purchaseId: purchaseId ?? this.purchaseId,
      purchaseNumber: purchaseNumber ?? this.purchaseNumber,
      productionId: productionId ?? this.productionId,
      productionNumber: productionNumber ?? this.productionNumber,
      expenseReference: expenseReference ?? this.expenseReference,
      description: description ?? this.description,
      receiptAttachmentName: receiptAttachmentName ?? this.receiptAttachmentName,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
