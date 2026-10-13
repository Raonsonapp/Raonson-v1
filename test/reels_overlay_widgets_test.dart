import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/core/i18n/strings.dart';
import 'package:raonson/models/reel_model.dart';
import 'package:raonson/reels/reels_feed/reels_screen.dart' show friendAvatarsOf;
import 'package:raonson/reels/widgets/reel_action_column.dart';
import 'package:raonson/reels/widgets/reel_info_block.dart';
import 'package:raonson/reels/widgets/reels_top_bar.dart';

// Сутуни рост, блоки поён-чап ва сарлавҳаи Reels — ЯК амалисозӣ барои
// таби Reels, Explore ва reel-и ягона. Рақамҳо дар ҳама ҷо як шакл.

Widget _dark(Widget child, {Size size = const Size(390, 800)}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: Scaffold(backgroundColor: Colors.black, body: child),
      ),
    );

String _rich(WidgetTester t) => t
    .widgetList<RichText>(find.byType(RichText))
    .map((r) => r.text.toPlainText())
    .join('\n');

ReelModel _reel(String id, String uid, String avatar) => ReelModel.fromJson({
      '_id': id,
      'videoUrl': 'https://example.com/$id.mp4',
      'caption': '',
      'likesCount': 0,
      'commentsCount': 0,
      'isLiked': false,
      'user': {'_id': uid, 'username': 'u$uid', 'avatar': avatar},
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('рақамҳо', () {
    test('0 пинҳон, дигар — шакли ягонаи барнома', () {
      expect(reelCountLabel(0), '');
      expect(reelCountLabel(null), '');
      expect(reelCountLabel(-1), '');
      expect(reelCountLabel(999), '999');
      expect(reelCountLabel(1234), '1.2K');
      expect(reelCountLabel(16900), '17K');
      expect(reelCountLabel(306000), '306K');
      expect(reelCountLabel(2500000), '2.5M');
    });

    test('лайкҳои пинҳон — калима, на рақам', () {
      expect(reelLikesLabel(50, hidden: true), tr('reels.likesWord'));
      expect(reelLikesLabel(50), '50');
      expect(reelLikesLabel(0), '');
    });
  });

  group('ReelActionColumn', () {
    testWidgets('рақам зери ҳар тугма, «0» нест, ≡ менюро мекушояд',
        (t) async {
      var liked = 0, commented = 0, shared = 0, saved = 0, more = 0;
      await t.pumpWidget(_dark(Center(
        child: ReelActionColumn(
          liked: false,
          likesLabel: reelLikesLabel(16900),
          onLike: () => liked++,
          commentsCount: 306,
          onComment: () => commented++,
          sharesCount: 0,
          onShare: () => shared++,
          saved: false,
          savesCount: 12000,
          onSave: () => saved++,
          onMore: () => more++,
        ),
      )));
      expect(find.text('17K'), findsOneWidget);
      expect(find.text('306'), findsOneWidget);
      expect(find.text('12K'), findsOneWidget);
      expect(find.text('0'), findsNothing);
      expect(find.byType(MoreLinesIcon), findsOneWidget);

      await t.tap(find.text('17K'));
      await t.tap(find.text('306'));
      await t.tap(find.byType(MoreLinesIcon));
      await t.pump(const Duration(milliseconds: 300));
      expect([liked, commented, more], [1, 1, 1]);
      expect(shared + saved, 0);
    });

    testWidgets('шарҳҳо хомӯш → тугмаи шарҳ нест', (t) async {
      await t.pumpWidget(_dark(Center(
        child: ReelActionColumn(
          liked: true,
          likesLabel: '5',
          onLike: () {},
          showComments: false,
          commentsCount: 77,
          onComment: () {},
          onShare: () {},
          saved: true,
          onSave: () {},
          onMore: () {},
        ),
      )));
      expect(find.text('77'), findsNothing);
      expect(find.byType(ReelActionButton), findsNWidgets(3));
    });
  });

  group('блоки поён-чап', () {
    test('сатри садо: «иҷрокунанда · ном», бе ном — оригинал', () {
      expect(reelMusicText(title: 'Ёр', artist: 'Шабнам', username: 'ali'),
          'Шабнам · Ёр');
      expect(reelMusicText(title: 'Ёр', artist: '', username: 'ali'), 'Ёр');
      expect(reelMusicText(title: '', artist: '', username: 'ali'),
          'ali · ${tr('audio.originalAudio')}');
      expect(reelMusicText(title: 'оригинал садо', artist: '', username: 'ali'),
          'ali · ${tr('audio.originalAudio')}');
    });

    testWidgets('тавсифи дароз: «… ещё» дар сатр, зарба — пурра', (t) async {
      final long = 'Тавсифи хеле дароз барои санҷиш ' * 10;
      await t.pumpWidget(_dark(SizedBox(
        width: 260,
        child: ReelCaption(caption: long),
      )));
      final more = tr('reels.captionMore');
      expect(_rich(t), contains(more));
      expect(_rich(t).length, lessThan(long.length));
      await t.tap(find.byType(ReelCaption));
      await t.pump();
      expect(_rich(t), isNot(contains(more)));
      expect(_rich(t), contains(long.trim()));
    });

    testWidgets('тавсифи кӯтоҳ — бе «… ещё»', (t) async {
      await t.pumpWidget(_dark(const SizedBox(
          width: 260, child: ReelCaption(caption: 'салом'))));
      expect(_rich(t), isNot(contains(tr('reels.captionMore'))));
    });

    testWidgets('320×560, ҳарфи 1.3×, номи дароз — бе overflow', (t) async {
      t.view.physicalSize = const Size(320 * 3, 560 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: w!),
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(children: [
            Positioned(
              right: 4,
              bottom: 20,
              child: ReelActionColumn(
                liked: false,
                likesLabel: reelLikesLabel(123456),
                onLike: () {},
                commentsCount: 98765,
                onComment: () {},
                sharesCount: 4321,
                onShare: () {},
                saved: false,
                onSave: () {},
                onMore: () {},
                gap: 12,
              ),
            ),
            Positioned(
              left: 14,
              right: 72,
              bottom: 18,
              child: ReelInfoBlock(
                author: ReelAuthorRow(
                  userId: 'u-long',
                  username: 'username_bisyor_daroz_${'x' * 20}',
                  avatarUrl: '',
                  verified: true,
                  onProfile: () {},
                ),
                music: ReelMusicLine(
                    title: 'Суруди хеле дароз ' * 4,
                    artist: 'Иҷрокунанда',
                    isPlaying: false),
                caption: 'Тавсиф ' * 40,
              ),
            ),
          ]),
        ),
      ));
      await t.pump();
      expect(t.takeException(), isNull);
    });
  });

  testWidgets('муаллифи обунашуда: тугма нест ва FittedBox намешиканад',
      (t) async {
    // Регрессия: FittedBox бо кӯдаки 0×0 дар эмулятор
    // «width > 0.0» assertion медод.
    await t.pumpWidget(_dark(SizedBox(
      width: 220,
      child: ReelAuthorRow(
        userId: 'u-followed',
        username: 'dust',
        avatarUrl: '',
        following: true,
        onProfile: () {},
      ),
    )));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.byType(FittedBox), findsNothing);
  });

  test('рақами захираҳо: ±1 баъди пахш, ҳеҷ гоҳ манфӣ', () {
    expect(reelSavesCount(10, savedAtLoad: false, savedNow: true), 11);
    expect(reelSavesCount(10, savedAtLoad: true, savedNow: false), 9);
    expect(reelSavesCount(10, savedAtLoad: true, savedNow: true), 10);
    expect(reelSavesCount(0, savedAtLoad: true, savedNow: false), 0);
  });

  group('сарлавҳаи Reels', () {
    testWidgets('«Дӯстон» → филтри дӯстон; аватарҳо танҳо агар бошанд',
        (t) async {
      bool? picked;
      await t.pumpWidget(_dark(Align(
        alignment: Alignment.topCenter,
        child: ReelsTopBar(
            friends: false, onSelect: (v) => picked = v, onCreate: () {}),
      )));
      expect(find.byType(StackedAvatars), findsNothing);
      expect(find.text(tr('reels.reels')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('reels-tab-friends')));
      expect(picked, isTrue);

      await t.pumpWidget(_dark(Align(
        alignment: Alignment.topCenter,
        child: ReelsTopBar(
            friends: true,
            friendAvatars: const ['a', 'b', 'c', 'd'],
            onSelect: (_) {},
            onCreate: () {}),
      )));
      expect(find.byType(StackedAvatars), findsOneWidget);
    });

    testWidgets('«Reels ˅» менюи хурд мекушояд', (t) async {
      bool? picked;
      var created = 0;
      await t.pumpWidget(_dark(Align(
        alignment: Alignment.topCenter,
        child: ReelsTopBar(
            friends: true,
            onSelect: (v) => picked = v,
            onCreate: () => created++),
      )));
      await t.tap(find.byKey(const ValueKey('reels-tab-main')));
      await t.pumpAndSettle();
      // Дар меню ҳарду интихоб ҳаст.
      expect(find.text(tr('reels.friends')), findsNWidgets(2));
      await t.tap(find.text(tr('reels.reels')).last);
      await t.pumpAndSettle();
      expect(picked, isFalse);
      await t.tap(find.byTooltip(tr('reels.addReel')));
      expect(created, 1);
    });

    test('аватарҳои дӯстон: бе худам, бе такрор, то 3', () {
      final list = [
        _reel('1', 'me', 'https://x/me.jpg'),
        _reel('2', 'a', 'https://x/a.jpg'),
        _reel('3', 'a', 'https://x/a.jpg'),
        _reel('4', 'b', ''),
        _reel('5', 'c', 'https://x/c.jpg'),
        _reel('6', 'd', 'https://x/d.jpg'),
        _reel('7', 'e', 'https://x/e.jpg'),
      ];
      expect(friendAvatarsOf(list, 'me'),
          ['https://x/a.jpg', 'https://x/c.jpg', 'https://x/d.jpg']);
      expect(friendAvatarsOf(const [], 'me'), isEmpty);
    });
  });
}
