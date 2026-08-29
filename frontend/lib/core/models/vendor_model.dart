class Vendor {
  final String id;
  final String name;
  final String contactPerson;
  final String mobile;
  final String email;
  final String gstNumber;
  final String panNumber;
  final String address;
  final String paymentTerms;
  final double creditLimit;
  final double outstandingBalance;
  final bool isDeleted;
  final String? deleteReason;
  final DateTime? deletedAt;
  final DateTime createdAt;

  Vendor({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.mobile,
    required this.email,
    required this.gstNumber,
    required this.panNumber,
    required this.address,
    required this.paymentTerms,
    required this.creditLimit,
    this.outstandingBalance = 0.0,
    this.isDeleted = false,
    this.deleteReason,
    this.deletedAt,
    required this.createdAt,
  });

  Vendor copyWith({
    String? id,
    String? name,
    String? contactPerson,
    String? mobile,
    String? email,
    String? gstNumber,
    String? panNumber,
    String? address,
    String? paymentTerms,
    double? creditLimit,
    double? outstandingBalance,
    bool? isDeleted,
    String? deleteReason,
    DateTime? deletedAt,
    DateTime? createdAt,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      gstNumber: gstNumber ?? this.gstNumber,
      panNumber: panNumber ?? this.panNumber,
      address: address ?? this.address,
      paymentTerms: paymentTerms ?? this.paymentTerms,
      creditLimit: creditLimit ?? this.creditLimit,
      outstandingBalance: outstandingBalance ?? this.outstandingBalance,
      isDeleted: isDeleted ?? this.isDeleted,
      deleteReason: deleteReason ?? this.deleteReason,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
