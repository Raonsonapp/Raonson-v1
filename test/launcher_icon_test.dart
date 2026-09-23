import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Корбар: «логои барнома безеб мондаги».
//
// Сабаб: иконаи Android як расми 1254×1254 (1.4 МБ) буд, ки бе тағйир
// дар ҳамаи 5 зичӣ меистод (6.9 МБ дар APK) ва иконаи «adaptive»
// набуд. Launcher-ҳои нави Android чунин иконаро хурд карда дар
// дохили қуттии ранга мегузоранд.
void main() {
  const res = 'android/app/src/main/res';

  test('иконаи adaptive ҳаст', () {
    for (final f in ['ic_launcher.xml', 'ic_launcher_round.xml']) {
      final s = File('$res/mipmap-anydpi-v26/$f').readAsStringSync();
      expect(s, contains('<adaptive-icon'));
    }
    final m = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(m, contains('android:roundIcon="@mipmap/ic_launcher_round"'));
  });

  test('ҳар зичӣ иконаи андозаи худро дорад, на расми 1.4 МБ', () {
    for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
      for (final f in ['ic_launcher.png', 'ic_launcher_round.png']) {
        final size = File('$res/mipmap-$d/$f').lengthSync();
        expect(size, lessThan(120 * 1024),
            reason: '$d/$f $size байт — боз расми калон бе тағйир');
      }
    }
  });
}
