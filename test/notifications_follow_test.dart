import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/services/follow_service.dart';
import 'package:raonson/core/services/notification_badge_controller.dart';
import 'package:raonson/models/notification_model.dart';
import 'package:raonson/models/user_model.dart';
import 'package:raonson/thanks/thanks_screen.dart';

NotificationModel _n(String type) => NotificationModel.fromJson({
      '_id': 'n1',
      'type': type,
      'read': false,
      'createdAt': '2026-01-01T10:00:00Z',
      'fromUser': {'_id': 'u1', 'username': 'ali', 'isFollowing': false},
      'targetId': 't1',
    });

void main() {
  group('огоҳиномаҳо', () {
    test('навъҳои нав матни худро доранд, на «бо шумо амал кард»', () {
      const generic = 'бо шумо амал кард';
      for (final t in [
        'follow', 'follow_accepted', 'comment_like', 'reel_comment_like',
        'reel_reply', 'contact_joined', 'thanks', 'gift', 'story_addyours',
      ]) {
        expect(_n(t).message, isNot(generic), reason: t);
      }
      expect(_n('contact_joined').message, contains('мухотибони шумо'));
    });

    test('fromUser.isFollowing барои «Пайравии мутақобил» хонда мешавад', () {
      final u = _n('follow').fromUser!;
      expect(u.isFollowing, isFalse);
      expect(u.followKnown, isTrue);
    });

    test('сокет: шумораи сервер бейҷро муқаррар мекунад (на +1)', () {
      final b = NotificationBadgeController.instance;
      b.setCount(7);
      b.onSocketEvent({'type': 'follow', 'unreadCount': 3});
      expect(b.count, 3);
      // Сервери кӯҳна шумора намефиристад — ҳадди ақал +1.
      b.onSocketEvent({'type': 'follow'});
      expect(b.count, 4);
      b.reset();
    });
  });

  group('манбаи обуна', () {
    test('пост ва рилс ба бадани POST /follow/:id', () {
      expect(const FollowSource.post('p1').toJson(),
          {'sourceKind': 'post', 'sourceId': 'p1'});
      expect(const FollowSource.reel('r1').toJson(),
          {'sourceKind': 'reel', 'sourceId': 'r1'});
      expect(const FollowSource.post('').toJson(), isNull);
    });

    test('бе isFollowing аз сервер тугмаи «Пайравӣ» нишон дода намешавад', () {
      final known = UserModel.fromJson({'_id': 'a', 'isFollowing': false});
      final unknown = UserModel.fromJson({'_id': 'a'});
      expect(known.followKnown, isTrue);
      expect(unknown.followKnown, isFalse);
      expect(unknown.copyWith(isFollowing: true).followKnown, isTrue);
    });
  });

  group('«Раҳмат»', () {
    test('саҳифа аз JSON', () {
      final p = ThanksPage.fromJson({
        'count': 1,
        'canThank': true,
        'mine': {'_id': 'x', 'text': 'раҳмат'},
        'thanks': [
          {
            '_id': 'x', 'text': 'раҳмат', 'createdAt': '2026-01-01T10:00:00Z',
            'canRemove': true,
            'fromUser': {'_id': 'u', 'username': 'ali', 'avatar': ''},
          }
        ],
      });
      expect(p.count, 1);
      expect(p.items.single.fromUsername, 'ali');
      expect(p.items.single.canRemove, isTrue);
      expect(p.mineText, 'раҳмат');
      expect(p.canThank, isTrue);
    });

    test('ҷавоби холӣ хато намедиҳад', () {
      final p = ThanksPage.fromJson({});
      expect(p.count, 0);
      expect(p.items, isEmpty);
      expect(p.mineId, isNull);
      expect(p.canThank, isFalse);
    });
  });
}
