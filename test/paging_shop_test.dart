import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raonson/core/services/follow_service.dart';
import 'package:raonson/models/post_model.dart';
import 'package:raonson/models/user_model.dart';
import 'package:raonson/profile/profile_controller.dart';
import 'package:raonson/shop/buy_sheet.dart';

// Камбудиҳое, ки корбари талабгор медид:
//
//  • Профил, Reels-и профил, захирашудаҳо, обуначиён, шарҳҳо,
//    огоҳиномаҳо ва ҳаштаг танҳо САҲИФАИ АВВАЛРО нишон медоданд
//    (20–50 унсур). Пости 25-ум ва кӯҳнатар ҳеҷ гоҳ дида намешуд.
//  • «Харид» дар лента/профил/Explore тахфифи фаъолро намедонист:
//    нархи пурра нишон дода мешуд, вале фармоиш бо нархи арзон сабт
//    мешуд.
//  • Хатоҳо ҳамчун муваффақият: паёми чат «нест шуд», шикоят
//    «фиристода шуд», баҳо «пок шуд» — ҳол он ки сервер рад карда буд.

String _read(String p) => File(p).readAsStringSync();

PostModel _product({int salePct = 0}) => PostModel(
      id: 'p1',
      user: const UserModel(
          id: 'seller', username: 'seller', avatar: '', verified: false,
          isPrivate: false, postsCount: 0, followersCount: 0,
          followingCount: 0),
      caption: '',
      media: const [],
      likesCount: 0,
      commentsCount: 0,
      liked: false,
      saved: false,
      createdAt: DateTime(2026),
      isProduct: true,
      price: 100,
      currency: 'TJS',
      productName: 'Курта',
      salePct: salePct,
    );

void main() {
  group('тахфифи маҳсул дар PostModel', () {
    test('salePct аз сервер хонда мешавад ва нархро кам мекунад', () {
      final p = PostModel.fromJson({
        '_id': 'x', 'isProduct': true, 'price': 100, 'currency': 'TJS',
        'salePct': 20,
      });
      expect(p.salePct, 20);
      expect(p.onSale, isTrue);
      expect(p.salePrice, 80);
      expect(p.salePriceLabel, '80 TJS');
    });

    test('бе salePct (сервери кӯҳна) — нарх тағйир намеёбад', () {
      final p = PostModel.fromJson(
          {'_id': 'x', 'isProduct': true, 'price': 100});
      expect(p.onSale, isFalse);
      expect(p.salePrice, 100);
    });

    test('рақами нодуруст маҳдуд мешавад (0–90)', () {
      expect(PostModel.fromJson({'_id': 'x', 'salePct': 500}).salePct, 90);
      expect(PostModel.fromJson({'_id': 'x', 'salePct': -3}).salePct, 0);
    });

    test('кэши диск тахфифро гум намекунад', () {
      final p = _product(salePct: 15);
      expect(PostModel.fromJson(p.toJson()).salePct, 15);
      expect(p.copyWith(caption: 'нав').salePct, 15);
    });
  });

  group('варақаи «Харид»', () {
    Future<void> open(WidgetTester t, PostModel post) async {
      await t.pumpWidget(MaterialApp(home: Builder(
          builder: (c) => Scaffold(body: Center(child: TextButton(
              onPressed: () => showBuySheet(c, post),
              child: const Text('buy')))))));
      await t.tap(find.text('buy'));
      await t.pumpAndSettle();
    }

    testWidgets('нархи тахфифӣ ва нархи кӯҳна (хатзада)', (t) async {
      await open(t, _product(salePct: 20));
      expect(find.text('80 TJS'), findsOneWidget);
      final old = t.widget<Text>(find.text('100 TJS'));
      expect(old.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('бе тахфиф — танҳо нархи пурра', (t) async {
      await open(t, _product());
      expect(find.text('100 TJS'), findsOneWidget);
      expect(find.text('80 TJS'), findsNothing);
    });
  });

  group('саҳифабандии профил', () {
    test('рақами саҳифаи навбатӣ аз шумораи боршуда', () {
      expect(ProfileController.nextPage(24, 24), 2);
      expect(ProfileController.nextPage(48, 24), 3);
      // Пост дар миён нест шуд — саҳифаи қаблӣ такрор мешавад, на гум.
      expect(ProfileController.nextPage(47, 24), 2);
    });

    test('илова бе такрор', () {
      final list = ['a', 'b', 'c'];
      final added =
          ProfileController.appendUnique<String>(list, ['c', 'd', 'e'], (s) => s);
      expect(added, 2);
      expect(list, ['a', 'b', 'c', 'd', 'e']);
      expect(ProfileController.appendUnique<String>(list, ['a'], (s) => s), 0);
    });

    test('ҷадвалҳо ба поён расида саҳифаи навро мехонанд', () {
      final src = _read('lib/profile/profile_screen.dart');
      expect(src, contains('_onNearEnd(_ctrl.loadMorePosts'));
      expect(src, contains('_onNearEnd(_ctrl.loadMoreReels'));
      expect(src, contains('_onNearEnd(_ctrl.loadMoreSaved'));
      // Обуначиён: саҳифаҳо ва хатои шабака (на скелети абадӣ).
      expect(src, contains('_loadMore()'));
      expect(src, contains('_failed'));
    });
  });

  group('рӯйхатҳои дигар саҳифа ба саҳифа', () {
    test('шарҳҳо page/limit мефиристанд', () {
      final src = _read('lib/feed/comments/comments_screen.dart');
      expect(src, contains("'page': '\$page'"));
      expect(src, contains('_loadMore'));
    });

    test('огоҳиномаҳо: саҳифаҳо ва «Ин ҳафта»', () {
      final src = _read('lib/notifications/notifications_screen.dart');
      expect(src, contains('_loadMore'));
      expect(src, contains("tr('common.thisWeek')"));
      // Ду сарлавҳаи «Қаблтар» паси ҳам набошад.
      expect("tr('common.earlier')".allMatches(src).length, 1);
      final repo = _read('lib/notifications/notifications_repository.dart');
      expect(repo, contains('statusCode >= 400'));
    });

    test('ҳаштаг саҳифаи навбатиро мехонад', () {
      final src = _read('lib/feed/hashtag/hashtag_screen.dart');
      expect(src, contains('_loadMore'));
      expect(src, contains("'page': '\$page'"));
    });

    test('бинандагони сторӣ — то 200, на 50', () {
      expect(_read('lib/stories/story_viewers_cache.dart'),
          contains("'limit': '200'"));
    });
  });

  group('дархости обуна ба ҳисоби пӯшида', () {
    test('ҷавоби {"requested": true} обуна нест', () {
      expect(isFollowRequested('{"requested": true}'), isTrue);
      expect(isFollowRequested('{"following": true}'), isFalse);
      expect(isFollowRequested('not json'), isFalse);
    });

    test('ҳолати «Дархост» ба ҳамаи тугмаҳо хабар медиҳад', () {
      final fs = FollowService.instance;
      fs.clear();
      var calls = 0;
      void l() => calls++;
      fs.states.addListener(l);
      fs.primeRequested('u1', true);
      expect(fs.isRequested('u1'), isTrue);
      expect(fs.resolve('u1', false), isFalse, reason: 'дархост ≠ обуна');
      fs.primeRequested('u1', true); // бе тағйир — бе хабар
      fs.primeRequested('u1', false);
      expect(fs.isRequested('u1'), isFalse);
      expect(calls, 2);
      fs.states.removeListener(l);
      fs.clear();
    });

    test('тугмаҳо «Дархост» нишон медиҳанд ва бекор кардан мумкин аст', () {
      for (final f in [
        'lib/search/search_screen.dart',
        'lib/profile/profile_screen.dart',
        'lib/feed/timeline/feed_screen.dart',
      ]) {
        expect(_read(f), contains("tr('common.requested')"), reason: f);
      }
      final prof = _read('lib/profile/profile_screen.dart');
      expect(prof, isNot(contains('onTap: followRequestSent ? null : onFollow')));
    });
  });

  group('хато ҳамчун муваффақият нишон дода намешавад', () {
    test('нест кардан/вокуниши паём хаторо намефурӯбад', () {
      final src = _read('lib/chat/chat_repository.dart');
      expect(src, contains("deleteOk('/chat/messages/\$messageId')"));
      expect(src, contains("postOk(\n        '/chat/messages/\$messageId/react'"));
    });

    test('баҳои маҳсул: матн танҳо баъди сабт пок мешавад', () {
      final src = _read('lib/shop/product_reviews_screen.dart');
      final check = src.indexOf('r.statusCode >= 400');
      final clear = src.indexOf('_text.clear()');
      expect(check, greaterThan(0));
      expect(clear, greaterThan(check));
    });

    test('соҳиби пост шарҳи дигаронро нест карда метавонад', () {
      final src = _read('lib/feed/comments/comments_screen.dart');
      expect(src, contains('canModerate: _iOwnPost'));
      expect(src, contains('if (widget.canModerate)'));
    });

    test('Live: оғози ноком спиннери абадӣ намемонад', () {
      final src = _read('lib/live/live_screens.dart');
      expect(src, contains("_abortStart(joined: true);\n      _id = '';"));
    });

    test('«Ҷолиб нест» дар сервер ҳам бекор мешавад', () {
      expect(_read('lib/feed/post/post_card.dart'),
          contains(".delete('/posts/\${widget.post.id}/not-interested')"));
    });
  });
}
