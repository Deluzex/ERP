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

  factory StockMovement.fromJson(Map<String, dynamic> json) {
    final itemTypeStr = json['itemType'] as String? ?? 'rawMaterial';
    final txTypeStr = json['transactionType'] as String? ?? 'adjustment';

    return StockMovement(
      id: json['id'] as String? ?? '',
      date: json['date'] != null ? DateTime.tryParse(json['date'] as String) ?? DateTime.now() : DateTime.now(),
      itemId: json['itemId'] as String? ?? '',
      itemName: json['itemName'] as String? ?? '',
      itemCode: json['itemCode'] as String? ?? '',
      itemType: ItemType.values.firstWhere(
        (e) => e.name == itemTypeStr,
        orElse: () => ItemType.rawMaterial,
      ),
      transactionType: StockMovementType.values.firstWhere(
        (e) => e.name == txTypeStr,
        orElse: () => StockMovementType.adjustment,
      ),
      referenceNumber: json['referenceNumber'] as String? ?? '',
      stockIn: (json['stockIn'] as num?)?.toDouble() ?? 0.0,
      stockOut: (json['stockOut'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (json['currentBalance'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit'] as String? ?? 'PCS',
      notes: json['notes'] as String?,
      performedBy: json['performedBy'] as String? ?? 'System',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'itemId': itemId,
      'itemName': itemName,
      'itemCode': itemCode,
      'itemType': itemType.name,
      'transactionType': transactionType.name,
      'referenceNumber': referenceNumber,
      'stockIn': stockIn,
      'stockOut': stockOut,
      'currentBalance': currentBalance,
      'unit': unit,
      'notes': notes,
      'performedBy': performedBy,
    };
  }
}
