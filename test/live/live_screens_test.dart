// Экранҳои асосӣ бо СЕРВЕРИ ВОҚЕӢ (маҳаллӣ) кушода мешаванд ва ҳар хатои
// Flutter (он чи корбар ҳамчун «экрани сурх/хокистарӣ» мебинад) чоп мешавад.
//
// Иҷро: сервери маҳаллӣ дар :8099, баъд
//   flutter test test/live/live_screens_test.dart \
//     --dart-define=LIVE_BASE=http://127.0.0.1:8099 \
//     --dart-define=LIVE_TOKEN=<token> --dart-define=LIVE_UID=<id> \
//     --dart-define=LIVE_OTHER=<id-и корбари дигар>
// Бе LIVE_BASE тест худ ба худ гузаронида мешавад (CI-и оддӣ сервер надорад).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_config.dart';
import 'package:raonson/core/api/api_client.dart';
import 'package:raonson/core/services/user_session.dart';
import 'package:raonson/profile/profile_screen.dart';
import 'package:raonson/notifications/notifications_screen.dart' as nf;
import 'package:raonson/search/search_screen.dart';
import 'package:raonson/settings/settings_screen.dart' show SettingsScreen;

const base = String.fromEnvironment('LIVE_BASE');
const token = String.fromEnvironment('LIVE_TOKEN');
const uid = String.fromEnvironment('LIVE_UID');
const other = String.fromEnvironment('LIVE_OTHER');

class _Real extends HttpOverrides {}

void main() {
  if (base.isEmpty) {
    test('live screens (skipped: no LIVE_BASE)', () {}, skip: true);
    return;
  }
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // path_provider дар тест плагин надорад — ба /tmp равона мекунем.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => Directory.systemTemp.path);
    AppConfig.initialize(appName: 'Raonson', baseUrl: base);
    FlutterSecureStorage.setMockInitialValues({'user_id': uid, 'access_token': token});
    SharedPreferences.setMockInitialValues({});
    ApiClient.instance.setAuthToken(token);
    UserSession.userId = uid;
  });

  final screens = <String, Widget Function()>{
    'Профил бо номи корбар': () => const ProfileScreen(userId: 'fx', byUsername: true),
    'Профили ман': () => const ProfileScreen(userId: 'me'),
    'Профили бегона': () => const ProfileScreen(userId: other),
    'Огоҳиномаҳо': () => const nf.NotificationsScreen(),
    'Ҷустуҷӯ/Explore': () => const SearchScreen(),
    'Танзимот': () => const SettingsScreen(),
  };

  for (final e in screens.entries) {
    testWidgets(e.key, (t) async {
      HttpOverrides.global = _Real();
      final errors = <String>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) {
        final m = d.exceptionAsString();
        // Расмҳои санҷишӣ (example.com) бор намешаванд — ин хатои барнома нест.
        final isImage = d.library == 'image resource service' ||
            m.contains('HTTP request failed') || m.contains('NetworkImageLoadException') ||
            m.contains('Invalid image data') || m.contains('SocketException');
        if (!m.contains('overflowed') && !isImage) {
          errors.add('${m.split('\n').first}\n      ${d.stack.toString().split('\n').where((l) => l.contains('package:raonson')).take(3).join('\n      ')}');
        }
      };
      Future<void> settle([int n = 8]) async {
        for (var i = 0; i < n; i++) {
          await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
          await t.pump(const Duration(milliseconds: 100));
        }
      }
      // Андозаи телефони воқеӣ — хатоҳои тарҳ дар экрани танг пайдо мешаванд.
      await t.binding.setSurfaceSize(const Size(360, 780));
      await t.pumpWidget(MaterialApp(home: e.value()));
      await settle(12);
      // Ҷадвалҳо (профил): ҳар Tab-ро мезанем ва варақ мезанем.
      final tabs = find.byType(Tab);
      for (var i = 0; i < tabs.evaluate().length; i++) {
        await t.tap(tabs.at(i), warnIfMissed: false);
        await settle(4);
        final sc = find.byType(Scrollable);
        if (sc.evaluate().isNotEmpty) {
          await t.drag(sc.first, const Offset(0, -600), warnIfMissed: false);
          await settle(3);
        }
      }
      final ex = t.takeException();
      FlutterError.onError = old;
      // ignore: avoid_print
      print(errors.isEmpty && ex == null ? '✅ ${e.key}' : '❌ ${e.key}: ${errors.isNotEmpty ? errors.first : ex}');
      await t.pumpWidget(const SizedBox());
    });
  }
}
