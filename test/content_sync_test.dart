import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raonson/core/content_sync.dart';
import 'package:raonson/feed/post/post_card.dart';
import 'package:raonson/models/post_model.dart';
import 'package:raonson/models/reel_model.dart';
import 'package:raonson/models/user_model.dart';

// Як пост/reel = як ҳолат дар ҳамаи экранҳо. Пеш ҳар экран нусхаи худро
// дошт: лайк дар Reels дар Explore ва профил намоён набуд.
void main() {
  final sync = ContentSync.instance;
  var now = DateTime(2026, 1, 1, 12);

  setUp(() {
    now = DateTime(2026, 1, 1, 12);
    sync.clock = () => now;
    sync.clear();
  });

  group('report', () {
    test('ҳолатро якҷоя мекунад ва хабар медиҳад', () {
      var hits = 0;
      final note = sync.watch('p1');
      void l() => hits++;
      note.addListener(l);

      sync.report('p1', liked: true, likesCount: 5);
      sync.report('p1', saved: true);

      final s = sync.get('p1')!;
      expect(s.liked, isTrue);
      expect(s.likesCount, 5);
      expect(s.saved, isTrue);
      expect(s.commentsCount, isNull, reason: 'номаълум мемонад');
      expect(hits, 2);
      expect(note.value, s);

      // Ҳамон қимат — хабари бефоида нест.
      sync.report('p1', saved: true);
      expect(hits, 2);
      note.removeListener(l);
    });

    test('-1 (лайкҳо пинҳон) рақам ҳисоб намешавад', () {
      sync.report('p1', likesCount: 3);
      sync.report('p1', likesCount: -1, hideLikes: true);
      expect(sync.get('p1')!.likesCount, 3);
      expect(sync.get('p1')!.hideLikes, isTrue);
    });

    test('id-и холӣ сабт намешавад', () {
      sync.report('', liked: true);
      expect(sync.states.value, isEmpty);
    });

    test('view: модели экран + ҳолати умумӣ', () {
      sync.report('p1', liked: true, likesCount: 8);
      final v = sync.view('p1',
          const ContentState(liked: false, likesCount: 7, commentsCount: 2));
      expect(v.liked, isTrue);
      expect(v.likesCount, 8);
      expect(v.commentsCount, 2);
    });
  });

  group('prime', () {
    test('холигиро пур мекунад', () {
      sync.prime('p1', liked: false, likesCount: 4, fetchedAt: now);
      expect(sync.get('p1')!.likesCount, 4);
    });

    test('рӯйхати ПЕШ аз амал бор шуда амалро пахш намекунад', () {
      final listLoadedAt = now; // Explore бор шуд
      now = now.add(const Duration(minutes: 1));
      sync.report('p1', liked: true, likesCount: 11); // дар Reels лайк

      // Корти Explore сохта мешавад бо маълумоти куҳна.
      sync.prime('p1', liked: false, likesCount: 10, fetchedAt: listLoadedAt);
      expect(sync.get('p1')!.liked, isTrue);
      expect(sync.get('p1')!.likesCount, 11);

      // Ҷавобе, ки ҳангоми амал дар роҳ буд (дар grace) ҳам.
      sync.prime('p1', liked: false, likesCount: 10,
          fetchedAt: now.add(const Duration(seconds: 2)));
      expect(sync.get('p1')!.liked, isTrue);
    });

    test('маълумоти навтари сервер (баъди амал) қабул мешавад', () {
      sync.report('p1', liked: true, likesCount: 11);
      final later = now.add(ContentSync.localGrace + const Duration(seconds: 1));
      sync.prime('p1', liked: true, likesCount: 15, fetchedAt: later);
      expect(sync.get('p1')!.likesCount, 15);
    });

    test('маълумоти кӯҳнатари сервер навтаринро бармегардонад — не', () {
      sync.prime('p1', likesCount: 20, fetchedAt: now);
      sync.prime('p1', likesCount: 12,
          fetchedAt: now.subtract(const Duration(minutes: 5)));
      expect(sync.get('p1')!.likesCount, 20);
    });

    test('бе fetchedAt танҳо холигиро пур мекунад', () {
      sync.prime('p1', likesCount: 3);
      expect(sync.get('p1')!.likesCount, 3);
      sync.prime('p1', likesCount: 9);
      expect(sync.get('p1')!.likesCount, 3);
    });
  });

  test('bumpComments: аз рақами маълум ё аз base', () {
    sync.bumpComments('p1', 1, base: 4);
    expect(sync.get('p1')!.commentsCount, 5);
    sync.bumpComments('p1', 1, base: 0); // base аҳамият надорад
    expect(sync.get('p1')!.commentsCount, 6);
    sync.bumpComments('p1', -10);
    expect(sync.get('p1')!.commentsCount, 0);
    sync.bumpComments('nobody', 1); // рақам номаълум — ҳеҷ чиз
    expect(sync.get('nobody'), isNull);
  });

  test('clear: ҳолат ва вақтҳо тоза, гӯшкунандагон null мегиранд', () {
    final note = sync.watch('p1');
    sync.report('p1', liked: true);
    expect(note.value, isNotNull);
    sync.clear();
    expect(sync.states.value, isEmpty);
    expect(note.value, isNull);
    // Баъди clear амали куҳна prime-ро бозмедорад — не.
    sync.prime('p1', liked: false, fetchedAt: now);
    expect(sync.get('p1')!.liked, isFalse);
  });

  group('моделҳо вақти гирифтанро медонанд', () {
    test('кэши диск вақти аслиро нигоҳ медорад', () {
      final t = DateTime(2025, 5, 5);
      final json = <String, dynamic>{'_id': 'p1', 'likesCount': 3};
      ContentSync.stamp(json, t);
      final post = PostModel.fromJson(json);
      expect(post.fetchedAt, t);
      final again = PostModel.fromJson(post.toJson());
      expect(again.fetchedAt, t, reason: 'toJson → fromJson');
      expect(ReelModel.fromJson(json).fetchedAt, t);
    });

    test('toJson пинҳонии лайкҳо ва хомӯшии шарҳҳоро гум намекунад', () {
      final post = PostModel.fromJson(const {
        '_id': 'p1', 'likesCount': 3, 'hideLikes': true,
        'commentsOff': true, 'sharesCount': 4,
      });
      final again = PostModel.fromJson(post.toJson());
      expect(again.hideLikes, isTrue);
      expect(again.commentsDisabled, isTrue);
      expect(again.sharesCount, 4);
    });

    test('primeSync ба ContentSync менависад', () {
      final reel = ReelModel.fromJson(const {
        '_id': 'r1', 'likesCount': -1, 'isLiked': true, 'commentsCount': 2,
      });
      reel.primeSync();
      final s = sync.get('r1')!;
      expect(s.liked, isTrue);
      expect(s.hideLikes, isTrue, reason: '-1 = лайкҳо пинҳон');
      expect(s.commentsCount, 2);
    });
  });

  group('PostCard ба ContentSync гӯш мекунад', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('лайк ва шарҳ аз экрани дигар фавран намоён', (t) async {
      final post = PostModel(
        id: 'post-sync', caption: '', media: const [],
        likesCount: 5, commentsCount: 2, liked: false, saved: false,
        createdAt: DateTime(2026),
        user: const UserModel(id: 'u2', username: 'ali', avatar: '',
            verified: false, isPrivate: false, postsCount: 0,
            followersCount: 0, followingCount: 0),
      );
      await t.pumpWidget(MaterialApp(
          home: Scaffold(body: SingleChildScrollView(
              child: PostCard(post: post)))));
      await t.pump();
      expect(find.text('5'), findsOneWidget);

      // Дар Reels/Explore лайк шуд ва шарҳ илова шуд.
      sync.report('post-sync', liked: true, likesCount: 6, commentsCount: 3);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('6'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Соҳиб лайкҳоро пинҳон кард → рақам намоён нест.
      sync.report('post-sync', hideLikes: true);
      await t.pump(const Duration(milliseconds: 400));
      expect(find.text('6'), findsNothing);

      // Виҷетро мебарорем ва таймерҳоро (view tracker) тамом мекунем.
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    });
  });

  group('ҷойҳо ба ContentSync пайвастанд', () {
    // Ин камбудӣ НАБУДАНИ пайваст буд — тести воҳидӣ онро намедид.
    const places = {
      'lib/feed/post/post_card.dart': 'Home (PostCard)',
      'lib/reels/reels_feed/reels_screen.dart': 'Reels',
      'lib/reels/player/reel_controls.dart': 'як reel',
      'lib/search/search_screen.dart': 'Explore',
      'lib/feed/comments/comments_screen.dart': 'шарҳҳо',
      'lib/profile/profile_screen.dart': 'профил',
    };
    places.forEach((path, name) {
      test(name, () {
        final src = File(path).readAsStringSync();
        expect(src, contains('ContentSync.instance'), reason: path);
      });
    });

    test('баромадан ва иваз кардани аккаунт тоза мекунанд', () {
      for (final path in const [
        'lib/core/services/account_manager.dart',
        'lib/core/services/user_session.dart',
      ]) {
        expect(File(path).readAsStringSync(),
            contains('ContentSync.instance.clear()'), reason: path);
      }
    });
  });
}
