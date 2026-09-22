import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Функсия ҳаст — вале ба он РОҲ нест.
//
// ═══════════════════════════════════════════════════════════════════
//  Ин бузургтарин навъи камбудии барнома буд ва ҳеҷ тест онро
//  намегирифт.
//
//  Мисол: `lib/live/live_screens.dart` — 420 сатр, Agora, сервер,
//  ҳама тайёр. Вале `LiveListScreen` аз ҲЕҶ ҶОИ барнома кушода
//  намешуд. На тугма, на роҳ. Яъне пахши зинда вуҷуд дошт ва ба
//  корбар ҳеҷ гоҳ намерасид.
//
//  Ҳамин тавр `EmailVerifyScreen` ва `OtpVerifyScreen`: экранҳо
//  буданд, вале аз куҷо кушода шаванд — маълум не.
//
//  `flutter analyze` инро НАМЕБИНАД: класс эълон шудааст, синтаксис
//  дуруст аст, ҳеҷ огоҳӣ нест.
// ═══════════════════════════════════════════════════════════════════

String _read(String p) => File(p).readAsStringSync();

/// Дар кадом файлҳои ДИГАР ин ном вомехӯрад?
int _usesOutside(String className, String ownFile) {
  var n = 0;
  for (final f in Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))) {
    if (f.path == ownFile) continue;
    n += RegExp('\\b$className\\b').allMatches(f.readAsStringSync()).length;
  }
  return n;
}

void main() {
  group('экранҳо аз барнома кушода мешаванд', () {
    test('Live — пахши зинда', () {
      expect(_usesOutside('LiveListScreen', 'lib/live/live_screens.dart'),
          greaterThan(0),
          reason: 'Live аз ҳеҷ ҷо кушода намешавад — '
              'функсия ҳасту корбар онро намебинад');
    });

    test('Live дар менюи сохтан аст, мисли Instagram', () {
      final src = _read('lib/create/gallery_picker_screen.dart');
      expect(src, contains('LiveListScreen'),
          reason: 'дар Instagram Live маҳз дар қатори '
              'Пост/Стори/Reels аст');
    });

    test('тасдиқи почта', () {
      expect(
          _usesOutside('EmailVerifyScreen',
              'lib/auth/verification/email_verify_screen.dart'),
          greaterThan(0),
          reason: 'экрани тасдиқи почта аз ҳеҷ ҷо кушода намешавад');
      expect(
          _usesOutside('OtpVerifyScreen',
              'lib/auth/verification/otp_verify_screen.dart'),
          greaterThan(0));
    });
  });

  group('роҳҳои эълоншуда case доранд', () {
    // Роҳе, ки дар `AppRoutes` ҳаст, вале дар `onGenerateRoute` case
    // надорад, ба `default` меафтад ва экрани ВУРУДро медиҳад.
    // Маҳз ҳамин бо `/otp-verify` шуда буд.
    test('ҳар сатри AppRoutes дар app_controller истифода мешавад', () {
      final routes = _read('lib/app/app_routes.dart');
      final ctrl = _read('lib/app/app_controller.dart');

      final names = RegExp(r'static const String (\w+) =')
          .allMatches(routes)
          .map((m) => m.group(1)!)
          .where((n) => n != 'splash') // splash экран нест, ҳолат аст
          .toList();

      expect(names, isNotEmpty);
      final missing = names
          .where((n) => !ctrl.contains('AppRoutes.$n'))
          .toList();
      expect(missing, isEmpty,
          reason: 'ин роҳҳо эълон шудаанд, вале case надоранд — '
              'корбар ба экрани вуруд меафтад: $missing');
    });

    test('AppRoutes танҳо ЯК ҷо эълон шудааст', () {
      // Пеш `lib/navigation/route_guards.dart` нусхаи дуюми
      // `AppRoutes` дошт бо қиматҳои ДИГАР (`/otp` ба ҷои
      // `/otp-verify`). Агар касе тасодуфан онро import мекард,
      // ҳамаи роҳҳо вайрон мешуданд.
      final decls = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) =>
              RegExp(r'\babstract class AppRoutes\b')
                  .hasMatch(f.readAsStringSync()))
          .map((f) => f.path)
          .toList();
      expect(decls.length, 1,
          reason: 'ду AppRoutes бо қиматҳои гуногун: $decls');
    });
  });

  group('дархостҳо ҷавоби сервeрро месанҷанд', () {
    // `ApiClient.post` ҳангоми 400/401 хато НАМЕПАРТОЯД — Response
    // бармегардонад. Пас `try { post() } catch` ҳеҷ гоҳ кор
    // намекунад ва ХАТО «муваффақият» ҳисоб мешавад.
    //
    // Маҳз ин буд: рамзи НОДУРУСТ ҳам «тасдиқ» мешуд.
    for (final f in [
      'lib/auth/verification/email_verify_screen.dart',
      'lib/auth/verification/otp_verify_screen.dart',
    ]) {
      test('${f.split('/').last} statusCode-ро месанҷад', () {
        expect(_read(f), contains('res.statusCode >= 400'),
            reason: 'ҷавоби хатои сервер ҳамчун муваффақият '
                'қабул мешавад');
      });
    }
  });

  group('калидҳои тарҷума дар ҳар се забон ҳастанд', () {
    test('verify.*', () {
      final src = _read('lib/core/i18n/strings.dart');
      for (final k in [
        'verify.emailTitle',
        'verify.emailSubtitle',
        'verify.emailHint',
        'verify.send',
        'verify.codeTitle',
        'verify.codeSentTo',
        'verify.codeHint',
        'verify.confirm',
        'verify.done',
        'verify.badCode',
        'verify.failed',
        'settings.verifyEmail',
      ]) {
        final n = "'$k'".allMatches(src).length;
        expect(n, 3,
            reason: '$k дар $n забон аст, на 3 — '
                'дар забони норасида калиди хом менамояд');
      }
    });
  });
}
