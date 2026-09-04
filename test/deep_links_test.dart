// test/deep_links_test.dart
// Таҷзияи линкҳои чуқур. Линки вайрон корбарро ба ҷои нодуруст
// намебарад — ҳар шакли ғайримунтазир «номаълум» мешавад.
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

  test('роҳҳо ба routing-и МАВҶУДА ишора мекунанд', () {
    // Ҳеҷ роҳи нав ихтироъ намешавад.
    expect(DeepLinks.routeFor(const DeepLink(DeepLinkKind.profile, 'ali')),
        '/profile-by-username');
  });
}
