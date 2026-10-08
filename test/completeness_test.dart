// test/completeness_test.dart
// Функсияҳои «нимтамом», ки ба охир расонида шуданд (мисли Instagram):
//   • Explore — саҳифабандии воқеӣ (seed, бе такрор, reels дар ҳуҷайраи баланд);
//   • Reels «Ба ман шавқовар нест» — плеери reel-и пинҳоншуда ба reel-и
//     навбатӣ НАМЕГУЗАРАД;
//   • «Ҷой»-и Reels ва стикери «📍 Ҷой» дар сторис;
//   • «Ба актуалӣ илова кардан» — ба актуалии МАВҶУДА;
//   • Бойгонӣ, хомӯшшудагон/маҳдудшудагон, тарҷумаи матнҳо.
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_settings.dart';
import 'package:raonson/core/i18n/strings.dart';
import 'package:raonson/core/places/place.dart';
import 'package:raonson/create/drafts/drafts_store.dart';
import 'package:raonson/models/reel_model.dart';
import 'package:raonson/profile/add_to_highlight_sheet.dart';
import 'package:raonson/profile/archive_screen.dart';
import 'package:raonson/profile/highlight_model.dart';
import 'package:raonson/reels/player/reel_location_chip.dart';
import 'package:raonson/reels/reels_feed/reel_removal.dart';
import 'package:raonson/search/explore_paging.dart';
import 'package:raonson/stories/story_sticker.dart';

String _read(String p) => File(p).readAsStringSync();

class _FakeHighlights implements HighlightsApi {
  final List<HighlightModel> list;
  final added = <(String, String)>[];
  final created = <String>[];
  _FakeHighlights(this.list);

  @override
  Future<List<HighlightModel>> mine() async => list;

  @override
  Future<bool> addStory(String highlightId, String storyId) async {
    added.add((highlightId, storyId));
    return true;
  }

  @override
  Future<bool> create(String title,
      {required String storyId, required String url, required String type}) async {
    created.add(title);
    return true;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsState.instance.setLang('tj');
  });

  group('Explore: саҳифабандӣ', () {
    test('ҳар ҷаласа seed-и нав дорад; саҳифа ба query меравад', () {
      final p = ExplorePager(random: Random(1))..reset();
      final s1 = p.seed;
      p.reset();
      expect(p.seed, isNot(equals(s1)));
      expect(p.seed, matches(RegExp(r'^[a-z0-9]{12}$')),
          reason: 'сервер танҳо ҳарф/рақамро қабул мекунад');
      expect(p.queryFor(3), {'page': '3', 'seed': p.seed});
    });

    test('унсурҳои дидашуда дубора илова намешаванд', () {
      final p = ExplorePager()..reset();
      p.replaceSeen(['a', 'b']);
      expect(p.fresh(['b', 'c', 'c', 'd'], (e) => e), ['c', 'd']);
      expect(p.fresh(['a', 'd', 'e'], (e) => e), ['e']);
      // «Аз нав кашидан» — ҳама аз нав.
      p.reset();
      expect(p.fresh(['a'], (e) => e), ['a']);
    });

    test('reels дар ҳуҷайраҳои баланд (ҳар 4-ум), ҳатто дар саҳифаи 2', () {
      final out = interleaveExplore(0, ['p1', 'p2', 'p3', 'p4', 'p5', 'p6'], ['r1', 'r2']);
      expect(out, ['r1', 'p1', 'p2', 'p3', 'r2', 'p4', 'p5', 'p6']);
      // Саҳифаи дуюм аз индекси 30 оғоз мешавад: 32 баланд аст.
      final page2 = interleaveExplore(30, ['p1', 'p2', 'p3'], ['r1']);
      expect(page2, ['p1', 'p2', 'r1', 'p3']);
      // Агар постҳо тамом шаванд — reels ба охир.
      expect(interleaveExplore(0, ['p1'], ['r1', 'r2', 'r3']), ['r1', 'p1', 'r2', 'r3']);
    });

    test('экран shuffle намекунад ва саҳифаи навбатиро мегирад', () {
      final src = _read('lib/search/search_screen.dart');
      expect(src.contains('..shuffle()'), isFalse,
          reason: 'омехта кардан тартиби устувори саҳифаҳоро вайрон мекунад');
      expect(src, contains('_loadMoreExplore'));
      expect(src, contains("_pager.queryFor(next)"));
      expect(src, contains('_scroll.addListener(_onExploreScroll)'));
    });
  });

  group('Reels «Ба ман шавқовар нест»', () {
    test('плеерҳои пешакӣ боршуда пас аз хориҷ як қадам ба паст', () {
      final m = {0: 'v0', 1: 'v1', 2: 'v2', 3: 'v3'};
      final gone = shiftAfterRemoval(m, 1);
      expect(gone, 'v1', reason: 'плеери видеои пинҳоншуда бояд dispose шавад');
      expect(m, {0: 'v0', 1: 'v2', 2: 'v3'},
          reason: 'reel-и навбатӣ бояд плеери ХУДАШРО гирад, на видеои пинҳоншуда');
    });

    test('холигӣ дар харита низ дуруст мекашад', () {
      final m = {2: 'v2', 5: 'v5'};
      expect(shiftAfterRemoval(m, 3), isNull);
      expect(m, {2: 'v2', 4: 'v5'});
    });

    test('пинҳоншудаҳо аз саҳифаҳои навбатӣ ва кэш бароварда мешаванд', () {
      expect(withoutHidden(['a', 'b', 'c'], {'b'}, (e) => e), ['a', 'c']);
    });

    test('лента reel-ро бо _removeReel мебарорад (на танҳо аз рӯйхат)', () {
      final src = _read('lib/reels/reels_feed/reels_screen.dart');
      expect(src, contains('shiftAfterRemoval(_preloaded, i)'));
      expect(src, contains('onNotInterested: () {\n            _removeReel(vm, vm.reels[i].id);'));
      final repo = _read('lib/reels/reels_repository.dart');
      expect(repo, contains('hiddenIds.add(reelId)'));
    });
  });

  group('«Ҷой»-и Reels', () {
    test('ReelModel ҷой ва id-ро мехонад ва нигоҳ медорад', () {
      final r = ReelModel.fromJson({
        '_id': 'r1', 'videoUrl': 'v', 'caption': '', 'likesCount': 0,
        'commentsCount': 0, 'isLiked': false,
        'location': 'Хуҷанд', 'locationId': 'tj-khujand',
      });
      expect(r.location, 'Хуҷанд');
      expect(r.locationId, 'tj-khujand');
      final back = ReelModel.fromJson(r.toJson());
      expect(back.locationId, 'tj-khujand', reason: 'кэши диск id-ро гум мекард');
    });

    testWidgets('chip танҳо бо ҷой намоён аст', (t) async {
      final withLoc = ReelModel.fromJson({
        '_id': 'r1', 'videoUrl': 'v', 'caption': '', 'likesCount': 0,
        'commentsCount': 0, 'isLiked': false, 'location': 'Хуҷанд',
      });
      final noLoc = withLoc.copyWith(location: '');
      await t.pumpWidget(MaterialApp(home: Scaffold(body: Column(children: [
        ReelLocationChip(reel: withLoc),
        ReelLocationChip(reel: noLoc),
      ]))));
      expect(find.text('Хуҷанд'), findsOneWidget);
      expect(find.byKey(const ValueKey('reel-location-chip')), findsOneWidget);
    });

    test('сохтани reel ҷойро мефиристад; overlay-ҳо chip доранд', () {
      final src = _read('lib/create/create_reel/create_reel_screen.dart');
      expect(src, contains("'locationId': _place!.id"));
      expect(src, contains('showLocationPicker'));
      expect(_read('lib/reels/reels_feed/reels_screen.dart'), contains('ReelLocationChip('));
      expect(_read('lib/reels/player/reel_controls.dart'), contains('ReelLocationChip('));
      expect(_read('lib/feed/location/location_screen.dart'), contains('/reels'));
    });

    test('стикери «📍 Ҷой» дар сторис', () {
      final s = StorySticker.fromJson({
        'kind': 'location', 'prompt': 'Хуҷанд', 'placeId': 'tj-khujand',
      });
      expect(s, isNotNull);
      expect(s!.kind, 'location');
      expect(s.url, 'tj-khujand');
      expect(_read('lib/create/create_story/story_editor.dart'),
          contains("'kind': 'location'"));
    });
  });

  group('Актуалӣ', () {
    testWidgets('сторис ба актуалии МАВҶУДА илова мешавад', (t) async {
      final api = _FakeHighlights([
        const HighlightModel(id: 'h1', title: 'Сафар', coverUrl: ''),
      ]);
      String? result = 'none';
      await t.pumpWidget(MaterialApp(home: Builder(builder: (ctx) => Scaffold(
        body: TextButton(
          onPressed: () async {
            result = await showAddToHighlightSheet(ctx,
                storyId: 's9', mediaUrl: 'https://x/y.jpg', api: api);
          },
          child: const Text('open'),
        ),
      ))));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      expect(find.text('Сафар'), findsOneWidget);
      expect(find.text(tr('highlight.new')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('highlight-h1')));
      await t.pumpAndSettle();
      expect(api.added, [('h1', 's9')]);
      expect(result, 'Сафар');
    });

    testWidgets('«Нав» актуалии нав месозад', (t) async {
      final api = _FakeHighlights([]);
      await t.pumpWidget(MaterialApp(home: Builder(builder: (ctx) => Scaffold(
        body: TextButton(
          onPressed: () => showAddToHighlightSheet(ctx,
              storyId: 's9', mediaUrl: 'https://x/y.jpg', api: api),
          child: const Text('open'),
        ),
      ))));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('highlight-new')));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('highlight-new-name')), 'Нав');
      await t.tap(find.byKey(const ValueKey('highlight-new-save')));
      await t.pumpAndSettle();
      expect(api.created, ['Нав']);
    });

    test('storyId-и унсури актуалӣ ҳангоми таҳрир гум намешавад', () {
      final i = HighlightItem.fromJson({'url': 'u', 'type': 'image', 'storyId': 's1'});
      expect(i.toJson()['storyId'], 's1');
    });

    test('намоишгари сторис аз варақаи нав истифода мебарад', () {
      expect(_read('lib/stories/story_group_viewer.dart'),
          contains('showAddToHighlightSheet('));
    });
  });

  group('Лоиҳаҳо (пост ва Reels)', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('drafts'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('нигоҳ доштан → идома → нашр (ҳазф)', () async {
      var owner = 'u1';
      final store = DraftsStore(baseDir: () async => tmp, owner: () => owner);
      final src = File('${tmp.path}/pick.jpg')..writeAsStringSync('img');
      final d = await store.save(kind: DraftKind.post, media: src,
          caption: 'салом', place: const Place(id: 'tj-khujand', name: 'Хуҷанд'));
      expect(d.mediaPath, contains('/drafts/'),
          reason: 'файли муваққатии галерея метавонад нест шавад — нусха лозим');
      src.deleteSync();
      final list = await store.list(DraftKind.post);
      expect(list.single.caption, 'салом');
      expect(list.single.place?.id, 'tj-khujand');
      expect(await store.list(DraftKind.reel), isEmpty);
      // Аккаунти дигар лоиҳаҳои маро намебинад.
      owner = 'u2';
      expect(await store.list(DraftKind.post), isEmpty);
      owner = 'u1';
      // Навсозии ҳамон лоиҳа — такрор намешавад.
      await store.save(kind: DraftKind.post, media: File(d.mediaPath),
          caption: 'нав', replaceId: d.id);
      expect((await store.list(DraftKind.post)).map((e) => e.caption), ['нав']);
      await store.delete(d.id);
      expect(await store.list(DraftKind.post), isEmpty);
      expect(File(d.mediaPath).existsSync(), isFalse);
    });

    test('лоиҳае, ки файлаш гум шуд, худ тоза мешавад', () async {
      final store = DraftsStore(baseDir: () async => tmp, owner: () => 'u1');
      final src = File('${tmp.path}/v.mp4')..writeAsStringSync('v');
      final d = await store.save(kind: DraftKind.reel, media: src, isVideo: true);
      File(d.mediaPath).deleteSync();
      expect(await store.list(DraftKind.reel), isEmpty);
    });

    testWidgets('«Лоиҳаро нигоҳ дорем?» се ҷавоб дорад', (t) async {
      String? r = 'none';
      await t.pumpWidget(MaterialApp(home: Builder(builder: (ctx) => Scaffold(
        body: TextButton(
            onPressed: () async => r = await askSaveDraft(ctx),
            child: const Text('x'))))));
      await t.tap(find.text('x'));
      await t.pumpAndSettle();
      expect(find.text(tr('draft.askTitle')), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('draft-save')));
      await t.pumpAndSettle();
      expect(r, 'save');
    });

    test('экранҳои пост ва Reels лоиҳаро пешниҳод ва идома медиҳанд', () {
      for (final p in ['lib/create/create_post/create_post_screen.dart',
          'lib/create/create_reel/create_reel_screen.dart']) {
        final src = _read(p);
        expect(src, contains('askSaveDraft('), reason: p);
        expect(src, contains('pickDraft('), reason: p);
        expect(src, contains('DraftsStore.instance.delete('), reason: p);
        expect(src, contains('PopScope('), reason: p);
      }
    });
  });

  group('Бойгонӣ ва рӯйхатҳои махфият', () {
    test('сторис танҳо то 24 соат ба сторис бармегардад', () {
      final s = ArchivedStory.fromJson({
        '_id': 's1', 'mediaUrl': 'u', 'archived': true, 'expired': false});
      expect(s.canRestore, isTrue);
      expect(ArchivedStory.fromJson({'_id': 's1', 'archived': true, 'expired': true})
          .canRestore, isFalse);
      expect(ArchivedStory.fromJson({'_id': 's1', 'archived': false}).canRestore, isFalse);
    });

    test('Танзимот: «Бойгонӣ», «Хомӯшшудагон», «Маҳдудшудагон»', () {
      final src = _read('lib/settings/settings_screen.dart');
      expect(src, contains('const ArchiveScreen()'));
      expect(src, contains('kind: ManagedList.muted'));
      expect(src, contains('kind: ManagedList.restricted'));
    });
  });

  group('Тарҷума', () {
    // Ҳар калиди нав бояд дар ҲАР СЕ забон бошад (tr ба тоҷикӣ
    // бармегардад, пас бе ин санҷиш калиди русии гумшуда пинҳон мемонд).
    const keys = [
      'place.add', 'place.tabPosts', 'place.tabReels', 'place.reelsEmpty',
      'highlight.new', 'highlight.addTo', 'highlight.nameHint',
      'archive.title', 'archive.posts', 'archive.stories', 'archive.postsEmpty',
      'archive.storiesEmpty', 'archive.showOnProfile', 'archive.restored',
      'archive.restoreStory', 'privacy.muted', 'privacy.restricted',
      'privacy.unmute', 'privacy.unrestrict', 'reels.hidden', 'reels.algoUpdated',
      'explore.deleteTitle', 'explore.profileOf', 'set.notifications', 'set.blocked',
      'draft.askTitle', 'draft.save', 'draft.discard', 'draft.openN', 'draft.saved',
      'autodm.title', 'video.failed', 'audio.originalAudio',
    ];

    test('ҳар калид дар tj/ru/en', () {
      final s = _read('lib/core/i18n/strings.dart');
      final ru = s.indexOf("  'ru': {"), en = s.indexOf("  'en': {");
      final sections = {
        'tj': s.substring(0, ru),
        'ru': s.substring(ru, en),
        'en': s.substring(en),
      };
      for (final k in keys) {
        for (final e in sections.entries) {
          expect(e.value.contains("'$k':"), isTrue, reason: '$k дар ${e.key} нест');
        }
      }
    });

    test('забони русӣ воқеан русӣ медиҳад', () async {
      await AppSettingsState.instance.setLang('ru');
      expect(tr('archive.title'), 'Архив');
      expect(tr('explore.profileOf', {'name': 'ali'}), 'Профиль @ali');
      await AppSettingsState.instance.setLang('en');
      expect(tr('privacy.muted'), 'Muted accounts');
    });

    test('экранҳои тағйирёфта матни тоҷикии сахт надоранд', () {
      for (final p in [
        'lib/profile/archive_screen.dart',
        'lib/profile/add_to_highlight_sheet.dart',
        'lib/settings/managed_users_screen.dart',
        'lib/feed/location/location_screen.dart',
        'lib/create/drafts/drafts_store.dart',
      ]) {
        final code = _read(p)
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
        expect(RegExp(r"'[^'\n]*[А-Яа-яӮӯҲҳҚқҶҷҒғӢӣ][^'\n]*'").hasMatch(code), isFalse,
            reason: '$p матни тоҷикии бе tr() дорад');
      }
    });
  });
}
