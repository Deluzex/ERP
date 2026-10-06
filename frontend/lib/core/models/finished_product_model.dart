class FinishedProduct {
  final String id;
  final String name;
  final String itemCode;
  final String categoryId;
  final String categoryName;
  final String? unitId;
  final String unit;
  final String? hsnSacCode;
  final double currentStock;
  final double purchasedStock;
  final double producedStock;
  final double reservedStock;
  final double openingStock;
  final double minimumStock;
  final double costPrice;
  final double dealerSellingPrice;
  final double customerSellingPrice;
  final double gstPercent;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  FinishedProduct({
    required this.id,
    required this.name,
    required this.itemCode,
    required this.categoryId,
    required this.categoryName,
    this.unitId,
    required this.unit,
    this.hsnSacCode,
    required this.currentStock,
    double? purchasedStock,
    double? producedStock,
    this.reservedStock = 0.0,
    required this.openingStock,
    required this.minimumStock,
    required this.costPrice,
    required this.dealerSellingPrice,
    required this.customerSellingPrice,
    required this.gstPercent,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  })  : purchasedStock = purchasedStock ?? 0.0,
        producedStock = producedStock ?? currentStock;

  bool get isLowStock => currentStock <= minimumStock;
  double get totalValuation => currentStock * costPrice;
  double get availableStock => (currentStock - reservedStock).clamp(0.0, double.infinity);

  FinishedProduct copyWith({
    String? id,
    String? name,
    String? itemCode,
    String? categoryId,
    String? categoryName,
    String? unitId,
    String? unit,
    String? hsnSacCode,
    double? currentStock,
    double? purchasedStock,
    double? producedStock,
    double? reservedStock,
    double? openingStock,
    double? minimumStock,
    double? costPrice,
    double? dealerSellingPrice,
    double? customerSellingPrice,
    double? gstPercent,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FinishedProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      itemCode: itemCode ?? this.itemCode,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      unitId: unitId ?? this.unitId,
      unit: unit ?? this.unit,
      hsnSacCode: hsnSacCode ?? this.hsnSacCode,
      currentStock: currentStock ?? this.currentStock,
      purchasedStock: purchasedStock ?? this.purchasedStock,
      producedStock: producedStock ?? this.producedStock,
      reservedStock: reservedStock ?? this.reservedStock,
      openingStock: openingStock ?? this.openingStock,
      minimumStock: minimumStock ?? this.minimumStock,
      costPrice: costPrice ?? this.costPrice,
      dealerSellingPrice: dealerSellingPrice ?? this.dealerSellingPrice,
      customerSellingPrice: customerSellingPrice ?? this.customerSellingPrice,
      gstPercent: gstPercent ?? this.gstPercent,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FinishedProduct.fromJson(Map<String, dynamic> json) {
    return FinishedProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      itemCode: json['itemCode']?.toString() ?? json['item_code']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? json['category_id']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? json['category_name']?.toString() ?? '',
      unitId: json['unitId']?.toString() ?? json['unit_id']?.toString(),
      unit: json['unit']?.toString() ?? json['unit_symbol']?.toString() ?? 'PCS',
      hsnSacCode: json['hsnSacCode']?.toString() ?? json['hsn_sac_code']?.toString(),
      currentStock: double.tryParse(json['currentStock']?.toString() ?? json['current_stock']?.toString() ?? json['opening_stock']?.toString() ?? '0') ?? 0.0,
      purchasedStock: double.tryParse(json['purchasedStock']?.toString() ?? '0') ?? 0.0,
      producedStock: double.tryParse(json['producedStock']?.toString() ?? '0') ?? 0.0,
      reservedStock: double.tryParse(json['reservedStock']?.toString() ?? '0') ?? 0.0,
      openingStock: double.tryParse(json['openingStock']?.toString() ?? json['opening_stock']?.toString() ?? '0') ?? 0.0,
      minimumStock: double.tryParse(json['minimumStock']?.toString() ?? json['minimum_stock']?.toString() ?? '0') ?? 0.0,
      costPrice: double.tryParse(json['costPrice']?.toString() ?? json['cost_price']?.toString() ?? '0') ?? 0.0,
      dealerSellingPrice: double.tryParse(json['dealerSellingPrice']?.toString() ?? json['dealer_selling_price']?.toString() ?? '0') ?? 0.0,
      customerSellingPrice: double.tryParse(json['customerSellingPrice']?.toString() ?? json['customer_selling_price']?.toString() ?? '0') ?? 0.0,
      gstPercent: double.tryParse(json['gstPercent']?.toString() ?? json['gst_percent']?.toString() ?? '18') ?? 18.0,
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true,
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'itemCode': itemCode,
      'categoryId': categoryId,
      if (unitId != null && unitId!.isNotEmpty) 'unitId': unitId,
      if (hsnSacCode != null && hsnSacCode!.isNotEmpty) 'hsnSacCode': hsnSacCode,
      'openingStock': openingStock,
      'minimumStock': minimumStock,
      'costPrice': costPrice,
      'dealerSellingPrice': dealerSellingPrice,
      'customerSellingPrice': customerSellingPrice,
      'gstPercent': gstPercent,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'name': name,
      'categoryId': categoryId,
      if (unitId != null && unitId!.isNotEmpty) 'unitId': unitId,
      if (hsnSacCode != null && hsnSacCode!.isNotEmpty) 'hsnSacCode': hsnSacCode,
      'currentStock': currentStock,
      'minimumStock': minimumStock,
      'costPrice': costPrice,
      'dealerSellingPrice': dealerSellingPrice,
      'customerSellingPrice': customerSellingPrice,
      'gstPercent': gstPercent,
    };
  }
}
