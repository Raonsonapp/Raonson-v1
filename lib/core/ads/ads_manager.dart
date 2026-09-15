import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'ad_config.dart';
import 'reward_backend.dart';

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

  /// Танзимоти дархост.
  ///
  /// Шиносаи ДОХИЛИИ корбар ин ҷо ФИРИСТОДА НАМЕШАВАД.
  ///
  /// Пештар он ҳамчун `parameters: {'user_id': ...}` мерафт — бо
  /// умеди он ки Yandex онро ба callback-и сервер бармегардонад.
  /// Чунин callback вуҷуд надорад: `parameters` дар SDK «Custom
  /// parameters for ad loading request» аст, яъне ҳадафгирӣ. Пас он
  /// шиносаи корбарро бе ҳеҷ фоида ба шабакаи бегона медод.
  AdRequest _config(String unitId) => AdRequest(adUnitId: unitId);

  // Шиносаҳо аз AdConfig меоянд: debug → демои Yandex,
  // release → шиносаи воқеӣ аз --dart-define.
  //
  // null маънои «танзим нашудааст» дорад ва боркунӣ умуман оғоз
  // намешавад — на ин ки шиносаи дигар гузошта шавад.
  static String? get _interstitialId => AdConfig.idFor(AdFormat.interstitial);
  static String? get _rewardedId => AdConfig.idFor(AdFormat.rewarded);

  InterstitialAd? _interstitialAd;
  RewardedAd?     _rewardedAd;

  // ⚠️ Loader-ҳо бояд НИГОҲ дошта шаванд.
  //
  // Плагин ба ҳар loader Finalizer мечаспонад (lib/ad.dart:12):
  //
  //     final _finalizer = Finalizer<MethodChannel>((channel) {
  //       channel.invokeMethod('destroy');
  //     });
  //
  // Яъне вақте объекти Dart-и loader дастнорас мешавад, ҷамъкунандаи
  // партов loader-и НАТИВРО НЕСТ мекунад.
  //
  // Пештар loader танҳо тағйирёбандаи маҳаллӣ буд:
  //
  //     InterstitialAdLoader.create(...).then((loader) {
  //       loader.loadAd(...);          // ← баъд аз ин дастнорас
  //     });
  //
  // Дархост дар парвоз буд, вале loader метавонист дар ҳамон лаҳза
  // нест шавад. Ин ғайримуайян аст — аз вақти GC вобаста. Ҳамин
  // метавонад ҳам «ҷавоб наомад»-ро шарҳ диҳад, ҳам натиҷаи
  // ноустуворро.
  InterstitialAdLoader? _interstitialLoader;
  RewardedAdLoader?     _rewardedLoader;
  bool _interstitialLoading = false;
  bool _rewardedLoading     = false;
  bool _interstitialReady   = false;
  bool _rewardedReady       = false;

  DateTime? _lastInterstitialShown;
  int _reelsSinceAd = 0;
  static const int _reelsBetweenAds        = 5;
  static const int _interstitialCooldownSec = 180;

  bool _initialized = false;

  /// Оғози ҷорӣ — то ду даъваткунанда ду оғоз насозанд.
  ///
  /// `_initialized` танҳо ПАС аз await гузошта мешавад, пас танҳо он
  /// кофӣ набуд: main.dart ва reels_screen.dart метавонистанд
  /// ҳамзамон аз назорат гузаранд ва YandexAds.initialize()-ро ду
  /// бор даъват кунанд.
  ///
  /// Ин дуруст кардани тартиб аст. Ман НАМЕГӮЯМ, ки он хатои
  /// network error-ро ҳал мекунад.
  Future<void>? _initing;

  Future<void> init() {
    if (_initialized) return Future.value();
    return _initing ??= _doInit();
  }

  Future<void> _doInit() async {
    try {
      await YandexAds.initialize();
      _initialized = true;
      _initError = '';
    } catch (e) {
      // Пештар хато хомӯш мемонд ва «чаро реклама нест» ҷавоб надошт.
      _initError = e.toString();
      _initing = null;
      notifyListeners();
      return;
    }
    _preloadInterstitial();
    _preloadRewarded();
    notifyListeners();
    // Рекламае, ки дида шуд, вале хабараш нарасид.
    unawaited(retryPendingClaims());
  }

  /// Аз нав кӯшиш кардан — барои экрани ташхис.
  ///
  /// ⚠️ Пештар ин ҷо `_interstitialLoading = false` буд.
  ///
  /// Он дархости ДАР ПАРВОЗРО «фаромӯш» мекард: назорат кушода
  /// мешуд, дархости дуюм оғоз меёфт ва loader-и аввал маҳз дар
  /// мобайни кор нест карда мешуд. Дархости шикаста ҳамчун
  /// NETWORK_ERROR бармегашт — яъне хаторо ХУДИ БАРНОМА месохт.
  ///
  /// Акнун боркунии дар парвоз даст нахӯрда мемонад.
  Future<void> reload() async {
    _trace('RELOAD');
    if (!_initialized) {
      await init();
      return;
    }
    // Кӯшиши ДАСТӢ интизории афзояндаро аз сар оғоз мекунад ва
    // таймерҳои интизориро бекор мекунад — вагарна пахши тугма
    // ҳеҷ таъсир намедошт.
    _interstitialRetry?.cancel();
    _rewardedRetry?.cancel();
    _interstitialRetry = null;
    _rewardedRetry = null;
    _interstitialFailures = 0;
    _rewardedFailures = 0;
    _preloadInterstitial();
    _preloadRewarded();
    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════════
  //  Пайгирии дархостҳо
  //
  //  Ҳар қадам сабт мешавад, то дар logcat возеҳ бошад, ки КӢ
  //  дархостро оғоз кард ва КАЙ.
  //
  //      adb logcat | grep RAONSON_AD_TRACE
  // ══════════════════════════════════════════════════════════════
  int _seq = 0;

  void _trace(String event, {String slot = '-', String extra = ''}) {
    debugPrint('[RAONSON_AD_TRACE] ${DateTime.now().toIso8601String()} '
        'seq=$_seq slot=$slot $event $extra');
  }

  /// Боркунии дармондаро пас аз ин муддат мурда ҳисоб мекунем.
  ///
  /// Бе он як нокомии бе callback шаклро то нав кардани барнома
  /// хомӯш мемонд.
  static const _loadDeadline = Duration(seconds: 90);

  bool _stale(DateTime? startedAt) =>
      startedAt == null ||
      DateTime.now().difference(startedAt) > _loadDeadline;

  Timer? _interstitialRetry;
  DateTime? _interstitialLoadStartedAt;

  void _preloadInterstitial() {
    // Боркунии дар парвоз халалдор карда НАМЕШАВАД.
    if (_interstitialLoading && !_stale(_interstitialLoadStartedAt)) return;
    if (_interstitialReady) return;
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
    _interstitialLoadStartedAt = DateTime.now();
    _interstitialAttempts++;
    _seq++;
    _trace('REQUEST',
        slot: 'Interstitial',
        extra: 'unit=$unitId caller=${StackTrace.current.toString()
            .split('\n')[1].trim()} '
            'inFlight=false retryTimer=${_interstitialRetry != null} '
            'attempt=$_interstitialAttempts');
    notifyListeners();

    // SDK 8 loader-ро ҳамзамон месозад ва loadAd Future
    // бармегардонад. Loader боз ҳам дар МАЙДОН нигоҳ дошта
    // мешавад: Finalizer (ad.dart:12) ҳанӯз ҳаст ва loader-и
    // дастнорасро нест мекунад.
    final loader = _interstitialLoader ??= InterstitialAdLoader();
    _trace(_interstitialLoader == loader ? 'LOADER_REUSE' : 'LOADER_CREATE',
        slot: 'Interstitial');

    loader.loadAd(adRequest: _config(unitId)).then((ad) {
      _interstitialAd = ad;
      _interstitialReady = true;
      _interstitialLoading = false;
      _interstitialError = '';
      _interstitialLoadedAt = DateTime.now();
      _interstitialFailures = 0;
      notifyListeners();
      ad.setAdEventListener(
        eventListener: InterstitialAdEventListener(
          onAdShown: () {},
          onAdFailedToShow: (e) => _onInterstitialDone(),
          onAdDismissed: () => _onInterstitialDone(),
          onAdClicked: () {},
          onAdImpression: (d) {},
        ),
      );
    }).catchError((Object error) {
      // Дар SDK 8 нокомӣ ҳамчун истисно меояд, на callback.
      _interstitialLoading = false;
      _interstitialFailures++;
      _interstitialError = _describe(error);
      _recordFailure('Interstitial', error);
      notifyListeners();
      _retryInterstitial();
    });
  }

  /// Танҳо ЯК кӯшиши интизорӣ.
  ///
  /// Пештар ҳар нокомӣ таймери нав мемонд ва онҳо ҷамъ мешуданд:
  /// чанд таймер қариб якҷоя оташ мегирифт ва боркуниҳои ба ҳам
  /// печида месохт.
  void _retryInterstitial() {
    if (_interstitialRetry != null) {
      _trace('TIMER_CANCEL', slot: 'Interstitial');
      _interstitialRetry!.cancel();
    }
    final wait = backoffFor(_interstitialFailures);
    if (wait == null) {
      _trace('RETRY_GIVE_UP',
          slot: 'Interstitial', extra: 'failures=$_interstitialFailures');
      _interstitialRetry = null;
      return;
    }
    _trace('TIMER_CREATE',
        slot: 'Interstitial', extra: 'in=${wait.inSeconds}s');
    _interstitialRetry = Timer(wait, () {
      _trace('TIMER_FIRE', slot: 'Interstitial');
      _interstitialRetry = null;
      _preloadInterstitial();
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

  // ══════════════════════════════════════════════════════════════
  //  Сабти пурраи хатоҳо
  //
  //  ⚠️ Муҳим: аз ин зиёд гирифтан ИМКОН НАДОРАД.
  //
  //  Синфи AdRequestError-и худи SDK (com.yandex.mobile.ads.common)
  //  танҳо се метод дорад: getCode(), getDescription(),
  //  getAdUnitId(). Ҳеҷ getCause(), ҳеҷ exception, ҳеҷ stack trace.
  //  Пули Kotlin-и плагин (LoadListener.kt:31) маҳз ҳамон серо
  //  мефиристад — яъне плагин чизе пинҳон НАМЕКУНАД.
  //
  //  Пас сабаби зеринро танҳо худи SDK дар logcat навишта
  //  метавонад — баъд аз YandexAds.setLogging(true).
  // ══════════════════════════════════════════════════════════════

  /// Як нокомии боркунӣ — ҳар чизе, ки гирифта тавонистем.
  static Map<String, String> _capture(String slot, dynamic error) {
    String s(dynamic v) => v == null ? '—' : v.toString();
    String code = '—', desc = '—', unit = '—';
    try {
      code = s((error as dynamic).code);
    } catch (_) {}
    try {
      desc = s((error as dynamic).description);
    } catch (_) {}
    try {
      unit = s((error as dynamic).adUnitId);
    } catch (_) {}

    return {
      'time': DateTime.now().toIso8601String(),
      'slot': slot,
      'code': code,
      'description': desc,
      'adUnitId': unit,
      'toString': s(error),
      'runtimeType': s(error?.runtimeType),
    };
  }

  /// Таърихи нокомиҳо — на танҳо охирин.
  ///
  /// Дар дастгоҳ 9 нокомӣ аз 14 кӯшиш буд. Танҳо охиринро дидан
  /// намегӯяд, ки оё ҳама якхелаанд ё не.
  final List<Map<String, String>> _failures = [];
  List<Map<String, String>> get failures => List.unmodifiable(_failures);

  void _recordFailure(String slot, dynamic error) {
    final f = _capture(slot, error);
    _failures.insert(0, f);
    while (_failures.length > 15) {
      _failures.removeLast();
    }
    // Сатри ягона ва ҷустуҷӯшаванда дар logcat.
    debugPrint('[RAONSON_AD] ${f['slot']} code=${f['code']} '
        'unit=${f['adUnitId']} desc=${f['description']} '
        'type=${f['runtimeType']} raw=${f['toString']}');
  }

  /// Хатои охирин ҳамчун матни пурра — барои нусхабардорӣ.
  String get lastFailureDetail {
    if (_failures.isEmpty) return '';
    return _failures.first.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
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

  Timer? _rewardedRetry;
  DateTime? _rewardedLoadStartedAt;

  void _preloadRewarded() {
    if (_rewardedLoading && !_stale(_rewardedLoadStartedAt)) return;
    if (_rewardedReady) return;
    final unitId = _rewardedId;
    if (unitId == null) {
      _rewardedError = _notConfigured;
      notifyListeners();
      return;
    }
    _rewardedLoading = true;
    _rewardedLoadStartedAt = DateTime.now();
    _rewardedAttempts++;
    _seq++;
    _trace('REQUEST',
        slot: 'Rewarded',
        extra: 'unit=$unitId caller=${StackTrace.current.toString()
            .split('\n')[1].trim()} '
            'inFlight=false retryTimer=${_rewardedRetry != null} '
            'attempt=$_rewardedAttempts');
    notifyListeners();

    final loader = _rewardedLoader ??= RewardedAdLoader();
    _trace(_rewardedLoader == loader ? 'LOADER_REUSE' : 'LOADER_CREATE',
        slot: 'Rewarded');

    loader.loadAd(adRequest: _config(unitId)).then((ad) {
      _rewardedAd = ad;
      _rewardedReady = true;
      _rewardedLoading = false;
      _rewardedError = '';
      _rewardedLoadedAt = DateTime.now();
      _rewardedFailures = 0;
      notifyListeners();
    }).catchError((Object error) {
      _rewardedLoading = false;
      _rewardedFailures++;
      _rewardedError = _describe(error);
      _recordFailure('Rewarded', error);
      notifyListeners();
      _retryRewarded();
    });
  }

  void _retryRewarded() {
    if (_rewardedRetry != null) {
      _trace('TIMER_CANCEL', slot: 'Rewarded');
      _rewardedRetry!.cancel();
    }
    final wait = backoffFor(_rewardedFailures);
    if (wait == null) {
      _trace('RETRY_GIVE_UP',
          slot: 'Rewarded', extra: 'failures=$_rewardedFailures');
      _rewardedRetry = null;
      return;
    }
    _trace('TIMER_CREATE', slot: 'Rewarded', extra: 'in=${wait.inSeconds}s');
    _rewardedRetry = Timer(wait, () {
      _trace('TIMER_FIRE', slot: 'Rewarded');
      _rewardedRetry = null;
      _preloadRewarded();
    });
  }

  /// Интизории афзоянда: 30с, 1д, 2д, 4д, 8д, баъд 15д.
  ///
  /// Пештар ҳар 30 сония як дархост мерафт — БЕОХИР. Ин на танҳо
  /// батареяро мехӯрд, балки метавонист боиси маҳдудкунии худи
  /// Yandex шавад: барномае, ки ҳар ним дақиқа дархост мефиристад
  /// ва ҳеҷ гоҳ реклама намегирад, мисли трафики бад менамояд.
  ///
  /// null = дигар кӯшиш накун (то reload-и дастӣ).
  @visibleForTesting
  static Duration? backoffFor(int failures) {
    if (failures <= 0) return const Duration(seconds: 30);
    if (failures > 12) return null;
    final seconds = 30 * (1 << (failures - 1).clamp(0, 5));
    return Duration(seconds: seconds.clamp(30, 900));
  }

  /// Сарҳади сервер — тест онро иваз мекунад.
  RewardBackend rewardBackend = const ApiRewardBackend();

  /// Рекламаи мукофотдорро нишон медиҳад ва серверро хабардор мекунад.
  ///
  /// Тартиб муҳим аст:
  ///
  ///   1. Сервер сеанс мекушояд. Агар нашавад, реклама нишон дода
  ///      НАМЕШАВАД — вагарна корбар беҳуда тамошо мекард.
  ///   2. Реклама нишон дода мешавад.
  ///   3. ТАНҲО агар Yandex `onRewarded`-ро эълон кунад, хабар ба
  ///      сервер меравад.
  ///
  /// Барнома ҳеҷ чизро худаш ҳисоб намекунад: `counted` фақат аз
  /// ҷавоби сервер меояд.
  Future<RewardOutcome> showRewarded() async {
    final unitId = _rewardedId;
    if (unitId == null || !_rewardedReady || _rewardedAd == null) {
      return RewardOutcome.notShown;
    }

    final sessionId = await rewardBackend.openSession(unitId);
    if (sessionId == null) {
      // Сервер хомӯш ё шабака нест.
      return const RewardOutcome(false, RewardStatus.offline);
    }

    final completer = Completer<bool>();

    _rewardedAd!.setAdEventListener(
      eventListener: RewardedAdEventListener(
        onAdShown:        ()       {},
        onAdFailedToShow: (e)      {
          if (!completer.isCompleted) completer.complete(false);
          _resetRewarded();
        },
        onAdDismissed:    ()       {
          // Пӯшидан пеш аз мукофот — тамошо нашуд.
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

    final watched = await completer.future;
    if (!watched) return RewardOutcome.notShown;

    final status = await rewardBackend.claim(sessionId, unitId);
    if (status == RewardStatus.offline) {
      // Сеанс дар сервер ҲАНӮЗ кушода аст — кӯшиш баъдтар такрор
      // мешавад. Бе ин, реклама ҳангоми қатъи шабака гум мешуд.
      await _remember(sessionId, unitId);
    }
    _lastRewardStatus = status;
    notifyListeners();
    return RewardOutcome(true, status);
  }

  /// Ҷавоби охирини сервер — барои экрани ташхис.
  RewardStatus? _lastRewardStatus;
  RewardStatus? get lastRewardStatus => _lastRewardStatus;

  // ── Хабарҳои нафиристода ─────────────────────────────────────
  //
  // Барнома метавонад маҳз дар лаҳзаи хабардиҳӣ кушта шавад ё
  // шабака қатъ гардад. Он вақт корбар рекламаро дид, вале он ҳисоб
  // нашуд. Сеанс дар сервер то мӯҳлаташ кушода мемонад, пас кӯшиши
  // такрорӣ дуруст аст — ва такрор хатарнок нест, чунки сервер ҳар
  // сеансро танҳо як бор мепазирад.
  static const _pendingKey = 'ads.pendingClaims';

  Future<void> _remember(String sessionId, String unitId) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final list = sp.getStringList(_pendingKey) ?? <String>[];
      final entry = '$sessionId|$unitId';
      if (!list.contains(entry)) {
        // Рӯйхат маҳдуд аст: сеанси кӯҳна ба ҳар ҳол мӯҳлаташ мегузарад.
        list.add(entry);
        while (list.length > 20) {
          list.removeAt(0);
        }
        await sp.setStringList(_pendingKey, list);
      }
    } catch (_) {}
  }

  /// Хабарҳои нафиристодаро такрор мефиристад.
  Future<void> retryPendingClaims() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final list = sp.getStringList(_pendingKey) ?? <String>[];
      if (list.isEmpty) return;

      final left = <String>[];
      for (final entry in list) {
        final parts = entry.split('|');
        if (parts.length != 2) continue;
        final status = await rewardBackend.claim(parts[0], parts[1]);
        // Танҳо ҳангоми набудани шабака нигоҳ дошта мешавад: ҳар
        // ҷавоби сервер — ҳатто рад — ҷавоби ниҳоӣ аст.
        if (status == RewardStatus.offline) left.add(entry);
      }
      await sp.setStringList(_pendingKey, left);
    } catch (_) {}
  }

  void _resetRewarded() {
    _rewardedAd    = null;
    _rewardedReady = false;
    Future.delayed(const Duration(seconds: 3), _preloadRewarded);
  }

  // ══════════════════════════════════════════════════════════════
  //  Асбобҳои ташхис
  //
  //  Хатои «3: Ad request failed with network error» дар сатҳи
  //  SDK рух медиҳад ва сабаби ВОҚЕИИ он дар матни хато нест.
  //  Ин се асбоб онро намоён мекунанд.
  // ══════════════════════════════════════════════════════════════

  /// Сабти муфассали SDK-ро дар logcat фаъол мекунад.
  ///
  /// Баъд аз ин:
  ///   adb logcat | grep -i yandex
  Future<void> enableSdkLogging() async {
    try {
      await YandexAds.setLogging(true);
    } catch (_) {}
  }

  /// Панели ташхиси ХУДИ Yandex-ро мекушояд.
  ///
  /// Ин таҳлилгари дохилии SDK аст: он ҷойгиршавӣ, аккаунт ва
  /// пайвастшавиро месанҷад ва сабаби дақиқро мегӯяд — чизе, ки
  /// коди мо дида наметавонад.
  Future<void> showYandexDebugPanel() async {
    try {
      await YandexAds.showDebugPanel();
    } catch (e) {
      _lastProbe = 'debug panel: $e';
      notifyListeners();
    }
  }

  /// Рекламаи ДЕМОи Yandex-ро бор мекунад — ҳамон дастгоҳ, ҳамон
  /// шабака, ҳамон SDK, вале ҷойгиршавии дигар.
  ///
  /// Ин санҷиш ҷавоби ҚАТЪӢ медиҳад:
  ///
  ///   демо кор мекунад  → шабака ва SDK солиманд; масъала дар
  ///                       ҷойгиршавӣ ё аккаунти Yandex аст;
  ///   демо ҳам хато 3   → роҳ ба серверҳои рекламаи Yandex баста
  ///                       аст (ISP, VPN, DNS). Коди барнома айб
  ///                       надорад.
  ///
  /// Ҳолати рекламаи асосӣ даст намехӯрад.
  // ── Санҷиши ҷудогонаи ҷойгиршавии демо ───────────────────────
  //
  // Иҷрои пештара нодуруст буд ва натиҷаи ЗИДДИЯТНОК медод:
  //
  //   • loader дар тағйирёбандаи маҳаллӣ буд → GC метавонист онро
  //     дар мобайни дархост нест кунад (Finalizer) → «ҷавоб наомад»;
  //   • ҳеҷ назорати такрорӣ набуд → ду санҷиши ҳамзамон ҳарду ба
  //     ҳамон `_lastProbe` менавиштанд, пас натиҷаи дар экран
  //     нишондодашуда метавонист ба сатри log мувофиқ набошад;
  //   • натиҷаи санҷиши ПЕШТАРА дар экран мемонд.
  //
  // Акнун: як санҷиш дар як вақт, loader нигоҳ дошта мешавад, ва ҳар
  // санҷиш рақами худро дорад — ҷавоби дермонда ба санҷиши нав
  // нисбат дода намешавад.

  // ── Санҷиши ҷойгиршавии ДЕМО ────────────────────────────────
  //
  // Дастгирии Yandex санҷиши блокҳои демоеро талаб кард. Шиносаҳо
  // расмӣ ва ҷамъиятӣ мебошанд:
  //
  //     demo-rewarded-yandex
  //     demo-interstitial-yandex
  //
  // ⚠️ Онҳо ба build-и release ҲЕҶ ГОҲ намераванд. Ин ҷо
  // `kDebugMode` санҷида мешавад — доимии вақти тарҷума. Дар
  // release ин функсияҳо фавран бармегарданд ва худи шиносаҳо ба
  // коди release дохил намешаванд.

  static const demoRewardedId = 'demo-rewarded-yandex';
  static const demoInterstitialId = 'demo-interstitial-yandex';

  RewardedAdLoader? _probeRewardedLoader;
  InterstitialAdLoader? _probeInterstitialLoader;

  // Рекламаи БОРШУДАИ демо нигоҳ дошта мешавад, то онро НИШОН ДОДАН
  // мумкин бошад: «бор шуд» ва «нишон дода шуд» ду савол аст.
  RewardedAd? _probeRewardedAd;
  InterstitialAd? _probeInterstitialAd;

  int _probeRun = 0;
  bool _probeBusy = false;

  /// Натиҷаи санҷиш. Холӣ = ҳеҷ санҷиш нашудааст.
  String _lastProbe = '';
  String get lastProbe => _lastProbe;

  /// Оё санҷиш ҳоло давом дорад.
  bool get probeBusy => _probeBusy;

  /// Оё реклами демои боршуда тайёр аст (барои тугмаи «Нишон додан»).
  bool get demoRewardedReady => _probeRewardedAd != null;
  bool get demoInterstitialReady => _probeInterstitialAd != null;

  String _probeResult(int run, String text) {
    if (run != _probeRun) return _lastProbe;
    _lastProbe = text;
    _probeBusy = false;
    notifyListeners();
    debugPrint('[RAONSON_AD_TRACE] probe#$run → $text');
    return text;
  }

  /// Рекламаи ДЕМОи Yandex-ро бор мекунад — ҳамон дастгоҳ, ҳамон
  /// шабака, ҳамон SDK, вале ҷойгиршавии дигар.
  ///
  /// «✅» ТАНҲО пас аз бозгашти муваффақи `loadAd` гузошта мешавад.
  Future<String> probeDemo(AdFormat format) async {
    if (!kDebugMode) {
      return _lastProbe = 'санҷиши демо танҳо дар build-и debug';
    }
    if (_probeBusy) return _lastProbe;
    if (format != AdFormat.rewarded && format != AdFormat.interstitial) {
      return _lastProbe = 'ин шакл санҷиши демо надорад';
    }

    final rewarded = format == AdFormat.rewarded;
    final unitId = rewarded ? demoRewardedId : demoInterstitialId;
    final name = rewarded ? 'DEMO-rewarded' : 'DEMO-interstitial';

    final run = ++_probeRun;
    _probeBusy = true;
    _lastProbe = 'санҷиш… ($unitId)';
    notifyListeners();
    _trace('DEMO_LOAD', slot: name, extra: 'unit=$unitId');

    try {
      if (rewarded) {
        _probeRewardedAd?.destroy();
        _probeRewardedAd = null;
        _probeRewardedLoader ??= RewardedAdLoader();
        final ad = await _probeRewardedLoader!
            .loadAd(adRequest: const AdRequest(adUnitId: demoRewardedId))
            .timeout(const Duration(seconds: 30));
        if (run != _probeRun) {
          ad.destroy();
          return _lastProbe;
        }
        _probeRewardedAd = ad;
      } else {
        _probeInterstitialAd?.destroy();
        _probeInterstitialAd = null;
        _probeInterstitialLoader ??= InterstitialAdLoader();
        final ad = await _probeInterstitialLoader!
            .loadAd(adRequest: const AdRequest(adUnitId: demoInterstitialId))
            .timeout(const Duration(seconds: 30));
        if (run != _probeRun) {
          ad.destroy();
          return _lastProbe;
        }
        _probeInterstitialAd = ad;
      }
      return _probeResult(run, '✅ $name бор шуд (onAdLoaded)');
    } on TimeoutException {
      return _probeResult(run, '❌ $name: ҷавоб наомад (30 сония)');
    } catch (e) {
      _recordFailure(name, e);
      return _probeResult(run, '❌ $name: ${_describe(e)}');
    }
  }

  /// Рекламаи демои боршударо НИШОН медиҳад.
  ///
  /// Ин саволи дуюми дастгирии Yandex аст: «оё онро нишон додан
  /// мумкин аст». Натиҷа аз callback-ҳои воқеӣ ҷамъ карда мешавад.
  ///
  /// ⚠️ Ин ҳеҷ мукофот НАМЕДИҲАД: ҷараёни сеанси сервер ба он
  /// тамоман дахл надорад.
  Future<String> showDemo(AdFormat format) async {
    if (!kDebugMode) {
      return _lastProbe = 'санҷиши демо танҳо дар build-и debug';
    }
    final rewarded = format == AdFormat.rewarded;
    final name = rewarded ? 'DEMO-rewarded' : 'DEMO-interstitial';
    final events = <String>[];
    final done = Completer<void>();

    void finish() {
      if (!done.isCompleted) done.complete();
    }

    try {
      if (rewarded) {
        final ad = _probeRewardedAd;
        if (ad == null) return _lastProbe = '$name: аввал бор кунед';
        ad.setAdEventListener(
          eventListener: RewardedAdEventListener(
            onAdShown: () => events.add('onAdShown'),
            onAdFailedToShow: (e) {
              events.add('onAdFailedToShow: ${e.description}');
              finish();
            },
            onAdDismissed: () {
              events.add('onAdDismissed');
              finish();
            },
            onAdClicked: () => events.add('onAdClicked'),
            onAdImpression: (_) => events.add('onAdImpression'),
            onRewarded: (r) =>
                events.add('onRewarded(${r.type} ${r.amount})'),
          ),
        );
        _trace('DEMO_SHOW', slot: name);
        await ad.show();
      } else {
        final ad = _probeInterstitialAd;
        if (ad == null) return _lastProbe = '$name: аввал бор кунед';
        ad.setAdEventListener(
          eventListener: InterstitialAdEventListener(
            onAdShown: () => events.add('onAdShown'),
            onAdFailedToShow: (e) {
              events.add('onAdFailedToShow: ${e.description}');
              finish();
            },
            onAdDismissed: () {
              events.add('onAdDismissed');
              finish();
            },
            onAdClicked: () => events.add('onAdClicked'),
            onAdImpression: (_) => events.add('onAdImpression'),
          ),
        );
        _trace('DEMO_SHOW', slot: name);
        await ad.show();
      }

      // Корбар метавонад рекламаро тамошо кунад — интизори дароз.
      await done.future.timeout(const Duration(minutes: 2),
          onTimeout: () => events.add('(ҷавоб наомад)'));
    } catch (e) {
      events.add('истисно: ${_describe(e)}');
    } finally {
      // Реклама як бор нишон дода мешавад — баъд нест мешавад.
      if (rewarded) {
        _probeRewardedAd?.destroy();
        _probeRewardedAd = null;
      } else {
        _probeInterstitialAd?.destroy();
        _probeInterstitialAd = null;
      }
    }

    final text = '$name нишон: ${events.join(", ")}';
    _lastProbe = text;
    notifyListeners();
    debugPrint('[RAONSON_AD_TRACE] $text');
    return text;
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
