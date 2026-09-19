import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/utils/server_time.dart';

// Вақт дар барнома хато нишон дода мешуд.
//
// Ду сабаб:
//
//  1. Ҳар экран худаш ҳисоб мекард. Танҳо ЯК ҷо `.toLocal()` дошт.
//     Пас як пост дар лента як вақт, дар профил вақти дигар.
//
//  2. Сатри вақти БЕ МИНТАҚА («2026-09-19T05:33:06») дар Dart
//     МАҲАЛЛӢ хонда мешавад. Вале сервер дар UTC менависад. Дар
//     Тоҷикистон (UTC+5) ин фарқи ПАНҶ СОАТ медиҳад: пости навро
//     «5 соат пеш» нишон медод.

void main() {
  group('parseServerTime', () {
    test('вақти бо Z дуруст хонда мешавад', () {
      final t = parseServerTime('2026-09-19T05:33:06Z')!;
      expect(t.toUtc().hour, 5);
      expect(t.toUtc().minute, 33);
    });

    test('вақти БЕ минтақа ҳамчун UTC хонда мешавад', () {
      // Маҳз ин сабаби фарқи панҷ соат буд.
      final withZone = parseServerTime('2026-09-19T05:33:06Z')!;
      final without = parseServerTime('2026-09-19T05:33:06')!;
      expect(without.toUtc(), withZone.toUtc(),
          reason: 'вақти бе минтақа маҳаллӣ хонда мешавад — '
              'фарқи минтақа хато медиҳад');
    });

    test('вақти бо офсет дуруст хонда мешавад', () {
      final a = parseServerTime('2026-09-19T10:33:06+05:00')!;
      final b = parseServerTime('2026-09-19T05:33:06Z')!;
      expect(a.toUtc(), b.toUtc());
    });

    test('шакли Postgres бо фосила қабул мешавад', () {
      final t = parseServerTime('2026-09-19 05:33:06')!;
      expect(t.toUtc().hour, 5);
    });

    test('натиҷа ҳамеша МАҲАЛЛӢ аст', () {
      // Экранҳо бо соати телефон муқоиса мекунанд.
      expect(parseServerTime('2026-09-19T05:33:06Z')!.isUtc, isFalse);
    });

    test('вуруди вайрон null медиҳад, на вақти ҷорӣ', () {
      // Вақти ҷорӣ дурӯғ мебуд: «ҳозир» ба ҷои «номаълум».
      expect(parseServerTime(null), isNull);
      expect(parseServerTime(''), isNull);
      expect(parseServerTime('чизи бемаънӣ'), isNull);
    });
  });

  group('sinceServerTime', () {
    test('вақти оянда сифр медиҳад, на манфӣ', () {
      // Соати телефон метавонад аз сервер пеш бошад. Он гоҳ
      // «пас аз 3 соат» нишон дода мешуд.
      final future = DateTime.now().add(const Duration(hours: 3));
      expect(sinceServerTime(future), Duration.zero);
    });

    test('фарқи гузашта дуруст ҳисоб мешавад', () {
      final past = DateTime.now().subtract(const Duration(minutes: 10));
      final d = sinceServerTime(past);
      expect(d.inMinutes, inInclusiveRange(9, 11));
    });

    test('null сифр медиҳад', () {
      expect(sinceServerTime(null), Duration.zero);
    });
  });

  group('ҳисоби вақт дар як ҷо аст', () {
    test('timeAgo худаш ҳисоб намекунад', () {
      final src = File('lib/core/utils/time_ago.dart').readAsStringSync();
      expect(src, isNot(contains('DateTime.now().difference(when)')),
          reason: 'ҳар функсия худаш ҳисоб мекунад — минтақа фаромӯш '
              'мешавад');
      expect(src, contains('sinceServerTime(when)'));
    });

    test('моделҳо таҷзияи умумиро истифода мебаранд', () {
      // Бе ин як модел дуруст, дигаре хато мехонад.
      for (final f in [
        'lib/models/post_model.dart',
        'lib/models/comment_model.dart',
        'lib/models/notification_model.dart',
        'lib/models/story_model.dart',
        'lib/models/reel_model.dart',
        'lib/models/message_model.dart',
      ]) {
        final src = File(f).readAsStringSync();
        expect(src, contains('parseServerTime('),
            reason: '$f вақтро худаш таҷзия мекунад');
      }
    });
  });
}
