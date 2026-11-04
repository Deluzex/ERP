import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

/// Cross-tab / cross-instance session synchronization stub for Desktop, Mobile, and Test environments.
class CrossTabSessionSync {
  static const String sessionTimestampKey = 'erp_session_timestamp';
  static const String sessionUserKey = 'erp_session_user';
  static const String crossTabLogoutKey = 'erp_cross_tab_logout';

  static int? _inMemoryTimestamp;
  static int? _inMemoryLogoutTs;

  /// Broadcasts the current active user timestamp
  static Future<void> updateLastActivity(DateTime time) async {
    _inMemoryTimestamp = time.millisecondsSinceEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(sessionTimestampKey, time.millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Retrieves the latest shared activity timestamp across instances
  static Future<DateTime?> getLastActivity() async {
    if (_inMemoryTimestamp != null) {
      return DateTime.fromMillisecondsSinceEpoch(_inMemoryTimestamp!);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final ts = prefs.getInt(sessionTimestampKey);
      if (ts != null) {
        return DateTime.fromMillisecondsSinceEpoch(ts);
      }
    } catch (_) {}
    return null;
  }

  /// Clears logout signal upon fresh login
  static Future<void> notifyLogin() async {
    _inMemoryLogoutTs = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(crossTabLogoutKey);
    } catch (_) {}
  }

  /// Broadcasts logout event to all other tabs/instances
  static Future<void> notifyLogout() async {
    _inMemoryTimestamp = null;
    _inMemoryLogoutTs = DateTime.now().millisecondsSinceEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(sessionTimestampKey);
      await prefs.remove(sessionUserKey);
      await prefs.setInt(crossTabLogoutKey, _inMemoryLogoutTs!);
    } catch (_) {}
  }

  /// Checks if another tab or instance broadcasted a logout
  static Future<bool> isLoggedOutRemotely(DateTime? sessionStartTime) async {
    if (_inMemoryLogoutTs != null && sessionStartTime != null) {
      return _inMemoryLogoutTs! > sessionStartTime.millisecondsSinceEpoch;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final logoutTs = prefs.getInt(crossTabLogoutKey);
      if (logoutTs != null && sessionStartTime != null) {
        return logoutTs > sessionStartTime.millisecondsSinceEpoch;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Registers listeners for real-time cross-tab events
  static StreamSubscription? initListeners({
    required void Function(DateTime activityTime) onCrossTabActivity,
    required void Function() onCrossTabLogout,
  }) {
    // Non-web platforms use periodic reload and direct storage checks
    return null;
  }
}
