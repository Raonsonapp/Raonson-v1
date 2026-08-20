import 'package:flutter/foundation.dart';

class BottomNavController extends ChangeNotifier {
  int _currentIndex = 0;
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
