import '../models/expense_model.dart';
import 'api_client.dart';

/// Production API Service for Operational & Project Expenses (`/api/v1/expenses/*`)
class ExpensesApiService {
  final ApiClient _client = ApiClient.instance;

  /// List Expenses with category, date, and project filters + KPI summaries
  Future<Map<String, dynamic>> getExpenses({
    String? search,
    String? category,
    String? paymentStatus,
    String? projectId,
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
      if (category != null && category.isNotEmpty && category != 'all') {
        queryParams['category'] = category;
      }
      if (paymentStatus != null && paymentStatus.isNotEmpty && paymentStatus != 'all') {
        queryParams['paymentStatus'] = paymentStatus;
      }
      if (projectId != null && projectId.isNotEmpty) {
        queryParams['projectId'] = projectId;
      }
      if (fromDate != null && fromDate.isNotEmpty) {
        queryParams['startDate'] = fromDate;
      }
      if (toDate != null && toDate.isNotEmpty) {
        queryParams['endDate'] = toDate;
      }

      final response = await _client.dio.get(
        '/expenses',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<dynamic>(response);
      final rawList = (data is Map<String, dynamic> ? data['items'] : data) as List<dynamic>? ?? [];
      final expenses = rawList
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList();

      final summary = (response.data is Map<String, dynamic> &&
              response.data['meta'] is Map<String, dynamic> &&
              response.data['meta']['pagination'] is Map<String, dynamic>)
          ? response.data['meta']['pagination']['summary'] ?? {}
          : {};

      return {
        'items': expenses,
        'summary': summary,
      };
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Get single expense voucher by ID
  Future<Expense> getExpenseById(String id) async {
    try {
      final response = await _client.dio.get('/expenses/$id');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Expense.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Create Expense voucher
  Future<Expense> createExpense(Expense expense) async {
    try {
      final payload = {
        'expenseName': expense.expenseName,
        'category': expense.category.name,
        'amount': expense.amount,
        'paidBy': expense.paidBy,
        'paymentMethod': expense.paymentMethod,
        if (expense.vendorPayee != null) 'vendorPayee': expense.vendorPayee,
        if (expense.projectId != null) 'projectId': expense.projectId,
        if (expense.projectName != null) 'projectName': expense.projectName,
        if (expense.purchaseId != null) 'purchaseId': expense.purchaseId,
        if (expense.purchaseNumber != null) 'purchaseNumber': expense.purchaseNumber,
        if (expense.productionId != null) 'productionId': expense.productionId,
        if (expense.productionNumber != null) 'productionNumber': expense.productionNumber,
        if (expense.expenseReference != null) 'expenseReference': expense.expenseReference,
        if (expense.description != null) 'description': expense.description,
        if (expense.receiptAttachmentName != null) 'receiptAttachmentName': expense.receiptAttachmentName,
        'paymentStatus': expense.paymentStatus.name,
        'expenseDate': expense.expenseDate.toIso8601String(),
      };

      final response = await _client.dio.post(
        '/expenses',
        data: payload,
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Expense.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Update Expense voucher
  Future<Expense> updateExpense(String id, Map<String, dynamic> payload) async {
    try {
      final response = await _client.dio.put(
        '/expenses/$id',
        data: payload,
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return Expense.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Delete Expense voucher
  Future<bool> deleteExpense(String id) async {
    try {
      final response = await _client.dio.delete('/expenses/$id');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return data['success'] == true;
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
