import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ЧАРО ЗАНГ КОР НАМЕКАРД.
//
// Дар log-и сервер ин ҳазорҳо бор такрор мешуд:
//
//     [401] GET /ws 59µs
//     [401] GET /ws 75µs      ← ҳар ду сония, соатҳо
//
// Занг тавассути сокет меравад (`call:offer`). Агар сокет пайваст
// набошад, занг ҳеҷ ҷо намеравад. Маҳз барои ҳамин «аз даҳ бор як
// бораш» кор мекард — танҳо вақте ки сокет тасодуфан зинда буд.
//
// Ду камбудии ҷудогона ин ҳолатро месохтанд:
//
//  1. `WebSocketChannel.connect` дар Dart КОСИЛ аст: он ҳатто
//     ҳангоми 401 хато намедиҳад. Код фавран `_retry = 0` мекард —
//     яъне фосилаи такрор ҲЕҶ ГОҲ намеафзуд.
//
//  2. Токен аз ХОТИРА гирифта мешуд (`_lastToken`). Вақте он
//     мӯҳлаташ мегузашт, дархостҳои оддӣ онро нав мекарданд, вале
//     сокет ҳамон токени кӯҳнаро абадан такрор мекард.

void main() {
  late String src;
  setUpAll(() =>
      src = File('lib/core/services/socket_service.dart').readAsStringSync());

  group('пайвасти сокет', () {
    test('муваффақият танҳо баъди фрейми ҳақиқӣ тасдиқ мешавад', () {
      expect(src, contains('_handshakeOk'),
          reason: 'пайвасти РАДШУДА ҳамчун муваффақ ҳисоб мешавад');
      // `_retry = 0` бояд дар дохили коркарди фрейм бошад, на баъди
      // `connect`.
      final i = src.indexOf('_handshakeOk = true');
      expect(i, greaterThan(-1));
      expect(src.substring(i, i + 120), contains('_retry = 0'),
          reason: 'ҳисоби такрор берун аз тасдиқи пайваст сифр мешавад — '
              'фосила ҳеҷ гоҳ намеафзояд');
    });

    test('токен аз ЗАХИРА гирифта мешавад, на аз хотира', () {
      final i = src.indexOf('_reconnectTimer = Timer(');
      expect(i, greaterThan(-1));
      final body = src.substring(i, i + 1400);
      expect(body, contains('var token = await TokenStorage.getAccessToken()'),
          reason: 'токени кӯҳна абадан такрор мешавад');
      // `_lastToken` танҳо ҳамчун захира, на авлавият. Матни шарҳ
      // ҳисоб намешавад — танҳо худи код.
      expect(body, contains('token ??= _lastToken'),
          reason: '`_lastToken` авлотар аст — токени кӯҳна боз меравад');
      expect(body, isNot(contains('_lastToken ??')),
          reason: '`_lastToken` аввал санҷида мешавад');
    });

    test('баъди нокомии такрорӣ токен нав карда мешавад', () {
      expect(src, contains('_authFailures'),
          reason: 'нокомии авторизатсия аз нокомии шабака фарқ намешавад');
      expect(src, contains('refreshSession()'),
          reason: 'токен ҳеҷ гоҳ нав карда намешавад — 401 абадӣ мемонад');
    });

    test('фосилаи такрор меафзояд', () {
      // Бе ин телефон ҳар сония серверро мезанад.
      expect(src, contains('(1 << _retry)'));
      expect(src, contains('clamp(1, 30)'));
    });
  });

  group('занг ба корбари офлайн', () {
    test('сервер огоҳиномаи телефон мефиристад', () {
      final ws = File('backend/sockets/ws.go').readAsStringSync();
      expect(ws, contains('OnMissedCall'),
          reason: 'занг танҳо тавассути сокет меравад — корбари '
              'барномаашро баста ҳеҷ гоҳ намедонад');
      expect(ws, contains('!isOnline(p.To)'),
          reason: 'огоҳинома ҳатто ба корбари ОНЛАЙН меравад — '
              'ду бор хабар');
    });

    test('огоҳинома дар main васл шудааст', () {
      final main = File('backend/main_optimized.go').readAsStringSync();
      expect(main, contains('sockets.OnMissedCall = handlers.NotifyIncomingCall'),
          reason: 'callback навишта шуд, вале васл нашуд');
    });

    test('сервер сигнали «пайваст шуд» мефиристад', () {
      final ws = File('backend/sockets/ws.go').readAsStringSync();
      expect(ws, contains('socket:ready'),
          reason: 'телефон роҳи фаҳмидани пайвасти ҳақиқӣ надорад');
    });
  });
}
