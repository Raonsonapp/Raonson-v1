import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_config.dart';
import 'package:raonson/chat/chat_repository.dart';
import 'package:raonson/chat/inbox/chat_list_controller.dart';
import 'package:raonson/chat/inbox/chat_list_screen.dart';
import 'package:raonson/core/analytics/analytics_service.dart';
import 'package:raonson/core/api/api_client.dart';
import 'package:raonson/core/content_sync.dart';
import 'package:raonson/core/error/friendly_error.dart';
import 'package:raonson/core/storage/offline_cache.dart';
import 'package:raonson/models/message_model.dart';
import 'package:raonson/models/user_model.dart';
import 'package:raonson/profile/profile_screen.dart';
import 'package:raonson/stories/story_seen_sync.dart';

// Бе интернет ё бо интернети суст барнома маълумоти ОХИРИНро нишон
// медиҳад (мисли Instagram/Telegram) ва ҳеҷ гоҳ матни хоми хато
// (`TimeoutException after 0:00:08.000000: Future not completed`) намебарояд.

const _timeoutText = 'TimeoutException after 0:00:08.000000: Future not completed';

/// Шабакае, ки ҳеҷ гоҳ дар вақташ ҷавоб намедиҳад.
http.Client _timeoutClient() => MockClient((_) async =>
    throw TimeoutException('Future not completed', const Duration(seconds: 8)));

UserModel _peer(String id) => UserModel(
      id: id, username: 'peer_$id', avatar: '', verified: false,
      isPrivate: false, postsCount: 0, followersCount: 0, followingCount: 0,
    );

MessageModel _row(String chatId) => MessageModel(
      id: 'last_$chatId', chatId: chatId, peer: _peer(chatId), text: 'салом',
      createdAt: DateTime(2026), isMine: false,
    );

/// Repository-и сохта: кэш ҳаст (ё нест), шабака ҳамеша меафтад.
class _OfflineChatRepo extends ChatRepository {
  final List<MessageModel>? cached;
  _OfflineChatRepo(this.cached);

  @override
  Future<List<MessageModel>?> loadCachedInbox() async => cached;

  @override
  Future<({List<MessageModel> chats, int? totalUnread})?> fetchInboxFresh() async {
    lastInboxError = TimeoutException('Future not completed',
        const Duration(seconds: 8));
    return null;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    OfflineCache.viewerId = () => 'me1';
    StorySeenSync.instance.clear();
    ContentSync.instance.clear();
  });

  group('friendlyError — матни фаҳмо, на хатои хом', () {
    test('timeout бе кэш → «Сервер ҷавоб надод»', () {
      final m = friendlyError(
          TimeoutException('Future not completed', const Duration(seconds: 8)));
      expect(m, 'Сервер ҷавоб надод');
      expect(m, isNot(contains('TimeoutException')));
    });

    test('timeout бо кэш → «Пайвасти суст — маълумоти охирин…»', () {
      expect(friendlyError(TimeoutException('x'), hasCache: true),
          'Пайвасти суст — маълумоти охирин нишон дода шуд');
    });

    test('бе интернет → «Интернет нест»', () {
      expect(friendlyError(const SocketException('Failed host lookup')),
          'Интернет нест');
      expect(friendlyError(http.ClientException('Connection refused')),
          'Интернет нест');
      expect(friendlyError(Exception('SocketException: Network is unreachable')),
          'Интернет нест');
      expect(classifyError(const SocketException('x')), NetErrorKind.offline);
    });

    test('сервер 5xx ё HTML ба ҷои JSON → «Сервер ҷавоб надод»', () {
      expect(friendlyError(const ApiException(503, '<html>sleeping</html>')),
          'Сервер ҷавоб надод');
      expect(friendlyError(const FormatException('Unexpected character')),
          'Сервер ҷавоб надод');
      expect(isNetworkError(const ApiException(502, '')), isTrue);
    });

    test('хабари сервер (4xx) нигоҳ дошта мешавад', () {
      expect(friendlyError(const ApiException(409, '{"message":"Ин ном банд аст"}')),
          'Ин ном банд аст');
      expect(friendlyError(const ApiException(400, '{}')),
          'Нашуд. Дубора кӯшиш кунед');
      expect(isNetworkError(const ApiException(400, '{}')), isFalse);
    });

    test('матни барои корбар навишташуда мемонад, матни техникӣ — не', () {
      expect(friendlyError(Exception('Корбар ёфт нашуд')), 'Корбар ёфт нашуд');
      expect(friendlyError(Exception(_timeoutText)), isNot(contains('Timeout')));
      expect(friendlyError(StateError('Bad state: no element')),
          'Нашуд. Дубора кӯшиш кунед');
      expect(friendlyError(Exception('{"error":"x"}')),
          'Нашуд. Дубора кӯшиш кунед');
    });
  });

  group('ApiClient — timeout ва такрор', () {
    test('GET 15 с аст ва ҳангоми timeout як бор такрор мешавад', () async {
      expect(ApiClient.getTimeout, const Duration(seconds: 15));
      expect(ApiClient.getAttempts, 2);
      var calls = 0;
      final r = await ApiClient.runWithRetry(() async {
        calls++;
        if (calls == 1) throw TimeoutException('slow');
        return http.Response('ok', 200);
      }, attempts: ApiClient.getAttempts, backoff: Duration.zero);
      expect(r.body, 'ok');
      expect(calls, 2);
    });

    test('POST/PUT/DELETE такрор НАМЕШАВАНД (амал ду бор иҷро намешавад)',
        () async {
      expect(ApiClient.writeAttempts, 1);
      var calls = 0;
      await expectLater(
        ApiClient.runWithRetry(() async {
          calls++;
          throw TimeoutException('slow');
        }, attempts: ApiClient.writeAttempts, backoff: Duration.zero),
        throwsA(isA<TimeoutException>()),
      );
      expect(calls, 1);
    });

    test('хатои ғайришабакавӣ такрор намешавад', () async {
      var calls = 0;
      await expectLater(
        ApiClient.runWithRetry(() async {
          calls++;
          throw const FormatException('bad');
        }, attempts: 2, backoff: Duration.zero),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 1);
    });

    test('401 → токен нав мешавад ва як бор такрор, ҳатто барои POST', () async {
      var calls = 0;
      final r = await ApiClient.runWithRetry(() async {
        calls++;
        return http.Response('', calls == 1 ? 401 : 200);
      }, attempts: 1, onUnauthorized: () async => true, backoff: Duration.zero);
      expect(r.statusCode, 200);
      expect(calls, 2);
    });
  });

  group('OfflineCache', () {
    test('ба корбар баста аст — аккаунти дигар кэшро намебинад', () async {
      await OfflineCache.put('chat_inbox', [1, 2, 3]);
      expect((await OfflineCache.get('chat_inbox'))!.data, [1, 2, 3]);
      OfflineCache.viewerId = () => 'other';
      expect(await OfflineCache.get('chat_inbox'), isNull);
      OfflineCache.viewerId = () => null;
      expect(await OfflineCache.get('chat_inbox'), isNull,
          reason: 'бе корбари ворид кэш истифода намешавад');
    });

    test('андоза маҳдуд аст: рӯйхат бурида, гурӯҳ куҳнатаринро нест мекунад',
        () async {
      await OfflineCache.put('feed', List.generate(100, (i) => i), maxItems: 30);
      expect(((await OfflineCache.get('feed'))!.data as List).length, 30);
      for (var i = 0; i < 5; i++) {
        await OfflineCache.put('p$i', {'i': i}, group: 'profile', groupMax: 3);
      }
      expect(await OfflineCache.get('p0'), isNull);
      expect(await OfflineCache.get('p1'), isNull);
      expect((await OfflineCache.get('p4'))!.data, {'i': 4});
    });

    test('кэши куҳна (аз 12/24 соат) барои офлайн боқӣ мемонад', () async {
      final old = DateTime.now().subtract(const Duration(days: 3));
      SharedPreferences.setMockInitialValues({
        'oc1:me1:chat_inbox': jsonEncode(
            {'t': old.millisecondsSinceEpoch, 'd': ['x']}),
      });
      expect((await OfflineCache.get('chat_inbox'))!.data, ['x']);
    });
  });

  group('loadCacheFirst — шабака нашуд → кэш, на хато', () {
    test('кэш ҳаст, шабака меафтад → кэш нишон дода мешавад, хато не', () async {
      final shown = <String>[];
      final out = await loadCacheFirst<String>(
        readCache: () async => 'cached',
        fetch: () async => throw TimeoutException('slow'),
        onData: (d, {required fromCache}) => shown.add(d),
      );
      expect(shown, ['cached']);
      expect(out.isStale, isTrue);
      expect(out.isFailed, isFalse);
    });

    test('кэш нест, шабака меафтад → экрани хато', () async {
      final out = await loadCacheFirst<String>(
        readCache: () async => null,
        fetch: () async => throw const SocketException('offline'),
        onData: (_, {required fromCache}) => fail('чизе нишон дода нашавад'),
      );
      expect(out.isFailed, isTrue);
      expect(friendlyError(out.error), 'Интернет нест');
    });

    test('шабака шуд → маълумоти нав кэшро иваз мекунад', () async {
      final shown = <String>[];
      final out = await loadCacheFirst<String>(
        readCache: () async => 'cached',
        fetch: () async => 'fresh',
        onData: (d, {required fromCache}) => shown.add('$d:$fromCache'),
      );
      expect(shown, ['cached:true', 'fresh:false']);
      expect(out.isFresh, isTrue);
    });

    test('pull-to-refresh (маълумот аллакай дар экран) — кэш дубора хонда намешавад',
        () async {
      var reads = 0;
      final out = await loadCacheFirst<String>(
        hasData: true,
        readCache: () async { reads++; return 'cached'; },
        fetch: () async => throw TimeoutException('slow'),
        onData: (_, {required fromCache}) {},
      );
      expect(reads, 0);
      expect(out.isStale, isTrue);
    });
  });

  group('ChatListController — офлайн', () {
    test('кэш ҳаст, шабака timeout → рӯйхат мемонад, баннер, бе хато', () async {
      final c = ChatListController(_OfflineChatRepo([_row('a'), _row('b')]));
      await c.loadChats();
      expect(c.chats.length, 2);
      expect(c.isStale, isTrue);
      expect(c.error, isNull);
      // Pull-to-refresh боз ҳам рӯйхатро пок намекунад.
      await c.loadChats();
      expect(c.chats.length, 2);
      c.dispose();
    });

    test('кэш нест → хатои фаҳмо, на «Паёме нест» ва на матни хом', () async {
      final c = ChatListController(_OfflineChatRepo(null));
      await c.loadChats();
      expect(c.chats, isEmpty);
      expect(c.error, 'Сервер ҷавоб надод');
      c.dispose();
    });
  });

  group('экранҳо ҳангоми TimeoutException кэшро нишон медиҳанд', () {
    setUp(() {
      AppConfig.initialize(appName: 'Raonson', baseUrl: 'https://example.invalid');
      ApiClient.debugSetClient(_timeoutClient());
    });

    Future<void> settle(WidgetTester t) async {
      for (var i = 0; i < 12; i++) {
        await t.pump(const Duration(milliseconds: 300));
      }
    }

    Future<void> teardown(WidgetTester t) async {
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
      AnalyticsService.instance.resetForTest();
    }

    testWidgets('профил: кэш + баннери офлайн, бе «Корбар ёфт нашуд»', (t) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'oc1:me1:profile:uX': jsonEncode({'t': now, 'd': {
          '_id': 'uX', 'username': 'cached_user', 'fullName': 'Кэш',
          'avatar': '', 'isPrivate': false, 'postsCount': 1,
          'followersCount': 5, 'followingCount': 2,
        }}),
      });
      await t.pumpWidget(const MaterialApp(home: ProfileScreen(userId: 'uX')));
      await settle(t);
      expect(find.text('cached_user'), findsWidgets);
      expect(find.text('Офлайн — маълумоти охирин'), findsOneWidget);
      expect(find.text('Корбар ёфт нашуд'), findsNothing);
      expect(find.textContaining('TimeoutException'), findsNothing);
      await teardown(t);
    });

    testWidgets('профил бе кэш: матни фаҳмо, на матни хоми хато', (t) async {
      await t.pumpWidget(const MaterialApp(home: ProfileScreen(userId: 'uY')));
      await settle(t);
      expect(find.text('Сервер ҷавоб надод'), findsOneWidget);
      expect(find.textContaining('TimeoutException'), findsNothing);
      expect(find.textContaining('Future not completed'), findsNothing);
      await teardown(t);
    });

    testWidgets('рӯйхати чатҳо: кэш + баннер, на «Паёме нест»', (t) async {
      final now = DateTime.now();
      SharedPreferences.setMockInitialValues({
        'oc1:me1:chat_inbox': jsonEncode({
          't': now.millisecondsSinceEpoch,
          'd': [
            {
              '_id': 'm1', 'chatId': 'c1', 'text': 'Паёми охирин',
              'createdAt': now.toIso8601String(), 'isMine': false,
              'unreadCount': 0,
              'peer': {'_id': 'p1', 'username': 'dost_1', 'avatar': ''},
            },
          ],
        }),
      });
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: ChatListScreen())));
      await settle(t);
      expect(find.text('dost_1'), findsWidgets);
      expect(find.text('Паёме нест'), findsNothing);
      expect(find.text('Офлайн — маълумоти охирин'), findsOneWidget);
      expect(find.textContaining('TimeoutException'), findsNothing);
      // Кашидан ба поён (pull-to-refresh) дастрас аст.
      expect(find.byType(RefreshIndicator), findsWidgets);
      await teardown(t);
    });
  });
}
