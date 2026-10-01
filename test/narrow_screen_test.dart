import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/core/content_sync.dart';
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

Future<void> _narrow(WidgetTester t) async {
  t.view.physicalSize = const Size(320 * 3, 640 * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
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
    StorySeenSync.instance.clear();
    ContentSync.instance.clear();
  });

  testWidgets('пости маҳсул дар 320dp бо ҳарфи 1.3× — бе overflow', (t) async {
    await _narrow(t);
    await t.pumpWidget(_scaled(
        PostDetailScreen(posts: [_longPost()], initialIndex: 0)));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.takeException(), isNull);
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
    expect(t.takeException(), isNull);
  });

  testWidgets('огоҳиномаҳо (ҳар навъ) дар 320dp бо ҳарфи 1.3× — бе overflow',
      (t) async {
    await _narrow(t);
    const types = [
      'like', 'comment', 'follow', 'follow_request', 'collab_invite',
      'story_mention', 'order', 'gift', 'note_reaction', 'mention',
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
    expect(t.takeException(), isNull);
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
    expect(t.takeException(), isNull);
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
    expect(t.takeException(), isNull);
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
    expect(t.takeException(), isNull);
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
      'links': [
        {'title': 'Линки хеле дароз барои мағозаи онлайн ' * 3,
         'url': 'https://example.com/shop'},
      ],
    };
    SharedPreferences.setMockInitialValues({
      'profile_cache_uX': jsonEncode({'time': now, 'data': user}),
      'profile_posts_uX': jsonEncode({'time': now, 'data': [
        for (var i = 0; i < 6; i++) {..._longPost().toJson(), '_id': 'pp$i'},
      ]}),
    });
    await t.pumpWidget(_scaled(const ProfileScreen(userId: 'uX')));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    expect(find.text(longName), findsWidgets);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 2));
    AnalyticsService.instance.resetForTest(); // таймери 10-сонияи бастаи рӯйдодҳо
  });
}
