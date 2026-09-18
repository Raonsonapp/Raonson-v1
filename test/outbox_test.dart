import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/chat/outbox.dart';

// Паёми офлайн гум мешуд ва барнома ДУРӮҒ мегуфт.
//
// Ду камбудии ҷудогона:
//
//  1. Навбат танҳо дар ХОТИРА буд (`List` дар худи экран). Барномаро
//     пӯшед — паёмҳо абадан гум мешуданд.
//
//  2. Ҳангоми нокомии фиристодан код паёмро ҳамчун
//     `MessageStatus.sent` нишон медод. Паём нарасида буд, вале дар
//     экран «фиристода шуд» менамуд. Ин аз гум кардани паём БАДТАР
//     аст: корбар боварӣ дорад, ки хабараш расид.

void main() {
  group('PendingMessage', () {
    test('JSON рафту баргашт маълумотро гум намекунад', () {
      final m = PendingMessage(
        clientId: 'c1',
        toUserId: 'u2',
        chatId: 'u1_u2',
        text: 'салом',
        replyToId: 'm9',
        mediaUrl: 'https://x/a.jpg',
        mediaType: 'image',
        viewOnce: true,
        attempts: 3,
        createdAtMs: 1700000000000,
      );
      final back = PendingMessage.fromJson(m.toJson())!;
      expect(back.clientId, 'c1');
      expect(back.toUserId, 'u2');
      expect(back.chatId, 'u1_u2');
      expect(back.text, 'салом');
      expect(back.replyToId, 'm9');
      expect(back.mediaUrl, 'https://x/a.jpg');
      expect(back.viewOnce, isTrue);
      expect(back.attempts, 3);
      expect(back.createdAtMs, 1700000000000);
    });

    test('сабти бе шиноса қабул намешавад', () {
      // Вагарна паёми бешиноса абадан дар навбат мемонд ва ҳеҷ гоҳ
      // фиристода намешуд.
      expect(PendingMessage.fromJson({'text': 'x'}), isNull);
    });

    test('ҳар кӯшиш ҳисоб мешавад', () {
      final m = PendingMessage(
          clientId: 'c', toUserId: 'u', chatId: 'ch', text: 't',
          createdAtMs: 0);
      expect(m.bumpAttempt().attempts, 1);
      expect(m.bumpAttempt().bumpAttempt().attempts, 2);
      // Боқии майдонҳо нигоҳ дошта мешаванд.
      expect(m.bumpAttempt().text, 't');
    });

    test('шиносаи маҳаллӣ такрор намешавад', () {
      final ids = <String>{};
      for (var i = 0; i < 500; i++) {
        ids.add(Outbox.instance.newClientId());
      }
      // Такрор маънои паёми гумшуда дорад: дуюмӣ аввалиро мепӯшонад.
      expect(ids.length, 500);
    });
  });

  group('занҷири навбат', () {
    test('экран навбати диск истифода мебарад, на хотира', () {
      final src =
          File('lib/chat/room/chat_room_screen.dart').readAsStringSync();
      expect(src, isNot(contains('_offlineQueue.add')),
          reason: 'навбати хотиравӣ баргашт — барномаро пӯшед, '
              'паёмҳо гум мешаванд');
      expect(src, contains('Outbox.instance'),
          reason: 'навбати диск истифода намешавад');
    });

    test('нокомӣ ҳамчун «фиристода шуд» нишон дода намешавад', () {
      final src =
          File('lib/chat/room/chat_room_screen.dart').readAsStringSync();
      // Маҳз ин дурӯғ буд.
      expect(src, isNot(contains('status: MessageStatus.sent);\n            }\n          });\n        }\n      }')),
          reason: 'паёми нофиристода ҳамчун фиристодашуда нишон дода мешавад');
      expect(src, contains('MessageStatus.failed'),
          reason: 'ҳолати нокомӣ нишон дода намешавад');
    });

    test('сервер такрорро паёми дуюм намекунад', () {
      final src = File('backend/handlers/chat_extended.go').readAsStringSync();
      expect(src, contains('client_id'),
          reason: 'калиди такрорнашавӣ нест — такрор паёми дуюм месозад');
      expect(src, contains('WHERE sender_id=\$1 AND client_id=\$2'),
          reason: 'паёми мавҷуд ҷустуҷӯ намешавад');
    });

    test('навбат ҳангоми оғози барнома сар мешавад', () {
      final src = File('lib/main.dart').readAsStringSync();
      expect(src, contains('Outbox.instance.start()'),
          reason: 'паёмҳои навбатӣ ҳеҷ гоҳ фиристода намешаванд');
    });
  });
}
