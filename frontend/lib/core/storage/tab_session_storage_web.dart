// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

/// Web implementation using browser `window.sessionStorage`.
/// Guarantees 100% isolation between multiple browser tabs while surviving F5 page reloads.
class TabSessionStorage {
  static String? _mockTabId;

  static String get tabId {
    if (_mockTabId != null) return _mockTabId!;
    try {
      var id = html.window.sessionStorage['erp_tab_id'];
      if (id == null || id.isEmpty) {
        id = 'tab_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}';
        html.window.sessionStorage['erp_tab_id'] = id;
      }
      return id;
    } catch (_) {
      return 'web_fallback_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  static void setMockTabId(String id) {
    _mockTabId = id;
  }

  static void resetTabId() {
    _mockTabId = null;
  }

  static Future<void> setItem(String key, String value) async {
    try {
      html.window.sessionStorage['${tabId}_$key'] = value;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${tabId}_$key', value);
    } catch (_) {}
  }

  static Future<String?> getItem(String key) async {
    try {
      final val = html.window.sessionStorage['${tabId}_$key'];
      if (val != null && val.isNotEmpty) return val;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('${tabId}_$key');
    } catch (_) {
      return null;
    }
  }

  static Future<void> removeItem(String key) async {
    try {
      html.window.sessionStorage.remove('${tabId}_$key');
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${tabId}_$key');
    } catch (_) {}
  }

  static Future<List<String>> getKeys(String prefix) async {
    final results = <String>{};
    final tabPrefix = '${tabId}_$prefix';
    try {
      for (final k in html.window.sessionStorage.keys) {
        if (k.startsWith(tabPrefix)) {
          results.add(k);
        }
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys()) {
        if (k.startsWith(tabPrefix)) {
          results.add(k);
        }
      }
    } catch (_) {}
    return results.toList();
  }

  static Future<void> clearUserItems(String userId) async {
    try {
      final toRemove = html.window.sessionStorage.keys.where((k) => k.contains(userId)).toList();
      for (final k in toRemove) {
        html.window.sessionStorage.remove(k);
      }
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final toRemove = prefs.getKeys().where((k) => k.contains(userId)).toList();
      for (final k in toRemove) {
        await prefs.remove(k);
      }
    } catch (_) {}
  }
}

