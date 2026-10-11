// test/features_b_test.dart
// «Кӯмаки фаврӣ», «Овоз», «Тарҷума» ва «Профили тиҷоратӣ» — мантиқ,
// виджетҳо ва пайвастҳо (дари воридшавӣ дар меню, ҷустуҷӯ, танзимот).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_settings.dart';
import 'package:raonson/business/business_models.dart';
import 'package:raonson/business/business_screens.dart';
import 'package:raonson/core/features/feature_flags.dart';
import 'package:raonson/core/i18n/strings.dart';
import 'package:raonson/core/i18n/strings_features_b.dart';
import 'package:raonson/core/places/place.dart';
import 'package:raonson/core/translate/translate_service.dart';
import 'package:raonson/help/help_models.dart';
import 'package:raonson/help/help_screens.dart';
import 'package:raonson/models/post_model.dart';
import 'package:raonson/models/user_model.dart';
import 'package:raonson/voice/create_voice_post_screen.dart';
import 'package:raonson/voice/voice_post_player.dart';
import 'package:raonson/widgets/translate_toggle.dart';

String _read(String p) => File(p).readAsStringSync();

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

const _author = UserModel(id: 'u1', username: 'ali', avatar: '', verified: false,
    isPrivate: false, postsCount: 0, followersCount: 0, followingCount: 0);

HelpRequest _req({String id = 'h1', String kind = 'blood', bool mine = false,
        String status = 'open'}) =>
    HelpRequest(id: id, kind: kind, title: 'Хуни A+ лозим аст', bloodGroup: 'A+',
        units: 2, hospital: 'Шифобахш', cityId: 'tj-dushanbe', cityName: 'Душанбе',
        status: status, isMine: mine, author: _author,
        expiresAt: DateTime.now().add(const Duration(hours: 30)),
        createdAt: DateTime.now());

class _FakeHelp extends HelpRepository {
  final List<HelpRequest> items;
  final calls = <String>[];
  _FakeHelp(this.items);
  @override
  Future<List<HelpRequest>> list({String city = '', String kind = '',
      bool mine = false, int page = 1}) async {
    calls.add('list:$city:$kind:$mine');
    return items.where((r) => kind.isEmpty || r.kind == kind ||
        (kind == 'lost' && r.kind.startsWith('lost'))).toList();
  }

  @override
  Future<HelpRequest> get(String id) async => items.firstWhere((r) => r.id == id);

  @override
  Future<DonorSettings> donor() async => const DonorSettings(enabled: true,
      bloodGroup: 'O-', cityId: 'tj-dushanbe', cityName: 'Душанбе');
}

class _FakeBiz extends BusinessRepository {
  final BusinessProfile? b;
  final taps = <String>[];
  _FakeBiz(this.b);
  @override
  Future<BusinessProfile?> forUser(String userId, {String lang = 'tj'}) async => b;
  @override
  Future<void> tap(String userId, String action) async => taps.add(action);
}

/// Вақти маҳаллии Душанбе (UTC+5) → UTC. 2026-01-05 душанбе аст.
DateTime _tj(int weekday, int hh, int mm) =>
    DateTime.utc(2026, 1, 5 + (weekday - 1), hh, mm).subtract(const Duration(hours: 5));

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsState.instance.setLang('tj');
    FeatureFlags.debugReset();
    TranslateService.instance.debugBackend = null;
    TranslateService.instance.debugClear();
  });

  // ── i18n ─────────────────────────────────────────────────────────
  group('сатрҳо', () {
    test('ҳар калид дар tj/ru/en ҳаст', () {
      final tj = featureStringsB['tj']!.keys.toSet();
      for (final l in ['ru', 'en']) {
        expect(featureStringsB[l]!.keys.toSet(), tj, reason: 'забони $l');
      }
    });
    test('tr() сатрҳои навро медиҳад ва забонро иваз мекунад', () async {
      expect(tr('help.title'), 'Кӯмаки фаврӣ');
      await AppSettingsState.instance.setLang('ru');
      expect(tr('help.title'), 'Срочная помощь');
      expect(tr('biz.until', {'t': '18:00'}), 'до 18:00');
      await AppSettingsState.instance.setLang('en');
      expect(tr('tr.show'), 'See translation');
    });
    test('тугмаи мавҷуда «Тарҷума кардан» ягона шуд', () {
      expect(featureStringsB['tj']!['tr.show'], 'Тарҷума кардан');
      final card = _read('lib/feed/post/post_card.dart');
      expect(card, contains('TranslateToggle('));
      expect(card.contains("'/ai/translate'"), isFalse);
      expect(_read('lib/feed/comments/comments_screen.dart').contains("'/ai/translate'"), isFalse);
      expect(_read('lib/chat/room/chat_room_screen.dart').contains("'/ai/translate'"), isFalse);
    });
  });

  // ── Тарҷума ──────────────────────────────────────────────────────
  group('тарҷума', () {
    test('isTranslatable', () {
      expect(isTranslatable('Салом дӯстон'), isTrue);
      expect(isTranslatable('😀🔥 #raonson @ali'), isFalse);
      expect(isTranslatable('123 456'), isFalse);
    });

    test('кэши хотира: як матн — як дархост', () async {
      var n = 0;
      TranslateService.instance.debugBackend = (t, l) async {
        n++;
        return TranslateResult.ok('[$l] $t');
      };
      final a = await TranslateService.instance.translate('Салом');
      final b = await TranslateService.instance.translate('  Салом ');
      expect(a.text, '[tj] Салом');
      expect(b.text, a.text);
      expect(n, 1);
      await AppSettingsState.instance.setLang('ru');
      final c = await TranslateService.instance.translate('Салом');
      expect(c.text, '[ru] Салом', reason: 'забони мақсад = забони барнома');
    });

    testWidgets('бе провайдер тугма нест', (t) async {
      await t.pumpWidget(_app(const TranslateToggle(text: 'Салом дӯстон')));
      await t.pump();
      expect(find.byKey(const ValueKey('translate-toggle')), findsNothing);
    });

    testWidgets('бо провайдер: тарҷума ва пинҳон кардан', (t) async {
      FeatureFlags.debugSet(const FeatureFlags(translate: true));
      TranslateService.instance.debugBackend = (s, l) async => const TranslateResult.ok('Hello friends');
      await t.pumpWidget(_app(const TranslateToggle(text: 'Салом дӯстон')));
      await t.pump();
      expect(find.text('Тарҷума кардан'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('translate-toggle')));
      await t.pump();
      await t.pump();
      expect(find.text('Hello friends'), findsOneWidget);
      expect(find.text('Пинҳон кардани тарҷума'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('translate-toggle')));
      await t.pump();
      expect(find.text('Hello friends'), findsNothing);
    });

    testWidgets('хатои ҳад — паёми фаҳмо', (t) async {
      FeatureFlags.debugSet(const FeatureFlags(translate: true));
      TranslateService.instance.debugBackend = (s, l) async => const TranslateResult.fail('limited');
      await t.pumpWidget(_app(const TranslateToggle(text: 'Салом дӯстон')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('translate-toggle')));
      await t.pump();
      await t.pump();
      expect(find.text(tr('tr.limited')), findsOneWidget);
    });

    test('парчамҳо аз JSON', () {
      final f = FeatureFlags.fromJson({'translate': true, 'voiceMaxSeconds': 60,
          'translateLangs': ['tj', 'fa']});
      expect(f.translate, isTrue);
      expect(f.translateLangs, ['tj', 'fa']);
    });
  });

  // ── Овоз ─────────────────────────────────────────────────────────
  group('овоз', () {
    test('мавҷ, вақт ва бадани пост', () {
      expect(parseWaveform('0,50,100,200'), [0.0, 0.5, 1.0, 1.0]);
      expect(parseWaveform('', seed: 'x').length, 48);
      expect(parseWaveform('', seed: 'x'), parseWaveform('', seed: 'x'));
      expect(formatVoiceDuration(const Duration(seconds: 65)), '1:05');
      expect(amplitudeToLevel(-60), 0);
      expect(amplitudeToLevel(0), 100);
      expect(amplitudeToLevel(double.negativeInfinity), 0);
      final d = downsampleLevels(List.generate(500, (i) => i % 100));
      expect(d.length, 64);
      final body = voicePostBody(audioUrl: 'https://x/a.m4a',
          duration: const Duration(seconds: 75), levels: [1, 2, 3], caption: ' hi ');
      final m = (body['media'] as List).first as Map;
      expect(m['type'], 'audio');
      expect(m['durationMs'], 60000, reason: 'то 60 сония');
      expect(body['caption'], 'hi');
      expect(m.containsKey('cover'), isFalse);
    });

    test('PostModel: медиаи овозӣ ва кэши диск', () {
      final p = PostModel.fromJson({'_id': 'p1', 'caption': '', 'media': [
        {'url': 'https://x/a.m4a', 'type': 'audio', 'durationMs': 12000,
          'waveform': '10,20', 'cover': 'https://x/c.jpg'}
      ], 'createdAt': '2026-01-01T00:00:00Z'});
      expect(p.isVoice, isTrue);
      expect(p.media.first['durationMs'], '12000');
      final again = PostModel.fromJson(p.toJson());
      expect(again.media.first['durationMs'], '12000');
      expect(again.media.first['waveform'], '10,20');
    });

    testWidgets('плеер ва плитка вақтро нишон медиҳанд (бе платформа)', (t) async {
      const media = {'url': 'https://x/a.m4a', 'type': 'audio',
          'durationMs': '42000', 'waveform': '10,50,90'};
      await t.pumpWidget(_app(const SizedBox(width: 360,
          child: VoicePostPlayer(media: media, postId: 'p1'))));
      expect(find.text('0:42'), findsOneWidget);
      expect(find.byKey(const ValueKey('voice-play')), findsOneWidget);
      await t.pumpWidget(_app(const SizedBox(width: 120, height: 120,
          child: VoiceTile(media: media))));
      expect(find.text('0:42'), findsOneWidget);
    });

    testWidgets('экрани сабт: «Нашр» то сабт хомӯш', (t) async {
      await t.pumpWidget(const MaterialApp(home: CreateVoicePostScreen()));
      final btn = t.widget<TextButton>(find.byKey(const ValueKey('voice-publish')));
      expect(btn.onPressed, isNull);
      expect(find.text(tr('voice.tapToRecord')), findsOneWidget);
    });
  });

  // ── Кӯмаки фаврӣ ─────────────────────────────────────────────────
  group('кӯмаки фаврӣ', () {
    test('JSON ва вақти боқимонда', () {
      final r = HelpRequest.fromJson({'_id': 'h', 'kind': 'blood', 'title': 'T',
        'bloodGroup': 'O-', 'city': {'id': 'tj-dushanbe', 'name': 'Душанбе'},
        'user': {'_id': 'u', 'username': 'ali'}, 'isMine': true, 'notifiedCount': 3,
        'expiresAt': '2030-01-01T00:00:00Z', 'status': 'open'});
      expect(r.isBlood && r.isMine && r.notifiedCount == 3, isTrue);
      expect(r.author.username, 'ali');
      final now = DateTime.utc(2026, 1, 1);
      expect(helpTimeLeft(now.add(const Duration(hours: 5)), now: now), (5, 'h'));
      expect(helpTimeLeft(now.add(const Duration(days: 10)), now: now), (10, 'd'));
      expect(helpTimeLeft(now.subtract(const Duration(hours: 1)), now: now), isNull);
    });

    test('хатоҳои сервер — матни фаҳмо', () {
      expect(helpErrorText(const HelpError(403, 'help_trust_required', '')), tr('help.trust'));
      expect(helpErrorText(const HelpError(429, 'help_daily_cap', '')), tr('help.dailyCap'));
      expect(helpErrorText(const HelpError(400, 'help_no_contacts', '')), tr('help.noPhones'));
    });

    testWidgets('тахта: кортҳо ва филтр', (t) async {
      final repo = _FakeHelp([_req(), _req(id: 'h2', kind: 'lost_pet')]);
      await t.pumpWidget(MaterialApp(home: HelpBoardScreen(repo: repo,
          initialCity: const Place(id: 'tj-dushanbe', name: 'Душанбе', kind: 'city'))));
      await t.pumpAndSettle();
      expect(find.byType(HelpCard), findsNWidgets(2));
      expect(find.text('A+'), findsOneWidget, reason: 'гурӯҳи хун дар корт');
      expect(repo.calls.first, 'list:tj-dushanbe::false');
      await t.tap(find.text(tr('help.kind.lost')));
      await t.pumpAndSettle();
      expect(find.byType(HelpCard), findsOneWidget);
      expect(repo.calls.last, 'list:tj-dushanbe:lost:false');
    });

    testWidgets('дархости бегона: «Ман кӯмак карда метавонам», бе рақам', (t) async {
      final repo = _FakeHelp([_req()]);
      await t.pumpWidget(MaterialApp(home: HelpRequestScreen(id: 'h1', repo: repo)));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('help-respond')), findsOneWidget);
      expect(find.text(tr('help.chatOnly')), findsOneWidget);
    });

    testWidgets('дархости худ: тугмаи ҷавоб нест', (t) async {
      final repo = _FakeHelp([_req(mine: true)]);
      await t.pumpWidget(MaterialApp(home: HelpRequestScreen(id: 'h1', repo: repo)));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('help-respond')), findsNothing);
    });

    testWidgets('сохтан: «Нашр» то пур шудан хомӯш', (t) async {
      // Экрани баланд, то тугмаи поён сохта шавад (ListView танбал аст).
      t.view.physicalSize = const Size(800, 3200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(home: CreateHelpScreen(repo: _FakeHelp([]),
          city: const Place(id: 'tj-dushanbe', name: 'Душанбе', kind: 'city'))));
      ElevatedButton submit() =>
          t.widget<ElevatedButton>(find.byKey(const ValueKey('help-submit')));
      expect(submit().onPressed, isNull);
      await t.enterText(find.byKey(const ValueKey('help-title')), 'Хуни A+ лозим аст');
      await t.pump();
      expect(submit().onPressed, isNull, reason: 'гурӯҳи хун интихоб нашуд');
      await t.tap(find.byKey(const ValueKey('group-A+')));
      await t.pump();
      expect(submit().onPressed, isNotNull);
    });

    testWidgets('донор: танзимоти худ бор мешавад', (t) async {
      await t.pumpWidget(MaterialApp(home: DonorSettingsScreen(repo: _FakeHelp([]))));
      await t.pumpAndSettle();
      final sw = t.widget<SwitchListTile>(find.byKey(const ValueKey('donor-switch')));
      expect(sw.value, isTrue);
      expect(find.text('Душанбе'), findsOneWidget);
    });
  });

  // ── Профили тиҷоратӣ ─────────────────────────────────────────────
  group('тиҷорат', () {
    final hours = parseHours({
      'mon': [['09:00', '13:00'], ['14:00', '18:00']],
      'fri': [['22:00', '02:00']],
      'sun': [],
    });

    test('«Кушода/Пӯшида ҳозир» дар вақти Тоҷикистон', () {
      var s = computeOpenState(hours, _tj(1, 10, 0));
      expect(s.open && s.closesAt == '13:00', isTrue);
      s = computeOpenState(hours, _tj(1, 13, 30));
      expect(!s.open && s.opensAt == '14:00' && s.opensDay == 'mon', isTrue);
      s = computeOpenState(hours, _tj(1, 19, 0));
      expect(s.opensDay, 'fri');
      expect(computeOpenState(hours, _tj(6, 1, 30)).open, isTrue,
          reason: 'фосилаи шабонаи ҷумъа');
      // 04:30 UTC = 09:30 дар Душанбе.
      expect(computeOpenState(hours, DateTime.utc(2026, 1, 5, 4, 30)).open, isTrue);
      expect(computeOpenState({}, DateTime.now()).known, isFalse);
    });

    test('URI-ҳои алоқа', () {
      final b = BusinessProfile.fromJson({'userId': 'b', 'username': 'cafe',
          'phone': '+992931112233', 'whatsapp': '+992931112233',
          'lat': 38.5, 'lon': 68.7, 'address': 'Рӯдакӣ 45', 'priceRange': 2});
      expect(b.phoneUri.toString(), 'tel:+992931112233');
      expect(b.whatsappUri.toString(), 'https://wa.me/992931112233');
      expect(b.directionsUri!.scheme, 'geo');
      expect(b.priceLabel, r'$$');
    });

    testWidgets('сарлавҳаи профил: категория, ҳолат, тугмаҳо', (t) async {
      final repo = _FakeBiz(BusinessProfile.fromJson({
        'userId': 'b', 'username': 'cafe', 'categoryLabel': 'Қаҳвахона',
        'hours': {'mon': [['09:00', '18:00']]}, 'phone': '+992931112233',
        'showChat': true, 'address': 'Рӯдакӣ 45', 'productsCount': 3,
      }));
      await t.pumpWidget(_app(BusinessHeader(
          user: const UserModel(id: 'b', username: 'cafe', avatar: '', verified: false,
              isPrivate: false, postsCount: 0, followersCount: 0, followingCount: 0,
              isBusiness: true),
          repo: repo, now: () => _tj(1, 10, 0))));
      await t.pumpAndSettle();
      expect(find.text('Қаҳвахона'), findsOneWidget);
      expect(find.textContaining(tr('biz.openNow')), findsOneWidget);
      expect(find.byKey(const ValueKey('biz-call')), findsOneWidget);
      expect(find.byKey(const ValueKey('biz-chat')), findsOneWidget);
      expect(find.byKey(const ValueKey('biz-whatsapp')), findsNothing);
      expect(find.byKey(const ValueKey('biz-products')), findsOneWidget);
    });

    testWidgets('сарлавҳа: пӯшида бо вақти кушодан', (t) async {
      final repo = _FakeBiz(BusinessProfile.fromJson({
        'userId': 'b', 'categoryLabel': 'Дорухона',
        'hours': {'tue': [['08:00', '20:00']]}}));
      await t.pumpWidget(_app(BusinessHeader(user: _author, repo: repo,
          now: () => _tj(1, 22, 0))));
      await t.pumpAndSettle();
      expect(find.textContaining(tr('biz.closedNow')), findsOneWidget);
      expect(find.textContaining('08:00'), findsOneWidget);
    });

    test('UserModel: isBusiness аз профил', () {
      final u = UserModel.fromJson({'_id': 'x', 'username': 'x', 'isBusiness': true,
          'businessCategory': 'cafe'});
      expect(u.isBusiness && u.businessCategory == 'cafe', isTrue);
      expect(u.copyWith(bio: 'b').isBusiness, isTrue);
    });
  });

  // ── Дарҳои воридшавӣ ──────────────────────────────────────────────
  group('дарҳои воридшавӣ', () {
    test('менюи сохтан: «Овоз» ва «Кӯмак»', () {
      final s = _read('lib/create/gallery_picker_screen.dart');
      expect(s, contains('CreateVoicePostScreen'));
      expect(s, contains('CreateHelpScreen'));
    });
    test('ҷустуҷӯ: «Кӯмаки фаврӣ» ва «Тиҷорат»', () {
      expect(_read('lib/search/search_screen.dart'), contains('DiscoverShortcutsRow'));
      final row = _read('lib/search/discover_shortcuts.dart');
      expect(row, contains('HelpBoardScreen'));
      expect(row, contains('BusinessDirectoryScreen'));
    });
    test('танзимот: тиҷорат, кӯмак, донор', () {
      final s = _read('lib/settings/settings_screen.dart');
      for (final w in ['BusinessSettingsScreen', 'HelpBoardScreen', 'DonorSettingsScreen']) {
        expect(s, contains(w));
      }
    });
    test('профил: сарлавҳаи тиҷорат, плиткаи овоз, тарҷумаи bio', () {
      final s = _read('lib/profile/profile_screen.dart');
      expect(s, contains('BusinessHeader('));
      expect(s, contains('VoiceTile('));
      expect(s, contains('TranslateToggle('));
    });
    test('огоҳинома ва push ба дархост мебаранд', () {
      expect(_read('lib/notifications/notifications_screen.dart'), contains("'help_blood'"));
      expect(_read('lib/core/firebase_init.dart'), contains("'/help/'"));
    });
  });
}
