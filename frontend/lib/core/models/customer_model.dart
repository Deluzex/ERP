class Customer {
  final String id;
  final String name;
  final String mobile;
  final String email;
  final String gstNumber;
  final String address;
  final String state;
  final String pincode;
  final String stateCode;
  final double outstandingAmount;
  final double creditBalance;
  final String? linkedArchitectId;
  final bool isAlsoArchitect;
  final bool isDeleted;
  final DateTime? deletedAt;
  final DateTime createdAt;

  Customer({
    required this.id,
    required this.name,
    required this.mobile,
    required this.email,
    required this.gstNumber,
    required this.address,
    this.state = '',
    this.pincode = '',
    this.stateCode = '24',
    this.outstandingAmount = 0.0,
    this.creditBalance = 0.0,
    this.linkedArchitectId,
    this.isAlsoArchitect = false,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
  });

  Customer copyWith({
    String? id,
    String? name,
    String? mobile,
    String? email,
    String? gstNumber,
    String? address,
    String? state,
    String? pincode,
    String? stateCode,
    double? outstandingAmount,
    double? creditBalance,
    String? linkedArchitectId,
    bool? isAlsoArchitect,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      mobile: mobile ?? this.mobile,
      email: email ?? this.email,
      gstNumber: gstNumber ?? this.gstNumber,
      address: address ?? this.address,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      stateCode: stateCode ?? this.stateCode,
      outstandingAmount: outstandingAmount ?? this.outstandingAmount,
      creditBalance: creditBalance ?? this.creditBalance,
      linkedArchitectId: linkedArchitectId ?? this.linkedArchitectId,
      isAlsoArchitect: isAlsoArchitect ?? this.isAlsoArchitect,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      gstNumber: json['gstNumber']?.toString() ?? json['gst_number']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      pincode: json['pincode']?.toString() ?? '',
      stateCode: json['stateCode']?.toString() ?? json['state_code']?.toString() ?? '24',
      outstandingAmount: double.tryParse(json['outstandingAmount']?.toString() ?? json['outstanding_amount']?.toString() ?? '0') ?? 0.0,
      creditBalance: double.tryParse(json['creditBalance']?.toString() ?? json['credit_balance']?.toString() ?? '0') ?? 0.0,
      linkedArchitectId: json['linkedArchitectId']?.toString() ?? json['linked_architect_id']?.toString(),
      isAlsoArchitect: json['isAlsoArchitect'] == true || json['is_also_architect'] == true,
      isDeleted: json['isDeleted'] == true || json['is_deleted'] == true,
      deletedAt: json['deletedAt'] != null ? DateTime.tryParse(json['deletedAt'].toString()) : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'mobile': mobile,
      'email': email,
      if (gstNumber.trim().isNotEmpty) 'gstNumber': gstNumber.trim(),
      'address': address,
      if (state.trim().isNotEmpty) 'state': state.trim(),
      if (pincode.trim().isNotEmpty) 'pincode': pincode.trim(),
      if (stateCode.trim().isNotEmpty) 'stateCode': stateCode.trim(),
      if (linkedArchitectId != null && linkedArchitectId!.isNotEmpty)
        'linkedArchitectId': linkedArchitectId,
      'isAlsoArchitect': isAlsoArchitect,
    };
  }
}
