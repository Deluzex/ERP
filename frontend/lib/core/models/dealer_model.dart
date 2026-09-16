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
  final bool isDeleted;
  final DateTime? deletedAt;
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
    this.isDeleted = false,
    this.deletedAt,
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
    bool? isDeleted,
    DateTime? deletedAt,
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
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Dealer.fromJson(Map<String, dynamic> json) {
    return Dealer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['companyName']?.toString() ?? json['company_name']?.toString() ?? '',
      contactPerson: json['contactPerson']?.toString() ?? json['contact_person']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      companyName: json['companyName']?.toString() ?? json['company_name']?.toString() ?? json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      gstNumber: json['gstNumber']?.toString() ?? json['gst_number']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      outstandingAmount: double.tryParse(json['outstandingAmount']?.toString() ?? json['outstanding_amount']?.toString() ?? '0') ?? 0.0,
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true,
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': companyName.isNotEmpty ? companyName : name,
      'contactPerson': contactPerson,
      'mobile': mobile,
      'companyName': companyName.isNotEmpty ? companyName : name,
      'email': email,
      'gstNumber': gstNumber,
      'address': address,
    };
  }
}
