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
}
