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
        _isAuthenticated = false;
        _isInitialized   = true;
        notifyListeners();
        return;
      }

      // ✅ МУШКИЛИ АСОСӢ ИСЛОҲ ШУД:
      // Аввал кэшро бор кун — ФАВРАН, бе интернет
      ApiClient.instance.setAuthToken(token);
      await UserSession.loadCachedData();

      // Агар userId кэш дорад → ФАВРАН logged in нишон деҳ
      // Барнома дар 0 сония кушода мешавад!
      _isAuthenticated = true;
      _isInitialized   = true;
      notifyListeners(); // ← UI ФАВРАН нишон медиҳад

      // Баъд дар background профилро аз сервер бор кун
      // Корбар blank screen намебинад!
      _syncProfileInBackground();

    } catch (_) {
      _isAuthenticated = false;
      _isInitialized   = true;
      notifyListeners();
    }
  }

  // ── Background sync — UI block намекунад ─────────────────────────
  void _syncProfileInBackground() {
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        final res = await ApiClient.instance
            .get('/profile/me')
            .timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final user = data['user'] ?? data;
          final id       = (user['_id'] ?? user['id'])?.toString() ?? '';
          final uname    = user['username']?.toString() ?? '';
          final avatarUrl= user['avatar']?.toString()   ?? '';

          if (id.isNotEmpty) {
            await UserSession.saveAll(
              id: id, uname: uname, avatarUrl: avatarUrl);
            await TokenStorage.saveUserId(id);
          }
        } else if (res.statusCode == 401) {
          // Token беэтибор — logout
          await TokenStorage.clearTokens();
          ApiClient.instance.setAuthToken(null);
          await UserSession.clear();
          _isAuthenticated = false;
          notifyListeners();
        }
        // Дигар хатоҳо — silent, кэш нигоҳ дор
      } catch (_) {
        // Бе интернет — silent, кэш нигоҳ дор
      }
    });
  }

  void login() {
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await TokenStorage.clearTokens();
    ApiClient.instance.setAuthToken(null);
    await UserSession.clear();
    _isAuthenticated = false;
    notifyListeners();
  }
}
