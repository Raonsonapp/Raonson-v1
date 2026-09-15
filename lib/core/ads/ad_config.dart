// lib/core/ads/ad_config.dart
// ════════════════════════════════════════════════════════════════════
//  Шиносаҳои ҷойгиршавии реклама.
//
//  Ташхиси воқеӣ дар дастгоҳ нишон дод:
//
//    Interstitial R-M-19230220-1
//      → «Ad request completed successfully, but there are no ads
//         available» — ҷойгиршавӣ ҲАСТ, вале ҳоло реклама надорад.
//         Ин хатои код НЕСТ.
//
//    Rewarded R-M-19230220-2
//      → «Provided AdUnitId does not exist!» — ин ҷойгиршавӣ дар
//         кабинети Yandex ВУҶУД НАДОРАД.
//
//  Аз ин рӯ:
//
//  • debug — шиносаҳои РАСМИИ демои Yandex. Онҳо ҳамеша реклама
//    медиҳанд ва барои санҷиш сохта шудаанд.
//
//  • release — шиносаи ВОҚЕӢ, ки ҳангоми сохтан дода мешавад
//    (--dart-define). Ҳеҷ гоҳ шиносаи сохта ё демо!
//
//  Чаро демо дар release мамнӯъ аст: он рекламаи санҷиширо ба
//  корбарони воқеӣ нишон медиҳад ва ҳеҷ даромад намедиҳад — вале
//  «кор мекунад» менамояд. Хатои хомӯш аз хатои возеҳ бадтар аст.
// ════════════════════════════════════════════════════════════════════
import 'package:flutter/foundation.dart';

/// Шакли реклама.
enum AdFormat { interstitial, rewarded, banner, nativeFeed }

class AdConfig {
  AdConfig._();

  // ── Шиносаҳои РАСМИИ демои Yandex ────────────────────────────
  //
  // Инҳо ҷамъиятӣ ва ҳуҷҷатнокшудаанд; сир нестанд ва танҳо дар
  // build-и debug истифода мешаванд.
  static const _demo = {
    AdFormat.interstitial: 'demo-interstitial-yandex',
    AdFormat.rewarded: 'demo-rewarded-yandex',
    AdFormat.banner: 'demo-banner-yandex',
    AdFormat.nativeFeed: 'demo-native-content-yandex',
  };

  // ── Шиносаҳои production ─────────────────────────────────────
  //
  // Ҳангоми сохтан дода мешаванд:
  //
  //   flutter build appbundle \
  //     --dart-define=YANDEX_INTERSTITIAL_ID=R-M-xxxxxxxx-1 \
  //     --dart-define=YANDEX_REWARDED_ID=R-M-xxxxxxxx-2 \
  //     --dart-define=YANDEX_BANNER_ID=R-M-xxxxxxxx-3 \
  //     --dart-define=YANDEX_NATIVE_FEED_ID=R-M-xxxxxxxx-4
  //
  // Холӣ монда метавонанд: он вақт ҳамон шакл хомӯш мемонад ва
  // экрани ташхис сабабро возеҳ мегӯяд.
  static const _prodInterstitial =
      String.fromEnvironment('YANDEX_INTERSTITIAL_ID');
  static const _prodRewarded = String.fromEnvironment('YANDEX_REWARDED_ID');
  static const _prodBanner = String.fromEnvironment('YANDEX_BANNER_ID');
  static const _prodNativeFeed =
      String.fromEnvironment('YANDEX_NATIVE_FEED_ID');

  static const _prod = {
    AdFormat.interstitial: _prodInterstitial,
    AdFormat.rewarded: _prodRewarded,
    AdFormat.banner: _prodBanner,
    AdFormat.nativeFeed: _prodNativeFeed,
  };

  /// Оё build-и debug аст.
  ///
  /// Ҳамчун майдони тағйирёбанда нигоҳ дошта мешавад, то тест
  /// рафтори release-ро бе сохтани build-и release санҷида тавонад.
  static bool isDebugBuild = kDebugMode;

  /// Шиносаи ҷойгиршавӣ, ё null агар танзим нашуда бошад.
  ///
  /// null маънои «ин шаклро БОР НАКУН» дорад. Ҳеҷ гоҳ ба шиносаи
  /// дигар иваз намешавад.
  static String? idFor(AdFormat f) {
    // Ду шарт, на як.
    //
    // `isDebugBuild` майдони тағйирёбанда аст — тест онро иваз
    // мекунад. Танҳо он кифоя набуд: коди нодуруст метавонист
    // онро дар release ба true гузорад ва шиносаи ДЕМО ба
    // корбарони воқеӣ мерафт.
    //
    // `kDebugMode` бошад доимии ВАҚТИ ТАРҶУМА аст. Дар build-и
    // release он false аст, пас ин шоха умуман ба barnoma дохил
    // намешавад — демо дар release ҒАЙРИИМКОН мегардад, новобаста
    // аз он ки касе `isDebugBuild`-ро чӣ кор кунад.
    if (isDebugBuild && kDebugMode) return _demo[f];
    final id = _prod[f] ?? '';
    return id.isEmpty ? null : id;
  }

  /// Барои экрани ташхис: чаро шакл кор намекунад.
  static String describe(AdFormat f) {
    final id = idFor(f);
    if (id == null) return 'not configured';
    return isDebugBuild ? '$id (demo)' : id;
  }

  /// Оё ҳамаи шаклҳо танзим шудаанд.
  static bool get isFullyConfigured =>
      AdFormat.values.every((f) => idFor(f) != null);

  /// Шаклҳое, ки танзим нашудаанд.
  static List<AdFormat> get missing =>
      AdFormat.values.where((f) => idFor(f) == null).toList();
}
