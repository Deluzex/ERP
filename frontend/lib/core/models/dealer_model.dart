class Dealer {
  final String id;
  final String name;
  final String contactPerson;
  final String mobile;
  final String companyName;
  final String email;
  final String gstNumber;
  final String address;
  final String state;
  final String pincode;
  final String stateCode;
  final double outstandingAmount;
  final bool isDeleted;
  final bool isActive;
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
    this.state = '',
    this.pincode = '',
    this.stateCode = '24',
    this.outstandingAmount = 0.0,
    this.isDeleted = false,
    this.isActive = true,
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
    String? state,
    String? pincode,
    String? stateCode,
    double? outstandingAmount,
    bool? isDeleted,
    bool? isActive,
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
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      stateCode: stateCode ?? this.stateCode,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      isDeleted: isDeleted ?? this.isDeleted,
      isActive: isActive ?? this.isActive,
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
      state: json['state']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      stateCode: json['stateCode']?.toString() ?? json['state_code']?.toString() ?? '24',
      outstandingAmount: double.tryParse(json['outstandingAmount']?.toString() ?? json['outstanding_amount']?.toString() ?? '0') ?? 0.0,
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true,
      isActive: json['isActive'] != null
          ? (json['isActive'] == true || json['isActive'].toString() == 'true')
          : (json['is_active'] != null ? (json['is_active'] == true || json['is_active'].toString() == 'true') : true),
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': companyName.isNotEmpty ? companyName : name,
      'contactPerson': contactPerson,
      'mobile': mobile,
      'companyName': companyName.isNotEmpty ? companyName : name,
      'email': email,
      if (gstNumber.trim().isNotEmpty) 'gstNumber': gstNumber.trim(),
      'address': address,
      if (state.trim().isNotEmpty) 'state': state.trim(),
      if (pincode.trim().isNotEmpty) 'pincode': pincode.trim(),
      if (stateCode.trim().isNotEmpty) 'stateCode': stateCode.trim(),
      'isActive': isActive,
    };
  }
}
