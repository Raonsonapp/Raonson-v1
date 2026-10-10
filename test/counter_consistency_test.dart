import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:raonson/core/content_sync.dart';
import 'package:raonson/core/local_activity.dart';
import 'package:raonson/core/services/view_tracker.dart';
import 'package:raonson/core/ui/refresh_on_return.dart';
import 'package:raonson/models/post_model.dart';
import 'package:raonson/models/reel_model.dart';
import 'package:raonson/models/user_model.dart';
import 'package:raonson/profile/profile_screen.dart';
import 'package:raonson/widgets/synced_content.dart';

// Шикояти соҳиб: «Тамошо дар Explore ва ҷустуҷӯ меафзояд, дар профил 5
// мемонад. Ҳар рақам дар ҳар тугма бояд ҳамон бошад — на зиёд, на кам».
//
// Сабаб: плиткаи reel дар профил `r.viewsCount`-и модели ҳамон лаҳзаи
// боркуниро нишон медод; таби профил дар Offstage як бор бор мешуд ва
// ContentSync (манбаи умумии лайк/шарҳ/…) тамошоро умуман надошт.
const _user = UserModel(id: 'owner', username: 'owner', avatar: '',
    verified: false, isPrivate: false, postsCount: 0, followersCount: 0,
    followingCount: 0);

ReelModel _reel(String id, int views, DateTime at) => ReelModel(
      id: id, videoUrl: 'https://x/v.mp4', caption: '', user: _user,
      likesCount: 1, commentsCount: 0, viewsCount: views, isLiked: false,
      fetchedAt: at);

PostModel _post(String id, {int likes = 0, int views = 0, DateTime? at}) =>
    PostModel(
      id: id, caption: '', media: const [], user: _user,
      likesCount: likes, commentsCount: 0, liked: false, saved: false,
      createdAt: DateTime(2026), viewsCount: views, fetchedAt: at);

void main() {
  final sync = ContentSync.instance;
  var now = DateTime(2026, 10, 10, 12);

  setUp(() {
    now = DateTime(2026, 10, 10, 12);
    sync.clock = () => now;
    sync.clear();
    SharedPreferences.setMockInitialValues({});
  });

  group('ContentSync: тамошо', () {
    test('рақами калонтар аз ҳар манбаъ қабул; куҳна паст намекунад', () {
      final t0 = now;
      sync.prime('r', viewsCount: 5, fetchedAt: t0); // профил
      sync.prime('r', viewsCount: 8, fetchedAt: t0.add(const Duration(seconds: 30))); // Explore
      expect(sync.get('r')!.viewsCount, 8);
      // Кэши диск / рӯйхати кӯҳнаи профил дубора prime мешавад.
      sync.prime('r', viewsCount: 5, fetchedAt: t0);
      expect(sync.get('r')!.viewsCount, 8);
      // Бе вақт (модели дастӣ) — паст намекунад.
      sync.prime('r', viewsCount: 5);
      expect(sync.get('r')!.viewsCount, 8);
    });

    test('камшавӣ танҳо аз маълумоти НАВТАР (масалан бинанда ҳазф шуд)', () {
      final t0 = now;
      sync.prime('r', viewsCount: 8, fetchedAt: t0);
      sync.prime('r', viewsCount: 7, fetchedAt: t0.subtract(const Duration(seconds: 1)));
      expect(sync.get('r')!.viewsCount, 8, reason: 'куҳнатар — не');
      sync.prime('r', viewsCount: 7, fetchedAt: t0.add(const Duration(seconds: 1)));
      expect(sync.get('r')!.viewsCount, 7, reason: 'навтар — ҳа');
    });

    test('ҷавоби /view рақамро фавран мегузорад ва рӯйхати пешина онро паст намекунад', () {
      final listAt = now;
      sync.prime('r', viewsCount: 5, fetchedAt: listAt);
      now = now.add(const Duration(seconds: 2));
      sync.reportViewsBody('r', '{"ok":true,"views":9,"viewsCount":9}');
      expect(sync.get('r')!.viewsCount, 9);
      // Рӯйхате, ки ПЕШ аз тамошо фиристода шуда буд, дертар расид.
      sync.prime('r', viewsCount: 5, fetchedAt: listAt);
      expect(sync.get('r')!.viewsCount, 9);
    });

    test('лайки маҳаллӣ (grace) тамошои навро аз рӯйхат бозмедорад — не', () {
      sync.report('r', liked: true, likesCount: 2);
      sync.prime('r', viewsCount: 12, likesCount: 1,
          fetchedAt: now.add(const Duration(seconds: 1)));
      final s = sync.get('r')!;
      expect(s.viewsCount, 12, reason: 'тамошо қоидаи худро дорад');
      expect(s.likesCount, 2, reason: 'лайки маҳаллӣ ҳанӯз ғолиб');
    });

    test('batch: {"views": {id: n}} → ҳар id', () {
      reportBatchViews('{"ok":true,"views":{"p1":4,"p2":7}}');
      expect(sync.get('p1')!.viewsCount, 4);
      expect(sync.get('p2')!.viewsCount, 7);
      reportBatchViews('{"ok":true}'); // сервери кӯҳна — хато намешавад
    });

    test('primeSync-и моделҳо тамошоро ҳам мефиристад', () {
      _reel('r1', 5, now).primeSync();
      _post('p1', views: 3, at: now).primeSync();
      expect(sync.get('r1')!.viewsCount, 5);
      expect(sync.get('p1')!.viewsCount, 3);
      expect(_reel('r1', 5, now).syncState.viewsCount, 5);
    });
  });

  group('Профил: плиткаҳо аз манбаи умумӣ', () {
    testWidgets('reel: профил 5 → Explore/ҷустуҷӯ 8 → профил 8 бе боркунӣ',
        (t) async {
      final loadedAt = now;
      final reel = _reel('reel-a', 5, loadedAt);
      reel.primeSync(); // ProfileController._applySnapshot / loadProfile
      await t.pumpWidget(MaterialApp(home: Scaffold(
          body: ProfileReelGrid(reels: [reel]))));
      expect(find.text('5'), findsOneWidget);

      // Explore (ё ҷустуҷӯ) рақами навро аз сервер гирифт.
      ReelModel.fromJson({
        '_id': 'reel-a', 'videoUrl': 'https://x/v.mp4', 'viewsCount': 8,
        'likesCount': 1,
        ContentSync.fetchedAtKey:
            loadedAt.add(const Duration(minutes: 1)).millisecondsSinceEpoch,
      }).primeSync();
      await t.pump();
      expect(find.text('8'), findsOneWidget);
      expect(find.text('5'), findsNothing);

      // Кэши диски профил (куҳна) дубора хонда шуд — 8 мемонад.
      _reel('reel-a', 5, loadedAt).primeSync();
      await t.pump();
      expect(find.text('8'), findsOneWidget);

      // Худи корбар reel-ро кушод → сервер 9 баргардонд.
      sync.reportViews('reel-a', 9);
      await t.pump();
      expect(find.text('9'), findsOneWidget);
    });

    testWidgets('пост: зери ЧАШМ тамошо, на лайкҳо', (t) async {
      final p = _post('post-a', likes: 2, views: 7, at: now);
      p.primeSync();
      await t.pumpWidget(MaterialApp(home: Scaffold(body: ProfilePostGrid(
          posts: [p], isMe: true, onLongPress: (_) {}))));
      expect(find.text('7'), findsOneWidget);
      expect(find.text('2'), findsNothing,
          reason: 'пеш лайкҳо зери нишони тамошо буданд');
      sync.reportViews('post-a', 11);
      await t.pump();
      expect(find.text('11'), findsOneWidget);
    });
  });

  group('Навсозӣ ҳангоми баргаштан', () {
    test('FreshnessGate: 15 сония ё амали корбар', () async {
      var t0 = DateTime(2026, 10, 10, 12);
      final g = FreshnessGate()..clock = () => t0;
      expect(g.isStale, isTrue, reason: 'ҳеҷ гоҳ бор нашудааст');
      g.markFetched();
      expect(g.isStale, isFalse);
      t0 = t0.add(const Duration(seconds: 14));
      expect(g.isStale, isFalse);
      t0 = t0.add(const Duration(seconds: 1));
      expect(g.isStale, isTrue);

      g.markFetched();
      t0 = t0.add(const Duration(seconds: 2));
      expect(g.isStale, isFalse);
      LocalActivity.bump(); // масалан обуна дар Reels
      expect(g.isStale, isTrue, reason: 'амали корбар → интизори 15с нест');

      // Навсозӣ танҳо ҳангоми муваффақият markFetched мекунад.
      var runs = 0;
      Future<void> refresh() async { runs++; g.markFetched(); }
      expect(await g.maybeRun(refresh), isTrue);
      expect(runs, 1);
      expect(await g.maybeRun(refresh), isFalse,
          reason: 'маълумот ҳанӯз нав аст');
      expect(await g.maybeRun(refresh, force: true), isTrue);
    });

    test('Профил ва Explore ба «баргаштан» пайвастанд', () {
      final profile = File('lib/profile/profile_screen.dart').readAsStringSync();
      expect(profile, contains('RefreshOnReturn<ProfileScreen>'));
      expect(profile, contains('refreshIfStale'));
      final search = File('lib/search/search_screen.dart').readAsStringSync();
      expect(search, contains('RefreshOnReturn<SearchScreen>'));
      final app = File('lib/app/app.dart').readAsStringSync();
      expect(app, contains('appRouteObserver'));
    });
  });

  group('Ҳамаи плиткаҳо тамошоро аз ContentSync мехонанд', () {
    const tiles = {
      'lib/profile/profile_screen.dart': 'профил (постҳо ва Reels)',
      'lib/search/search_screen.dart': 'Explore ва ҷустуҷӯ',
      'lib/feed/hashtag/hashtag_screen.dart': 'хештег',
      'lib/feed/location/location_screen.dart': 'ҷой',
      'lib/reels/audio/audio_page_screen.dart': 'садо',
    };
    tiles.forEach((path, name) {
      test(name, () {
        final src = File(path).readAsStringSync();
        expect(src, contains('SyncedViews('), reason: path);
        expect(src, isNot(contains('Text(_f(r.viewsCount)')), reason: path);
      });
    });

    test('ҷавоби тамошо ба ContentSync мерасад', () {
      for (final path in const [
        'lib/reels/single_reel_screen.dart',
        'lib/reels/reels_repository.dart',
        'lib/search/search_screen.dart',
      ]) {
        expect(File(path).readAsStringSync(), contains('reportViewsBody'),
            reason: path);
      }
      expect(File('lib/core/services/view_tracker.dart').readAsStringSync(),
          contains('reportBatchViews'));
    });

    test('як шакли рақам дар ҳама ҷо', () {
      expect(formatCount(999), '999');
      expect(formatCount(1000), '1K');
      expect(formatCount(1234), '1.2K');
      expect(formatCount(12345), '12K');
      expect(formatCount(1500000), '1.5M');
    });
  });
}
