// test/hashtag_widgets_test.dart
// Хештегҳои зерклик (LinkedText / linkedSpans), пешниҳоди «#…» ҳангоми
// навиштан ва сатри «Трендҳо».
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/hashtags/hashtag_repository.dart';
import 'package:raonson/search/trending_hashtags_row.dart';
import 'package:raonson/widgets/hashtag_suggestions.dart';
import 'package:raonson/widgets/linked_text.dart';

TextEditingValue _v(String text, [int? cursor]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor ?? text.length));

/// MaterialApp, ки роҳҳои /hashtag ва /profile-by-username-ро сабт мекунад.
Widget _app(Widget child, List<String> opened) => MaterialApp(
      home: Scaffold(body: child),
      onGenerateRoute: (s) {
        opened.add('${s.name}:${s.arguments}');
        return MaterialPageRoute(builder: (_) => const SizedBox());
      },
    );

void main() {
  group('LinkedText — хештегҳо зерклик', () {
    testWidgets('хештеги тоҷикӣ ба шакли муқаррарӣ мебарад', (t) async {
      final opened = <String>[];
      await t.pumpWidget(_app(
          const LinkedText('Салом #Ҳисор!\n#кино🎬 ва @ali.',
              style: TextStyle(fontSize: 14)),
          opened));
      // Пеш `[^\w]` «#Ҳисор»-ро ба «» табдил медод.
      expect(find.text('#Ҳисор'), findsOneWidget);
      await t.tap(find.text('#Ҳисор'));
      await t.pumpAndSettle();
      expect(opened.last, '/hashtag:ҳисор');
    });

    testWidgets('сатри нав хештегҳоро ҷудо мекунад; зикр ба профил', (t) async {
      final opened = <String>[];
      await t.pumpWidget(_app(
          const LinkedText('#a1\n#b2 @ali.', style: TextStyle(fontSize: 14)),
          opened));
      await t.tap(find.text('#b2'));
      await t.pumpAndSettle();
      expect(opened.last, '/hashtag:b2');
      t.state<NavigatorState>(find.byType(Navigator)).pop();
      await t.pumpAndSettle();
      await t.tap(find.text('@ali'));
      await t.pumpAndSettle();
      expect(opened.last, '/profile-by-username:ali');
    });

    testWidgets('«#» дар URL зер намешавад', (t) async {
      await t.pumpWidget(_app(
          const LinkedText('https://x.tj/a#b', style: TextStyle(fontSize: 14)),
          []));
      expect(find.byKey(const ValueKey('tag-b')), findsNothing);
    });

    testWidgets('linkedSpans: callback-и худ', (t) async {
      String? got;
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Text.rich(TextSpan(
                children: linkedSpans(ctx, 'бо #Тег',
                    style: const TextStyle(), onHashtag: (v) => got = v))),
          ),
        ),
      ));
      await t.tap(find.text('#Тег'));
      expect(got, 'тег');
    });
  });

  group('«#» — таҳлили майдон', () {
    test('хештеги зери курсор', () {
      expect(activeHashtagQuery(_v('#ду')), 'ду');
      expect(activeHashtagQuery(_v('салом #Ҳис')), 'Ҳис');
      expect(activeHashtagQuery(_v('#')), '');
      expect(activeHashtagQuery(_v('салом')), isNull);
      expect(activeHashtagQuery(_v('a#b')), isNull);
      expect(activeHashtagQuery(_v('#ду шанбе')), isNull);
      expect(activeHashtagQuery(_v('#ду шанбе', 3)), 'ду');
      expect(activeHashtagQuery(_v('🎬#кино')), 'кино');
    });

    test('гузоштани хештеги пурра', () {
      final r = insertHashtag(_v('салом #ду'), 'душанбе');
      expect(r.text, 'салом #душанбе ');
      expect(r.selection.baseOffset, r.text.length);
      final mid = insertHashtag(_v('#ду ва', 3), 'душанбе');
      expect(mid.text, '#душанбе ва');
    });
  });

  group('HashtagSuggestions', () {
    testWidgets('debounce, «#tag · 1.2K пост», зарба хештег мегузорад',
        (t) async {
      final calls = <String>[];
      final pending = <String, Completer<List<HashtagCount>>>{};
      Future<List<HashtagCount>> search(String q) {
        calls.add(q);
        return (pending[q] = Completer<List<HashtagCount>>()).future;
      }

      final c = TextEditingController();
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            TextField(controller: c),
            HashtagSuggestions(controller: c, search: search),
          ]),
        ),
      ));
      c.value = _v('салом #д');
      await t.pump(const Duration(milliseconds: 100));
      c.value = _v('салом #ду');
      await t.pump(const Duration(milliseconds: 100));
      expect(calls, isEmpty);
      await t.pump(const Duration(milliseconds: 200));
      expect(calls, ['ду']);

      c.value = _v('салом #душ');
      await t.pump(const Duration(milliseconds: 300));
      pending['ду']!.complete(const [HashtagCount('дуруст', 3)]);
      await t.pump();
      expect(find.byKey(const ValueKey('hashtag-suggestion-дуруст')), findsNothing);

      pending['душ']!.complete(const [HashtagCount('душанбе', 1200)]);
      await t.pump();
      await t.pump();
      expect(find.byKey(const ValueKey('hashtag-suggestion-душанбе')), findsOneWidget);
      expect(find.textContaining('1.2K пост', findRichText: true), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('hashtag-suggestion-душанбе')));
      await t.pump();
      expect(c.text, 'салом #душанбе ');
      expect(find.byKey(const ValueKey('hashtag-suggestion-душанбе')), findsNothing);
    });

    testWidgets('хатои шабака — хомӯшона', (t) async {
      final c = TextEditingController();
      await t.pumpWidget(MaterialApp(
        home: Scaffold(
          body: HashtagSuggestions(
              controller: c, search: (_) async => throw Exception('net')),
        ),
      ));
      c.value = _v('#ду');
      await t.pump(const Duration(milliseconds: 300));
      await t.pump();
      expect(find.byType(InkWell), findsNothing);
    });
  });

  testWidgets('«Трендҳо»: чипҳо ва зарба ба саҳифаи хештег', (t) async {
    final opened = <String>[];
    await t.pumpWidget(_app(
        TrendingHashtagsRow(
            load: () async => const [HashtagCount('наврӯз', 40), HashtagCount('кино', 9)]),
        opened));
    await t.pump();
    expect(find.text('Трендҳо'), findsOneWidget);
    expect(find.text('#наврӯз'), findsOneWidget);
    await t.tap(find.text('#кино'));
    await t.pumpAndSettle();
    expect(opened.last, '/hashtag:кино');
  });

  testWidgets('«Трендҳо»: холӣ — пинҳон', (t) async {
    await t.pumpWidget(_app(TrendingHashtagsRow(load: () async => const []), []));
    await t.pump();
    expect(find.text('Трендҳо'), findsNothing);
  });
}
