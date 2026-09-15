// test/ads_debug_test.dart
// Ҳолати ташхиси реклама.
//
// Ҳадаф: вақте реклама намебарояд, сабаб бояд ДИДА шавад. Пештар
// ҳамаи хатоҳо хомӯшона фурӯ бурда мешуданд.
import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/ads/ads_manager.dart';

void main() {
  group('ҳолати шакли реклама', () {
    test('ҳолати пешфарз — тайёр НЕСТ, на «тайёр»', () {
      const s = AdSlotStatus(name: 'Rewarded', unitId: 'R-M-1');
      expect(s.ready, isFalse);
      expect(s.loading, isFalse);
      expect(s.lastError, isEmpty);
      expect(s.loadAttempts, 0);
      expect(s.loadFailures, 0);
      expect(s.shows, 0);
    });

    test('хато нигоҳ дошта мешавад', () {
      const s = AdSlotStatus(
        name: 'Rewarded',
        unitId: 'R-M-1',
        lastError: 'No fill',
        loadFailures: 3,
      );
      expect(s.lastError, 'No fill');
      expect(s.loadFailures, 3);
    });
  });

  group('AdsManager', () {
    test('ҳар ду шакл дар ҳолат ҳастанд', () {
      final st = AdsManager.instance.statuses();
      expect(st.length, 2);
      expect(st.map((e) => e.name), containsAll(['Interstitial', 'Rewarded']));
      for (final s in st) {
        expect(s.unitId, isNotEmpty, reason: '${s.name} бе ID');
      }
      // Дар build-и санҷишӣ ҳамеша шиносаи ДЕМО истифода мешавад:
      // шиносаи production дигар дар код нест (ниг. ad_config.dart).
      for (final s in st) {
        expect(s.unitId, contains('demo'),
            reason: '${s.name}: дар тест шиносаи ғайридемо');
        expect(s.unitId, isNot(startsWith('R-M-')),
            reason: '${s.name}: шиносаи production дар код монд');
      }
    });

    test('бе оғоз SDK «оғозшуда» нишон намедиҳад', () {
      // Дар муҳити тест SDK оғоз намешавад — ва ҳолат бояд инро
      // рост бигӯяд, на «ҳама хуб».
      expect(AdsManager.instance.isInitialized, isFalse);
    });

    test('шиносаи корбар қабул мешавад', () {
      // Худи арзиш хонда намешавад (хусусӣ аст) — муҳим ин аст, ки
      // даъват хато намедиҳад ва ҳолат вайрон намешавад.
      AdsManager.instance.setUserId('user-123');
      expect(AdsManager.instance.statuses().length, 2);
    });
  });
}
