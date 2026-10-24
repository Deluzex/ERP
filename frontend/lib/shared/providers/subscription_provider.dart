import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/subscription_api_service.dart';
import '../../core/models/subscription_model.dart';

/// In-memory & test-safe tracker to ensure humble daily reminder dialog
/// appears at most once per calendar day.
class SubscriptionReminderTracker {
  SubscriptionReminderTracker._();

  static String? _lastDismissedDateString;

  static bool shouldShowToday() {
    final todayStr = _todayKey();
    return _lastDismissedDateString != todayStr;
  }

  static void markShownToday() {
    _lastDismissedDateString = _todayKey();
  }

  /// For testing: reset dismissal tracker
  @visibleForTesting
  static void resetForTesting() {
    _lastDismissedDateString = null;
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionStatus> {
  SubscriptionNotifier() : super(SubscriptionStatus.healthyDefault());

  final SubscriptionApiService _api = SubscriptionApiService();
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<SubscriptionStatus> fetchStatus() async {
    _isLoading = true;
    try {
      final status = await _api.getStatus();
      state = status;
      return status;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SubscriptionNotifier] Failed to fetch subscription status: $e');
      }
      return state;
    } finally {
      _isLoading = false;
    }
  }

  void updateStatus(SubscriptionStatus newStatus) {
    state = newStatus;
  }
}

final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionStatus>((ref) {
  return SubscriptionNotifier();
});
