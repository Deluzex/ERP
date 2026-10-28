class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String notificationType;
  final String? targetRole;
  final String? recipientUserId;
  final String? recipientName;
  final String? recipientEmail;
  final String sourceModule;
  final String? relatedEntityType;
  final String? relatedEntityId;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.notificationType,
    this.targetRole,
    this.recipientUserId,
    this.recipientName,
    this.recipientEmail,
    this.sourceModule = 'sales',
    this.relatedEntityType = 'sales_order',
    this.relatedEntityId,
    this.data = const {},
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  String? get salesOrderNumber => data['salesOrderNumber'] as String?;
  String? get customerName => data['customerName'] as String?;
  String? get productName => data['productName'] as String?;
  String? get productSku => data['productSku'] as String?;
  double? get requestedQuantity => (data['requestedQuantity'] as num?)?.toDouble();
  double? get availableStock => (data['availableStock'] as num?)?.toDouble();
  double? get shortageQuantity => (data['shortageQuantity'] as num?)?.toDouble();
  String get requestType =>
      data['requestType'] as String? ??
      (notificationType.contains('purchase') ? 'Purchase' : 'Production');
  String? get route => data['route'] as String?;

  NotificationItem copyWith({
    String? id,
    String? title,
    String? message,
    String? notificationType,
    String? targetRole,
    String? recipientUserId,
    String? recipientName,
    String? recipientEmail,
    String? sourceModule,
    String? relatedEntityType,
    String? relatedEntityId,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      notificationType: notificationType ?? this.notificationType,
      targetRole: targetRole ?? this.targetRole,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      recipientName: recipientName ?? this.recipientName,
      recipientEmail: recipientEmail ?? this.recipientEmail,
      sourceModule: sourceModule ?? this.sourceModule,
      relatedEntityType: relatedEntityType ?? this.relatedEntityType,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'notificationType': notificationType,
      'targetRole': targetRole,
      'recipientUserId': recipientUserId,
      'recipientName': recipientName,
      'recipientEmail': recipientEmail,
      'sourceModule': sourceModule,
      'relatedEntityType': relatedEntityType,
      'relatedEntityId': relatedEntityId,
      'data': data,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      notificationType: json['notificationType'] as String? ?? 'requisition',
      targetRole: json['targetRole'] as String?,
      recipientUserId: json['recipientUserId'] as String?,
      recipientName: json['recipientName'] as String?,
      recipientEmail: json['recipientEmail'] as String?,
      sourceModule: json['sourceModule'] as String? ?? 'sales',
      relatedEntityType: json['relatedEntityType'] as String?,
      relatedEntityId: json['relatedEntityId'] as String?,
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : {},
      isRead: json['isRead'] as bool? ?? false,
      readAt: json['readAt'] != null ? DateTime.tryParse(json['readAt'] as String) : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
