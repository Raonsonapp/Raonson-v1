import 'dart:io';

import 'package:flutter/material.dart';
import 'package:raonson/core/ui/app_icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/models/story_model.dart';
import 'package:raonson/stories/story_sticker.dart';

// Стикерҳои сторис — мисли Instagram.
Widget _host(StorySticker s) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: StoryStickerView(
            storyId: 's1', sticker: s,
            onPause: () {}, onResume: () {},
          ),
        ),
      ),
    );

void main() {
  group('модел', () {
    test('стори стикерро аз сервер мехонад', () {
      final st = StoryModel.fromJson({
        '_id': 's1', 'mediaUrl': 'https://x/y.jpg', 'mediaType': 'image',
        'expiresAt': '2099-01-01T00:00:00Z',
        'user': {'_id': 'u', 'username': 'u'},
        'sticker': {
          'kind': 'quiz', 'prompt': 'Пойтахт?',
          'options': ['Хуҷанд', 'Душанбе'], 'x': 0.5, 'y': 0.6,
        },
      });
      expect(st.sticker?.kind, 'quiz');
      expect(st.sticker?.options, ['Хуҷанд', 'Душанбе']);
      expect(st.sticker?.correct, isNull,
          reason: 'ҷавоби дуруст пеш аз ҷавоб набояд бошад');
    });

    test('намуди нобуд рад мешавад', () {
      expect(StorySticker.fromJson({'kind': 'nest'}), isNull);
      expect(StorySticker.fromJson(null), isNull);
    });

    test('ҳисоби баръакс', () {
      expect(countdownLabel(const Duration(days: 2, hours: 3, minutes: 4, seconds: 5)),
          '2р 03:04:05');
      expect(countdownLabel(const Duration(minutes: 1, seconds: 2)), '00:01:02');
      expect(countdownLabel(const Duration(seconds: -1)), 'Анҷом ёфт');
    });
  });

  group('линк ва упоминание', () {
    test('стикери линк хонда мешавад', () {
      final s = StorySticker.fromJson(
          {'kind': 'link', 'prompt': 'Ёрдам', 'url': 'https://raonson.app/help'});
      expect(s?.kind, 'link');
      expect(s?.url, 'https://raonson.app/help');
    });

    test('упоминаниеҳо бо ҷойгиршавӣ хонда мешаванд', () {
      final st = StoryModel.fromJson({
        '_id': 's', 'mediaUrl': 'https://x/y.jpg', 'mediaType': 'image',
        'expiresAt': '2099-01-01T00:00:00Z', 'user': {'_id': 'u', 'username': 'u'},
        'mentions': [
          {'userId': 'b', 'username': 'bob', 'x': 0.3, 'y': 0.4},
          {'userId': '', 'username': 'бе-id'},
        ],
      });
      expect(st.mentions.length, 1, reason: 'упоминание бе userId зада намешавад');
      expect(st.mentions.first.username, 'bob');
      expect(st.mentions.first.x, closeTo(0.3, 0.001));
    });

    testWidgets('линк нишон дода мешавад', (t) async {
      await t.pumpWidget(_host(const StorySticker(
          kind: 'link', prompt: 'Ёрдам', url: 'https://raonson.app/help')));
      expect(find.text('Ёрдам'), findsOneWidget);
    });
  });

  group('навбати ту', () {
    test('стикер хонда мешавад', () {
      final s = StorySticker.fromJson({
        'kind': 'addyours', 'prompt': 'Акси аввали телефонат',
        'chainId': 'c1', 'participants': 3, 'joined': true,
        'avatars': ['https://x/a.jpg'],
      });
      expect(s?.kind, 'addyours');
      expect(s?.chainId, 'c1');
      expect(s?.participants, 3);
      expect(s?.joined, isTrue);
    });

    testWidgets('тамошобин тугмаи «Навбати ман»-ро мебинад ва мезанад', (t) async {
      var tapped = false;
      await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(
        child: StoryStickerView(
          storyId: 's1',
          sticker: const StorySticker(kind: 'addyours', prompt: 'Мавзӯъ',
              participants: 2),
          onPause: () {}, onResume: () {},
          onAddYours: () => tapped = true,
        ),
      ))));
      expect(find.text('Мавзӯъ'), findsOneWidget);
      expect(find.text('2 иштирокчӣ'), findsOneWidget);
      await t.tap(find.text('Навбати ман'));
      expect(tapped, isTrue);
    });

    testWidgets('соҳиб тугмаи ҳамроҳшавиро намебинад', (t) async {
      await t.pumpWidget(_host(const StorySticker(
          kind: 'addyours', prompt: 'Мавзӯъ', isOwner: true, participants: 1)));
      expect(find.text('Навбати ман'), findsNothing);
      expect(find.text('1 иштирокчӣ'), findsOneWidget);
    });
  });

  group('намоиш', () {
    testWidgets('викторина: пеш аз ҷавоб фоиз ва дуруст нест', (t) async {
      await t.pumpWidget(_host(const StorySticker(
          kind: 'quiz', prompt: 'Пойтахт?', options: ['Хуҷанд', 'Душанбе'])));
      expect(find.text('Пойтахт?'), findsOneWidget);
      expect(find.text('Душанбе'), findsOneWidget);
      expect(find.byIcon(AppIcons.check_circle), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('викторина: баъд аз ҷавоби нодуруст — ҳарду ранг', (t) async {
      await t.pumpWidget(_host(const StorySticker(
          kind: 'quiz', prompt: '?', options: ['a', 'b', 'c'],
          myChoice: 0, correct: 1, counts: [1, 3, 0])));
      expect(find.byIcon(AppIcons.check_circle), findsOneWidget); // дуруст
      expect(find.byIcon(AppIcons.cancel_rounded), findsOneWidget);       // ман хато
      expect(find.text('4 ҷавоб'), findsOneWidget);
    });

    testWidgets('слайдер: баъд аз ҷавоб миёна', (t) async {
      await t.pumpWidget(_host(const StorySticker(
          kind: 'slider', prompt: 'Маъқул?', emoji: '🔥',
          myValue: 80, average: 60, responses: 2)));
      expect(find.text('🔥'), findsOneWidget);
      expect(find.text('Миёна: 60% · 2 ҷавоб'), findsOneWidget);
    });

    testWidgets('савол: соҳиб шумораи ҷавобҳоро мебинад', (t) async {
      await t.pumpWidget(_host(const StorySticker(
          kind: 'question', prompt: 'Аз ман пурсед',
          isOwner: true, answersCount: 5)));
      expect(find.text('Ҷавобҳо: 5'), findsOneWidget);
    });

    testWidgets('ҳисоби баръакс ҳар сония нав мешавад', (t) async {
      await t.pumpWidget(_host(StorySticker(
          kind: 'countdown', prompt: 'Зодрӯз',
          endsAt: DateTime.now().add(const Duration(hours: 1)))));
      expect(find.text('ЗОДРӮЗ'), findsOneWidget);
      expect(find.textContaining(':'), findsWidgets);
      await t.pump(const Duration(seconds: 1));
      await t.pumpWidget(const SizedBox()); // таймер бекор шавад
    });
  });

  group('муҳаррир', () {
    test('ҳар чор намуд пешниҳод мешавад ва ба сервер меравад', () {
      final e = File('lib/create/create_story/story_editor.dart').readAsStringSync();
      for (final k in ["'question'", "'quiz'", "'slider'", "'countdown'"]) {
        expect(e, contains(k));
      }
      expect(e, contains('Ақаллан 2 вариант лозим'));
      expect(e, contains('Вақт бояд дар оянда бошад'));
      final c = File('lib/create/create_story/create_story_screen.dart').readAsStringSync();
      expect(c, contains("'sticker': sticker"));
    });
  });
}
