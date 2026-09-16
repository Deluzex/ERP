import '../models/raw_material_model.dart';
import 'api_client.dart';

/// Service for Raw Material Master against NestJS `/api/v1/masters/raw-materials`
class RawMaterialsApiService {
  final ApiClient _client = ApiClient.instance;

  Future<List<RawMaterial>> getRawMaterials({
    String? search,
    String? categoryId,
    bool? lowStock,
    bool includeDeleted = false,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (categoryId != null && categoryId.isNotEmpty) {
        queryParams['categoryId'] = categoryId;
      }
      if (lowStock == true) {
        queryParams['lowStock'] = 'true';
      }
      if (includeDeleted) {
        queryParams['includeDeleted'] = 'true';
      }

      final response = await _client.dio.get(
        '/masters/raw-materials',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<dynamic>(response);
      if (data is List) {
        return data.map((item) => RawMaterial.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<RawMaterial> getRawMaterialById(String id) async {
    try {
      final response = await _client.dio.get('/masters/raw-materials/$id');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return RawMaterial.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<RawMaterial> createRawMaterial(RawMaterial rm) async {
    try {
      final response = await _client.dio.post(
        '/masters/raw-materials',
        data: rm.toJson(),
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return RawMaterial.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<RawMaterial> updateRawMaterial(RawMaterial rm) async {
    try {
      final response = await _client.dio.put(
        '/masters/raw-materials/${rm.id}',
        data: rm.toJson(),
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return RawMaterial.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> deleteRawMaterial(String id) async {
    try {
      await _client.dio.delete('/masters/raw-materials/$id');
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
