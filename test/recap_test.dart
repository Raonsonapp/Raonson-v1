// test/recap_test.dart
// Ҷамъбасти ҳафтагӣ. Хатари асосӣ — рақами ихтироъшуда: агар сервер
// чизе нафиристад, client НАБОЯД онро худаш пур кунад.
import 'package:flutter_test/flutter_test.dart';
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

    test('ҷамъбасти холӣ рӯйхатҳои холӣ медиҳад, на null', () {
      final r = CreatorRecap.fromJson(const {});
      expect(r.hasEnoughData, isFalse);
      expect(r.topContent, isEmpty);
      expect(r.insights, isEmpty);
      expect(r.recommendation.hasData, isFalse);
      expect(r.overview.views, 0);
    });
  });
}
