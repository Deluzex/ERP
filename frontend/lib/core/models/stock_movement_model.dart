enum StockMovementType {
  purchase,
  productionConsumption,
  productionOutput,
  sale,
  saleReturn,
  purchaseReturn,
  damage,
  adjustment,
}

enum ItemType {
  rawMaterial,
  finishedProduct,
}

class StockMovement {
  final String id;
  final DateTime date;
  final String itemId;
  final String itemName;
  final String itemCode;
  final ItemType itemType;
  final StockMovementType transactionType;
  final String referenceNumber;
  final double stockIn;
  final double stockOut;
  final double currentBalance;
  final String unit;
  final String? notes;
  final String performedBy;

  StockMovement({
    required this.id,
    required this.date,
    required this.itemId,
    required this.itemName,
    required this.itemCode,
    required this.itemType,
    required this.transactionType,
    required this.referenceNumber,
    required this.stockIn,
    required this.stockOut,
    required this.currentBalance,
    required this.unit,
    this.notes,
    required this.performedBy,
  });

  String get transactionTypeLabel {
    switch (transactionType) {
      case StockMovementType.purchase:
        return itemType == ItemType.finishedProduct
            ? 'STOCK IN (FINISHED PRODUCT PURCHASE)'
            : 'STOCK IN (RAW MATERIAL PURCHASE)';
      case StockMovementType.productionConsumption:
        return 'STOCK OUT (PRODUCTION)';
      case StockMovementType.productionOutput:
        return 'STOCK IN (PRODUCTION)';
      case StockMovementType.sale:
        return 'STOCK OUT (SALE)';
      case StockMovementType.saleReturn:
        return 'STOCK IN (SALE RETURN)';
      case StockMovementType.purchaseReturn:
        return 'STOCK OUT (PURCHASE RETURN)';
      case StockMovementType.damage:
        return 'STOCK OUT (DAMAGE)';
      case StockMovementType.adjustment:
        return stockIn > 0 ? 'STOCK ADJUSTMENT (+)' : 'STOCK ADJUSTMENT (-)';
    }
  }

  String get sourceLabel {
    if (itemType == ItemType.finishedProduct) {
      if (transactionType == StockMovementType.productionOutput) return 'Produced';
      if (transactionType == StockMovementType.purchase) return 'Purchased';
      return 'Stock Transfer';
    }
    return 'Purchased';
  }

  DateTime get timestamp => date;
  double get quantityChanged => stockIn > 0 ? stockIn : stockOut;
}
