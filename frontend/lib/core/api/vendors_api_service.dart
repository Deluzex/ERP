import '../models/vendor_model.dart';
import 'api_client.dart';

/// Service for managing Vendor records against NestJS `/api/v1/masters/vendors`
class VendorsApiService {
  final ApiClient _client = ApiClient.instance;

  Future<List<Vendor>> getVendors({String? search, bool includeDeleted = false}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (includeDeleted) {
        queryParams['includeDeleted'] = 'true';
      }

      final response = await _client.dio.get(
        '/masters/vendors',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<dynamic>(response);
      if (data is List) {
        return data.map((item) => Vendor.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Vendor> getVendorById(String id) async {
    try {
      final response = await _client.dio.get('/masters/vendors/$id');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Vendor.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Vendor> createVendor(Vendor vendor) async {
    try {
      final response = await _client.dio.post(
        '/masters/vendors',
        data: vendor.toJson(),
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Vendor.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Vendor> updateVendor(Vendor vendor) async {
    try {
      final response = await _client.dio.put(
        '/masters/vendors/${vendor.id}',
        data: vendor.toJson(),
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Vendor.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> deleteVendor(String id, String reason) async {
    try {
      await _client.dio.delete(
        '/masters/vendors/$id',
        data: {
          'deleteReason': reason.trim(),
        },
      );
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
