// Калиди Agora ба build мерасад?
//
// `kAgoraAppId` дар код НЕСТ — он ҳангоми сохтан бо `--dart-define`
// дода мешавад. Ин ҳамон хатари хомӯшро меорад, ки бо шиносаҳои
// реклама рӯй дод: агар қадами build калидро надиҳад, ҳеҷ чиз
// намешиканад. Барнома сохта мешавад, имзо мешавад, ба Google Play
// мебарояд — ва ҳар занг фавран «хатогӣ» медиҳад ва пӯшида мешавад.
//
// Маҳз ин дар `release.yml` буд: он танҳо `ad_units.json` медод.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ҷараёнҳое, ки барномаи ВОҚЕӢ месозанд.
const _buildFlows = [
  '.github/workflows/release.yml',
  '.github/workflows/flutter_full_build.yml',
  '.github/workflows/debug-apk.yml',
];

void main() {
  group('калиди Agora дар ҷараёнҳои сохтан', () {
    for (final path in _buildFlows) {
      test('$path калидро мегузарад', () {
        final f = File(path);
        if (!f.existsSync()) {
          markTestSkipped('$path нест');
          return;
        }
        final src = f.readAsStringSync();

        expect(src, contains('AGORA_APP_ID'),
            reason: '$path калиди Agora-ро намедиҳад — '
                'занг дар ин build кор намекунад');

        // Файл сохтан бас нест — онро ба `flutter build` низ додан лозим.
        expect(src, contains('--dart-define-from-file=.env'),
            reason: '$path файли .env месозад, вале ба build намедиҳад');
      });
    }

    test('ҳар қадами build ҳамаи файлҳои define-ро мегирад', () {
      // Як `--dart-define-from-file` дигареро бекор намекунад, вале
      // фаромӯш кардани яктои онҳо осон аст.
      final re = RegExp(r'flutter build (apk|appbundle)[^\n]*(\n[^\n]*)*?(?=\n\n|\n\s*-\s)');
      for (final path in _buildFlows) {
        final f = File(path);
        if (!f.existsSync()) continue;
        final src = f.readAsStringSync();
        for (final m in re.allMatches(src)) {
          final step = m.group(0)!;
          if (step.contains('--debug') && !step.contains('.env')) {
            fail('$path: build-и debug .env намегирад:\n$step');
          }
          expect(step, contains('dart_defines/ad_units.json'),
              reason: '$path: қадами build шиносаҳои рекламаро '
                  'намегирад:\n$step');
        }
      }
    });
  });

  test('код калидро дар худаш нигоҳ намедорад', () {
    // Калид бояд аз secret ояд. Агар касе онро ба код нависад, он ба
    // GitHub меафтад ва ҳар кас метавонад бо ҳисоби мо занг занад.
    final src = File('lib/core/agora_service.dart').readAsStringSync();
    expect(src, contains("String.fromEnvironment('AGORA_APP_ID'"),
        reason: 'калид бояд ҳангоми сохтан дода шавад');
    expect(src, contains("defaultValue: ''"),
        reason: 'қимати пешфарз бояд холӣ бошад, на калиди воқеӣ');
  });
}
