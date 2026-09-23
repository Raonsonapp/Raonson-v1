import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/services/socket_service.dart';

// Гузариш аз экран ба экран — мисли Instagram.
//
// ═══════════════════════════════════════════════════════════════════
//  Корбар: «аз ин чат ба ин чат, аз ин рилс ба ин рилс, аз ин сторис
//  ба ин сторис — ҳама бояд кор кунад».
//
//  Се камбудӣ ёфт шуд:
//
//   1. Чат A → ақиб → фавран чат B: бастани дертари A ШУНАВАНДАҲОИ
//      B-ро пок мекард. Дар B паёмҳои нав фавран намеомаданд.
//   2. Сторияи видеоии вайрон: таймер ҳеҷ гоҳ сар намешуд — экрани
//      сиёҳи абадӣ.
//   3. Reel-и вайрон: спиннери абадӣ.
// ═══════════════════════════════════════════════════════════════════

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('1. чат → чат', () {
    final s = SocketService.instance;

    test('бастани чат A шунавандаи чат B-ро пок НАМЕКУНАД', () {
      void a(dynamic _) {}
      void b(dynamic _) {}
      s.on('test:new', a);   // чат A
      s.on('test:new', b);   // чат B кушода шуд
      s.off('test:new', a);  // A дер баста шуд
      expect(s.listenerCount('test:new'), 1,
          reason: 'бастани A шунавандаи B-ро ҳам пок кард');
      s.off('test:new', b);
      expect(s.listenerCount('test:new'), 0);
    });

    test('leaveChat ба шунавандаҳо даст намерасонад', () {
      void b(dynamic _) {}
      s.on('chat:new', b);
      s.leaveChat('chat-a');
      expect(s.listenerCount('chat:new'), 1,
          reason: 'leaveChat шунавандаи чати дигарро пок кард');
      s.off('chat:new', b);
    });

    test('экрани чат танҳо шунавандаҳои ХУДАШРО хориҷ мекунад', () {
      final room = _read('lib/chat/room/chat_room_screen.dart');
      expect(RegExp(r"_socket\.off\('chat:[a-z]+'\)").hasMatch(room), isFalse,
          reason: "`off('chat:…')` бе шунаванда боз пайдо шуд");
      expect(room, contains('_socket.off(e.key, e.value)'));
      final group = _read('lib/chat/group/group_chat_screen.dart');
      expect(group, contains("off('group:new', _onSocket)"));
    });
  });

  group('2. стори → стори', () {
    late String src;
    setUpAll(() => src = _read('lib/stories/story_group_viewer.dart'));

    test('видеои вайрон стори-ро абадан намебандад', () {
      final i = src.indexOf('void _initVideo()');
      final body = src.substring(i, i + 2200);
      expect(body, contains('.catchError('));
      expect(body, contains('_startProgress(const Duration(seconds: 3))'));
    });

    test('ҷавоби видеои кӯҳна ба видеои нав намерасад', () {
      final i = src.indexOf('void _initVideo()');
      final body = src.substring(i, i + 2200);
      expect(body, contains('_videoCtrl != c'));
    });
  });

  group('3. Reel → Reel', () {
    late String src;
    setUpAll(() => src = _read('lib/reels/reels_feed/reels_screen.dart'));

    test('видеои вайрон спиннери абадӣ намедиҳад', () {
      expect('.catchError((Object e) { _onVideoError('.allMatches(src).length,
          2, reason: 'ҳарду роҳи боркунӣ хаторо гирифта наметавонанд');
      expect(src, contains("'Видео кушода нашуд'"));
    });

    test('Reel-и вайрон ба сервер хабар медиҳад', () {
      final i = src.indexOf('void _onVideoError(');
      expect(src.substring(i, i + 600), contains('/media-check'));
    });
  });

  group('экрани обуна — ҳеҷ чизи «барои намоиш»', () {
    test('нишони «скоро» дигар нест', () {
      final s = _read('lib/subscription/subscription_screen.dart');
      expect(s.contains("tr('ui.0ba9823f99')"), isFalse,
          reason: 'функсияҳои набуда боз бо «скоро» таблиғ мешаванд');
      expect(s, contains('List<_Group> get _liveGroups'));
    });

    test('Loyalty Program ҳамчун фаъол нишон дода намешавад', () {
      final s = _read('lib/subscription/subscription_screen.dart');
      final i = s.indexOf('const Set<String> _kAvailable');
      expect(s.substring(i).contains("'Loyalty Program'"), isFalse,
          reason: 'дар ягон ҷои код вуҷуд надорад');
    });
  });
}
