import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/models/user_model.dart';

// Лентаи «Обунаҳо / Дӯстдоштаҳо» — мисли Instagram.
String _read(String p) => File(p).readAsStringSync();

void main() {
  test('профил isFavorite-ро аз сервер мехонад', () {
    final u = UserModel.fromJson({'_id': 'u', 'username': 'x', 'isFavorite': true});
    expect(u.isFavorite, isTrue);
    expect(u.copyWith(isFavorite: false).isFavorite, isFalse);
  });

  test('сарлавҳа ҳамеша Raonson; режимҳо экрани алоҳида мекушоянд', () {
    final s = _read('lib/feed/timeline/feed_screen.dart');
    expect(s, contains('_pickFeedMode(ctx)'));
    expect(s, contains("Text('Raonson'"));
    expect(s.contains("'following' => 'Обунаҳо'"), isFalse,
        reason: 'номи Raonson дар сарлавҳа набояд иваз шавад');
    expect(s, contains('ModeFeedScreen(mode: picked)'));
    for (final m in ["'following'", "'favorites'"]) {
      expect(s, contains(m));
    }
    final m = _read('lib/feed/timeline/mode_feed_screen.dart');
    expect(m, contains('mode: widget.mode'));
  });

  test('режим ба сервер меравад ва кэши лентаи асосиро намеомезад', () {
    final r = _read('lib/feed/feed_repository.dart');
    final i = r.indexOf('if (mode.isNotEmpty) {');
    expect(i, greaterThan(0));
    final body = r.substring(i, i + 900);
    expect(body, contains("'mode': mode"));
    expect(body.contains('_memCache'), isFalse,
        reason: 'лентаи «Дӯстдоштаҳо» ба кэши лентаи асосӣ навишта шуд');
  });

  test('ҳамаи боркуниҳо режимро риоя мекунанд', () {
    final c = _read('lib/feed/timeline/feed_controller.dart');
    expect('mode: _mode'.allMatches(c).length, 4,
        reason: 'боркунӣ, давом, навсозӣ ва санҷиши пинҳонии постҳои нав');
  });

  test('профил: «Ба дӯстдоштаҳо»', () {
    final p = _read('lib/profile/profile_screen.dart');
    expect(p, contains("'/users/\${u.id}/favorite'"));
  });
}
