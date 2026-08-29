class RawMaterial {
  final String id;
  final String name;
  final String itemCode;
  final String categoryId;
  final String categoryName;
  final String unit;
  final double currentStock;
  final double openingStock;
  final double minimumStock;
  final double reorderLevel;
  final double defaultPurchasePrice;
  final double gstPercent;
  final List<String> preferredVendorIds;
  final List<String> preferredVendorNames;
  final DateTime createdAt;
  final DateTime updatedAt;

  RawMaterial({
    required this.id,
    required this.name,
    required this.itemCode,
    required this.categoryId,
    required this.categoryName,
    required this.unit,
    required this.currentStock,
    required this.openingStock,
    required this.minimumStock,
    required this.reorderLevel,
    required this.defaultPurchasePrice,
    required this.gstPercent,
    required this.preferredVendorIds,
    required this.preferredVendorNames,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => currentStock <= minimumStock;
  double get totalValuation => currentStock * defaultPurchasePrice;

  RawMaterial copyWith({
    String? id,
    String? name,
    String? itemCode,
    String? categoryId,
    String? categoryName,
    String? unit,
    double? currentStock,
    double? openingStock,
    double? minimumStock,
    double? reorderLevel,
    double? defaultPurchasePrice,
    double? gstPercent,
    List<String>? preferredVendorIds,
    List<String>? preferredVendorNames,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RawMaterial(
      id: id ?? this.id,
      name: name ?? this.name,
      itemCode: itemCode ?? this.itemCode,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      openingStock: openingStock ?? this.openingStock,
      minimumStock: minimumStock ?? this.minimumStock,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      defaultPurchasePrice: defaultPurchasePrice ?? this.defaultPurchasePrice,
      gstPercent: gstPercent ?? this.gstPercent,
      preferredVendorIds: preferredVendorIds ?? this.preferredVendorIds,
      preferredVendorNames: preferredVendorNames ?? this.preferredVendorNames,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
