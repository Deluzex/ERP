import '../models/production_model.dart';
import 'api_client.dart';

/// Production API Service for Manufacturing & Production Domain (`/api/v1/production/*`)
class ProductionApiService {
  final ApiClient _client = ApiClient.instance;

  /// 8.1 List Production Orders with metrics
  Future<Map<String, dynamic>> getProductionOrders({
    String? search,
    String? status,
    String? finishedProductId,
    String? fromDate,
    String? toDate,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams['status'] = status;
      }
      if (finishedProductId != null && finishedProductId.isNotEmpty) {
        queryParams['finishedProductId'] = finishedProductId;
      }
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['fromDate'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        queryParams['toDate'] = toDate;
      }

      final response = await _client.dio.get(
        '/production/orders',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<Map<String, dynamic>>(response);
      final rawList = data['orders'] as List<dynamic>? ?? [];
      final orders = rawList
          .map((item) => ProductionOrder.fromJson(item as Map<String, dynamic>))
          .toList();

      return {
        'summary': data['summary'] ?? {},
        'orders': orders,
        'meta': data['meta'] ?? {},
      };
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 8.4 Get Production Order by ID
  Future<ProductionOrder> getOrderById(String id) async {
    try {
      final response = await _client.dio.get('/production/orders/$id');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return ProductionOrder.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 8.3 Create Production Order (supports direct 1-step completion)
  Future<ProductionOrder> createOrder(Map<String, dynamic> payload) async {
    try {
      final response = await _client.dio.post(
        '/production/orders',
        data: payload,
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return ProductionOrder.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 8.5 Cancel/Delete Production Order with rollback
  Future<ProductionOrder> cancelOrder(String id, {required String reason}) async {
    try {
      final response = await _client.dio.delete(
        '/production/orders/$id',
        data: {'reason': reason},
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return ProductionOrder.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 8.2 Get Bill of Materials recipe
  Future<Map<String, dynamic>?> getBom(String finishedProductId) async {
    try {
      final response = await _client.dio.get('/production/bom/$finishedProductId');
      return _client.unwrap<Map<String, dynamic>>(response);
    } catch (e) {
      return null;
    }
  }

  /// 8.2 Save Bill of Materials recipe
  Future<Map<String, dynamic>> saveBom(
    String finishedProductId,
    List<Map<String, dynamic>> items, {
    String? notes,
  }) async {
    try {
      final response = await _client.dio.post(
        '/production/bom',
        data: {
          'finishedProductId': finishedProductId,
          'notes': notes,
          'items': items,
        },
      );
      return _client.unwrap<Map<String, dynamic>>(response);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
