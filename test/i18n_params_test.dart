// test/i18n_params_test.dart
// Санҷиши сатрҳои параметрдор.
//
// Пеш аз ин, ҷумлаҳо дар Dart аз пораҳо сохта мешуданд ('$n пост'), ки
// тарҷумашаванда набуданд: иваз кардани забон танҳо як қисми экранро
// тағйир медод. Ин тестҳо тафтиш мекунанд, ки ҳар се забон кор мекунад
// ва ҷойгирҳо воқеан пур мешаванд.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raonson/app/app_settings.dart';
import 'package:raonson/core/i18n/strings.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettingsState.instance.setLang('tj');
  });

  test('ҷойгир бо арзиш иваз мешавад', () {
    expect(tr('count.posts.many', {'n': 5}), '5 пост');
    expect(tr('story.replyTo', {'user': 'ali'}), 'ali-га ҷавоб...');
  });

  test('ҳеҷ ҷойгири пуркарданашуда намемонад', () {
    final filled = tr('profile.followedByMore',
        {'first': 'a', 'second': 'b', 'n': 3});
    expect(filled.contains('{'), isFalse,
        reason: 'ҷойгири боқимонда: $filled');
  });

  test('бе параметр tr() мисли пештара кор мекунад', () {
    // 2843 ҷои даъвати мавҷуда параметр намедиҳанд — набояд вайрон шаванд.
    expect(tr('settings.title'), isNotEmpty);
    expect(tr('settings.title'), isNot(contains('{')));
  });

  test('калиди номаълум худи калидро бармегардонад', () {
    expect(tr('no.such.key.exists'), 'no.such.key.exists');
  });

  group('забонҳо', () {
    test('ҳар се забон ҷавоби ҷудогона медиҳанд', () async {
      final tj = tr('count.members.many', {'n': 3});

      await AppSettingsState.instance.setLang('ru');
      final ru = tr('count.members.few', {'n': 3});

      await AppSettingsState.instance.setLang('en');
      final en = tr('count.members.many', {'n': 3});

      expect(tj, '3 аъзо');
      expect(ru, '3 участника');
      expect(en, '3 members');
    });

    test('забони номаълум ба тоҷикӣ бармегардад', () async {
      await AppSettingsState.instance.setLang('de');
      expect(tr('count.posts.many', {'n': 2}), '2 пост');
    });
  });

  group('ҷамъбасти ҳафтагӣ', () {
    // Ин ду сатр ҷойгир доранд ва дар ҳар се забон бояд пур шаванд:
    // «Ҳафтаи {date}» бе сана маъно надорад.
    test('ҷойгирҳо дар ҳар се забон пур мешаванд', () async {
      for (final lang in ['tj', 'ru', 'en']) {
        await AppSettingsState.instance.setLang(lang);

        final week = tr('recap.weekOf', {'date': '2026-08-24'});
        expect(week, contains('2026-08-24'), reason: lang);
        expect(week, isNot(contains('{')), reason: lang);

        final topic = tr('recap.topTopicIs', {'topic': 'Бозиҳо'});
        expect(topic, contains('Бозиҳо'), reason: lang);
        expect(topic, isNot(contains('{')), reason: lang);
      }
    });

    test('ҳар се забон матни худро дорад', () async {
      final seen = <String>{};
      for (final lang in ['tj', 'ru', 'en']) {
        await AppSettingsState.instance.setLang(lang);
        final t = tr('recap.quietWeek');
        // Калид ҳамчун матн баргардонда нашавад — яъне тарҷума ҳаст.
        expect(t, isNot('recap.quietWeek'), reason: lang);
        seen.add(t);
      }
      expect(seen.length, 3, reason: 'забонҳо матни якхела доранд');
    });
  });

  group('нишонҳо', () {
    // Рамзҳо дар сервер муайян мешаванд (creator/achievements.go).
    // Агар тарҷума набошад, корбар рамзи техникиро мебинад.
    const codes = [
      'firstPost',
      'tenPosts',
      'fiftyPosts',
      'tenFollowers',
      'hundredFollowers',
      'thousandFollowers',
      'thousandViews',
      'tenThousandViews',
      'hundredLikes',
      'fourActiveWeeks',
    ];

    test('ҳар рамз дар ҳар се забон ном дорад', () async {
      for (final lang in ['tj', 'ru', 'en']) {
        await AppSettingsState.instance.setLang(lang);
        for (final c in codes) {
          final key = 'ach.code.$c';
          expect(tr(key), isNot(key), reason: '$lang: $key тарҷума надорад');
        }
      }
    });

    test('зина рақами худро нишон медиҳад', () async {
      for (final lang in ['tj', 'ru', 'en']) {
        await AppSettingsState.instance.setLang(lang);
        expect(tr('ach.levelN', {'n': 3}), contains('3'), reason: lang);
        expect(tr('ach.toNext', {'n': 4}), contains('4'), reason: lang);
        expect(tr('ach.toNext', {'n': 4}), isNot(contains('{')), reason: lang);
      }
    });
  });

  group('ҳамкорӣ ва даъват', () {
    test('номи корбар дар матн ҷойгир мешавад', () async {
      for (final lang in ['tj', 'ru', 'en']) {
        await AppSettingsState.instance.setLang(lang);
        final t = tr('collab.invitedYou', {'user': 'ali'});
        expect(t, contains('ali'), reason: lang);
        expect(t, isNot(contains('{')), reason: lang);
      }
    });

    test('матнҳои даъват дар ҳар се забон ҳастанд', () async {
      const keys = [
        'collab.title',
        'collab.accept',
        'collab.decline',
        'collab.none',
        'invite.title',
        'invite.yourCode',
        'invite.nobodyYet',
      ];
      for (final lang in ['tj', 'ru', 'en']) {
        await AppSettingsState.instance.setLang(lang);
        for (final k in keys) {
          expect(tr(k), isNot(k), reason: '$lang: $k тарҷума надорад');
        }
      }
    });
  });

  group('ҷамъбандӣ', () {
    test('тоҷикӣ: як ва зиёд', () {
      expect(trn('count.votes', 1), '1 овоз');
      expect(trn('count.votes', 7), '7 овоз');
    });

    test('англисӣ: шакли ҷамъ', () async {
      await AppSettingsState.instance.setLang('en');
      expect(trn('count.posts', 1), '1 post');
      expect(trn('count.posts', 4), '4 posts');
    });

    test('русӣ: се шакл — 1, 2-4, 5+', () async {
      await AppSettingsState.instance.setLang('ru');
      expect(trn('count.members', 1), '1 участник');
      expect(trn('count.members', 3), '3 участника');
      expect(trn('count.members', 8), '8 участников');
    });

    test('русӣ: 11-14 шакли «зиёд» мегиранд, на «кам»', () async {
      await AppSettingsState.instance.setLang('ru');
      // 12 бо 2 тамом мешавад, вале 12 участника ХАТОСТ.
      expect(trn('count.members', 12), '12 участников');
      expect(trn('count.members', 13), '13 участников');
      // 22 бошад дуруст «участника» мегирад.
      expect(trn('count.members', 22), '22 участника');
      expect(trn('count.members', 21), '21 участник');
    });
  });
}
