import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:raonson/chat/chat_repository.dart';
import 'package:raonson/chat/room/chat_room_app_bar.dart';
import 'package:raonson/core/links/deep_links.dart';
import 'package:raonson/models/message_model.dart';
import 'package:raonson/models/note_model.dart';
import 'package:raonson/models/user_model.dart';
import 'package:raonson/profile/share_profile_sheet.dart';

// Камбудиҳое, ки соҳиб аз барномаи воқеӣ фиристод:
// чати суст, иконҳо болои ном, вокуниш ба ёддошт ва QR.
String _read(String p) => File(p).readAsStringSync();

UserModel _peer(String name) => UserModel(
      id: 'u2', username: name, avatar: '', verified: false,
      isPrivate: false, postsCount: 0, followersCount: 0, followingCount: 0,
    );

void main() {
  group('1. кушодани чат — бе round-trip-и иловагӣ', () {
    test('chatId маҳаллӣ = sortedChatID-и backend (симметрӣ)', () {
      expect(ChatRepository.localChatId('b', 'a'), 'a_b');
      expect(ChatRepository.localChatId('a', 'b'), 'a_b');
      // UUID-ҳо — ҳамон тартиби байтии Go (ASCII).
      const x = '31356983-3ab4-4022-b662-57363421e904';
      const y = 'f794bbaf-44e5-486f-aca3-28050a0565dd';
      expect(ChatRepository.localChatId(y, x), '${x}_$y');
      final go = _read('backend/handlers/helpers.go');
      expect(go, contains('if a < b { return a + "_" + b }'));
    });

    test('_init пеш аз шабака `/chat/with` интизор намешавад', () {
      final repo = _read('lib/chat/chat_repository.dart');
      final start = repo.indexOf('Future<String?> resolveChatId');
      final body = repo.substring(start, repo.indexOf('fetchLatest', start));
      // Шабака танҳо вақте ки myId номаълум аст.
      expect(body.indexOf('localChatId'),
          lessThan(body.indexOf('/with/')));
      // Натиҷаи шабака ва паёми фиристода ба кэш навишта мешаванд.
      expect(repo, contains('_saveMessagesCache(chatId, data)'));
      expect(repo, contains('appendToCache(cid, raw)'));
    });
  });

  group('2. сарлавҳаи чат дар телефони танг', () {
    for (final width in [320.0, 360.0, 411.0]) {
      testWidgets('ном бо тугмаҳо намепӯшад ($width dp)', (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        const name = 'shahromcoder_with_a_really_long_username';
        await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (ctx) => Scaffold(
            appBar: buildChatRoomAppBar(ctx,
                peer: _peer(name), online: true, statusLabel: 'Онлайн',
                typing: false, vanish: false,
                onBack: () {}, onOpenProfile: () {}, onToggleVanish: () {},
                onVideo: () {}, onVoice: () {}, onTheme: () {}),
          )),
        ));
        expect(tester.takeException(), isNull); // RenderFlex overflow нест
        final nameRect = tester.getRect(find.text(name));
        final buttons = find.descendant(
            of: find.byType(AppBar),
            matching: find.byWidgetPredicate(
                (w) => w is IconButton || w is PopupMenuButton));
        // Тугмаи «ба қафо» чап аст — танҳо тугмаҳои рост.
        final actionsLeft = buttons.evaluate()
            .map((e) => tester.getRect(find.byWidget(e.widget)).left)
            .where((l) => l > width / 2)
            .reduce((a, b) => a < b ? a : b);
        expect(nameRect.right, lessThanOrEqualTo(actionsLeft));
        expect(nameRect.width, greaterThan(40)); // ном ҳоло ҳам намоён аст
      });
    }
  });

  group('4. ёддошт: вокуниш ва ҷавоб', () {
    test('myReaction ва рӯйхати вокунишҳо хонда мешаванд', () {
      final n = NoteModel.fromJson({
        '_id': 'o1', 'username': 'ali', 'note': 'салом',
        'noteExpiresAt': '2099-01-01T00:00:00Z', 'myReaction': '🔥',
      });
      expect(n.myReaction, '🔥');
      expect(n.copyWith(myReaction: '').myReaction, '');
      final r = NoteReaction.fromJson({
        'user': {'_id': 'u9', 'username': 'vali', 'avatar': ''},
        'emoji': '❤️',
      });
      expect(r.username, 'vali');
      expect(r.emoji, '❤️');
    });

    test('ҷавоб ба ёддошт дар чат бо иқтибос меояд', () {
      final m = MessageModel.fromRoomJson({
        '_id': 'm1', 'chatId': 'a_b', 'text': 'Олӣ!',
        'createdAt': '2026-09-30T01:00:00Z',
        'shareId': 'b', 'shareKind': 'note',
        'shareThumb': 'Салом ҷаҳон', 'shareUser': 'ali',
        'sender': {'_id': 'a', 'username': 'a'},
      }, 'b');
      expect(m.share?.kind, 'note');
      expect(m.share?.thumb, 'Салом ҷаҳон');
      expect(m.share?.label, 'Ёддошт');
      expect(_read('lib/chat/room/message_bubble.dart'),
          contains("m.share?.kind == 'note'"));
    });

    test('эмодзиҳои клиент = рӯйхати иҷозатдодаи backend', () {
      final go = _read('backend/handlers/note_reactions.go');
      for (final e in ['❤️', '😂', '😮', '😢', '🔥', '👏']) {
        expect(go, contains('"$e": true'), reason: e);
      }
    });
  });

  group('5. QR бо логотип', () {
    testWidgets('логотип дар марказ, ErrorCorrection H, ≤ 20% масоҳат',
        (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: ShareProfileSheet(user: _peer('ali')))));
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr.errorCorrectionLevel, QrErrorCorrectLevel.H);
      expect(qr.embeddedImage, const AssetImage('assets/qr_logo.png'));
      final logo = qr.embeddedImageStyle!.size!;
      final area = (logo.width * logo.height) / (qr.size! * qr.size!);
      expect(area, lessThanOrEqualTo(0.20));
      expect(QrValidator.validate(
              data: DeepLinks.share(DeepLinkKind.profile, 'ali'),
              errorCorrectionLevel: QrErrorCorrectLevel.H)
          .isValid, isTrue);
      expect(File('assets/qr_logo.png').existsSync(), isTrue);
      expect(_read('pubspec.yaml'), contains('assets/qr_logo.png'));
    });
  });
}
