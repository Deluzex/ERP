import '../models/category_unit_model.dart';
import 'api_client.dart';

/// Production API Service for Expense Category Masters (`/api/v1/expense-categories/*`)
class ExpenseCategoriesApiService {
  final ApiClient _client = ApiClient.instance;

  /// Fetch all expense categories with optional search and pagination
  Future<List<ExpenseCategoryMasterItem>> getExpenseCategories({
    String? search,
    bool? isActive,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (isActive != null) {
        queryParams['isActive'] = isActive;
      }

      final response = await _client.dio.get(
        '/expense-categories',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<dynamic>(response);
      final rawList = (data is Map<String, dynamic> ? data['items'] : data) as List<dynamic>? ?? [];
      return rawList
          .map((item) => ExpenseCategoryMasterItem.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Create new expense category master item
  Future<ExpenseCategoryMasterItem> createExpenseCategory({
    required String name,
    required String code,
    String? description,
    bool isActive = true,
    String? linkedKey,
  }) async {
    try {
      final response = await _client.dio.post(
        '/expense-categories',
        data: {
          'name': name.trim(),
          'code': code.trim().toUpperCase(),
          if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
          'isActive': isActive,
          if (linkedKey != null && linkedKey.trim().isNotEmpty) 'linkedKey': linkedKey.trim(),
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return ExpenseCategoryMasterItem.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Update expense category details
  Future<ExpenseCategoryMasterItem> updateExpenseCategory({
    required String id,
    String? name,
    String? code,
    String? description,
    bool? isActive,
    String? linkedKey,
  }) async {
    try {
      final response = await _client.dio.put(
        '/expense-categories/$id',
        data: {
          if (name != null) 'name': name.trim(),
          if (code != null) 'code': code.trim().toUpperCase(),
          if (description != null) 'description': description.trim(),
          'isActive': ?isActive,
          if (linkedKey != null) 'linkedKey': linkedKey.trim(),
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return ExpenseCategoryMasterItem.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Toggle active/inactive status
  Future<ExpenseCategoryMasterItem> toggleExpenseCategoryStatus(String id, bool isActive) async {
    try {
      final response = await _client.dio.patch(
        '/expense-categories/$id/status',
        data: {'isActive': isActive},
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return ExpenseCategoryMasterItem.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Delete expense category
  Future<void> deleteExpenseCategory(String id) async {
    try {
      await _client.dio.delete('/expense-categories/$id');
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
