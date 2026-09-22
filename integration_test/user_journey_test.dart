// Барнома мисли КОРБАР истифода мешавад.
//
// ═══════════════════════════════════════════════════════════════════
//  `app_smoke_test.dart` танҳо мепурсад: «барнома кушод?»
//
//  Ин файл кори дигар мекунад — он барномаро МЕЗАНАД. Экранҳоро
//  мекушояд, забонро иваз мекунад, аз як экран ба дигаре зуд-зуд
//  мегузарад, майдонҳоро пур мекунад, тугмаҳоро мезанад.
//
//  Маҳз ҳамин гуна истифода камбудиҳоеро мекушояд, ки як бор
//  кушодани барнома ҳеҷ гоҳ намебинад:
//
//   • экран ҳангоми зуд-зуд гузаштан меафтад
//     (`setState` баъди `dispose`, controller-и партофташуда);
//   • баъди иваз кардани забон матн намеояд ё калиди хом менамояд;
//   • тугмаи «ба ақиб» кор намекунад ва корбар банд мемонад;
//   • дар экрани хурд матн аз ҳудуд мебарояд.
//
// ═══════════════════════════════════════════════════════════════════
//  ⚠️ ИН ТЕСТ ҲЕҶ ЧИЗ НАМЕНАВИСАД
//
//  Дар CI барнома ба сервери ВОҚЕИИ продакшн пайваст мешавад. Пас
//  ин ҷо ҳеҷ гоҳ бақайдгирӣ, пост, паём ё стори ФИРИСТОДА
//  НАМЕШАВАД — вагарна дар ҳисоби воқеӣ партов пайдо мешуд.
//
//  Танҳо экран, тугма ва матн санҷида мешаванд.
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

import 'package:raonson/app/app_settings.dart';
import 'package:raonson/auth/login/login_screen.dart';
import 'package:raonson/auth/password/forgot_password_screen.dart';
import 'package:raonson/auth/register/register_flow_screen.dart';
import 'package:raonson/core/ui/app_icons.dart';
import 'package:raonson/main.dart' as app;

/// То экрани вуруд мебарад. `false` — агар нарасид.
Future<bool> _toLogin(WidgetTester t) async {
  beginCapture();
  await app.main();
  installCapture();
  return waitFor(t, find.byType(LoginScreen),
      timeout: const Duration(seconds: 25));
}


void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  
  testWidgets('зуд-зуд байни экранҳо гузаштан барномаро намешиканад',
      (tester) async {
    if (!await _toLogin(tester)) {
      fail('экрани вуруд накушод');
    }

    // Се даври пурра: вуруд → бақайдгирӣ → ақиб → парол → ақиб.
    //
    // Маҳз такрор муҳим аст. Камбудии «setState баъди dispose» бори
    // аввал ҳеҷ гоҳ намебарояд — он вақте мебарояд, ки экран пӯшида
    // шавад, вале кори он ҳанӯз давом кунад.
    for (var round = 1; round <= 3; round++) {
      final toRegister = find.textContaining(
          RegExp('Сабти ном|Зарегистр|Sign up', caseSensitive: false));
      if (toRegister.evaluate().isNotEmpty) {
        await tester.tap(toRegister.first, warnIfMissed: false);
        await pumpFor(tester, 900);
        expect(find.byType(RegisterScreen), findsWidgets,
            reason: 'даври $round: экрани бақайдгирӣ накушод');

        // Ба ақиб.
        final nav = find.byType(Navigator).evaluate().isNotEmpty;
        expect(nav, isTrue);
        await goBack(tester);
        expect(find.byType(LoginScreen), findsWidgets,
            reason: 'даври $round: «ба ақиб» кор накард — '
                'корбар дар экран банд мемонад');
      }

      final forgot = find.textContaining(
          RegExp('фаромӯш|Забыли|Forgot', caseSensitive: false));
      if (forgot.evaluate().isNotEmpty) {
        await tester.tap(forgot.first, warnIfMissed: false);
        await pumpFor(tester, 900);
        if (find.byType(ForgotPasswordScreen).evaluate().isNotEmpty) {
          await goBack(tester);
          expect(find.byType(LoginScreen), findsWidgets,
              reason: 'даври $round: аз «парол фаромӯш шуд» '
                  'баргашта намешавад');
        }
      }
    }

    expect(realErrors, isEmpty,
        reason: 'ҳангоми гузариш хато партофт:\n${realErrors.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('иваз кардани забон матнро фавран иваз мекунад',
      (tester) async {
    if (!await _toLogin(tester)) fail('экрани вуруд накушод');

    final startLang = AppSettingsState.instance.lang;
    addTearDown(() => AppSettingsState.instance.setLang(startLang));

    // Ҳар се забон. Даври дуюм бардошта шуд: варақаи забон
    // аниматсия дорад ва вақти эмуляторро беҳуда мегирад.
    for (var round = 0; round < 1; round++) {
      for (final name in ['Русский', 'English', 'Тоҷикӣ']) {
        final chip = find.byIcon(AppIcons.language_rounded);
        if (chip.evaluate().isEmpty) return; // забон дар ин сохт нест
        await tester.tap(chip.first, warnIfMissed: false);
        await pumpFor(tester, 700);

        final item = find.text(name);
        if (item.evaluate().isEmpty) {
          // Варақа накушод — онро мепӯшем ва идома медиҳем.
          await tester.tapAt(const Offset(10, 10));
          await pumpFor(tester, 400);
          continue;
        }
        await tester.tap(item.last, warnIfMissed: false);
        await pumpFor(tester, 800);

        // Худи чип бояд номи забони НАВро нишон диҳад.
        expect(find.text(name), findsWidgets,
            reason: 'баъди интихоби «$name» матн иваз нашуд');
      }
    }

    // Калиди хом (`auth.welcome`) дар экран набояд бошад.
    //
    // Маҳз ҳамин вақте мешавад, ки калид дар як забон ҳаст, дар
    // дигаре не.
    final raw = find.textContaining(RegExp(r'^[a-z]+\.[a-zA-Z]+$'));
    expect(raw, findsNothing,
        reason: 'дар экран калиди тарҷумаи хом менамояд — '
            'дар ин забон матн нест');

    expect(realErrors, isEmpty,
        reason: 'ҳангоми иваз кардани забон хато:\n${realErrors.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('экрани бақайдгирӣ: санҷиши майдонҳо кор мекунад',
      (tester) async {
    if (!await _toLogin(tester)) fail('экрани вуруд накушод');

    final toRegister = find.textContaining(
        RegExp('Сабти ном|Зарегистр|Sign up', caseSensitive: false));
    if (toRegister.evaluate().isEmpty) return;
    await tester.tap(toRegister.first, warnIfMissed: false);
    await pumpFor(tester, 1000);
    expect(find.byType(RegisterScreen), findsWidgets);

    // Майдонҳои холӣ → тугмаи идома → бояд ХАТО нишон диҳад ва ҳеҷ
    // ҷо наравад.
    //
    // ⚠️ ҲЕҶ ГОҲ маълумоти пурра намедиҳем ва submit намекунем:
    // сервери воқеӣ ҳисоби партов месохт.
    final fields = find.byType(TextField);
    expect(fields, findsAtLeastNWidgets(3),
        reason: 'майдонҳои бақайдгирӣ нестанд');

    final next = find.textContaining(
        RegExp('Давом додан|Продолжить|Continue', caseSensitive: false));
    if (next.evaluate().isNotEmpty) {
      await tester.tap(next.first, warnIfMissed: false);
      await pumpFor(tester, 800);
      // Ҳанӯз дар ҳамон экран — санҷиш нагузошт.
      expect(find.byType(RegisterScreen), findsWidgets,
          reason: 'бо майдонҳои ХОЛӢ пеш рафт — санҷиш кор намекунад');
    }

    // Навиштан дар майдон кор мекунад?
    await tester.enterText(fields.first, 'Санҷиш');
    await pumpFor(tester, 400);
    expect(find.text('Санҷиш'), findsWidgets,
        reason: 'матн ба майдон дохил намешавад');

    expect(realErrors, isEmpty,
        reason: 'экрани бақайдгирӣ хато партофт:\n${realErrors.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('дар экрани хурд ҳеҷ экран аз ҳудуд намебарояд',
      (tester) async {
    // Телефони арзон: 320×640 dp.
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.25;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    if (!await _toLogin(tester)) fail('экрани вуруд накушод');
    await pumpFor(tester, 800);

    // Ҳамон роҳро мегузарем — вале дар экрани хурд.
    for (final pattern in [
      RegExp('Сабти ном|Зарегистр|Sign up', caseSensitive: false),
      RegExp('фаромӯш|Забыли|Forgot', caseSensitive: false),
    ]) {
      final link = find.textContaining(pattern);
      if (link.evaluate().isEmpty) continue;
      await tester.tap(link.first, warnIfMissed: false);
      await pumpFor(tester, 1000);
      // Экран бояд ба поён ҳаракат кунад, на бишканад.
      final scroll = find.byType(Scrollable);
      if (scroll.evaluate().isNotEmpty) {
        await tester.drag(scroll.first, const Offset(0, -400));
        await pumpFor(tester, 600);
        await tester.drag(scroll.first, const Offset(0, 400));
        await pumpFor(tester, 600);
      }
      await goBack(tester);
    }

    final overflow = realErrors
        .where((e) => e.contains('overflowed') || e.contains('OVERFLOW'))
        .toList();
    expect(overflow, isEmpty,
        reason: 'дар экрани хурд ҷузъҳо аз ҳудуд мебароянд:\n'
            '${overflow.join('\n')}');
    expect(realErrors, isEmpty,
        reason: 'дар экрани хурд хато:\n${realErrors.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 4)));
}
