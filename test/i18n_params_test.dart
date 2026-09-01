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
