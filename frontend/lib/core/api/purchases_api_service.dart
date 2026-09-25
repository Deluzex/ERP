import '../models/purchase_model.dart';
import 'api_client.dart';

/// Production API Service for Purchases & Procurement Management (`/api/v1/purchases/*`)
class PurchasesApiService {
  final ApiClient _client = ApiClient.instance;

  /// 7.1 List Purchases with filters and summary metrics
  Future<Map<String, dynamic>> getPurchases({
    String? search,
    String? status,
    String? purchaseType,
    String? vendorId,
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
      if (purchaseType != null && purchaseType.isNotEmpty && purchaseType != 'all') {
        queryParams['purchaseType'] = purchaseType;
      }
      if (vendorId != null && vendorId.isNotEmpty) {
        queryParams['vendorId'] = vendorId;
      }
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['fromDate'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        queryParams['toDate'] = toDate;
      }

      final response = await _client.dio.get(
        '/purchases',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<Map<String, dynamic>>(response);
      final rawList = data['items'] as List<dynamic>? ?? [];
      final purchases = rawList
          .map((p) => Purchase.fromJson(p as Map<String, dynamic>))
          .toList();

      return {
        'summary': data['summary'] ?? {},
        'purchases': purchases,
        'meta': data['pagination'] ?? {},
      };
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 7.2 Get Purchase details by ID
  Future<Purchase> getPurchaseById(String id) async {
    try {
      final response = await _client.dio.get('/purchases/$id');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Purchase.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 7.3 Create Purchase Order & Inward Bill (Transactional Stock Increment & Ledger)
  Future<Purchase> createPurchase(Purchase purchase) async {
    try {
      final payload = purchase.toJson();
      final response = await _client.dio.post(
        '/purchases',
        data: payload,
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Purchase.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 7.4 Update Purchase Status (with auto-rollback on cancellation)
  Future<Purchase> updatePurchaseStatus(
    String id, {
    required String status,
    String? cancelReason,
  }) async {
    try {
      final body = <String, dynamic>{
        'status': status,
        if (cancelReason != null) 'cancelReason': cancelReason,
      };
      final response = await _client.dio.patch(
        '/purchases/$id/status',
        data: body,
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Purchase.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
