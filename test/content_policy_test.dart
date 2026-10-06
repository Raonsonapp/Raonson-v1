import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/admin/moderation_screen.dart';
import 'package:raonson/core/i18n/strings.dart';
import 'package:raonson/core/moderation/content_policy.dart';
import 'package:raonson/create/upload/post_upload_service.dart';
import 'package:raonson/create/upload/upload_progress_bar.dart';
import 'package:raonson/settings/community_guidelines_screen.dart';

// Модератсияи пеш аз нашр: сервер 403 + `code: content_blocked`
// бармегардонад. Барнома бояд онро фаҳмо нишон диҳад — на «Хато 403»,
// на «Нашр нашуд» бе сабаб, ва паёми радшударо дар навбат такрор накунад.

const _blockedBody =
    '{"message":"Ин мӯҳтаво қоидаҳои Raonson-ро вайрон мекунад","code":"content_blocked","categories":["sexual"]}';
const _suspendedBody =
    '{"message":"Ҳисоби шумо то 13.10.2026 10:41 барои нашр маҳдуд шудааст","code":"account_suspended","suspendedUntil":"2026-10-13T05:41:00Z"}';

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('ContentPolicy — ҷавоби сервер', () {
    test('403 content_blocked → ContentRejection бо матни тоҷикӣ', () {
      final r = ContentPolicy.fromResponse(403, _blockedBody)!;
      expect(r.message, kContentBlockedMessage);
      expect(r.code, 'content_blocked');
      expect(r.categories, ['sexual']);
      expect(r.isSuspension, isFalse);
    });

    test('маҳдудкунии ҳисоб', () {
      final r = ContentPolicy.fromResponse(403, _suspendedBody)!;
      expect(r.isSuspension, isTrue);
      expect(r.suspendedUntil, isNotNull);
      expect(r.message, contains('маҳдуд'));
    });

    test('403-и дигар (масалан «Admin only») — модератсия нест', () {
      expect(ContentPolicy.fromResponse(403, '{"message":"Admin only"}'), isNull);
      expect(ContentPolicy.fromResponse(400, _blockedBody), isNull);
      expect(ContentPolicy.fromResponse(403, '<html>'), isNull);
    });

    test('аз хатои боргузорӣ (Upload 403: {...}) ҳам фаҳмида мешавад', () {
      final e = Exception('Upload 403: $_blockedBody');
      expect(ContentPolicy.fromError(e)?.message, kContentBlockedMessage);
      expect(ContentPolicy.friendlyError(e), kContentBlockedMessage);
    });

    test('friendlyError: бе «Exception:» ва JSON-и хом', () {
      expect(ContentPolicy.friendlyError(Exception('Reel 500: {"message":"Reel сабт нашуд"}')),
          'Reel сабт нашуд');
      expect(ContentPolicy.friendlyError(Exception('шабака нест')), 'шабака нест');
      expect(ContentPolicy.friendlyError(null), 'Нашр нашуд');
    });
  });

  group('огоҳии линки 18+ дар чат', () {
    test('доменҳои 18+ ёфт мешаванд', () {
      for (final t in [
        'бин https://www.pornhub.com/view?x=1',
        'xvideos.com',
        'pornhub dot com',
        'rule34.xxx/x',
        'https://m.chaturbate.com',
        'free-porn-site.net',
        'onlyfans.com/someone',
      ]) {
        expect(ContentPolicy.adultLinkIn(t), isNotNull, reason: t);
      }
    });

    test('линкҳои бегуноҳ — огоҳӣ нест', () {
      for (final t in [
        'салом! https://raonson.tj',
        'www.wikipedia.org ва google.com',
        'University of Essex: essex.ac.uk',
        'sextant.io',
        'бе линк, танҳо матн',
        '',
      ]) {
        expect(ContentPolicy.adultLinkIn(t), isNull, reason: t);
      }
    });
  });

  group('экран', () {
    testWidgets('равзанаи рад: матни сервер ва сабаб', (t) async {
      final r = ContentPolicy.fromResponse(403, _blockedBody)!;
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
              onPressed: () => showContentRejection(ctx, r),
              child: const Text('open')),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('content-rejection-message')), findsOneWidget);
      expect(find.text(kContentBlockedMessage), findsOneWidget);
      expect(find.textContaining('оилавист'), findsOneWidget);
      await t.tap(find.text('Фаҳмидам'));
      await t.pumpAndSettle();
      expect(find.text(kContentBlockedMessage), findsNothing);
    });

    testWidgets('равзанаи маҳдудкунӣ', (t) async {
      final r = ContentPolicy.fromResponse(403, _suspendedBody)!;
      await t.pumpWidget(MaterialApp(home: Scaffold(body: ContentRejectionDialog(rejection: r))));
      expect(find.text('Нашр муваққатан маҳдуд аст'), findsOneWidget);
      expect(find.textContaining('13.10.2026'), findsOneWidget);
    });

    testWidgets('огоҳии линк номи доменро нишон медиҳад', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => TextButton(
              onPressed: () => showAdultLinkWarning(ctx, 'pornhub.com'),
              child: const Text('open')),
        ),
      ));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('adult-link-warning')), findsOneWidget);
      expect(find.textContaining('pornhub.com'), findsOneWidget);
    });

    testWidgets('навори нашр сабаби радро нишон медиҳад', (t) async {
      final svc = PostUploadService.instance;
      final f = File('${Directory.systemTemp.path}/thumb_test.jpg');
      await t.pumpWidget(const MaterialApp(home: Scaffold(body: UploadProgressBar())));
      svc.state.value = UploadState(
          thumb: f, error: true, rejected: true, message: kContentBlockedMessage);
      await t.pump();
      expect(find.text(kContentBlockedMessage), findsOneWidget);
      svc.state.value = UploadState(thumb: f, error: true);
      await t.pump();
      expect(find.text('Нашр нашуд'), findsOneWidget);
      svc.state.value = null;
      await t.pump();
    });

    testWidgets('admin: корти навбат — категорияҳо ва амалҳо', (t) async {
      final actions = <String>[];
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: ModerationItemCard(
            item: const {
              'id': 7,
              'surface': 'post',
              'text': 'My new sexy dress',
              'mediaUrl': '',
              'categories': ['suggestive'],
              'score': 0.6,
              'action': 'review',
              'held': true,
              'user': {'id': 'u1', 'username': 'ali', 'strikes': 2},
            },
            onAction: actions.add,
          ),
        ),
      ));
      expect(find.text('@ali'), findsOneWidget);
      expect(find.text('огоҳӣ: 2'), findsOneWidget);
      expect(find.text('Шубҳанок'), findsOneWidget);
      expect(find.textContaining('хол 60%'), findsOneWidget);
      await t.tap(find.byKey(const Key('moderation-approve')));
      await t.tap(find.byKey(const Key('moderation-remove')));
      await t.tap(find.byKey(const Key('moderation-ban')));
      expect(actions, ['approve', 'remove', 'ban']);
    });

    testWidgets('қоидаҳои ҷамъият сиёсати 18+-ро возеҳ мегӯянд', (t) async {
      await t.pumpWidget(const MaterialApp(home: CommunityGuidelinesScreen()));
      expect(find.byKey(const Key('guidelines-family-policy')), findsOneWidget);
      expect(find.text(tr('guidelines.familyTitle')), findsOneWidget);
      expect(tr('guidelines.familyTitle'), contains('18+'));
      expect(tr('guidelines.enforcementText'), contains('3 огоҳӣ'));
    });
  });

  group('ҷойҳои истифода', () {
    test('чат: паёми радшуда ба навбат намеравад ва сабаб нишон дода мешавад', () {
      final room = _read('lib/chat/room/chat_room_screen.dart');
      expect(room, contains('on ContentRejection catch'));
      expect(room, contains('ContentPolicy.adultLinkIn'));
      expect(room, contains('Outbox.instance.onRejected'));
      final outbox = _read('lib/chat/outbox.dart');
      expect(outbox, contains('on ContentRejection catch'));
      final repo = _read('lib/chat/chat_repository.dart');
      expect(repo, contains('ContentPolicy.fromResponse'));
    });

    test('экранҳои сохтан матни серверро нишон медиҳанд', () {
      for (final f in [
        'lib/create/create_reel/create_reel_screen.dart',
        'lib/create/create_story/create_story_screen.dart',
        'lib/create/upload/post_upload_service.dart',
      ]) {
        expect(_read(f), contains('ContentPolicy.'), reason: f);
      }
    });

    test('admin панел ба «Модератсия» мебарад', () {
      expect(_read('lib/admin/admin_panel_screen.dart'), contains('ModerationScreen()'));
    });
  });
}
