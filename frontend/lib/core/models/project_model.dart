enum ProjectStatus {
  planned,
  active,
  completed,
  closed,
  cancelled,
}

class Project {
  final String id;
  final String projectCode;
  final String name;
  final String? customerId;
  final String? customerName;
  final String? dealerId;
  final String? dealerName;
  final String? architectId;
  final String? architectName;
  final DateTime startDate;
  final DateTime? expectedCompletionDate;
  final DateTime? actualCompletionDate;
  final ProjectStatus status;
  final double budgetAmount;
  final double totalSalesAmount;
  final double totalCommissionAmount;
  final String? notes;
  final bool isDeleted;
  final String? deleteReason;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Project({
    required this.id,
    this.projectCode = '',
    required this.name,
    this.customerId,
    this.customerName,
    this.dealerId,
    this.dealerName,
    this.architectId,
    this.architectName,
    required this.startDate,
    this.expectedCompletionDate,
    this.actualCompletionDate,
    required this.status,
    this.budgetAmount = 0.0,
    this.totalSalesAmount = 0.0,
    this.totalCommissionAmount = 0.0,
    this.notes,
    this.isDeleted = false,
    this.deleteReason,
    required this.createdAt,
    this.updatedAt,
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
      case ProjectStatus.cancelled:
        return 'Cancelled';
    }
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    ProjectStatus parseStatus(String? val) {
      switch (val?.toLowerCase()) {
        case 'planned':
          return ProjectStatus.planned;
        case 'active':
          return ProjectStatus.active;
        case 'completed':
          return ProjectStatus.completed;
        case 'closed':
          return ProjectStatus.closed;
        case 'cancelled':
          return ProjectStatus.cancelled;
        default:
          return ProjectStatus.active;
      }
    }

    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val == null) return fallback ?? DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? (fallback ?? DateTime.now());
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    double parseNum(dynamic val) {
      if (val == null) return 0.0;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString()) ?? 0.0;
    }

    return Project(
      id: json['id']?.toString() ?? '',
      projectCode: json['projectCode']?.toString() ?? json['project_code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? json['customer_id']?.toString(),
      customerName: json['customerName']?.toString() ?? json['customer_name']?.toString(),
      dealerId: json['dealerId']?.toString() ?? json['dealer_id']?.toString(),
      dealerName: json['dealerName']?.toString() ?? json['dealer_name']?.toString(),
      architectId: json['architectId']?.toString() ?? json['architect_id']?.toString(),
      architectName: json['architectName']?.toString() ?? json['architect_name']?.toString(),
      startDate: parseDate(json['startDate'] ?? json['start_date']),
      expectedCompletionDate: parseNullableDate(json['expectedCompletionDate'] ?? json['expected_completion_date']),
      actualCompletionDate: parseNullableDate(json['actualCompletionDate'] ?? json['actual_completion_date']),
      status: parseStatus(json['status']?.toString()),
      budgetAmount: parseNum(json['budgetAmount'] ?? json['budget_amount']),
      totalSalesAmount: parseNum(json['totalSalesAmount'] ?? json['total_sales_amount']),
      totalCommissionAmount: parseNum(json['totalCommissionAmount'] ?? json['total_commission_amount']),
      notes: json['notes']?.toString(),
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true,
      deleteReason: json['deleteReason']?.toString() ?? json['delete_reason']?.toString(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseNullableDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (customerId != null) 'customerId': customerId,
      if (dealerId != null) 'dealerId': dealerId,
      if (architectId != null) 'architectId': architectId,
      'startDate': startDate.toIso8601String().split('T')[0],
      if (expectedCompletionDate != null)
        'expectedCompletionDate': expectedCompletionDate!.toIso8601String().split('T')[0],
      if (actualCompletionDate != null)
        'actualCompletionDate': actualCompletionDate!.toIso8601String().split('T')[0],
      'status': status.name,
      'budgetAmount': budgetAmount,
      if (notes != null) 'notes': notes,
    };
  }

  Project copyWith({
    String? id,
    String? projectCode,
    String? name,
    String? customerId,
    String? customerName,
    String? dealerId,
    String? dealerName,
    String? architectId,
    String? architectName,
    DateTime? startDate,
    DateTime? expectedCompletionDate,
    DateTime? actualCompletionDate,
    ProjectStatus? status,
    double? budgetAmount,
    double? totalSalesAmount,
    double? totalCommissionAmount,
    String? notes,
    bool? isDeleted,
    String? deleteReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Project(
      id: id ?? this.id,
      projectCode: projectCode ?? this.projectCode,
      name: name ?? this.name,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      dealerId: dealerId ?? this.dealerId,
      dealerName: dealerName ?? this.dealerName,
      architectId: architectId ?? this.architectId,
      architectName: architectName ?? this.architectName,
      startDate: startDate ?? this.startDate,
      expectedCompletionDate: expectedCompletionDate ?? this.expectedCompletionDate,
      actualCompletionDate: actualCompletionDate ?? this.actualCompletionDate,
      status: status ?? this.status,
      budgetAmount: budgetAmount ?? this.budgetAmount,
      totalSalesAmount: totalSalesAmount ?? this.totalSalesAmount,
      totalCommissionAmount: totalCommissionAmount ?? this.totalCommissionAmount,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
      deleteReason: deleteReason ?? this.deleteReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
