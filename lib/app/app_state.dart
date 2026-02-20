import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../core/storage/token_storage.dart';

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
        _isAuthenticated = true;
      }
    } catch (_) {
      _isAuthenticated = false;
      ApiClient.instance.setAuthToken(null);
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  void login() {
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await TokenStorage.clearTokens();
    ApiClient.instance.setAuthToken(null);
    _isAuthenticated = false;
    notifyListeners();
  }
}
