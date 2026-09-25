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
  final bool isDeleted;
  final DateTime? deletedAt;
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
    this.isDeleted = false,
    this.deletedAt,
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
    bool? isDeleted,
    DateTime? deletedAt,
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
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Architect.fromJson(Map<String, dynamic> json) {
    return Architect(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? json['company_name']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      gstNumber: json['gstNumber']?.toString() ?? json['gst_number']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      defaultCommissionRate: double.tryParse(json['defaultCommissionRate']?.toString() ?? json['default_commission_rate']?.toString() ?? '5.0') ?? 5.0,
      totalCommissionEarned: double.tryParse(json['totalCommissionEarned']?.toString() ?? json['total_commission_earned']?.toString() ?? '0') ?? 0.0,
      pendingCommission: double.tryParse(json['pendingCommission']?.toString() ?? json['pending_commission']?.toString() ?? '0') ?? 0.0,
      approvedCommission: double.tryParse(json['approvedCommission']?.toString() ?? json['approved_commission']?.toString() ?? '0') ?? 0.0,
      paidCommission: double.tryParse(json['paidCommission']?.toString() ?? json['paid_commission']?.toString() ?? '0') ?? 0.0,
      linkedCustomerId: json['linkedCustomerId']?.toString() ?? json['linked_customer_id']?.toString(),
      isAlsoCustomer: json['isAlsoCustomer'] == true || json['is_also_customer'] == true,
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true,
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'companyName': companyName,
      'mobile': mobile,
      'email': email,
      'gstNumber': gstNumber,
      'address': address,
      'defaultCommissionRate': defaultCommissionRate,
      if (linkedCustomerId != null && linkedCustomerId!.isNotEmpty)
        'linkedCustomerId': linkedCustomerId,
      'isAlsoCustomer': isAlsoCustomer,
    };
  }
}
