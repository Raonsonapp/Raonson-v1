// lib/app/app_state.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../core/api/api_client.dart';
import '../core/storage/token_storage.dart';
import '../core/services/user_session.dart';
import '../core/services/vip_service.dart';
import '../core/ads/ad_eligibility.dart';
import '../core/ads/sponsored_ads.dart';
import '../core/analytics/analytics_service.dart';
import '../core/analytics/analytics_events.dart';
import '../core/storage/offline_cache.dart';

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

      // ✅ Token дорад → ФАВРАН login нишон деҳ аз cache
      ApiClient.instance.setAuthToken(token);
      ApiClient.instance.setRefreshToken(await TokenStorage.getRefreshToken());
      await UserSession.loadCachedData();

      // Агар userId cache дорад → ФАВРАН кушода мешавад
      _isAuthenticated = true;
      _isInitialized   = true;
      notifyListeners();

      // Background-да profile sync
      _syncProfileInBackground();

    } catch (_) {
      _isAuthenticated = false;
      _isInitialized   = true;
      notifyListeners();
    }
  }

  void _syncProfileInBackground() {
    Future.delayed(const Duration(milliseconds: 800), () async {
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

          // VIP-ро аз сервер ҳамоҳанг мекунем (admin додааст).
          // Соҳиби барнома (@raonson) ҳамеша VIP аст.
          final vip = user['is_vip'] == true || user['isVip'] == true ||
              uname.toLowerCase() == 'raonson';
          await VipService.instance.setVip(vip);
          // VIP/Pro — бе реклама. Сервер `adsFree`-ро худаш мегӯяд;
          // сервери кӯҳна онро надорад — он гоҳ аз VIP.
          final adsFree = user['adsFree'] is bool
              ? user['adsFree'] as bool
              : vip;
          await AdEligibility.instance.updateFromServer(adsFree);

          if (id.isNotEmpty) {
            // Аватари холиро ба ҷои аватари кэшшуда нанависем
            final keepAvatar =
                avatarUrl.isNotEmpty ? avatarUrl : (UserSession.avatar ?? '');
            await UserSession.saveAll(
                id: id, uname: uname, avatarUrl: keepAvatar);
            await TokenStorage.saveUserId(id);
            AnalyticsService.instance.setUser(id);
          }
        } else if (res.statusCode == 401) {
          await TokenStorage.clearTokens();
          ApiClient.instance.setAuthToken(null);
          await UserSession.clear();
          _isAuthenticated = false;
          notifyListeners();
        }
      } catch (_) {
        // Бе интернет — cache нигоҳ дор, silent
      }
    });
  }

  void login() {
    _isAuthenticated = true;
    notifyListeners();
    // VIP/бе-реклама барои аккаунти НАВ — вагарна то оғози дубора
    // ҳолати аккаунти пешина мемонд.
    _syncProfileInBackground();
  }

  Future<void> logout() async {
    AnalyticsService.instance.logEvent(AnalyticsEvents.logout);
    AnalyticsService.instance.clearUser();
    await AnalyticsService.instance.flush();
    await TokenStorage.clearTokens();
    ApiClient.instance.setAuthToken(null);
    // Кэши офлайни корбари баромада (чатҳо, лента, профилҳо) пок мешавад.
    await OfflineCache.clearViewer();
    await UserSession.clear();
    // Корбари навбатӣ VIP-и пешинаро мерос намегирад.
    await VipService.instance.setVip(false);
    await AdEligibility.instance.reset();
    SponsoredAdsRepository.instance.clear();
    _isAuthenticated = false;
    notifyListeners();
  }
}
