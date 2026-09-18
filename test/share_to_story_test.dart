import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/models/story_model.dart';

// «Пост ё Reel → стори» ТАМОМАН вуҷуд надошт: на банд дар меню, на
// ҷой дар база, на роҳи кушодан.
//
// Ин тест занҷири пурраро месанҷад, чунки камбудӣ метавонад дар ҳар
// ҳалқа пайдо шавад ва ҳеҷ кадоми онҳо хато намедиҳад — танҳо
// хусусият хомӯшона кор намекунад.

void main() {
  group('StoryModel', () {
    test('шиносаи паҳншуда хонда мешавад', () {
      final s = StoryModel.fromJson({
        '_id': 's1',
        'mediaUrl': 'https://x/a.jpg',
        'mediaType': 'image',
        'sharedPostId': 'p42',
      });
      expect(s.sharedPostId, 'p42');
      expect(s.hasShared, isTrue);
    });

    test('Reel-и паҳншуда низ', () {
      final s = StoryModel.fromJson({
        '_id': 's2',
        'mediaUrl': 'https://x/a.jpg',
        'mediaType': 'image',
        'sharedReelId': 'r7',
      });
      expect(s.sharedReelId, 'r7');
      expect(s.hasShared, isTrue);
    });

    test('стори-и оддӣ чизе паҳн намекунад', () {
      // Бе ин ҳар стори тугмаи «Публикатсияро дидан»-и бефоида
      // нишон медод.
      final s = StoryModel.fromJson({
        '_id': 's3',
        'mediaUrl': 'https://x/a.jpg',
        'mediaType': 'image',
      });
      expect(s.hasShared, isFalse);
    });

    test('маълумоти вайрон ба крах намеорад', () {
      final s = StoryModel.fromJson({
        '_id': 's4',
        'mediaUrl': '',
        'sharedPostId': 123, // рақам, на сатр
      });
      expect(s.sharedPostId, '123');
    });
  });

  group('занҷири паҳнкунӣ', () {
    test('менюи пост банди «Ба стори» дорад', () {
      final src = File('lib/feed/post/post_card.dart').readAsStringSync();
      expect(src, contains('_shareToStory'),
          reason: 'дар менюи пост роҳи гузоштан ба стори нест');
      expect(src, contains('shareToStory('),
          reason: 'банд ҳаст, вале ҳеҷ кор намекунад');
    });

    test('стори шиносаро ба сервер мефиристад', () {
      final src = File('lib/create/share_to_story.dart').readAsStringSync();
      // Бе ин стори танҳо расм мебуд — занед, ҳеҷ ҷо намебарад.
      expect(src, contains("'sharedReelId'"));
      expect(src, contains("'sharedPostId'"));
    });

    test('намоишгари стори пости аслиро мекушояд', () {
      final src =
          File('lib/stories/story_group_viewer.dart').readAsStringSync();
      expect(src, contains('_openShared'),
          reason: 'тугма ҳаст, вале ҳеҷ ҷо намебарад');
      expect(src, contains('hasShared'),
          reason: 'тугма дар ҳар стори намоён мешавад, ҳатто дар оддӣ');
      // Пост метавонад ҳазф шавад — стори 24 соат зиндагӣ мекунад.
      expect(src, contains('Публикатсия ёфт нашуд'),
          reason: 'пости ҳазфшуда бе ҳеҷ фаҳмиш мемонад');
    });
  });
}
