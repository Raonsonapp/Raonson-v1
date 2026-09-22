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
}
