import '../models/project_model.dart';
import 'api_client.dart';

/// Service for managing Architectural Projects against NestJS `/api/v1/projects`
class ProjectsApiService {
  final ApiClient _client = ApiClient.instance;

  Future<List<Project>> getProjects({
    String? search,
    String? status,
    String? customerId,
    String? architectId,
    String? dealerId,
    int? page,
    int? limit,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams['status'] = status;
      }
      if (customerId != null && customerId.isNotEmpty) {
        queryParams['customerId'] = customerId;
      }
      if (architectId != null && architectId.isNotEmpty) {
        queryParams['architectId'] = architectId;
      }
      if (dealerId != null && dealerId.isNotEmpty) {
        queryParams['dealerId'] = dealerId;
      }
      if (page != null) queryParams['page'] = page;
      if (limit != null) queryParams['limit'] = limit;

      final response = await _client.dio.get(
        '/projects',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<dynamic>(response);
      if (data is List) {
        return data.map((item) => Project.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Project> getProjectById(String id) async {
    try {
      final response = await _client.dio.get('/projects/$id');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Project.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Map<String, dynamic>> getProjectFinancials(String id) async {
    try {
      final response = await _client.dio.get('/projects/$id/financials');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return data;
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Project> createProject(Project project) async {
    try {
      final response = await _client.dio.post(
        '/projects',
        data: project.toJson(),
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Project.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Project> updateProject(Project project) async {
    try {
      final response = await _client.dio.put(
        '/projects/${project.id}',
        data: project.toJson(),
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Project.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> deleteProject(String id, String reason) async {
    try {
      await _client.dio.delete(
        '/projects/$id',
        data: {'reason': reason},
      );
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
