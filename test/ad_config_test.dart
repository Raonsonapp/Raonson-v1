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
import 'dart:convert';
import 'dart:io';

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
    // Ин тестҳо ду ҳолати ҷудогонаро месанҷанд ва ҳарду муҳиманд:
    //
    //   flutter test
    //     → --dart-define нест. Бояд ҳеҷ шиноса набошад.
    //
    //   flutter test --dart-define-from-file=dart_defines/ad_units.json
    //     → маҳз ҳамон шиносаҳои build-и production.
    //
    // Онҳо ҳангоми сохтан муайян мешаванд, аз ин рӯ `skip` аз рӯи
    // худи арзиш ҳисоб мешавад.
    const rewarded = String.fromEnvironment('YANDEX_REWARDED_ID');
    const interstitial = String.fromEnvironment('YANDEX_INTERSTITIAL_ID');
    final defined = rewarded.isNotEmpty;

    setUp(() => AdConfig.isDebugBuild = false);

    test('ҳеҷ гоҳ ба шиносаи демо намеафтад', () {
      // Ин дар ҳар ду ҳолат дуруст аст.
      for (final f in AdFormat.values) {
        expect(AdConfig.describe(f), isNot(contains('demo')),
            reason: '$f дар release демо гирифт');
      }
    });

    group('бе --dart-define', () {
      test('шиноса НЕСТ, на демо', () {
        for (final f in AdFormat.values) {
          final id = AdConfig.idFor(f);
          expect(id, isNull, reason: '$f: шиносаи ғайричашмдошт $id');
        }
      });

      test('набудани шиноса возеҳ эълон мешавад', () {
        expect(AdConfig.isFullyConfigured, isFalse);
        expect(AdConfig.missing.length, AdFormat.values.length);
        expect(AdConfig.describe(AdFormat.rewarded), 'not configured');
      });
    }, skip: defined ? 'шиносаҳо ҳангоми сохтан дода шуданд' : null);

    group('бо --dart-define', () {
      test('маҳз ҳамон шиносаи додашуда истифода мешавад', () {
        expect(AdConfig.idFor(AdFormat.rewarded), rewarded);
        expect(AdConfig.idFor(AdFormat.interstitial), interstitial);
      });

      test('экрани ташхис шиносаи хомро нишон медиҳад', () {
        // Экран `AdConfig.describe` -ро чоп мекунад. Дар release
        // он бояд худи шиноса бошад — бе «(demo)» ва бе «not
        // configured».
        expect(AdConfig.describe(AdFormat.rewarded), rewarded);
        expect(AdConfig.describe(AdFormat.rewarded), isNot(contains('(')));
      });

      test('ҳеҷ шакл бе шиноса намемонад', () {
        expect(AdConfig.missing, isEmpty);
        expect(AdConfig.isFullyConfigured, isTrue);
      });

      test('арзиш аз файли танзимот мегузарад', () {
        // Ду санҷиши болоӣ ҳарду аз ҳамон --dart-define мехонанд,
        // пас онҳо худ ба худро тасдиқ мекунанд. Ин ҷо файл аз диск
        // мустақилона хонда мешавад: файл → --dart-define → AdConfig.
        final fromFile = jsonDecode(
                File('dart_defines/ad_units.json').readAsStringSync())
            as Map<String, dynamic>;

        expect(AdConfig.idFor(AdFormat.rewarded),
            fromFile['YANDEX_REWARDED_ID']);
        expect(AdConfig.idFor(AdFormat.interstitial),
            fromFile['YANDEX_INTERSTITIAL_ID']);
        expect(AdConfig.idFor(AdFormat.banner), fromFile['YANDEX_BANNER_ID']);
        expect(AdConfig.idFor(AdFormat.nativeFeed),
            fromFile['YANDEX_NATIVE_FEED_ID']);
      });
    }, skip: defined ? null : '--dart-define дода нашуд');
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
