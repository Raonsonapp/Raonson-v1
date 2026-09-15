import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'ad_config.dart';

/// Ҳолати як шакли реклама — барои экрани ташхис.
///
/// Бе ин, вақте реклама намебарояд, ҳеҷ роҳи фаҳмидани сабаб нест:
/// хатоҳои боркунӣ хомӯшона фурӯ бурда мешуданд.
class AdSlotStatus {
  final String name;
  final String unitId;
  final bool loading;
  final bool ready;
  final String lastError;
  final DateTime? lastLoadedAt;
  final DateTime? lastShownAt;
  final int loadAttempts;
  final int loadFailures;
  final int shows;

  const AdSlotStatus({
    required this.name,
    required this.unitId,
    this.loading = false,
    this.ready = false,
    this.lastError = '',
    this.lastLoadedAt,
    this.lastShownAt,
    this.loadAttempts = 0,
    this.loadFailures = 0,
    this.shows = 0,
  });
}

class AdsManager extends ChangeNotifier {
  AdsManager._();
  static final AdsManager instance = AdsManager._();

  /// Шиносаи корбар — ба дархости реклама дода мешавад.
  ///
  /// Барои мукофоти S2S: Yandex ҳамин арзишро ба callback-и сервер
  /// бармегардонад. Бе он сервер намедонад реклама ба КӢ тааллуқ
  /// дорад ва ҳисоб кор намекунад.
  String _userId = '';
  void setUserId(String id) => _userId = id;

  String _initError = '';
  String get initError => _initError;
  bool get isInitialized => _initialized;

  // Ҳолати ҳар шакл — барои экрани ташхис.
  String _interstitialError = '', _rewardedError = '';
  DateTime? _interstitialLoadedAt, _rewardedLoadedAt;
  DateTime? _rewardedShownAt;
  int _interstitialAttempts = 0, _rewardedAttempts = 0;
  int _interstitialFailures = 0, _rewardedFailures = 0;
  int _interstitialShows = 0, _rewardedShows = 0;

  /// Ҳолати ҳамаи шаклҳо.
  List<AdSlotStatus> statuses() => [
        AdSlotStatus(
          name: 'Interstitial',
          unitId: AdConfig.describe(AdFormat.interstitial),
          loading: _interstitialLoading,
          ready: _interstitialReady,
          lastError: _interstitialError,
          lastLoadedAt: _interstitialLoadedAt,
          lastShownAt: _lastInterstitialShown,
          loadAttempts: _interstitialAttempts,
          loadFailures: _interstitialFailures,
          shows: _interstitialShows,
        ),
        AdSlotStatus(
          name: 'Rewarded',
          unitId: AdConfig.describe(AdFormat.rewarded),
          loading: _rewardedLoading,
          ready: _rewardedReady,
          lastError: _rewardedError,
          lastLoadedAt: _rewardedLoadedAt,
          lastShownAt: _rewardedShownAt,
          loadAttempts: _rewardedAttempts,
          loadFailures: _rewardedFailures,
          shows: _rewardedShows,
        ),
      ];

  /// Танзимоти дархост — ҳамеша бо шиносаи корбар.
  AdRequestConfiguration _config(String unitId) => AdRequestConfiguration(
        adUnitId: unitId,
        parameters: _userId.isEmpty ? null : {'user_id': _userId},
      );

  // Шиносаҳо аз AdConfig меоянд: debug → демои Yandex,
  // release → шиносаи воқеӣ аз --dart-define.
  //
  // null маънои «танзим нашудааст» дорад ва боркунӣ умуман оғоз
  // намешавад — на ин ки шиносаи дигар гузошта шавад.
  static String? get _interstitialId => AdConfig.idFor(AdFormat.interstitial);
  static String? get _rewardedId => AdConfig.idFor(AdFormat.rewarded);

  InterstitialAd? _interstitialAd;
  RewardedAd?     _rewardedAd;
  bool _interstitialLoading = false;
  bool _rewardedLoading     = false;
  bool _interstitialReady   = false;
  bool _rewardedReady       = false;

  DateTime? _lastInterstitialShown;
  int _reelsSinceAd = 0;
  static const int _reelsBetweenAds        = 5;
  static const int _interstitialCooldownSec = 180;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    try {
      await MobileAds.initialize();
      _initialized = true;
      _initError = '';
    } catch (e) {
      // Пештар хато хомӯш мемонд ва «чаро реклама нест» ҷавоб надошт.
      _initError = e.toString();
      notifyListeners();
      return;
    }
    _preloadInterstitial();
    _preloadRewarded();
    notifyListeners();
  }

  /// Аз нав кӯшиш кардан — барои экрани ташхис.
  Future<void> reload() async {
    _interstitialLoading = false;
    _rewardedLoading = false;
    if (!_initialized) {
      await init();
      return;
    }
    _preloadInterstitial();
    _preloadRewarded();
    notifyListeners();
  }

  void _preloadInterstitial() {
    if (_interstitialLoading || _interstitialReady) return;
    final unitId = _interstitialId;
    if (unitId == null) {
      // Танзим нашудааст — боркунӣ умуман оғоз намешавад ва такрор
      // ҳам нест: такрори беохир барои чизе, ки ҳеҷ гоҳ кор
      // намекунад, танҳо батареяро мехӯрад.
      _interstitialError = _notConfigured;
      notifyListeners();
      return;
    }
    _interstitialLoading = true;
    _interstitialAttempts++;
    notifyListeners();

    InterstitialAdLoader.create(
      onAdLoaded: (InterstitialAd ad) {
        _interstitialAd      = ad;
        _interstitialReady   = true;
        _interstitialLoading = false;
        _interstitialError   = '';
        _interstitialLoadedAt = DateTime.now();
        notifyListeners();
        ad.setAdEventListener(
          eventListener: InterstitialAdEventListener(
            onAdShown:        ()  {},
            onAdFailedToShow: (e) => _onInterstitialDone(),
            onAdDismissed:    ()  => _onInterstitialDone(),
            onAdClicked:      ()  {},
            onAdImpression:   (d) {},
          ),
        );
      },
      onAdFailedToLoad: (error) {
        _interstitialLoading = false;
        _interstitialFailures++;
        // Хато НИГОҲ дошта мешавад: бе он «чаро реклама намебарояд»
        // ҷавоб надошт.
        _interstitialError = _describe(error);
        notifyListeners();
        Future.delayed(const Duration(seconds: 30), _preloadInterstitial);
      },
    ).then((loader) {
      loader.loadAd(adRequestConfiguration: _config(unitId));
    });
  }

  /// Сабаби ягонаи «танзим нашудааст».
  ///
  /// Дар release ин маънои онро дорад, ки шиноса ҳангоми сохтан
  /// дода нашудааст (--dart-define).
  static const _notConfigured =
      'Ad unit ID is not configured for this build.';

  /// Хатои SDK-ро ба матни хондашаванда табдил медиҳад.
  static String _describe(dynamic error) {
    if (error == null) return 'номаълум';
    try {
      final code = (error as dynamic).code;
      final desc = (error as dynamic).description;
      if (code != null || desc != null) return '$code: $desc';
    } catch (_) {}
    return error.toString();
  }

  void _onInterstitialDone() {
    _interstitialAd        = null;
    _interstitialReady     = false;
    _lastInterstitialShown = DateTime.now();
    _reelsSinceAd          = 0;
    Future.delayed(const Duration(seconds: 5), _preloadInterstitial);
  }

  Future<void> onReelSwiped() async {
    _reelsSinceAd++;
    if (_reelsSinceAd >= _reelsBetweenAds) {
      await showInterstitialIfReady();
    }
  }

  Future<bool> showInterstitialIfReady() async {
    if (!_interstitialReady || _interstitialAd == null) return false;
    if (_lastInterstitialShown != null) {
      final elapsed = DateTime.now()
          .difference(_lastInterstitialShown!)
          .inSeconds;
      if (elapsed < _interstitialCooldownSec) return false;
    }
    try {
      _interstitialAd!.show();
      _interstitialReady = false;
      _interstitialShows++;
      notifyListeners();
      return true;
    } catch (e) {
      _onInterstitialDone();
      return false;
    }
  }

  void _preloadRewarded() {
    if (_rewardedLoading || _rewardedReady) return;
    final unitId = _rewardedId;
    if (unitId == null) {
      _rewardedError = _notConfigured;
      notifyListeners();
      return;
    }
    _rewardedLoading = true;
    _rewardedAttempts++;
    notifyListeners();

    RewardedAdLoader.create(
      onAdLoaded: (RewardedAd ad) {
        _rewardedAd     = ad;
        _rewardedReady   = true;
        _rewardedLoading = false;
        _rewardedError   = '';
        _rewardedLoadedAt = DateTime.now();
        notifyListeners();
      },
      onAdFailedToLoad: (error) {
        _rewardedLoading = false;
        _rewardedFailures++;
        _rewardedError = _describe(error);
        notifyListeners();
        Future.delayed(const Duration(seconds: 30), _preloadRewarded);
      },
    ).then((loader) {
      loader.loadAd(adRequestConfiguration: _config(unitId));
    });
  }

  Future<bool> showRewarded() async {
    if (!_rewardedReady || _rewardedAd == null) return false;
    final completer = Completer<bool>();

    _rewardedAd!.setAdEventListener(
      eventListener: RewardedAdEventListener(
        onAdShown:        ()       {},
        onAdFailedToShow: (e)      {
          if (!completer.isCompleted) completer.complete(false);
          _resetRewarded();
        },
        onAdDismissed:    ()       {
          if (!completer.isCompleted) completer.complete(false);
          _resetRewarded();
        },
        onAdClicked:      ()       {},
        onAdImpression:   (d)      {},
        onRewarded:       (reward) {
          _rewardedShows++;
          _rewardedShownAt = DateTime.now();
          notifyListeners();
          if (!completer.isCompleted) completer.complete(true);
        },
      ),
    );

    try {
      _rewardedAd!.show();
    } catch (e) {
      if (!completer.isCompleted) completer.complete(false);
      _resetRewarded();
    }

    return completer.future;
  }

  void _resetRewarded() {
    _rewardedAd    = null;
    _rewardedReady = false;
    Future.delayed(const Duration(seconds: 3), _preloadRewarded);
  }

  bool get isInterstitialReady => _interstitialReady;
  bool get isRewardedReady     => _rewardedReady;

  /// null = танзим нашудааст; виджет набояд чизе нишон диҳад.
  String? get bannerId     => AdConfig.idFor(AdFormat.banner);
  String? get nativeFeedId => AdConfig.idFor(AdFormat.nativeFeed);

  @override
  void dispose() {
    _interstitialAd?.destroy();
    _rewardedAd?.destroy();
    super.dispose();
  }
}
