import '../models/architect_model.dart';
import '../models/customer_model.dart';
import '../models/dealer_model.dart';
import 'api_client.dart';

/// Service for Customers, Dealers, Architects and Dual-Linking against NestJS `/api/v1/masters/*`
class PartiesApiService {
  final ApiClient _client = ApiClient.instance;

  // -------------------------------------------------------------
  // CUSTOMERS CRUD
  // -------------------------------------------------------------

  Future<List<Customer>> getCustomers({String? search, bool includeDeleted = false}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (includeDeleted) {
        queryParams['includeDeleted'] = 'true';
      }

      final response = await _client.dio.get(
        '/masters/customers',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<dynamic>(response);
      if (data is List) {
        return data.map((item) => Customer.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Customer> getCustomerById(String id) async {
    try {
      final response = await _client.dio.get('/masters/customers/$id');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Customer.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Customer> createCustomer(Customer customer) async {
    try {
      final response = await _client.dio.post(
        '/masters/customers',
        data: customer.toJson(),
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Customer.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Customer> updateCustomer(Customer customer) async {
    try {
      final response = await _client.dio.put(
        '/masters/customers/${customer.id}',
        data: customer.toJson(),
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Customer.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> deleteCustomer(String id, String reason) async {
    try {
      await _client.dio.delete(
        '/masters/customers/$id',
        data: {'deleteReason': reason.trim()},
      );
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  // -------------------------------------------------------------
  // DEALERS CRUD
  // -------------------------------------------------------------

  Future<List<Dealer>> getDealers({String? search, bool includeDeleted = false}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (includeDeleted) {
        queryParams['includeDeleted'] = 'true';
      }

      final response = await _client.dio.get(
        '/masters/dealers',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<dynamic>(response);
      if (data is List) {
        return data.map((item) => Dealer.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Dealer> getDealerById(String id) async {
    try {
      final response = await _client.dio.get('/masters/dealers/$id');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Dealer.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Dealer> createDealer(Dealer dealer) async {
    try {
      final response = await _client.dio.post(
        '/masters/dealers',
        data: dealer.toJson(),
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Dealer.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Dealer> updateDealer(Dealer dealer) async {
    try {
      final response = await _client.dio.put(
        '/masters/dealers/${dealer.id}',
        data: dealer.toJson(),
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Dealer.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> deleteDealer(String id, String reason) async {
    try {
      await _client.dio.delete(
        '/masters/dealers/$id',
        data: {'deleteReason': reason.trim()},
      );
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  // -------------------------------------------------------------
  // ARCHITECTS CRUD
  // -------------------------------------------------------------

  Future<List<Architect>> getArchitects({String? search, bool includeDeleted = false}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (includeDeleted) {
        queryParams['includeDeleted'] = 'true';
      }

      final response = await _client.dio.get(
        '/masters/architects',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<dynamic>(response);
      if (data is List) {
        return data.map((item) => Architect.fromJson(item as Map<String, dynamic>)).toList();
      }
      return [];
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Architect> getArchitectById(String id) async {
    try {
      final response = await _client.dio.get('/masters/architects/$id');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Architect.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Architect> createArchitect(Architect architect) async {
    try {
      final response = await _client.dio.post(
        '/masters/architects',
        data: architect.toJson(),
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Architect.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Architect> updateArchitect(Architect architect) async {
    try {
      final response = await _client.dio.put(
        '/masters/architects/${architect.id}',
        data: architect.toJson(),
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Architect.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<void> deleteArchitect(String id, String reason) async {
    try {
      await _client.dio.delete(
        '/masters/architects/$id',
        data: {'deleteReason': reason.trim()},
      );
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  // -------------------------------------------------------------
  // DUAL IDENTITY LINKING
  // -------------------------------------------------------------

  Future<void> linkArchitectAndCustomer({
    required String architectId,
    required String customerId,
  }) async {
    try {
      await _client.dio.post(
        '/masters/link-architect-customer',
        data: {
          'architectId': architectId,
          'customerId': customerId,
        },
      );
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
