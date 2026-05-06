// lib/core/ads/yandex_ads.dart
// ──────────────────────────────────────────────────────────────
// Legacy shim — delegates to AdsManager.
// Kept for backward compatibility if any existing code calls it.
// ──────────────────────────────────────────────────────────────

import 'ads_manager.dart';

@Deprecated('Use AdsManager.instance instead')
class YandexAds {
  static void loadAndShowInterstitial() {
    AdsManager.instance.showInterstitialIfReady();
  }
}
