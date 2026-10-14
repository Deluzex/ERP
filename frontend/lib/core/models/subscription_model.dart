class SubscriptionStatus {
  final String clientName;
  final String planName;
  final bool isActive;
  final bool isExpired;
  final DateTime validFrom;
  final DateTime validUntil;
  final int daysRemaining;
  final bool showRenewalWarning;
  final String supportPhone;
  final String supportEmail;

  const SubscriptionStatus({
    required this.clientName,
    required this.planName,
    required this.isActive,
    required this.isExpired,
    required this.validFrom,
    required this.validUntil,
    required this.daysRemaining,
    required this.showRenewalWarning,
    required this.supportPhone,
    required this.supportEmail,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      clientName: json['clientName']?.toString() ?? 'Deluzex ERP Client',
      planName: json['planName']?.toString() ?? 'Enterprise Annual',
      isActive: json['isActive'] == true,
      isExpired: json['isExpired'] == true,
      validFrom: DateTime.tryParse(json['validFrom']?.toString() ?? '') ?? DateTime.now(),
      validUntil: DateTime.tryParse(json['validUntil']?.toString() ?? '') ??
          DateTime.now().add(const Duration(days: 365)),
      daysRemaining: (json['daysRemaining'] as num?)?.toInt() ?? 0,
      showRenewalWarning: json['showRenewalWarning'] == true,
      supportPhone: json['supportPhone']?.toString() ?? '+91 98250 12345',
      supportEmail: json['supportEmail']?.toString() ?? 'billing@deluzex.com',
    );
  }

  // Fallback healthy instance for offline/test environments
  static SubscriptionStatus healthyDefault() {
    final now = DateTime.now();
    return SubscriptionStatus(
      clientName: 'Deluzex Lighting & Living Ltd.',
      planName: 'Enterprise Annual Edition',
      isActive: true,
      isExpired: false,
      validFrom: now,
      validUntil: now.add(const Duration(days: 365)),
      daysRemaining: 365,
      showRenewalWarning: false,
      supportPhone: '+91 98250 12345',
      supportEmail: 'billing@deluzex.com',
    );
  }
}
