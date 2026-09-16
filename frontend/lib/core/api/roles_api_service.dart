import '../models/rbac_models.dart';
import '../../app/routes/app_routes.dart';
import 'api_client.dart';

/// Service for managing Role records against NestJS `/api/v1/roles`
class RolesApiService {
  final ApiClient _client = ApiClient.instance;

  Future<List<Role>> getRoles() async {
    try {
      final response = await _client.dio.get('/roles');
      final data = _client.unwrap<dynamic>(response);
      if (data is List) {
        return data.map((item) => _mapToRole(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Role> getRoleById(String id) async {
    try {
      final response = await _client.dio.get('/roles/$id');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return _mapToRole(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Role> createRole({
    required String id,
    required String name,
    required String description,
    required List<String> permissions,
    String? defaultDashboardSection,
  }) async {
    try {
      final response = await _client.dio.post(
        '/roles',
        data: {
          'id': id,
          'name': name,
          'description': description,
          'permissions': permissions,
          if (defaultDashboardSection != null) 'defaultDashboardSection': defaultDashboardSection,
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return _mapToRole(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> updateRolePermissions(String roleId, List<String> permissions) async {
    try {
      await _client.dio.put(
        '/roles/$roleId/permissions',
        data: {
          'permissionIds': permissions,
        },
      );
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> deleteRole(String roleId) async {
    try {
      await _client.dio.delete('/roles/$roleId');
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Role _mapToRole(Map<String, dynamic> json) {
    final rawPerms = (json['permissions'] as List?)?.map((p) => p.toString()).toList() ?? [];
    final permMap = permissionStringsToMap(rawPerms);

    final sectionStr = json['defaultDashboardSection']?.toString();
    ErpNavSection defaultSec = ErpNavSection.dashboard;
    for (final sec in ErpNavSection.values) {
      if (sec.name == sectionStr) {
        defaultSec = sec;
        break;
      }
    }

    return Role(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      isSystemRole: json['isSystemRole'] == true || json['is_system_role'] == true,
      isActive: json['isActive'] != false && json['is_active'] != false,
      defaultDashboardSection: defaultSec,
      permissions: permMap,
    );
  }

  static Map<ErpModule, Set<ErpAction>> permissionStringsToMap(List<String> list) {
    final Map<ErpModule, Set<ErpAction>> map = {};
    for (final p in list) {
      final parts = p.split('.');
      if (parts.length < 2) continue;
      final mod = _mapModule(parts[0]);
      final act = _mapAction(parts[1]);
      if (mod != null && act != null) {
        map.putIfAbsent(mod, () => <ErpAction>{}).add(act);
      }
    }
    return map;
  }

  static List<String> permissionMapToStrings(Map<ErpModule, Set<ErpAction>> map) {
    final List<String> result = [];
    map.forEach((mod, actions) {
      final modStr = _moduleToString(mod);
      for (final act in actions) {
        final actStr = _actionToString(act);
        result.add('$modStr.$actStr');
      }
    });
    return result;
  }

  static ErpModule? _mapModule(String mod) {
    switch (mod.toLowerCase()) {
      case 'dashboard': return ErpModule.dashboard;
      case 'inventory': return ErpModule.inventory;
      case 'purchase': return ErpModule.purchase;
      case 'production': return ErpModule.production;
      case 'sales': return ErpModule.sales;
      case 'payments':
      case 'finance': return ErpModule.payments;
      case 'masters': return ErpModule.masters;
      case 'reports': return ErpModule.reports;
      case 'settings': return ErpModule.settings;
      case 'usermanagement':
      case 'identity': return ErpModule.userManagement;
      default: return null;
    }
  }

  static String _moduleToString(ErpModule mod) {
    switch (mod) {
      case ErpModule.dashboard: return 'dashboard';
      case ErpModule.inventory: return 'inventory';
      case ErpModule.purchase: return 'purchase';
      case ErpModule.production: return 'production';
      case ErpModule.sales: return 'sales';
      case ErpModule.payments: return 'payments';
      case ErpModule.masters: return 'masters';
      case ErpModule.reports: return 'reports';
      case ErpModule.settings: return 'settings';
      case ErpModule.userManagement: return 'settings';
    }
  }

  static ErpAction? _mapAction(String act) {
    switch (act.toLowerCase()) {
      case 'view': return ErpAction.view;
      case 'create': return ErpAction.create;
      case 'edit': return ErpAction.edit;
      case 'delete': return ErpAction.delete;
      case 'approve': return ErpAction.approve;
      case 'cancel': return ErpAction.cancel;
      case 'export': return ErpAction.export;
      case 'print': return ErpAction.print;
      case 'share': return ErpAction.share;
      default: return null;
    }
  }

  static String _actionToString(ErpAction act) {
    return act.name;
  }
}
