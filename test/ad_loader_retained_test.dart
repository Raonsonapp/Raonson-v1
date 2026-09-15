// test/ad_loader_retained_test.dart
// Loader-и реклама бояд дар МАЙДОН нигоҳ дошта шавад.
//
// Плагини Yandex ба ҳар loader Finalizer мечаспонад
// (yandex_mobileads/lib/ad.dart:12):
//
//     final _finalizer = Finalizer<MethodChannel>((channel) {
//       channel.invokeMethod('destroy');
//     });
//
// Яъне вақте объекти Dart дастнорас мешавад, ҷамъкунандаи партов
// loader-и НАТИВРО нест мекунад. Агар loader танҳо тағйирёбандаи
// маҳаллӣ бошад:
//
//     AdLoader.create(...).then((loader) {
//       loader.loadAd(...);        // ← баъд аз ин дастнорас
//     });
//
// он метавонад маҳз дар мобайни дархост нест шавад. Callback ҳеҷ гоҳ
// намеояд ва сабаб ғайримуайян аст — аз вақти GC вобаста.
//
// Ин хатогӣ хомӯш аст ва худ аз худ барнамегардад, бинобар ин тест
// лозим.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/ads/ads_manager.dart';

/// Матни як функсияро аз рӯи сарлавҳа то қавси пӯшандаи он мегирад.
String _body(String code, String header) {
  final start = code.indexOf(header);
  if (start < 0) return '';
  var depth = 0;
  for (var i = start + header.length - 1; i < code.length; i++) {
    if (code[i] == '{') depth++;
    if (code[i] == '}') {
      depth--;
      if (depth == 0) return code.substring(start, i + 1);
    }
  }
  return code.substring(start);
}

void main() {
  late String code;

  setUpAll(() {
    code = File('lib/core/ads/ads_manager.dart').readAsStringSync();
  });

  test('майдонҳои нигоҳдорӣ мавҷуданд', () {
    for (final field in [
      'InterstitialAdLoader? _interstitialLoader',
      'RewardedAdLoader?     _rewardedLoader',
      'RewardedAdLoader? _probeRewardedLoader',
      'InterstitialAdLoader? _probeInterstitialLoader',
      'RewardedAd? _probeRewardedAd',
      'InterstitialAd? _probeInterstitialAd',
    ]) {
      expect(code, contains(field), reason: 'майдон нест: $field');
    }
  });

  test('ҳар loader пеш аз loadAd ба майдон дода мешавад', () {
    // SDK 8 дигар `.then((loader)` надорад — loader ҳамзамон сохта
    // мешавад. Тест намунаи кӯҳнаро нигоҳ медорад, то агар касе ба
    // он баргардад, айб дубора пайдо нашавад.
    // Ҳар блоки `.then((loader) {` бояд дар ду сатри аввал
    // `... = loader;` дошта бошад.
    final lines = code.split('\n');
    final offenders = <String>[];

    for (var i = 0; i < lines.length; i++) {
      // Шарҳҳо ҳисоб намешаванд — маҳз онҳо намунаи КӮҲНАро нақл
      // мекунанд, то он дубора нашавад.
      if (lines[i].trimLeft().startsWith('//')) continue;
      if (!lines[i].contains('.then((loader)')) continue;
      final window = lines.sublist(i + 1, (i + 6).clamp(0, lines.length));
      final assigned = window.any((l) => RegExp(r'_\w*Loader = loader;')
          .hasMatch(l));
      if (!assigned) {
        offenders.add('сатри ${i + 1}: ${lines[i].trim()}');
      }
    }

    expect(offenders, isEmpty,
        reason: 'loader нигоҳ дошта намешавад — GC онро нест карда '
            'метавонад:\n${offenders.join('\n')}');
  });

  test('санҷиши демо loader-ро дар майдон нигоҳ медорад', () {
    // SDK 8: конструктор ҳамзамон аст, вале Finalizer ҳанӯз ҳаст,
    // пас loader бояд дар майдон монад, на дар тағйирёбандаи
    // маҳаллӣ.
    // Ҳар ду шакли демо loader-и худро дар МАЙДОН нигоҳ медорад.
    expect(code, contains('_probeRewardedLoader ??= RewardedAdLoader();'),
        reason: 'loader-и демои Rewarded ба майдон дода намешавад');
    expect(code,
        contains('_probeInterstitialLoader ??= InterstitialAdLoader();'),
        reason: 'loader-и демои Interstitial ба майдон дода намешавад');
    expect(code, contains('await _probeRewardedLoader!'),
        reason: 'санҷиш аз майдон истифода намебарад');
    expect(code, contains('await _probeInterstitialLoader!'),
        reason: 'санҷиш аз майдон истифода намебарад');
  });

  test('санҷиши демо назорати такрорӣ дорад', () {
    // Ду санҷиши ҳамзамон ҳарду ба ҳамон ҳолат менавиштанд ва
    // натиҷаи дар экран нишондодашуда ба сатри log мувофиқ набуд.
    expect(code, contains('if (_probeBusy) return _lastProbe;'),
        reason: 'ду санҷиши ҳамзамон имконпазир аст');
    expect(code, contains('if (run != _probeRun) return _lastProbe;'),
        reason: 'ҷавоби санҷиши кӯҳна ба санҷиши нав нисбат дода мешавад');
  });

  group('дархости дар парвоз шикаста намешавад', () {
    // Ин гурӯҳ хатои воқеиро нигоҳ медорад: барнома худаш
    // NETWORK_ERROR месохт.

    test('reload() назорати боркуниро тоза намекунад', () {
      // Пештар reload() `_interstitialLoading = false` мегузошт.
      // Он дархости дар парвозро «фаромӯш» мекард: дархости дуюм
      // оғоз меёфт ва loader-и аввалро дар мобайни кор нест мекард.
      final reload = _body(code, 'Future<void> reload() async {');
      expect(reload, isNot(contains('_interstitialLoading = false')),
          reason: 'reload() боркунии дар парвозро мешиканад');
      expect(reload, isNot(contains('_rewardedLoading = false')),
          reason: 'reload() боркунии дар парвозро мешиканад');
    });

    test('loader ҳангоми сохтани нав нест карда намешавад', () {
      // `_interstitialLoader?.destroy()` пеш аз loadAd метавонист
      // loader-и ҳанӯз коркунандаро нест кунад.
      expect(code, isNot(contains('_interstitialLoader?.destroy()')),
          reason: 'loader-и эҳтимолан фаъол нест карда мешавад');
      expect(code, isNot(contains('_rewardedLoader?.destroy()')),
          reason: 'loader-и эҳтимолан фаъол нест карда мешавад');
    });

    test('loader боз-боз истифода мешавад, на ҳар бор нав', () {
      // SDK 8: `??=` loader-ро танҳо бори аввал месозад.
      expect(code, contains('_interstitialLoader ??= InterstitialAdLoader()'),
          reason: 'ҳар кӯшиш loader-и нав месозад');
      expect(code, contains('_rewardedLoader ??= RewardedAdLoader()'),
          reason: 'ҳар кӯшиш loader-и нав месозад');
    });

    test('танҳо ЯК таймери такрор мемонад', () {
      // Пештар ҳар нокомӣ `Future.delayed` мемонд ва онҳо ҷамъ
      // мешуданд — чанд боркунии ба ҳам печида.
      // Манъ маҳз ба `Future.delayed` аст: онро бекор кардан мумкин
      // нест. `Timer` бекор мешавад ва иҷозат дода мешавад.
      for (final slot in ['_preloadInterstitial', '_preloadRewarded']) {
        expect(code, isNot(contains('Future.delayed(const Duration('
            'seconds: 30), $slot)')),
            reason: '$slot: таймери бекорнашаванда');
      }
      expect(code, contains('_interstitialRetry?.cancel();'));
      expect(code, contains('_rewardedRetry?.cancel();'));
    });

    test('боркунии дармонда абадӣ намемонад', () {
      // Бе ин, як нокомии бе callback шаклро то нав кардани барнома
      // хомӯш мемонд.
      expect(code, contains('_loadDeadline'));
      expect(code, contains('_stale('));
    });
  });

  _backoffTests();

  test('«✅» танҳо аз callback-и onAdLoaded меояд', () {
    // Агар ин сатр аз ҷои дигар ҳам гузошта шавад, «демо бор шуд»
    // дигар далели боркунии ВОҚЕӢ намешавад.
    final successes = RegExp(r"'✅[^']*'").allMatches(code).length;
    expect(successes, 1,
        reason: 'матни муваффақият дар $successes ҷо сохта мешавад — '
            'он бояд танҳо дар onAdLoaded бошад');
  });
}

// ── Интизории афзоянда ─────────────────────────────────────────
//
// Дар дастгоҳ дархостҳо ҳар 30 сония БЕОХИР такрор мешуданд:
//
//   13:20:26  Interstitial code=3 / Rewarded code=3
//   13:20:56  Interstitial code=3 / Rewarded code=3
//   13:21:26  Interstitial code=3 / Rewarded code=3
//
// Фосила дақиқан 30 сония ва як дархост ба ҳар шакл — яъне таймери
// такрории худи мо, на схемаи пинҳонӣ. Вале беохир такрор кардан
// батареяро мехӯрад ва метавонад боиси маҳдудкунии Yandex шавад.
void _backoffTests() {
  group('интизории афзоянда', () {
    test('аввалин кӯшиш зуд такрор мешавад', () {
      expect(AdsManager.backoffFor(1), const Duration(seconds: 30));
    });

    test('фосила дучанд мешавад', () {
      expect(AdsManager.backoffFor(2), const Duration(seconds: 60));
      expect(AdsManager.backoffFor(3), const Duration(seconds: 120));
      expect(AdsManager.backoffFor(4), const Duration(seconds: 240));
    });

    test('фосила аз 15 дақиқа зиёд намешавад', () {
      for (var f = 5; f <= 12; f++) {
        final d = AdsManager.backoffFor(f)!;
        expect(d.inSeconds, lessThanOrEqualTo(900), reason: 'failures=$f');
        expect(d.inSeconds, greaterThanOrEqualTo(30), reason: 'failures=$f');
      }
    });

    test('баъд аз кӯшишҳои зиёд тамоман бас мекунад', () {
      // Вагарна барнома то абад ҳар чанд дақиқа дархост мефиристад.
      expect(AdsManager.backoffFor(13), isNull);
      expect(AdsManager.backoffFor(100), isNull);
    });

    test('ҳеҷ гоҳ ба такрори 30-сонияи беохир барнамегардад', () {
      final thirties = [
        for (var f = 1; f <= 12; f++) AdsManager.backoffFor(f)
      ].where((d) => d == const Duration(seconds: 30)).length;
      expect(thirties, 1, reason: 'фосила намеафзояд');
    });
  });
}
