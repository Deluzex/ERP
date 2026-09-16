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
