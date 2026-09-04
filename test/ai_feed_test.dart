// test/ai_feed_test.dart
// Санҷиши таҷзияи ҷавоби ВОҚЕИИ сервери «Лентаи AI».
//
// JSON аз сервери зинда гирифта шудааст, на дастӣ навишта.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_settings.dart';
import 'package:raonson/core/i18n/strings.dart';
import 'package:raonson/feed_ai/ai_feed_repository.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsState.instance.setLang('tj');
  });

  test('профили корбари нав — ҳама мавзӯъ бо холи сифр', () {
    // Ҷавоби воқеии GET /feed/preferences барои корбари нав.
    const raw = '''
    {"languages":[],"preferLocal":false,"preferOriginal":false,
     "preferFollowing":false,"fewerRecommendations":false,
     "topics":[{"slug":"anime","nameTj":"Аниме","nameRu":"Аниме",
                "nameEn":"Anime","score":0,"source":""}],
     "mutedCreators":0,"boostedCreators":0}''';
    final p = FeedPrefs.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(p.topics.length, 1);
    expect(p.topics.first.score, 0);
    expect(p.topics.first.isExplicit, isFalse);
    expect(p.fewerRecs, isFalse);
  });

  test('мавзӯи возеҳан интихобшуда', () {
    const raw = '''
    {"slug":"gaming","nameTj":"Бозиҳо","nameRu":"Игры","nameEn":"Gaming",
     "score":0.8,"source":"explicit"}''';
    final t = FeedTopic.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(t.score, 0.8);
    expect(t.isExplicit, isTrue);
    expect(t.name('tj'), 'Бозиҳо');
    expect(t.name('ru'), 'Игры');
    expect(t.name('en'), 'Gaming');
  });

  test('номи мавзӯъ ба забони мавҷуда бармегардад', () {
    const t = FeedTopic(
        slug: 'x', nameTj: 'Тоҷикӣ', nameRu: '', nameEn: 'English',
        score: 0, source: '');
    // Русӣ холист — ба англисӣ бармегардад, на сатри холӣ.
    expect(t.name('ru'), 'English');
  });

  group('шарҳи «Чаро инро мебинам?»', () {
    test('сабабҳо аз сигнали воқеӣ', () {
      // Ҷавоби воқеии сервер аз санҷиши зинда.
      const raw = '''
      {"reasons":[{"code":"topicExplicit","params":{"topic":"gaming"},
                   "strength":40}],"personalized":true}''';
      final e =
          FeedExplanation.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      expect(e.personalized, isTrue);
      expect(e.reasons.single.code, 'topicExplicit');
      expect(e.reasons.single.params['topic'], 'gaming');
    });

    test('бе сигнал — шарҳ холӣ ва personalized=false', () {
      const raw = '{"reasons":[],"personalized":false}';
      final e =
          FeedExplanation.fromJson(jsonDecode(raw) as Map<String, dynamic>);

      expect(e.reasons, isEmpty);
      // Муҳим: интерфейс бояд «мӯҳтавои маъмул» гӯяд, на сабаб ихтироъ кунад.
      expect(e.personalized, isFalse);
    });

    test('ҳар рамзи сабаб тарҷума дорад', () {
      for (final code in [
        'following',
        'creatorLearned',
        'creatorExplicit',
        'topicLearned',
        'topicExplicit',
        'similarEngagement',
      ]) {
        final text = tr('aifeed.why.$code', {'topic': 'gaming', 'count': 3});
        expect(text, isNot(equals('aifeed.why.$code')),
            reason: 'тарҷумаи $code нест');
        expect(text.contains('{'), isFalse,
            reason: 'ҷойгири пуркарданашуда дар $code: $text');
      }
    });
  });

  test('эҷодкори пешниҳодшуда', () {
    // Ҷавоби воқеии POST /feed/find-people.
    const raw = '''
    {"userId":"5b13591f","username":"feeduser","avatar":"","bio":"",
     "verified":false,"followersCount":0,"topics":["gaming"],
     "similarity":100,"sharedTopics":["gaming"]}''';
    final p = SuggestedPerson.fromJson(jsonDecode(raw) as Map<String, dynamic>);

    expect(p.username, 'feeduser');
    expect(p.similarity, 100);
    expect(p.sharedTopics, ['gaming']);
  });

  test('ҷавоби нопурра ба крах намеорад', () {
    final p = FeedPrefs.fromJson(<String, dynamic>{});
    expect(p.topics, isEmpty);
    expect(p.languages, isEmpty);

    final t = FeedTopic.fromJson(<String, dynamic>{});
    expect(t.score, 0);
    expect(t.slug, '');

    final e = FeedExplanation.fromJson(<String, dynamic>{});
    expect(e.reasons, isEmpty);
    expect(e.personalized, isFalse);
  });

  group('тарҷумаҳо', () {
    test('сатрҳои асосӣ дар ҳар се забон ҳастанд', () async {
      const keys = [
        'aifeed.title',
        'aifeed.subtitle',
        'aifeed.moreLikeThis',
        'aifeed.lessLikeThis',
        'aifeed.whyTitle',
        'aifeed.whyNoData',
        'aifeed.findPeople',
        'aifeed.reset',
        'aifeed.resetConfirm',
      ];
      for (final lang in ['tj', 'ru', 'en']) {
        await AppSettingsState.instance.setLang(lang);
        for (final k in keys) {
          final v = tr(k);
          expect(v, isNot(equals(k)), reason: '$k дар $lang нест');
          expect(v.trim(), isNotEmpty, reason: '$k дар $lang холӣ');
        }
      }
    });

    test('фоизи монандӣ параметр мегирад', () {
      expect(tr('aifeed.similarity', {'n': 92}), contains('92'));
      expect(tr('aifeed.similarity', {'n': 92}).contains('{'), isFalse);
    });
  });
}
