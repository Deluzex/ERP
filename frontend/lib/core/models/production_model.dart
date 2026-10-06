enum ProductionStatus {
  planned,
  inProgress,
  completed,
  cancelled,
}

class ProductionRawMaterialUsage {
  final String rawMaterialId;
  final String rawMaterialName;
  final String rawMaterialCode;
  final double quantityUsed;
  final String unit;
  final double unitCost;
  final double totalCost;

  ProductionRawMaterialUsage({
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.rawMaterialCode,
    required this.quantityUsed,
    required this.unit,
    required this.unitCost,
    required this.totalCost,
  });

  factory ProductionRawMaterialUsage.fromJson(Map<String, dynamic> json) {
    return ProductionRawMaterialUsage(
      rawMaterialId: json['rawMaterialId'] ?? json['raw_material_id'] ?? '',
      rawMaterialName: json['rawMaterialName'] ?? json['raw_material_name'] ?? '',
      rawMaterialCode: json['rawMaterialCode'] ?? json['raw_material_code'] ?? '',
      quantityUsed: (json['quantityUsed'] ?? json['quantity_used'] ?? 0).toDouble(),
      unit: json['unit'] ?? '',
      unitCost: (json['unitCost'] ?? json['unit_cost'] ?? 0).toDouble(),
      totalCost: (json['totalCost'] ?? json['total_cost'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rawMaterialId': rawMaterialId,
      'rawMaterialName': rawMaterialName,
      'rawMaterialCode': rawMaterialCode,
      'quantityUsed': quantityUsed,
      'unit': unit,
      'unitCost': unitCost,
      'totalCost': totalCost,
    };
  }
}

class ProductionOrder {
  final String id;
  final String productionNumber; // e.g. PRD-2026-001
  final String finishedProductId;
  final String finishedProductName;
  final String finishedProductCode;
  final String unit;
  final double plannedQuantity;
  final double actualQuantityProduced;
  final List<ProductionRawMaterialUsage> rawMaterialsUsed;
  final double rawMaterialCost;
  final double labourCost;
  final double otherExpenses;
  final double totalProductionCost;
  final double costPerUnit;
  final DateTime productionDate;
  final ProductionStatus status;
  final String? salesOrderId;
  final String? salesOrderNumber;
  final String? projectId;
  final String? projectName;
  final String? notes;
  final DateTime createdAt;
  final bool isDeleted;
  final String? deletedReason;
  final DateTime? deletedAt;

  ProductionOrder({
    required this.id,
    required this.productionNumber,
    required this.finishedProductId,
    required this.finishedProductName,
    required this.finishedProductCode,
    required this.unit,
    required this.plannedQuantity,
    this.actualQuantityProduced = 0.0,
    required this.rawMaterialsUsed,
    this.rawMaterialCost = 0.0,
    this.labourCost = 0.0,
    this.otherExpenses = 0.0,
    this.totalProductionCost = 0.0,
    this.costPerUnit = 0.0,
    required this.productionDate,
    required this.status,
    this.salesOrderId,
    this.salesOrderNumber,
    this.projectId,
    this.projectName,
    this.notes,
    required this.createdAt,
    this.isDeleted = false,
    this.deletedReason,
    this.deletedAt,
  });

  DateTime get orderDate => productionDate;
  double get targetQuantity => plannedQuantity;
  double get producedQuantity => actualQuantityProduced;

  String get statusLabel {
    switch (status) {
      case ProductionStatus.planned:
        return 'Waiting Approval';
      case ProductionStatus.inProgress:
        return 'In Progress';
      case ProductionStatus.completed:
        return 'Completed';
      case ProductionStatus.cancelled:
        return 'Cancelled';
    }
  }

  factory ProductionOrder.fromJson(Map<String, dynamic> json) {
    var rawMaterialsList = <ProductionRawMaterialUsage>[];
    final materialsRaw = json['rawMaterials'] ?? json['rawMaterialsUsed'];
    if (materialsRaw is List) {
      rawMaterialsList = materialsRaw
          .map((item) => ProductionRawMaterialUsage.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    ProductionStatus parsedStatus = ProductionStatus.planned;
    final statusStr = (json['status'] ?? '').toString().toLowerCase();
    if (statusStr == 'inprogress' || statusStr == 'in_progress') {
      parsedStatus = ProductionStatus.inProgress;
    } else if (statusStr == 'completed') {
      parsedStatus = ProductionStatus.completed;
    } else if (statusStr == 'cancelled') {
      parsedStatus = ProductionStatus.cancelled;
    }

    return ProductionOrder(
      id: json['id'] ?? '',
      productionNumber: json['productionNumber'] ?? json['production_number'] ?? '',
      finishedProductId: json['finishedProductId'] ?? json['finished_product_id'] ?? '',
      finishedProductName: json['finishedProductName'] ?? json['finished_product_name'] ?? '',
      finishedProductCode: json['finishedProductCode'] ?? json['finished_product_code'] ?? '',
      unit: json['unit'] ?? 'Pcs',
      plannedQuantity: (json['plannedQuantity'] ?? json['planned_quantity'] ?? 0).toDouble(),
      actualQuantityProduced: (json['actualQuantityProduced'] ?? json['actual_quantity_produced'] ?? 0).toDouble(),
      rawMaterialsUsed: rawMaterialsList,
      rawMaterialCost: (json['rawMaterialCost'] ?? json['raw_material_cost'] ?? 0).toDouble(),
      labourCost: (json['labourCost'] ?? json['labour_cost'] ?? 0).toDouble(),
      otherExpenses: (json['otherExpenses'] ?? json['other_expenses'] ?? 0).toDouble(),
      totalProductionCost: (json['totalProductionCost'] ?? json['total_production_cost'] ?? 0).toDouble(),
      costPerUnit: (json['costPerUnit'] ?? json['cost_per_unit'] ?? 0).toDouble(),
      productionDate: json['productionDate'] != null
          ? DateTime.tryParse(json['productionDate'].toString()) ?? DateTime.now()
          : (json['production_date'] != null
              ? DateTime.tryParse(json['production_date'].toString()) ?? DateTime.now()
              : DateTime.now()),
      status: parsedStatus,
      salesOrderId: json['salesOrderId'] ?? json['sales_order_id'],
      salesOrderNumber: json['salesOrderNumber'] ?? json['sales_order_number'],
      projectId: json['projectId'] ?? json['project_id'],
      projectName: json['projectName'] ?? json['project_name'],
      notes: json['notes'],
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true,
      deletedReason: json['deletedReason'] ?? json['deleted_reason'],
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productionNumber': productionNumber,
      'finishedProductId': finishedProductId,
      'finishedProductName': finishedProductName,
      'finishedProductCode': finishedProductCode,
      'unit': unit,
      'plannedQuantity': plannedQuantity,
      'actualQuantityProduced': actualQuantityProduced,
      'rawMaterials': rawMaterialsUsed.map((m) => m.toJson()).toList(),
      'rawMaterialCost': rawMaterialCost,
      'labourCost': labourCost,
      'otherExpenses': otherExpenses,
      'totalProductionCost': totalProductionCost,
      'costPerUnit': costPerUnit,
      'productionDate': productionDate.toIso8601String(),
      'status': status.name,
      'salesOrderId': salesOrderId,
      'salesOrderNumber': salesOrderNumber,
      'projectId': projectId,
      'projectName': projectName,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'isDeleted': isDeleted,
      'deletedReason': deletedReason,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  ProductionOrder copyWith({
    String? id,
    String? productionNumber,
    String? finishedProductId,
    String? finishedProductName,
    String? finishedProductCode,
    String? unit,
    double? plannedQuantity,
    double? actualQuantityProduced,
    List<ProductionRawMaterialUsage>? rawMaterialsUsed,
    double? rawMaterialCost,
    double? labourCost,
    double? otherExpenses,
    double? totalProductionCost,
    double? costPerUnit,
    DateTime? productionDate,
    ProductionStatus? status,
    String? salesOrderId,
    String? salesOrderNumber,
    String? notes,
    DateTime? createdAt,
    bool? isDeleted,
    String? deletedReason,
    DateTime? deletedAt,
  }) {
    return ProductionOrder(
      id: id ?? this.id,
      productionNumber: productionNumber ?? this.productionNumber,
      finishedProductId: finishedProductId ?? this.finishedProductId,
      finishedProductName: finishedProductName ?? this.finishedProductName,
      finishedProductCode: finishedProductCode ?? this.finishedProductCode,
      unit: unit ?? this.unit,
      plannedQuantity: plannedQuantity ?? this.plannedQuantity,
      actualQuantityProduced: actualQuantityProduced ?? this.actualQuantityProduced,
      rawMaterialsUsed: rawMaterialsUsed ?? this.rawMaterialsUsed,
      rawMaterialCost: rawMaterialCost ?? this.rawMaterialCost,
      labourCost: labourCost ?? this.labourCost,
      otherExpenses: otherExpenses ?? this.otherExpenses,
      totalProductionCost: totalProductionCost ?? this.totalProductionCost,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      productionDate: productionDate ?? this.productionDate,
      status: status ?? this.status,
      salesOrderId: salesOrderId ?? this.salesOrderId,
      salesOrderNumber: salesOrderNumber ?? this.salesOrderNumber,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedReason: deletedReason ?? this.deletedReason,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
