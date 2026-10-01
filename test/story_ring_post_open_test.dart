import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_theme.dart';
import 'package:raonson/core/content_sync.dart';
import 'package:raonson/feed/post/post_card.dart';
import 'package:raonson/feed/post/post_detail_screen.dart';
import 'package:raonson/models/post_model.dart';
import 'package:raonson/models/reel_model.dart';
import 'package:raonson/models/story_model.dart';
import 'package:raonson/models/user_model.dart';
import 'package:raonson/stories/story_seen_sync.dart';
import 'package:raonson/widgets/avatar.dart';

// ⚠️ Ҷавоби ВОҚЕИИ GET /posts/:id аз сервери маҳаллӣ (бо майдонҳои нави
// ҳалқа ва тамошо) — айнан ҳамон шакл, ки барнома мегирад.
const _livePost = r'''
{"_id": "88297dfe-2618-4f82-957b-98d01842496d", "caption": "шакл #тест",
 "collaboratorUsers": [], "collaborators": [], "commentsCount": 0,
 "commentsOff": false, "contactRaonson": true,
 "createdAt": "2026-10-01T02:32:47.127629Z", "currency": "TJS",
 "hideLikes": false, "isPinned": false, "isProduct": false, "liked": false,
 "likesCount": 0, "location": "",
 "media": [{"alt": "", "aspectRatio": 0, "type": "image", "url": "https://example.com/a.jpg"},
           {"alt": "", "aspectRatio": 0, "type": "video", "url": "https://example.com/b.mp4"}],
 "musicArtist": "", "musicTitle": "", "price": 0, "productName": "",
 "saved": false, "sharesCount": 0, "shopPhone": "", "shopWhatsapp": "",
 "song": null, "taggedUsers": [],
 "user": {"_id": "c8ac0944-a773-4d99-bca2-bdaf1b8b20a3", "avatar": "",
          "hasStory": true, "hasUnseenStory": true, "isFollowing": false,
          "storySeen": false, "username": "pq45769", "verified": false},
 "views": 1, "viewsCount": 1}
''';

List<Color>? _ringColors(WidgetTester t, String imageUrl) {
  // Контейнери берунии Avatar — градиенти ҳалқа дар он аст.
  final box = t.widgetList<Container>(find.descendant(
      of: find.byWidgetPredicate((w) => w is Avatar && w.imageUrl == imageUrl),
      matching: find.byType(Container))).first;
  final deco = box.decoration as BoxDecoration?;
  final g = deco?.gradient;
  return g is LinearGradient ? g.colors : null;
}

void main() {
  final sync = StorySeenSync.instance;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sync.clear();
    sync.clock = DateTime.now;
    ContentSync.instance.clear();
  });

  group('«Постҳо» кушода мешавад (пеш танҳо рахи хокистарӣ ва сиёҳ)', () {
    test('GET /posts/:id-и воқеӣ пурра хонда мешавад', () {
      final p = PostModel.fromJson(jsonDecode(_livePost) as Map<String, dynamic>);
      expect(p.id, '88297dfe-2618-4f82-957b-98d01842496d');
      expect(p.media, hasLength(2));
      expect(p.media.first['url'], 'https://example.com/a.jpg');
      expect(p.user.username, 'pq45769');
      expect(p.viewsCount, 1);
      expect(p.user.hasStory, isTrue);
      expect(p.user.hasUnseenStory, isTrue);
    });

    testWidgets(
        'PostCard вақте ContentSync аллакай ҳолати постро дорад '
        '(сабаби аслӣ: LateInitializationError дар initState)', (t) async {
      final dump = jsonDecode(
          File('test/fixtures/live/api_dump.json').readAsStringSync()) as Map;
      final posts = [
        for (final p in ((dump['user_posts'] as Map)['body'] as Map)['posts'] as List)
          PostModel.fromJson(p as Map<String, dynamic>),
        PostModel.fromJson(jsonDecode(_livePost) as Map<String, dynamic>),
      ];
      // Пост аллакай дар Home/профил дида шуда буд → ContentSync тавсиф дорад.
      for (final p in posts) {
        ContentSync.instance.report(p.id, caption: p.caption, likesCount: 3);
      }
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);

      await t.pumpWidget(MaterialApp(
          home: PostDetailScreen(posts: posts, initialIndex: 0)));
      await t.pump(const Duration(milliseconds: 300));

      expect(t.takeException(), isNull);
      expect(find.byType(ErrorWidget), findsNothing);
      expect(find.byType(PostCard), findsWidgets);
      expect(find.text(posts.first.user.username), findsWidgets);

      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
    });
  });

  group('StorySeenSync — як ҳолати ҳалқа барои ҳамаи экранҳо', () {
    const uid = 'author-1';
    StoryModel story(String id, {bool viewed = false}) => StoryModel.fromJson({
          '_id': id, 'mediaUrl': 'https://example.com/$id.jpg',
          'mediaType': 'image', 'viewed': viewed,
          'user': {'_id': uid, 'username': 'ali', 'avatar': ''},
        });

    test('майдонҳои сервер: hasUnseenStory / storySeen', () {
      final a = UserModel.fromJson(
          {'_id': 'a', 'hasStory': true, 'hasUnseenStory': false});
      expect(a.hasUnseenStory, isFalse);
      final b = UserModel.fromJson(
          {'_id': 'b', 'hasStory': true, 'storySeen': false});
      expect(b.hasUnseenStory, isTrue);
      final c = UserModel.fromJson({'_id': 'c', 'hasStory': true});
      expect(c.hasUnseenStory, isNull, reason: 'сервери кӯҳна');
    });

    test('prime → ранга; дидани ҲАМАИ сторисҳо → хокистарӣ', () {
      sync.prime(uid, hasStory: true, unseen: true, fetchedAt: DateTime.now());
      expect(sync.ringOf(uid), StoryRing.unseen);
      sync.markViewed(uid, 's1', groupIds: ['s1', 's2']);
      expect(sync.ringOf(uid), StoryRing.unseen, reason: 's2 ҳанӯз дида нашуд');
      sync.markViewed(uid, 's2', groupIds: ['s1', 's2']);
      expect(sync.ringOf(uid), StoryRing.seen);
    });

    test('ҷавоби куҳнаи сервер «дидам»-и навро бекор намекунад', () {
      final before = DateTime.now().subtract(const Duration(minutes: 1));
      sync.markViewed(uid, 's1', groupIds: ['s1']);
      sync.prime(uid, hasStory: true, unseen: true, fetchedAt: before);
      expect(sync.ringOf(uid), StoryRing.seen);
      // Кэши диск бе вақт ҳам.
      sync.prime(uid, hasStory: true, unseen: true);
      expect(sync.ringOf(uid), StoryRing.seen);
      // Ҷавоби хеле навтар (сториси нав) — боз ранга.
      sync.prime(uid, hasStory: true, unseen: true,
          fetchedAt: DateTime.now().add(const Duration(minutes: 1)));
      expect(sync.ringOf(uid), StoryRing.unseen);
    });

    test('рӯйхати сторисҳо ва сториси нав', () {
      sync.primeStories([story('a', viewed: true), story('b')]);
      expect(sync.ringOf(uid), StoryRing.unseen);
      sync.primeStories([story('a', viewed: true), story('b', viewed: true)]);
      expect(sync.ringOf(uid), StoryRing.seen);
      sync.markNewStory(uid, storyId: 'c');
      expect(sync.ringOf(uid), StoryRing.unseen);
      sync.primeStories(const [], completeFor: [uid]);
      expect(sync.ringOf(uid), StoryRing.none, reason: 'мӯҳлат гузашт');
    });

    test('модели Reel ва Post ҳалқаро ба манбаи умумӣ медиҳанд', () {
      ReelModel.fromJson({
        '_id': 'r1', 'videoUrl': 'v',
        'user': {'_id': 'ru', 'hasStory': true, 'hasUnseenStory': true},
      }).primeSync();
      expect(sync.ringOf('ru'), StoryRing.unseen);
      PostModel.fromJson({
        '_id': 'p1',
        'user': {'_id': 'ru', 'hasStory': true, 'hasUnseenStory': false},
      }).primeSync();
      expect(sync.ringOf('ru'), StoryRing.seen);
    });

    testWidgets('сарлавҳаи PostCard дар Home ҳамон лаҳза хокистарӣ мешавад',
        (t) async {
      final post = PostModel.fromJson(jsonDecode(_livePost) as Map<String, dynamic>)
          .copyWith(user: const UserModel(
              id: uid, username: 'ali', avatar: 'https://example.com/ali.jpg',
              verified: false, isPrivate: false, postsCount: 0,
              followersCount: 0, followingCount: 0,
              hasStory: true, hasUnseenStory: true));
      await t.pumpWidget(MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: PostCard(post: post)))));
      await t.pump(const Duration(milliseconds: 50));
      expect(_ringColors(t, 'https://example.com/ali.jpg'), AppColors.storyGradient);

      // Сторис дар StoryGroupViewer (аз сатри сторис, Reels ё профил) дида шуд.
      sync.markViewed(uid, 'only', groupIds: ['only']);
      await t.pump();
      expect(_ringColors(t, 'https://example.com/ali.jpg'), kStorySeenRing);

      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
    });
  });
}
