import '../models/bom_model.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Service for BOM Master against NestJS `/api/v1/boms`
/// (versioned bill of materials with DRAFT -> ACTIVE -> OBSOLETE lifecycle).
class BomsApiService {
  final ApiClient _client = ApiClient.instance;

  /// List BOM recipes, hydrated with their itemized components.
  Future<List<BillOfMaterial>> getBoms({
    String? search,
    String? productId,
    String? status,
    int limit = 200,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit,
      };
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (productId != null && productId.trim().isNotEmpty) {
        queryParams['productId'] = productId.trim();
      }
      if (status != null && status.trim().isNotEmpty) {
        queryParams['status'] = status.trim();
      }

      final response = await _client.dio.get(
        '/boms',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<Map<String, dynamic>>(response);
      final rows = ((data['items'] ?? const []) as List)
          .whereType<Map<String, dynamic>>()
          .toList();

      // The list endpoint returns headers only (itemCount, no components), so
      // hydrate each recipe with its items for quantity/cost details.
      final hydrated = await Future.wait(rows.map((row) async {
        final id = row['id']?.toString() ?? '';
        final itemCount = (row['itemCount'] as num?)?.toInt() ?? 0;
        if (id.isEmpty || itemCount <= 0) {
          return _mapBomRow(row);
        }
        try {
          return await getBomById(id);
        } catch (_) {
          return _mapBomRow(row);
        }
      }));
      return hydrated;
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Get BOM recipe details by ID including itemized components.
  Future<BillOfMaterial> getBomById(String id) async {
    try {
      final response = await _client.dio.get('/boms/$id');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return _mapBomRow(
        data,
        _mapBomItems((data['items'] ?? const []) as List),
      );
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Create a new BOM recipe and return the persisted record ( hydrated ).
  Future<BillOfMaterial> createBom({
    required String finishedProductId,
    required double yieldQuantity,
    required bool active,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await _client.dio.post(
        '/boms',
        data: {
          'finishedProductId': finishedProductId,
          if (yieldQuantity > 0) 'yieldQuantity': yieldQuantity,
          'status': active ? 'ACTIVE' : 'DRAFT',
          'items': items,
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      final createdId = data['id']?.toString() ?? '';
      if (createdId.isEmpty) {
        throw ApiException(
          statusCode: response.statusCode,
          errorCode: 'CREATE_BOM_FAILED',
          message: 'BOM creation failed',
        );
      }
      // Re-read the authoritative record so the list entry includes server
      // assigned number/version/status and the resolved item components. If
      // the read-back fails the create itself still persisted, so fall back to
      // the create summary instead of reporting a failed save.
      try {
        return await getBomById(createdId);
      } catch (_) {
        return _mapBomRow(data);
      }
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Update a DRAFT BOM recipe (quantities, yield and item components).
  Future<BillOfMaterial> updateBom(
    String id, {
    required double yieldQuantity,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final response = await _client.dio.put(
        '/boms/$id',
        data: {
          if (yieldQuantity > 0) 'yieldQuantity': yieldQuantity,
          'items': items,
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return _mapBomRow(
        data,
        _mapBomItems((data['items'] ?? const []) as List),
      );
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Update BOM lifecycle status (DRAFT -> ACTIVE -> OBSOLETE).
  Future<BillOfMaterial> updateStatus(String id, String status) async {
    try {
      final response = await _client.dio.patch(
        '/boms/$id/status',
        data: {'status': status},
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return _mapBomRow(
        data,
        _mapBomItems((data['items'] ?? const []) as List),
      );
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  // --------------------------------------------------------------------------
  // Mapping helpers (backend snake/camel rows -> frontend models)
  // --------------------------------------------------------------------------
  BillOfMaterial _mapBomRow(Map<String, dynamic> r, [List<BomItem>? items]) {
    final rawStatus = (r['status']?.toString() ?? 'ACTIVE').trim().toUpperCase();
    final displayStatus =
        rawStatus == 'DRAFT' ? 'Draft' : (rawStatus == 'OBSOLETE' ? 'Inactive' : 'Active');
    final fpName = r['finishedProductName']?.toString() ?? '';
    return BillOfMaterial(
      id: r['id']?.toString() ?? '',
      bomNumber: r['bomNumber']?.toString() ?? '',
      finishedProductId: r['finishedProductId']?.toString() ?? '',
      finishedProductName: fpName,
      finishedProductCode: r['finishedProductCode']?.toString() ?? '',
      // The backend BOM Master has no dedicated recipe-name column; derive a
      // stable display name from the finished product (matches the create
      // screen's default naming).
      name: fpName.isNotEmpty ? '$fpName Recipe' : '',
      outputQuantity: ((r['yieldQuantity'] as num?) ?? 1.0).toDouble(),
      isActive: rawStatus == 'ACTIVE',
      status: displayStatus,
      items: items ?? const <BomItem>[],
      createdAt: DateTime.tryParse(r['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(r['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  List<BomItem> _mapBomItems(List<dynamic> rawItems) {
    return rawItems.whereType<Map<String, dynamic>>().map((e) {
      return BomItem(
        id: e['id']?.toString() ?? '',
        rawMaterialId: e['rawMaterialId']?.toString() ?? '',
        rawMaterialName: e['rawMaterialName']?.toString() ?? '',
        rawMaterialCode: e['rawMaterialCode']?.toString() ?? '',
        quantityPerUnit: ((e['quantity'] as num?) ?? 0.0).toDouble(),
        wastagePercent: ((e['scrapPercentage'] as num?) ?? 0.0).toDouble(),
        unit: e['unit']?.toString() ?? 'PCS',
        unitCost: ((e['unitCost'] as num?) ?? 0.0).toDouble(),
      );
    }).toList();
  }
}
