import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Workflow-и вайрон — сурхии сабабнофаҳмо.
//
// ═══════════════════════════════════════════════════════════════════
//  `flutter_full_build.yml` 1949 бор «афтид» — ва ҳеҷ гоҳ иҷро
//  нашуд. Дар рӯйхат сурх менамуд, вале ҳеҷ job оғоз намешуд ва
//  ҳеҷ log набуд. Сабаб як сатр:
//
//      if: ${{ secrets.KEYSTORE_BASE64 != '' }}
//
//  Контексти `secrets` дар `if:` ИҶОЗАТ ДОДА НАМЕШАВАД — он танҳо
//  дар `env:` ва `with:` кор мекунад. GitHub худи workflow-ро рад
//  мекард.
//
//  Натиҷа: на analyze, на тест, на APK — ҳеҷ кадом ҳеҷ гоҳ
//  нагузашт, вале касе намедонист, ки чаро.
//
//  Ин тест ҳамон хаторо дар компютер мегирад — пеш аз push.
// ═══════════════════════════════════════════════════════════════════

Iterable<File> _workflows() => Directory('.github/workflows')
    .listSync()
    .whereType<File>()
    .where((f) => f.path.endsWith('.yml') || f.path.endsWith('.yaml'));

void main() {
  test('дар папка workflow ҳаст', () {
    expect(_workflows().isNotEmpty, isTrue);
  });

  test('`secrets` дар `if:` истифода намешавад', () {
    final bad = <String>[];
    for (final f in _workflows()) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        // Танҳо худи шарт, на эзоҳ.
        final code = l.split('#').first;
        if (RegExp(r'^\s*if\s*:').hasMatch(code) &&
            code.contains('secrets.')) {
          bad.add('${f.path}:${i + 1}: ${l.trim()}');
        }
      }
    }
    expect(bad, isEmpty,
        reason: 'GitHub чунин workflow-ро РАД мекунад — он дар 0 '
            'сония меафтад ва ҳеҷ job оғоз намешавад:\n'
            '${bad.join('\n')}');
  });

  test('ҳар workflow `on:` ва `jobs:` дорад', () {
    for (final f in _workflows()) {
      final src = f.readAsStringSync();
      expect(RegExp(r'^on:', multiLine: true).hasMatch(src), isTrue,
          reason: '${f.path}: `on:` нест — ҳеҷ гоҳ оғоз намешавад');
      expect(RegExp(r'^jobs:', multiLine: true).hasMatch(src), isTrue,
          reason: '${f.path}: `jobs:` нест');
    }
  });

  test('қадамҳои тести эмулятор дар ЯК сатранд', () {
    // `android-emulator-runner` ҳар сатри `script`-ро ҷудогона
    // `sh -c` мекунад. Пас `\` дар охири сатр идомаи фармон
    // намешавад — он ҳамчун далели изофӣ мемонад ва Flutter
    // мегӯяд «Integration tests and unit tests cannot be run in a
    // single invocation». Ду build маҳз аз ин афтиданд.
    final f = File('.github/workflows/integration-test.yml');
    if (!f.existsSync()) return;
    final lines = f.readAsLinesSync();
    final bad = <String>[];
    var inScript = false;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (RegExp(r'^\s*script\s*:\s*\|').hasMatch(l)) {
        inScript = true;
        continue;
      }
      if (inScript) {
        if (l.trim().isNotEmpty && !l.startsWith('    ')) inScript = false;
        if (inScript && l.trimRight().endsWith(r'\')) {
          bad.add('${f.path}:${i + 1}: ${l.trim()}');
        }
      }
    }
    expect(bad, isEmpty,
        reason: 'идомаи сатр бо `\\` дар `script:` кор намекунад:\n'
            '${bad.join('\n')}');
  });

  test('номи иловагии сирр ҳамеша бо номи АСЛӢ ҳамроҳ аст', () {
    // `release.yml` (ки кор мекунад) `STORE_PASSWORD`-ро мехонад.
    // `flutter_full_build.yml` бошад `KEYSTORE_PASSWORD` навишта
    // буд — чунин сирр ВУҶУД НАДОРАД.
    //
    // GitHub барои сирри набуда огоҳӣ намедиҳад: он танҳо сатри
    // ХОЛӢ мегузорад. Баъд Gradle мегӯяд «keystore password was
    // incorrect» — ва сабаб дар ҷои тамоман дигар ҷустуҷӯ мешавад.
    //
    // Қоида: агар файл номи ИЛОВАГӢ истифода барад, ӯ бояд номи
    // АСЛиро низ дошта бошад (ҳамчун эҳтиёт).
    const primary = 'STORE_PASSWORD';
    const alias = 'KEYSTORE_PASSWORD';

    for (final f in _workflows()) {
      final src = f.readAsStringSync();
      final hasAlias = src.contains('secrets.$alias');
      if (!hasAlias) continue;
      expect(src.contains('secrets.$primary'), isTrue,
          reason: '${f.path}: танҳо `$alias`-ро мехонад. Дар '
              '`release.yml` ном `$primary` аст — пас ин ҷо сатри '
              'ХОЛӢ мемонад ва имзо меафтад');
    }
  });

  test('ду роҳи тақсими APK омехта намешаванд', () {
    // Gradle-и лоиҳа блоки `splits` дорад, ки бо `SPLIT_PER_ABI`
    // фаъол мешавад. Он файлҳоро месозад, вале ХУДИ FLUTTER аз он
    // бехабар аст ва `app-release.apk`-ро меҷӯяд:
    //
    //   Gradle build failed to produce an .apk file
    //
    // Роҳи дуруст — парчами худи Flutter (`--split-per-abi`).
    for (final f in _workflows()) {
      final src = f.readAsStringSync();
      final gradleWay = src.contains("SPLIT_PER_ABI: 'true'") ||
          src.contains('SPLIT_PER_ABI: "true"');
      if (!gradleWay) continue;
      expect(src.contains('flutter build apk'), isFalse,
          reason: '${f.path}: `SPLIT_PER_ABI` бо `flutter build apk` '
              'кор намекунад — Flutter `app-release.apk`-ро меҷӯяд '
              'ва намеёбад. Ба ҷои он `--split-per-abi` гиред');
    }
  });

  test('ҳангоми тақсим роҳи артефакт ба ЯК файл нишон намедиҳад', () {
    // Бо тақсим `app-release.apk` вуҷуд надорад — номҳо
    // `app-arm64-v8a-release.apk` ва ғайра мешаванд. Агар роҳ
    // собит монад, upload хомӯш ХОЛӢ мемонад.
    for (final f in _workflows()) {
      final src = f.readAsStringSync();
      if (!src.contains('--split-per-abi')) continue;
      expect(src.contains('path: build/app/outputs/flutter-apk/app-release.apk'),
          isFalse,
          reason: '${f.path}: бо тақсим ин файл вуҷуд надорад — '
              'артефакт холӣ мемонад');
    }
  });

  test('блоки splits тақсими худи Flutter-ро хомӯш намекунад', () {
    // Агар `flutter build apk --split-per-abi` даъват шавад, Flutter
    // худаш `splits.abi`-ро фаъол мекунад. Агар баъд блоки лоиҳа
    // онро хомӯш кунад, як output-и БЕ ABI мемонад ва плагини
    // Flutter меафтад:
    //
    //   flutter.groovy:1182
    //   int abiVersionCode = ABI_VERSION.get(output.getFilter(ABI))
    //   → GroovyCastException: Cannot cast object 'null' ... to int
    final f = File('android/app/build.gradle.kts');
    if (!f.existsSync()) return;
    final src = f.readAsStringSync();
    if (!src.contains('splits')) return;
    expect(src.contains('split-per-abi'), isTrue,
        reason: 'блоки `splits` ҳаст, вале парчами худи Flutter '
            '(`split-per-abi`) ба назар гирифта намешавад — '
            'ду механизм ба ҳам мерасанд ва build меафтад');
  });
}
