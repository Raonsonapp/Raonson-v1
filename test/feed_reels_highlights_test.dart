// test/feed_reels_highlights_test.dart
// Лентаи асосӣ ва актуалӣ мисли Instagram:
//   • «Рекомендуем видео Reels» — ҷойҳо (на дар паҳлӯи реклама), корт,
//     пинҳон шудан вақте холӣ/хато, «Не интересно»;
//   • видеои лента — давр задан ё як бор + «Боз тамошо кардан», садо,
//     танҳо видеои бештар намоён бозӣ мекунад;
//   • «Илова ба актуалӣ» — интихоби якчанд сторис, сана, «Минбаъд».
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_settings.dart';
import 'package:raonson/core/ads/ad_slot_layout.dart';
import 'package:raonson/core/i18n/strings.dart';
import 'package:raonson/core/music/feed_video.dart';
import 'package:raonson/feed/timeline/feed_reels_carousel.dart';
import 'package:raonson/models/reel_model.dart';
import 'package:raonson/models/user_model.dart';
import 'package:raonson/profile/archive_screen.dart';
import 'package:raonson/profile/highlight_story_picker.dart';
import 'package:raonson/profile/story_date_badge.dart';
import 'package:raonson/widgets/media_view.dart';

String _read(String p) => File(p).readAsStringSync();

ReelModel _reel(String id, {int views = 0}) => ReelModel(
      id: id,
      videoUrl: 'https://example.com/$id.mp4',
      caption: '',
      user: UserModel.fromJson({'_id': 'u-$id', 'username': 'user_$id'}),
      likesCount: 0,
      commentsCount: 0,
      viewsCount: views,
      isLiked: false,
    );

class _FakeSource implements FeedReelsSource {
  List<ReelModel> reels;
  bool fail;
  final marked = <String>[];
  _FakeSource(this.reels, {this.fail = false});

  @override
  Future<List<ReelModel>> fetch() async {
    if (fail) throw Exception('offline');
    return reels;
  }

  @override
  Future<bool> notInterested(String reelId) async {
    marked.add(reelId);
    return true;
  }
}

Future<FeedReelsController> _loaded(_FakeSource src) async {
  final c = FeedReelsController(src);
  await c.load();
  return c;
}

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

bool _adAt(int b) =>
    b >= kFeedAdLayout.first && (b - kFeedAdLayout.first) % kFeedAdLayout.every == 0;

ArchivedStory _story(String id, DateTime at, {String type = 'image'}) =>
    ArchivedStory(
        id: id,
        mediaUrl: 'https://example.com/$id.${type == 'video' ? 'mp4' : 'jpg'}',
        mediaType: type,
        createdAt: at);

/// Плиткаро ба экран меорад ва зер мекунад (рӯйхат аз поён сар мешавад).
Future<void> _tapTile(WidgetTester t, String id) async {
  final f = find.byKey(ValueKey('highlight-pick-$id'));
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pump();
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsState.instance.setLang('tj');
  });

  // ═══ 1. Ҷойҳои қатори Reels ═══════════════════════════════════════
  group('ҷойҳои «Рекомендуем видео Reels»', () {
    test('бе реклама: пеш аз пости 4, баъд ҳар 10, на зиёда аз 3', () {
      expect(feedReelsBoundaries(posts: 100, adAt: (_) => false), [4, 14, 24]);
    });

    test('ҳеҷ гоҳ дар ҷойи карти реклама (паҳлӯи ҳам) нест', () {
      final at = feedReelsBoundaries(posts: 100, adAt: _adAt);
      expect(at, [5, 15, 25]);
      for (final b in at) {
        expect(_adAt(b), isFalse, reason: 'қатор ва реклама дар ҷойи $b');
      }
    });

    test('танҳо байни постҳо — пас аз қатор ҳадди ақал як пост', () {
      expect(feedReelsBoundaries(posts: 5, adAt: _adAt), isEmpty);
      expect(feedReelsBoundaries(posts: 6, adAt: _adAt), [5]);
      expect(feedReelsBoundaries(posts: 3, adAt: (_) => false), isEmpty);
    });

    test('лента қаторро истифода мебарад, на маълумоти сохта', () {
      final src = _read('lib/feed/timeline/feed_screen.dart');
      expect(src, contains('FeedReelsCarousel('));
      expect(src, contains('feedReelsBoundaries('));
      final car = _read('lib/feed/timeline/feed_reels_carousel.dart');
      expect(car, contains("'/reels/smart'"));
      expect(car, contains('markNotInterested'));
    });
  });

  // ═══ 2. Корт ва ҳолатҳо ═══════════════════════════════════════════
  group('қатори Reels', () {
    testWidgets('сарлавҳа, кортҳо ва шумораи тамошо', (t) async {
      final c = await _loaded(_FakeSource([_reel('a', views: 1500), _reel('b'), _reel('c')]));
      await t.pumpWidget(_host(FeedReelsCarousel(controller: c, slot: 0)));
      await t.pump();
      expect(find.text(tr('feed.reelsReco')), findsOneWidget);
      expect(find.byKey(const ValueKey('feed-reel-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('feed-reel-c')), findsOneWidget);
      expect(find.text('1.5K'), findsOneWidget);
      // Корт баланд 9:16, ~0.42 васеъии экран.
      final size = t.getSize(find.byKey(const ValueKey('feed-reel-a')));
      expect(size.height / size.width, closeTo(16 / 9, 0.01));
    });

    testWidgets('холӣ → қатор умуман нест', (t) async {
      final c = await _loaded(_FakeSource([]));
      await t.pumpWidget(_host(FeedReelsCarousel(controller: c, slot: 0)));
      expect(find.text(tr('feed.reelsReco')), findsNothing);
    });

    testWidgets('офлайн/хато → қатор нест (на маълумоти сохта)', (t) async {
      final c = await _loaded(_FakeSource([_reel('a')], fail: true));
      await t.pumpWidget(_host(FeedReelsCarousel(controller: c, slot: 0)));
      expect(find.text(tr('feed.reelsReco')), findsNothing);
    });

    test('қаторҳо reels-и гуногун доранд, бе такрор', () async {
      final list = [for (var i = 0; i < 12; i++) _reel('r$i'), _reel('r0')];
      final c = await _loaded(_FakeSource(list));
      final a = c.section(0).map((r) => r.id).toList();
      final b = c.section(1).map((r) => r.id).toList();
      expect(a.length, kFeedReelsPerSection);
      expect(b, ['r8', 'r9', 'r10', 'r11']);
      expect(a.toSet().intersection(b.toSet()), isEmpty);
      expect(c.section(2), isEmpty);
    });

    testWidgets('«Не интересно» дар корт — reel меравад ва ба сервер', (t) async {
      final src = _FakeSource([_reel('a'), _reel('b')]);
      final c = await _loaded(src);
      await t.pumpWidget(_host(FeedReelsCarousel(controller: c, slot: 0)));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('feed-reel-menu-a')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('feed-reel-not-interested')));
      await t.pumpAndSettle();
      expect(src.marked, ['a']);
      expect(find.byKey(const ValueKey('feed-reel-a')), findsNothing);
      expect(find.byKey(const ValueKey('feed-reel-b')), findsOneWidget);
    });

    testWidgets('«Не интересно» дар сарлавҳа — қатор пинҳон ва нигоҳ дошта', (t) async {
      final c = await _loaded(_FakeSource([_reel('a')]));
      await t.pumpWidget(_host(FeedReelsCarousel(controller: c, slot: 0)));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('feed-reels-menu-0')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('feed-reels-hide')));
      await t.pumpAndSettle();
      expect(find.text(tr('feed.reelsReco')), findsNothing);
      // Аз нав бор кардан (мас. баъди «аз нав кашидан») — ҳанӯз пинҳон.
      final again = await _loaded(_FakeSource([_reel('a')]));
      expect(again.hidden, isTrue);
      expect(again.section(0), isEmpty);
    });

    testWidgets('320dp бо ҳарфи калон — бе overflow', (t) async {
      t.view.physicalSize = const Size(320 * 3, 640 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      final c = await _loaded(_FakeSource([_reel('a', views: 123456789), _reel('b')]));
      await t.pumpWidget(MaterialApp(
        builder: (ctx, w) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: w!),
        home: Scaffold(body: SingleChildScrollView(
            child: FeedReelsCarousel(controller: c, slot: 0))),
      ));
      await t.pump();
      expect(t.takeException(), isNull);
    });
  });

  // ═══ 3. Видеои лента ══════════════════════════════════════════════
  group('видеои лента', () {
    test('кӯтоҳ давр мезанад, дароз — як бор', () {
      expect(feedVideoShouldLoop(const Duration(seconds: 8)), isTrue);
      expect(feedVideoShouldLoop(const Duration(milliseconds: 19900)), isTrue);
      expect(feedVideoShouldLoop(const Duration(seconds: 20)), isFalse);
      expect(feedVideoShouldLoop(const Duration(minutes: 2)), isFalse);
      expect(feedVideoShouldLoop(Duration.zero), isTrue,
          reason: 'давомнокии номаълум — давр мезанад');
    });

    test('«Боз тамошо кардан» танҳо вақте видеои як-боза тамом шуд', () {
      const d = Duration(seconds: 30);
      expect(feedVideoFinished(position: d, duration: d, isPlaying: false, looping: false), isTrue);
      expect(feedVideoFinished(position: const Duration(milliseconds: 29800),
          duration: d, isPlaying: false, looping: false), isTrue);
      expect(feedVideoFinished(position: d, duration: d, isPlaying: true, looping: false), isFalse);
      expect(feedVideoFinished(position: const Duration(seconds: 10),
          duration: d, isPlaying: false, looping: false), isFalse,
          reason: 'ист (пауза) ≠ тамом');
      expect(feedVideoFinished(position: d, duration: d, isPlaying: false, looping: true), isFalse);
    });

    test('садо: танҳо фаъол, бе суруд ва соҳиби садо', () {
      expect(feedVideoVolume(muted: false, soundless: false, isOwner: true), 1.0);
      expect(feedVideoVolume(muted: true, soundless: false, isOwner: true), 0.0);
      expect(feedVideoVolume(muted: false, soundless: true, isOwner: true), 0.0,
          reason: 'суруди пост мехонад — видео хомӯш');
      expect(feedVideoVolume(muted: false, soundless: false, isOwner: false), 0.0);
    });

    test('танҳо видеои бештар намоён бозӣ мекунад', () {
      final f = FeedVideoFocus();
      f.report('a', 0.3);
      expect(f.current.value, isNull, reason: 'кам намоён');
      f.report('a', 0.7);
      f.report('b', 0.6);
      expect(f.current.value, 'a');
      f.report('b', 0.7);
      expect(f.current.value, 'a', reason: 'баробар — ҷорӣ намепарад');
      f.report('b', 0.95);
      expect(f.current.value, 'b');
      f.remove('b');
      expect(f.current.value, 'a');
      f.report('a', 0);
      expect(f.current.value, isNull);
    });

    testWidgets('пардаи «Боз тамошо кардан» ва тугмаи садо', (t) async {
      var replays = 0, taps = 0;
      await t.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(
        width: 300, height: 300,
        child: Stack(children: [
          FeedVideoReplayOverlay(onReplay: () => replays++),
          Positioned(right: 10, bottom: 10,
              child: FeedVideoSoundButton(muted: true, onTap: () => taps++)),
        ]),
      ))));
      expect(find.text(tr('feed.watchAgain')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('feed-video-sound')));
      expect(taps, 1);
      await t.tap(find.text(tr('feed.watchAgain')));
      expect(replays, 1);
    });

    test('пости суруддор садои видеоро хомӯш медорад (ду садо не)', () {
      final src = _read('lib/feed/post/post_card.dart');
      expect(src, contains('soundless: _song.isNotEmpty'));
      final mv = _read('lib/widgets/media_view.dart');
      expect(mv, contains('FeedAudio'), reason: 'ҳамон mute-и умумии лента');
      expect(mv, contains('FeedVideoFocus'));
    });
  });

  // ═══ 4. «Илова ба актуалӣ» ════════════════════════════════════════
  group('интихоби сторисҳо барои актуалӣ', () {
    test('сана: рӯз ва моҳи кӯтоҳ, танҳо вақте рӯз иваз шуд', () async {
      final d1 = DateTime(2026, 10, 3, 10), d2 = DateTime(2026, 10, 3, 22);
      expect(showStoryDateBadge(null, d1), isTrue);
      expect(showStoryDateBadge(d1, d2), isFalse);
      expect(showStoryDateBadge(d2, DateTime(2026, 10, 4, 1)), isTrue);
      await AppSettingsState.instance.setLang('ru');
      expect(shortMonthName(10), 'окт.');
      await AppSettingsState.instance.setLang('en');
      expect(shortMonthName(1), 'Jan');
      expect(formatClipDuration(const Duration(seconds: 15)), '0:15');
      expect(formatClipDuration(const Duration(seconds: 65)), '1:05');
    });

    test('аз кӯҳна ба нав', () {
      final s = sortStoriesOldestFirst([
        _story('n', DateTime(2026, 10, 5)),
        _story('o', DateTime(2026, 10, 1)),
      ]);
      expect(s.map((e) => e.id), ['o', 'n']);
    });

    testWidgets('«Минбаъд» то интихоб хомӯш; якчандто интихоб → натиҷа', (t) async {
      final stories = [
        _story('s3', DateTime(2026, 10, 4, 9)),
        _story('s1', DateTime(2026, 10, 3, 9)),
        _story('s2', DateTime(2026, 10, 3, 18), type: 'video'),
        _story('s0', DateTime(2026, 10, 2, 9)),
      ];
      HighlightDraft? result;
      await t.pumpWidget(MaterialApp(home: Builder(builder: (ctx) => Scaffold(
        body: TextButton(
          onPressed: () async {
            result = await Navigator.push<HighlightDraft>(ctx, MaterialPageRoute(
                builder: (_) => HighlightStoryPicker(
                    mode: HighlightPickMode.add,
                    exclude: const {'s0'},
                    loader: () async => stories)));
          },
          child: const Text('open'),
        ),
      ))));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text(tr('highlight.pickTitle')), findsOneWidget);

      TextButton next() => t.widget<TextButton>(
          find.byKey(const ValueKey('highlight-pick-next')));
      expect(next().onPressed, isNull, reason: 'то интихоб хомӯш');

      // Се рӯз → се нишони сана (на чор).
      expect(find.byType(StoryDateBadge), findsNWidgets(3));

      // Сториси аллакай дар актуалӣ — қулф.
      await _tapTile(t, 's0');
      await t.pump();
      expect(next().onPressed, isNull);

      await _tapTile(t, 's3');
      await _tapTile(t, 's1');
      await t.pump();
      expect(next().onPressed, isNotNull);
      // Бекор кардани интихоб.
      await _tapTile(t, 's1');
      await _tapTile(t, 's2');
      await t.pump();

      await t.tap(find.byKey(const ValueKey('highlight-pick-next')));
      await t.pumpAndSettle();
      expect(result, isNotNull);
      // Бо тартиби вақт, на тартиби зер кардан.
      expect(result!.storyIds, ['s2', 's3']);
      expect(result!.items.first.type, 'video');
      expect(result!.items.first.storyId, 's2');
    });

    testWidgets('актуалии нав: «Минбаъд» → ном ва муқова → «Тайёр»', (t) async {
      final stories = [
        _story('v', DateTime(2026, 10, 3, 9), type: 'video'),
        _story('i', DateTime(2026, 10, 3, 10)),
      ];
      HighlightDraft? result;
      await t.pumpWidget(MaterialApp(home: Builder(builder: (ctx) => Scaffold(
        body: TextButton(
          onPressed: () async {
            result = await Navigator.push<HighlightDraft>(ctx, MaterialPageRoute(
                builder: (_) => HighlightStoryPicker(loader: () async => stories)));
          },
          child: const Text('open'),
        ),
      ))));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await _tapTile(t, 'v');
      await _tapTile(t, 'i');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('highlight-pick-next')));
      await t.pumpAndSettle();
      expect(find.text(tr('highlight.newTitle')), findsOneWidget);
      TextButton done() => t.widget<TextButton>(
          find.byKey(const ValueKey('highlight-create-done')));
      expect(done().onPressed, isNull, reason: 'бе ном хомӯш');
      await t.enterText(find.byKey(const ValueKey('highlight-details-name')), 'Сафар');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('highlight-create-done')));
      await t.pumpAndSettle();
      expect(result?.title, 'Сафар');
      expect(result?.storyIds, ['v', 'i']);
      expect(result?.coverUrl, stories[1].mediaUrl, reason: 'муқова — расм, на видео');
    });

    testWidgets('холӣ → матни фаҳмо', (t) async {
      await t.pumpWidget(MaterialApp(
          home: HighlightStoryPicker(loader: () async => const [])));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('highlight-pick-empty')), findsOneWidget);
    });

    testWidgets('320dp бо ҳарфи калон — бе overflow', (t) async {
      t.view.physicalSize = const Size(320 * 3, 640 * 3);
      t.view.devicePixelRatio = 3;
      addTearDown(t.view.reset);
      await AppSettingsState.instance.setLang('ru');
      await t.pumpWidget(MaterialApp(
        builder: (ctx, w) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: w!),
        home: HighlightStoryPicker(loader: () async => [
          for (var i = 0; i < 7; i++)
            _story('x$i', DateTime(2026, 11, 20 + i), type: i.isEven ? 'image' : 'video'),
        ]),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });

    test('профил «+ Нав» галереяро намекушояд', () {
      final src = _read('lib/profile/profile_screen.dart');
      expect(src, contains('HighlightStoryPicker('));
      expect(src.contains('pickMultiImage'), isFalse);
      final archive = _read('lib/profile/archive_screen.dart');
      expect(archive, contains('StoryDateBadge('));
    });

    test('экранҳои нав матни сахти тоҷикӣ/русӣ надоранд', () {
      for (final p in [
        'lib/profile/highlight_story_picker.dart',
        'lib/profile/story_date_badge.dart',
        'lib/feed/timeline/feed_reels_carousel.dart',
      ]) {
        final code = _read(p)
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(RegExp(r"'[^'\n]*[А-Яа-яӮӯҲҳҚқҶҷҒғӢӣ][^'\n]*'").hasMatch(code), isFalse,
            reason: '$p матни бе tr() дорад');
      }
    });
  });
}
