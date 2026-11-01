import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

/// Stub implementation for Desktop / Mobile / Test environments.
/// Simulates isolated tab storage using SharedPreferences with an in-memory unique tab session ID.
class TabSessionStorage {
  static String? _tabId;

  static String get tabId {
    _tabId ??= 'tab_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999)}';
    return _tabId!;
  }

  static void setMockTabId(String id) {
    _tabId = id;
  }

  static void resetTabId() {
    _tabId = null;
  }

  static Future<void> setItem(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${tabId}_$key', value);
  }

  static Future<String?> getItem(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('${tabId}_$key');
  }

  static Future<void> removeItem(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${tabId}_$key');
  }

  static Future<List<String>> getKeys(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    final tabPrefix = '${tabId}_$prefix';
    return prefs.getKeys().where((k) => k.startsWith(tabPrefix)).toList();
  }

  static Future<void> clearUserItems(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final toRemove = prefs.getKeys().where((k) => k.contains(userId)).toList();
    for (final k in toRemove) {
      await prefs.remove(k);
    }
  }
}

