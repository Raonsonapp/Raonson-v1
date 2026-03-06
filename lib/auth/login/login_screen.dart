import 'secure_storage.dart';

class TokenStorage {
  TokenStorage._();

  /// ✅ Singleton instance
  static final TokenStorage instance = TokenStorage._();

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  // =====================================================
  // STATIC API (backward compatibility)
  // =====================================================

  static Future<void> saveAccessToken(String token) {
    return SecureStorage.write(_accessTokenKey, token);
  }

  static Future<void> saveRefreshToken(String token) {
    return SecureStorage.write(_refreshTokenKey, token);
  }

  static Future<String?> getAccessToken() {
    return SecureStorage.read(_accessTokenKey);
  }

  static Future<String?> getRefreshToken() {
    return SecureStorage.read(_refreshTokenKey);
  }

  static Future<void> clearTokens() async {
    await SecureStorage.delete(_accessTokenKey);
    await SecureStorage.delete(_refreshTokenKey);
    await SecureStorage.delete(_userIdKey);
  }


  static const String _userIdKey = 'user_id';

  static Future<void> saveUserId(String id) {
    return SecureStorage.write(_userIdKey, id);
  }

  static Future<String?> getUserId() {
    return SecureStorage.read(_userIdKey);
  }

  // =====================================================
  // INSTANCE API (НАВ)
  // =====================================================

  /// 🔹 save access token
  Future<void> saveToken(String token) {
    return saveAccessToken(token);
  }

  /// 🔹 get access token
  Future<String?> getToken() {
    return getAccessToken();
  }

  /// 🔹 clear all tokens
  Future<void> clear() {
    return clearTokens();
  }
}
