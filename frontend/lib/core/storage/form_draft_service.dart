import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'tab_session_storage.dart';

/// FormDraftService manages persistent local drafts for all ERP creation and edit forms.
/// Guarantees:
/// 1. Multi-tab isolation: drafts in Tab A do not overwrite or collide with Tab B.
/// 2. User isolation: drafts are bound to userId to prevent cross-account leaks.
/// 3. Debounced persistence: avoids excessive disk/storage I/O while typing.
/// 4. Edit protection: preserves recordId for existing records without duplicate generation.
/// 5. Automatic cleanup on save, discard, or session expiration (30-minute inactivity).
class FormDraftService {
  static const String _kDraftPrefix = 'erp_draft_';
  static const int _kDraftVersion = 1;

  static final FormDraftService instance = FormDraftService._();
  FormDraftService._();

  // In-memory cache for instant synchronous access
  final Map<String, Map<String, dynamic>> _memoryCache = {};
  final Map<String, Timer> _debounceTimers = {};

  static String _buildKey({
    required String module,
    required String formId,
    String? recordId,
    String? userId,
  }) {
    final t = TabSessionStorage.tabId;
    final u = userId ?? 'default_user';
    final r = recordId != null ? 'edit_$recordId' : 'new';
    return '${t}_$_kDraftPrefix${u}_${module}_${formId}_$r';
  }

  /// Sanitize form data to strictly prevent passwords or tokens from ever being saved in drafts
  static Map<String, dynamic> _sanitizeData(Map<String, dynamic> raw) {
    final sanitized = <String, dynamic>{};
    for (final entry in raw.entries) {
      final lowerKey = entry.key.toLowerCase();
      if (lowerKey.contains('password') || lowerKey.contains('token') || lowerKey.contains('secret')) {
        continue;
      }
      sanitized[entry.key] = entry.value;
    }
    return sanitized;
  }

  /// Automatically save form draft with short 300ms debounce.
  /// Synchronous memory cache is updated immediately so widget state never loses data.
  Future<void> saveFormDraft({
    required String module,
    required String formId,
    String? recordId,
    String? userId,
    required Map<String, dynamic> data,
    bool debounce = true,
  }) async {
    final key = _buildKey(
      module: module,
      formId: formId,
      recordId: recordId,
      userId: userId,
    );

    final cleanData = _sanitizeData(data);
    final payload = <String, dynamic>{
      '_version': _kDraftVersion,
      '_timestamp': DateTime.now().millisecondsSinceEpoch,
      '_module': module,
      '_formId': formId,
      '_recordId': recordId,
      '_userId': userId,
      'data': cleanData,
    };

    // Update memory cache immediately
    _memoryCache[key] = payload;
    _memoryCache['${TabSessionStorage.tabId}_$formId'] = cleanData;

    if (debounce) {
      _debounceTimers[key]?.cancel();
      _debounceTimers[key] = Timer(const Duration(milliseconds: 300), () async {
        await _flushDraftToStorage(key, payload);
      });
    } else {
      await _flushDraftToStorage(key, payload);
    }
  }

  Future<void> _flushDraftToStorage(String key, Map<String, dynamic> payload) async {
    try {
      final jsonStr = jsonEncode(payload);
      await TabSessionStorage.setItem(key, jsonStr);
    } catch (e) {
      if (kDebugMode) debugPrint('[FormDraftService] Failed to persist draft for $key: $e');
    }
  }

  /// Load draft for a specific module and form.
  /// Checks memory cache first, then TabSessionStorage.
  Future<Map<String, dynamic>?> loadFormDraft({
    required String module,
    required String formId,
    String? recordId,
    String? userId,
  }) async {
    final key = _buildKey(
      module: module,
      formId: formId,
      recordId: recordId,
      userId: userId,
    );

    if (_memoryCache.containsKey(key)) {
      final cached = _memoryCache[key];
      if (cached != null && cached['data'] is Map<String, dynamic>) {
        return Map<String, dynamic>.from(cached['data'] as Map);
      }
    }

    try {
      final raw = await TabSessionStorage.getItem(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _memoryCache[key] = decoded;
          if (decoded['data'] is Map<String, dynamic>) {
            return Map<String, dynamic>.from(decoded['data'] as Map);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FormDraftService] Failed to load draft for $key: $e');
    }

    return null;
  }

  /// Synchronously retrieve draft from memory cache if available
  Map<String, dynamic>? getDraftSync(String formId) {
    final tabKey = '${TabSessionStorage.tabId}_$formId';
    if (_memoryCache.containsKey(tabKey)) {
      return _memoryCache[tabKey];
    }
    for (final entry in _memoryCache.entries) {
      if (entry.key.contains(formId)) {
        final val = entry.value;
        if (val.containsKey('data') && val['data'] is Map<String, dynamic>) {
          return val['data'] as Map<String, dynamic>;
        }
        return val;
      }
    }
    return null;
  }

  /// Check whether a draft exists
  Future<bool> hasFormDraft({
    required String module,
    required String formId,
    String? recordId,
    String? userId,
  }) async {
    final d = await loadFormDraft(
      module: module,
      formId: formId,
      recordId: recordId,
      userId: userId,
    );
    return d != null && d.isNotEmpty;
  }

  /// Clear specific form draft on submit or cancel
  Future<void> clearFormDraft({
    required String module,
    required String formId,
    String? recordId,
    String? userId,
  }) async {
    final key = _buildKey(
      module: module,
      formId: formId,
      recordId: recordId,
      userId: userId,
    );

    _debounceTimers[key]?.cancel();
    _debounceTimers.remove(key);
    _memoryCache.remove(key);
    _memoryCache.remove('${TabSessionStorage.tabId}_$formId');

    try {
      await TabSessionStorage.removeItem(key);
    } catch (e) {
      if (kDebugMode) debugPrint('[FormDraftService] Failed to clear draft for $key: $e');
    }
  }

  /// Backward compatible helper methods
  Future<void> saveDraft(String formKey, Map<String, dynamic> data) async {
    await saveFormDraft(
      module: 'general',
      formId: formKey,
      data: data,
    );
  }

  Future<Map<String, dynamic>?> loadDraft(String formKey) async {
    return loadFormDraft(
      module: 'general',
      formId: formKey,
    );
  }

  Future<void> clearDraft(String formKey) async {
    await clearFormDraft(
      module: 'general',
      formId: formKey,
    );
  }

  /// Clear all stored drafts for a user on logout or 30m inactivity
  Future<void> clearAllUserDrafts(String userId) async {
    _debounceTimers.forEach((_, timer) => timer.cancel());
    _debounceTimers.clear();
    _memoryCache.clear();
    try {
      await TabSessionStorage.clearUserItems(userId);
    } catch (e) {
      if (kDebugMode) debugPrint('[FormDraftService] Failed to clear user drafts: $e');
    }
  }

  /// Clear all stored drafts across all forms
  Future<void> clearAllDrafts() async {
    _debounceTimers.forEach((_, timer) => timer.cancel());
    _debounceTimers.clear();
    _memoryCache.clear();
    try {
      await TabSessionStorage.clearUserItems('');
    } catch (e) {
      if (kDebugMode) debugPrint('[FormDraftService] Failed to clear all drafts: $e');
    }
  }
}
