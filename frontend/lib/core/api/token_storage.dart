import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Token & Session storage manager for ERP JWT tokens and active session
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  static const String _kAccessToken = 'erp_access_token';
  static const String _kRefreshToken = 'erp_refresh_token';
  static const String _kSessionId = 'erp_session_id';
  static const String _kTokenIssuedAt = 'erp_token_issued_at';
  static const String _kTokenExpiresIn = 'erp_token_expires_in';

  String? _accessToken;
  String? _refreshToken;
  String? _sessionId;
  int? _tokenIssuedAt;
  int? _tokenExpiresIn;
  bool _initialized = false;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get sessionId => _sessionId;
  int? get tokenIssuedAt => _tokenIssuedAt;
  int? get tokenExpiresIn => _tokenExpiresIn;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  /// Returns true if the token is past its expiration lifetime (default 30 min / 1800s)
  bool get isTokenExpired {
    if (!hasToken) return true;
    if (_tokenIssuedAt == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxLifeSeconds = _tokenExpiresIn ?? 1800;
    return (now - _tokenIssuedAt!) >= (maxLifeSeconds * 1000);
  }

  /// Remaining seconds before token expires
  int get remainingSeconds {
    if (!hasToken || _tokenIssuedAt == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final maxLifeSeconds = _tokenExpiresIn ?? 1800;
    final elapsedSeconds = (now - _tokenIssuedAt!) ~/ 1000;
    final remaining = maxLifeSeconds - elapsedSeconds;
    return remaining > 0 ? remaining : 0;
  }

  /// Pre-loads tokens and session ID from persistent browser storage (localStorage / SharedPreferences)
  Future<void> init() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString(_kAccessToken);
      _refreshToken = prefs.getString(_kRefreshToken);
      _sessionId = prefs.getString(_kSessionId);
      _tokenIssuedAt = prefs.getInt(_kTokenIssuedAt);
      _tokenExpiresIn = prefs.getInt(_kTokenExpiresIn);
      _initialized = true;
      if (kDebugMode) {
        debugPrint('[TokenStorage] Initialized. hasToken: $hasToken, sessionId: $_sessionId, isTokenExpired: $isTokenExpired');
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
    int? expiresIn,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (sessionId != null && sessionId.isNotEmpty) {
      _sessionId = sessionId;
    }
    _tokenIssuedAt = DateTime.now().millisecondsSinceEpoch;
    _tokenExpiresIn = expiresIn ?? 1800; // 30 minutes in seconds
    _persistTokens();
    if (kDebugMode) {
      debugPrint('[TokenStorage] Tokens & Session updated successfully (expires in $_tokenExpiresIn s).');
    }
  }

  void updateAccessToken(String newAccessToken, [int? expiresIn]) {
    _accessToken = newAccessToken;
    _tokenIssuedAt = DateTime.now().millisecondsSinceEpoch;
    if (expiresIn != null) {
      _tokenExpiresIn = expiresIn;
    }
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

      if (_tokenIssuedAt != null) {
        await prefs.setInt(_kTokenIssuedAt, _tokenIssuedAt!);
      } else {
        await prefs.remove(_kTokenIssuedAt);
      }

      if (_tokenExpiresIn != null) {
        await prefs.setInt(_kTokenExpiresIn, _tokenExpiresIn!);
      } else {
        await prefs.remove(_kTokenExpiresIn);
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
    _tokenIssuedAt = null;
    _tokenExpiresIn = null;
    _persistTokens();
    if (kDebugMode) {
      debugPrint('[TokenStorage] Tokens cleared.');
    }
  }
}
