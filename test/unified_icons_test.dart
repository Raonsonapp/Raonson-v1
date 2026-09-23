import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/ui/r_icon.dart';

// Корбар: «икони лайкро аз Home гир, икони шарҳро аз шарҳ — дар
// ҳамаи барнома як бошад, на гуногун».
//
// Ин санҷиш нигоҳ медорад, ки нишонаҳои дигари «дил» ва «шарҳ»
// (аз шрифт) ба ҷойҳое, ки маънояш ЛАЙК ё ШАРҲ аст, барнагарданд.
void main() {
  test('дар ҷойҳои лайк/шарҳ нишонаҳои шрифт нестанд', () {
    const files = [
      'lib/stories/story_group_viewer.dart',
      'lib/feed/comments/comments_screen.dart',
      'lib/live/live_overlay.dart',
      'lib/reels/reels_feed/reels_screen.dart',
      'lib/feed/post/post_card.dart',
    ];
    final banned = RegExp(r'Icon\(\s*(?:widget\.liked \? |_liked \? )?'
        r'AppIcons\.(favorite|favorite_border|chat_bubble_outline)\b');
    for (final f in files) {
      final s = File(f).readAsStringSync();
      expect(banned.hasMatch(s), isFalse,
          reason: '$f боз нишонаи дигари дил/шарҳ дорад');
    }
  });

  testWidgets('RIcon ҳамон SVG-ҳои лентаро мекашад', (t) async {
    await t.pumpWidget(MaterialApp(home: Row(children: [
      RIcon.like(), RIcon.like(filled: true), RIcon.comment(),
    ])));
    expect(find.byType(RIcon), findsNWidgets(3));
  });
}
