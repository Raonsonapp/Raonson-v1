import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/analytics/analytics_service.dart';

void main() {
  final a = AnalyticsService.instance;

  setUp(() {
    a.sendOverride = null;
    a.resetForTest();
  });
  tearDown(() {
    a.sendOverride = null;
    a.resetForTest();
  });

  test('buffer accumulates events', () {
    a.logEvent('a');
    a.logEvent('b');
    a.logEvent('c');
    expect(a.bufferLength, 3);
  });

  test('buffer clears after successful flush', () async {
    a.sendOverride = (batch) async => true; // mock a successful send
    a.logEvent('x');
    a.logEvent('y');
    expect(a.bufferLength, 2);
    await a.flush();
    expect(a.bufferLength, 0);
  });
}
