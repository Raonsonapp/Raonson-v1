import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/ads/feed_ad_card.dart';
import 'package:raonson/core/ads/ad_eligibility.dart';
import 'package:raonson/core/ads/ad_slot_layout.dart';
import 'package:raonson/core/ads/reels_ad_page.dart';
import 'package:raonson/core/ads/sponsored_ads.dart';
import 'package:raonson/core/ads/yandex_banner_slot.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visibility_detector/visibility_detector.dart';

// Реклама дар ҷойҳои худ — мисли Instagram.
//
// ═══════════════════════════════════════════════════════════════════
//  Соҳиб: «то X-ро зер накунӣ, видеои Reels намеояд — корбар маҷбур
//  аст рекламаро тамошо кунад. Мисли Instagram кун: рекламаро
//  гузаштан мумкин бошад».
//
//  Пештар:
//    • Reels — ҳар 5 видео рекламаи ТОМЭКРАНИИ interstitial;
//    • стори  — ҳар 5 стори рекламаи томэкранӣ;
//    • лента  — `FeedAdCard`, ки `AdWidget`-ро то «loaded» намесохт,
//      пас баннер ҳеҷ гоҳ бор намешуд.
//
//  Ҳоло:
//    • interstitial ҳеҷ ҷо худкор нишон дода намешавад;
//    • реклама — ҷойи оддии рӯйхат (пост ё саҳифаи Reels) бо
//      «Реклама», CTA ва менюи ⋯, ки корбар фавран мегузарад;
//    • VIP/Pro — ҳеҷ реклама.
//
//  Тестҳои пешинаи ин файл маҳз рафтори маҷбуриро месанҷиданд
//  (`onReelSwiped`, `onStoryAdvanced`, `showInterstitialIfReady`) —
//  онҳо бо санҷиши баръакс иваз шуданд.
// ═══════════════════════════════════════════════════════════════════

String _read(String p) => File(p).readAsStringSync();

/// Ҳамаи файлҳои lib — барои «ҳеҷ ҷо».
Map<String, String> _libFiles() => {
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File && f.path.endsWith('.dart'))
          f.path.replaceAll(r'\', '/'): f.readAsStringSync(),
    };

/// Рекламаи дохилии санҷишӣ.
SponsoredAd _ad(String id) => SponsoredAd(
      id: id,
      postId: 'p$id',
      goal: 'website',
      actionUrl: 'https://example.com',
      cta: 'Бештар',
      advertiserId: 'u1',
      advertiserName: 'shop',
      advertiserAvatar: '',
      advertiserVerified: false,
      caption: '',
      likesCount: 0,
      commentsCount: 0,
      media: const [SponsoredMedia(url: 'https://x/v.mp4', isVideo: true)],
    );

SponsoredAd _imageAd(String id) => SponsoredAd(
      id: id,
      postId: 'p$id',
      goal: 'install',
      actionUrl: '',
      cta: 'Насб кардан',
      advertiserId: 'u1',
      advertiserName: 'shop',
      advertiserAvatar: '',
      advertiserVerified: false,
      caption: 'Тахфиф',
      likesCount: 3,
      commentsCount: 0,
      media: const [SponsoredMedia(url: 'https://x/1.jpg', isVideo: false)],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AdEligibility.instance.debugSet(server: false);
    SponsoredAdsRepository.instance.clear();
  });

  group('рекламаи маҷбурӣ нест', () {
    test('Reels рекламаи томэкраниро нишон намедиҳад', () {
      final reels = _read('lib/reels/reels_feed/reels_screen.dart');
      expect(reels.contains('onReelSwiped'), isFalse,
          reason: 'swipe боз рекламаи томэкранӣ мебарорад');
      expect(reels.contains('Interstitial'), isFalse);
      expect(reels, contains('ReelsAdPage('),
          reason: 'реклама дар Reels бояд саҳифаи оддӣ бошад');
    });

    test('стори рекламаи томэкраниро нишон намедиҳад', () {
      final viewer = _read('lib/stories/story_group_viewer.dart');
      expect(viewer.contains('onStoryAdvanced'), isFalse);
      expect(viewer.contains('AdsManager'), isFalse);
      // Стори бе интизорӣ давом мекунад.
      final i = viewer.indexOf('void _nextStory()');
      expect(viewer.substring(i, i + 500), contains('_advanceStory()'));
    });

    test('interstitial танҳо аз экрани ташхис, бо зеркунии дастӣ', () {
      final files = _libFiles();
      final ads = files['lib/core/ads/ads_manager.dart']!;
      expect(ads.contains('onReelSwiped'), isFalse);
      expect(ads.contains('onStoryAdvanced'), isFalse);
      expect(ads.contains('showInterstitialIfReady'), isFalse);
      final callers = files.entries
          .where((e) =>
              e.value.contains('showInterstitialForDiagnostics') &&
              e.key != 'lib/core/ads/ads_manager.dart')
          .map((e) => e.key)
          .toList();
      expect(callers, ['lib/core/ads/ads_debug_screen.dart'],
          reason: 'interstitial боз аз экрани корбарӣ нишон дода мешавад');
    });

    test('interstitial ҳангоми оғоз бор карда намешавад', () {
      // Рекламае, ки ҳеҷ гоҳ нишон дода намешавад, дархости беҳуда аст.
      final ads = _read('lib/core/ads/ads_manager.dart');
      final i = ads.indexOf('Future<void> _doInit()');
      final end = ads.indexOf('\n  }\n', i);
      expect(ads.substring(i, end).contains('_preloadInterstitial()'), isFalse);
    });

    test('рекламаи мукофотӣ бе амали корбар нишон дода намешавад', () {
      // Намоиш ТАНҲО аз `showRewarded()`, ки экран даъват мекунад.
      // Ҳеҷ таймер, ҳеҷ намоиши худкор.
      final ads = _read('lib/core/ads/ads_manager.dart');
      expect(RegExp(r'Timer\([^;]*showRewarded').hasMatch(ads), isFalse);
      expect(ads.indexOf('Future<RewardOutcome> showRewarded()'),
          greaterThan(0));
    });

    test('ҳеҷ таймер рекламаро нишон намедиҳад', () {
      for (final e in _libFiles().entries) {
        if (!e.key.startsWith('lib/core/ads/') &&
            !e.key.contains('reels') &&
            !e.key.contains('feed') &&
            !e.key.contains('stories')) {
          continue;
        }
        expect(
            RegExp(r'Timer(\.periodic)?\([^;]*\.show\(').hasMatch(e.value),
            isFalse,
            reason: '${e.key}: реклама аз таймер');
      }
    });
  });

  group('лента', () {
    test('карти реклама дар лента ҳаст', () {
      final src = _read('lib/feed/timeline/feed_screen.dart');
      expect(src, contains('FeedAdCard('));
      expect(src, contains('kFeedAdLayout'));
    });

    test('ҷойҳо мисли Instagram: баъди 4, баъд ҳар 8', () {
      expect(kFeedAdLayout.first, 4);
      expect(kFeedAdLayout.every, 8);
      final ads = [for (var i = 0; i < 40; i++) if (kFeedAdLayout.isAdAt(i)) i];
      // p0..p3 [AD] p4..p11 [AD] p12..p19 [AD] …
      expect(ads.take(3), [4, 13, 22]);
    });

    test('пост гум ва такрор намешавад', () {
      const l = kFeedAdLayout;
      for (final n in [0, 3, 4, 5, 12, 13, 30]) {
        final total = l.totalFor(n);
        final seen = <int>[];
        for (var i = 0; i < total; i++) {
          if (l.isAdAt(i)) continue;
          seen.add(l.itemIndexAt(i));
        }
        expect(seen, List.generate(n, (i) => i), reason: 'n=$n');
      }
    });

    test('реклама ҳеҷ гоҳ дар охири рӯйхат нест', () {
      const l = kFeedAdLayout;
      for (var n = 0; n < 40; n++) {
        final total = l.totalFor(n);
        if (total == 0) continue;
        expect(l.isAdAt(total - 1), isFalse, reason: 'n=$n');
      }
    });

    test('VIP — ҷойҳои реклама умуман нестанд', () {
      final l = kFeedAdLayout.copyWith(enabled: false);
      expect(l.totalFor(30), 30);
      for (var i = 0; i < 30; i++) {
        expect(l.isAdAt(i), isFalse);
        expect(l.itemIndexAt(i), i);
      }
    });
  });

  group('Reels', () {
    test('ҷой танҳо вақте гузошта мешавад, ки реклама ҳаст', () {
      final plan = ReelsAdPlan();
      expect(plan.planAhead(currentPage: 0, available: false), isFalse);
      expect(plan.positions, isEmpty);
      expect(plan.planAhead(currentPage: 0, available: true), isTrue);
      expect(plan.positions, [kReelsAdFirst]);
    });

    test('ҷой ҳеҷ гоҳ дар саҳифаи ҷорӣ ё навбатӣ гузошта намешавад', () {
      // Вагарна видео зери ангушти корбар иваз мешуд.
      for (var cur = 0; cur < 30; cur++) {
        final plan = ReelsAdPlan();
        plan.planAhead(currentPage: cur, available: true);
        for (final p in plan.positions) {
          expect(p, greaterThanOrEqualTo(cur + 2), reason: 'cur=$cur');
        }
      }
    });

    test('видео гум намешавад', () {
      final plan = ReelsAdPlan();
      for (var cur = 0; cur < 40; cur++) {
        plan.planAhead(currentPage: cur, available: true);
      }
      const reels = 30;
      final seen = <int>[];
      for (var p = 0; p < plan.pageCount(reels); p++) {
        if (plan.isAdAt(p)) continue;
        seen.add(plan.reelIndexAt(p));
      }
      expect(seen, List.generate(reels, (i) => i));
      // Ду реклама пай дар пай нест.
      final pos = plan.positions;
      for (var i = 1; i < pos.length; i++) {
        expect(pos[i] - pos[i - 1], greaterThan(1));
      }
    });

    test('VIP — дар Reels ҷойи реклама нест', () {
      SponsoredAdsRepository.instance
          .debugSetList(SponsoredPlacement.reels, [_ad('a')]);
      expect(reelsAdAvailable(0), isTrue);
      AdEligibility.instance.debugSet(server: true);
      expect(reelsAdAvailable(0), isFalse);
      expect(
          SponsoredAdsRepository.instance
              .forSlot(SponsoredPlacement.reels, 0),
          isNull);
    });
  });

  group('Yandex баннер', () {
    test('ҳар ҷой як дархост, бе такрор ва бо keep-alive', () {
      final code = _read('lib/core/ads/yandex_banner_slot.dart');
      expect(RegExp(r'\.load\(AdRequest').allMatches(code).length, 1);
      expect(code, contains('bool get wantKeepAlive => true'));
    });

    test('AdWidget пеш аз «loaded» ҳам дар дарахт аст', () {
      // SDK 8 дархостро танҳо баъди сохтани platform view мефиристад.
      final code = _read('lib/core/ads/yandex_banner_slot.dart');
      expect(code, contains(': AdWidget(bannerAd: ad)'));
      expect(code.contains('if (!_isLoaded'), isFalse);
    });

    test('бе розигӣ ва бе SDK дархост намеравад', () {
      // Дар тест SDK оғоз нашудааст — яъне розигӣ нест.
      YandexSlotBudget.instance.debugReset();
      expect(YandexSlotBudget.instance.canRequest, isFalse);
    });

    test('ҳадди дархост дар сессия ҳаст', () {
      expect(YandexSlotBudget.maxRequestsPerSession, inInclusiveRange(1, 30));
      expect(YandexSlotBudget.failureCooldown.inMinutes, greaterThan(0));
    });
  });

  group('рекламаи дохилӣ', () {
    test('рӯйхат як бор дар TTL пурсида мешавад', () async {
      final repo = SponsoredAdsRepository.instance;
      var calls = 0;
      repo.fetcher = (p) async {
        calls++;
        return {
          'adsFree': false,
          'items': [
            {
              'id': 'x1',
              'postId': 'p1',
              'advertiser': {'id': 'u', 'username': 'shop'},
              'media': [
                {'url': 'https://x/1.jpg', 'type': 'image'}
              ],
            },
          ],
        };
      };
      await Future.wait([
        repo.prefetch(SponsoredPlacement.feed),
        repo.prefetch(SponsoredPlacement.feed),
      ]);
      await repo.prefetch(SponsoredPlacement.feed);
      expect(calls, 1);
      expect(repo.forSlot(SponsoredPlacement.feed, 0)?.id, 'x1');
      // Ҳамон ҷой — ҳамон реклама.
      expect(repo.forSlot(SponsoredPlacement.feed, 5)?.id, 'x1');
    });

    test('сервер «adsFree» гуфт — ҳеҷ реклама', () async {
      final repo = SponsoredAdsRepository.instance;
      repo.fetcher = (p) async => {'adsFree': true, 'items': const []};
      await repo.prefetch(SponsoredPlacement.reels);
      expect(AdEligibility.instance.isAdsFree, isTrue);
      expect(repo.forSlot(SponsoredPlacement.reels, 0), isNull);
    });

    test('VIP ҳеҷ дархост намефиристад', () async {
      final repo = SponsoredAdsRepository.instance;
      var calls = 0;
      repo.fetcher = (p) async {
        calls++;
        return null;
      };
      AdEligibility.instance.debugSet(server: true);
      await repo.prefetch(SponsoredPlacement.feed);
      expect(calls, 0);
    });

    test('«Пинҳон кардан» рекламаро фавран мебарорад', () {
      final repo = SponsoredAdsRepository.instance;
      repo.debugSetList(SponsoredPlacement.feed, [_ad('a'), _ad('b')]);
      repo.hide(_ad('a'));
      expect(repo.listFor(SponsoredPlacement.feed).value.map((e) => e.id),
          ['b']);
    });

    test('реклама бе расм/видео нишон дода намешавад', () {
      expect(SponsoredAd.fromJson({'id': 'z', 'media': const []}), isNull);
    });

    test('карт «Реклама», CTA ва менюи ⋯ дорад', () {
      final ui = _read('lib/core/ads/ad_ui.dart');
      expect(ui, contains("kSponsoredLabel = 'Реклама'"));
      expect(ui, contains('Пинҳон кардан'));
      expect(ui, contains('Чаро ин реклама?'));
      final feed = _read('lib/core/ads/feed_ad_card.dart');
      expect(feed, contains('SponsoredCtaBar('));
      expect(feed, contains('kSponsoredLabel'));
      final reels = _read('lib/core/ads/reels_ad_page.dart');
      expect(reels, contains('SponsoredCtaBar('));
      // Ҳеҷ ҳисобкунаки баръакс ва ҳеҷ «X»-и маҷбурӣ.
      expect(RegExp(r'countdown|секунд|сония то', caseSensitive: false)
          .hasMatch(reels), isFalse);
    });
  });

  group('намуди карт', () {
    setUp(() => VisibilityDetectorController.instance.updateInterval =
        Duration.zero);

    testWidgets('карти лента: «Реклама», ном, CTA — мисли пост', (t) async {
      SponsoredAdsRepository.instance
          .debugSetList(SponsoredPlacement.feed, [_imageAd('f1')]);
      await t.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(child: FeedAdCard(slot: 0)))));
      await t.pump();
      expect(find.text('Реклама'), findsOneWidget);
      expect(find.text('shop'), findsOneWidget);
      expect(find.text('Насб кардан'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('VIP — карти лента холӣ аст', (t) async {
      SponsoredAdsRepository.instance
          .debugSetList(SponsoredPlacement.feed, [_imageAd('f1')]);
      AdEligibility.instance.debugSet(server: true);
      await t.pumpWidget(const MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(child: FeedAdCard(slot: 0)))));
      await t.pump();
      expect(find.text('Реклама'), findsNothing);
      expect(find.text('Насб кардан'), findsNothing);
    });

    testWidgets('саҳифаи Reels: бе ҳисобкунак, бо CTA', (t) async {
      SponsoredAdsRepository.instance
          .debugSetList(SponsoredPlacement.reels, [_imageAd('r1')]);
      await t.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ReelsAdPage(
                  slot: 0,
                  isActive: false,
                  isMuted: true,
                  onUnavailable: () {}))));
      await t.pump();
      expect(find.text('Реклама'), findsOneWidget);
      expect(find.text('Насб кардан'), findsOneWidget);
      // Ҳеҷ тугмаи «X»/пӯшидан — рекламаро бо swipe мегузаранд.
      expect(find.byIcon(Icons.close), findsNothing);
      await t.pumpWidget(const SizedBox());
    });
  });
}
