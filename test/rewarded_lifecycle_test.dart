import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/ads/ads_manager.dart';

// Рекламаи мукофотӣ: даври пурра бе навсозии ДАСТӢ.
//
// ═══════════════════════════════════════════════════════════════════
//  Шикояти корбар: «реклама кор мекунад, вале баъди як намоиш
//  навбатиаш омода нест — ҳар бор навсозиро бояд зад».
//
//  Се сабаб буданд:
//
//   1. Аввалин интизорӣ баъди `NoAdsAvailable` 30 СОНИЯ буд.
//      `code=4` аксаран гузарост — кӯшиши дуюм баъди ду сония
//      аллакай реклама медиҳад. Бо 30 сония корбар фикр мекард,
//      ки барнома вайрон аст.
//
//   2. Баъди 12 нокомӣ ҳисоб ТАМОМ мешуд ва дигар ҳеҷ гоҳ худ ба
//      худ оғоз намешуд. Ягона роҳ — тугмаи дастӣ.
//
//   3. Ҳеҷ ҳалқае набуд: на «барнома боз кушода шуд», на
//      «интернет баргашт». Барнома метавонист соатҳо бе реклама
//      бимонад, дар ҳоле ки Yandex кайҳо реклама медод.
//
//  ⚠️ Ин тест худи SDK-и Yandex-ро даъват НАМЕКУНАД. Он мантиқи
//  ҳолат ва интизориро месанҷад — маҳз он чи дар дасти мост.
//  Мавҷудияти реклама дар дасти Yandex аст ва кафолат дода
//  намешавад.
// ═══════════════════════════════════════════════════════════════════

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('интизории афзоянда', () {
    test('аввал ЗУД: 2 сония, на 30', () {
      // Маҳз ин камбудии асосӣ буд.
      expect(AdsManager.backoffFor(0), const Duration(seconds: 2));
      expect(AdsManager.backoffFor(1), const Duration(seconds: 2));
    });

    test('пайдарпай меафзояд: 2 → 5 → 10 → 20 → 30', () {
      expect(AdsManager.backoffFor(2), const Duration(seconds: 5));
      expect(AdsManager.backoffFor(3), const Duration(seconds: 10));
      expect(AdsManager.backoffFor(4), const Duration(seconds: 20));
      expect(AdsManager.backoffFor(5), const Duration(seconds: 30));
    });

    test('ҳеҷ гоҳ зудтар аз 2 сония — spam ба Yandex намеравад', () {
      for (var i = 0; i <= 12; i++) {
        final d = AdsManager.backoffFor(i);
        if (d == null) continue;
        expect(d.inSeconds, greaterThanOrEqualTo(2),
            reason: 'нокомии $i: интизории $d аз ҳад зуд аст');
      }
    });

    test('интизорӣ ҳадди боло дорад', () {
      for (var i = 0; i <= 12; i++) {
        final d = AdsManager.backoffFor(i);
        if (d == null) continue;
        expect(d.inSeconds, lessThanOrEqualTo(300));
      }
    });

    test('баъди кӯшишҳои зиёд ҳисоб бас мекунад', () {
      // Бе ин таймер абадӣ кор мекард ва батареяро мехӯрд.
      expect(AdsManager.backoffFor(13), isNull);
      expect(AdsManager.backoffFor(50), isNull);
    });
  });

  group('ҳолатҳо', () {
    test('ҳар шаш ҳолат эълон шудааст', () {
      expect(RewardedAdState.values, hasLength(6));
      for (final s in [
        RewardedAdState.idle,
        RewardedAdState.loading,
        RewardedAdState.ready,
        RewardedAdState.showing,
        RewardedAdState.cooldown,
        RewardedAdState.unavailable,
      ]) {
        expect(RewardedAdState.values, contains(s));
      }
    });
  });

  group('мантиқи preload дар код', () {
    late String src;
    setUpAll(() => src = _read('lib/core/ads/ads_manager.dart'));

    // ── B, N: дархости дуюм сохта намешавад ──
    test('се муҳофизат аз дархости параллелӣ', () {
      expect(src, contains('if (_rewardedLoading && !_stale('),
          reason: 'дархости дар парвоз аз дуюмӣ ҳимоя намешавад');
      expect(src, contains('if (_rewardedReady) return;'),
          reason: 'рекламаи омода аз нав бор мешавад');
      expect(src,
          contains('if (_rewardedState == RewardedAdState.showing) return;'),
          reason: 'болои рекламаи дар экран чизе бор мешавад');
    });

    // ── F: баъди намоиш preload-и ХУДКОР ──
    test('баъди пӯшидан навбатӣ худкор бор мешавад', () {
      final i = src.indexOf('void _resetRewarded()');
      expect(i, greaterThan(0));
      final body = src.substring(i, i + 900);
      expect(body, contains('_preloadRewarded()'),
          reason: 'баъди намоиш навбатӣ тайёр намешавад — маҳз аз ин '
              'корбар ҳар бор навсозиро мезад');
    });

    // ── M: хотира ──
    test('рекламаи истифодашуда НЕСТ карда мешавад', () {
      final i = src.indexOf('void _resetRewarded()');
      final body = src.substring(i, i + 900);
      expect(body, contains('destroy()'),
          reason: 'объекти нативӣ дар хотира мемонад — баъди даҳ '
              'намоиш даҳ реклама ҷамъ мешавад');
      expect(body, contains('_rewardedAd    = null'));
    });

    // ── H, I: оғози худкор ──
    test('баргаштан ба барнома preload оғоз мекунад', () {
      expect(src, contains('AppLifecycleState.resumed'),
          reason: 'барнома боз кушода мешавад, вале реклама не');
      expect(src, contains('_AdsLifecycleHook'));
    });

    test('баргаштани интернет preload оғоз мекунад', () {
      expect(src, contains('isOnlineNotifier'),
          reason: 'баъди офлайн реклама худ ба худ барнамегардад');
      expect(src, contains('network restored'));
    });

    // ── A: кушодани экран ──
    test('ensureRewardedReady ҳисоби нокомиҳоро аз сар оғоз мекунад', () {
      final i = src.indexOf('void ensureRewardedReady()');
      expect(i, greaterThan(0), reason: 'чунин усул нест');
      final body = src.substring(i, i + 900);
      expect(body, contains('_rewardedFailures = 0'),
          reason: 'агар кӯшишҳо тамом шуда бошанд, экран онро аз сар '
              'оғоз карда наметавонад — тугмаи дастӣ лозим мешавад');
      expect(body, contains('RewardedAdState.unavailable'));
    });

    test('ensureRewardedReady рекламаи омодаро даст намерасонад', () {
      final i = src.indexOf('void ensureRewardedReady()');
      final body = src.substring(i, i + 900);
      expect(body, contains('case RewardedAdState.ready:'));
      expect(body, contains('case RewardedAdState.showing:'));
    });

    // ── D, E: намоиш ──
    test('ду намоиши ҳамзамон рад мешавад', () {
      expect(src, contains("_log('show ignored — already showing')"));
    });

    // ── J, K, L: қарор аз они СЕРВЕР аст ──
    test('мукофот танҳо аз onRewarded меояд, на аз shown/dismissed', () {
      // ⚠️ Танҳо дар дохили `showRewarded` меҷӯем: дар файл
      // `onAdDismissed`-и interstitial ҳам ҳаст ва ҷустуҷӯи содда
      // ҳамонро меёфт.
      final start = src.indexOf('Future<RewardOutcome> showRewarded()');
      expect(start, greaterThan(0));
      final block = src.substring(start, start + 2600);

      final i = block.indexOf('onRewarded:');
      expect(i, greaterThan(0));
      expect(block.substring(i, i + 500),
          contains('completer.complete(true)'));

      // Пӯшидан набояд мукофот ҳисоб шавад.
      final d = block.indexOf('onAdDismissed:');
      expect(d, greaterThan(0));
      expect(block.substring(d, d + 300), contains('complete(false)'),
          reason: 'пӯшидан мукофот ҳисоб мешавад');
    });

    test('баъди onRewarded ҳатман ба сервер claim меравад', () {
      expect(src, contains('rewardBackend.claim(sessionId, unitId)'));
      // Ҳолати воқеӣ аз ҷавоби сервер гирифта мешавад.
      expect(src, contains('_lastRewardStatus = status'));
    });

    // ── LOGGING ──
    test('log-ҳои возеҳ ҳастанд', () {
      for (final m in [
        'preload started', 'loaded', 'show started', 'onRewarded',
        'dismissed', 'retry in', 'load failed',
      ]) {
        expect(src, contains(m), reason: 'log «$m» нест');
      }
    });

    test('log сир ё маълумоти шахсӣ намебарорад', () {
      final i = src.indexOf('void _log(');
      final body = src.substring(i, i + 200);
      for (final bad in ['token', 'Token', 'password', 'userId']) {
        expect(body.contains(bad), isFalse,
            reason: 'log метавонад «$bad» барорад');
      }
    });
  });

  group('экрани галочка', () {
    late String src;
    setUpAll(() => src = _read('lib/verification/verification_screen.dart'));

    test('ҳангоми кушодан preload оғоз мешавад', () {
      expect(src, contains('AdsManager.instance.ensureRewardedReady()'),
          reason: 'корбар тугмаро мезанад ва интизор мешавад');
    });

    test('экран ба тағйири ҳолат гӯш медиҳад', () {
      expect(src, contains('AdsManager.instance.addListener'));
      expect(src, contains('AdsManager.instance.removeListener'),
          reason: 'listener бармегардонида намешавад — leak');
    });

    test('тугма се ҳолатро фарқ мекунад', () {
      expect(src, contains('RewardedAdState.loading'));
      expect(src, contains('RewardedAdState.cooldown'));
      expect(src, contains('RewardedAdState.unavailable'));
      expect(src, contains("tr('ads.rewardPreparing')"));
    });
  });

  group('калидҳои тарҷума дар ҳар се забон', () {
    test('ads.reward*', () {
      final src = _read('lib/core/i18n/strings.dart');
      for (final k in [
        'ads.rewardPreparing',
        'ads.rewardRetrying',
        'ads.rewardAutoRetry',
      ]) {
        expect("'$k'".allMatches(src).length, 3,
            reason: '$k дар ҳар се забон нест');
      }
    });
  });

  group('шиносаи Yandex даст нахӯрдааст', () {
    test('шиносаи production ҳамон аст', () {
      // Талаби возеҳи корбар: ID-и production иваз нашавад.
      final src = _read('dart_defines/ad_units.json');
      expect(src, contains('R-M-19230220-2'),
          reason: 'шиносаи рекламаи мукофотӣ иваз шудааст');
    });
  });
}
