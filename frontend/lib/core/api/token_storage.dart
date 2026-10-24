import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Token & Session storage manager for ERP JWT tokens and active session
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  static const String _kAccessToken = 'erp_access_token';
  static const String _kRefreshToken = 'erp_refresh_token';
  static const String _kSessionId = 'erp_session_id';

  String? _accessToken;
  String? _refreshToken;
  String? _sessionId;
  bool _initialized = false;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get sessionId => _sessionId;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  /// Pre-loads tokens and session ID from persistent browser storage (localStorage / SharedPreferences)
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_kAccessToken);
      _refreshToken = prefs.getString(_kRefreshToken);
      _sessionId = prefs.getString(_kSessionId);
      _initialized = true;
      if (kDebugMode) {
        debugPrint('[TokenStorage] Initialized. hasToken: $hasToken, sessionId: $_sessionId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TokenStorage] Error initializing SharedPreferences: $e');
      }
    }
  }

  void saveTokens({
    required String accessToken,
    required String refreshToken,
    String? sessionId,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (sessionId != null && sessionId.isNotEmpty) {
      _sessionId = sessionId;
    }
    _persistTokens();
    if (kDebugMode) {
      debugPrint('[TokenStorage] Tokens & Session updated successfully.');
    }
  }

  void updateAccessToken(String newAccessToken) {
    _accessToken = newAccessToken;
    _persistTokens();
    if (kDebugMode) {
      debugPrint('[TokenStorage] Access token refreshed.');
    }
  }

  void updateSessionId(String newSessionId) {
    _sessionId = newSessionId;
    _persistTokens();
  }

  Future<void> _persistTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_accessToken != null && _accessToken!.isNotEmpty) {
        await prefs.setString(_kAccessToken, _accessToken!);
      } else {
        await prefs.remove(_kAccessToken);
      }

      if (_refreshToken != null && _refreshToken!.isNotEmpty) {
        await prefs.setString(_kRefreshToken, _refreshToken!);
      } else {
        await prefs.remove(_kRefreshToken);
      }

      if (_sessionId != null && _sessionId!.isNotEmpty) {
        await prefs.setString(_kSessionId, _sessionId!);
      } else {
        await prefs.remove(_kSessionId);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[TokenStorage] Error persisting tokens: $e');
      }
    }
  }

  void clear() {
    _accessToken = null;
    _refreshToken = null;
    _sessionId = null;
    _persistTokens();
    if (kDebugMode) {
      debugPrint('[TokenStorage] Tokens cleared.');
    }
  }
}
