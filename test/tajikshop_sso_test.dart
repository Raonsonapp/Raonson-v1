// test/tajikshop_sso_test.dart
//
// Як ҳисоб бо TajikShop — бе сервер:
//   • таҷзияи `raonson://sso?code=…` (оғози сард ва барномаи кушода);
//   • ҷавобҳои сервер → натиҷа (ворид / нав / link_required / тасдиқ);
//   • link_required: «бо рамзи Raonson ворид шавед» → баъди вуруд
//     пайванд бо token-и якдафъаина тасдиқ мешавад;
//   • «Ҳисобҳои пайвастшуда»: ҳолат, ҷудо кардан, пайваст кардан;
//   • «TajikShop-ро кушоед»: deep link → Play Store.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_settings.dart';
import 'package:raonson/auth/login/login_screen.dart';
import 'package:raonson/auth/sso/tajikshop_sign_in_screen.dart';
import 'package:raonson/core/links/deep_links.dart';
import 'package:raonson/core/sso/sso_deep_link_observer.dart';
import 'package:raonson/core/sso/tajikshop_sso.dart';
import 'package:raonson/settings/account_screens.dart';
import 'package:raonson/settings/connected_accounts_screen.dart';

final _code = 'dX7${'a' * 37}_kQ'; // 43 аломат, base64url

typedef _H = SsoResponse Function(Map<String, dynamic>? body);

class _Fake {
  final Map<String, _H> h;
  final calls = <String, List<Map<String, dynamic>?>>{};
  _Fake(this.h);

  Future<SsoResponse> call(
      String method, String path, Map<String, dynamic>? body) async {
    final k = '$method $path';
    calls.putIfAbsent(k, () => []).add(body);
    final f = h[k];
    return f == null ? const SsoResponse(404, {}) : f(body);
  }

  int count(String k) => calls[k]?.length ?? 0;
}

_Fake _install(Map<String, _H> h) {
  final f = _Fake(h);
  TajikshopSso.instance.repo = TajikshopSsoRepository(transport: f.call);
  return f;
}

Widget _app(Widget home, {GlobalKey<NavigatorState>? key}) => MaterialApp(
      navigatorKey: key,
      home: home,
      routes: const {},
    );

/// Хона барои тест: '/' пас аз ворид ба ин ҷо меояд.
class _Home extends StatelessWidget {
  const _Home();
  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('HOME'));
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsState.instance.setLang('tj');
    TajikshopSso.instance.debugReset();
  });

  group('таҷзияи линк', () {
    test('raonson://sso?code=… → код', () {
      expect(TajikshopSso.codeFromRoute('raonson://sso?code=$_code'), _code);
      expect(TajikshopSso.codeFromUri(Uri.parse('raonson://sso?code=$_code')),
          _code);
      // Flutter метавонад схема ва host-ро партояд.
      expect(TajikshopSso.codeFromRoute('/sso?code=$_code'), _code);
    });

    test('линкҳои дигар ва кодҳои нодуруст → null', () {
      for (final raw in [
        null,
        '',
        'raonson://sso',
        'raonson://sso?code=short',
        'raonson://sso?code=${'a' * 65}',
        'raonson://sso?code=bad%20code%20with%20spaces',
        'raonson://profile/ali',
        'tajikshop://sso?code=$_code',
        'https://evil.example/sso?code=$_code',
        '/?code=$_code',
      ]) {
        expect(TajikshopSso.codeFromRoute(raw), isNull, reason: '$raw');
      }
    });

    test('линкҳои пештара вайрон нашуданд', () {
      expect(DeepLinks.parse('raonson://profile/ali').kind,
          DeepLinkKind.profile);
      expect(DeepLinks.parse('raonson://sso?code=$_code').isValid, isFalse);
    });
  });

  group('қабати API', () {
    test('ҷавобҳо → натиҷа ва матни тоҷикӣ', () {
      SsoResult p(int st, Map<String, dynamic> b) =>
          SsoResult.parse(SsoResponse(st, b));
      final created = p(200, {
        'status': 'created',
        'needsProfileSetup': true,
        'accessToken': 'a',
        'refreshToken': 'r',
        'user': {'id': 'u1', 'username': 'ehson'},
      });
      expect(created.outcome, SsoOutcome.signedIn);
      expect(created.needsProfileSetup, isTrue);
      expect(created.created, isTrue);

      final lr = p(409, {
        'code': 'link_required',
        'email': 'a***i@mail.tj',
        'pendingToken': 'p' * 43,
        'expiresIn': 600,
      });
      expect(lr.outcome, SsoOutcome.linkRequired);
      expect(lr.maskedEmail, 'a***i@mail.tj');
      expect(lr.pendingToken.length, 43);

      expect(p(200, {'status': 'confirm_link', 'pendingToken': 'x'}).outcome,
          SsoOutcome.confirmLink);
      expect(p(200, {'status': 'linked', 'linked': true}).outcome,
          SsoOutcome.linked);

      final bad = p(401, {'code': 'invalid_code', 'message': 'x'});
      expect(bad.outcome, SsoOutcome.failed);
      expect(bad.message, 'Код нодуруст ё мӯҳлаташ гузашт');
      expect(p(503, {'code': 'sso_not_configured'}).message,
          'Пайвасти TajikShop танзим нашудааст');
    });

    test('хатои шабака → failed, на exception', () async {
      final repo = TajikshopSsoRepository(
          transport: (m, p, b) => throw Exception('offline'));
      final r = await repo.signIn(_code);
      expect(r.outcome, SsoOutcome.failed);
      expect(await repo.status(), isNull);
      final h = await repo.handoff();
      expect(h.deepLink, 'tajikshop://');
    });

    test('handoff: танҳо схемаи tajikshop кушода мешавад', () {
      final h = TajikshopHandoff.fromJson({
        'linked': true,
        'handoff': true,
        'deep_link': 'https://evil.example/x',
        'fallback': 'javascript:alert(1)',
      });
      expect(h.deepLink, 'tajikshop://');
      expect(h.fallback, TajikshopSso.playStore);
    });

    test('нияти «Пайваст кардан» як бор ва 10 дақ', () async {
      expect(await TajikshopSso.instance.consumeLinkIntent(), isFalse);
      await TajikshopSso.instance.setLinkIntent();
      expect(await TajikshopSso.instance.consumeLinkIntent(), isTrue);
      expect(await TajikshopSso.instance.consumeLinkIntent(), isFalse);
      SharedPreferences.setMockInitialValues({
        'sso_tajikshop_link_intent': DateTime.now()
            .subtract(const Duration(minutes: 11))
            .millisecondsSinceEpoch,
      });
      expect(await TajikshopSso.instance.consumeLinkIntent(), isFalse);
    });
  });

  group('экрани вуруд бо TajikShop', () {
    testWidgets('link_required → ворид шавед → пайванд тасдиқ мешавад',
        (t) async {
      final f = _install({
        'POST /auth/sso/tajikshop': (_) => const SsoResponse(409, {
              'code': 'link_required',
              'email': 'v***m@victim.tj',
              'pendingToken': 'PENDINGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
              'expiresIn': 600,
            }),
        'POST /auth/sso/tajikshop/link': (b) =>
            b?['pendingToken'] == 'PENDINGxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'
                ? const SsoResponse(200, {'status': 'linked', 'linked': true})
                : const SsoResponse(401, {'code': 'link_expired'}),
      });
      var sessions = 0;
      await t.pumpWidget(MaterialApp(
        routes: {'/': (_) => const _Home()},
        initialRoute: '/sso-test',
        onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => TajikshopSignInScreen(
                  code: _code,
                  isSignedIn: () async => false,
                  onSession: (_) async => sessions++,
                )),
      ));
      await t.pumpAndSettle();

      expect(f.calls['POST /auth/sso/tajikshop']!.single,
          {'code': _code}); // бе link — корбар ворид нест
      expect(find.text('Ин почта аллакай дар Raonson ҳаст'), findsOneWidget);
      expect(find.textContaining('v***m@victim.tj'), findsOneWidget);
      expect(sessions, 0, reason: 'бе тасдиқ сессия дода намешавад');

      await t.tap(find.byKey(const Key('sso-login-to-confirm')));
      await t.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
      final p = TajikshopSso.instance.pendingLink.value;
      expect(p, isNotNull);
      expect(p!.maskedEmail, 'v***m@victim.tj');

      // Баъди вуруди муваффақ (LoginScreen) — тасдиқ.
      final before = TajikshopSso.instance.linkChanged.value;
      final r = await TajikshopSso.instance.completePendingLink();
      expect(r!.outcome, SsoOutcome.linked);
      expect(f.count('POST /auth/sso/tajikshop/link'), 1);
      expect(TajikshopSso.instance.pendingLink.value, isNull);
      expect(TajikshopSso.instance.linkChanged.value, before + 1);
      // Дубора — чизе интизор нест.
      expect(await TajikshopSso.instance.completePendingLink(), isNull);
    });

    testWidgets('ҳисоби нав → сессия + «номи корбарро интихоб кунед»',
        (t) async {
      _install({
        'POST /auth/sso/tajikshop': (_) => const SsoResponse(200, {
              'status': 'created',
              'needsProfileSetup': true,
              'accessToken': 'acc',
              'refreshToken': 'ref',
              'user': {'id': 'u1', 'username': 'ehson_test'},
            }),
      });
      Map<String, dynamic>? saved;
      await t.pumpWidget(MaterialApp(
        routes: {'/': (_) => const _Home()},
        initialRoute: '/sso-test',
        onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => TajikshopSignInScreen(
                  code: _code,
                  isSignedIn: () async => false,
                  onSession: (b) async => saved = b,
                )),
      ));
      await t.pumpAndSettle();
      expect(saved?['accessToken'], 'acc');
      expect(find.byType(ChangeUsernameScreen), findsOneWidget);
      expect(find.textContaining('аз TajikShop сохта шуд'), findsOneWidget);
    });

    testWidgets('ворид аст → тасдиқи пайванд бо ном/почтаи пӯшида', (t) async {
      final f = _install({
        'POST /auth/sso/tajikshop': (_) => const SsoResponse(200, {
              'status': 'confirm_link',
              'pendingToken': 'CONFIRMxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx',
              'expiresIn': 600,
              'tajikshop': {'name': 'Ali V.', 'email': 'a***i@shop.tj'},
            }),
        'POST /auth/sso/tajikshop/link': (_) =>
            const SsoResponse(200, {'status': 'linked', 'linked': true}),
      });
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) => TajikshopSignInScreen(
                          code: _code, isSignedIn: () async => true))),
              child: const Text('OPEN'),
            ),
          ),
        ),
      ));
      await t.tap(find.text('OPEN'));
      await t.pumpAndSettle();
      expect(find.text('TajikShop-ро пайваст кунем?'), findsOneWidget);
      expect(find.textContaining('Ali V.'), findsOneWidget);
      expect(find.textContaining('a***i@shop.tj'), findsOneWidget);
      await t.tap(find.byKey(const Key('sso-confirm-link')));
      await t.pumpAndSettle();
      expect(f.calls['POST /auth/sso/tajikshop/link']!.single,
          {'pendingToken': 'CONFIRMxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'});
      expect(find.text('OPEN'), findsOneWidget, reason: 'ба ҷои қаблӣ баргашт');
      expect(find.text('TajikShop пайваст шуд'), findsOneWidget);
    });

    testWidgets('«Пайваст кардан» аз Танзимот → link:true', (t) async {
      final f = _install({
        'POST /auth/sso/tajikshop': (_) =>
            const SsoResponse(200, {'status': 'linked', 'linked': true}),
      });
      await TajikshopSso.instance.setLinkIntent();
      await t.pumpWidget(MaterialApp(
        routes: {'/': (_) => const _Home()},
        initialRoute: '/sso-test',
        onGenerateRoute: (_) => MaterialPageRoute(
            builder: (_) => TajikshopSignInScreen(
                code: _code, isSignedIn: () async => true)),
      ));
      await t.pumpAndSettle();
      expect(f.calls['POST /auth/sso/tajikshop']!.single,
          {'code': _code, 'link': true});
    });

    testWidgets('коди гузашта → хатои фаҳмо; ҳамон код дубора намеравад',
        (t) async {
      final f = _install({
        'POST /auth/sso/tajikshop': (_) => const SsoResponse(401, {
              'code': 'invalid_code',
              'message': 'Код нодуруст ё мӯҳлаташ гузашт'
            }),
      });
      Widget screen() => MaterialApp(
            routes: {'/': (_) => const _Home()},
            initialRoute: '/sso-test',
            onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => TajikshopSignInScreen(
                    code: _code, isSignedIn: () async => false)),
          );
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      expect(find.text('Код нодуруст ё мӯҳлаташ гузашт'), findsOneWidget);
      expect(TajikshopSso.instance.wasHandled(_code), isTrue);

      // Барнома аз нав сохта шуд (restartApp) — ҳамон линк боз омад.
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(screen());
      await t.pumpAndSettle();
      expect(f.count('POST /auth/sso/tajikshop'), 1);
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('барнома кушода аст: observer линкро мегирад', (t) async {
      _install({
        'POST /auth/sso/tajikshop': (_) =>
            const SsoResponse(401, {'code': 'invalid_code'}),
      });
      final key = GlobalKey<NavigatorState>();
      await t.pumpWidget(_app(const _Home(), key: key));
      final obs = SsoDeepLinkObserver(key);
      expect(
          await obs.didPushRouteInformation(
              RouteInformation(uri: Uri.parse('raonson://profile/ali'))),
          isFalse);
      expect(
          await obs.didPushRouteInformation(
              RouteInformation(uri: Uri.parse('raonson://sso?code=$_code'))),
          isTrue);
      await t.pumpAndSettle();
      expect(find.byType(TajikshopSignInScreen), findsOneWidget);
    });
  });

  group('экрани вуруд', () {
    testWidgets('«Бо TajikShop ворид шавед» ва банери пайванд', (t) async {
      final opened = <Uri>[];
      TajikshopSso.instance.opener = (u) async {
        opened.add(u);
        return false; // насб нашудааст → Play Store
      };
      await t.pumpWidget(const MaterialApp(home: LoginScreen()));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('sso-pending-banner')), findsNothing);

      TajikshopSso.instance.setPending('t' * 43, 'v***m@victim.tj', 600);
      await t.pump();
      expect(find.byKey(const Key('sso-pending-banner')), findsOneWidget);
      expect(find.textContaining('v***m@victim.tj'), findsOneWidget);

      await t.ensureVisible(find.byKey(const Key('sso-sign-in-with-tajikshop')));
      await t.tap(find.byKey(const Key('sso-sign-in-with-tajikshop')));
      await t.pumpAndSettle();
      expect(find.textContaining('Ба Raonson гузаред'), findsOneWidget);
      await t.tap(find.byKey(const Key('sso-open-tajikshop')));
      await t.pumpAndSettle();
      expect(opened.map((u) => u.toString()),
          ['tajikshop://', TajikshopSso.playStore]);
    });
  });

  group('Ҳисобҳои пайвастшуда', () {
    testWidgets('пайваст: ном/почтаи пӯшида → ҷудо кардан', (t) async {
      var linked = true;
      final f = _install({
        'GET /sso/tajikshop/status': (_) => SsoResponse(200, {
              'configured': true,
              'linked': linked,
              'hasPassword': true,
              'tajikshop': linked
                  ? {
                      'name': 'Ehson M.',
                      'email': 'e***n@gmail.com',
                      'linkedAt': '2026-10-01T10:00:00Z'
                    }
                  : null,
            }),
        'DELETE /sso/tajikshop/link': (_) {
          linked = false;
          return const SsoResponse(200, {'linked': false});
        },
      });
      await t.pumpWidget(const MaterialApp(home: ConnectedAccountsScreen()));
      await t.pumpAndSettle();
      expect(find.text('Ҳисобҳои пайвастшуда'), findsOneWidget);
      expect(find.text('Ehson M.'), findsOneWidget);
      expect(find.text('e***n@gmail.com'), findsOneWidget);
      expect(find.text('Пайваст'), findsOneWidget);
      expect(find.textContaining('01.10.2026'), findsOneWidget);

      await t.tap(find.byKey(const Key('sso-unlink')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('sso-unlink-confirm')));
      await t.pumpAndSettle();
      expect(f.count('DELETE /sso/tajikshop/link'), 1);
      expect(find.text('Пайваст нест'), findsOneWidget);
      expect(find.byKey(const Key('sso-link')), findsOneWidget);
    });

    testWidgets('ҳисоби бе рамз: ҷудо кардан → аввал рамз', (t) async {
      final f = _install({
        'GET /sso/tajikshop/status': (_) => const SsoResponse(200, {
              'configured': true,
              'linked': true,
              'hasPassword': false,
              'tajikshop': {'name': 'A', 'email': ''},
            }),
      });
      await t.pumpWidget(const MaterialApp(home: ConnectedAccountsScreen()));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('sso-unlink')));
      await t.pumpAndSettle();
      expect(find.textContaining('Аввал рамз гузоред'), findsOneWidget);
      expect(f.count('DELETE /sso/tajikshop/link'), 0);
    });

    testWidgets('пайваст нест: «Пайваст кардан» → TajikShop + ният',
        (t) async {
      _install({
        'GET /sso/tajikshop/status': (_) => const SsoResponse(200, {
              'configured': true,
              'linked': false,
              'hasPassword': true,
              'tajikshop': null,
            }),
      });
      final opened = <Uri>[];
      TajikshopSso.instance.opener = (u) async {
        opened.add(u);
        return true;
      };
      await t.pumpWidget(const MaterialApp(home: ConnectedAccountsScreen()));
      await t.pumpAndSettle();
      expect(find.textContaining('«Ба Raonson гузаред»'), findsWidgets);
      await t.tap(find.byKey(const Key('sso-link')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('sso-open-to-link')));
      await t.pumpAndSettle();
      expect(opened.single.toString(), 'tajikshop://');
      expect(await TajikshopSso.instance.consumeLinkIntent(), isTrue);
    });

    testWidgets('танзим нашудааст → огоҳӣ, бе тугма', (t) async {
      _install({
        'GET /sso/tajikshop/status': (_) => const SsoResponse(200, {
              'configured': false,
              'linked': false,
              'hasPassword': true,
            }),
      });
      await t.pumpWidget(const MaterialApp(home: ConnectedAccountsScreen()));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('sso-not-configured')), findsOneWidget);
      expect(find.byKey(const Key('sso-link')), findsNothing);
    });
  });

  group('«TajikShop-ро кушоед»', () {
    Future<void> openFrom(WidgetTester t) async {
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: TextButton(
                onPressed: () => openTajikshopApp(ctx),
                child: const Text('SHOP')),
          ),
        ),
      ));
      await t.tap(find.text('SHOP'));
      await t.pumpAndSettle();
    }

    testWidgets('пайваст: tajikshop://sso?code=…, насб нест → Play Store',
        (t) async {
      _install({
        'POST /sso/tajikshop/handoff': (_) => const SsoResponse(200, {
              'linked': true,
              'handoff': true,
              'deep_link': 'tajikshop://sso?code=T123',
              'fallback': TajikshopSso.playStore,
            }),
      });
      final opened = <String>[];
      TajikshopSso.instance.opener = (u) async {
        opened.add(u.toString());
        return u.scheme == 'https';
      };
      await openFrom(t);
      expect(opened, ['tajikshop://sso?code=T123', TajikshopSso.playStore]);
    });

    testWidgets('пайваст нест → пешниҳоди пайванд ё танҳо кушодан',
        (t) async {
      _install({
        'POST /sso/tajikshop/handoff': (_) => const SsoResponse(200, {
              'linked': false,
              'handoff': false,
              'deep_link': 'tajikshop://',
              'fallback': TajikshopSso.playStore,
            }),
      });
      final opened = <String>[];
      TajikshopSso.instance.opener = (u) async {
        opened.add(u.toString());
        return true;
      };
      await openFrom(t);
      expect(find.text('Ҳисоби TajikShop пайваст нест'), findsOneWidget);
      expect(opened, isEmpty);
      await t.tap(find.text('Танҳо кушодан'));
      await t.pumpAndSettle();
      expect(opened, ['tajikshop://']);
    });
  });
}
