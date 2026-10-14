import '../models/finished_product_model.dart';
import 'api_client.dart';

/// Service for Finished Product Master against NestJS `/api/v1/masters/finished-products`
class FinishedProductsApiService {
  final ApiClient _client = ApiClient.instance;

  Future<List<FinishedProduct>> getFinishedProducts({
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
        '/masters/finished-products',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<dynamic>(response);
      if (data is List) {
        return data.map((item) => FinishedProduct.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<FinishedProduct> getFinishedProductById(String id) async {
    try {
      final response = await _client.dio.get('/masters/finished-products/$id');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return FinishedProduct.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<FinishedProduct> createFinishedProduct(FinishedProduct fp) async {
    try {
      final response = await _client.dio.post(
        '/masters/finished-products',
        data: fp.toJson(),
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return FinishedProduct.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<FinishedProduct> updateFinishedProduct(FinishedProduct fp) async {
    try {
      final response = await _client.dio.put(
        '/masters/finished-products/${fp.id}',
        data: fp.toUpdateJson(),
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return FinishedProduct.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> deleteFinishedProduct(String id) async {
    try {
      await _client.dio.delete('/masters/finished-products/$id');
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
