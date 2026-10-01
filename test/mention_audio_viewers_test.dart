import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/music/feed_audio.dart';
import 'package:raonson/stories/story_viewers_cache.dart';
import 'package:raonson/widgets/mention_suggestions.dart';

TextEditingValue _v(String text, [int? cursor]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor ?? text.length));

void main() {
  group('@зикр — таҳлили матн', () {
    test('калимаи @ зери курсор', () {
      expect(activeMentionQuery(_v('@eh')), 'eh');
      expect(activeMentionQuery(_v('салом @eh')), 'eh');
      expect(activeMentionQuery(_v('@')), '');
      expect(activeMentionQuery(_v('салом')), isNull);
      expect(activeMentionQuery(_v('a@b.c')), isNull); // email
      expect(activeMentionQuery(_v('@eh дӯст')), isNull);
      expect(activeMentionQuery(_v('@eh дӯст', 3)), 'eh');
      expect(activeMentionQuery(_v('@ҷамшед')), 'ҷамшед');
    });

    test('майдони «Зикр» — бо ё бе @', () {
      expect(wholeFieldMentionQuery('@eh'), 'eh');
      expect(wholeFieldMentionQuery('eh'), 'eh');
      expect(wholeFieldMentionQuery('@'), '');
      expect(wholeFieldMentionQuery('eh son'), isNull);
    });

    test('гузоштани номи дақиқ', () {
      final r = insertMention(_v('салом @eh'), 'ehson.m');
      expect(r.text, 'салом @ehson.m ');
      expect(r.selection.baseOffset, r.text.length);
      final mid = insertMention(_v('@eh дӯст', 3), 'ehson');
      expect(mid.text, '@ehson дӯст');
    });
  });

  group('MentionSuggestions', () {
    Future<void> pump(WidgetTester t, TextEditingController c,
        MentionSearch search,
        {ValueChanged<MentionUser>? onPick, bool whole = false}) {
      return t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            TextField(controller: c),
            MentionSuggestions(
                controller: c,
                search: search,
                onPick: onPick,
                wholeField: whole),
          ]),
        ),
      ));
    }

    testWidgets('debounce, ҷавоби кӯҳна партофта мешавад, зарба ном мегузорад',
        (t) async {
      final calls = <String>[];
      final pending = <String, Completer<List<MentionUser>>>{};
      Future<List<MentionUser>> search(String q) {
        calls.add(q);
        return (pending[q] = Completer<List<MentionUser>>()).future;
      }

      final c = TextEditingController();
      await pump(t, c, search);
      c.value = _v('@e');
      await t.pump(const Duration(milliseconds: 100));
      c.value = _v('@eh');
      await t.pump(const Duration(milliseconds: 100));
      expect(calls, isEmpty); // ҳанӯз debounce
      await t.pump(const Duration(milliseconds: 200));
      expect(calls, ['eh']);

      c.value = _v('@ehs');
      await t.pump(const Duration(milliseconds: 300));
      expect(calls, ['eh', 'ehs']);
      // Ҷавоби кӯҳна дертар омад — нишон дода намешавад.
      pending['eh']!.complete(
          const [MentionUser(id: '1', username: 'old_user')]);
      await t.pump();
      await t.pump();
      expect(find.text('old_user'), findsNothing);

      pending['ehs']!.complete(const [
        MentionUser(id: '2', username: 'ehson', verified: true),
      ]);
      await t.pump();
      await t.pump();
      expect(find.text('ehson'), findsOneWidget);
      await t.tap(find.text('ehson'));
      await t.pump();
      expect(c.text, '@ehson ');
      expect(find.text('ehson'), findsNothing);
    });

    testWidgets('хатои шабака — хомӯшона', (t) async {
      final c = TextEditingController();
      await pump(t, c, (_) async => throw Exception('offline'));
      c.value = _v('@eh');
      await t.pump(const Duration(milliseconds: 300));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('майдони «Зикр»: onPick номи дақиқро мегирад', (t) async {
      MentionUser? picked;
      final c = TextEditingController(text: '@');
      await pump(t, c,
          (_) async => const [MentionUser(id: '1', username: 'ehson_m')],
          onPick: (u) => picked = u, whole: true);
      c.value = _v('eh');
      await t.pump(const Duration(milliseconds: 300));
      await t.pump();
      await t.pump();
      await t.tap(find.text('ehson_m'));
      expect(picked?.username, 'ehson_m');
    });
  });

  group('Фокуси садо', () {
    test('саҳифаи болоӣ фокус дорад; bottom sheet фокусро намегирад', () {
      final audio = FeedAudio.instance;
      final obs = AudioFocusObserver(audio: audio);
      final home = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      final story = PageRouteBuilder<void>(
          opaque: false, pageBuilder: (_, __, ___) => const SizedBox());
      final sheet = ModalBottomSheetRoute<void>(
          builder: (_) => const SizedBox(), isScrollControlled: false);

      obs.didPush(home, null);
      expect(audio.hasFocus(home), isTrue);

      obs.didPush(sheet, home);
      expect(audio.hasFocus(home), isTrue);
      obs.didPop(sheet, home);

      obs.didPush(story, home);
      expect(audio.hasFocus(home), isFalse); // музикаи лента хомӯш
      expect(audio.hasFocus(story), isTrue);

      obs.didPop(story, home);
      expect(audio.hasFocus(home), isTrue); // баъди бастан бармегардад

      obs.didRemove(home, null);
      expect(audio.focusRoute.value, isNull);
    });
  });

  group('Кэши «Кӣ дид»', () {
    test('prefetch, кэш фаврӣ, дархостҳо якҷоя, хато кэшро намепартояд',
        () async {
      var calls = 0;
      var fail = false;
      final cache = StoryViewersCache(fetcher: (id) async {
        calls++;
        if (fail) throw Exception('offline');
        return {
          'viewsCount': 7,
          'viewers': [
            {'avatar': 'a1'},
            {'avatar': ''},
            {'avatar': 'a3'},
            {'avatar': 'a4'},
          ],
        };
      });
      expect(cache.preview('s1'), isNull);
      cache.prefetch(['s1']);
      final f = cache.refresh('s1'); // ҳамон дархост
      await f;
      expect(calls, 1);
      final p = cache.preview('s1')!;
      expect(p.count, 7);
      expect(p.avatars, ['a1', 'a3']);

      fail = true;
      final b = await cache.refresh('s1');
      expect(b, isNotNull);
      expect(cache.preview('s1')!.count, 7);
    });
  });
}
