import 'stock_movement_model.dart';

enum AdjustmentReason {
  physicalCountMismatch,
  damagedGoods,
  expiry,
  theftOrLoss,
  internalConsumption,
  revaluation,
  other,
}

class StockAdjustment {
  final String id;
  final String adjustmentNumber; // e.g. ADJ-2026-001
  final DateTime adjustmentDate;
  final String itemId;
  final String itemName;
  final String itemCode;
  final ItemType itemType;
  final double currentStockBefore;
  final double adjustedStockAfter;
  final double adjustmentQuantity; // can be positive or negative
  final String unit;
  final AdjustmentReason reason;
  final String remarks;
  final String performedBy;
  final DateTime createdAt;

  StockAdjustment({
    required this.id,
    required this.adjustmentNumber,
    required this.adjustmentDate,
    required this.itemId,
    required this.itemName,
    required this.itemCode,
    required this.itemType,
    required this.currentStockBefore,
    required this.adjustedStockAfter,
    required this.adjustmentQuantity,
    required this.unit,
    required this.reason,
    required this.remarks,
    required this.performedBy,
    required this.createdAt,
  });

  String get reasonLabel {
    switch (reason) {
      case AdjustmentReason.physicalCountMismatch:
        return 'Physical Count Mismatch';
      case AdjustmentReason.damagedGoods:
        return 'Damaged Goods';
      case AdjustmentReason.expiry:
        return 'Expiry';
      case AdjustmentReason.theftOrLoss:
        return 'Theft / Loss';
      case AdjustmentReason.internalConsumption:
        return 'Internal Consumption';
      case AdjustmentReason.revaluation:
        return 'Revaluation';
      case AdjustmentReason.other:
        return 'Other';
    }
  }

  factory StockAdjustment.fromJson(Map<String, dynamic> json) {
    final itemTypeStr = json['itemType'] as String? ?? 'rawMaterial';
    final reasonStr = json['reason'] as String? ?? 'other';

    return StockAdjustment(
      id: json['id'] as String? ?? '',
      adjustmentNumber: json['adjustmentNumber'] as String? ?? '',
      adjustmentDate: json['adjustmentDate'] != null
          ? DateTime.tryParse(json['adjustmentDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      itemId: json['itemId'] as String? ?? '',
      itemName: json['itemName'] as String? ?? '',
      itemCode: json['itemCode'] as String? ?? '',
      itemType: ItemType.values.firstWhere(
        (e) => e.name == itemTypeStr,
        orElse: () => ItemType.rawMaterial,
      ),
      currentStockBefore: (json['currentStockBefore'] as num?)?.toDouble() ?? 0.0,
      adjustedStockAfter: (json['adjustedStockAfter'] as num?)?.toDouble() ?? 0.0,
      adjustmentQuantity: (json['adjustmentQuantity'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? 'PCS',
      reason: AdjustmentReason.values.firstWhere(
        (e) => e.name == reasonStr,
        orElse: () => AdjustmentReason.other,
      ),
      remarks: json['remarks'] as String? ?? '',
      performedBy: json['performedBy'] as String? ?? 'System',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'adjustmentNumber': adjustmentNumber,
      'adjustmentDate': adjustmentDate.toIso8601String(),
      'itemId': itemId,
      'itemName': itemName,
      'itemCode': itemCode,
      'itemType': itemType.name,
      'currentStockBefore': currentStockBefore,
      'adjustedStockAfter': adjustedStockAfter,
      'adjustmentQuantity': adjustmentQuantity,
      'unit': unit,
      'reason': reason.name,
      'remarks': remarks,
      'performedBy': performedBy,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
