import '../models/rbac_models.dart';
import 'api_client.dart';

/// Service for managing User records against NestJS `/api/v1/users`
class UsersApiService {
  final ApiClient _client = ApiClient.instance;

  Future<List<AppUser>> getUsers({String? search, String? roleId}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (roleId != null && roleId.trim().isNotEmpty) {
        queryParams['roleId'] = roleId.trim();
      }

      final response = await _client.dio.get('/users', queryParameters: queryParams);
      final data = _client.unwrap<dynamic>(response);
      if (data is List) {
        return data.map((item) => _mapToAppUser(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<AppUser> getUserById(String id) async {
    try {
      final response = await _client.dio.get('/users/$id');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return _mapToAppUser(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<AppUser> createUser({
    required String name,
    required String email,
    required String mobile,
    required String password,
    required String primaryRoleId,
    List<String>? assignedRoleIds,
  }) async {
    try {
      final response = await _client.dio.post(
        '/users',
        data: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'mobile': mobile.trim(),
          'password': password,
          'roleId': primaryRoleId,
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return _mapToAppUser(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<AppUser> updateUser(
    String id, {
    String? name,
    String? mobile,
    String? primaryRoleId,
    List<String>? assignedRoleIds,
    bool? isActive,
  }) async {
    try {
      final response = await _client.dio.patch(
        '/users/$id',
        data: {
          if (name != null) 'name': name.trim(),
          if (mobile != null) 'mobile': mobile.trim(),
          if (primaryRoleId != null) 'roleId': primaryRoleId,
          if (isActive != null) 'isActive': isActive,
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return _mapToAppUser(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> deleteUser(String id) async {
    try {
      await _client.dio.delete('/users/$id');
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  AppUser _mapToAppUser(Map<String, dynamic> json) {
    final roleId = json['roleId']?.toString() ?? json['primaryRoleId']?.toString() ?? 'data_entry';
    final rawRoles = (json['roles'] as List?)?.map((r) => r.toString()).toList() ?? [roleId];

    return AppUser(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      mobile: json['mobile']?.toString() ?? '',
      passwordHash: '',
      salt: '',
      primaryRoleId: roleId,
      assignedRoleIds: rawRoles,
      isActive: json['isActive'] != false && json['is_active'] != false,
      avatarUrl: json['avatarUrl']?.toString() ??
          'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.tryParse(json['lastLoginAt'].toString())
          : null,
    );
  }
}
