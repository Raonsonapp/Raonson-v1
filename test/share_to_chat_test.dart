import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Корбар: «публикатсия ё рилсро ба чат фиристонӣ — экран сиёҳ
// мешавад».
//
// Сабаб: «Мубодила → Ба чат фиристодан» экрани чатҳоро ҳамчун саҳифаи
// АЛОҲИДА мекушод. Он `BottomNavController`-ро меҷуст, ки танҳо дар
// навбари поёнӣ ҳаст — ва хато мепартофт. Дар release ин экрани сиёҳ
// аст. Бо кушодани воқеии экран дар тест тасдиқ шуд:
//
//   Could not find the correct Provider<BottomNavController>
//   above this ChatListScreen Widget
//
// Ҳамон санҷиш барои ҳамаи 67 экрани бе-параметр гузаронда шуд
// (tool/probe_screens.py) — ягон экрани дигар ин хаторо надошт.
void main() {
  test('экрани чат бе навбари поёнӣ ҳам кушода мешавад', () {
    final s = File('lib/chat/inbox/chat_list_screen.dart').readAsStringSync();
    expect(s.contains('context.read<BottomNavController>()'), isFalse,
        reason: 'боз `read` бе `?` — аз «Мубодила» экрани сиёҳ мешавад');
    expect(s, contains('context.read<BottomNavController?>()'));
  });
}
