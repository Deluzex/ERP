import '../models/purchase_model.dart';
import '../models/sale_model.dart';
import 'api_client.dart';

/// Production API Service for Sales & Commercial Lifecycle (`/api/v1/sales/*`)
class SalesApiService {
  final ApiClient _client = ApiClient.instance;

  Map<String, dynamic> _lineItemDto(SaleLineItem item) => item.toJson();

  Future<Map<String, dynamic>> _list(
    String path, {
    String? status,
    String? search,
    String? partyId,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (status != null && status.isNotEmpty && status != 'all') {
        queryParams['status'] = status;
      }
      if (search != null && search.trim().isNotEmpty) {
        queryParams['search'] = search.trim();
      }
      if (partyId != null && partyId.isNotEmpty) {
        queryParams['partyId'] = partyId;
      }

      final response = await _client.dio.get(path, queryParameters: queryParams);
      final data = _client.unwrap<Map<String, dynamic>>(response);
      final rawItems = data['items'] as List<dynamic>? ?? [];
      final items = rawItems.map((i) => Sale.fromJson(i as Map<String, dynamic>)).toList();

      return {
        'items': items,
        'total': data['total'] ?? items.length,
        'page': data['page'] ?? page,
        'limit': data['limit'] ?? limit,
        'totalPages': data['totalPages'] ?? 1,
      };
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Sale> _getById(String path) async {
    try {
      final response = await _client.dio.get(path);
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  // ==========================================================================
  // DASHBOARD
  // ==========================================================================
  Future<Map<String, dynamic>> getDashboardMetrics() async {
    try {
      final response = await _client.dio.get('/sales/dashboard');
      return _client.unwrap<Map<String, dynamic>>(response);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  // ==========================================================================
  // QUOTATIONS
  // ==========================================================================
  Future<Map<String, dynamic>> getQuotations({String? status, String? search, String? partyId, int page = 1, int limit = 50}) =>
      _list('/sales/quotations', status: status, search: search, partyId: partyId, page: page, limit: limit);

  Future<Sale> getQuotationById(String id) => _getById('/sales/quotations/$id');

  Future<Sale> createQuotation({
    required PartyType partyType,
    required String partyId,
    String? architectId,
    String? projectId,
    String? salesExecutive,
    int? validDays,
    bool isInterStateTax = false,
    bool isDraft = false,
    required List<SaleLineItem> items,
    String? notes,
    String? termsAndConditions,
  }) async {
    try {
      final body = <String, dynamic>{
        'partyType': partyType.name,
        'partyId': partyId,
        if (architectId != null) 'architectId': architectId,
        if (projectId != null) 'projectId': projectId,
        if (salesExecutive != null) 'salesExecutive': salesExecutive,
        if (validDays != null) 'validDays': validDays,
        'isInterStateTax': isInterStateTax,
        'isDraft': isDraft,
        'items': items.map(_lineItemDto).toList(),
        if (notes != null) 'notes': notes,
        if (termsAndConditions != null) 'termsAndConditions': termsAndConditions,
      };
      final response = await _client.dio.post('/sales/quotations', data: body);
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Sale> createQuotationRevision(
    String id, {
    double? discountAmount,
    String? notes,
    String? termsAndConditions,
    bool isDraft = false,
    required List<SaleLineItem> items,
  }) async {
    try {
      final body = <String, dynamic>{
        if (discountAmount != null) 'discountAmount': discountAmount,
        if (notes != null) 'notes': notes,
        if (termsAndConditions != null) 'termsAndConditions': termsAndConditions,
        'isDraft': isDraft,
        'items': items.map(_lineItemDto).toList(),
      };
      final response = await _client.dio.post('/sales/quotations/$id/revisions', data: body);
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Sale> updateQuotationStatus(String id, String status) async {
    try {
      final response = await _client.dio.patch('/sales/quotations/$id/status', data: {'status': status});
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Sale> convertQuotationToProforma(String id) async {
    try {
      final response = await _client.dio.post('/sales/quotations/$id/convert-to-proforma');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  // ==========================================================================
  // PROFORMA INVOICES
  // ==========================================================================
  Future<Map<String, dynamic>> getProforma({String? status, String? search, String? partyId, int page = 1, int limit = 50}) =>
      _list('/sales/proforma', status: status, search: search, partyId: partyId, page: page, limit: limit);

  Future<Sale> getProformaById(String id) => _getById('/sales/proforma/$id');

  Future<Sale> recordProformaAdvancePayment(
    String id, {
    required double amount,
    required PaymentMode paymentMode,
    String? transactionReference,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'amount': amount,
        'paymentMode': paymentMode.name,
        if (transactionReference != null) 'transactionReference': transactionReference,
        if (notes != null) 'notes': notes,
      };
      final response = await _client.dio.post('/sales/proforma/$id/advance-payment', data: body);
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  // ==========================================================================
  // SALES ORDERS
  // ==========================================================================
  Future<Map<String, dynamic>> getSalesOrders({String? status, String? search, String? partyId, int page = 1, int limit = 50}) =>
      _list('/sales/orders', status: status, search: search, partyId: partyId, page: page, limit: limit);

  Future<Sale> getSalesOrderById(String id) => _getById('/sales/orders/$id');

  Future<Sale> createSalesOrder({
    required PartyType partyType,
    required String partyId,
    String? architectId,
    String? projectId,
    String? salesExecutive,
    String? deliveryDate,
    PaymentMode paymentMode = PaymentMode.bankTransfer,
    bool isInterStateTax = false,
    required List<SaleLineItem> items,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'partyType': partyType.name,
        'partyId': partyId,
        if (architectId != null) 'architectId': architectId,
        if (projectId != null) 'projectId': projectId,
        if (salesExecutive != null) 'salesExecutive': salesExecutive,
        if (deliveryDate != null) 'deliveryDate': deliveryDate,
        'paymentMode': paymentMode.name,
        'isInterStateTax': isInterStateTax,
        'items': items.map(_lineItemDto).toList(),
        if (notes != null) 'notes': notes,
      };
      final response = await _client.dio.post('/sales/orders', data: body);
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Sale> updateSalesOrderStatus(String id, String status) async {
    try {
      final response = await _client.dio.patch('/sales/orders/$id/status', data: {'status': status});
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  // ==========================================================================
  // DELIVERIES
  // ==========================================================================
  Future<Map<String, dynamic>> getDeliveries({String? status, String? search, String? partyId, int page = 1, int limit = 50}) =>
      _list('/sales/deliveries', status: status, search: search, partyId: partyId, page: page, limit: limit);

  Future<Sale> getDeliveryById(String id) => _getById('/sales/deliveries/$id');

  Future<Sale> createDelivery({
    required String salesOrderId,
    String? vehicleNumber,
    String? driverContact,
    String? courierName,
    String? trackingNumber,
    String? expectedDeliveryDate,
    String? dispatchNotes,
    required List<SaleLineItem> items,
  }) async {
    try {
      final body = <String, dynamic>{
        'salesOrderId': salesOrderId,
        if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
        if (driverContact != null) 'driverContact': driverContact,
        if (courierName != null) 'courierName': courierName,
        if (trackingNumber != null) 'trackingNumber': trackingNumber,
        if (expectedDeliveryDate != null) 'expectedDeliveryDate': expectedDeliveryDate,
        if (dispatchNotes != null) 'dispatchNotes': dispatchNotes,
        'items': items
            .map((i) => {
                  'finishedProductId': i.finishedProductId,
                  'quantity': i.quantity,
                })
            .toList(),
      };
      final response = await _client.dio.post('/sales/deliveries', data: body);
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Sale> updateDeliveryTracking(
    String id, {
    String? courierName,
    String? trackingNumber,
    String? vehicleNumber,
    String? driverContact,
    String? dispatchNotes,
  }) async {
    try {
      final body = <String, dynamic>{
        if (courierName != null) 'courierName': courierName,
        if (trackingNumber != null) 'trackingNumber': trackingNumber,
        if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
        if (driverContact != null) 'driverContact': driverContact,
        if (dispatchNotes != null) 'dispatchNotes': dispatchNotes,
      };
      final response = await _client.dio.patch('/sales/deliveries/$id/tracking', data: body);
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  // ==========================================================================
  // TAX INVOICES & POS DIRECT SALE
  // ==========================================================================
  Future<Map<String, dynamic>> getInvoices({String? status, String? search, String? partyId, int page = 1, int limit = 50}) =>
      _list('/sales/invoices', status: status, search: search, partyId: partyId, page: page, limit: limit);

  Future<Sale> getInvoiceById(String id) => _getById('/sales/invoices/$id');

  Future<Sale> createInvoiceFromDelivery({
    required String deliveryId,
    double discountAmount = 0,
    double initialPaidAmount = 0,
    PaymentMode paymentMode = PaymentMode.bankTransfer,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'deliveryId': deliveryId,
        'discountAmount': discountAmount,
        'initialPaidAmount': initialPaidAmount,
        'paymentMode': paymentMode.name,
        if (notes != null) 'notes': notes,
      };
      final response = await _client.dio.post('/sales/invoices/from-delivery', data: body);
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Sale> createDirectSale({
    required PartyType partyType,
    required String partyId,
    String? architectId,
    String? projectId,
    required List<SaleLineItem> items,
    double paidAmount = 0,
    PaymentMode paymentMode = PaymentMode.upi,
    bool isInterStateTax = false,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'partyType': partyType.name,
        'partyId': partyId,
        if (architectId != null) 'architectId': architectId,
        if (projectId != null) 'projectId': projectId,
        'items': items.map(_lineItemDto).toList(),
        'paidAmount': paidAmount,
        'paymentMode': paymentMode.name,
        'isInterStateTax': isInterStateTax,
        if (notes != null) 'notes': notes,
      };
      final response = await _client.dio.post('/sales/direct-sale', data: body);
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Sale> recordInvoicePayment(
    String id, {
    required double amount,
    required PaymentMode paymentMode,
    String? transactionReference,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'amount': amount,
        'paymentMode': paymentMode.name,
        if (transactionReference != null) 'transactionReference': transactionReference,
        if (notes != null) 'notes': notes,
      };
      final response = await _client.dio.post('/sales/invoices/$id/payments', data: body);
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  // ==========================================================================
  // SALES RETURNS (RMA) & REFUNDS
  // ==========================================================================
  Future<Map<String, dynamic>> getReturns({String? status, String? search, String? partyId, int page = 1, int limit = 50}) =>
      _list('/sales/returns', status: status, search: search, partyId: partyId, page: page, limit: limit);

  Future<Sale> getReturnById(String id) => _getById('/sales/returns/$id');

  Future<Sale> createSalesReturn({
    required String originalInvoiceId,
    required String returnReason,
    ReturnCondition? condition,
    ReturnFinancialAction? financialAction,
    required List<SaleLineItem> items,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'originalInvoiceId': originalInvoiceId,
        'returnReason': returnReason,
        if (condition != null) 'condition': condition.name,
        if (financialAction != null) 'financialAction': financialAction.name,
        'items': items.map(_lineItemDto).toList(),
        if (notes != null) 'notes': notes,
      };
      final response = await _client.dio.post('/sales/returns', data: body);
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Sale> approveSalesReturn(String id) async {
    try {
      final response = await _client.dio.post('/sales/returns/$id/approve');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  Future<Sale> disburseRefund(
    String id, {
    required double amount,
    required PaymentMode paymentMode,
    String? transactionReference,
    String? notes,
  }) async {
    try {
      final body = <String, dynamic>{
        'amount': amount,
        'paymentMode': paymentMode.name,
        if (transactionReference != null) 'transactionReference': transactionReference,
        if (notes != null) 'notes': notes,
      };
      final response = await _client.dio.post('/sales/returns/$id/refund', data: body);
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Sale.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
