import 'package:flutter/foundation.dart';

/// Token storage manager for ERP JWT tokens
class TokenStorage {
  TokenStorage._();
  static final TokenStorage instance = TokenStorage._();

  String? _accessToken;
  String? _refreshToken;

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get hasToken => _accessToken != null && _accessToken!.isNotEmpty;

  void saveTokens({required String accessToken, required String refreshToken}) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    if (kDebugMode) {
      debugPrint('[TokenStorage] Tokens updated successfully.');
    }
  }

  void updateAccessToken(String newAccessToken) {
    _accessToken = newAccessToken;
    if (kDebugMode) {
      debugPrint('[TokenStorage] Access token refreshed.');
    }
  }

  void clear() {
    _accessToken = null;
    _refreshToken = null;
    if (kDebugMode) {
      debugPrint('[TokenStorage] Tokens cleared.');
    }
  }
}
