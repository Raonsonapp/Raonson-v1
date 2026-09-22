// Барнома БО ҲИСОБИ ВОҚЕӢ — ҳамаи экранҳои асосӣ.
//
// ═══════════════════════════════════════════════════════════════════
//  Чаро ин файл лозим шуд
//
//  Ду тести дигари эмулятор танҳо СЕ экранро мекушоданд: вуруд,
//  сабти ном, барқарорсозии парол. Сабаб содда буд — бе ворид шудан
//  ба лента, Reels, чат, ҷустуҷӯ ва профил роҳ нест.
//
//  Яъне аз 106 экрани барнома 103-тоаш дар эмулятор ҲЕҶ ГОҲ кушода
//  намешуданд. Ҳар камбудие, ки маҳз дар онҳо буд, дида намешуд.
//
//  Акнун тест бо ҳисоби САНҶИШӢ ворид мешавад ва ҳар панҷ бахшро
//  мекушояд, варақ мезанад ва мебинад, ки чӣ мешавад.
//
// ═══════════════════════════════════════════════════════════════════
//  ⚠️ ИН ТЕСТ ТАНҲО МЕХОНАД
//
//  Дар CI барнома ба сервери ВОҚЕИИ шумо пайваст мешавад. Пас ин ҷо
//  ҲЕҶ ГОҲ пост, паём, стори, шарҳ ё лайк ФИРИСТОДА НАМЕШАВАД —
//  вагарна дар ҳисоби воқеӣ партов пайдо мешуд.
//
//  Иҷозат: кушодани экран, варақ задан, навиштан дар майдони
//  ҷустуҷӯ. Дигар ҳеҷ чиз.
//
// ═══════════════════════════════════════════════════════════════════
//  Парол дар КОД НЕСТ
//
//  Ном ва парол аз GitHub Secrets тавассути `--dart-define` меоянд:
//
//      TEST_USERNAME, TEST_PASSWORD
//
//  Агар онҳо набошанд, тест бе хато гузашта мешавад — вале он гоҳ
//  ин 103 экран боз санҷида НАМЕШАВАНД, ва инро тест рӯирост
//  менависад.
// ═══════════════════════════════════════════════════════════════════

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:raonson/auth/login/login_screen.dart';
import 'package:raonson/chat/inbox/chat_list_screen.dart';
import 'package:raonson/feed/timeline/feed_screen.dart';
import 'package:raonson/main.dart' as app;
import 'package:raonson/navigation/bottom_nav/bottom_nav_bar.dart';
import 'package:raonson/navigation/bottom_nav/bottom_nav_scaffold.dart';
import 'package:raonson/profile/profile_screen.dart';
import 'package:raonson/reels/reels_feed/reels_screen.dart';
import 'package:raonson/search/search_screen.dart';

const _user = String.fromEnvironment('TEST_USERNAME');
const _pass = String.fromEnvironment('TEST_PASSWORD');

final List<String> _errors = <String>[];

void _captureErrors() {
  final prev = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails d) {
    _errors.add(d.exceptionAsString());
    prev?.call(d);
  };
  final prevAsync = ui.PlatformDispatcher.instance.onError;
  ui.PlatformDispatcher.instance.onError = (Object e, StackTrace s) {
    _errors.add('$e');
    return prevAsync?.call(e, s) ?? true;
  };
}

/// Хатоҳои муҳит, на барнома.
bool _noise(String e) => const [
      'SocketException', 'ClientException', 'HandshakeException',
      'TimeoutException', 'Connection closed', 'Connection refused',
      'Failed host lookup', 'MissingPluginException', 'channel-error',
      'firebase', 'Firebase', 'google_mobile_ads', 'MobileAds', 'yandex',
      // Видеои ҳақиқӣ дар эмулятори бе GPU метавонад накушояд —
      // ин айби барнома нест.
      'VideoError', 'ExoPlaybackException', 'PlatformException(VideoError',
    ].any(e.contains);

List<String> get _real => _errors.where((e) => !_noise(e)).toList();

Future<void> _pump(WidgetTester t, [int ms = 800]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> _waitFor(WidgetTester t, Finder f,
    {Duration timeout = const Duration(seconds: 30)}) async {
  var spent = Duration.zero;
  const step = Duration(milliseconds: 100);
  while (spent < timeout) {
    await t.pump(step);
    if (f.evaluate().isNotEmpty) return true;
    spent += step;
  }
  return false;
}

/// Оё ин экран ҲОЗИР намоён аст?
///
/// Ҳар панҷ бахш ҳамеша дар дарахти виҷет ҳастанд — `BottomNavScaffold`
/// онҳоро дар `Offstage` нигоҳ медорад. Пас `find.byType(...)` ҳамаро
/// мебинад ва чизе исбот намекунад. Ин ҷо маҳз НАМОЁН буданаш
/// санҷида мешавад.
bool _visible(WidgetTester t, Finder screen) {
  final shown = find.descendant(
    of: find.byWidgetPredicate((w) => w is Offstage && !w.offstage),
    matching: screen,
  );
  return shown.evaluate().isNotEmpty;
}

/// Ба бахши рақами `i` мегузарад — маҳз мисли корбар, бо зери
/// навори поён.
Future<void> _tab(WidgetTester t, int i) async {
  final bar = find.byType(BottomNavBar);
  if (bar.evaluate().isEmpty) return;
  final r = t.getRect(bar);
  await t.tapAt(Offset(r.left + r.width * (i + 0.5) / 5, r.center.dy));
  await _pump(t, 1500);
}

/// Варақ задан — боло ва поён.
Future<void> _scroll(WidgetTester t) async {
  final s = find.byType(Scrollable);
  if (s.evaluate().isEmpty) return;
  await t.drag(s.first, const Offset(0, -500));
  await _pump(t, 900);
  await t.drag(s.first, const Offset(0, 400));
  await _pump(t, 900);
}

Future<bool> _login(WidgetTester t) async {
  await app.main();
  _captureErrors();

  // Агар токени кӯҳна бошад, барнома фавран лентаро мекушояд.
  if (await _waitFor(t, find.byType(BottomNavScaffold),
      timeout: const Duration(seconds: 6))) {
    return true;
  }
  if (!await _waitFor(t, find.byType(LoginScreen))) return false;

  final fields = find.byType(TextField);
  if (fields.evaluate().length < 2) return false;
  await t.enterText(fields.at(0), _user);
  await _pump(t, 400);
  await t.enterText(fields.at(1), _pass);
  await _pump(t, 400);

  final btn = find.textContaining(
      RegExp('Ворид шудан|Войти|Log in', caseSensitive: false));
  if (btn.evaluate().isEmpty) return false;
  await t.tap(btn.first, warnIfMissed: false);

  // Сервери HuggingFace метавонад хоб бошад — вақти васеъ.
  return _waitFor(t, find.byType(BottomNavScaffold),
      timeout: const Duration(seconds: 60));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  setUp(_errors.clear);

  testWidgets('ҳамаи панҷ бахши барнома кушода мешаванд ва намеафтанд',
      (tester) async {
    if (_user.isEmpty || _pass.isEmpty) {
      markTestSkipped(
          'TEST_USERNAME/TEST_PASSWORD дода нашудаанд — 103 экрани '
          'дохилӣ санҷида НАШУД. Онҳоро дар GitHub Secrets гузоред.');
      return;
    }

    expect(await _login(tester), isTrue,
        reason: 'ворид шуда нашуд — ном/парол ё сервер');

    // Ҳар бахш: кушода мешавад, варақ мезанад, хато намедиҳад.
    final tabs = <int, Finder>{
      0: find.byType(FeedScreen),
      1: find.byType(ReelsScreen),
      2: find.byType(ChatListScreen),
      3: find.byType(SearchScreen),
      4: find.byType(ProfileScreen),
    };
    const names = {
      0: 'Лента', 1: 'Reels', 2: 'Чат', 3: 'Ҷустуҷӯ', 4: 'Профил',
    };

    for (final i in tabs.keys) {
      await _tab(tester, i);
      expect(_visible(tester, tabs[i]!), isTrue,
          reason: '${names[i]}: бахш кушода нашуд');
      await _scroll(tester);
      expect(_real, isEmpty,
          reason: '${names[i]} хато партофт:\n${_real.join('\n')}');
    }

    // Ду давр — то боварӣ, ки гузариши такрорӣ чизе намешиканад.
    for (var round = 0; round < 2; round++) {
      for (final i in [4, 0, 3, 1, 2, 0]) {
        await _tab(tester, i);
      }
    }
    expect(_real, isEmpty,
        reason: 'ҳангоми гузариши такрорӣ хато:\n${_real.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 8)));

  testWidgets('ҷустуҷӯ натиҷа медиҳад ва намеафтад', (tester) async {
    if (_user.isEmpty || _pass.isEmpty) {
      markTestSkipped('маълумоти ҳисоби санҷишӣ нест');
      return;
    }
    expect(await _login(tester), isTrue);

    await _tab(tester, 3);
    expect(_visible(tester, find.byType(SearchScreen)), isTrue);

    final field = find.byType(TextField);
    if (field.evaluate().isNotEmpty) {
      // Танҳо ХОНДАН: ҷустуҷӯ чизе намесозад.
      await tester.enterText(field.first, 'a');
      await _pump(tester, 2500);
      await tester.enterText(field.first, 'ra');
      await _pump(tester, 2500);
    }
    expect(_real, isEmpty,
        reason: 'ҷустуҷӯ хато партофт:\n${_real.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('дар экрани хурд ҳеҷ бахш аз ҳудуд намебарояд',
      (tester) async {
    if (_user.isEmpty || _pass.isEmpty) {
      markTestSkipped('маълумоти ҳисоби санҷишӣ нест');
      return;
    }
    // Телефони арзон: 320×640 dp.
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.25;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    expect(await _login(tester), isTrue);
    for (var i = 0; i < 5; i++) {
      await _tab(tester, i);
      await _scroll(tester);
    }

    final overflow = _real
        .where((e) => e.contains('overflowed') || e.contains('OVERFLOW'))
        .toList();
    expect(overflow, isEmpty,
        reason: 'дар экрани хурд ҷузъҳо аз ҳудуд мебароянд:\n'
            '${overflow.join('\n')}');
  }, timeout: const Timeout(Duration(minutes: 8)));
}
