import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/music/song_info.dart';

// «Номаш ҳасту намехонад».
//
// Постҳои КӮҲНА танҳо ном ва хонанда доранд: он вақт барнома
// суроғаи сурудро умуман намефиристод. Дар экран ном менамуд, вале
// зада ҳеҷ чиз намешуд — на садо, на хато, на фаҳмиш.
//
// Постҳои НАВ суроғаро доранд ва фавран мехонанд. Барои кӯҳнаҳо
// суруд аз рӯи ном ёфта мешавад.

void main() {
  group('SongInfo', () {
    test('суруди бе суроға навишта мешавад, вале намехонад', () {
      const s = SongInfo(title: 'Суруд', artist: 'Х', artUrl: '');
      expect(s.isNotEmpty, isTrue, reason: 'ном бояд навишта шавад');
      expect(s.playable, isFalse, reason: 'бе суроға хондан мумкин нест');
    });

    test('суруди бо суроға мехонад', () {
      const s = SongInfo(
          title: 'Суруд',
          artist: 'Х',
          artUrl: '',
          previewUrl: 'https://audio-ssl.itunes.apple.com/x.m4a');
      expect(s.playable, isTrue);
    });
  });

  group('сатри музика', () {
    late String src;
    setUpAll(() =>
        src = File('lib/core/music/music_bar.dart').readAsStringSync());

    test('суроғаи нарасида аз рӯи ном ёфта мешавад', () {
      expect(src, contains('_lookup('),
          reason: 'пости кӯҳна ҳеҷ гоҳ намехонад — '
              'номаш ҳасту садо нест');
      expect(src, contains('itunes.apple.com/search'),
          reason: 'ҷустуҷӯ аз ҳамон манбаъ нест — '
              'суруди дигар ёфта мешавад');
    });

    test('зер кардан ҳатто бе суроға кор мекунад', () {
      // Пеш `onTap` барои чунин пост `null` буд — тугма мурда буд.
      expect(src, contains('onTap: _canPlay ? _toggle : null'),
          reason: 'тугма барои пости кӯҳна мурда аст');
      expect(src, contains('_song.playable || _song.title.isNotEmpty'),
          reason: 'имкони хондан танҳо аз рӯи суроға санҷида мешавад');
    });

    test('суруди ёфташуда ҷои оғози худи постро нигоҳ медорад', () {
      // Вагарна ҳамеша аз сари суруд мехонд — ҳамон камбудии кӯҳна.
      expect(src, contains('s.copyWith('),
          reason: 'маълумоти пост партофта мешавад');
      expect(src, contains('previewUrl: url'));
    });

    test('ҷустуҷӯ вақти маҳдуд дорад', () {
      // Бе ин шабакаи суст тугмаро абадан банд мекард.
      expect(src, contains('timeout(const Duration(seconds: 6))'));
    });
  });

  group('нашр суроғаро мефиристад', () {
    test('пост', () {
      final src =
          File('lib/create/upload/post_upload_service.dart').readAsStringSync();
      expect(src, contains("'song': song.toJson()"),
          reason: 'пости НАВ низ бе суроға сабт мешавад');
    });

    test('стори', () {
      final src = File('lib/create/create_story/create_story_screen.dart')
          .readAsStringSync();
      expect(src, contains("'song': song.toJson()"));
    });
  });
}
