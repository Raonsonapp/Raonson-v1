import 'package:flutter_test/flutter_test.dart';
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
}
