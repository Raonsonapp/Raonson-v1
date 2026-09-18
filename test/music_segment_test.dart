import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/music/music_bar.dart';
import 'package:raonson/core/music/song_info.dart';

// Мантиқи порчаи суруд.
//
// Ин ҳисоб дар се ҷо истифода мешавад (интихоб, стори, пост), пас
// хатогии он дар ҳама ҷо якбора пайдо мешуд. Маҳз ин ҷо камбудии
// аслӣ буд: панели стори ва пост `seek` намекарданд ва ҳамеша аз
// сифр мехонданд.

void main() {
  SongInfo song({int trackMs = 210000, int startMs = 0, int endMs = 15000}) =>
      SongInfo(
        title: 'Суруд',
        artist: 'Хонанда',
        artUrl: '',
        previewUrl: 'https://audio-ssl.itunes.apple.com/x.m4a',
        trackMs: trackMs,
        startMs: startMs,
        endMs: endMs,
      );

  group('previewOffsetMs', () {
    test('оғоз аз сар — офсет сифр аст', () {
      expect(previewOffsetMs(song(startMs: 0)), 0);
    });

    test('миёнаи суруд ба миёнаи preview мерасад', () {
      // 105с аз 210с = нисфи суруд → нисфи preview-и 30с = 15с.
      // Вале тирезаи 15с аз охири preview намебарояд, пас 15000.
      expect(previewOffsetMs(song(startMs: 105000)), 15000);
    });

    test('офсет ҳеҷ гоҳ аз охири preview намегузарад', () {
      // Бе ин маҳдудият плеер аз ҷои холӣ мехонд ва хомӯш мемонд.
      final o = previewOffsetMs(song(startMs: 200000));
      expect(o, lessThanOrEqualTo(kPreviewMs - 15000));
      expect(o, 15000);
    });

    test('тирезаи 30-сония ҳамеша аз сар мехонад', () {
      // Тиреза ба ҳама preview баробар аст — ҷои дигар нест.
      expect(previewOffsetMs(song(startMs: 90000, endMs: 120000)), 0);
    });

    test('дарозии нофаҳмои суруд барномаро вайрон намекунад', () {
      expect(previewOffsetMs(song(trackMs: 0, startMs: 5000)), isNonNegative);
    });
  });

  group('SongInfo', () {
    test('windowMs дарозии порчаро медиҳад', () {
      expect(song(startMs: 30000, endMs: 45000).windowMs, 15000);
    });

    test('тирезаи вайрон ба ҳудуд оварда мешавад', () {
      // `end <= start` маънои надорад — плеер фавран ҳалқа мезад.
      expect(song(startMs: 30000, endMs: 10000).windowMs, greaterThan(0));
    });

    test('label номи хонандаро дар бар мегирад', () {
      expect(song().label, 'Суруд — Хонанда');
    });

    test('бе хонанда танҳо ном', () {
      const s = SongInfo(title: 'Суруд', artist: '', artUrl: '');
      expect(s.label, 'Суруд');
    });

    test('суруди бе суроға навишта мешавад, вале намехонад', () {
      const s = SongInfo(title: 'Суруд', artist: 'Х', artUrl: '');
      expect(s.isNotEmpty, isTrue);
      expect(s.playable, isFalse);
    });

    test('JSON рафту баргашт маълумотро гум намекунад', () {
      final a = song(startMs: 42000, endMs: 57000);
      final b = SongInfo.fromJson(a.toJson());
      expect(b.title, a.title);
      // Маҳз ин се майдон дар стори ва пост гум мешуданд.
      expect(b.artist, a.artist);
      expect(b.previewUrl, a.previewUrl);
      expect(b.startMs, a.startMs);
      expect(b.endMs, a.endMs);
    });

    test('JSON-и холӣ суруди холӣ медиҳад', () {
      expect(SongInfo.fromJson(null).isEmpty, isTrue);
    });
  });
}
