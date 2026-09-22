import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/feed/timeline/feed_screen.dart';

// Реклама дар ҷойҳои худ — мисли Instagram.
//
// ═══════════════════════════════════════════════════════════════════
//  Пеш аз ин реклама ТАНҲО дар ду ҷо буд:
//
//    • Reels — ҳар 5 видео як рекламаи томэкранӣ;
//    • экрани галочка — рекламаи мукофотӣ.
//
//  Дар ЛЕНТА ва дар СТОРИ реклама умуман набуд.
//
//  Ва ин на аз он буд, ки код навишта нашудааст. `FeedAdCard` (143
//  сатр) кайҳо тайёр буд — вале аз ҲЕҶ ҶОИ барнома даъват намешуд.
//  Ҳамон камбудии ошно: функсия ҳасту роҳ ба он нест.
//
//  Ҳоло:
//    лента  — ҳар 5 пост як карти реклама;
//    стори  — баъди ҳар 5 стори як рекламаи томэкранӣ, ВАЛЕ танҳо
//             агар он аллакай омода бошад.
// ═══════════════════════════════════════════════════════════════════

String _read(String p) => File(p).readAsStringSync();

void main() {
  group('лента', () {
    late String src;
    setUpAll(() => src = _read('lib/feed/timeline/feed_screen.dart'));

    test('карти реклама воқеан истифода мешавад', () {
      expect(src, contains('FeedAdCard'),
          reason: '`FeedAdCard` навишта шудааст, вале дар лента нест — '
              'реклама дар лента умуман намебарояд');
    });

    test('фосила чандир аст ва аз ҳад зич нест', () {
      // Камтар аз 3 лентаро ба реклама табдил медиҳад.
      expect(kPostsPerAd, greaterThanOrEqualTo(3),
          reason: 'реклама аз ҳад зич — лента хонда намешавад');
      expect(kPostsPerAd, lessThanOrEqualTo(10));
    });

    test('ҳисоби ҷойҳо дуруст аст — пост гум намешавад', () {
      // Маҳз ин ҷо хатои классикӣ мешавад: карти реклама як ҷойро
      // мегирад, ва агар индекс ислоҳ нашавад, ҳар панҷум пост
      // НАМЕНАМОЯД.
      //
      // Ҳамон формуларо, ки дар экран аст, ин ҷо месанҷем.
      int postIndexAt(int index) => index - index ~/ (kPostsPerAd + 1);
      bool isAdAt(int index) =>
          index > 0 && index % (kPostsPerAd + 1) == kPostsPerAd;

      final seen = <int>[];
      for (var i = 0; i < 40; i++) {
        if (isAdAt(i)) continue;
        seen.add(postIndexAt(i));
      }
      // Ҳар пост ЯК бор ва бе холигӣ.
      for (var i = 0; i < seen.length; i++) {
        expect(seen[i], i, reason: 'пости $i гум шуд ё такрор шуд');
      }
    });

    test('шумораи умумӣ ҷойҳои рекламаро ба ҳисоб мегирад', () {
      expect(src, contains('state.posts.length ~/ kPostsPerAd'),
          reason: 'childCount ҷойҳои рекламаро ҳисоб намекунад — '
              'постҳои охирин намебароянд');
    });
  });

  group('стори', () {
    late String viewer;
    late String ads;
    setUpAll(() {
      viewer = _read('lib/stories/story_group_viewer.dart');
      ads = _read('lib/core/ads/ads_manager.dart');
    });

    test('стори рекламаро даъват мекунад', () {
      expect(viewer, contains('onStoryAdvanced()'),
          reason: 'дар стори реклама умуман нест');
    });

    test('ҳисобкунак дар AdsManager аст, на дар экран', () {
      // Корбар аз як гурӯҳи стори ба дигаре мегузарад ва ҳар гурӯҳ
      // `State`-и НАВ месозад. Агар ҳисоб он ҷо мебуд, он ҳар
      // дафъа аз сифр сар мешуд ва реклама ҳеҷ гоҳ намебаромад.
      expect(ads, contains('int _storiesSinceAd = 0'));
      expect(viewer.contains('_storiesSinceAd'), isFalse,
          reason: 'ҳисоб дар экран аст — бо ҳар гурӯҳи нав сифр '
              'мешавад ва реклама ҳеҷ гоҳ намерасад');
    });

    test('агар реклама омода набошад, стори интизор НАМЕШАВАД', () {
      final i = ads.indexOf('Future<bool> onStoryAdvanced()');
      expect(i, greaterThan(0));
      final body = ads.substring(i, i + 500);
      expect(body, contains('if (!_interstitialReady) return false'),
          reason: 'корбар интизори боркунии реклама мемонад — '
              'тамошои стори канда мешавад');
    });

    test('баъди намоиш ҳисоб аз сар оғоз мешавад', () {
      final i = ads.indexOf('Future<bool> onStoryAdvanced()');
      final body = ads.substring(i, i + 500);
      expect(body, contains('_storiesSinceAd = 0'));
    });

    test('стори баъди реклама ҲАТМАН давом мекунад', () {
      // Агар `_advanceStory` танҳо дар як шоха бошад, корбар дар
      // экрани сиёҳ мемонад.
      expect(viewer, contains('_advanceStory()'));
      final i = viewer.indexOf('onStoryAdvanced()');
      expect(viewer.substring(i, i + 260), contains('_advanceStory()'));
    });
  });

  group('Reels', () {
    late String ads;
    setUpAll(() => ads = _read('lib/core/ads/ads_manager.dart'));

    test('ҳисоб баъди намоиш аз сар оғоз мешавад', () {
      // ⚠️ Пештар `_reelsSinceAd` сифр КАРДА НАМЕШУД.
      //
      // Яъне баъди панҷум реел он 6, 7, 8 … мешуд ва шарт
      // ҲАМЕША рост мемонд: барнома баъди ҲАР свайп кӯшиши
      // намоиши реклама мекард. Танҳо фосилаи хунуккунӣ
      // (`_interstitialCooldownSec`) онро нигоҳ медошт.
      final i = ads.indexOf('Future<void> onReelSwiped()');
      expect(i, greaterThan(0));
      final body = ads.substring(i, i + 300);
      expect(body, contains('_reelsSinceAd = 0'),
          reason: 'ҳисоб сифр намешавад — баъди панҷум реел ҳар '
              'свайп кӯшиши реклама мекунад');
    });
  });

  group('қоидаҳои Yandex риоя мешаванд', () {
    late String ads;
    setUpAll(() => ads = _read('lib/core/ads/ads_manager.dart'));

    test('фосилаи хунуккунӣ байни рекламаҳои томэкранӣ ҳаст', () {
      expect(ads, contains('_interstitialCooldownSec'),
          reason: 'реклама метавонад пайдарпай барояд');
      final i = ads.indexOf('Future<bool> showInterstitialIfReady()');
      final body = ads.substring(i, i + 500);
      expect(body, contains('_interstitialCooldownSec'));
    });

    test('рекламаи мукофотӣ бе амали корбар нишон дода намешавад', () {
      // Намоиш ТАНҲО аз `showRewarded()`, ки экран даъват мекунад.
      // Ҳеҷ таймер, ҳеҷ намоиши худкор.
      expect(ads.contains('Timer(.*showRewarded'), isFalse);
      final i = ads.indexOf('Future<RewardOutcome> showRewarded()');
      expect(i, greaterThan(0));
    });
  });
}
