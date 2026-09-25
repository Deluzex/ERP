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

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      contactPerson: json['contactPerson']?.toString() ?? json['contact_person']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      gstNumber: json['gstNumber']?.toString() ?? json['gst_number']?.toString() ?? '',
      panNumber: json['panNumber']?.toString() ?? json['pan_number']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      paymentTerms: json['paymentTerms']?.toString() ?? json['payment_terms']?.toString() ?? 'Net 30 Days',
      creditLimit: double.tryParse(json['creditLimit']?.toString() ?? json['credit_limit']?.toString() ?? '0') ?? 0.0,
      outstandingBalance: double.tryParse(json['outstandingBalance']?.toString() ?? json['outstanding_balance']?.toString() ?? '0') ?? 0.0,
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true,
      deleteReason: json['deleteReason']?.toString() ?? json['delete_reason']?.toString(),
      deletedAt: json['deletedAt'] != null
          ? DateTime.tryParse(json['deletedAt'].toString())
          : (json['deleted_at'] != null ? DateTime.tryParse(json['deleted_at'].toString()) : null),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : (json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now() : DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'contactPerson': contactPerson,
      'mobile': mobile,
      'email': email,
      'gstNumber': gstNumber,
      'panNumber': panNumber,
      'address': address,
      'paymentTerms': paymentTerms,
      'creditLimit': creditLimit,
    };
  }
}
