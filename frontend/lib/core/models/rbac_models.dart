import '../../app/routes/app_routes.dart';

/// Supported functional modules in the ERP system
enum ErpModule {
  dashboard,
  inventory,
  purchase,
  production,
  sales,
  payments,
  masters,
  reports,
  settings,
  userManagement,
}

extension ErpModuleExtension on ErpModule {
  String get label {
    switch (this) {
      case ErpModule.dashboard:
        return 'Dashboard';
      case ErpModule.inventory:
        return 'Inventory';
      case ErpModule.purchase:
        return 'Purchase';
      case ErpModule.production:
        return 'Production';
      case ErpModule.sales:
        return 'Sales';
      case ErpModule.payments:
        return 'Payments & Accounts';
      case ErpModule.masters:
        return 'Masters';
      case ErpModule.reports:
        return 'Reports';
      case ErpModule.settings:
        return 'Settings';
      case ErpModule.userManagement:
        return 'User & Role Management';
    }
  }
}

/// Granular action permissions per module
enum ErpAction {
  view,
  create,
  edit,
  delete,
  approve,
  cancel,
  export,
  print,
  share,
}

extension ErpActionExtension on ErpAction {
  String get label {
    switch (this) {
      case ErpAction.view:
        return 'View';
      case ErpAction.create:
        return 'Create';
      case ErpAction.edit:
        return 'Edit';
      case ErpAction.delete:
        return 'Delete';
      case ErpAction.approve:
        return 'Approve';
      case ErpAction.cancel:
        return 'Cancel';
      case ErpAction.export:
        return 'Export';
      case ErpAction.print:
        return 'Print';
      case ErpAction.share:
        return 'Share';
    }
  }
}

/// Permission entry definition
class Permission {
  final String id;
  final ErpModule module;
  final ErpAction action;
  final String description;

  const Permission({
    required this.id,
    required this.module,
    required this.action,
    required this.description,
  });
}

/// Role definition with permission matrix
class Role {
  final String id;
  final String name;
  final String description;
  final bool isSystemRole;
  final bool isActive;
  final ErpNavSection defaultDashboardSection;
  final Map<ErpModule, Set<ErpAction>> permissions;

  const Role({
    required this.id,
    required this.name,
    required this.description,
    this.isSystemRole = false,
    this.isActive = true,
    this.defaultDashboardSection = ErpNavSection.dashboard,
    required this.permissions,
  });

  bool hasPermission(ErpModule module, ErpAction action) {
    if (!isActive) return false;
    final actions = permissions[module];
    if (actions == null) return false;
    return actions.contains(action);
  }

  bool canAccessModule(ErpModule module) {
    if (!isActive) return false;
    return hasPermission(module, ErpAction.view);
  }

  Role copyWith({
    String? id,
    String? name,
    String? description,
    bool? isSystemRole,
    bool? isActive,
    ErpNavSection? defaultDashboardSection,
    Map<ErpModule, Set<ErpAction>>? permissions,
  }) {
    return Role(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isSystemRole: isSystemRole ?? this.isSystemRole,
      isActive: isActive ?? this.isActive,
      defaultDashboardSection: defaultDashboardSection ?? this.defaultDashboardSection,
      permissions: permissions ?? Map.from(this.permissions),
    );
  }
}

/// Temporary Access Grant Model
class TemporaryAccessGrant {
  final String id;
  final ErpModule module;
  final ErpAction? action; // If null, applies to whole module
  final String grantedToUserId;
  final String grantedByUserId;
  final String grantedByName;
  final DateTime grantedAt;
  final DateTime? expiresAt; // If null, active for session
  final bool isSessionOnly;

  const TemporaryAccessGrant({
    required this.id,
    required this.module,
    this.action,
    required this.grantedToUserId,
    required this.grantedByUserId,
    required this.grantedByName,
    required this.grantedAt,
    this.expiresAt,
    this.isSessionOnly = false,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool matches(ErpModule targetModule, [ErpAction? targetAction]) {
    if (isExpired) return false;
    if (module != targetModule) return false;
    if (action == null) return true; // Whole module granted
    if (targetAction == null) return true;
    return action == targetAction;
  }
}

/// Access and Security Audit Trail Model
class AuditLogEntry {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final ErpModule module;
  final ErpAction action;
  final String? sectionName;
  final DateTime timestamp;
  final String status; // 'allowed', 'denied', 'temporaryGranted'
  final String? authorizingUserId;
  final String? authorizingUserName;
  final int? durationMinutes;
  final String? notes;

  const AuditLogEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.module,
    required this.action,
    this.sectionName,
    required this.timestamp,
    required this.status,
    this.authorizingUserId,
    this.authorizingUserName,
    this.durationMinutes,
    this.notes,
  });

  String get statusLabel {
    switch (status) {
      case 'allowed':
        return 'Standard Allowed';
      case 'denied':
        return 'Access Denied';
      case 'temporaryGranted':
        return 'Temporary Override Granted';
      default:
        return status;
    }
  }
}

/// Authenticated user model with RBAC capabilities
class AppUser {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String passwordHash;
  final String salt;
  final String primaryRoleId;
  final List<String> assignedRoleIds;
  final Map<ErpModule, Set<ErpAction>> customPermissionOverrides;
  final bool isActive;
  final String avatarUrl;
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.passwordHash,
    required this.salt,
    required this.primaryRoleId,
    this.assignedRoleIds = const [],
    this.customPermissionOverrides = const {},
    this.isActive = true,
    required this.avatarUrl,
    this.lastLoginAt,
    required this.createdAt,
  });

  /// Role title alias for backward compatibility
  String get role => primaryRoleId;

  /// Check if user has permission considering primary role, assigned roles, custom overrides, and temporary grants
  bool hasPermission(
    ErpModule module,
    ErpAction action,
    List<Role> allRoles, [
    List<TemporaryAccessGrant>? temporaryGrants,
  ]) {
    if (!isActive) return false;

    // Super Admin has universal access
    if (primaryRoleId == 'admin') return true;

    // Check active temporary grants
    if (temporaryGrants != null) {
      for (final grant in temporaryGrants) {
        if (grant.grantedToUserId == id && grant.matches(module, action)) {
          return true;
        }
      }
    }

    // Check custom overrides (can explicitly grant)
    if (customPermissionOverrides.containsKey(module) &&
        customPermissionOverrides[module]!.contains(action)) {
      return true;
    }

    // Check primary role
    final primaryRole = allRoles.where((r) => r.id == primaryRoleId).firstOrNull;
    if (primaryRole != null && primaryRole.hasPermission(module, action)) {
      return true;
    }

    // Check additional assigned roles
    for (final roleId in assignedRoleIds) {
      final role = allRoles.where((r) => r.id == roleId).firstOrNull;
      if (role != null && role.hasPermission(module, action)) {
        return true;
      }
    }

    return false;
  }

  /// Check if user can view/access a given module
  bool canAccessModule(
    ErpModule module,
    List<Role> allRoles, [
    List<TemporaryAccessGrant>? temporaryGrants,
  ]) {
    return hasPermission(module, ErpAction.view, allRoles, temporaryGrants);
  }

  /// Map an ErpNavSection to its corresponding module
  static ErpModule mapSectionToModule(ErpNavSection section) {
    switch (section) {
      case ErpNavSection.dashboard:
        return ErpModule.dashboard;
      case ErpNavSection.inventoryDashboard:
      case ErpNavSection.rawMaterialStock:
      case ErpNavSection.finishedProductStock:
      case ErpNavSection.stockMovement:
      case ErpNavSection.stockAdjustments:
        return ErpModule.inventory;
      case ErpNavSection.purchaseDashboard:
      case ErpNavSection.purchaseList:
      case ErpNavSection.createPurchase:
      case ErpNavSection.purchaseHistory:
      case ErpNavSection.vendorPayments:
        return ErpModule.purchase;
      case ErpNavSection.productionDashboard:
      case ErpNavSection.productionOrders:
      case ErpNavSection.createProduction:
      case ErpNavSection.productionHistory:
      case ErpNavSection.productionCosting:
        return ErpModule.production;
      case ErpNavSection.salesDashboard:
      case ErpNavSection.quotations:
      case ErpNavSection.createQuotation:
      case ErpNavSection.proformaInvoices:
      case ErpNavSection.salesOrders:
      case ErpNavSection.createSalesOrder:
      case ErpNavSection.salesDeliveries:
      case ErpNavSection.salesInvoiceList:
      case ErpNavSection.createSale:
      case ErpNavSection.salesReturns:
      case ErpNavSection.createSalesReturn:
        return ErpModule.sales;
      case ErpNavSection.paymentsDashboard:
      case ErpNavSection.customerPayments:
      case ErpNavSection.dealerPayments:
      case ErpNavSection.vendorPaymentsSection:
      case ErpNavSection.commissionPayments:
      case ErpNavSection.expenseList:
        return ErpModule.payments;
      case ErpNavSection.mastersDashboard:
      case ErpNavSection.categoriesUnits:
      case ErpNavSection.vendors:
      case ErpNavSection.customers:
      case ErpNavSection.dealers:
      case ErpNavSection.architects:
      case ErpNavSection.rawMaterials:
      case ErpNavSection.finishedProducts:
      case ErpNavSection.projectList:
      case ErpNavSection.createProject:
        return ErpModule.masters;
      case ErpNavSection.reportsDashboard:
      case ErpNavSection.inventoryReports:
      case ErpNavSection.purchaseReports:
      case ErpNavSection.productionReports:
      case ErpNavSection.salesReports:
      case ErpNavSection.projectReports:
      case ErpNavSection.commissionReports:
      case ErpNavSection.financialReports:
        return ErpModule.reports;
      case ErpNavSection.settings:
        return ErpModule.settings;
    }
  }

  /// Check if user can navigate to a specific ERP section
  bool canAccessSection(
    ErpNavSection section,
    List<Role> allRoles, [
    List<TemporaryAccessGrant>? temporaryGrants,
  ]) {
    if (!isActive) return false;
    final module = mapSectionToModule(section);
    return canAccessModule(module, allRoles, temporaryGrants);
  }

  AppUser copyWith({
    String? id,
    String? name,
    String? email,
    String? mobile,
    String? passwordHash,
    String? salt,
    String? primaryRoleId,
    List<String>? assignedRoleIds,
    Map<ErpModule, Set<ErpAction>>? customPermissionOverrides,
    bool? isActive,
    String? avatarUrl,
    DateTime? lastLoginAt,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      primaryRoleId: primaryRoleId ?? this.primaryRoleId,
      assignedRoleIds: assignedRoleIds ?? this.assignedRoleIds,
      customPermissionOverrides: customPermissionOverrides ?? this.customPermissionOverrides,
      isActive: isActive ?? this.isActive,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
