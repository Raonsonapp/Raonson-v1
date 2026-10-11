import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/sso/tajikshop_sso.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TajikshopSso.instance.debugReset();
  });

  test('state is parsed from the return link', () {
    final u = Uri.parse('raonson://sso?code=${'a' * 43}&state=abcDEF_123-xyz');
    expect(TajikshopSso.codeFromUri(u), 'a' * 43);
    expect(TajikshopSso.stateFromUri(u), 'abcDEF_123-xyz');
    expect(TajikshopSso.stateFromUri(Uri.parse('raonson://sso?code=x&state=<bad>')), isNull);
  });

  test('openAuthorize stores a state that verifies exactly once', () async {
    Uri? opened;
    TajikshopSso.instance.opener = (u) async { opened = u; return true; };
    await TajikshopSso.instance.openAuthorize();
    expect(opened!.scheme, 'tajikshop');
    expect(opened!.host, 'sso');
    expect(opened!.path, '/authorize');
    expect(opened!.queryParameters['app'], 'raonson');
    final state = opened!.queryParameters['state']!;
    expect(state.length, greaterThanOrEqualTo(16));
    expect(await TajikshopSso.instance.verifyState(state), isTrue);
    expect(await TajikshopSso.instance.verifyState(state), isFalse); // як бор
  });

  test('a foreign state is rejected; a missing state is allowed', () async {
    TajikshopSso.instance.opener = (_) async => true;
    await TajikshopSso.instance.openAuthorize();
    expect(await TajikshopSso.instance.verifyState('attacker_state_123'), isFalse);
    expect(await TajikshopSso.instance.verifyState(null), isTrue);
  });

  test('state with nothing stored is rejected', () async {
    expect(await TajikshopSso.instance.verifyState('whatever_state_1'), isFalse);
  });
}
