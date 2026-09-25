import '../models/rbac_models.dart';
import 'api_client.dart';
import 'token_storage.dart';

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final AppUser user;
  final List<String> permissions;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
    required this.permissions,
  });
}

class AuthApiService {
  final ApiClient _client = ApiClient.instance;

  Future<AuthResponse> login(String email, String password) async {
    try {
      final response = await _client.dio.post(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      final data = _client.unwrap<Map<String, dynamic>>(response);
      final accessToken = data['accessToken'] as String;
      final refreshToken = data['refreshToken'] as String;
      final expiresIn = (data['expiresIn'] as num?)?.toInt() ?? 900;
      final userJson = data['user'] as Map<String, dynamic>;

      TokenStorage.instance.saveTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );

      final permissionsList = (userJson['permissions'] as List?)?.map((p) => p.toString()).toList() ?? [];
      final appUser = _mapToAppUser(userJson, permissionsList);

      return AuthResponse(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiresIn: expiresIn,
        user: appUser,
        permissions: permissionsList,
      );
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<AppUser> getMe() async {
    try {
      final response = await _client.dio.get('/auth/me');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      final permissionsList = (data['permissions'] as List?)?.map((p) => p.toString()).toList() ?? [];
      return _mapToAppUser(data, permissionsList);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = TokenStorage.instance.refreshToken;
      await _client.dio.post(
        '/auth/logout',
        data: refreshToken != null ? {'refreshToken': refreshToken} : null,
      );
    } catch (_) {
      // Best-effort logout
    } finally {
      TokenStorage.instance.clear();
    }
  }

  AppUser _mapToAppUser(Map<String, dynamic> json, List<String> permissions) {
    final roleId = json['roleId']?.toString() ?? 'admin';
    final roleName = json['roleName']?.toString() ?? 'System Administrator';

    // Map permission strings like 'masters.view' into ErpModule -> Set<ErpAction>
    final overrides = <ErpModule, Set<ErpAction>>{};
    for (final p in permissions) {
      final parts = p.split('.');
      if (parts.length == 2) {
        final mod = _mapModule(parts[0]);
        final act = _mapAction(parts[1]);
        if (mod != null && act != null) {
          overrides.putIfAbsent(mod, () => <ErpAction>{}).add(act);
        }
      }
    }

    return AppUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? roleName,
      email: json['email']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      passwordHash: '',
      salt: '',
      primaryRoleId: roleId,
      assignedRoleIds: [roleId],
      customPermissionOverrides: overrides,
      isActive: json['isActive'] != false,
      avatarUrl: json['avatarUrl']?.toString() ?? 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      createdAt: DateTime.now(),
    );
  }

  ErpModule? _mapModule(String mod) {
    switch (mod.toLowerCase()) {
      case 'dashboard':
        return ErpModule.dashboard;
      case 'inventory':
        return ErpModule.inventory;
      case 'purchase':
        return ErpModule.purchase;
      case 'production':
        return ErpModule.production;
      case 'sales':
        return ErpModule.sales;
      case 'payments':
      case 'finance':
        return ErpModule.payments;
      case 'masters':
        return ErpModule.masters;
      case 'reports':
        return ErpModule.reports;
      case 'settings':
        return ErpModule.settings;
      case 'identity':
      case 'users':
      case 'usermanagement':
        return ErpModule.userManagement;
      default:
        return null;
    }
  }

  ErpAction? _mapAction(String act) {
    switch (act.toLowerCase()) {
      case 'view':
        return ErpAction.view;
      case 'create':
        return ErpAction.create;
      case 'edit':
        return ErpAction.edit;
      case 'delete':
        return ErpAction.delete;
      case 'approve':
        return ErpAction.approve;
      case 'cancel':
        return ErpAction.cancel;
      case 'export':
        return ErpAction.export;
      case 'print':
        return ErpAction.print;
      case 'share':
        return ErpAction.share;
      default:
        return null;
    }
  }
}
