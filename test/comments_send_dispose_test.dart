import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_config.dart';
import 'package:raonson/core/api/api_client.dart';
import 'package:raonson/core/content_sync.dart';
import 'package:raonson/core/i18n/strings.dart';
import 'package:raonson/core/storage/offline_cache.dart';
import 'package:raonson/feed/comments/comments_screen.dart';
import 'package:raonson/models/post_model.dart';

// Корбар шарҳ менависад ва варақро ПЕШ аз ҷавоби сервер мепӯшад
// (ҳолати маъмулӣ дар интернети суст). Пеш setState баъди dispose
// хато медод, catch боз setState мезад (хатои дуюм берун мерафт) ва
// шумораи шарҳҳо дар лента/Reels нав намешуд.
void main() {
  late Completer<http.Response> postReply;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OfflineCache.viewerId = () => 'me1';
    ContentSync.instance.clear();
    AppConfig.initialize(appName: 'Raonson', baseUrl: 'https://example.invalid');
    ApiClient.debugSetClient(MockClient((req) {
      if (req.method == 'POST' && req.url.path.endsWith('/comments')) {
        return postReply.future;
      }
      return Future.value(http.Response(
          jsonEncode({'comments': []}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'}));
    }));
  });

  testWidgets('шарҳ баъди пӯшидани варақ: бе хато ва рақам нав мешавад',
      (t) async {
    // Дар дохили тест (минтақаи FakeAsync) — вагарна pump онро намебинад.
    postReply = Completer<http.Response>();
    final post = PostModel.fromJson({
      '_id': 'p-dispose', 'caption': '', 'commentsCount': 5,
      'createdAt': '2026-10-01T02:32:47Z',
      'media': [{'url': 'https://example.com/a.jpg', 'type': 'image'}],
      'user': {'_id': 'owner', 'username': 'owner', 'avatar': ''},
    });
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: CommentsScreen(post: post, comments: const []))));
    await t.pump(const Duration(milliseconds: 300));

    await t.enterText(find.byType(TextField), 'салом');
    // Тугмаи «Фиристодан» акнун номи хонандаи экран дорад.
    await t.tap(find.byTooltip(tr('common.send')));
    await t.pump();

    // Варақ пӯшида шуд — ҷавоб ҳанӯз наомадааст.
    await t.pumpWidget(const SizedBox());
    postReply.complete(http.Response(
        jsonEncode({
          '_id': 'c-real', 'text': 'салом', 'createdAt': '2026-10-01T02:33:00Z',
          'user': {'_id': 'me1', 'username': 'me', 'avatar': ''},
        }),
        201,
        headers: {'content-type': 'application/json; charset=utf-8'}));
    await t.pump(const Duration(milliseconds: 100));

    expect(t.takeException(), isNull);
    expect(ContentSync.instance.get('p-dispose')?.commentsCount, 6);
  });
}
