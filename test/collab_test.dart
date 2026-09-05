// test/collab_test.dart
// Даъвати ҳамкорӣ. Экран набояд даъватеро нишон диҳад, ки сервер
// надодааст, ва набояд аз маълумоти вайрон афтад.
import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/collab/collab_invites_screen.dart';

void main() {
  test('даъват аз ҷавоби сервер хонда мешавад', () {
    final i = CollabInvite.fromJson(const {
      'postId': 'p1',
      'ownerId': 'u1',
      'username': 'creator1',
      'avatar': '',
      'caption': 'Ҳамкорӣ',
    });
    expect(i.postId, 'p1');
    expect(i.ownerId, 'u1');
    expect(i.username, 'creator1');
    expect(i.caption, 'Ҳамкорӣ');
  });

  test('майдони нест сатри холӣ мешавад, на null', () {
    final i = CollabInvite.fromJson(const {});
    expect(i.postId, isEmpty);
    expect(i.username, isEmpty);
    expect(i.avatar, isEmpty);
  });

  test('навъи ғайримунтазир ба крах намеорад', () {
    final i = CollabInvite.fromJson(const {'postId': 42, 'caption': ['a']});
    expect(i.postId, '42');
    expect(i.caption, isNotEmpty);
  });
}
