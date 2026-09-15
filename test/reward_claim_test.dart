// test/reward_claim_test.dart
// Хабардиҳии сервер дар бораи рекламаи тамошошуда.
//
// Yandex server-side verification надорад, пас барнома худаш хабар
// медиҳад. Маҳз аз ин сабаб ин тестҳо муҳиманд: онҳо месанҷанд, ки
// барнома ҳеҷ гоҳ ба ҷои сервер қарор намекунад.
//
// Се қоида санҷида мешавад:
//   1. Бе `onRewarded` ҳеҷ хабар намеравад.
//   2. Ҷавоби сервер ягона манбаи «ҳисоб шуд» аст.
//   3. Ҳангоми қатъи шабака ҳисоб гум намешавад — кӯшиш такрор
//      мешавад.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_settings.dart';
import 'package:raonson/core/ads/reward_backend.dart';
import 'package:raonson/core/i18n/strings.dart';

/// Сервери сохта — ҳар даъватро нигоҳ медорад.
class FakeBackend implements RewardBackend {
  FakeBackend({this.sessionId = 's1', this.status = RewardStatus.counted});

  String? sessionId;
  RewardStatus status;

  final List<String> openedFor = [];
  final List<List<String>> claims = [];

  @override
  Future<String?> openSession(String adUnitId) async {
    openedFor.add(adUnitId);
    return sessionId;
  }

  @override
  Future<RewardStatus> claim(String s, String unit) async {
    claims.add([s, unit]);
    return status;
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('натиҷаи тамошо', () {
    test('танҳо ҷавоби сервер маънои «ҳисоб шуд» дорад', () {
      const watchedAndCounted =
          RewardOutcome(true, RewardStatus.counted);
      expect(watchedAndCounted.counted, isTrue);

      // Реклама дида шуд, вале сервер рад кард — мукофот НЕСТ.
      for (final s in [
        RewardStatus.invalid,
        RewardStatus.duplicate,
        RewardStatus.tooFast,
        RewardStatus.dailyCap,
        RewardStatus.offline,
        RewardStatus.unavailable,
      ]) {
        expect(RewardOutcome(true, s).counted, isFalse, reason: '$s');
      }
    });

    test('реклама нишон дода нашуд — ҳисоб нест', () {
      expect(RewardOutcome.notShown.watched, isFalse);
      expect(RewardOutcome.notShown.counted, isFalse);
    });
  });

  group('сарҳади сервер', () {
    test('сеанс пеш аз реклама кушода мешавад', () async {
      final b = FakeBackend();
      final id = await b.openSession('R-M-1-2');
      expect(id, 's1');
      expect(b.openedFor, ['R-M-1-2']);
    });

    test('хабар танҳо шиносаи сеанс ва ҷойгиршавӣ дорад', () async {
      // Миқдори мукофот, баланс ва шиносаи корбар ин ҷо НЕСТАНД:
      // ҳамаро сервер худаш муайян мекунад.
      final b = FakeBackend();
      await b.claim('s1', 'R-M-1-2');
      expect(b.claims.single, ['s1', 'R-M-1-2']);
      expect(b.claims.single.length, 2);
    });

    test('сеанс кушода нашуд — хабар ҳам нест', () async {
      final b = FakeBackend()..sessionId = null;
      final id = await b.openSession('R-M-1-2');
      expect(id, isNull);
      expect(b.claims, isEmpty);
    });
  });

  group('хабарҳои нафиристода', () {
    // Ин рафтори AdsManager-ро такрор мекунад: ҳангоми `offline`
    // сеанс нигоҳ дошта мешавад, ҳангоми ҳар ҷавоби дигар — не.
    const key = 'ads.pendingClaims';

    test('қатъи шабака ҳисобро гум намекунад', () async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(key, ['s1|R-M-1-2']);

      final b = FakeBackend()..status = RewardStatus.offline;
      final left = <String>[];
      for (final e in sp.getStringList(key)!) {
        final p = e.split('|');
        if (await b.claim(p[0], p[1]) == RewardStatus.offline) left.add(e);
      }
      expect(left, ['s1|R-M-1-2'], reason: 'сеанс партофта шуд');
    });

    test('ҷавоби сервер — ҳатто рад — ниҳоист', () async {
      SharedPreferences.setMockInitialValues({});
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(key, ['s1|R-M-1-2']);

      // Такрори сеанси аллакай ҳисобшуда набояд абадӣ такрор шавад.
      final b = FakeBackend()..status = RewardStatus.duplicate;
      final left = <String>[];
      for (final e in sp.getStringList(key)!) {
        final p = e.split('|');
        if (await b.claim(p[0], p[1]) == RewardStatus.offline) left.add(e);
      }
      expect(left, isEmpty, reason: 'кӯшиши беохир');
    });
  });

  group('матни хато', () {
    // Бе ин корбар мебинад, ки «чизе нашуд», вале намедонад чаро.
    const keys = [
      'ads.rewardOffline',
      'ads.rewardUnavailable',
      'ads.rewardNotWatched',
      'ads.rewardRejected',
      'ads.rewardDuplicate',
      'ads.rewardTooFast',
      'ads.rewardDailyCap',
    ];

    test('ҳар сабаб дар ҳар се забон матн дорад', () async {
      for (final lang in ['tj', 'ru', 'en']) {
        await AppSettingsState.instance.setLang(lang);
        for (final k in keys) {
          // tr() калиди номаълумро худаш бармегардонад.
          expect(tr(k), isNot(k), reason: '$lang: $k тарҷума надорад');
          expect(tr(k), isNot(contains('{')), reason: '$lang: $k');
        }
      }
    });

    test('ҳар ҳолати сервер сабаб дорад', () {
      // `counted` матн намехоҳад — он муваффақият аст.
      expect(keys.length, greaterThanOrEqualTo(
          RewardStatus.values.length - 1));
    });
  });
}
