// test/verification_test.dart
// Галочка ва реклама.
//
// Хатари асосӣ: рақами БАРДУРӮҒ. Ҳисоб дар сервер аст — барнома
// набояд онро худаш зиёд кунад ё пешрафти сохта нишон диҳад.
import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/verification/verification_screen.dart';

void main() {
  group('пешрафт аз сервер', () {
    test('ҷавоби сервер ҳамон тавр хонда мешавад', () {
      final p = AdProgress.fromJson(const {
        'watched': 150,
        'balance': 150,
        'today': 40,
        'dailyCap': 200,
        'remaining': 150,
        'goal': {'code': '3d', 'ads': 300, 'days': 3},
        'tiers': [
          {'code': '3d', 'ads': 300, 'days': 3},
          {'code': '7d', 'ads': 600, 'days': 7},
          {'code': '30d', 'ads': 1200, 'days': 30},
        ],
        'verified': false,
        'enabled': true,
      });
      expect(p.balance, 150);
      expect(p.goal.ads, 300);
      expect(p.tiers.length, 3);
      expect(p.fraction, closeTo(0.5, 0.001));
      expect(p.enabled, isTrue);
    });

    test('ҷавоби холӣ пешрафти бардурӯғ намедиҳад', () {
      final p = AdProgress.fromJson(const {});
      expect(p.balance, 0);
      expect(p.watched, 0);
      expect(p.fraction, 0);
      expect(p.verified, isFalse);
      // Муҳим: бе тасдиқи сервер «фаъол» нишон дода намешавад.
      expect(p.enabled, isFalse);
    });

    test('маълумоти вайрон ба крах намеорад', () {
      final p = AdProgress.fromJson(const {
        'balance': 'сад',
        'tiers': 'се зина',
        'goal': 'се рӯз',
        'verified': 'ҳа',
      });
      expect(p.balance, 0);
      expect(p.tiers, isEmpty);
      expect(p.goal.ads, 0);
      expect(p.verified, isFalse);
    });
  });

  group('нишондиҳии пешрафт', () {
    test('пешрафт ҳеҷ гоҳ аз 100% зиёд намешавад', () {
      final p = AdProgress.fromJson(const {
        'balance': 5000,
        'goal': {'code': '3d', 'ads': 300, 'days': 3},
      });
      expect(p.fraction, 1.0);
    });

    test('ҳадафи сифр ба тақсим бар сифр намебарад', () {
      final p = AdProgress.fromJson(const {
        'balance': 10,
        'goal': {'code': 'x', 'ads': 0, 'days': 0},
      });
      expect(p.fraction, 0);
      expect(p.fraction.isNaN, isFalse);
    });

    test('баланси манфӣ пешрафти манфӣ намедиҳад', () {
      final p = AdProgress.fromJson(const {
        'balance': -50,
        'goal': {'code': '3d', 'ads': 300, 'days': 3},
      });
      expect(p.fraction, greaterThanOrEqualTo(0));
    });
  });

  group('зинаҳо', () {
    test('зинаи калонтар барои як рӯз арзонтар аст', () {
      final p = AdProgress.fromJson(const {
        'tiers': [
          {'code': '3d', 'ads': 300, 'days': 3},
          {'code': '7d', 'ads': 600, 'days': 7},
          {'code': '30d', 'ads': 1200, 'days': 30},
        ],
      });
      for (var i = 1; i < p.tiers.length; i++) {
        final prev = p.tiers[i - 1].ads / p.tiers[i - 1].days;
        final cur = p.tiers[i].ads / p.tiers[i].days;
        expect(cur, lessThanOrEqualTo(prev),
            reason: 'зинаи ${p.tiers[i].code} фоида надорад');
      }
    });
  });
}
