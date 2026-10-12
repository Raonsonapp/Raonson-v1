// test/features_five_test.dart
// Панҷ имконияти нав: «Даъватнома», пурсиш дар пост, «Савол ба ман»,
// «Мактуб ба оянда», «Чаленҷ» — экранҳои асосӣ бо маълумоти иваз-
// кардашуда (бе шабака), линкҳо ва тарҷумаҳо.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_settings.dart';
import 'package:raonson/capsules/capsule_screens.dart';
import 'package:raonson/challenges/challenge_screens.dart';
import 'package:raonson/core/i18n/strings.dart';
import 'package:raonson/core/i18n/strings_features.dart';
import 'package:raonson/core/links/deep_links.dart';
import 'package:raonson/core/ui/feature_kit.dart';
import 'package:raonson/create/create_more_sheet.dart';
import 'package:raonson/events/event_model.dart';
import 'package:raonson/events/events_screens.dart';
import 'package:raonson/polls/post_poll.dart';
import 'package:raonson/qa/qa_screens.dart';

Widget _app(Widget child) => MaterialApp(home: child);

EventModel _event({String rsvp = 'pending', bool host = false, bool open = false}) =>
    EventModel(
      id: 'e1',
      title: 'Тӯйи Алӣ',
      kind: 'wedding',
      startsAt: open
          ? DateTime.now().subtract(const Duration(minutes: 5))
          : DateTime.now().add(const Duration(days: 2)),
      placeName: 'Душанбе',
      status: open ? 'live' : 'upcoming',
      myRsvp: rsvp,
      isHost: host,
      isOwner: host,
      canRsvp: !host,
      albumOpen: open,
      canUpload: open && (host || rsvp == 'going'),
      going: 2,
      maybe: 1,
      guests: 5,
      maxPlus: 0,
      shareCode: host ? 'abc123' : '',
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsState.instance.setLang('tj');
    PollSync.instance.clear();
  });

  group('тарҷумаҳо', () {
    test('ҳар калид дар ҳар се забон ҳаст ва холӣ нест', () {
      final tj = featureStrings['tj']!.keys.toSet();
      for (final lang in ['ru', 'en']) {
        final keys = featureStrings[lang]!.keys.toSet();
        expect(keys.difference(tj), isEmpty, reason: '$lang: калиди зиёдатӣ');
        expect(tj.difference(keys), isEmpty, reason: '$lang: калид намерасад');
        for (final v in featureStrings[lang]!.values) {
          expect(v.trim(), isNotEmpty);
        }
      }
    });

    test('tr() ҷадвали навро мехонад ва ҷойгирҳоро пур мекунад', () async {
      expect(tr('ev.going'), 'Меоям');
      await AppSettingsState.instance.setLang('ru');
      expect(tr('ev.going'), 'Приду');
      expect(tr('poll.votes', {'n': 3}), '3 голосов');
      await AppSettingsState.instance.setLang('en');
      expect(tr('chl.participants', {'n': 4}), '4 participants');
    });
  });

  group('линкҳо', () {
    test('event бо коди мизбон', () {
      final l = DeepLinks.parse('raonson://event/e1/abc123');
      expect(l.kind, DeepLinkKind.event);
      expect(l.id, 'e1');
      expect(l.extra, 'abc123');
      final w = DeepLinks.parse(DeepLinks.share(DeepLinkKind.event, 'e1', extra: 'abc123'));
      expect((w.kind, w.id, w.extra), (DeepLinkKind.event, 'e1', 'abc123'));
      expect(DeepLinks.appLink(DeepLinkKind.event, 'e1'), 'raonson://event/e1');
    });

    test('capsule ва challenge', () {
      expect(DeepLinks.parse('/capsule/c9').kind, DeepLinkKind.capsule);
      expect(DeepLinks.parse('/challenge/x1').kind, DeepLinkKind.challenge);
      expect(DeepLinks.parse('/post/p1').extra, '');
    });

    test('линки чорабинии мизбон кодро дар бар мегирад', () {
      expect(_event(host: true).appLink, 'raonson://event/e1/abc123');
      expect(_event().appLink, 'raonson://event/e1');
    });
  });

  group('Даъватнома', () {
    testWidgets('рӯйхат кортҳоро бо ҳисоби баръакс нишон медиҳад', (t) async {
      await t.pumpWidget(_app(EventsScreen(load: (_) async => [_event()])));
      await t.pump();
      expect(find.textContaining('Тӯйи Алӣ'), findsWidgets);
      expect(find.textContaining(tr('ev.startsIn')), findsWidgets);
      expect(find.byKey(const ValueKey('ev-create')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('меҳмон: се тугмаи ҷавоб, тугмаҳои мизбон нест', (t) async {
      await t.pumpWidget(_app(EventDetailScreen(
          eventId: 'e1',
          load: () async => _event(rsvp: 'going'),
          loadPhotos: () async => const [])));
      await t.pump();
      expect(find.byKey(const ValueKey('rsvp-going')), findsOneWidget);
      expect(find.byKey(const ValueKey('rsvp-maybe')), findsOneWidget);
      expect(find.byKey(const ValueKey('rsvp-declined')), findsOneWidget);
      expect(find.byKey(const ValueKey('ev-invite')), findsNothing);
      expect(find.byKey(const ValueKey('ev-guests')), findsNothing);
      expect(find.text(tr('ev.albumLocked')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('мизбон: даъват ва меҳмонон; албоми кушода', (t) async {
      await t.pumpWidget(_app(EventDetailScreen(
          eventId: 'e1',
          load: () async => _event(host: true, open: true),
          loadPhotos: () async => const [])));
      await t.pump();
      expect(find.byKey(const ValueKey('ev-invite')), findsOneWidget);
      expect(find.byKey(const ValueKey('ev-guests')), findsOneWidget);
      expect(find.byKey(const ValueKey('rsvp-going')), findsNothing);
      expect(find.byKey(const ValueKey('ev-add-photo')), findsOneWidget);
      expect(find.text(tr('ev.live')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('чорабинии нодастрас → паём', (t) async {
      await t.pumpWidget(_app(EventDetailScreen(
          eventId: 'x', load: () async => throw Exception('404'))));
      await t.pump();
      expect(find.text(tr('ev.notFound')), findsOneWidget);
    });
  });

  group('Пурсиш', () {
    PollState state({int myVote = -1}) => PollState.fromJson({
          'postId': 'p1',
          'question': 'Пойтахт?',
          'isQuiz': true,
          'myVote': myVote,
          'canVote': myVote < 0,
          'resultsVisible': myVote >= 0,
          'options': [
            {'text': 'Хуҷанд', if (myVote >= 0) 'votes': 0, if (myVote >= 0) 'percent': 0},
            {'text': 'Душанбе', if (myVote >= 0) 'votes': 1, if (myVote >= 0) 'percent': 100},
          ],
          if (myVote >= 0) 'totalVotes': 1,
          if (myVote >= 0) 'correctIndex': 1,
          if (myVote >= 0) 'myCorrect': myVote == 1,
        });

    testWidgets('пеш аз овоз фоиз нест; баъди овоз — натиҷа ва «Дуруст»', (t) async {
      int? voted;
      await t.pumpWidget(_app(Scaffold(
          body: PostPollCard(
              postId: 'p1',
              load: (_) async => state(),
              vote: (_, i) async {
                voted = i;
                return state(myVote: i);
              }))));
      await t.pump();
      expect(find.text('Пойтахт?'), findsOneWidget);
      expect(find.text('100%'), findsNothing);
      await t.tap(find.byKey(const ValueKey('poll-opt-1')));
      await t.pump();
      expect(voted, 1);
      expect(find.text('100%'), findsOneWidget);
      expect(find.text(tr('poll.correct')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('PollSync: ду корт — як ҳолат', (t) async {
      await t.pumpWidget(_app(Scaffold(
          body: Column(children: [
        PostPollCard(postId: 'p1', load: (_) async => state()),
        PostPollCard(postId: 'p1', load: (_) async => state()),
      ]))));
      await t.pump();
      PollSync.instance.report(state(myVote: 1));
      await t.pump();
      expect(find.text('100%'), findsNWidgets(2));
      await t.pumpWidget(const SizedBox());
    });

    test('PollDraft: санҷиш ва JSON', () {
      expect(const PollDraft(options: ['a', 'A']).validate(), isNotNull);
      expect(const PollDraft(options: ['a', '']).validate(), isNotNull);
      const d = PollDraft(question: ' Q ', options: ['a', 'b', ' '], correctIndex: 1);
      expect(d.validate(), isNull);
      final j = d.toJson();
      expect(j['options'], ['a', 'b']);
      expect(j['correctIndex'], 1);
      expect(j['question'], 'Q');
    });
  });

  group('Савол ба ман', () {
    QAPage page() => QAPage([
          QAItem('q1', 'Аз чӣ метарсед?', 'Аз ҳеҷ', 'answered', true, false,
              const MiniUser('u2', 'secret_asker', ''), DateTime.now()),
          QAItem('q2', 'Чӣ мехонед?', 'Шоҳнома', 'answered', false, false,
              const MiniUser('u3', 'ali', ''), DateTime.now()),
        ], true, 0, 'followers');

    testWidgets('беном: номи савoлдиҳанда нишон дода намешавад', (t) async {
      await t.pumpWidget(_app(Scaffold(
          body: ProfileAnswersTab(userId: 'u1', isMe: false, load: (_) async => page()))));
      await t.pump();
      expect(find.text('Аз ҳеҷ'), findsOneWidget);
      expect(find.text(tr('qa.anon')), findsOneWidget);
      expect(find.textContaining('secret_asker'), findsNothing);
      expect(find.text('@ali'), findsOneWidget);
      expect(find.byKey(const ValueKey('qa-ask')), findsOneWidget);
    });

    testWidgets('соҳиб қуттиро мебинад, тугмаи савол не', (t) async {
      await t.pumpWidget(_app(Scaffold(
          body: ProfileAnswersTab(userId: 'u1', isMe: true, load: (_) async => page()))));
      await t.pump();
      expect(find.byKey(const ValueKey('qa-inbox')), findsOneWidget);
      expect(find.byKey(const ValueKey('qa-ask')), findsNothing);
    });

    testWidgets('савол бо байрақи беном фиристода мешавад', (t) async {
      String? text;
      bool? anon;
      await t.pumpWidget(_app(Scaffold(
          body: AskQuestionSheet(
              userId: 'u1',
              send: (x, a) async {
                text = x;
                anon = a;
              }))));
      await t.enterText(find.byKey(const ValueKey('qa-text')), 'Салом, чӣ хел?');
      await t.tap(find.byKey(const ValueKey('qa-anon')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('qa-send')));
      await t.pump();
      expect(text, 'Салом, чӣ хел?');
      expect(anon, isTrue);
    });
  });

  group('Мактуб ба оянда', () {
    final sealed = Capsule(
        id: 'c1',
        audience: 'friend',
        note: 'Барои 2027',
        author: const MiniUser('a', 'ali', ''),
        unlockAt: DateTime.now().add(const Duration(days: 3)));

    testWidgets('лифофаи мӯҳр: ҳисоби баръакс, матн нест', (t) async {
      await t.pumpWidget(_app(CapsuleDetailScreen(
          capsuleId: 'c1', initial: sealed, load: () async => sealed)));
      await t.pump();
      expect(find.byKey(const ValueKey('cap-locked')), findsOneWidget);
      expect(find.byKey(const ValueKey('cap-text')), findsNothing);
      expect(find.textContaining(tr('cap.opensIn')), findsOneWidget);
      expect(find.text('«Барои 2027»'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('кушодашуда: матн', (t) async {
      final open = Capsule(
          id: 'c1', text: 'Салом аз гузашта', opened: true,
          author: const MiniUser('a', 'ali', ''),
          unlockAt: DateTime.now().subtract(const Duration(days: 1)));
      await t.pumpWidget(_app(CapsuleDetailScreen(
          capsuleId: 'c1', initial: open, load: () async => open)));
      await t.pump();
      expect(find.text('Салом аз гузашта'), findsOneWidget);
    });

    testWidgets('қуттӣ: ду таб', (t) async {
      await t.pumpWidget(_app(CapsulesScreen(load: (_) async => [sealed])));
      await t.pump();
      expect(find.text(tr('cap.inbox')), findsOneWidget);
      expect(find.text(tr('cap.sent')), findsOneWidget);
      expect(find.text(tr('cap.from', {'user': 'ali'})), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });
  });

  group('Чаленҷ', () {
    final ch = Challenge(
      id: 'ch1',
      tag: 'рақс',
      title: 'Рақси миллӣ',
      startsAt: DateTime.now().subtract(const Duration(days: 1)),
      endsAt: DateTime.now().add(const Duration(days: 6)),
      participants: 2,
      joined: true,
      myEntry: const ChallengeEntry(2, 2, MiniUser('b', 'bob', ''), 'post', 'p1'),
      leaderboard: const [
        ChallengeEntry(1, 3, MiniUser('h', 'hana', ''), 'reel', 'r1'),
        ChallengeEntry(2, 2, MiniUser('b', 'bob', ''), 'post', 'p1'),
      ],
    );

    testWidgets('саҳифа: ҷадвал, иштироки ман, тугмаи иштирок', (t) async {
      await t.pumpWidget(_app(ChallengeDetailScreen(challengeId: 'ch1', load: () async => ch)));
      await t.pump();
      expect(find.text('#рақс'), findsOneWidget);
      expect(find.text('hana'), findsOneWidget);
      expect(find.text('🥇'), findsOneWidget);
      expect(find.byKey(const ValueKey('chl-my-entry')), findsOneWidget);
      expect(find.byKey(const ValueKey('chl-join')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('Explore: «Чаленҷҳо»; холӣ — пинҳон', (t) async {
      await t.pumpWidget(_app(Scaffold(body: ChallengesRow(load: () async => [ch]))));
      await t.pump();
      expect(find.byKey(const ValueKey('chl-all')), findsOneWidget);
      expect(find.text('#рақс'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(_app(Scaffold(body: ChallengesRow(load: () async => const []))));
      await t.pump();
      expect(find.byKey(const ValueKey('chl-all')), findsNothing);
    });

    testWidgets('нишони ғолиб дар профил', (t) async {
      await t.pumpWidget(_app(Scaffold(
          body: ChallengeBadgesRow(
              userId: 'b',
              load: (_) async => const [ChallengeBadge(1, 'ch1', 'рақс', 'Рақс')]))));
      await t.pump();
      expect(find.byKey(const ValueKey('badge-ch1')), findsOneWidget);
      expect(find.textContaining('🥇'), findsOneWidget);
    });
  });

  testWidgets('менюи «+» → «Бештар»: се имконият', (t) async {
    await t.pumpWidget(_app(const Scaffold(body: CreateMoreSheet())));
    expect(find.byKey(const ValueKey('more-event')), findsOneWidget);
    expect(find.byKey(const ValueKey('more-capsule')), findsOneWidget);
    expect(find.byKey(const ValueKey('more-challenge')), findsOneWidget);
  });

  test('ҳисоби баръакс', () {
    expect(formatCountdown(const Duration(days: 2, hours: 3, minutes: 4)), contains('2'));
    expect(formatCountdown(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
    expect(formatCountdown(const Duration(seconds: -5)), '00:00:00');
  });
}
