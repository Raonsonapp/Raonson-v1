import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/models/post_model.dart';
import 'package:raonson/models/user_model.dart';
import 'package:raonson/widgets/media_view.dart';

void main() {
  test('ҷонишинҳо аз сервер хонда мешаванд', () {
    final u = UserModel.fromJson({'_id': 'u', 'username': 'x', 'pronouns': 'she/her'});
    expect(u.pronouns, 'she/her');
    expect(u.copyWith(bio: 'нав').pronouns, 'she/her',
        reason: 'copyWith ҷонишинро гум кард');
  });

  test('alt text аз медиаи пост хонда мешавад', () {
    final p = PostModel.fromJson({
      '_id': 'p', 'caption': '', 'createdAt': '2026-09-23T00:00:00Z',
      'user': {'_id': 'u', 'username': 'u'},
      'media': [
        {'url': 'https://x/1.jpg', 'type': 'image', 'alt': 'Ду кас дар боғ'},
        {'url': 'https://x/2.jpg', 'type': 'image', 'alt': ''},
      ],
    });
    expect(p.media[0]['alt'], 'Ду кас дар боғ');
    expect(p.media[1].containsKey('alt'), isFalse);
  });

  testWidgets('хонандаи экран alt-ро мегирад', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox(
        width: 200, height: 200,
        child: MediaView(media: {
          'url': 'https://example.com/a.jpg', 'type': 'image',
          'alt': 'Ду кас дар боғ, шом'})))));
    expect(find.bySemanticsLabel('Ду кас дар боғ, шом'), findsOneWidget);
    handle.dispose();
  });
}
