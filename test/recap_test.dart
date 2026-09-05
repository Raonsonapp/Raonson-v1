// test/recap_test.dart
// Ҷамъбасти ҳафтагӣ. Хатари асосӣ — рақами ихтироъшуда: агар сервер
// чизе нафиристад, client НАБОЯД онро худаш пур кунад.
import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/creator_studio/creator_studio_repository.dart';
import 'package:raonson/recap/recap_repository.dart';

void main() {
  group('ҷамъбасти бинанда', () {
    test('рақамҳо ҳамон тавре хонда мешаванд, ки сервер дод', () {
      final r = ViewerRecap.fromJson(const {
        'weekStart': '2026-08-24',
        'hasEnoughData': true,
        'reelsWatched': 12,
        'postsViewed': 7,
        'creatorsDiscovered': 3,
        'followed': 2,
        'liked': 9,
        'saved': 4,
        'shared': 1,
        'topTopic': 'gaming',
        'topTopicName': {'tj': 'Бозиҳо', 'ru': 'Игры', 'en': 'Gaming'},
      });
      expect(r.weekStart, '2026-08-24');
      expect(r.hasEnoughData, isTrue);
      expect(r.reelsWatched, 12);
      expect(r.postsViewed, 7);
      expect(r.creatorsDiscovered, 3);
      expect(r.followed, 2);
      expect(r.liked, 9);
      expect(r.saved, 4);
      expect(r.shared, 1);
    });

    test('майдони нест сифр мешавад, на рақами тахминӣ', () {
      final r = ViewerRecap.fromJson(const {'weekStart': '2026-08-24'});
      expect(r.hasEnoughData, isFalse);
      expect(r.reelsWatched, 0);
      expect(r.postsViewed, 0);
      expect(r.liked, 0);
      expect(r.topTopic, isEmpty);
      expect(r.topTopicName, isNull);
    });

    test('маълумоти вайрон барномаро вайрон намекунад', () {
      final r = ViewerRecap.fromJson(const {
        'reelsWatched': 'дувоздаҳ',
        'hasEnoughData': 'ҳа',
        'topTopicName': 'gaming',
      });
      expect(r.reelsWatched, 0);
      expect(r.hasEnoughData, isFalse);
      expect(r.topTopicName, isNull);
    });
  });

  group('номи мавзӯъ', () {
    test('забони ҷорӣ интихоб мешавад', () {
      const n = TopicName(tj: 'Бозиҳо', ru: 'Игры', en: 'Gaming');
      expect(n.label('tj'), 'Бозиҳо');
      expect(n.label('ru'), 'Игры');
      expect(n.label('en'), 'Gaming');
    });

    test('агар тарҷума набошад, ба забони дигар мегузарад', () {
      const n = TopicName(tj: 'Бозиҳо');
      expect(n.label('ru'), 'Бозиҳо');
      expect(n.label('en'), 'Бозиҳо');
    });

    test('бе ном slug нишон дода мешавад, на сатри холӣ', () {
      final r = ViewerRecap.fromJson(const {'topTopic': 'gaming'});
      expect(r.topicLabel('tj'), 'gaming');
    });

    test('номи тарҷумашуда аз slug бартарӣ дорад', () {
      final r = ViewerRecap.fromJson(const {
        'topTopic': 'gaming',
        'topTopicName': {'tj': 'Бозиҳо'},
      });
      expect(r.topicLabel('tj'), 'Бозиҳо');
    });
  });

  group('ҷамъбасти эҷодкор', () {
    test('бахшҳои дохилӣ хонда мешаванд', () {
      final r = CreatorRecap.fromJson(const {
        'weekStart': '2026-08-24',
        'hasEnoughData': true,
        'overview': {'posts': 2, 'reels': 1, 'views': 500, 'followersGained': 4},
        'recommendation': {'impressions': 300, 'follows': 4, 'openRate': 0.5},
        'topContent': [
          {'contentType': 'post', 'contentId': 'p1', 'impressions': 100},
        ],
        'topTopic': 'gaming',
        'insights': [
          {'code': 'followerGrowth', 'params': {'count': 4}},
        ],
      });
      expect(r.hasEnoughData, isTrue);
      expect(r.overview.posts + r.overview.reels, 3);
      expect(r.overview.views, 500);
      expect(r.recommendation.impressions, 300);
      expect(r.recommendation.hasData, isTrue);
      expect(r.topContent.single.contentId, 'p1');
      expect(r.insights.single.code, 'followerGrowth');
      expect(r.insights.single.params['count'], 4);
    });

    test('навъи нодурусти рӯйхат ба крах намеорад', () {
      // Агар сервер ба ҷои рӯйхат сатр диҳад, экран набояд афтад.
      final r = CreatorRecap.fromJson(const {
        'topContent': 'ду пост',
        'insights': 42,
      });
      expect(r.topContent, isEmpty);
      expect(r.insights, isEmpty);
    });

    test('ҷамъбасти холӣ рӯйхатҳои холӣ медиҳад, на null', () {
      final r = CreatorRecap.fromJson(const {});
      expect(r.hasEnoughData, isFalse);
      expect(r.topContent, isEmpty);
      expect(r.insights, isEmpty);
      expect(r.recommendation.hasData, isFalse);
      expect(r.overview.views, 0);
    });
  });

  group('пешрафти эҷодкор', () {
    test('зина ва ҳадафи оянда хонда мешаванд', () {
      final p = CreatorProgress.fromJson(const {
        'achievements': [
          {'code': 'firstPost', 'value': 3, 'earnedAt': '2026-09-01T00:00:00Z'},
        ],
        'level': {
          'level': 2,
          'stats': {'followers': 12, 'posts': 3, 'reels': 1, 'views': 400},
          'next': {'level': 3, 'followers': 100, 'views': 1000, 'content': 10},
        },
      });
      expect(p.achievements.single.code, 'firstPost');
      expect(p.achievements.single.value, 3);
      expect(p.level.level, 2);
      expect(p.level.stats.content, 4, reason: 'пост + рилс');
      expect(p.level.next!.followers, 100);
    });

    test('зинаи охирин ҳадафи оянда надорад', () {
      final p = CreatorProgress.fromJson(const {
        'level': {'level': 5, 'stats': {}},
      });
      expect(p.level.next, isNull);
      expect(p.achievements, isEmpty);
    });

    test('навъи нодурусти рӯйхати нишонҳо ба крах намеорад', () {
      final p = CreatorProgress.fromJson(const {'achievements': 'firstPost'});
      expect(p.achievements, isEmpty);
    });

    test('ҷавоби холӣ ба крах намеорад', () {
      final p = CreatorProgress.fromJson(const {});
      expect(p.level.level, 0);
      expect(p.level.stats.followers, 0);
      expect(p.achievements, isEmpty);
    });
  });
}
