enum WhatsAppAlertType {
  lowStockRawMaterial,
  lowStockFinishedProduct,
  allLowStock,
  productionDelay,
  dispatchAlert,
}

enum AlertRecordStatus {
  pending,
  sent,
  failed,
  resolved,
}

class WhatsAppAlertRecipient {
  final String id;
  final String recipientName;
  final String mobileNumber;
  final String whatsappNumber;
  final String roleOrDepartment; // e.g. Production Manager, Inventory Head, Plant Supervisor
  final WhatsAppAlertType alertType;
  final bool isActive;
  final DateTime createdAt;

  WhatsAppAlertRecipient({
    required this.id,
    required this.recipientName,
    required this.mobileNumber,
    required this.whatsappNumber,
    required this.roleOrDepartment,
    this.alertType = WhatsAppAlertType.allLowStock,
    this.isActive = true,
    required this.createdAt,
  });

  String get alertTypeLabel {
    switch (alertType) {
      case WhatsAppAlertType.lowStockRawMaterial:
        return 'Raw Material Low Stock';
      case WhatsAppAlertType.lowStockFinishedProduct:
        return 'Finished Product Low Stock';
      case WhatsAppAlertType.allLowStock:
        return 'All Low Stock Alerts';
      case WhatsAppAlertType.productionDelay:
        return 'Production Delay Alerts';
      case WhatsAppAlertType.dispatchAlert:
        return 'Dispatch Alerts';
    }
  }

  WhatsAppAlertRecipient copyWith({
    String? id,
    String? recipientName,
    String? mobileNumber,
    String? whatsappNumber,
    String? roleOrDepartment,
    WhatsAppAlertType? alertType,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return WhatsAppAlertRecipient(
      id: id ?? this.id,
      recipientName: recipientName ?? this.recipientName,
      mobileNumber: mobileNumber ?? this.mobileNumber,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      roleOrDepartment: roleOrDepartment ?? this.roleOrDepartment,
      alertType: alertType ?? this.alertType,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class LowStockAlertRecord {
  final String id;
  final String itemId;
  final String itemName;
  final String itemCode;
  final String itemType; // 'Raw Material' or 'Finished Product'
  final double currentStock;
  final double minimumStock;
  final double reorderLevel;
  final String unit;
  final String recipientName;
  final String recipientWhatsApp;
  final String messageBody;
  final AlertRecordStatus status;
  final DateTime triggeredAt;
  final DateTime? resolvedAt;

  LowStockAlertRecord({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.itemCode,
    required this.itemType,
    required this.currentStock,
    required this.minimumStock,
    required this.reorderLevel,
    required this.unit,
    required this.recipientName,
    required this.recipientWhatsApp,
    required this.messageBody,
    this.status = AlertRecordStatus.sent,
    required this.triggeredAt,
    this.resolvedAt,
  });

  String get statusLabel {
    switch (status) {
      case AlertRecordStatus.pending:
        return 'Pending';
      case AlertRecordStatus.sent:
        return 'Sent';
      case AlertRecordStatus.failed:
        return 'Failed';
      case AlertRecordStatus.resolved:
        return 'Resolved';
    }
  }
}

class WhatsAppMessageLog {
  final String id;
  final String messageType; // Quotation, Invoice, Dispatch, Payment Reminder, Project Update, Low Stock Alert, Custom
  final String recipientName;
  final String recipientNumber;
  final String? relatedEntityType; // Quotation, Invoice, Delivery, Project, Customer, Dealer, Architect
  final String? relatedEntityId;
  final String? relatedEntityNumber;
  final String messageText;
  final DateTime sentAt;
  final String status; // Sent, Delivered, Opened

  WhatsAppMessageLog({
    required this.id,
    required this.messageType,
    required this.recipientName,
    required this.recipientNumber,
    this.relatedEntityType,
    this.relatedEntityId,
    this.relatedEntityNumber,
    required this.messageText,
    required this.sentAt,
    this.status = 'Sent',
  });
}

class GlobalSupportConfig {
  final String teamName;
  final String whatsappNumber;
  final String? groupLink;
  final String defaultMessage;
  final bool isEnabled;

  const GlobalSupportConfig({
    this.teamName = 'Deluzex ERP Operations & Support Team',
    this.whatsappNumber = '+919820012345',
    this.groupLink,
    this.defaultMessage = 'Hello Deluzex Support Team, I need assistance regarding ERP operations:',
    this.isEnabled = true,
  });

  GlobalSupportConfig copyWith({
    String? teamName,
    String? whatsappNumber,
    String? groupLink,
    String? defaultMessage,
    bool? isEnabled,
  }) {
    return GlobalSupportConfig(
      teamName: teamName ?? this.teamName,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      groupLink: groupLink ?? this.groupLink,
      defaultMessage: defaultMessage ?? this.defaultMessage,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }
}
