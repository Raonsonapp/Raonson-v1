// Тести БАРНОМАИ ЗИНДА.
//
// ═══════════════════════════════════════════════════════════════════
//  Чаро ин файл ҳаст
//
//  Шумо гуфтед: «ту чихе тест мекуни ки ними барнома кор намекунад».
//  Ин дуруст буд. Ҳамаи тестҳои то ҳол дар `test/` МАНТИҚРО
//  месанҷиданд: функсия рақами дурустро медиҳад ё не. Онҳо ҳеҷ гоҳ
//  худи барномаро намекушоданд. Барои ҳамин:
//
//   • экрани сиёҳ,
//   • тугмаи мурда,
//   • афтидани барнома ҳангоми кушодан,
//   • матни аз экран баромада (overflow),
//
//  ҳеҷ кадоме дида намешуд — маҳз он чизҳое, ки шумо мебинед.
//
//  Ин тест барномаро ДАР ЭМУЛЯТОРИ ВОҚЕИИ Android мекушояд, ҳамон
//  тавре ки телефон мекушояд, ва мебинад, ки чӣ мешавад.
//
// ═══════════════════════════════════════════════════════════════════
//  Ин тест ЧИРО НАМЕСАНҶАД — бояд рӯирост гуфт
//
//   • огоҳиномаи FCM — калиди Google дар эмулятор нест;
//   • занги Agora — микрофон ва камераи воқеӣ лозим;
//   • камераи воқеӣ, галерея, аксбардорӣ;
//   • ҳар чизе, ки вуруд ба аккаунтро талаб мекунад — парол дар
//     ин ҷо гузошта намешавад (ниг. қоидаи махфият).
//
//  Пас «тест сабз шуд» маънои «ҳама чиз кор мекунад»-ро НАДОРАД.
//  Маънои он: «барнома мекушояд, намеафтад ва экранҳои аввал
//  дурустанд».
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

import 'package:raonson/app/app_splash.dart';
import 'package:raonson/auth/login/login_screen.dart';
import 'package:raonson/core/ui/app_icons.dart';
import 'package:raonson/main.dart' as app;
import 'package:raonson/navigation/bottom_nav/bottom_nav_scaffold.dart';

// Ҷамъоварии хатоҳо, pump, интизорӣ ва бозгашт — ҳама дар
// `harness.dart`. Ҳар се тести эмулятор ҳамонро истифода мебаранд,
// то камбудии «handler барнагардонида шуд» такрор нашавад.

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('барнома мекушояд ва намеафтад', (tester) async {
    // Тартиб: handler-и ТЕСТ пеш аз `app.main()` нигоҳ дошта
    // мешавад, вагарна хатоҳо ба handler-и БАРНОМА мераванд ва тест
    // аз онҳо бехабар мемонад.
    //
    // Сохтани виҷетҳо баъди баргаштани `main` мешавад — пас ҳамаи
    // хатоҳои сохтан ҳанӯз пеш истодаанд.
    beginCapture();
    await app.main();
    installCapture();

    await pumpFor(tester, 2000);

    // 1. Дарахти виҷет умуман сохта шуд?
    expect(find.byType(MaterialApp), findsOneWidget,
        reason: 'барнома ҳатто MaterialApp насохт — экрани сиёҳ');

    // 2. Экрани аввал — splash ё аллакай экрани кории барнома.
    //    (Агар cache-и зуд бошад, splash метавонад аллакай гузашта
    //    бошад — барои ҳамин ҳарду қабул аст.)
    final firstScreen = find.byType(AppSplash).evaluate().isNotEmpty ||
        find.byType(LoginScreen).evaluate().isNotEmpty ||
        find.byType(BottomNavScaffold).evaluate().isNotEmpty;
    expect(firstScreen, isTrue,
        reason: 'на splash, на login, на лента — экрани номаълум');

    // 3. Splash бояд ГУЗАРАД. Агар начунин бошад — маҳз ҳамон
    //    «экрани сиёҳи абадӣ», ки корбар мебинад.
    final loaded = await waitFor(
      tester,
      find.byWidgetPredicate((w) =>
          w is LoginScreen || w is BottomNavScaffold),
      timeout: const Duration(seconds: 25),
    );
    expect(loaded, isTrue,
        reason: 'барнома дар splash банд монд — корбар экрани '
            'логоро абадан мебинад');

    expect(realErrors, isEmpty,
        reason: 'ҳангоми кушодан хато партофт:\n${realErrors.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('экрани вуруд пурра ва зинда аст', (tester) async {
    beginCapture();
    await app.main();
    installCapture();

    final onLogin =
        await waitFor(tester, find.byType(LoginScreen),
            timeout: const Duration(seconds: 25));
    if (!onLogin) {
      // Дар эмулятори тоза токен нест, пас ин набояд шавад. Вале
      // агар шуд — ин тестро гузаронда наметавонем ва РӮИРОСТ
      // мегӯем, на ин ки «сабз» менависем.
      fail('экрани вуруд накушод — дар эмулятор токени кӯҳна ҳаст?');
    }

    // Ду майдон: ном ва парол. Агар яке набошад — вуруд ғайриимкон.
    expect(find.byType(TextField), findsAtLeastNWidgets(2),
        reason: 'майдонҳои ном/парол нестанд');

    // Тугмаи «чашм» — парол пинҳон/намоён.
    final eye = find.byIcon(AppIcons.visibility_off_rounded);
    if (eye.evaluate().isNotEmpty) {
      await tester.tap(eye.first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byIcon(AppIcons.visibility_rounded), findsWidgets,
          reason: 'тугмаи «чашм» мурда аст — зер мешавад, ҳеҷ чиз '
              'намешавад');
    }

    // Навиштан дар майдон кор мекунад?
    await tester.enterText(find.byType(TextField).first, 'raonson');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('raonson'), findsWidgets,
        reason: 'матн ба майдон дохил намешавад — клавиатура '
            'банд аст');

    expect(realErrors, isEmpty,
        reason: 'экрани вуруд хато партофт:\n${realErrors.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('дар экрани хурд матн аз ҳудуд намебарояд', (tester) async {
    // Телефони арзон: 320×640 dp. Маҳз дар чунин экранҳо навори
    // зарди «BOTTOM OVERFLOWED BY … PIXELS» мебарояд.
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.25;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    beginCapture();
    await app.main();
    installCapture();

    await waitFor(tester, find.byType(LoginScreen),
        timeout: const Duration(seconds: 25));
    await pumpFor(tester, 1000);

    final overflow = realErrors
        .where((e) => e.contains('overflowed') || e.contains('OVERFLOW'))
        .toList();
    expect(overflow, isEmpty,
        reason: 'дар экрани хурд ҷузъҳо аз ҳудуд мебароянд:\n'
            '${overflow.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
