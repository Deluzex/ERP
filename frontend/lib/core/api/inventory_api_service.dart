import '../models/stock_adjustment_model.dart';
import '../models/stock_movement_model.dart';
import '../models/whatsapp_models.dart';
import 'api_client.dart';

/// Production API Service for Inventory & Stock Ledger (`/api/v1/inventory/*`)
class InventoryApiService {
  final ApiClient _client = ApiClient.instance;

  /// 6.1 Get Raw Materials Stock with summary metrics
  Future<Map<String, dynamic>> getRawMaterialsStock({
    String? search,
    String? categoryId,
    bool? isLowStock,
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
      if (categoryId != null && categoryId.isNotEmpty) {
        queryParams['categoryId'] = categoryId;
      }
      if (isLowStock == true) {
        queryParams['isLowStock'] = 'true';
      }

      final response = await _client.dio.get(
        '/inventory/raw-materials',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<Map<String, dynamic>>(response);
      return data;
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 6.2 Get Finished Products Stock with summary metrics
  Future<Map<String, dynamic>> getFinishedProductsStock({
    String? search,
    String? categoryId,
    bool? isLowStock,
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
      if (categoryId != null && categoryId.isNotEmpty) {
        queryParams['categoryId'] = categoryId;
      }
      if (isLowStock == true) {
        queryParams['isLowStock'] = 'true';
      }

      final response = await _client.dio.get(
        '/inventory/finished-products',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<Map<String, dynamic>>(response);
      return data;
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 6.3 Get Immutable Stock Movement Ledger
  Future<List<StockMovement>> getStockMovements({
    String? itemId,
    ItemType? itemType,
    StockMovementType? transactionType,
    DateTime? startDate,
    DateTime? endDate,
    String? search,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (itemId != null && itemId.isNotEmpty) {
        queryParams['itemId'] = itemId;
      }
      if (itemType != null) {
        queryParams['itemType'] = itemType.name;
      }
      if (transactionType != null) {
        queryParams['transactionType'] = transactionType.name;
      }
      if (startDate != null) {
        queryParams['startDate'] = startDate.toIso8601String();
      }
      if (endDate != null) {
        queryParams['endDate'] = endDate.toIso8601String();
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }

      final response = await _client.dio.get(
        '/inventory/stock-movements',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<Map<String, dynamic>>(response);
      final items = data['items'] as List<dynamic>? ?? [];
      return items.map((m) => StockMovement.fromJson(m as Map<String, dynamic>)).toList();
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 6.4 Perform Stock Adjustment
  Future<StockAdjustment> performStockAdjustment({
    required String itemId,
    required ItemType itemType,
    required double adjustedStockAfter,
    required AdjustmentReason reason,
    String? remarks,
  }) async {
    try {
      final response = await _client.dio.post(
        '/inventory/stock-adjustments',
        data: {
          'itemId': itemId,
          'itemType': itemType.name,
          'adjustedStockAfter': adjustedStockAfter,
          'reason': reason.name,
          'remarks': remarks,
        },
      );

      final data = _client.unwrap<Map<String, dynamic>>(response);
      return StockAdjustment.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 6.4 Get Historical Stock Adjustments
  Future<List<StockAdjustment>> getStockAdjustments({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _client.dio.get(
        '/inventory/stock-adjustments',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      final data = _client.unwrap<Map<String, dynamic>>(response);
      final items = data['items'] as List<dynamic>? ?? [];
      return items.map((a) => StockAdjustment.fromJson(a as Map<String, dynamic>)).toList();
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 6.5 Trigger WhatsApp Low Stock Alert
  Future<Map<String, dynamic>> triggerLowStockAlert({
    required String itemId,
    required ItemType itemType,
    String? recipientId,
    String? recipientName,
    String? recipientWhatsApp,
    String? customMessage,
  }) async {
    try {
      final response = await _client.dio.post(
        '/inventory/trigger-low-stock-alert',
        data: {
          'itemId': itemId,
          'itemType': itemType.name,
          'recipientId': recipientId,
          'recipientName': recipientName,
          'recipientWhatsApp': recipientWhatsApp,
          'customMessage': customMessage,
        },
      );

      return _client.unwrap<Map<String, dynamic>>(response);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 6.6 Get Low Stock Alert Logs
  Future<List<LowStockAlertRecord>> getLowStockAlerts({
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final response = await _client.dio.get(
        '/inventory/low-stock-alerts',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      final data = _client.unwrap<Map<String, dynamic>>(response);
      final items = data['items'] as List<dynamic>? ?? [];
      return items.map((a) {
        final map = a as Map<String, dynamic>;
        final statusStr = map['status'] as String? ?? 'sent';
        final status = statusStr == 'resolved'
            ? AlertRecordStatus.resolved
            : AlertRecordStatus.sent;

        return LowStockAlertRecord(
          id: map['id'] as String? ?? '',
          itemId: map['itemId'] as String? ?? '',
          itemName: map['itemName'] as String? ?? '',
          itemCode: map['itemCode'] as String? ?? '',
          itemType: (map['itemType'] as String? ?? '') == 'rawMaterial'
              ? 'Raw Material'
              : 'Finished Product',
          currentStock: (map['currentStock'] as num?)?.toDouble() ?? 0.0,
          minimumStock: (map['minimumStock'] as num?)?.toDouble() ?? 0.0,
          reorderLevel: (map['reorderLevel'] as num?)?.toDouble() ?? 0.0,
          unit: map['unit'] as String? ?? 'PCS',
          recipientName: map['recipientName'] as String? ?? 'Warehouse Manager',
          recipientWhatsApp: map['recipientWhatsApp'] as String? ?? '',
          messageBody: map['customMessage'] as String? ?? '',
          status: status,
          triggeredAt: map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
              : DateTime.now(),
          resolvedAt: map['resolvedAt'] != null
              ? DateTime.tryParse(map['resolvedAt'] as String)
              : null,
        );
      }).toList();
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 6.7 Resolve Low Stock Alert
  Future<Map<String, dynamic>> resolveLowStockAlert(String alertId) async {
    try {
      final response = await _client.dio.patch(
        '/inventory/low-stock-alerts/$alertId/resolve',
      );

      return _client.unwrap<Map<String, dynamic>>(response);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
