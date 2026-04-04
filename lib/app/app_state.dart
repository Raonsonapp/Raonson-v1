import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/storage/token_storage.dart';
import '../core/services/user_session.dart';

class AppState extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isInitialized   = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized   => _isInitialized;

  Future<void> initialize() async {
    try {
      final token = await TokenStorage.getAccessToken();

      if (token == null || token.isEmpty) {
        // No token → login screen
        _isAuthenticated = false;
        _isInitialized   = true;
        notifyListeners();
        return;
      }

      // Token mavjud — set it
      ApiClient.instance.setAuthToken(token);

      // Restore userId from storage (no network needed)
      final uid = await TokenStorage.getUserId();
      if (uid != null && uid.isNotEmpty) {
        UserSession.userId = uid;
      }

      // Try to load profile (with timeout)
      try {
        final res = await ApiClient.instance
            .get('/profile/me')
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final user = data['user'] ?? data;
          final id   = (user['_id'] ?? user['id'])?.toString() ?? '';
          if (id.isNotEmpty) {
            UserSession.userId   = id;
            UserSession.username = user['username']?.toString() ?? '';
            UserSession.avatar   = user['avatar']?.toString()   ?? '';
            await TokenStorage.saveUserId(id);
          }
          _isAuthenticated = true;
        } else if (res.statusCode == 401) {
          // Token expired
          await TokenStorage.clearTokens();
          ApiClient.instance.setAuthToken(null);
          _isAuthenticated = false;
        } else {
          // Server error but token exists → stay logged in
          _isAuthenticated = true;
        }
      } catch (_) {
        // No internet → stay logged in with saved token
        _isAuthenticated = true;
      }
    } catch (_) {
      _isAuthenticated = false;
    }

    _isInitialized = true;
    notifyListeners();
  }

  void login() {
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await TokenStorage.clearTokens();
    ApiClient.instance.setAuthToken(null);
    UserSession.userId   = null;
    UserSession.username = null;
    UserSession.avatar   = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
