class BomItem {
  final String id;
  final String rawMaterialId;
  final String rawMaterialName;
  final String rawMaterialCode;
  final double quantityPerUnit;
  final double wastagePercent;
  final String unit;
  final double unitCost;

  const BomItem({
    required this.id,
    required this.rawMaterialId,
    required this.rawMaterialName,
    required this.rawMaterialCode,
    required this.quantityPerUnit,
    this.wastagePercent = 0.0,
    required this.unit,
    this.unitCost = 0.0,
  });

  String get safeName => rawMaterialName.isNotEmpty ? rawMaterialName : 'Material';
  String get safeCode => rawMaterialCode.isNotEmpty ? rawMaterialCode : '-';
  String get safeUnit => unit.isNotEmpty ? unit : 'PCS';

  double get quantityWithWastage =>
      quantityPerUnit * (1.0 + (wastagePercent / 100.0));

  double get totalCostPerFinishedUnit => quantityWithWastage * unitCost;
  double get totalCost => totalCostPerFinishedUnit;

  BomItem copyWith({
    String? id,
    String? rawMaterialId,
    String? rawMaterialName,
    String? rawMaterialCode,
    double? quantityPerUnit,
    double? wastagePercent,
    String? unit,
    double? unitCost,
  }) {
    return BomItem(
      id: id ?? this.id,
      rawMaterialId: rawMaterialId ?? this.rawMaterialId,
      rawMaterialName: rawMaterialName ?? this.rawMaterialName,
      rawMaterialCode: rawMaterialCode ?? this.rawMaterialCode,
      quantityPerUnit: quantityPerUnit ?? this.quantityPerUnit,
      wastagePercent: wastagePercent ?? this.wastagePercent,
      unit: unit ?? this.unit,
      unitCost: unitCost ?? this.unitCost,
    );
  }

  factory BomItem.fromJson(Map<String, dynamic> json) {
    return BomItem(
      id: json['id']?.toString() ?? '',
      rawMaterialId: json['rawMaterialId']?.toString() ?? json['raw_material_id']?.toString() ?? '',
      rawMaterialName: json['rawMaterialName']?.toString() ?? json['raw_material_name']?.toString() ?? '',
      rawMaterialCode: json['rawMaterialCode']?.toString() ?? json['raw_material_code']?.toString() ?? '',
      quantityPerUnit: (json['quantityPerUnit'] ?? json['quantity_per_unit'] ?? 0.0).toDouble(),
      wastagePercent: (json['wastagePercent'] ?? json['wastage_percent'] ?? 0.0).toDouble(),
      unit: json['unit']?.toString() ?? 'PCS',
      unitCost: (json['unitCost'] ?? json['unit_cost'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rawMaterialId': rawMaterialId,
      'rawMaterialName': rawMaterialName,
      'rawMaterialCode': rawMaterialCode,
      'quantityPerUnit': quantityPerUnit,
      'wastagePercent': wastagePercent,
      'unit': unit,
      'unitCost': unitCost,
    };
  }
}

class BillOfMaterial {
  final String id;
  final String finishedProductId;
  final String finishedProductName;
  final String finishedProductCode;
  final String name;
  final String? description;
  final double outputQuantity;
  final bool isActive;
  final String? status;
  final List<BomItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BillOfMaterial({
    required this.id,
    required this.finishedProductId,
    required this.finishedProductName,
    required this.finishedProductCode,
    required this.name,
    this.description,
    this.outputQuantity = 1.0,
    this.isActive = true,
    this.status = 'Active',
    required this.items,
    required this.createdAt,
    required this.updatedAt,
  });

  String get safeStatus {
    if (status != null && status!.trim().isNotEmpty) {
      return status!;
    }
    return isActive ? 'Active' : 'Inactive';
  }

  String get safeName => name.isNotEmpty ? name : 'BOM Recipe';
  String get safeProductName => finishedProductName.isNotEmpty ? finishedProductName : '-';
  String get safeProductCode => finishedProductCode.isNotEmpty ? finishedProductCode : '-';

  int get itemsCount => items.length;

  double get totalMaterialCostPerUnit {
    final batchCost = items.fold(0.0, (sum, item) => sum + item.totalCostPerFinishedUnit);
    return outputQuantity > 0 ? (batchCost / outputQuantity) : batchCost;
  }

  double get totalBatchMaterialCost => totalMaterialCostPerUnit * outputQuantity;

  BillOfMaterial copyWith({
    String? id,
    String? finishedProductId,
    String? finishedProductName,
    String? finishedProductCode,
    String? name,
    String? description,
    double? outputQuantity,
    bool? isActive,
    String? status,
    List<BomItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BillOfMaterial(
      id: id ?? this.id,
      finishedProductId: finishedProductId ?? this.finishedProductId,
      finishedProductName: finishedProductName ?? this.finishedProductName,
      finishedProductCode: finishedProductCode ?? this.finishedProductCode,
      name: name ?? this.name,
      description: description ?? this.description,
      outputQuantity: outputQuantity ?? this.outputQuantity,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory BillOfMaterial.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final active = json['isActive'] ?? json['is_active'] ?? true;
    final stat = json['status']?.toString() ?? (active == true ? 'Active' : 'Inactive');
    return BillOfMaterial(
      id: json['id']?.toString() ?? '',
      finishedProductId: json['finishedProductId']?.toString() ?? json['finished_product_id']?.toString() ?? '',
      finishedProductName: json['finishedProductName']?.toString() ?? json['finished_product_name']?.toString() ?? '',
      finishedProductCode: json['finishedProductCode']?.toString() ?? json['finished_product_code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      outputQuantity: (json['outputQuantity'] ?? json['output_quantity'] ?? 1.0).toDouble(),
      isActive: active == true,
      status: stat,
      items: rawItems.map((e) => BomItem.fromJson(e as Map<String, dynamic>)).toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'finishedProductId': finishedProductId,
      'finishedProductName': finishedProductName,
      'finishedProductCode': finishedProductCode,
      'name': name,
      if (description != null) 'description': description,
      'outputQuantity': outputQuantity,
      'isActive': isActive,
      'status': safeStatus,
      'items': items.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}
