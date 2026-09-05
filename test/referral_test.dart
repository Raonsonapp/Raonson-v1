// test/referral_test.dart
// Даъват. Хатари асосӣ — рақами бардурӯғ: экран набояд ҳеҷ гоҳ
// рақамеро нишон диҳад, ки сервер надодааст.
import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/links/deep_links.dart';
import 'package:raonson/referral/referral_screen.dart';

void main() {
  group('ҳисоби даъват', () {
    test('ҷавоби сервер ҳамон тавр хонда мешавад', () {
      final s = ReferralSummary.fromJson(const {
        'code': 'UNAX7YRG',
        'joined': 3,
        'invitedBy': 'ABCD2345',
        'recent': [
          {
            'userId': 'u1',
            'username': 'ali',
            'avatar': '',
            'joinedAt': '2026-09-05T07:23:44Z',
          },
        ],
      });
      expect(s.code, 'UNAX7YRG');
      expect(s.joined, 3);
      expect(s.invitedBy, 'ABCD2345');
      expect(s.recent.single.username, 'ali');
    });

    test('ҷавоби холӣ сифр медиҳад, на рақами тахминӣ', () {
      final s = ReferralSummary.fromJson(const {});
      expect(s.joined, 0);
      expect(s.code, isEmpty);
      expect(s.recent, isEmpty);
      expect(s.invitedBy, isEmpty);
    });

    test('маълумоти вайрон ба крах намеорад', () {
      final s = ReferralSummary.fromJson(const {
        'joined': 'се',
        'recent': 'ali',
      });
      expect(s.joined, 0);
      expect(s.recent, isEmpty);
    });

    test('рӯйхат танҳо сатрҳои дурустро мегирад', () {
      final s = ReferralSummary.fromJson(const {
        'recent': [
          {'userId': 'u1', 'username': 'ali'},
          'сатри бегона',
          42,
        ],
      });
      expect(s.recent.length, 1);
      expect(s.recent.single.username, 'ali');
      expect(s.recent.single.avatar, isEmpty);
    });
  });

  group('линки даъват', () {
    test('линк аз код сохта ва бозхонда мешавад', () {
      final link = DeepLinks.share(DeepLinkKind.referral, 'UNAX7YRG');
      expect(link.startsWith('https://'), isTrue);
      final back = DeepLinks.parse(link);
      expect(back.kind, DeepLinkKind.referral);
      expect(back.id, 'UNAX7YRG');
    });

    test('коди холӣ линки вайрон намесозад', () {
      final link = DeepLinks.share(DeepLinkKind.referral, '');
      expect(DeepLinks.parse(link).isValid, isFalse);
    });
  });
}
