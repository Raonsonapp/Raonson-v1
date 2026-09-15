// test/ad_config_test.dart
// Шиносаҳои реклама.
//
// Ду хатои гарон вуҷуд дорад:
//
//  1. Дар release шиносаи ДЕМО истифода шавад — рекламаи санҷишӣ ба
//     корбарони воқеӣ меравад, даромад сифр аст, вале ҳама чиз
//     «кор мекунад» менамояд.
//
//  2. Шиносаи НАБУДА фиристода шавад — маҳз ҳамин дар дастгоҳ рӯй
//     дод: «Provided AdUnitId does not exist!»
import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/ads/ad_config.dart';

void main() {
  tearDown(() {
    // Ҳолати воқеии build барқарор карда мешавад.
    AdConfig.isDebugBuild = true;
  });

  group('build-и debug', () {
    setUp(() => AdConfig.isDebugBuild = true);

    test('шиносаҳои демои Yandex истифода мешаванд', () {
      expect(AdConfig.idFor(AdFormat.rewarded), 'demo-rewarded-yandex');
      expect(AdConfig.idFor(AdFormat.interstitial),
          'demo-interstitial-yandex');
      expect(AdConfig.idFor(AdFormat.banner), 'demo-banner-yandex');
      expect(AdConfig.idFor(AdFormat.nativeFeed),
          'demo-native-content-yandex');
    });

    test('ҳар шакл шиноса дорад', () {
      expect(AdConfig.isFullyConfigured, isTrue);
      expect(AdConfig.missing, isEmpty);
    });

    test('матн возеҳ мегӯяд, ки ин демо аст', () {
      expect(AdConfig.describe(AdFormat.rewarded), contains('demo'));
    });
  });

  group('build-и release', () {
    setUp(() => AdConfig.isDebugBuild = false);

    // Дар ин муҳит --dart-define дода нашудааст, бинобар ин ҳамаи
    // шиносаҳои production холианд.
    test('бе --dart-define шиноса НЕСТ, на демо', () {
      for (final f in AdFormat.values) {
        final id = AdConfig.idFor(f);
        expect(id, isNull, reason: '$f: шиносаи ғайричашмдошт $id');
      }
    });

    test('ҳеҷ гоҳ ба шиносаи демо намеафтад', () {
      for (final f in AdFormat.values) {
        expect(AdConfig.describe(f), isNot(contains('demo')),
            reason: '$f дар release демо гирифт');
      }
    });

    test('набудани шиноса возеҳ эълон мешавад', () {
      expect(AdConfig.isFullyConfigured, isFalse);
      expect(AdConfig.missing.length, AdFormat.values.length);
      expect(AdConfig.describe(AdFormat.rewarded), 'not configured');
    });
  });

  group('шиносаҳои сохта', () {
    test('ҳеҷ шиносаи R-M-... дар код нест', () {
      // Шиносаи Rewarded-и қаблӣ (R-M-19230220-2) дар кабинети
      // Yandex вуҷуд надошт. Шиносаи воқеӣ бояд ҳангоми сохтан
      // дода шавад, на дар код навишта шавад.
      AdConfig.isDebugBuild = true;
      for (final f in AdFormat.values) {
        expect(AdConfig.idFor(f), isNot(startsWith('R-M-')),
            reason: '$f: шиносаи production дар код');
      }
    });
  });
}
