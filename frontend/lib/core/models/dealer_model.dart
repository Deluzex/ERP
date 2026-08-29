class Dealer {
  final String id;
  final String name;
  final String contactPerson;
  final String mobile;
  final String companyName;
  final String email;
  final String gstNumber;
  final String address;
  final double outstandingAmount;
  final DateTime createdAt;

  Dealer({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.mobile,
    required this.companyName,
    required this.email,
    required this.gstNumber,
    required this.address,
    this.outstandingAmount = 0.0,
    required this.createdAt,
  });

  Dealer copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? mobile,
    String? companyName,
    String? email,
    String? gstNumber,
    String? address,
    double? outstandingAmount,
    DateTime? createdAt,
  }) {
    return Dealer(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      mobile: mobile ?? this.mobile,
      companyName: companyName ?? this.companyName,
      email: email ?? this.email,
      gstNumber: gstNumber ?? this.gstNumber,
      address: address ?? this.address,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
