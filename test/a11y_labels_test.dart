import 'dart:ui' show SemanticsAction;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raonson/core/i18n/strings.dart';
import 'package:raonson/navigation/bottom_nav/bottom_nav_bar.dart';
import 'package:raonson/reels/widgets/reel_action_column.dart';

// Хонандаи экран (TalkBack/VoiceOver). Пеш табҳои поён ва тугмаҳои
// рилс ном надоштанд — корбари нобино танҳо «тугма» мешунид.
void main() {
  testWidgets('табҳои поён ном доранд ва пахш тавассути semantics кор мекунад',
      (t) async {
    final handle = t.ensureSemantics();
    var tapped = -1;
    await t.pumpWidget(MaterialApp(home: Scaffold(
        bottomNavigationBar: BottomNavBar(
            currentIndex: 0, chatUnread: 3, onTap: (i) => tapped = i))));
    for (final k in ['nav.home', 'nav.reels', 'nav.search', 'nav.profile']) {
      expect(find.bySemanticsLabel(tr(k)), findsOneWidget, reason: k);
    }
    // Шумораи паёмҳои хонданашуда ҳам хонда мешавад.
    expect(find.bySemanticsLabel('${tr('nav.messages')}, 3'), findsOneWidget);
    expect(t.getSemantics(find.bySemanticsLabel(tr('nav.home'))),
        matchesSemantics(label: tr('nav.home'), isButton: true,
            isSelected: true, hasTapAction: true));

    final node = t.getSemantics(find.bySemanticsLabel(tr('nav.search')));
    t.binding.pipelineOwner.semanticsOwner!
        .performAction(node.id, SemanticsAction.tap);
    expect(tapped, 3);
    handle.dispose();
  });

  testWidgets('сутуни амалҳои рилс: лайк/шарҳ/паҳн/захира ном доранд',
      (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(MaterialApp(home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: ReelActionColumn(
            liked: false, likesLabel: '12', onLike: () {},
            onComment: () {}, onShare: () {}, saved: true, onSave: () {},
            onMore: () {})))));
    for (final k in ['a11y.like', 'a11y.comments', 'common.share', 'a11y.unsave']) {
      expect(find.bySemanticsLabel(RegExp('^${RegExp.escape(tr(k))}')),
          findsOneWidget, reason: k);
    }
    handle.dispose();
  });
}
