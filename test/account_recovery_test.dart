// test/account_recovery_test.dart
//
// «Рамзро фаромӯш кардед?» — ҷараёни пурра бе сервер:
// ёфтан → «Ин шумоед?» → рамз (6 хона, вақтшумор) → рамзи нав → ворид.
// Инчунин хатоҳои фаҳмо ва «Кӯмак лозим».
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_settings.dart';
import 'package:raonson/auth/password/forgot_password_screen.dart';
import 'package:raonson/auth/password/recovery_repository.dart';
import 'package:raonson/auth/password/recovery_status.dart';

typedef _Handler = RecoveryResponse Function(Map<String, dynamic> body);

class _FakeServer {
  final Map<String, _Handler> handlers;
  final calls = <String, List<Map<String, dynamic>>>{};
  _FakeServer(this.handlers);

  Future<RecoveryResponse> call(String path, Map<String, dynamic> body,
      {bool long = false}) async {
    calls.putIfAbsent(path, () => []).add(body);
    final h = handlers[path];
    if (h == null) return const RecoveryResponse(404, {});
    return h(body);
  }

  int count(String path) => calls[path]?.length ?? 0;
}

RecoveryResponse _ok(Map<String, dynamic> b) => RecoveryResponse(200, b);

Map<String, dynamic> _found({List<Map<String, String>>? channels}) => {
      'found': true,
      'needUsername': false,
      'account': {'username': 'al*i', 'avatar': ''},
      'channels': channels ??
          [
            {'type': 'email', 'to': 'a***i@mail.tj'}
          ],
      'canRequestHelp': true,
      'message': 'Ин шумоед?',
    };

_FakeServer _happyServer() => _FakeServer({
      RecoveryEndpoints.lookup: (_) => _ok(_found()),
      RecoveryEndpoints.send: (_) => _ok({
            'sent': true,
            'channel': 'email',
            'to': 'a***i@mail.tj',
            'resendIn': 60,
            'expiresIn': 600,
          }),
      RecoveryEndpoints.verify: (b) => b['code'] == '123456'
          ? _ok({'resetToken': 'tok-123', 'expiresIn': 900})
          : const RecoveryResponse(400, {
              'code': 'invalid_code',
              'message': 'Рамз нодуруст',
              'attemptsLeft': 4,
            }),
      RecoveryEndpoints.reset: (b) => b['token'] == 'tok-123'
          ? _ok({
              'accessToken': 'acc',
              'refreshToken': 'ref',
              'user': {'id': 'u1', 'username': 'ali'},
            })
          : const RecoveryResponse(400, {'code': 'invalid_token'}),
    });

Future<void> _pumpScreen(
  WidgetTester tester,
  _FakeServer server, {
  List<Map<String, dynamic>>? persisted,
  List<bool>? loggedIn,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: ForgotPasswordScreen(
      repository: RecoveryRepository(transport: server.call),
      persist: (data) async => persisted?.add(data),
      onLoggedIn: (_) => loggedIn?.add(true),
    ),
  ));
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pump();
  await tester.tap(find.byKey(Key(key)));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsState.instance.setLang('tj');
  });

  group('қабати API', () {
    test('lookup: «Ин шумоед?» ва каналҳо', () {
      final l = RecoveryLookup.fromJson(_found(channels: [
        {'type': 'email', 'to': 'e***n@gmail.com'},
        {'type': 'sms', 'to': '+992 *** ** 33'},
      ]));
      expect(l.found, isTrue);
      expect(l.maskedUsername, 'al*i');
      expect(l.channels.map((c) => c.type), ['email', 'sms']);
      expect(l.channels.first.to, 'e***n@gmail.com');
    });

    test('хатоҳо ба матни фаҳмо табдил меёбанд', () {
      expect(
          recoveryError(const RecoveryResponse(
                  400, {'code': 'invalid_code', 'attemptsLeft': 3}))
              .message,
          'Рамз нодуруст. 3 кӯшиш монд.');
      expect(
          recoveryError(const RecoveryResponse(400, {'code': 'invalid_code'}))
              .message,
          'Рамз нодуруст');
      expect(recoveryError(const RecoveryResponse(410, {'code': 'expired'})).message,
          'Рамз гузашт, нав фиристед');
      final cd = recoveryError(const RecoveryResponse(
          429, {'code': 'cooldown', 'retryAfter': 42, 'message': 'баъди 42 сония'}));
      expect(cd.code, 'cooldown');
      expect(cd.retryAfter, 42);
      expect(cd.message, 'баъди 42 сония');
    });

    test('хатои шабака → «Пайваст нест»', () async {
      final repo = RecoveryRepository(
          transport: (p, b, {bool long = false}) =>
              throw const SocketException('offline'));
      expect(
          () => repo.lookup('ali'),
          throwsA(isA<RecoveryException>()
              .having((e) => e.code, 'code', 'network')
              .having((e) => e.message, 'message', contains('Пайваст нест'))));
    });

    test('verify бе token — хато, на «муваффақ»', () async {
      final repo = RecoveryRepository(
          transport: (p, b, {bool long = false}) async =>
              const RecoveryResponse(200, {}));
      expect(() => repo.verify('ali', '123456'),
          throwsA(isA<RecoveryException>()));
    });

    test('санҷиши рамз', () {
      expect(checkPassword('abc').longEnough, isFalse);
      final strong = checkPassword('Raonson2026!');
      expect(strong.longEnough && strong.lettersAndDigits && strong.hasSymbol,
          isTrue);
      expect(strong.score, 3);
      expect(newPasswordError('short', 'short'), contains('8'));
      expect(newPasswordError('Raonson2026', 'Raonson2027'),
          'Рамзҳо мувофиқ нестанд');
      expect(newPasswordError('Raonson2026', 'Raonson2026'), isNull);
    });

    test('огоҳии почта: танҳо бе почтаи тасдиқшуда ва як бор', () {
      const noEmail = RecoveryStatus();
      const unverified = RecoveryStatus(email: 'a@b.tj');
      const verified = RecoveryStatus(email: 'a@b.tj', emailVerified: true);
      expect(shouldShowRecoveryBanner(noEmail, alreadyShown: false), isTrue);
      expect(shouldShowRecoveryBanner(unverified, alreadyShown: false), isTrue);
      expect(shouldShowRecoveryBanner(verified, alreadyShown: false), isFalse);
      expect(shouldShowRecoveryBanner(noEmail, alreadyShown: true), isFalse);
      expect(shouldShowRecoveryBanner(null, alreadyShown: false), isFalse);
      expect(
          RecoveryStatus.fromJson(const {
            'email': 'a@b.tj',
            'emailVerified': true,
            'hasPhone': true,
            'phoneChannels': ['sms'],
          }).needsEmail,
          isFalse);
    });
  });

  group('экран', () {
    testWidgets('ҷараёни пурра: ёфтан → рамз → рамзи нав → ворид',
        (tester) async {
      final server = _happyServer();
      final persisted = <Map<String, dynamic>>[];
      final loggedIn = <bool>[];
      await _pumpScreen(tester, server,
          persisted: persisted, loggedIn: loggedIn);

      await tester.enterText(find.byKey(const Key('recover-identifier')), ' Ali ');
      await _tap(tester, 'recover-search');
      expect(server.calls[RecoveryEndpoints.lookup]!.single['identifier'], 'Ali');

      // «Ин шумоед?»
      expect(find.text('Ин шумоед?'), findsOneWidget);
      expect(find.byKey(const Key('recover-masked-username')), findsOneWidget);
      expect(find.text('al*i'), findsOneWidget);
      expect(find.text('a***i@mail.tj'), findsOneWidget);

      await _tap(tester, 'recover-send');
      expect(server.calls[RecoveryEndpoints.send]!.single,
          {'identifier': 'Ali', 'channel': 'email'});
      expect(find.textContaining('a***i@mail.tj'), findsOneWidget);
      expect(find.text('Рамзи нав баъди 60 сония'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Рамзи нав баъди 57 сония'), findsOneWidget);

      // Рамзи нодуруст → хатои фаҳмо, хонаҳо тоза.
      await tester.enterText(find.byKey(const Key('recover-code-field')), '111111');
      await tester.pump();
      await tester.pump();
      expect(find.text('Рамз нодуруст. 4 кӯшиш монд.'), findsOneWidget);

      // Рамзи дуруст — худкор баъди 6 рақам.
      await tester.enterText(find.byKey(const Key('recover-code-field')), '123456');
      await tester.pump();
      await tester.pump();
      expect(server.count(RecoveryEndpoints.verify), 2);
      expect(find.byKey(const Key('recover-new-password')), findsOneWidget);

      // Рамзҳо мувофиқ нестанд → сервер даъват намешавад.
      await tester.enterText(
          find.byKey(const Key('recover-new-password')), 'Raonson2026!');
      await tester.enterText(
          find.byKey(const Key('recover-confirm-password')), 'Raonson2027!');
      await _tap(tester, 'recover-save');
      expect(find.text('Рамзҳо мувофиқ нестанд'), findsOneWidget);
      expect(server.count(RecoveryEndpoints.reset), 0);

      await tester.enterText(
          find.byKey(const Key('recover-confirm-password')), 'Raonson2026!');
      await _tap(tester, 'recover-save');
      expect(server.calls[RecoveryEndpoints.reset]!.single,
          {'token': 'tok-123', 'newPassword': 'Raonson2026!'});
      expect(persisted.single['accessToken'], 'acc');
      expect(loggedIn, [true]);
      expect(find.text('Рамз иваз шуд!'), findsOneWidget);
      expect(find.byKey(const Key('recover-continue')), findsOneWidget);
    });

    testWidgets('рамз гузашт → «Рамз гузашт, нав фиристед»', (tester) async {
      final server = _happyServer();
      server.handlers[RecoveryEndpoints.verify] = (_) => const RecoveryResponse(
          410, {'code': 'expired', 'message': 'Рамз гузашт, нав фиристед'});
      await _pumpScreen(tester, server);
      await tester.enterText(find.byKey(const Key('recover-identifier')), 'ali');
      await _tap(tester, 'recover-search');
      await _tap(tester, 'recover-send');
      await tester.enterText(find.byKey(const Key('recover-code-field')), '123456');
      await tester.pump();
      await tester.pump();
      expect(find.text('Рамз гузашт, нав фиристед'), findsOneWidget);
      // Рамзи нав фавран фиристода мешавад (вақтшумор бекор шуд).
      expect(find.byKey(const Key('recover-resend')), findsOneWidget);
      await _tap(tester, 'recover-resend');
      expect(server.count(RecoveryEndpoints.send), 2);
    });

    testWidgets('ҳисоб ёфт нашуд / якчанд ҳисоб / шабака', (tester) async {
      var mode = 'missing';
      final server = _FakeServer({
        RecoveryEndpoints.lookup: (_) {
          if (mode == 'missing') {
            return _ok({'found': false, 'needUsername': false, 'channels': []});
          }
          return _ok({'found': false, 'needUsername': true, 'channels': []});
        },
      });
      await _pumpScreen(tester, server);
      await tester.enterText(find.byKey(const Key('recover-identifier')), 'nest');
      await _tap(tester, 'recover-search');
      expect(find.text('Ҳисоб ёфт нашуд. Маълумотро санҷед.'), findsOneWidget);

      mode = 'ambiguous';
      await _tap(tester, 'recover-search');
      expect(find.textContaining('Номи корбарро ворид кунед'), findsOneWidget);

      server.handlers[RecoveryEndpoints.lookup] =
          (_) => throw const SocketException('offline');
      await _tap(tester, 'recover-search');
      expect(find.textContaining('Пайваст нест'), findsOneWidget);
    });

    testWidgets('бе канал → «Кӯмак лозим» → дархост', (tester) async {
      final server = _happyServer();
      server.handlers[RecoveryEndpoints.lookup] = (_) => _ok(_found(channels: []));
      server.handlers[RecoveryEndpoints.request] =
          (_) => _ok({'submitted': true, 'alreadyPending': false});
      await _pumpScreen(tester, server);
      await tester.enterText(find.byKey(const Key('recover-identifier')), 'ali');
      await _tap(tester, 'recover-search');
      expect(find.byKey(const Key('recover-no-channel')), findsOneWidget);
      expect(find.byKey(const Key('recover-send')), findsNothing);

      await _tap(tester, 'recover-help');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('help-identifier')), findsOneWidget);
      // Идентификатор аз қадами пешина пур шудааст.
      expect(find.text('ali'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('help-name')), 'Алӣ Валиев');
      await tester.enterText(find.byKey(const Key('help-email')), 'nodurust');
      await _tap(tester, 'help-submit');
      expect(server.count(RecoveryEndpoints.request), 0);
      expect(find.byKey(const Key('recover-error')), findsOneWidget);

      await tester.enterText(find.byKey(const Key('help-email')), 'ali.new@mail.tj');
      await tester.enterText(find.byKey(const Key('help-message')), 'телефонро гум кардам');
      await _tap(tester, 'help-submit');
      expect(server.calls[RecoveryEndpoints.request]!.single, {
        'identifier': 'ali',
        'contactEmail': 'ali.new@mail.tj',
        'fullName': 'Алӣ Валиев',
        'message': 'телефонро гум кардам',
      });
      expect(find.byKey(const Key('help-sent')), findsOneWidget);
      expect(find.textContaining('ali.new@mail.tj'), findsOneWidget);
    });
  });
}
