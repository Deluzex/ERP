class FinishedProduct {
  final String id;
  final String name;
  final String itemCode;
  final String categoryId;
  final String categoryName;
  final String unit;
  final double currentStock;
  final double openingStock;
  final double minimumStock;
  final double costPrice;
  final double dealerSellingPrice;
  final double customerSellingPrice;
  final double gstPercent;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinishedProduct({
    required this.id,
    required this.name,
    required this.itemCode,
    required this.categoryId,
    required this.categoryName,
    required this.unit,
    required this.currentStock,
    required this.openingStock,
    required this.minimumStock,
    required this.costPrice,
    required this.dealerSellingPrice,
    required this.customerSellingPrice,
    required this.gstPercent,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => currentStock <= minimumStock;
  double get totalValuation => currentStock * costPrice;

  FinishedProduct copyWith({
    String? id,
    String? name,
    String? itemCode,
    String? categoryId,
    String? categoryName,
    String? unit,
    double? currentStock,
    double? openingStock,
    double? minimumStock,
    double? costPrice,
    double? dealerSellingPrice,
    double? customerSellingPrice,
    double? gstPercent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinishedProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      itemCode: itemCode ?? this.itemCode,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      openingStock: openingStock ?? this.openingStock,
      minimumStock: minimumStock ?? this.minimumStock,
      costPrice: costPrice ?? this.costPrice,
      dealerSellingPrice: dealerSellingPrice ?? this.dealerSellingPrice,
      customerSellingPrice: customerSellingPrice ?? this.customerSellingPrice,
      gstPercent: gstPercent ?? this.gstPercent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
