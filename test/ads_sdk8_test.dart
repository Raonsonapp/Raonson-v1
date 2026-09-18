// test/ads_sdk8_test.dart
// Гузариш ба Yandex Mobile Ads SDK 8.4.0.
//
// Дастгирии Yandex гуфт: «реклама подбирается» танҳо аз нусхаи
// 8.4.0. Ин тестҳо нигоҳ медоранд, ки гузариш ПУРРА бошад ва
// касе тасодуфан ба API-и SDK 7 барнагардад.
//
// SDK 8 ин чизҳоро ИВАЗ кард (CHANGELOG 8.0.0):
//   MobileAds              → YandexAds
//   AdRequestConfiguration → AdRequest
//   Loader.create()        → конструктори ҳамзамон
//   loadAd(callbacks)      → Future<Ad>, хато ҳамчун истисно
//   BannerAd(callbacks)    → load() + loadStateStream
//   setLocationConsent     → setLocationTracking
//   setAgeRestrictedUser   → setAgeRestricted
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Map<String, String> adFiles;

  setUpAll(() {
    adFiles = {
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          f.path.replaceAll(r'\', '/'): f.readAsStringSync(),
    }..removeWhere((_, code) => !code.contains('yandex_mobileads'));
  });

  group('нусхаи вобастагӣ', () {
    // ⚠️ «НА КАМТАР АЗ», на «МАҲЗ».
    //
    // Дастгирии Yandex гуфт: реклама АЗ 8.4.0 САР КАРДА мувофиқ
    // мешавад. Санҷиши қаблӣ баробариро талаб мекард ва ҳамон рӯзе
    // шикаст, ки Yandex 8.5.0-ро баровард — дар ҳоле ки 8.5.0
    // талабро пурра иҷро мекунад.
    //
    // `pubspec.lock` дар анбор нест, пас CI ҳар бор нусхаи
    // навтаринро ҳал мекунад. Бо санҷиши «маҳз» ҳар барориши нави
    // Yandex build-ро мешикаст.
    const minVersion = [8, 4, 0];

    List<int> parseVersion(String v) => v
        .split(RegExp(r'[-+]'))
        .first
        .split('.')
        .map((x) => int.tryParse(x) ?? 0)
        .toList();

    bool atLeastMin(String v) {
      final got = parseVersion(v);
      for (var i = 0; i < minVersion.length; i++) {
        final a = i < got.length ? got[i] : 0;
        if (a != minVersion[i]) return a > minVersion[i];
      }
      return true;
    }

    test('pubspec ҳадди ақал 8.4.0-ро талаб мекунад', () {
      final spec = File('pubspec.yaml').readAsStringSync();
      final m = RegExp(r'yandex_mobileads:\s*\^?([0-9.]+)').firstMatch(spec);
      expect(m, isNotNull, reason: 'вобастагӣ дар pubspec.yaml нест');
      expect(atLeastMin(m!.group(1)!), isTrue,
          reason: 'pubspec нусхаи ${m.group(1)}-ро талаб мекунад, '
              'на камтар аз 8.4.0 лозим');
    });

    test('нусхаи ҲАЛШУДА на камтар аз 8.4.0 аст', () {
      // pubspec.yaml танҳо талаб аст. Нусхаи воқеӣ дар lock аст.
      final lock = File('pubspec.lock').readAsStringSync();
      final i = lock.indexOf('  yandex_mobileads:');
      expect(i, greaterThan(-1), reason: 'дар lock нест');
      final block = lock.substring(i, (i + 300).clamp(i, lock.length));
      final m = RegExp(r'version: "([^"]+)"').firstMatch(block);
      expect(m, isNotNull, reason: 'нусха дар lock хонда нашуд: $block');
      expect(atLeastMin(m!.group(1)!), isTrue,
          reason: 'нусхаи ҳалшуда ${m.group(1)} аст, '
              'на камтар аз 8.4.0 лозим');
    });

    test('SDK-и НАТИВ низ на камтар аз 8.4.0 аст', () {
      // Плагин ва SDK-и натив нусхаҳои ҷудогона доранд — дастгирии
      // Yandex маҳз дар бораи SDK-и натив гап мезад.
      final gradle = File('${_pluginRoot()}/android/build.gradle')
          .readAsStringSync();
      final m = RegExp(r'com\.yandex\.android:mobileads:([0-9.]+)')
          .firstMatch(gradle);
      expect(m, isNotNull, reason: 'нусхаи SDK-и натив ёфт нашуд');
      expect(atLeastMin(m!.group(1)!), isTrue,
          reason: 'SDK-и натив ${m.group(1)} аст, на камтар аз 8.4.0 лозим');
    });

    test('муқоиса рақамӣ аст, на сатрӣ', () {
      // '8.10.0' < '8.4.0' ҳамчун САТР дуруст аст — ва ин камбудии
      // ниҳонӣ мебуд, ки танҳо баъди барориши 8.10 пайдо мешуд.
      expect(atLeastMin('8.10.0'), isTrue);
      expect(atLeastMin('9.0.0'), isTrue);
      expect(atLeastMin('8.5.0'), isTrue);
      expect(atLeastMin('8.4.0'), isTrue);
      expect(atLeastMin('8.3.9'), isFalse);
      expect(atLeastMin('7.18.0'), isFalse);
    });
  });

  group('API-и SDK 7 дигар истифода намешавад', () {
    test('MobileAds. боқӣ намондааст', () {
      final offenders = <String>[];
      adFiles.forEach((path, code) {
        for (final line in code.split('\n')) {
          if (line.trimLeft().startsWith('//')) continue;
          if (RegExp(r'\bMobileAds\.').hasMatch(line)) {
            offenders.add('$path: ${line.trim()}');
          }
        }
      });
      expect(offenders, isEmpty,
          reason: 'API-и SDK 7:\n${offenders.join('\n')}');
    });

    test('AdRequestConfiguration боқӣ намондааст', () {
      final offenders = <String>[];
      adFiles.forEach((path, code) {
        for (final line in code.split('\n')) {
          if (line.trimLeft().startsWith('//')) continue;
          if (line.contains('AdRequestConfiguration')) {
            offenders.add('$path: ${line.trim()}');
          }
        }
      });
      expect(offenders, isEmpty,
          reason: 'AdRequestConfiguration дар SDK 8 нест:\n'
              '${offenders.join('\n')}');
    });

    test('Loader.create() боқӣ намондааст', () {
      adFiles.forEach((path, code) {
        for (final line in code.split('\n')) {
          if (line.trimLeft().startsWith('//')) continue;
          expect(line, isNot(contains('AdLoader.create(')), reason: path);
        }
      });
    });

    test('BannerAd дигар callback қабул намекунад', () {
      // Дар SDK 8 конструктор танҳо андозаро мегирад.
      adFiles.forEach((path, code) {
        if (!code.contains('BannerAd(')) return;
        expect(code, contains('BannerAd(adSize:'), reason: path);
        expect(code, isNot(contains('adRequest:')), reason: path);
      });
    });
  });

  group('API-и нав дуруст истифода мешавад', () {
    test('баннер ба stream обуна мешавад ва баъд load мекунад', () {
      for (final path in [
        'lib/core/ads/ad_banner_widget.dart',
        'lib/core/ads/feed_ad_card.dart',
      ]) {
        final code = adFiles[path];
        expect(code, isNotNull, reason: '$path yandex-ро истифода намебарад');
        expect(code, contains('loadStateStream.listen'), reason: path);
        expect(code, contains('BannerAdLoadStateLoaded'), reason: path);
        expect(code, contains('BannerAdLoadStateError'), reason: path);
        expect(code, contains('ad.load(AdRequest(adUnitId: unitId))'),
            reason: path);
      }
    });

    test('обуна ҳангоми dispose бекор мешавад', () {
      // Бе ин, ҳар бор кушодани экран як обунаи нав мемонад.
      for (final path in [
        'lib/core/ads/ad_banner_widget.dart',
        'lib/core/ads/feed_ad_card.dart',
      ]) {
        expect(adFiles[path], contains('_sub?.cancel();'), reason: path);
        expect(adFiles[path], contains('_bannerAd?.destroy();'), reason: path);
      }
    });

    test('нокомии боркунӣ ҳамчун истисно гирифта мешавад', () {
      // SDK 8 хаторо бо `throw` медиҳад, на бо callback.
      final code = adFiles['lib/core/ads/ads_manager.dart']!;
      expect(code, contains('.catchError((Object error)'),
          reason: 'нокомии боркунӣ гирифта намешавад');
    });
  });

  _demoModeTests();

  group('шиносаҳо пас аз гузариш', () {
    test('ҳар чор шиноса бетағйир мондаанд', () {
      final units = jsonDecode(
              File('dart_defines/ad_units.json').readAsStringSync())
          as Map<String, dynamic>;
      expect(units['YANDEX_INTERSTITIAL_ID'], 'R-M-19230220-1');
      expect(units['YANDEX_REWARDED_ID'], 'R-M-19230220-2');
      expect(units['YANDEX_BANNER_ID'], 'R-M-19230220-3');
      expect(units['YANDEX_NATIVE_FEED_ID'], 'R-M-19230220-4');
    });

    test('шиносаи корбар ба Yandex намеравад', () {
      // SDK 8 `AdRequest.parameters`-ро нигоҳ дошт — бояд холӣ монад.
      adFiles.forEach((path, code) {
        for (final line in code.split('\n')) {
          if (line.trimLeft().startsWith('//')) continue;
          expect(line, isNot(contains('parameters:')), reason: path);
        }
      });
    });
  });
}

/// Роҳи плагини ҳалшуда аз package_config.json.
String _pluginRoot() {
  final cfg = jsonDecode(
          File('.dart_tool/package_config.json').readAsStringSync())
      as Map<String, dynamic>;
  final pkg = (cfg['packages'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((p) => p['name'] == 'yandex_mobileads');
  return Uri.parse(pkg['rootUri'] as String).toFilePath();
}

// ── Режими демо барои ташхиси дастгирии Yandex ─────────────────
//
// Дастгирии Yandex санҷиши блокҳои демоеро талаб кард. Хатари
// асосӣ ин аст, ки шиносаи демо ба build-и release дарояд: он
// рекламаи санҷиширо ба корбарони воқеӣ нишон медиҳад ва ҳеҷ
// даромад намедиҳад — вале «кор мекунад» менамояд.
void _demoModeTests() {
  late String config;
  late String manager;
  late String screen;

  setUpAll(() {
    config = File('lib/core/ads/ad_config.dart').readAsStringSync();
    manager = File('lib/core/ads/ads_manager.dart').readAsStringSync();
    screen = File('lib/core/ads/ads_debug_screen.dart').readAsStringSync();
  });

  group('демо ба release намедарояд', () {
    test('шохаи демо бо kDebugMode маҳкам аст', () {
      // `isDebugBuild` майдони тағйирёбанда аст — танҳо он кифоя
      // нест. `kDebugMode` доимии вақти тарҷума аст, пас дар
      // release ин шоха умуман тарҷума намешавад.
      expect(config, contains('if (isDebugBuild && kDebugMode)'),
          reason: 'демо дар release дастрас мемонад');
    });

    test('ҳар ду функсияи демо kDebugMode-ро месанҷанд', () {
      for (final fn in ['Future<String> probeDemo(', 'Future<String> showDemo(']) {
        final i = manager.indexOf(fn);
        expect(i, greaterThan(-1), reason: '$fn нест');
        expect(manager.substring(i, i + 200), contains('if (!kDebugMode)'),
            reason: '$fn дар release кор мекунад');
      }
    });

    test('тугмаҳои демо дар release нишон дода намешаванд', () {
      expect(screen, contains('if (kDebugMode) ...['),
          reason: 'тугмаҳои демо дар release намоёнанд');
    });
  });

  group('шиносаҳои демо', () {
    test('маҳз шиносаҳои талабкардаи Yandex', () {
      expect(manager,
          contains("static const demoRewardedId = 'demo-rewarded-yandex'"));
      expect(
          manager,
          contains("static const demoInterstitialId = "
              "'demo-interstitial-yandex'"));
    });

    test('шиносаҳои production даст нахӯрдаанд', () {
      final units = jsonDecode(
              File('dart_defines/ad_units.json').readAsStringSync())
          as Map<String, dynamic>;
      expect(units['YANDEX_INTERSTITIAL_ID'], 'R-M-19230220-1');
      expect(units['YANDEX_REWARDED_ID'], 'R-M-19230220-2');
      expect(units['YANDEX_BANNER_ID'], 'R-M-19230220-3');
      expect(units['YANDEX_NATIVE_FEED_ID'], 'R-M-19230220-4');
    });

    test('демо ба ҷараёни мукофот дахл надорад', () {
      // showDemo набояд ба сервер хабар диҳад ё мукофот диҳад.
      final i = manager.indexOf('Future<String> showDemo(');
      final body = manager.substring(i, manager.indexOf('\n  }', i));
      for (final forbidden in [
        'rewardBackend',
        'openSession',
        'claim(',
        '_remember(',
      ]) {
        expect(body, isNot(contains(forbidden)),
            reason: 'санҷиши демо ба ҷараёни мукофот даст мерасонад: '
                '$forbidden');
      }
    });
  });
}
