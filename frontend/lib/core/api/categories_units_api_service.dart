import '../models/category_unit_model.dart';
import 'api_client.dart';

/// Service for Category and Unit Masters against NestJS `/api/v1/masters/categories` and `/units`
class CategoriesUnitsApiService {
  final ApiClient _client = ApiClient.instance;

  // -------------------------------------------------------------
  // Categories CRUD
  // -------------------------------------------------------------

  Future<List<ItemCategory>> getCategories() async {
    try {
      final response = await _client.dio.get('/masters/categories');
      final data = _client.unwrap<dynamic>(response);
      if (data is List) {
        return data.map((item) => ItemCategory.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<ItemCategory> createCategory({required String name, String? description}) async {
    try {
      final response = await _client.dio.post(
        '/masters/categories',
        data: {
          'name': name.trim(),
          if (description != null) 'description': description.trim(),
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return ItemCategory.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<ItemCategory> updateCategory({required String id, required String name, String? description}) async {
    try {
      final response = await _client.dio.put(
        '/masters/categories/$id',
        data: {
          'name': name.trim(),
          if (description != null) 'description': description.trim(),
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return ItemCategory.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _client.dio.delete('/masters/categories/$id');
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  // -------------------------------------------------------------
  // Measurement Units CRUD
  // -------------------------------------------------------------

  Future<List<MeasurementUnit>> getUnits() async {
    try {
      final response = await _client.dio.get('/masters/units');
      final data = _client.unwrap<dynamic>(response);
      if (data is List) {
        return data.map((item) => MeasurementUnit.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<MeasurementUnit> createUnit({required String name, required String symbol}) async {
    try {
      final response = await _client.dio.post(
        '/masters/units',
        data: {
          'name': name.trim(),
          'symbol': symbol.trim().toUpperCase(),
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return MeasurementUnit.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<MeasurementUnit> updateUnit({required String id, required String name, required String symbol}) async {
    try {
      final response = await _client.dio.put(
        '/masters/units/$id',
        data: {
          'name': name.trim(),
          'symbol': symbol.trim().toUpperCase(),
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return MeasurementUnit.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> deleteUnit(String id) async {
    try {
      await _client.dio.delete('/masters/units/$id');
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
