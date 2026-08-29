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
  final String? notes;
  final DateTime createdAt;

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
    this.notes,
    required this.createdAt,
  });

  String get statusLabel {
    switch (status) {
      case ProductionStatus.planned:
        return 'Planned';
      case ProductionStatus.inProgress:
        return 'In Progress';
      case ProductionStatus.completed:
        return 'Completed';
      case ProductionStatus.cancelled:
        return 'Cancelled';
    }
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
    String? notes,
    DateTime? createdAt,
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
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
