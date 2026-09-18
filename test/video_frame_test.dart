import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Плиткаҳои reel дар explore комилан сиёҳ буданд.
//
// Ин камбудӣ дар матни SQL ва дар ҳамроҳии ду сатри Dart буд, пас
// ягон тести оддии виҷет онро намедид. Ин ҷо маҳз ҳамон ҳамроҳӣ
// санҷида мешавад.

void main() {
  group('гриди explore', () {
    late String src;
    setUpAll(() => src = File('lib/search/search_screen.dart').readAsStringSync());

    test('плитка расмро мустақим ба CachedNetworkImage намедиҳад', () {
      // Маҳз ин сабаби плиткаи сиёҳ буд: агар reel тасвир надошта
      // бошад, сервер суроғаи ВИДЕО медод ва расм кушода намешуд.
      expect(src, contains('VideoFrame('),
          reason: 'плитка кадри аввали видеоро намекашад');
    });

    test('плеер видеоро мекушояд, на тасвирро', () {
      expect(src, contains('widget.item.playUrl'),
          reason: 'плеер `url`-ро мекушояд — барои reel он ТАСВИР аст');
    });

    test('хатогии видео пинҳон намешавад', () {
      // Пеш `catch (_) {}` буд — корбар чархаки абадиро медид.
      expect(src, isNot(contains('await c.initialize();\n      if (!mounted) return;\n      c..setLooping(true)..play();\n      setState(() => _ready = true);\n    } catch (_) {}')),
          reason: 'хатогии видео бе ҳеҷ нишона фурӯ бурда мешавад');
      expect(src, contains('_failed'),
          reason: 'ҳолати нокомии видео нест');
    });
  });

  group('VideoFrame', () {
    late String src;
    setUpAll(() => src = File('lib/core/ui/video_frame.dart').readAsStringSync());

    test('шумораи видеоҳои ҳамзамон маҳдуд аст', () {
      // ⚠️ Ҳар видео як декодери системаро мегирад ва онҳо
      // маҳдуданд (8–16). Бе ҳад грид ҳам худаш, ҳам плеери Reels-ро
      // мешикаст — камбудии аз плиткаи сиёҳ бадтар.
      expect(src, contains('_kMaxLiveFrames'),
          reason: 'ҳадди декодерҳо нест');
      expect(src, contains('_releaseSlot'),
          reason: 'ҷои декодер озод намешавад — баъди ғелонидан тамом мешавад');
    });

    test('ҳар роҳи хуруҷ ҷоро озод мекунад', () {
      // Агар ягон роҳ фаромӯш шавад, ҳад оҳиста пур мешавад ва
      // плиткаҳо боз холӣ мемонанд — камбудии бозгашта.
      for (final path in ['void dispose()', 'catch (e)', 'if (!mounted)']) {
        final i = src.indexOf(path);
        expect(i, greaterThan(-1), reason: '$path ёфт нашуд');
      }
      // Се даъват: dispose, catch, ва !mounted.
      final calls = '_releaseSlot()'.allMatches(src).length;
      expect(calls, greaterThanOrEqualTo(4),
          reason: 'ҷои декодер дар ҳама роҳҳои хуруҷ озод намешавад');
    });

    test('садои плитка ҳамеша хомӯш аст', () {
      // Даҳ плитка = даҳ садои якбора.
      expect(src, contains('setVolume(0)'));
    });
  });
}

extension on String {
  Iterable<Match> allMatches(String input) => RegExp(RegExp.escape(this)).allMatches(input);
}
