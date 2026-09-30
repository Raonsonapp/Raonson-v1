// lib/core/ads/yandex_banner_slot.dart
// ════════════════════════════════════════════════════════════════════
//  Баннери Yandex дар ҷойи реклама (лента ё Reels).
//
//  Плагини yandex_mobileads 8.4.0 чор шакл дорад: Banner (sticky ва
//  inline), Interstitial, Rewarded ва AppOpen. Native НЕСТ. Барои
//  рекламаи дар байни мӯҳтаво — `BannerAdSize.inline`.
//
//  ⚠️ Хатои пешина: карт то «loaded» `SizedBox.shrink()` медод ва
//  `AdWidget`-ро намесохт. Вале дар SDK 8 дархост танҳо баъди
//  сохтани platform view (яъне худи `AdWidget`) мерафт — пас баннер
//  ҲЕҶ ГОҲ бор намешуд. Акнун `AdWidget` ҳамеша дар дарахт аст (то
//  боршавӣ баландии 1px, чизе намоён нест).
//
//  Қоидаҳо:
//    • ҳар ҷой — ЯК BannerAd ва ЯК `load()`, бе такрор; ҷой бо
//      keep-alive нигоҳ дошта мешавад, то scroll онро аз нав насозад;
//    • намоишро худи SDK ҳисоб мекунад (onImpression), вақте баннер
//      воқеан дар экран аст — барнома ҳеҷ чиз «намесозад»;
//    • бе розигӣ ё барои VIP — ҳеҷ дархост.
// ════════════════════════════════════════════════════════════════════
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:yandex_mobileads/mobile_ads.dart';

import 'ad_config.dart';
import 'ad_eligibility.dart';
import 'ads_manager.dart';

enum YandexSlotState { loading, loaded, failed }

/// Маҳдудияти дархостҳои баннер дар як сессия.
///
/// Бе ин scroll-и дароз садҳо дархост мефиристод; ва агар Yandex
/// реклама надошта бошад, ҳар ҷойи нав боз мепурсид.
class YandexSlotBudget {
  YandexSlotBudget._();
  static final YandexSlotBudget instance = YandexSlotBudget._();

  /// Ҳадди дархостҳо дар як сессия.
  static const maxRequestsPerSession = 12;

  /// Баъди «реклама нест» ё хато — ин муддат ҷойи нав намепурсад.
  static const failureCooldown = Duration(minutes: 5);

  int _requests = 0;
  DateTime? _lastFailure;

  int get requests => _requests;

  /// Оё ҳоло ҷойи нав метавонад баннер пурсад.
  bool get canRequest {
    if (AdEligibility.instance.isAdsFree) return false;
    if (AdConfig.idFor(AdFormat.banner) == null) return false;
    // SDK танҳо бо розигии корбар оғоз мешавад (main.dart).
    if (!AdsManager.instance.isInitialized) return false;
    if (_requests >= maxRequestsPerSession) return false;
    final f = _lastFailure;
    if (f != null && DateTime.now().difference(f) < failureCooldown) {
      return false;
    }
    return true;
  }

  void _onRequest() => _requests++;
  void _onFailure() => _lastFailure = DateTime.now();

  @visibleForTesting
  void debugReset() {
    _requests = 0;
    _lastFailure = null;
  }

  @visibleForTesting
  void debugFail() => _onFailure();

  @visibleForTesting
  void debugRequest() => _onRequest();
}

typedef YandexSlotBuilder = Widget Function(
    BuildContext context, Widget banner, YandexSlotState state);

class YandexBannerSlot extends StatefulWidget {
  /// Баландии ҳадди баннер (dp).
  final int maxHeight;

  /// Хабар ба волид: боршуд ё не (Reels саҳифаи холиро мегузарад).
  final ValueChanged<YandexSlotState>? onState;

  final YandexSlotBuilder builder;

  const YandexBannerSlot({
    super.key,
    required this.maxHeight,
    required this.builder,
    this.onState,
  });

  @override
  State<YandexBannerSlot> createState() => _YandexBannerSlotState();
}

class _YandexBannerSlotState extends State<YandexBannerSlot>
    with AutomaticKeepAliveClientMixin {
  BannerAd? _bannerAd;
  StreamSubscription<BannerAdLoadState>? _sub;
  StreamSubscription<BannerAdEvent>? _eventSub;
  YandexSlotState _state = YandexSlotState.loading;
  bool _started = false;

  // Ҷой нигоҳ дошта мешавад, то scroll боз дархост насозад.
  @override
  bool get wantKeepAlive => true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _start();
  }

  void _start() {
    final unitId = AdConfig.idFor(AdFormat.banner);
    if (unitId == null || !YandexSlotBudget.instance.canRequest) {
      _set(YandexSlotState.failed, notifyLater: true);
      return;
    }
    final width = MediaQuery.of(context).size.width.round();
    final ad = BannerAd(adSize: BannerAdSize.inline(
        width: width, maxHeight: widget.maxHeight));
    _bannerAd = ad;
    // Обуна ПЕШ аз load — вагарна ҳолати аввал гум мешавад.
    _sub = ad.loadStateStream.listen((s) {
      if (!mounted) return;
      if (s is BannerAdLoadStateLoaded) {
        _set(YandexSlotState.loaded);
      } else if (s is BannerAdLoadStateError) {
        debugPrint('[YandexSlot] code=${s.error.code} '
            '${s.error.description}');
        YandexSlotBudget.instance._onFailure();
        _set(YandexSlotState.failed);
      }
    });
    // Танҳо барои ташхис: намоишро SDK худаш ҳисоб мекунад.
    _eventSub = ad.events.listen((e) {
      if (e is BannerAdImpressionEvent) {
        debugPrint('[RAONSON_AD_TRACE] banner impression (SDK)');
      }
    });
    YandexSlotBudget.instance._onRequest();
    // Як бор. Ҳеҷ такрор — ҷойи нокомро ҷойҳои навбатӣ иваз мекунанд.
    //
    // `load()` platform view-ро ТАНҲО дар дохили худ месозад; то
    // `AdWidget` аз нав сохта нашавад, он ба дарахт намерасад ва
    // дархост ба Android/iOS намеравад. Пас баъди `load()` як бор
    // rebuild мекунем.
    unawaited(ad.load(AdRequest(adUnitId: unitId)).then((_) {
      if (mounted) setState(() {});
    }).catchError((Object e) {
      if (!mounted) return;
      YandexSlotBudget.instance._onFailure();
      _set(YandexSlotState.failed);
    }));
  }

  void _set(YandexSlotState s, {bool notifyLater = false}) {
    if (_state == s && s != YandexSlotState.failed) return;
    if (mounted && !notifyLater) setState(() => _state = s);
    if (notifyLater) _state = s;
    final cb = widget.onState;
    if (cb == null) return;
    // Дар вақти build ба волид setState кардан мумкин нест.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) cb(s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _eventSub?.cancel();
    _bannerAd?.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ad = _bannerAd;
    final banner = (ad == null || _state == YandexSlotState.failed)
        ? const SizedBox.shrink()
        : AdWidget(bannerAd: ad);
    return widget.builder(context, banner, _state);
  }
}
