import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

/// ──────────────────────────────────────────────────────────────
///  AdsManager — Singleton production-ready ad service
///  Yandex Mobile Ads SDK
/// ──────────────────────────────────────────────────────────────
class AdsManager {
  AdsManager._();
  static final AdsManager instance = AdsManager._();

  // ── Ad Unit IDs ─────────────────────────────────────────────
  static const String _interstitialId  = 'R-M-19230220-1';
  static const String _rewardedId      = 'R-M-19230220-2';
  static const String _bannerId        = 'R-M-19230220-3';
  static const String _nativeFeedId    = 'R-M-19230220-4';

  // ── State ────────────────────────────────────────────────────
  InterstitialAd?  _interstitialAd;
  RewardedAd?      _rewardedAd;
  bool _interstitialLoading = false;
  bool _rewardedLoading     = false;
  bool _interstitialReady   = false;
  bool _rewardedReady       = false;

  // ── Cooldown: never spam ─────────────────────────────────────
  DateTime? _lastInterstitialShown;
  int _reelsSinceAd = 0;
  static const int _reelsBetweenAds       = 5;   // every 5 reels
  static const int _interstitialCooldownSec = 180; // 3 min minimum

  bool _initialized = false;

  // ─────────────────────────────────────────────────────────────
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await MobileAds.initialize();
    _preloadInterstitial();
    _preloadRewarded();
    debugPrint('[AdsManager] initialized ✓');
  }

  // ── Interstitial ─────────────────────────────────────────────
  void _preloadInterstitial() {
    if (_interstitialLoading || _interstitialReady) return;
    _interstitialLoading = true;

    InterstitialAdLoader.create(
      onAdLoaded: (InterstitialAd ad) {
        _interstitialAd     = ad;
        _interstitialReady   = true;
        _interstitialLoading = false;
        debugPrint('[AdsManager] Interstitial ready ✓');

        ad.setAdEventListener(
          eventListener: InterstitialAdEventListener(
            onAdShown:           ()  => debugPrint('[Ad] Interstitial shown'),
            onAdFailedToShow:    (e) => _onInterstitialDone(),
            onAdDismissed:       ()  => _onInterstitialDone(),
            onAdClicked:         ()  {},
            onAdImpression:      (d) {},
          ),
        );
      },
      onAdFailedToLoad: (error) {
        _interstitialLoading = false;
        debugPrint('[AdsManager] Interstitial failed: $error');
        // Retry after 30s
        Future.delayed(const Duration(seconds: 30), _preloadInterstitial);
      },
    ).loadAd(
      adRequestConfiguration: const AdRequestConfiguration(
        adUnitId: _interstitialId,
      ),
    );
  }

  void _onInterstitialDone() {
    _interstitialAd    = null;
    _interstitialReady = false;
    _lastInterstitialShown = DateTime.now();
    _reelsSinceAd      = 0;
    // preload next
    Future.delayed(const Duration(seconds: 5), _preloadInterstitial);
  }

  /// Call after each reel swipe — shows ad when threshold reached
  Future<void> onReelSwiped() async {
    _reelsSinceAd++;
    if (_reelsSinceAd >= _reelsBetweenAds) {
      await showInterstitialIfReady();
    }
  }

  /// Manual trigger (after upload, after navigation)
  Future<bool> showInterstitialIfReady() async {
    if (!_interstitialReady || _interstitialAd == null) return false;

    // Cooldown guard
    if (_lastInterstitialShown != null) {
      final elapsed = DateTime.now()
          .difference(_lastInterstitialShown!)
          .inSeconds;
      if (elapsed < _interstitialCooldownSec) return false;
    }

    try {
      _interstitialAd!.show();
      _interstitialReady = false;
      return true;
    } catch (e) {
      debugPrint('[AdsManager] show interstitial error: $e');
      _onInterstitialDone();
      return false;
    }
  }

  // ── Rewarded ─────────────────────────────────────────────────
  void _preloadRewarded() {
    if (_rewardedLoading || _rewardedReady) return;
    _rewardedLoading = true;

    RewardedAdLoader.create(
      onAdLoaded: (RewardedAd ad) {
        _rewardedAd     = ad;
        _rewardedReady   = true;
        _rewardedLoading = false;
        debugPrint('[AdsManager] Rewarded ready ✓');
      },
      onAdFailedToLoad: (error) {
        _rewardedLoading = false;
        debugPrint('[AdsManager] Rewarded failed: $error');
        Future.delayed(const Duration(seconds: 30), _preloadRewarded);
      },
    ).loadAd(
      adRequestConfiguration: const AdRequestConfiguration(
        adUnitId: _rewardedId,
      ),
    );
  }

  /// Show rewarded ad. Returns true if user earned reward.
  Future<bool> showRewarded() async {
    if (!_rewardedReady || _rewardedAd == null) {
      debugPrint('[AdsManager] Rewarded not ready');
      return false;
    }

    final completer = Completer<bool>();

    _rewardedAd!.setAdEventListener(
      eventListener: RewardedAdEventListener(
        onAdShown:         ()  => debugPrint('[Ad] Rewarded shown'),
        onAdFailedToShow:  (e) {
          if (!completer.isCompleted) completer.complete(false);
          _resetRewarded();
        },
        onAdDismissed:     ()  {
          if (!completer.isCompleted) completer.complete(false);
          _resetRewarded();
        },
        onAdClicked:       ()  {},
        onAdImpression:    (d) {},
        onRewarded:        (reward) {
          debugPrint('[Ad] Reward earned: ${reward.amount} ${reward.type}');
          if (!completer.isCompleted) completer.complete(true);
        },
      ),
    );

    try {
      _rewardedAd!.show();
    } catch (e) {
      debugPrint('[AdsManager] show rewarded error: $e');
      if (!completer.isCompleted) completer.complete(false);
      _resetRewarded();
    }

    return completer.future;
  }

  void _resetRewarded() {
    _rewardedAd   = null;
    _rewardedReady = false;
    Future.delayed(const Duration(seconds: 3), _preloadRewarded);
  }

  bool get isInterstitialReady => _interstitialReady;
  bool get isRewardedReady     => _rewardedReady;

  String get bannerId    => _bannerId;
  String get nativeFeedId => _nativeFeedId;

  void dispose() {
    _interstitialAd?.destroy();
    _rewardedAd?.destroy();
  }
}
