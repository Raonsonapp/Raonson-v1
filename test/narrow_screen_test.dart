import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/core/content_sync.dart';
import 'package:raonson/core/storage/offline_cache.dart';
import 'package:raonson/chat/inbox/chat_list_screen.dart';
import 'package:raonson/chat/room/message_bubble.dart';
import 'package:raonson/core/analytics/analytics_service.dart';
import 'package:raonson/feed/comments/comments_screen.dart';
import 'package:raonson/feed/post/post_detail_screen.dart';
import 'package:raonson/models/comment_model.dart';
import 'package:raonson/models/message_model.dart';
import 'package:raonson/models/user_model.dart';
import 'package:raonson/models/notification_model.dart';
import 'package:raonson/notifications/notification_item.dart';
import 'package:raonson/profile/profile_screen.dart';
import 'package:raonson/settings/settings_screen.dart';
import 'package:raonson/models/post_model.dart';
import 'package:raonson/models/reel_model.dart';
import 'package:raonson/reels/player/reel_controls.dart';
import 'package:raonson/shop/buy_sheet.dart';
import 'package:raonson/stories/story_seen_sync.dart';

// Телефони хурд (320dp) ва ҳарфи калон (1.3×) — RenderFlex overflow
// (рахи зард-сиёҳ) набояд бошад. Пост бо номи дароз, ҷой, маҳсул ва
// тахфиф — ҳамон чизҳое, ки сатрро дароз мекунанд.
PostModel _longPost() => PostModel.fromJson({
      '_id': 'narrow1',
      'caption': 'Тавсифи дароз ' * 12,
      'createdAt': '2026-10-01T02:32:47Z',
      'likesCount': 123456,
      'commentsCount': 98765,
      'sharesCount': 4321,
      'viewsCount': 1234567,
      'location': 'Душанбе, кӯчаи Рӯдакӣ, хонаи 100, қабати 12',
      'isProduct': true,
      'price': 99999.99,
      'currency': 'TJS',
      'salePct': 15,
      'productName': 'Маҳсулоти хеле дароз бо номи пурра ' * 2,
      'shopWhatsapp': '+992900000000',
      'media': [
        {'url': 'https://example.com/a.jpg', 'type': 'image'}
      ],
      'user': {
        '_id': 'u-narrow',
        'username': 'username_bisyor_daroz_baroi_sanjish_${'x' * 10}',
        'avatar': '',
        'verified': true,
      },
    });

/// Хатоҳои рендер бо ҷойи Row/Column дар код — то дар ҳисобот маълум
/// бошад, КАДОМ сатр аз экран берун баромад. [stopCapture] ҳатман пеш
/// аз `expect` даъват мешавад (flutter_test инро талаб мекунад).
late List<String> Function() stopCapture;

Future<void> _narrow(WidgetTester t) async {
  t.view.physicalSize = const Size(320 * 3, 640 * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  final errors = <String>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    final where = RegExp(r'(Row|Column|Flex):file://\S*/(lib/\S+)')
        .firstMatch(d.toString());
    errors.add('${d.exceptionAsString().split('\n').first} '
        '${where == null ? '' : '@ ${where.group(2)}'}');
  };
  stopCapture = () {
    FlutterError.onError = old;
    return errors;
  };
}

Widget _scaled(Widget child) => MaterialApp(
      builder: (c, w) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: w!),
      home: child,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OfflineCache.viewerId = () => 'me1';
    StorySeenSync.instance.clear();
    ContentSync.instance.clear();
  });

  testWidgets('пости маҳсул дар 320dp бо ҳарфи 1.3× — бе overflow', (t) async {
    await _narrow(t);
    await t.pumpWidget(_scaled(
        PostDetailScreen(posts: [_longPost()], initialIndex: 0)));
    await t.pump(const Duration(milliseconds: 300));
    expect(stopCapture(), isEmpty);
    // VisibilityDetector таймер мегузорад — дарахтро мепӯшонем.
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('варақаи «Харид» дар 320dp бо ҳарфи 1.3× — бе overflow',
      (t) async {
    await _narrow(t);
    await t.pumpWidget(_scaled(Builder(
        builder: (c) => Scaffold(body: Center(child: TextButton(
            onPressed: () => showBuySheet(c, _longPost()),
            child: const Text('buy')))))));
    await t.tap(find.text('buy'));
    await t.pumpAndSettle();
    expect(stopCapture(), isEmpty);
  });

  testWidgets('огоҳиномаҳо (ҳар навъ) дар 320dp бо ҳарфи 1.3× — бе overflow',
      (t) async {
    await _narrow(t);
    const types = [
      'like', 'comment', 'follow', 'follow_request', 'collab_invite',
      'story_mention', 'order', 'gift', 'note_reaction', 'mention',
      'contact_joined', 'thanks', 'comment_like', 'follow_accepted',
    ];
    await t.pumpWidget(_scaled(Scaffold(body: ListView(children: [
      for (final ty in types)
        NotificationItem(
          notification: NotificationModel.fromJson({
            '_id': 'n-$ty', 'type': ty, 'read': false,
            'createdAt': '2026-10-01T02:32:47Z', 'targetId': 'p1',
            'fromUser': {
              '_id': 'u1',
              'username': 'username_bisyor_daroz_baroi_sanjish_xxxxxxxx',
              'avatar': '', 'verified': true,
            },
          }),
          onTap: () {},
        ),
    ]))));
    await t.pump(const Duration(milliseconds: 300));
    expect(stopCapture(), isEmpty);
  });

  testWidgets('тугмаҳои Reels дар 320dp бо ҳарфи 1.3× — бе overflow',
      (t) async {
    await _narrow(t);
    final reel = ReelModel.fromJson({
      '_id': 'r-narrow', 'videoUrl': 'https://example.com/v.mp4',
      'caption': 'Тавсифи дароз #теги_дароз ' * 8,
      'likesCount': 1234567, 'commentsCount': 98765, 'sharesCount': 43210,
      'viewsCount': 9876543,
      'audio': {'id': 'a1', 'title': 'Суруди хеле дароз бо номи пурра ' * 2,
                'artist': 'Сарояндаи машҳур'},
      'user': {
        '_id': 'u-narrow',
        'username': 'username_bisyor_daroz_baroi_sanjish_xxxxxxxxxx',
        'avatar': '', 'verified': true,
      },
    });
    await t.pumpWidget(_scaled(Scaffold(
        backgroundColor: Colors.black,
        body: Stack(children: [
          ReelControls(reel: reel, isPlaying: true),
        ]))));
    await t.pump(const Duration(milliseconds: 300));
    expect(stopCapture(), isEmpty);
  });

  const longName = 'username_bisyor_daroz_baroi_sanjish_xxxxxxxxxx';

  testWidgets('шарҳҳо дар 320dp бо ҳарфи 1.3× — бе overflow', (t) async {
    await _narrow(t);
    final comments = [
      for (var i = 0; i < 4; i++)
        CommentModel.fromJson({
          '_id': 'c$i', 'text': 'Шарҳи дароз ' * 20, 'likesCount': 123456,
          'createdAt': '2026-10-01T02:32:47Z',
          'parentId': i.isOdd ? 'c${i - 1}' : '',
          'user': {'_id': 'u$i', 'username': longName, 'avatar': '',
                   'verified': true},
        }),
    ];
    await t.pumpWidget(_scaled(Scaffold(body: SafeArea(
        child: CommentsScreen(post: _longPost(), comments: comments)))));
    await t.pump(const Duration(milliseconds: 500));
    expect(stopCapture(), isEmpty);
  });

  testWidgets('паёмҳои чат дар 320dp бо ҳарфи 1.3× — бе overflow', (t) async {
    await _narrow(t);
    const peer = UserModel(id: 'p', username: longName, avatar: '',
        verified: true, isPrivate: false, postsCount: 0, followersCount: 0,
        followingCount: 0);
    MessageModel m(String id, bool mine, {MessageType type = MessageType.text,
        String text = ''}) => MessageModel(
          id: id, chatId: 'c', peer: peer, text: text,
          createdAt: DateTime(2026, 10, 1, 12), isMine: mine, type: type,
          editedAt: mine ? DateTime(2026, 10, 1, 12, 5) : null,
          forwarded: !mine);
    await t.pumpWidget(_scaled(Scaffold(body: ListView(children: [
      MessageBubble(message: m('1', true, text: 'Салом ' * 40)),
      MessageBubble(message: m('2', false,
          text: 'https://example.com/${'x' * 80}'), senderName: longName),
      MessageBubble(message: m('3', false, type: MessageType.call,
          text: 'video')),
      MessageBubble(message: m('4', true, type: MessageType.location,
          text: '38.5598,68.7870')),
    ]))));
    await t.pump(const Duration(milliseconds: 300));
    expect(stopCapture(), isEmpty);
  });

  testWidgets('профили бегона (номи дароз, био, линк) дар 320dp — бе overflow',
      (t) async {
    await _narrow(t);
    final now = DateTime.now().millisecondsSinceEpoch;
    final user = {
      '_id': 'uX', 'username': longName,
      'fullName': 'Номи пурраи хеле дароз барои санҷиши экран ' * 2,
      'bio': 'Био ' * 60, 'website': 'https://example.com/${'x' * 60}',
      'avatar': '', 'verified': true, 'isPrivate': false,
      'postsCount': 123456, 'followersCount': 12345678,
      'followingCount': 1234567, 'pronouns': 'ӯ/вай',
      'isFollowing': false,
      'bioSong': {'title': 'Суруди хеле дароз барои профил ' * 3,
                  'artist': 'Сарояндаи машҳур', 'artUrl': '',
                  'previewUrl': 'https://example.com/p.m4a'},
      'links': [
        {'title': 'Линки хеле дароз барои мағозаи онлайн ' * 3,
         'url': 'https://example.com/shop'},
      ],
    };
    SharedPreferences.setMockInitialValues({
      // Кэши офлайн (OfflineCache) — ба корбари ворид баста аст.
      'oc1:me1:profile:uX': jsonEncode({'t': now, 'd': user}),
      'oc1:me1:profile_posts:uX': jsonEncode({'t': now, 'd': [
        for (var i = 0; i < 6; i++) {..._longPost().toJson(), '_id': 'pp$i'},
      ]}),
    });
    await t.pumpWidget(_scaled(const ProfileScreen(userId: 'uX')));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.text(longName), findsWidgets);
    expect(stopCapture(), isEmpty);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
    AnalyticsService.instance.resetForTest(); // таймери 10-сонияи бастаи рӯйдодҳо
  });

  testWidgets('рӯйхати чатҳо дар 320dp бо ҳарфи 1.3× — бе overflow',
      (t) async {
    await _narrow(t);
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'oc1:me1:chat_inbox': jsonEncode({
        't': now.millisecondsSinceEpoch,
        'd': [
          for (var i = 0; i < 4; i++) {
            '_id': 'm$i', 'chatId': 'c$i',
            'text': 'Паёми охирини хеле дароз ' * 6,
            'createdAt': now.subtract(Duration(days: i * 3)).toIso8601String(),
            'isMine': i.isOdd, 'unreadCount': i * 37, 'muted': i == 2,
            'pinned': i == 1, 'type': i == 3 ? 'audio' : 'text',
            'peer': {'_id': 'p$i', 'username': longName, 'avatar': '',
                     'verified': true, 'fullName': 'Ном ' * 10},
          },
        ],
      }),
    });
    await t.pumpWidget(_scaled(const Scaffold(body: ChatListScreen())));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.text(longName), findsWidgets);
    expect(stopCapture(), isEmpty);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
    AnalyticsService.instance.resetForTest();
  });

  testWidgets('танзимот дар 320dp бо ҳарфи 1.3× — бе overflow', (t) async {
    await _narrow(t);
    await t.pumpWidget(_scaled(const SettingsScreen()));
    await t.pump(const Duration(milliseconds: 500));
    // То поён ғелонда мешавад — ҳамаи бахшҳо сохта шаванд.
    for (var i = 0; i < 12; i++) {
      await t.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(stopCapture(), isEmpty);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
    AnalyticsService.instance.resetForTest();
  });
}
