// ignore: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'package:shared_preferences/shared_preferences.dart';

/// Web implementation of cross-tab session synchronization using HTML5 StorageEvent and localStorage.
class CrossTabSessionSync {
  static const String sessionTimestampKey = 'erp_session_timestamp';
  static const String sessionUserKey = 'erp_session_user';
  static const String crossTabLogoutKey = 'erp_cross_tab_logout';

  /// Broadcasts the current active user timestamp across all open tabs
  static Future<void> updateLastActivity(DateTime time) async {
    final msStr = time.millisecondsSinceEpoch.toString();
    try {
      html.window.localStorage[sessionTimestampKey] = msStr;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(sessionTimestampKey, time.millisecondsSinceEpoch);
    } catch (_) {}
  }

  /// Retrieves the latest shared activity timestamp across all tabs
  static Future<DateTime?> getLastActivity() async {
    try {
      final raw = html.window.localStorage[sessionTimestampKey];
      if (raw != null && raw.isNotEmpty) {
        final parsed = int.tryParse(raw);
        if (parsed != null) {
          return DateTime.fromMillisecondsSinceEpoch(parsed);
        }
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {}
      final ts = prefs.getInt(sessionTimestampKey);
      if (ts != null) {
        return DateTime.fromMillisecondsSinceEpoch(ts);
      }
    } catch (_) {}
    return null;
  }

  /// Clears logout signal upon fresh login
  static Future<void> notifyLogin() async {
    try {
      html.window.localStorage.remove(crossTabLogoutKey);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(crossTabLogoutKey);
    } catch (_) {}
  }

  /// Broadcasts logout event across all open tabs
  static Future<void> notifyLogout() async {
    final nowMs = DateTime.now().millisecondsSinceEpoch.toString();
    try {
      html.window.localStorage.remove(sessionTimestampKey);
      html.window.localStorage.remove(sessionUserKey);
      html.window.localStorage[crossTabLogoutKey] = nowMs;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(sessionTimestampKey);
      await prefs.remove(sessionUserKey);
      await prefs.setInt(crossTabLogoutKey, int.parse(nowMs));
    } catch (_) {}
  }

  /// Checks if another tab broadcasted a logout
  static Future<bool> isLoggedOutRemotely(DateTime? sessionStartTime) async {
    try {
      final raw = html.window.localStorage[crossTabLogoutKey];
      if (raw != null && raw.isNotEmpty && sessionStartTime != null) {
        final ts = int.tryParse(raw);
        if (ts != null && ts > sessionStartTime.millisecondsSinceEpoch) {
          return true;
        }
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      try {
        await prefs.reload();
      } catch (_) {}
      final ts = prefs.getInt(crossTabLogoutKey);
      if (ts != null && sessionStartTime != null) {
        return ts > sessionStartTime.millisecondsSinceEpoch;
      }
    } catch (_) {}
    return false;
  }

  /// Registers real-time window storage listeners for instantaneous cross-tab synchronization
  static StreamSubscription? initListeners({
    required void Function(DateTime activityTime) onCrossTabActivity,
    required void Function() onCrossTabLogout,
  }) {
    try {
      return html.window.onStorage.listen((html.StorageEvent event) {
        if (event.key == sessionTimestampKey && event.newValue != null) {
          final ts = int.tryParse(event.newValue!);
          if (ts != null) {
            onCrossTabActivity(DateTime.fromMillisecondsSinceEpoch(ts));
          }
        } else if (event.key == crossTabLogoutKey ||
            (event.key == sessionUserKey && event.newValue == null)) {
          onCrossTabLogout();
        }
      });
    } catch (_) {
      return null;
    }
  }
}
