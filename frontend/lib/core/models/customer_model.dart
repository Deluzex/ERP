class Customer {
  final String id;
  final String name;
  final String mobile;
  final String email;
  final String gstNumber;
  final String address;
  final double outstandingAmount;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
    required this.gstNumber,
    required this.address,
    this.outstandingAmount = 0.0,
    required this.createdAt,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? mobile,
    String? email,
    String? gstNumber,
    String? address,
    double? outstandingAmount,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      gstNumber: gstNumber ?? this.gstNumber,
      address: address ?? this.address,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
