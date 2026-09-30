import 'package:flutter/widgets.dart';

class BottomNavController extends ChangeNotifier {
  int _currentIndex = 0;

  /// Ҳар зарбаи дубора ба ҳамон таб +1 мешавад. Шунавандаҳо (Home,
  /// Reels, Explore, Профил, Чат) бояд `currentIndex`-ро санҷанд.
  final scrollToTopNotifier = ValueNotifier<int>(0);

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (index == _currentIndex) {
      scrollToTopNotifier.value++;
      return;
    }
    _currentIndex = index;
    notifyListeners();
  }

  void reset() {
    _currentIndex = 0;
    notifyListeners();
  }
}

/// Зарбаи дубораи таб — мисли Instagram:
///   дар мобайни рӯйхат → ба боло мебарад;
///   аллакай дар боло   → навсозӣ ([refresh]).
/// Барои ҳамин зарбаи якум ҳеҷ гоҳ маълумотро «гум» намекунад.
Future<void> scrollTopOrRefresh(
  Iterable<ScrollController?> controllers,
  Future<void> Function() refresh,
) async {
  final attached = controllers
      .whereType<ScrollController>()
      .where((c) => c.hasClients)
      .toList();
  final notAtTop = attached.any((c) =>
      c.positions.any((p) => p.pixels > p.minScrollExtent + 4));
  if (notAtTop) {
    await Future.wait([
      for (final c in attached)
        for (final p in c.positions)
          p.animateTo(p.minScrollExtent,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic),
    ]);
    return;
  }
  await refresh();
}
