import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/storage/token_storage.dart';
import 'package:raonson/core/services/socket_service.dart';

void main() {
  final s = SocketService.instance;

  setUp(() => s.debugReset());
  tearDown(() => s.debugReset());

  test('schedules reconnect after unexpected disconnect', () {
    expect(s.reconnectPending, isFalse);
    s.debugTriggerDisconnect(); // simulate onError / onDone
    expect(s.reconnectPending, isTrue); // backoff timer armed
  });

  test('manual disconnect does NOT schedule reconnect', () {
    s.disconnect(); // sets manual-close + cancels any reconnect
    expect(s.reconnectPending, isFalse);
  });

  // Баъди иловаи аккаунт сокет бо token-и аккаунти КӮҲНА мемонд ва паём
  // аз номи ӯ мерафт. Акнун сокет ивази корбарро мешунавад.
  test('сокет ба ивази корбар гӯш медиҳад ва бе тасдиқи сервер «бегона» аст', () {
    final s = SocketService.instance;
    expect(TokenStorage.onUserChanged, isNotNull);
    expect(s.isFor('any-user'), isFalse,
        reason: 'то socket:ready маълум нест, ки сокет аз они кист');
  });
}
