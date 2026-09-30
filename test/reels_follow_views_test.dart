// Обуна аз Reels баъди бозкушоӣ, тамошоҳо ва ишораҳои плеер.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raonson/core/services/follow_service.dart';
import 'package:raonson/models/reel_model.dart';
import 'package:raonson/navigation/bottom_nav/bottom_nav_controller.dart';
import 'package:raonson/reels/player/reel_gestures.dart';

Map<String, dynamic> _reelJson({bool following = true}) => {
      '_id': 'r1',
      'videoUrl': 'https://x/v.mp4',
      'caption': 'c',
      'likesCount': 3,
      'commentsCount': 1,
      'viewsCount': 8,
      'isLiked': false,
      'audio': {'id': 'a1', 'title': 'Суруд', 'artist': 'Ман'},
      'user': {
        '_id': 'u1',
        'username': 'shahromcoder',
        'avatar': '',
        'isFollowing': following,
        'hasStory': true,
      },
    };

void main() {
  setUp(() => FollowService.instance.clear());

  group('ReelModel кэши диск', () {
    test('toJson → fromJson обуна, сторис ва садоро нигоҳ медорад', () {
      final r = ReelModel.fromJson(_reelJson());
      final back = ReelModel.fromJson(r.toJson());
      expect(back.user.isFollowing, isTrue);
      expect(back.user.hasStory, isTrue);
      expect(back.audioId, 'a1');
      expect(back.audioTitle, 'Суруд');
      expect(back.audioArtist, 'Ман');
      expect(back.viewsCount, 8);
      expect(back.fetchedAt?.millisecondsSinceEpoch,
          r.fetchedAt?.millisecondsSinceEpoch);
    });
  });

  group('FollowService: нави сервер аз кэши куҳна бартар', () {
    test('кэши куҳна аввал, баъд ҷавоби нави сервер → ғолиб сервер', () {
      final f = FollowService.instance;
      final old = DateTime(2026, 1, 1);
      f.prime('u1', false, fetchedAt: old); // аз диск (isFollowing-и куҳна)
      expect(f.resolve('u1', false), isFalse);
      f.prime('u1', true, fetchedAt: old.add(const Duration(days: 1)));
      expect(f.resolve('u1', false), isTrue);
    });

    test('маълумоти КУҲНАТАР амали навро барнамегардонад', () {
      final f = FollowService.instance;
      f.report('u1', true); // корбар ҳозир обуна шуд
      f.prime('u1', false,
          fetchedAt: DateTime.now().subtract(const Duration(minutes: 5)));
      expect(f.resolve('u1', false), isTrue);
    });

    test('prime бе вақт — рафтори куҳна (танҳо агар номаълум)', () {
      final f = FollowService.instance;
      f.prime('u1', true);
      f.prime('u1', false);
      expect(f.resolve('u1', false), isTrue);
    });
  });

  group('scrollTopOrRefresh', () {
    testWidgets('дар мобайн → ба боло; дар боло → навсозӣ', (t) async {
      final c = ScrollController();
      var refreshed = 0;
      await t.pumpWidget(MaterialApp(
        home: ListView.builder(
          controller: c,
          itemCount: 100,
          itemBuilder: (_, i) => SizedBox(height: 80, child: Text('$i')),
        ),
      ));
      c.jumpTo(2000);
      await t.pump();
      scrollTopOrRefresh([c], () async => refreshed++);
      await t.pumpAndSettle();
      expect(c.offset, 0);
      expect(refreshed, 0);
      scrollTopOrRefresh([c], () async => refreshed++);
      await t.pumpAndSettle();
      expect(refreshed, 1);
      c.dispose();
    });
  });

  group('Тугмаи ист/бозӣ', () {
    testWidgets('нишонаи дуруст ва зарба', (t) async {
      var taps = 0;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ReelPlayPauseButton(paused: false, onTap: () => taps++),
        ),
      ));
      expect(find.bySemanticsLabel('Ист'), findsOneWidget);
      await t.tap(find.byType(ReelPlayPauseButton));
      expect(taps, 1);
    });
  });
}
