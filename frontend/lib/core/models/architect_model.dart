class Architect {
  final String id;
  final String name;
  final String companyName;
  final String mobile;
  final String email;
  final String gstNumber;
  final String address;
  final double defaultCommissionRate; // e.g. 5.0 for 5%
  final double totalCommissionEarned;
  final double pendingCommission;
  final double approvedCommission;
  final double paidCommission;
  final String? linkedCustomerId;
  final bool isAlsoCustomer;
  final DateTime createdAt;

  Architect({
    required this.id,
    required this.name,
    required this.companyName,
    required this.mobile,
    required this.email,
    required this.gstNumber,
    required this.address,
    this.defaultCommissionRate = 5.0,
    this.totalCommissionEarned = 0.0,
    this.pendingCommission = 0.0,
    this.approvedCommission = 0.0,
    this.paidCommission = 0.0,
    this.linkedCustomerId,
    this.isAlsoCustomer = false,
    required this.createdAt,
  });

  Architect copyWith({
    String? id,
    String? name,
    String? companyName,
    String? mobile,
    String? email,
    String? gstNumber,
    String? address,
    double? defaultCommissionRate,
    double? totalCommissionEarned,
    double? pendingCommission,
    double? approvedCommission,
    double? paidCommission,
    String? linkedCustomerId,
    bool? isAlsoCustomer,
    DateTime? createdAt,
  }) {
    return Architect(
      id: id ?? this.id,
      name: name ?? this.name,
      companyName: companyName ?? this.companyName,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      gstNumber: gstNumber ?? this.gstNumber,
      address: address ?? this.address,
      defaultCommissionRate: defaultCommissionRate ?? this.defaultCommissionRate,
      totalCommissionEarned: totalCommissionEarned ?? this.totalCommissionEarned,
      pendingCommission: pendingCommission ?? this.pendingCommission,
      approvedCommission: approvedCommission ?? this.approvedCommission,
      paidCommission: paidCommission ?? this.paidCommission,
      linkedCustomerId: linkedCustomerId ?? this.linkedCustomerId,
      isAlsoCustomer: isAlsoCustomer ?? this.isAlsoCustomer,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
