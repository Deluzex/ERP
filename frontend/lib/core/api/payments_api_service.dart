import '../models/commission_model.dart';
import '../models/payment_model.dart';
import 'api_client.dart';

/// Production API Service for Payments, Receipts & Architect Commissions (`/api/v1/payments/*`)
class PaymentsApiService {
  final ApiClient _client = ApiClient.instance;

  /// List Payments with optional filters and KPI summary metrics
  Future<Map<String, dynamic>> getPayments({
    String? search,
    String? paymentType,
    String? partyId,
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
      if (paymentType != null && paymentType.isNotEmpty && paymentType != 'all') {
        queryParams['paymentType'] = paymentType;
      }
      if (partyId != null && partyId.isNotEmpty) {
        queryParams['partyId'] = partyId;
      }
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['fromDate'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        queryParams['toDate'] = toDate;
      }

      final response = await _client.dio.get(
        '/payments',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<dynamic>(response);
      final rawList = (data is Map<String, dynamic> ? data['items'] : data) as List<dynamic>? ?? [];
      final payments = rawList
          .map((p) => ErpPayment.fromJson(p as Map<String, dynamic>))
          .toList();

      final summary = (response.data is Map<String, dynamic> &&
              response.data['meta'] is Map<String, dynamic> &&
              response.data['meta']['pagination'] is Map<String, dynamic>)
          ? response.data['meta']['pagination']['summary'] ?? {}
          : {};

      return {
        'items': payments,
        'summary': summary,
      };
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Record Payment / Customer Receipt / Vendor Payment / Commission Payout
  Future<ErpPayment> createPayment(Map<String, dynamic> payload) async {
    try {
      final response = await _client.dio.post(
        '/payments',
        data: payload,
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return ErpPayment.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// List Architect Commissions
  Future<Map<String, dynamic>> getCommissions({
    String? search,
    String? status,
    String? architectId,
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
      if (architectId != null && architectId.isNotEmpty) {
        queryParams['architectId'] = architectId;
      }

      final response = await _client.dio.get(
        '/payments/commissions',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<dynamic>(response);
      final rawList = (data is Map<String, dynamic> ? data['items'] : data) as List<dynamic>? ?? [];
      final commissions = rawList
          .map((c) => ArchitectCommission.fromJson(c as Map<String, dynamic>))
          .toList();

      final summary = (response.data is Map<String, dynamic> &&
              response.data['meta'] is Map<String, dynamic> &&
              response.data['meta']['pagination'] is Map<String, dynamic>)
          ? response.data['meta']['pagination']['summary'] ?? {}
          : {};

      return {
        'items': commissions,
        'summary': summary,
      };
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Approve Architect Commission
  Future<ArchitectCommission> approveCommission(String id, {String? notes}) async {
    try {
      final response = await _client.dio.post(
        '/payments/commissions/$id/approve',
        data: {
          if (notes != null) 'notes': notes,
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return ArchitectCommission.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Disburse Commission Payout and generate payment voucher atomically
  Future<Map<String, dynamic>> disburseCommission(
    String id, {
    required String paymentMode,
    String? transactionReference,
    String? notes,
  }) async {
    try {
      final response = await _client.dio.post(
        '/payments/commissions/$id/pay',
        data: {
          'paymentMode': paymentMode,
          if (transactionReference != null) 'transactionReference': transactionReference,
          if (notes != null) 'notes': notes,
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return {
        'commission': ArchitectCommission.fromJson(data['commission'] as Map<String, dynamic>),
        'payment': ErpPayment.fromJson(data['payment'] as Map<String, dynamic>),
      };
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Reject Architect Commission
  Future<ArchitectCommission> rejectCommission(String id, {String? reason}) async {
    try {
      final response = await _client.dio.post(
        '/payments/commissions/$id/reject',
        data: {
          if (reason != null) 'reason': reason,
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return ArchitectCommission.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
