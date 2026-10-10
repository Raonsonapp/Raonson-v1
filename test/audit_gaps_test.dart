// test/audit_gaps_test.dart
// Камбудҳои Instagram, ки дар аудит анҷом дода шуданд:
//   • шарҳҳои часпонидашуда (pin) — модел, тартиб, роҳҳои API;
//   • папкаи захира — иваз кардани ном ва баровардани пост аз папка.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_settings.dart';
import 'package:raonson/core/i18n/strings.dart';
import 'package:raonson/feed/comments/comments_screen.dart';
import 'package:raonson/models/comment_model.dart';
import 'package:raonson/models/post_model.dart';
import 'package:raonson/profile/saved_collections_screen.dart';

String _read(String p) => File(p).readAsStringSync();

CommentModel _c(String id, {bool pinned = false, String parent = ''}) =>
    CommentModel.fromJson({
      '_id': id, 'text': 't$id', 'liked': false, 'likesCount': 0,
      'createdAt': '2026-10-10T10:00:00Z', 'parentId': parent,
      'pinned': pinned,
      'user': {'_id': 'u', 'username': 'u'},
    });

PostModel _p(String id) => PostModel.fromJson({
      '_id': id, 'caption': 'c$id', 'media': <dynamic>[],
      'user': {'_id': 'u1', 'username': 'ali'},
      'createdAt': '2026-10-10T10:00:00Z',
    });

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsState.instance.setLang('tj');
  });

  group('Шарҳҳои часпонидашуда', () {
    test('модел "pinned"-ро мехонад ва copyWith нигоҳ медорад', () {
      expect(_c('1', pinned: true).pinned, isTrue);
      expect(_c('2').pinned, isFalse);
      final c = _c('3', pinned: true).copyWith(liked: true);
      expect(c.pinned, isTrue);
      expect(c.copyWith(pinned: false).pinned, isFalse);
      expect(_c('4').copyWith(text: 'нав').text, 'нав');
    });

    test('часпонидашудаҳо аввал, тартиби дигарон бетағйир', () {
      final out = sortPinnedFirst([_c('a'), _c('b', pinned: true), _c('c'), _c('d', pinned: true)]);
      expect(out.map((e) => e.id).toList(), ['b', 'd', 'a', 'c']);
    });

    test('роҳҳои API ва тугма дар меню', () {
      final src = _read('lib/feed/comments/comments_screen.dart');
      expect(src, contains("'/reels/\${widget.post.id}/comments/\${comment.id}/pin'"));
      expect(src, contains("'/comments/\${comment.id}/pin'"));
      // Танҳо соҳиби пост ва танҳо шарҳи асосӣ.
      expect(src, contains('canPin: _iOwnPost && !isReply && c.parentId.isEmpty'));
      expect(src, contains("tr('comment.pinLimit')"));
    });

    test('тарҷумаҳо дар ҳар се забон', () async {
      for (final lang in ['tj', 'ru', 'en']) {
        await AppSettingsState.instance.setLang(lang);
        for (final k in ['comment.pin', 'comment.unpin', 'comment.pinnedBy',
            'comment.pinLimit', 'collection.rename', 'collection.removeHint']) {
          expect(tr(k), isNot(k), reason: '$lang $k');
        }
        expect(tr('collection.removeFrom', {'name': 'X'}), contains('X'));
      }
    });
  });

  group('Матнҳои сахт навишташуда тарҷума шуданд', () {
    // Сатри тоҷикии дохили '...' ё "..." дар код (на дар шарҳ).
    final cyr = RegExp(r"""(['"])[^'"\n]*[Ѐ-ӿ][^'"\n]*\1""");
    for (final f in [
      'lib/feed/comments/comments_screen.dart',
      'lib/stories/story_sticker.dart',
      'lib/chat/room/chat_room_screen.dart',
      'lib/profile/saved_collections_screen.dart',
    ]) {
      test(f, () {
        final bad = <String>[];
        for (final line in _read(f).split('\n')) {
          final t = line.trim();
          if (t.startsWith('//')) continue;
          final code = line.split(' // ').first;
          if (cyr.hasMatch(code)) bad.add(t);
        }
        expect(bad, isEmpty);
      });
    }

    test('калидҳои нав дар ҳар се забон', () async {
      const keys = [
        'comment.title', 'comment.disabled', 'comment.writeHint',
        'comment.translate', 'comment.hideTranslation',
        'sticker.ended', 'sticker.answerHint', 'sticker.openLink',
        'sticker.addYoursTitle', 'sticker.noAnswers',
        'chat.translateTitle', 'chat.editTitle', 'chat.vanishOn',
      ];
      final seen = <String, Set<String>>{};
      for (final lang in ['tj', 'ru', 'en']) {
        await AppSettingsState.instance.setLang(lang);
        for (final k in keys) {
          final v = tr(k);
          expect(v, isNot(k), reason: '$lang $k');
          seen.putIfAbsent(k, () => {}).add(v);
        }
        expect(tr('comment.titleCount', {'n': 4}), contains('4'));
        expect(tr('sticker.sliderAverage', {'avg': 70, 'n': 3}), allOf(contains('70'), contains('3')));
        expect(tr('chat.scheduledFor', {'time': '12.10 09:30'}), contains('12.10 09:30'));
      }
      // Тарҷумаи русӣ/англисӣ аз тоҷикӣ фарқ мекунад.
      for (final k in keys) {
        expect(seen[k]!.length, greaterThan(1), reason: k);
      }
    });
  });

  group('Папкаи захира', () {
    testWidgets('баровардан аз папка ва иваз кардани ном', (t) async {
      final removed = <String>[];
      final renamed = <String>[];
      await t.pumpWidget(MaterialApp(home: CollectionPostsScreen(
        collection: const SavedCollection(id: 'c1', name: 'Китобҳо', count: 2),
        loader: (_) async => [_p('p1'), _p('p2')],
        renamer: (id, name) async { renamed.add('$id:$name'); return name; },
        remover: (id, pid) async { removed.add('$id:$pid'); return true; },
      )));
      await t.pumpAndSettle();
      expect(find.text('Китобҳо'), findsOneWidget);
      expect(find.byKey(const Key('collection-post-p1')), findsOneWidget);
      expect(find.byKey(const Key('collection-post-p2')), findsOneWidget);

      // Пахши дароз → «Аз папка баровардан».
      await t.longPress(find.byKey(const Key('collection-post-p1')));
      await t.pumpAndSettle();
      expect(find.text(tr('collection.removeFrom', {'name': 'Китобҳо'})), findsOneWidget);
      await t.tap(find.byKey(const Key('collection-remove-post')));
      await t.pumpAndSettle();
      expect(removed, ['c1:p1']);
      expect(find.byKey(const Key('collection-post-p1')), findsNothing);
      expect(find.byKey(const Key('collection-post-p2')), findsOneWidget);

      // Меню → иваз кардани ном.
      await t.tap(find.byKey(const Key('collection-menu')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('collection-rename')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const Key('collection-name-field')), '  Шеър  ');
      await t.tap(find.byKey(const Key('collection-name-done')));
      await t.pumpAndSettle();
      expect(renamed, ['c1:Шеър']);
      expect(find.text('Шеър'), findsOneWidget);
    });

    testWidgets('хатои сервер — пост ба папка бармегардад', (t) async {
      await t.pumpWidget(MaterialApp(home: CollectionPostsScreen(
        collection: const SavedCollection(id: 'c1', name: 'A'),
        loader: (_) async => [_p('p1')],
        remover: (_, __) async => false,
      )));
      await t.pumpAndSettle();
      await t.longPress(find.byKey(const Key('collection-post-p1')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('collection-remove-post')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('collection-post-p1')), findsOneWidget);
      expect(find.text(tr('common.failedRetry')), findsOneWidget);
    });

    test('API: PATCH ва DELETE-и пост аз папка', () {
      final src = _read('lib/profile/saved_collections_screen.dart');
      expect(src, contains(".patch('/collections/\$id'"));
      expect(src, contains(".delete('/collections/\$collectionId/posts/\$postId')"));
      expect(src, contains('onLongPress: () => _options(c)'));
    });
  });
}
