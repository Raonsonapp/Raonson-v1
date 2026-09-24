import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/models/message_model.dart';

// Функсияҳои чат, ки Instagram дорад ва Raonson надошт:
// таҳрир, forward, пин, хомӯш.
String _read(String p) => File(p).readAsStringSync();

void main() {
  group('модел', () {
    test('«таҳрир шуд» ва «Фиристода шуд» аз сервер хонда мешаванд', () {
      final m = MessageModel.fromRoomJson({
        '_id': 'm1', 'chatId': 'a_b', 'text': 'салом',
        'createdAt': '2026-09-23T01:00:00Z',
        'editedAt': '2026-09-23T01:05:00Z',
        'forwarded': true,
        'sender': {'_id': 'a', 'username': 'a'},
      }, 'b');
      expect(m.editedAt, isNotNull);
      expect(m.forwarded, isTrue);
    });

    test('пин ва хомӯш дар рӯйхати чатҳо', () {
      final c = MessageModel.fromJson({
        '_id': 'm1', 'chatId': 'a_b', 'text': 'x',
        'createdAt': '2026-09-23T01:00:00Z',
        'pinned': true, 'muted': true,
        'peer': {'_id': 'b', 'username': 'b'},
      });
      expect(c.pinned, isTrue);
      expect(c.muted, isTrue);
    });

    test('паёми оддӣ на таҳриршуда, на фиристодашуда', () {
      final m = MessageModel.fromRoomJson({
        '_id': 'm2', 'chatId': 'a_b', 'text': 'x',
        'createdAt': '2026-09-23T01:00:00Z',
        'sender': {'_id': 'a'},
      }, 'b');
      expect(m.editedAt, isNull);
      expect(m.forwarded, isFalse);
    });
  });

  test('vanish аз сервер хонда мешавад ва тавассути REST меравад', () {
    final m = MessageModel.fromRoomJson({
      '_id': 'v', 'chatId': 'a_b', 'text': 'x', 'vanish': true,
      'createdAt': '2026-09-23T01:00:00Z', 'sender': {'_id': 'a'},
    }, 'b');
    expect(m.vanish, isTrue);
    final r = File('lib/chat/room/chat_room_screen.dart').readAsStringSync();
    // Ҳамаи паёмҳо (аз ҷумла vanish) тавассути REST мераванд: роҳи
    // сокет парчами vanish, блок, огоҳинома ва ҷавоби худкорро гум мекард
    // ва баъди иловаи аккаунт аз номи аккаунти кӯҳна менавишт.
    expect(r.contains("_socket.emit('chat:send'"), isFalse,
        reason: 'паём набояд тавассути socket равад');
    expect(r, contains('vanish:    _vanish'));
    expect(r, contains("'/chat/\$_chatId/vanish-close'"));
  });

  group('экранҳо', () {
    test('менюи паём «Таҳрир» ва «Фиристодан» дорад', () {
      final b = _read('lib/chat/room/message_bubble.dart');
      expect(b, contains("label: 'Таҳрир'"));
      expect(b, contains("label: 'Фиристодан'"));
      // Таҳрир танҳо паёми матнии худам, 15 дақиқа.
      final i = b.indexOf('bool get _canEdit');
      final body = b.substring(i, i + 400);
      expect(body, contains('message.isMine'));
      expect(body, contains('Duration(minutes: 15)'));
    });

    test('нишонаҳо дар ҳубобча', () {
      final b = _read('lib/chat/room/message_bubble.dart');
      expect(b, contains('таҳрир шуд'));
      expect(b, contains("'Фиристода шуд'"));
    });

    test('таҳрир дар экран фавран ва баргардонидан ҳангоми рад', () {
      final r = _read('lib/chat/room/chat_room_screen.dart');
      final i = r.indexOf('Future<void> _onEdit(');
      final body = r.substring(i, i + 2200);
      expect(body, contains("put('/chat/messages/"));
      expect(body, contains('before : m'),
          reason: 'агар сервер рад кунад, матни пешина барнагардад');
      expect(r, contains("_listen('chat:edit'"));
    });

    test('forward парчами forwarded мефиристад', () {
      final s = _read('lib/chat/share/share_to_chat_row.dart');
      expect(s, contains("'forwarded': true"));
    });

    test('рӯйхати чат: пахши дароз → пин/хомӯш', () {
      final l = _read('lib/chat/inbox/chat_list_screen.dart');
      expect(l, contains("'/chat/pin/"));
      expect(l, contains("'/chat/mute/"));
      expect(l, contains('onLongPress: chat.isRequest ? null'));
    });
  });
}
