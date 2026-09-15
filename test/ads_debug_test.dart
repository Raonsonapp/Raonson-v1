// test/ads_debug_test.dart
// Ҳолати ташхиси реклама.
//
// Ҳадаф: вақте реклама намебарояд, сабаб бояд ДИДА шавад. Пештар
// ҳамаи хатоҳо хомӯшона фурӯ бурда мешуданд.
import 'dart:io';

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

    test('шиносаи корбар ба Yandex ФИРИСТОДА НАМЕШАВАД', () {
      // Пештар шиносаи дохилии корбар ҳамчун
      // `parameters: {'user_id': ...}` ба ҳар дархости реклама
      // мерафт — бо умеди он ки Yandex онро ба callback-и сервер
      // бармегардонад.
      //
      // Чунин callback вуҷуд надорад: Yandex server-side
      // verification надорад, ва `parameters` дар SDK маънои
      // ҳадафгириро дорад. Пас он танҳо шиносаи корбарро бе ҳеҷ
      // фоида ба шабакаи бегона медод.
      // Худи механизм санҷида мешавад — `parameters:` дар
      // AdRequestConfiguration. Шарҳҳо ҳисоб намешаванд (онҳо маҳз
      // ҳамин таърихро нақл мекунанд), ва нишон додани шиносаи худи
      // корбар дар экрани ташхис низ дахл надорад: он аз дастгоҳ
      // берун намеравад.
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final code = f
            .readAsLinesSync()
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        if (code.contains('AdRequestConfiguration') &&
            code.contains('parameters:')) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'ба дархости реклама параметри иловагӣ меравад: $offenders');
    });
  });
}
