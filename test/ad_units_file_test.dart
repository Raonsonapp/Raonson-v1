// test/ad_units_file_test.dart
// Шиносаҳои реклама ба build-и release мерасанд?
//
// Дар меъмории ҳозира шиноса дар код нест — он ҳангоми сохтан дода
// мешавад. Ин як хатари нав меорад: агар қадами build файлро надиҳад,
// ҳеҷ чиз намешиканад. Барнома сохта мешавад, имзо мешавад, ба Google
// Play мебарояд — ва реклама умуман нест. Ҳеҷ хатогӣ, ҳеҷ огоҳӣ.
//
// Маҳз ҳамин дар `release.yml` буд: он AAB-и имзошударо барои Play
// месохт ва ҳеҷ --dart-define намедод.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _configPath = 'dart_defines/ad_units.json';

void main() {
  late Map<String, dynamic> units;

  setUpAll(() {
    units = jsonDecode(File(_configPath).readAsStringSync())
        as Map<String, dynamic>;
  });

  group('файли шиносаҳо', () {
    test('ҳар чор шакл шиноса дорад', () {
      for (final k in [
        'YANDEX_INTERSTITIAL_ID',
        'YANDEX_REWARDED_ID',
        'YANDEX_BANNER_ID',
        'YANDEX_NATIVE_FEED_ID',
      ]) {
        expect(units[k], isA<String>(), reason: '$k нест');
        expect(units[k] as String, isNotEmpty, reason: '$k холӣ аст');
      }
    });

    test('Rewarded ҷойгиршавии нави воқеӣ аст', () {
      // Пештар ин шиноса вуҷуд надошт ва дастгоҳ мегуфт:
      // «Provided AdUnitId does not exist!». Соҳиби барнома онро дар
      // кабинети Yandex сохт.
      expect(units['YANDEX_REWARDED_ID'], 'R-M-19230220-2');
    });

    test('Interstitial тағйир наёфтааст', () {
      expect(units['YANDEX_INTERSTITIAL_ID'], 'R-M-19230220-1');
    });

    test('ҳар шиноса шакли дурусти Yandex дорад', () {
      final shape = RegExp(r'^R-M-\d+-\d+$');
      units.forEach((k, v) {
        expect(v, matches(shape), reason: '$k шакли ғайричашмдошт дорад');
      });
    });

    test('ҳеҷ шиносаи демо дар танзимоти production нест', () {
      // Демо дар release рекламаи санҷиширо ба корбарони воқеӣ
      // мебарорад ва ҳеҷ даромад намедиҳад.
      units.forEach((k, v) {
        expect(v as String, isNot(contains('demo')), reason: k);
      });
    });
  });

  group('қадамҳои build', () {
    // Фармонҳо бо `\` ба сатрҳо тақсим мешаванд; онҳо як фармони
    // мантиқӣ мешаванд, пас пеш аз санҷиш якҷоя карда мешаванд.
    List<String> buildCommands(File f) {
      final joined = f.readAsStringSync().replaceAll('\\\n', ' ');
      return const LineSplitter()
          .convert(joined)
          .where((l) => l.contains('flutter build'))
          .toList();
    }

    test('ҳар build-и release файли шиносаҳоро мегирад', () {
      final offenders = <String>[];
      for (final f in Directory('.github/workflows').listSync()) {
        if (f is! File || !f.path.endsWith('.yml')) continue;
        for (final cmd in buildCommands(f)) {
          if (!cmd.contains('--release')) continue;
          if (!cmd.contains(_configPath)) {
            offenders.add('${f.path}: ${cmd.trim()}');
          }
        }
      }
      expect(offenders, isEmpty,
          reason: 'build-и release бе шиносаи реклама:\n'
              '${offenders.join('\n')}');
    });

    test('ҳадди ақал як қадами build ҳаст', () {
      // Агар тести боло ҳеҷ фармон наёбад, ӯ низ сабз мешавад —
      // яъне ҳимоя ҳаст, вале чизе намесанҷад.
      var count = 0;
      for (final f in Directory('.github/workflows').listSync()) {
        if (f is! File || !f.path.endsWith('.yml')) continue;
        count += buildCommands(f).where((c) => c.contains('--release')).length;
      }
      expect(count, greaterThanOrEqualTo(2),
          reason: 'қадами build-и release ёфт нашуд');
    });
  });
}
