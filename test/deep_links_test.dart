// test/deep_links_test.dart
// Таҷзияи линкҳои чуқур. Линки вайрон корбарро ба ҷои нодуруст
// намебарад — ҳар шакли ғайримунтазир «номаълум» мешавад.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/links/deep_links.dart';

void main() {
  group('схемаи худӣ', () {
    test('профил', () {
      final l = DeepLinks.parse('raonson://profile/ali');
      expect(l.kind, DeepLinkKind.profile);
      expect(l.id, 'ali');
      expect(l.isValid, isTrue);
    });

    test('пост ва рилс', () {
      expect(DeepLinks.parse('raonson://post/abc-123').kind, DeepLinkKind.post);
      expect(DeepLinks.parse('raonson://post/abc-123').id, 'abc-123');
      expect(DeepLinks.parse('raonson://reel/xyz').kind, DeepLinkKind.reel);
    });

    test('мавзӯъ ва даъват', () {
      expect(DeepLinks.parse('raonson://topic/gaming').kind, DeepLinkKind.topic);
      expect(DeepLinks.parse('raonson://invite/CODE7').kind,
          DeepLinkKind.referral);
    });
  });

  group('линки веб', () {
    test('роҳи пурраи веб ҳамон натиҷа медиҳад', () {
      final web = DeepLinks.parse(
          'https://raonsonapp.github.io/Raonson-v1/l/profile/ali');
      final app = DeepLinks.parse('raonson://profile/ali');
      expect(web.kind, app.kind);
      expect(web.id, app.id);
    });

    test('роҳи оддӣ бе host', () {
      final l = DeepLinks.parse('/profile/ali');
      expect(l.kind, DeepLinkKind.profile);
      expect(l.id, 'ali');
    });
  });

  group('вуруди вайрон', () {
    test('линки нодуруст ба ҷои нодуруст намебарад', () {
      for (final bad in [
        '',
        '   ',
        'raonson://',
        'raonson://profile',        // бе шиноса
        'https://example.com/',
        'https://raonsonapp.github.io/Raonson-v1/l/',
        'raonson://unknownkind/x',
        'not a url at all',
      ]) {
        final l = DeepLinks.parse(bad);
        expect(l.isValid, isFalse, reason: 'бояд номаълум бошад: $bad');
        expect(DeepLinks.routeFor(l), isNull, reason: bad);
      }
    });

    test('линки каси дигар профили нодуруст намекушояд', () {
      // Роҳи бе навъи маълум набояд ҳамчун профил фаҳмида шавад.
      final l = DeepLinks.parse('https://raonsonapp.github.io/Raonson-v1/ali');
      expect(l.isValid, isFalse);
    });
  });

  group('сохтани линк', () {
    test('линки мубодила ҳамеша ВЕБ аст', () {
      final s = DeepLinks.share(DeepLinkKind.profile, 'ali');
      // Схемаи худӣ дар браузери гиранда кушода намешавад.
      expect(s.startsWith('https://'), isTrue);
      expect(s.contains('/profile/ali'), isTrue);
    });

    test('линки сохташуда бозхонда мешавад', () {
      for (final kind in [
        DeepLinkKind.profile,
        DeepLinkKind.post,
        DeepLinkKind.reel,
        DeepLinkKind.topic,
      ]) {
        final built = DeepLinks.share(kind, 'test-id');
        final back = DeepLinks.parse(built);
        expect(back.kind, kind, reason: built);
        expect(back.id, 'test-id', reason: built);
      }
    });

    test('аломатҳои махсус вайрон намешаванд', () {
      final built = DeepLinks.share(DeepLinkKind.profile, 'ali muhammad');
      final back = DeepLinks.parse(built);
      expect(back.id, 'ali muhammad');
    });

    test('шиносаи холӣ линки вайрон намесозад', () {
      final s = DeepLinks.share(DeepLinkKind.profile, '');
      expect(DeepLinks.parse(s).isValid, isFalse);
    });
  });

  test('ҳеҷ ҷо суроғаи хом мубодила намешавад', () {
    // Пештар линкҳо ба host-и API ё ба файли видео мерафтанд: онҳо
    // барномаро НАМЕКУШОДАНД ва гиранда ба ҷои холӣ мерасид.
    // Танҳо линки МӮҲТАВО санҷида мешавад: '${...}' дар роҳ маънои
    // «ин линк ба пост, рилс ё профили мушаххас мебарад»-ро дорад.
    // Саҳифаҳои статикӣ (шартнома, махфият) ин ҷо дахл надоранд.
    final bad = RegExp(r"'https?://[^']*(hf\.space|raonson\.app)/[^']*\$\{");
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (bad.hasMatch(f.readAsStringSync())) offenders.add(f.path);
    }
    expect(offenders, isEmpty,
        reason: 'линки хом ба ҷои DeepLinks.share: $offenders');
  });

  group('линки мубодила барои мессенҷер', () {
    // Шикояти воқеӣ: «видеоро ба чат мепартоям — линк меравад, на
    // видео». Сабаб ин буд, ки линк ба саҳифаи статикӣ мерафт, ки
    // ҳеҷ теги OpenGraph надошт. Акнун пост ва рилс ба саҳифаи
    // ПЕШНАМОИШИ сервер мераванд, ки видеоро нишон медиҳад.
    test('пост ва рилс ба саҳифаи пешнамоиш мераванд', () {
      final post = DeepLinks.share(DeepLinkKind.post, 'p1');
      final reel = DeepLinks.share(DeepLinkKind.reel, 'r1');
      expect(post, startsWith(DeepLinks.previewBase));
      expect(reel, startsWith(DeepLinks.previewBase));
      expect(post, endsWith('/p/p1'));
      expect(reel, endsWith('/r/r1'));
    });

    test('линки пешнамоиш дубора фаҳмида мешавад', () {
      for (final kind in [DeepLinkKind.post, DeepLinkKind.reel]) {
        final built = DeepLinks.share(kind, 'abc-123');
        final back = DeepLinks.parse(built);
        expect(back.kind, kind, reason: built);
        expect(back.id, 'abc-123', reason: built);
        expect(DeepLinks.routeFor(back), isNotNull, reason: built);
      }
    });

    test('профил ва мавзӯъ ҳамон домени вебро нигоҳ медоранд', () {
      // Барои онҳо саҳифаи пешнамоиш нест — линки веб мемонад.
      expect(DeepLinks.share(DeepLinkKind.profile, 'ali'),
          startsWith(DeepLinks.webBase));
      expect(DeepLinks.share(DeepLinkKind.topic, 'gaming'),
          startsWith(DeepLinks.webBase));
    });

    test('шиносаи холӣ линки вайрон намесозад', () {
      for (final kind in [DeepLinkKind.post, DeepLinkKind.reel]) {
        expect(DeepLinks.parse(DeepLinks.share(kind, '')).isValid, isFalse);
      }
    });
  });

  group('шартномаи сервер ↔ барнома', () {
    // Сервер линкро дар payload-и огоҳинома мефиристад
    // (backend/notify/text.go, функсияи Link). Агар барнома ин
    // шаклҳоро нафаҳмад, пахши огоҳинома ба ҳеҷ ҷо намебарад — ва
    // ин хатогӣ хомӯш аст.
    const serverLinks = {
      '/post/abc-123': DeepLinkKind.post,
      '/reel/xyz-789': DeepLinkKind.reel,
      '/profile/ali': DeepLinkKind.profile,
      '/topic/gaming': DeepLinkKind.topic,
    };

    test('ҳар линки сервер фаҳмида мешавад', () {
      serverLinks.forEach((link, kind) {
        final parsed = DeepLinks.parse(link);
        expect(parsed.isValid, isTrue, reason: link);
        expect(parsed.kind, kind, reason: link);
        expect(parsed.id, isNotEmpty, reason: link);
      });
    });

    test('ҳар линки сервер роҳи мушаххас дорад', () {
      for (final link in serverLinks.keys) {
        final parsed = DeepLinks.parse(link);
        expect(DeepLinks.routeFor(parsed), isNotNull, reason: link);
      }
    });
  });

  test('роҳҳо ба routing-и МАВҶУДА ишора мекунанд', () {
    // Ҳеҷ роҳи нав ихтироъ намешавад.
    expect(DeepLinks.routeFor(const DeepLink(DeepLinkKind.profile, 'ali')),
        '/profile-by-username');
  });
}
