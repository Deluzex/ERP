import '../models/notification_model.dart';
import 'api_client.dart';

/// Production API Service for Notifications (`/api/v1/notifications/*`)
class NotificationsApiService {
  final ApiClient _client = ApiClient.instance;

  /// Fetch notifications for current user with server-side role & identity filtering
  Future<Map<String, dynamic>> getNotifications({
    bool? unreadOnly,
    String? notificationType,
    String? targetRole,
    int page = 1,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'limit': limit,
      };
      if (unreadOnly != null) queryParams['unreadOnly'] = unreadOnly.toString();
      if (notificationType != null && notificationType.isNotEmpty) {
        queryParams['notificationType'] = notificationType;
      }
      if (targetRole != null && targetRole.isNotEmpty) {
        queryParams['targetRole'] = targetRole;
      }

      final response = await _client.dio.get(
        '/notifications',
        queryParameters: queryParams,
      );

      final data = _client.unwrap<Map<String, dynamic>>(response);
      final rawItems = data['items'] as List<dynamic>? ?? [];
      final items = rawItems
          .map((i) => NotificationItem.fromJson(i as Map<String, dynamic>))
          .toList();

      return {
        'items': items,
        'unreadCount': data['unreadCount'] as int? ?? 0,
        'total': data['total'] as int? ?? 0,
        'page': data['page'] as int? ?? page,
        'limit': data['limit'] as int? ?? limit,
      };
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Create and persist an internal notification
  Future<NotificationItem> createNotification(Map<String, dynamic> payload) async {
    try {
      final response = await _client.dio.post(
        '/notifications',
        data: payload,
      );
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return NotificationItem.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Mark specific notification as read
  Future<NotificationItem> markAsRead(String id) async {
    try {
      final response = await _client.dio.patch('/notifications/$id/read');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return NotificationItem.fromJson(data);
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }

  /// Mark all visible notifications as read for current user
  Future<int> markAllAsRead() async {
    try {
      final response = await _client.dio.patch('/notifications/mark-all-read');
      final data = _client.unwrap<Map<String, dynamic>>(response);
      return data['count'] as int? ?? 0;
    } catch (e) {
      throw _client.handleDioError(e);
    }
  }
}
