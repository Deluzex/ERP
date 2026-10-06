class RawMaterial {
  final String id;
  final String name;
  final String itemCode;
  final String categoryId;
  final String categoryName;
  final String? unitId;
  final String unit;
  final String? hsnSacCode;
  final double currentStock;
  final double openingStock;
  final double minimumStock;
  final double reorderLevel;
  final double defaultPurchasePrice;
  final double gstPercent;
  final List<String> preferredVendorIds;
  final List<String> preferredVendorNames;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  RawMaterial({
    required this.id,
    required this.name,
    required this.itemCode,
    required this.categoryId,
    required this.categoryName,
    this.unitId,
    required this.unit,
    this.hsnSacCode,
    required this.currentStock,
    required this.openingStock,
    required this.minimumStock,
    required this.reorderLevel,
    required this.defaultPurchasePrice,
    required this.gstPercent,
    required this.preferredVendorIds,
    this.preferredVendorNames = const [],
    this.isDeleted = false,
    this.deletedAt,
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
    String? unitId,
    String? unit,
    String? hsnSacCode,
    double? currentStock,
    double? openingStock,
    double? minimumStock,
    double? reorderLevel,
    double? defaultPurchasePrice,
    double? gstPercent,
    List<String>? preferredVendorIds,
    List<String>? preferredVendorNames,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RawMaterial(
      id: id ?? this.id,
      name: name ?? this.name,
      itemCode: itemCode ?? this.itemCode,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      unitId: unitId ?? this.unitId,
      unit: unit ?? this.unit,
      hsnSacCode: hsnSacCode ?? this.hsnSacCode,
      currentStock: currentStock ?? this.currentStock,
      openingStock: openingStock ?? this.openingStock,
      minimumStock: minimumStock ?? this.minimumStock,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      defaultPurchasePrice: defaultPurchasePrice ?? this.defaultPurchasePrice,
      gstPercent: gstPercent ?? this.gstPercent,
      preferredVendorIds: preferredVendorIds ?? this.preferredVendorIds,
      preferredVendorNames: preferredVendorNames ?? this.preferredVendorNames,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory RawMaterial.fromJson(Map<String, dynamic> json) {
    return RawMaterial(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      itemCode: json['itemCode']?.toString() ?? json['item_code']?.toString() ?? '',
      categoryId: json['categoryId']?.toString() ?? json['category_id']?.toString() ?? '',
      categoryName: json['categoryName']?.toString() ?? json['category_name']?.toString() ?? '',
      unitId: json['unitId']?.toString() ?? json['unit_id']?.toString(),
      unit: json['unit']?.toString() ?? json['unit_symbol']?.toString() ?? 'PCS',
      hsnSacCode: json['hsnSacCode']?.toString() ?? json['hsn_sac_code']?.toString(),
      currentStock: double.tryParse(json['currentStock']?.toString() ?? json['opening_stock']?.toString() ?? '0') ?? 0.0,
      openingStock: double.tryParse(json['openingStock']?.toString() ?? json['opening_stock']?.toString() ?? '0') ?? 0.0,
      minimumStock: double.tryParse(json['minimumStock']?.toString() ?? json['minimum_stock']?.toString() ?? '0') ?? 0.0,
      reorderLevel: double.tryParse(json['reorderLevel']?.toString() ?? json['reorder_level']?.toString() ?? '0') ?? 0.0,
      defaultPurchasePrice: double.tryParse(json['defaultPurchasePrice']?.toString() ?? json['default_purchase_price']?.toString() ?? '0') ?? 0.0,
      gstPercent: double.tryParse(json['gstPercent']?.toString() ?? json['gst_percent']?.toString() ?? '18') ?? 18.0,
      preferredVendorIds: (json['preferredVendorIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      preferredVendorNames: (json['preferredVendorNames'] as List?)?.map((e) => e.toString()).toList() ?? [],
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
      'reorderLevel': reorderLevel,
      'defaultPurchasePrice': defaultPurchasePrice,
      'gstPercent': gstPercent,
      'preferredVendorIds': preferredVendorIds,
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
      'reorderLevel': reorderLevel,
      'defaultPurchasePrice': defaultPurchasePrice,
      'gstPercent': gstPercent,
      'preferredVendorIds': preferredVendorIds,
    };
  }
}
