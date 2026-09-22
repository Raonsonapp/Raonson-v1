// ЯК СЕССИЯИ ПУРРАИ КОРБАР — маҳз мисли одами телефондор.
//
// ═══════════════════════════════════════════════════════════════════
//  Ин файл барномаро мисли корбари ҳақиқӣ истифода мебарад: ворид
//  мешавад, лентаро варақ мезанад, шарҳҳоро мекушояд, ба профили
//  каси дигар медарояд, стори мебинад, Reels мегардонад, ҷустуҷӯ
//  мекунад, ба танзимот медарояд ва ҳар зерэкранро мекушояд.
//
//  Чаро ЯК тест, на панҷто: ҳар `testWidgets` барномаро аз нав
//  мекушояд ва АЗ НАВ ворид мешавад. Се файл × вуруди алоҳида =
//  эмулятор 30 дақиқа кор мекард. Корбари ҳақиқӣ ҳам як бор ворид
//  мешавад ва баъд ҳама ҷоро мегардад.
//
// ═══════════════════════════════════════════════════════════════════
//  ⚠️ ЧӢ КОР МЕКУНАД ВА ЧӢ НЕ
//
//  МЕКУНАД: экран мекушояд, варақ мезанад, менависад дар ҷустуҷӯ,
//  менюҳоро мекушояд ва мепӯшад.
//
//  НАМЕКУНАД: пост, стори, паём, шарҳ, лайк, обуна, ҳазф. Дар CI
//  барнома ба сервери ВОҚЕИИ шумо пайваст мешавад — партов мондан
//  мумкин нест.
//
//  (Ҳисоби тамошо ҳангоми кушодани лента ва стори худкор меравад —
//  ин аз хондан ҷудонашаванда аст ва корбари ҳақиқӣ ҳам ҳамин
//  тавр мекунад.)
//
// ═══════════════════════════════════════════════════════════════════
//  Парол дар КОД НЕСТ — аз GitHub Secrets тавассути `--dart-define`:
//  TEST_USERNAME, TEST_PASSWORD.
// ═══════════════════════════════════════════════════════════════════

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:raonson/app/app.dart';
import 'package:raonson/auth/login/login_screen.dart';
import 'package:raonson/chat/inbox/chat_list_screen.dart';
import 'package:raonson/core/ui/app_icons.dart';
import 'package:raonson/feed/timeline/feed_screen.dart';
import 'package:raonson/main.dart' as app;
import 'package:raonson/navigation/bottom_nav/bottom_nav_bar.dart';
import 'package:raonson/navigation/bottom_nav/bottom_nav_scaffold.dart';
import 'package:raonson/profile/profile_screen.dart';
import 'package:raonson/reels/reels_feed/reels_screen.dart';
import 'package:raonson/search/search_screen.dart';
import 'package:raonson/settings/settings_screen.dart';

const _user = String.fromEnvironment('TEST_USERNAME');
const _pass = String.fromEnvironment('TEST_PASSWORD');

final List<String> _errors = <String>[];

/// Ҳар қадами сессия — то дар гузориш маълум бошад, кадомаш шуд.
final List<String> _steps = <String>[];

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

bool _noise(String e) => const [
      'SocketException', 'ClientException', 'HandshakeException',
      'TimeoutException', 'Connection closed', 'Connection refused',
      'Failed host lookup', 'MissingPluginException', 'channel-error',
      'firebase', 'Firebase', 'google_mobile_ads', 'MobileAds', 'yandex',
      // Видеои ҳақиқӣ дар эмулятори бе GPU метавонад накушояд.
      'VideoError', 'ExoPlaybackException', 'MediaCodec',
    ].any(e.contains);

List<String> get _real => _errors.where((e) => !_noise(e)).toList();

/// Баъди ҳар қадам: хато ҷамъ нашуд?
void _check(String step) {
  _steps.add(step);
  expect(_real, isEmpty,
      reason: 'дар қадами «$step» хато партофт:\n${_real.join('\n')}\n'
          'қадамҳои гузашта: ${_steps.join(' → ')}');
}

Future<void> _pump(WidgetTester t, [int ms = 800]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<bool> _waitFor(WidgetTester t, Finder f,
    {Duration timeout = const Duration(seconds: 25)}) async {
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
/// Ҳар панҷ бахш ҳамеша дар дарахти виҷет ҳастанд —
/// `BottomNavScaffold` онҳоро дар `Offstage` нигоҳ медорад. Пас
/// `find.byType(...)` ҳамаро мебинад ва чизе исбот намекунад.
bool _visible(Finder screen) => find
    .descendant(
      of: find.byWidgetPredicate((w) => w is Offstage && !w.offstage),
      matching: screen,
    )
    .evaluate()
    .isNotEmpty;

Future<void> _tab(WidgetTester t, int i) async {
  final bar = find.byType(BottomNavBar);
  if (bar.evaluate().isEmpty) return;
  final r = t.getRect(bar);
  await t.tapAt(Offset(r.left + r.width * (i + 0.5) / 5, r.center.dy));
  await _pump(t, 1600);
}

Future<void> _scroll(WidgetTester t, {int times = 2}) async {
  for (var i = 0; i < times; i++) {
    final s = find.byType(Scrollable);
    if (s.evaluate().isEmpty) return;
    await t.drag(s.first, const Offset(0, -450));
    await _pump(t, 800);
  }
  final s = find.byType(Scrollable);
  if (s.evaluate().isNotEmpty) {
    await t.drag(s.first, const Offset(0, 900));
    await _pump(t, 800);
  }
}

/// Бозгашт бе хатари бастани барнома.
///
/// `handlePopRoute()` ҳангоми набудани роҳи бозгашт барномаро
/// МЕБАНДАД ва тест абадан интизор мемонад. Барои ҳамин танҳо
/// `Navigator`-и худи барнома истифода мешавад.
Future<void> _back(WidgetTester t) async {
  final nav = appNavigatorKey.currentState;
  if (nav != null && nav.canPop()) nav.pop();
  await _pump(t, 900);
}

/// Экранеро мекушояд ва мепӯшад. `true` — агар воқеан кушода шуд.
Future<bool> _openThenBack(WidgetTester t, Finder tapTarget,
    {Finder? expectScreen, int wait = 1500}) async {
  if (tapTarget.evaluate().isEmpty) return false;
  await t.tap(tapTarget.first, warnIfMissed: false);
  await _pump(t, wait);
  final opened =
      expectScreen == null || expectScreen.evaluate().isNotEmpty;
  await _back(t);
  return opened;
}

Future<bool> _login(WidgetTester t) async {
  await app.main();
  _captureErrors();

  // Токени кӯҳна бошад — фавран лента кушода мешавад.
  if (await _waitFor(t, find.byType(BottomNavScaffold),
      timeout: const Duration(seconds: 8))) {
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
      timeout: const Duration(seconds: 90));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('сессияи пурраи корбар: ҳама бахш ва зерэкранҳо',
      (tester) async {
    if (_user.isEmpty || _pass.isEmpty) {
      markTestSkipped('TEST_USERNAME/TEST_PASSWORD дода нашудаанд — '
          'экранҳои дохилӣ санҷида НАШУД');
      return;
    }
    _errors.clear();
    _steps.clear();

    expect(await _login(tester), isTrue,
        reason: 'ворид шуда нашуд — ном/парол ё сервер');
    _check('вуруд');

    // ── 1. ЛЕНТА ────────────────────────────────────────────────
    await _tab(tester, 0);
    expect(_visible(find.byType(FeedScreen)), isTrue,
        reason: 'лента кушода нашуд');
    await _scroll(tester, times: 3);
    _check('лента: варақ задан');

    // Шарҳҳои пости аввал — ин ҷо матн, аватар ва вақт ҷамъ мешаванд.
    await _openThenBack(
        tester, find.byIcon(AppIcons.mode_comment_outlined),
        wait: 2000);
    _check('лента: шарҳҳо');

    // Огоҳиномаҳо — аз сари лента.
    await _openThenBack(tester, find.byType(IconButton), wait: 2000);
    _check('огоҳиномаҳо');

    // Стори — аввалин доира дар сари лента.
    final story = find.byType(GestureDetector);
    if (story.evaluate().length > 2) {
      await tester.tap(story.at(1), warnIfMissed: false);
      await _pump(tester, 2500);
      await _back(tester);
    }
    _check('стори');

    // ── 2. REELS ────────────────────────────────────────────────
    await _tab(tester, 1);
    expect(_visible(find.byType(ReelsScreen)), isTrue,
        reason: 'Reels кушода нашуд');
    // Ба реели навбатӣ — маҳз ин ҷо плеери кӯҳна бояд озод шавад.
    for (var i = 0; i < 3; i++) {
      final s = find.byType(Scrollable);
      if (s.evaluate().isEmpty) break;
      await tester.drag(s.first, const Offset(0, -600));
      await _pump(tester, 1800);
    }
    _check('Reels: гардондани се видео');

    // ── 3. ЧАТ ──────────────────────────────────────────────────
    await _tab(tester, 2);
    expect(_visible(find.byType(ChatListScreen)), isTrue,
        reason: 'чат кушода нашуд');
    await _scroll(tester);
    _check('чат: рӯйхат');

    // ── 4. ҶУСТУҶӮ ──────────────────────────────────────────────
    await _tab(tester, 3);
    expect(_visible(find.byType(SearchScreen)), isTrue,
        reason: 'ҷустуҷӯ кушода нашуд');
    await _scroll(tester); // explore-и grid
    _check('ҷустуҷӯ: explore');

    final sf = find.byType(TextField);
    if (sf.evaluate().isNotEmpty) {
      await tester.enterText(sf.first, 'a');
      await _pump(tester, 2500);
      await tester.enterText(sf.first, 'ra');
      await _pump(tester, 2500);
      await tester.enterText(sf.first, '');
      await _pump(tester, 1200);
    }
    _check('ҷустуҷӯ: навиштан ва натиҷа');

    // ── 5. ПРОФИЛ ───────────────────────────────────────────────
    await _tab(tester, 4);
    expect(_visible(find.byType(ProfileScreen)), isTrue,
        reason: 'профил кушода нашуд');
    await _scroll(tester);
    _check('профил: варақ задан');

    // ── 6. ТАНЗИМОТ ВА ҲАМАИ ЗЕРЭКРАНҲОИ ОН ─────────────────────
    //
    // Маҳз ин ҷо камбудиҳои «тугма зада мешавад, ҳеҷ чиз намешавад»
    // зиндагӣ мекунанд — экранҳое, ки касе ҳеҷ гоҳ намекушояд.
    final more = find.byType(IconButton);
    var settingsOpened = false;
    for (var i = 0; i < more.evaluate().length && i < 6; i++) {
      await tester.tap(more.at(i), warnIfMissed: false);
      await _pump(tester, 1500);
      if (find.byType(SettingsScreen).evaluate().isNotEmpty) {
        settingsOpened = true;
        break;
      }
      await _back(tester);
    }
    _check('кушодани танзимот');

    if (settingsOpened) {
      await _scroll(tester);
      // Ҳар сатри танзимот: кушода мешавад, мепӯшад.
      final tiles = find.byType(ListTile);
      final n = tiles.evaluate().length;
      for (var i = 0; i < n && i < 12; i++) {
        final t2 = find.byType(ListTile);
        if (t2.evaluate().length <= i) break;
        await tester.tap(t2.at(i), warnIfMissed: false);
        await _pump(tester, 1400);
        await _back(tester);
        _check('танзимот: сатри ${i + 1}');
      }
    }
    await _back(tester);
    await _pump(tester, 900);

    // ── 7. ГУЗАРИШИ ЗУД-ЗУД ─────────────────────────────────────
    //
    // Такрор муҳим аст: «setState баъди dispose» бори аввал
    // намебарояд.
    for (var round = 0; round < 3; round++) {
      for (final i in [0, 3, 1, 4, 2, 0]) {
        await _tab(tester, i);
      }
    }
    _check('гузариши зуд-зуд (3 давр)');

    // ── 8. ҲАМОН РОҲ ДАР ЭКРАНИ ХУРД ────────────────────────────
    //
    // Телефони арзон: 320×640 dp. Маҳз ин ҷо навори зарди
    // «BOTTOM OVERFLOWED BY … PIXELS» мебарояд.
    tester.view.physicalSize = const Size(720, 1440);
    tester.view.devicePixelRatio = 2.25;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await _pump(tester, 1200);

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
    _check('экрани хурд 320×640');

    debugPrint('✅ сессия пурра гузашт: ${_steps.join(' → ')}');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
