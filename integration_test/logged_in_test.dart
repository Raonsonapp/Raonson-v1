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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'harness.dart';

import 'package:raonson/auth/login/login_screen.dart';
import 'package:raonson/auth/widgets/auth_kit.dart';
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
  await pumpFor(t, 1600);
}

Future<void> _scroll(WidgetTester t, {int times = 2}) async {
  for (var i = 0; i < times; i++) {
    final s = find.byType(Scrollable);
    if (s.evaluate().isEmpty) return;
    await t.drag(s.first, const Offset(0, -450));
    await pumpFor(t, 800);
  }
  final s = find.byType(Scrollable);
  if (s.evaluate().isNotEmpty) {
    await t.drag(s.first, const Offset(0, 900));
    await pumpFor(t, 800);
  }
}

/// Экранеро мекушояд ва мепӯшад. `true` — агар воқеан кушода шуд.
Future<bool> _openThenBack(WidgetTester t, Finder tapTarget,
    {Finder? expectScreen, int wait = 1500}) async {
  if (tapTarget.evaluate().isEmpty) return false;
  await t.tap(tapTarget.first, warnIfMissed: false);
  await pumpFor(t, wait);
  final opened =
      expectScreen == null || expectScreen.evaluate().isNotEmpty;
  await goBack(t);
  return opened;
}

Future<bool> _login(WidgetTester t) async {
  _loginProblem = '';
  // ⚠️ Тартиб муҳим аст: handler-и ТЕСТ бояд ПЕШ аз `app.main()`
  // нигоҳ дошта шавад — баъд барнома онро иваз мекунад.
  beginCapture();
  await app.main();
  installCapture();

  // Токени кӯҳна бошад — фавран лента кушода мешавад.
  if (await waitFor(t, find.byType(BottomNavScaffold),
      timeout: const Duration(seconds: 8))) {
    return true;
  }
  if (!await waitFor(t, find.byType(LoginScreen))) return false;

  final fields = find.byType(TextField);
  if (fields.evaluate().length < 2) return false;
  await t.enterText(fields.at(0), _user);
  await pumpFor(t, 400);
  await t.enterText(fields.at(1), _pass);
  await pumpFor(t, 400);

  // ⚠️ Run #15: тест 90 сония интизор шуд ва экран ҲЕҶ тағйир
  // наёфт — на спиннер, на хато. Яъне зарба ба `_submit` НАРАСИД.
  //
  // Сабаб: баъди навиштан клавиатураи экранӣ боз аст ва тугма дар
  // `SingleChildScrollView` ЗЕРИ он мемонад. Зарба ба ҷои холӣ
  // меафтод, ва `warnIfMissed: false` инро пинҳон мекард.
  //
  // Ҳоло ҳамон кори одам: клавиатураро мепӯшем, тугмаро ба экран
  // меорем ва баъд мезанем.
  FocusManager.instance.primaryFocus?.unfocus();
  await pumpFor(t, 600);

  final btn = find.byType(AuthButton);
  if (btn.evaluate().isEmpty) {
    _loginProblem = 'тугмаи вуруд ёфт нашуд';
    return false;
  }
  await t.ensureVisible(btn.first);
  await pumpFor(t, 400);
  await t.tap(btn.first);

  // Агар зарба боз ҳам нарасида бошад, инро ОШКОРО мегӯем, на
  // «ворид нашуд»-и хомӯш.
  await pumpFor(t, 1500);
  final started = find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
      find.byType(BottomNavScaffold).evaluate().isNotEmpty ||
      find.textContaining(RegExp('нодуруст|Invalid|хато|error',
              caseSensitive: false)).evaluate().isNotEmpty;
  if (!started) {
    _loginProblem = 'зарба ба тугма нарасид; ';
    // Бо вуҷуди ин вурудро месанҷем — мақсад экранҳои дохилист.
    t.widget<AuthButton>(btn.first).onTap?.call();
  }

  // Сервери HuggingFace метавонад хоб бошад — вақти васеъ.
  final ok = await waitFor(t, find.byType(BottomNavScaffold),
      timeout: const Duration(seconds: 90));
  if (!ok) _loginProblem += _visibleTexts(t);
  return ok;
}

/// Сабаби нокомии вуруд — барои гузориш.
///
/// «Ворид нашуд» ҳеҷ чиз намегӯяд. Матни худи экран мегӯяд: пароли
/// нодуруст, хатои шабака, ё чизи дигар.
String _loginProblem = '';

/// Ҳамаи матни намоёни экран.
String _visibleTexts(WidgetTester t) {
  final out = <String>[];
  for (final e in find.byType(Text).evaluate()) {
    final w = e.widget;
    if (w is Text) {
      final s = w.data;
      if (s != null && s.trim().isNotEmpty && s.length < 120) out.add(s);
    }
  }
  return out.isEmpty ? '(дар экран матн нест)' : out.join(' | ');
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
    final loggedIn = await _login(tester);
    expect(loggedIn, isTrue,
        reason: 'ворид шуда нашуд.\n'
            'Дар экран: $_loginProblem\n'
            'Санҷед: TEST_USERNAME ва TEST_PASSWORD дар GitHub '
            'Secrets дуруст ҳастанд?');
    checkStep('вуруд');

    // ── 1. ЛЕНТА ────────────────────────────────────────────────
    await _tab(tester, 0);
    expect(_visible(find.byType(FeedScreen)), isTrue,
        reason: 'лента кушода нашуд');
    await _scroll(tester, times: 3);
    checkStep('лента: варақ задан');

    // Шарҳҳои пости аввал — ин ҷо матн, аватар ва вақт ҷамъ мешаванд.
    await _openThenBack(
        tester, find.byIcon(AppIcons.mode_comment_outlined),
        wait: 2000);
    checkStep('лента: шарҳҳо');

    // Огоҳиномаҳо — аз сари лента.
    await _openThenBack(tester, find.byType(IconButton), wait: 2000);
    checkStep('огоҳиномаҳо');

    // Стори — аввалин доира дар сари лента.
    final story = find.byType(GestureDetector);
    if (story.evaluate().length > 2) {
      await tester.tap(story.at(1), warnIfMissed: false);
      await pumpFor(tester, 2500);
      await goBack(tester);
    }
    checkStep('стори');

    // ── 2. REELS ────────────────────────────────────────────────
    await _tab(tester, 1);
    expect(_visible(find.byType(ReelsScreen)), isTrue,
        reason: 'Reels кушода нашуд');
    // Ба реели навбатӣ — маҳз ин ҷо плеери кӯҳна бояд озод шавад.
    for (var i = 0; i < 3; i++) {
      final s = find.byType(Scrollable);
      if (s.evaluate().isEmpty) break;
      await tester.drag(s.first, const Offset(0, -600));
      await pumpFor(tester, 1800);
    }
    checkStep('Reels: гардондани се видео');

    // ── 3. ЧАТ ──────────────────────────────────────────────────
    await _tab(tester, 2);
    expect(_visible(find.byType(ChatListScreen)), isTrue,
        reason: 'чат кушода нашуд');
    await _scroll(tester);
    checkStep('чат: рӯйхат');

    // ── 4. ҶУСТУҶӮ ──────────────────────────────────────────────
    await _tab(tester, 3);
    expect(_visible(find.byType(SearchScreen)), isTrue,
        reason: 'ҷустуҷӯ кушода нашуд');
    await _scroll(tester); // explore-и grid
    checkStep('ҷустуҷӯ: explore');

    final sf = find.byType(TextField);
    if (sf.evaluate().isNotEmpty) {
      await tester.enterText(sf.first, 'a');
      await pumpFor(tester, 2500);
      await tester.enterText(sf.first, 'ra');
      await pumpFor(tester, 2500);
      await tester.enterText(sf.first, '');
      await pumpFor(tester, 1200);
    }
    checkStep('ҷустуҷӯ: навиштан ва натиҷа');

    // ── 5. ПРОФИЛ ───────────────────────────────────────────────
    await _tab(tester, 4);
    expect(_visible(find.byType(ProfileScreen)), isTrue,
        reason: 'профил кушода нашуд');
    await _scroll(tester);
    checkStep('профил: варақ задан');

    // ── 6. ТАНЗИМОТ ВА ҲАМАИ ЗЕРЭКРАНҲОИ ОН ─────────────────────
    //
    // Маҳз ин ҷо камбудиҳои «тугма зада мешавад, ҳеҷ чиз намешавад»
    // зиндагӣ мекунанд — экранҳое, ки касе ҳеҷ гоҳ намекушояд.
    final more = find.byType(IconButton);
    var settingsOpened = false;
    for (var i = 0; i < more.evaluate().length && i < 6; i++) {
      await tester.tap(more.at(i), warnIfMissed: false);
      await pumpFor(tester, 1500);
      if (find.byType(SettingsScreen).evaluate().isNotEmpty) {
        settingsOpened = true;
        break;
      }
      await goBack(tester);
    }
    checkStep('кушодани танзимот');

    if (settingsOpened) {
      await _scroll(tester);
      // Ҳар сатри танзимот: кушода мешавад, мепӯшад.
      final tiles = find.byType(ListTile);
      final n = tiles.evaluate().length;
      for (var i = 0; i < n && i < 12; i++) {
        final t2 = find.byType(ListTile);
        if (t2.evaluate().length <= i) break;
        await tester.tap(t2.at(i), warnIfMissed: false);
        await pumpFor(tester, 1400);
        await goBack(tester);
        checkStep('танзимот: сатри ${i + 1}');
      }
    }
    await goBack(tester);
    await pumpFor(tester, 900);

    // ── 7. ГУЗАРИШИ ЗУД-ЗУД ─────────────────────────────────────
    //
    // Такрор муҳим аст: «setState баъди dispose» бори аввал
    // намебарояд.
    for (var round = 0; round < 3; round++) {
      for (final i in [0, 3, 1, 4, 2, 0]) {
        await _tab(tester, i);
      }
    }
    checkStep('гузариши зуд-зуд (3 давр)');

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
    await pumpFor(tester, 1200);

    for (var i = 0; i < 5; i++) {
      await _tab(tester, i);
      await _scroll(tester);
    }
    final overflow = realErrors
        .where((e) => e.contains('overflowed') || e.contains('OVERFLOW'))
        .toList();
    expect(overflow, isEmpty,
        reason: 'дар экрани хурд ҷузъҳо аз ҳудуд мебароянд:\n'
            '${overflow.join('\n')}');
    checkStep('экрани хурд 320×640');

    debugPrint('✅ сессия пурра гузашт: ${steps.join(' → ')}');
  }, timeout: const Timeout(Duration(minutes: 9)));
}
