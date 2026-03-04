import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../core/storage/token_storage.dart';
import '../core/services/user_session.dart';

class AppState extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isInitialized = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    try {
      final token = await TokenStorage.getAccessToken();

      if (token != null && token.isNotEmpty) {
        ApiClient.instance.setAuthToken(token);

        // ✅ Токенро бо backend тафтиш кун
        final res = await ApiClient.instance.get('/health').timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw Exception('timeout'),
        );

        if (res.statusCode == 200) {
          _isAuthenticated = true;
          // Load current user id for chat
          await _loadMe();
        } else {
          // Токен нокор — тоза кун
          await TokenStorage.clearTokens();
          ApiClient.instance.setAuthToken(null);
          _isAuthenticated = false;
        }
      }
    } catch (_) {
      // Интернет нест — токен бошад ворид кун, набошад login
      final token = await TokenStorage.getAccessToken();
      _isAuthenticated = token != null && token.isNotEmpty;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _loadMe() async {
    try {
      final res = await ApiClient.instance.getRequest('/profile/me');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final user = data['user'] ?? data;
        UserSession.userId = user['_id']?.toString() ?? user['id']?.toString();
        UserSession.username = user['username']?.toString();
        UserSession.avatar = user['avatar']?.toString();
        debugPrint('[AppState] userId loaded: ${UserSession.userId}');
      }
    } catch (e) {
      debugPrint('[AppState] _loadMe error: $e');
    }
  }

  void login() {
    _isAuthenticated = true;
    notifyListeners();
    // userId already set by login_controller, but reload to be sure
    _loadMe();
  }

  Future<void> logout() async {
    await TokenStorage.clearTokens();
    ApiClient.instance.setAuthToken(null);
    _isAuthenticated = false;
    notifyListeners();
  }
}
