import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/content_events.dart';

// Пост аз лента ҳазф мешуд, вале дар профил ва explore мемонд.
//
// Ҳар экран нусхаи ХУДИ рӯйхатро дар хотира дорад ва аз ҳазфи
// экрани дигар бехабар аст. `ContentEvents` онҳоро мепайвандад.

void main() {
  group('ContentEvents', () {
    test('хабар ба ҳамаи шунавандагон мерасад', () async {
      // Ду экран — ҳарду бояд хабар бигиранд, на танҳо якум.
      final a = <String>[];
      final b = <String>[];
      final subA = ContentEvents.deleted.listen(a.add);
      final subB = ContentEvents.deleted.listen(b.add);

      ContentEvents.notifyDeleted('post-1');
      await Future<void>.delayed(Duration.zero);

      expect(a, ['post-1']);
      expect(b, ['post-1']);
      await subA.cancel();
      await subB.cancel();
    });

    test('шиносаи холӣ хабар намедиҳад', () async {
      // Вагарна экранҳо бе сабаб аз нав кашида мешуданд.
      final got = <String>[];
      final sub = ContentEvents.deleted.listen(got.add);
      ContentEvents.notifyDeleted('');
      await Future<void>.delayed(Duration.zero);
      expect(got, isEmpty);
      await sub.cancel();
    });

    test('бе шунаванда хато намедиҳад', () {
      // Хабар метавонад пеш аз кушода шудани ягон экран ояд.
      expect(() => ContentEvents.notifyDeleted('x'), returnsNormally);
    });
  });

  group('ҷойҳои ҳазф хабар медиҳанд', () {
    // Ин камбудӣ НАБУДАНИ код буд, на коди нодуруст — пас он дар
    // ягон тести воҳидӣ дида намешуд.
    final places = {
      'lib/feed/post/post_card.dart': 'лента',
      'lib/search/search_screen.dart': 'explore/ҷустуҷӯ',
    };

    places.forEach((path, name) {
      test('$name баъди ҳазф хабар медиҳад', () {
        final src = File(path).readAsStringSync();
        expect(src, contains('ContentEvents.notifyDeleted'),
            reason: '$name баъди ҳазф ба экранҳои дигар хабар намедиҳад — '
                'мундариҷа дар онҳо мемонад');
      });
    });

    test('профил ба хабар обуна мешавад', () {
      final src = File('lib/profile/profile_controller.dart').readAsStringSync();
      expect(src, contains('ContentEvents.deleted.listen'),
          reason: 'профил аз ҳазфи экрани дигар бехабар мемонад');
      expect(src, contains('_deletedSub?.cancel()'),
          reason: 'обуна бекор намешавад — ихроҷи хотира');
    });
  });
}
