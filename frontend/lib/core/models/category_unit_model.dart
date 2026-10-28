class ItemCategory {
  final String id;
  final String name;
  final String description;

  ItemCategory({
    required this.id,
    required this.name,
    required this.description,
  });

  ItemCategory copyWith({
    String? id,
    String? name,
    String? description,
  }) {
    return ItemCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
    );
  }

  factory ItemCategory.fromJson(Map<String, dynamic> json) {
    return ItemCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
    };
  }
}

class MeasurementUnit {
  final String id;
  final String name;
  final String symbol;

  MeasurementUnit({
    required this.id,
    required this.name,
    required this.symbol,
  });

  MeasurementUnit copyWith({
    String? id,
    String? name,
    String? symbol,
  }) {
    return MeasurementUnit(
      id: id ?? this.id,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
    );
  }

  factory MeasurementUnit.fromJson(Map<String, dynamic> json) {
    return MeasurementUnit(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      symbol: json['symbol']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'symbol': symbol,
    };
  }
}

class ExpenseCategoryMasterItem {
  final String id;
  final String name;
  final String code;
  final String description;
  final bool isActive;

  /// Canonical backend expense key this master entry maps to for saving
  /// expenses (must match the backend's EXPENSE_CATEGORIES list, e.g.
  /// 'transportation', 'officeExpense'). Null for custom entries that have
  /// no linked expense key yet.
  final String? linkedKey;

  ExpenseCategoryMasterItem({
    required this.id,
    required this.name,
    required this.code,
    required this.description,
    this.isActive = true,
    this.linkedKey,
  });

  ExpenseCategoryMasterItem copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    bool? isActive,
    String? linkedKey,
  }) {
    return ExpenseCategoryMasterItem(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      linkedKey: linkedKey ?? this.linkedKey,
    );
  }

  factory ExpenseCategoryMasterItem.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryMasterItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isActive: json['isActive'] == null
          ? (json['is_active'] == null ? true : json['is_active'] == true)
          : json['isActive'] == true,
      linkedKey: (json['linkedKey']?.toString() ?? json['linked_key']?.toString() ?? '').trim().isEmpty
          ? null
          : (json['linkedKey']?.toString() ?? json['linked_key']?.toString() ?? '').trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'isActive': isActive,
      if (linkedKey != null && linkedKey!.trim().isNotEmpty) 'linkedKey': linkedKey,
    };
  }
}

class PaymentModeMasterItem {
  final String id;
  final String name;
  final String code;
  final String type;
  final String description;
  final bool isActive;

  PaymentModeMasterItem({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.description,
    this.isActive = true,
  });

  PaymentModeMasterItem copyWith({
    String? id,
    String? name,
    String? code,
    String? type,
    String? description,
    bool? isActive,
  }) {
    return PaymentModeMasterItem(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      type: type ?? this.type,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
    );
  }

  factory PaymentModeMasterItem.fromJson(Map<String, dynamic> json) {
    return PaymentModeMasterItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? 'Bank / Electronic',
      description: json['description']?.toString() ?? '',
      isActive: json['isActive'] == null ? true : json['isActive'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'code': code,
      'type': type,
      'description': description,
      'isActive': isActive,
    };
  }
}
