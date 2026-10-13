import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raonson/widgets/min_height_scroll.dart';

Widget _page(double h) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 320,
            height: h,
            child: MinHeightScroll(
              child: Column(children: [
                const SizedBox(height: 120, child: Text('сарлавҳа')),
                Expanded(child: ListView(children: const [Text('чат')])),
              ]),
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('ҷои қариб 0 (клавиатура) — бе навори зард', (t) async {
    await t.pumpWidget(_page(6));
    expect(t.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('ҷои кофӣ — бе варақ, Expanded кор мекунад', (t) async {
    await t.pumpWidget(_page(600));
    expect(t.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.text('чат'), findsOneWidget);
  });
}
