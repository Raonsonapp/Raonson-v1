import 'package:flutter/foundation.dart';
import 'package:yandex_mobileads/interstitial.dart';

class YandexAds {
  static final String interstitialId = 'R-M-19230220-1';

  static InterstitialAd? _interstitialAd;

  static void loadAndShowInterstitial() {
    InterstitialAdLoader.create(
      onAdLoaded: (InterstitialAd ad) {
        _interstitialAd = ad;

        ad.show();
      },
      onAdFailedToLoad: (errorInfo) {
        debugPrint('Yandex ad error: $errorInfo');
      },
    ).loadAd(
      adRequestConfiguration: const AdRequestConfiguration(
        adUnitId: interstitialId,
      ),
    );
  }
}
