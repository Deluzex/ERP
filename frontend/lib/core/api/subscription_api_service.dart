import '../models/subscription_model.dart';
import 'api_client.dart';

class SubscriptionApiService {
  final ApiClient _client = ApiClient.instance;

  /// Fetch active instance subscription status (Public / Unauthenticated)
  Future<SubscriptionStatus> getStatus() async {
    try {
      final response = await _client.dio.get('/subscription/status');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return SubscriptionStatus.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Extend subscription duration by months (Requires authenticated admin/user)
  Future<SubscriptionStatus> renewSubscription({
    required int months,
    String? notes,
  }) async {
    try {
      final response = await _client.dio.patch(
        '/subscription/renew',
        data: {
          'months': months,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return SubscriptionStatus.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
