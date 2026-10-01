import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/chat/chat_repository.dart';
import 'package:raonson/chat/inbox/chat_list_controller.dart';
import 'package:raonson/chat/room/read_tracker.dart';
import 'package:raonson/chat/room/system_share.dart';
import 'package:raonson/chat/unread/chat_unread_store.dart';
import 'package:raonson/models/message_model.dart';
import 'package:raonson/models/user_model.dart';

// Бейҷи «2» дар рӯйхати чатҳо баъди хондан намерафт. Акнун паёмҳо
// ҳангоми ДИДАН хонда мешаванд (тадриҷан), бейҷҳо фавран кам мешаванд
// ва GET /chat-и нав онҳоро аз кэш барнамегардонад.

List<ReadItem> _chat({int read = 0, int unread = 0, int mineAfter = 0}) => [
      for (var i = 0; i < read; i++)
        ReadItem(id: 'r$i', incoming: true, read: true),
      for (var i = 0; i < unread; i++)
        ReadItem(id: 'u$i', incoming: true, read: false),
      for (var i = 0; i < mineAfter; i++)
        ReadItem(id: 'm$i', incoming: false, read: false),
    ];

UserModel _peer(String id) => UserModel(
      id: id, username: 'user_$id', avatar: '', verified: false,
      isPrivate: false, postsCount: 0, followersCount: 0, followingCount: 0,
    );

MessageModel _row(String chatId, int unread, {bool request = false}) =>
    MessageModel(
      id: 'last_$chatId', chatId: chatId, peer: _peer(chatId), text: 'hi',
      createdAt: DateTime(2026), isMine: false, unreadCount: unread,
      isRequest: request,
    );

class _FakeRepo extends ChatRepository {
  List<MessageModel>? cached;
  List<({List<MessageModel> chats, int? totalUnread})?> fresh = [];
  int freshCalls = 0;

  @override
  Future<List<MessageModel>?> loadCachedInbox() async => cached;

  @override
  Future<({List<MessageModel> chats, int? totalUnread})?> fetchInboxFresh() async {
    final r = fresh.isEmpty ? null : fresh.removeAt(0);
    freshCalls++;
    return r;
  }
}

void main() {
  group('ReadTracker — дида шуд → хонда шуд', () {
    test('10 хонданашуда, 4 дар экран → 6 мемонад', () {
      final items = _chat(read: 3, unread: 10);
      final visible = {'u0', 'u1', 'u2', 'u3'};
      final m = ReadTracker.compute(items, visible)!;
      expect(m.upToId, 'u3');
      expect(m.newlyRead, 4);
      expect(m.remaining, 6);
    });

    test('то поён scroll → 0 мемонад, upTo = навтарин', () {
      final items = _chat(unread: 10);
      final m = ReadTracker.compute(items, {'u8', 'u9'})!;
      expect(m.upToId, 'u9');
      expect(m.newlyRead, 10); // паёмҳои болотар аллакай гузаштаанд
      expect(m.remaining, 0);
    });

    test('кушодани чат бо паёмҳои охирин дар экран — фавран хонда', () {
      final items = _chat(read: 20, unread: 2);
      final m = ReadTracker.compute(items, {'r19', 'u0', 'u1'})!;
      expect(m.remaining, 0);
      expect(m.newlyRead, 2);
    });

    test('танҳо паёмҳои кӯҳна/худам дар экран — ҳеҷ чиз хонда намешавад', () {
      final items = _chat(read: 5, unread: 3, mineAfter: 2);
      expect(ReadTracker.compute(items, {'r0', 'r1', 'm0', 'm1'}), isNull);
      expect(ReadTracker.compute(items, <String>{}), isNull);
    });

    test('паёми худам дар экран ҳисоб намешавад', () {
      final items = [
        const ReadItem(id: 'a', incoming: true, read: false),
        const ReadItem(id: 'mine', incoming: false, read: false),
        const ReadItem(id: 'b', incoming: true, read: false),
      ];
      final m = ReadTracker.compute(items, {'a', 'mine'})!;
      expect(m.upToId, 'a');
      expect(m.remaining, 1);
    });

    test('setVisible / next ва firstUnreadIndex', () {
      final t = ReadTracker();
      final items = _chat(read: 2, unread: 3);
      expect(ReadTracker.firstUnreadIndex(items), 2);
      expect(ReadTracker.unreadCount(items), 3);
      t.setVisible('u1', true);
      expect(t.next(items)!.remaining, 1);
      t.setVisible('u1', false);
      expect(t.next(items), isNull);
      expect(ReadTracker.firstUnreadIndex(_chat(read: 2)), -1);
    });
  });

  group('ChatUnreadStore — бейҷи умумӣ', () {
    test('хондани маҳаллӣ бейҷро фавран кам мекунад, сервер ҳақиқат аст', () {
      final s = ChatUnreadStore.forTest();
      s.setTotal(12);
      s.markedLocally('c1', remaining: 6, delta: 4);
      expect(s.total, 8);
      expect(s.unreadFor('c1'), 6);
      s.applyServer('c1', 5, 7);
      expect(s.total, 7);
      expect(s.unreadFor('c1'), 5);
    });

    test('паёми нав: +1, ғайр аз чати кушода ва паёми худам', () {
      final s = ChatUnreadStore.forTest();
      s.setTotal(1);
      s.markedLocally('c1', remaining: 1);
      s.onIncoming({'chatId': 'c1', 'sender': {'_id': 'peer'}}, 'me');
      expect(s.total, 2);
      expect(s.unreadFor('c1'), 2);
      s.onIncoming({'chatId': 'c1', 'sender': {'_id': 'me'}}, 'me');
      expect(s.total, 2);
      s.activeChatId = 'c1';
      s.onIncoming({'chatId': 'c1', 'sender': {'_id': 'peer'}}, 'me');
      expect(s.total, 2);
    });

    test('ҳеҷ гоҳ манфӣ намешавад; reset пок мекунад', () {
      final s = ChatUnreadStore.forTest();
      s.markedLocally('c', remaining: -3, delta: 9);
      expect(s.total, 0);
      expect(s.unreadFor('c'), 0);
      s.setTotal(4);
      s.reset();
      expect(s.total, 0);
      expect(s.unreadFor('c'), isNull);
    });
  });

  group('ChatListController — бейҷи inbox', () {
    test('кэши кӯҳна бейҷро барнамегардонад: шабака ҳамеша меояд', () async {
      final store = ChatUnreadStore.forTest();
      final repo = _FakeRepo()
        ..cached = [_row('c1', 2)]
        ..fresh = [(chats: [_row('c1', 0)], totalUnread: 0)];
      final ctrl = ChatListController(repo, unread: store);
      await ctrl.loadChats();
      expect(repo.freshCalls, 1);
      expect(ctrl.chats.single.unreadCount, 0);
      expect(store.total, 0);
      ctrl.dispose();
    });

    test('хондан дар чат → бейҷи ҳамон сатр фавран кам мешавад', () async {
      final store = ChatUnreadStore.forTest();
      final repo = _FakeRepo()
        ..fresh = [(chats: [_row('c1', 10), _row('c2', 1)], totalUnread: 11)];
      final ctrl = ChatListController(repo, unread: store);
      await ctrl.loadChats();
      expect(ctrl.totalUnreadMessages, 11);
      store.markedLocally('c1', remaining: 6, delta: 4);
      expect(ctrl.chats.firstWhere((c) => c.chatId == 'c1').unreadCount, 6);
      expect(store.total, 7);
      ctrl.dispose();
    });

    test('POST /read дар роҳ: GET /chat-и кӯҳна бейҷро бознамегардонад', () async {
      final store = ChatUnreadStore.forTest();
      final repo = _FakeRepo();
      final ctrl = ChatListController(repo, unread: store);
      // Хонда шуд ПЕШ аз он ки ҷавоби (кӯҳнаи) сервер расад.
      repo.fresh = [(chats: [_row('c1', 2)], totalUnread: 2)];
      final f = ctrl.loadChats();
      store.markedLocally('c1', remaining: 0, delta: 2);
      await f;
      expect(ctrl.chats.single.unreadCount, 0);
      ctrl.dispose();
    });

    test('дархостҳо ва чатҳои хомӯш ба бейҷи умумӣ намедароянд', () async {
      final store = ChatUnreadStore.forTest();
      final repo = _FakeRepo()
        ..fresh = [
          (chats: [_row('c1', 3), _row('c2', 5, request: true)], totalUnread: null)
        ];
      final ctrl = ChatListController(repo, unread: store);
      await ctrl.loadChats();
      expect(ctrl.totalUnreadMessages, 3);
      ctrl.dispose();
    });
  });

  group('Кортҳои системавии Direct', () {
    test('даъвати ҳамкорӣ ва зикри сторис шинохта мешаванд', () {
      const post = SharedRef(id: 'p1', kind: 'post');
      const story = SharedRef(id: 's1', kind: 'story');
      expect(classifySystemShare(post, kCollabInviteDMText),
          SystemShare.collabInvite);
      expect(classifySystemShare(story, kStoryMentionDMText),
          SystemShare.storyMention);
      expect(classifySystemShare(post, 'салом'), SystemShare.none);
      expect(classifySystemShare(story, kCollabInviteDMText), SystemShare.none);
      expect(classifySystemShare(null, kCollabInviteDMText), SystemShare.none);
    });

    test('матнҳо бо сервер мувофиқанд (share_dm.go)', () {
      // Агар яке иваз шавад, тугмаҳои «Қабул/Рад» гум мешаванд.
      expect(kCollabInviteDMText, 'Шуморо ба ҳамкорӣ дар пост даъват кард');
      expect(kStoryMentionDMText, 'Шуморо дар сторис зикр кард');
    });
  });

}
