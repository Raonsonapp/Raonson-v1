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

void main() {
  late String code;

  setUpAll(() {
    code = File('lib/core/ads/ads_manager.dart').readAsStringSync();
  });

  test('майдонҳои нигоҳдорӣ мавҷуданд', () {
    for (final field in [
      'InterstitialAdLoader? _interstitialLoader',
      'RewardedAdLoader?     _rewardedLoader',
      'RewardedAdLoader? _probeLoader',
    ]) {
      expect(code, contains(field), reason: 'майдон нест: $field');
    }
  });

  test('ҳар loader пеш аз loadAd ба майдон дода мешавад', () {
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
    // Дар probe loader бо `await` сохта мешавад, пас намунаи
    // `.then` ин ҷо кор намекунад.
    expect(code, contains('_probeLoader = await RewardedAdLoader.create('),
        reason: 'loader-и санҷиш ба майдон дода намешавад');
  });

  test('санҷиши демо назорати такрорӣ дорад', () {
    // Ду санҷиши ҳамзамон ҳарду ба ҳамон ҳолат менавиштанд ва
    // натиҷаи дар экран нишондодашуда ба сатри log мувофиқ набуд.
    expect(code, contains('if (_probeBusy) return _lastProbe;'),
        reason: 'ду санҷиши ҳамзамон имконпазир аст');
    expect(code, contains('if (run != _probeRun) return;'),
        reason: 'ҷавоби санҷиши кӯҳна ба санҷиши нав нисбат дода мешавад');
  });

  test('«✅» танҳо аз callback-и onAdLoaded меояд', () {
    // Агар ин сатр аз ҷои дигар ҳам гузошта шавад, «демо бор шуд»
    // дигар далели боркунии ВОҚЕӢ намешавад.
    final successes = RegExp(r"'✅[^']*'").allMatches(code).length;
    expect(successes, 1,
        reason: 'матни муваффақият дар $successes ҷо сохта мешавад — '
            'он бояд танҳо дар onAdLoaded бошад');
  });
}
