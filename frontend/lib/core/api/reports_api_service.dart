import 'api_client.dart';

/// Production API Service for Reports & Business Intelligence (`/api/v1/reports/*`)
class ReportsApiService {
  final ApiClient _client = ApiClient.instance;

  /// Generic Report query for all 8 statement types
  Future<Map<String, dynamic>> getReport(
    String reportType, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _client.dio.get(
        '/reports/$reportType',
        queryParameters: query,
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return data;
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// 1. Inventory & Stock Valuation Report
  Future<Map<String, dynamic>> getInventoryReport({
    String? categoryId,
    String? search,
  }) async {
    return getReport('inventory', query: {
      if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
      if (search != null && search.isNotEmpty) 'search': search,
    });
  }

  /// 2. Purchases Register & Vendor Balances Report
  Future<Map<String, dynamic>> getPurchaseReport({
    String? partyId,
    String? startDate,
    String? endDate,
  }) async {
    return getReport('purchase', query: {
      if (partyId != null && partyId.isNotEmpty) 'partyId': partyId,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
    });
  }

  /// 3. Production Costing & Manufacturing Output Report
  Future<Map<String, dynamic>> getProductionReport({
    String? startDate,
    String? endDate,
  }) async {
    return getReport('production', query: {
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
    });
  }

  /// 4. Sales Revenue & GST Statement Report
  Future<Map<String, dynamic>> getSalesReport({
    String? partyId,
    String? startDate,
    String? endDate,
  }) async {
    return getReport('sales', query: {
      if (partyId != null && partyId.isNotEmpty) 'partyId': partyId,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
    });
  }

  /// 5. Project Costing & Profit Margins Report
  Future<Map<String, dynamic>> getProjectCostingReport({
    String? projectId,
    String? startDate,
    String? endDate,
  }) async {
    return getReport('project-costing', query: {
      if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
    });
  }

  /// 6. Expenses Operating Overheads Report
  Future<Map<String, dynamic>> getExpensesReport({
    String? category,
    String? startDate,
    String? endDate,
  }) async {
    return getReport('expenses', query: {
      if (category != null && category.isNotEmpty) 'category': category,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
    });
  }

  /// 7. Architect Commissions Statement Report
  Future<Map<String, dynamic>> getCommissionsReport({
    String? architectId,
    String? startDate,
    String? endDate,
  }) async {
    return getReport('commissions', query: {
      if (architectId != null && architectId.isNotEmpty) 'architectId': architectId,
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
    });
  }

  /// 8. Financial Balance & Working Capital Report
  Future<Map<String, dynamic>> getFinancialBalanceReport({
    String? startDate,
    String? endDate,
  }) async {
    return getReport('financial-balance', query: {
      if (startDate != null && startDate.isNotEmpty) 'startDate': startDate,
      if (endDate != null && endDate.isNotEmpty) 'endDate': endDate,
    });
  }
}
