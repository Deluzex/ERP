enum ProjectStatus {
  planned,
  active,
  completed,
  closed,
}

class Project {
  final String id;
  final String name;
  final String? customerId;
  final String? customerName;
  final String? dealerId;
  final String? dealerName;
  final String? architectId;
  final String? architectName;
  final DateTime startDate;
  final DateTime expectedCompletionDate;
  final ProjectStatus status;
  final double totalSalesAmount;
  final double totalCommissionAmount;
  final String? notes;
  final DateTime createdAt;

  Project({
    required this.id,
    required this.name,
    this.customerId,
    this.customerName,
    this.dealerId,
    this.dealerName,
    this.architectId,
    this.architectName,
    required this.startDate,
    required this.expectedCompletionDate,
    required this.status,
    this.totalSalesAmount = 0.0,
    this.totalCommissionAmount = 0.0,
    this.notes,
    required this.createdAt,
  });

  String get statusLabel {
    switch (status) {
      case ProjectStatus.planned:
        return 'Planned';
      case ProjectStatus.active:
        return 'Active';
      case ProjectStatus.completed:
        return 'Completed';
      case ProjectStatus.closed:
        return 'Closed';
    }
  }

  Project copyWith({
    String? id,
    String? name,
    String? customerId,
    String? customerName,
    String? dealerId,
    String? dealerName,
    String? architectId,
    String? architectName,
    DateTime? startDate,
    DateTime? expectedCompletionDate,
    ProjectStatus? status,
    double? totalSalesAmount,
    double? totalCommissionAmount,
    String? notes,
    DateTime? createdAt,
  }) {
    return Project(
      id: id ?? this.id,
      name: name ?? this.name,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      dealerId: dealerId ?? this.dealerId,
      dealerName: dealerName ?? this.dealerName,
      architectId: architectId ?? this.architectId,
      architectName: architectName ?? this.architectName,
      startDate: startDate ?? this.startDate,
      expectedCompletionDate: expectedCompletionDate ?? this.expectedCompletionDate,
      status: status ?? this.status,
      totalSalesAmount: totalSalesAmount ?? this.totalSalesAmount,
      totalCommissionAmount: totalCommissionAmount ?? this.totalCommissionAmount,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
