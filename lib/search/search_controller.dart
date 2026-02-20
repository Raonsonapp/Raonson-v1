import 'package:flutter/foundation.dart';
import 'search_state.dart';

// This file kept for backward compat - actual logic moved to search_screen.dart
class RaonsonSearchController extends ChangeNotifier {
  SearchState _state = SearchState.initial();
  SearchState get state => _state;

  void updateQuery(String value) {
    _state = _state.copyWith(query: value);
    notifyListeners();
  }

  void clearResults() {
    _state = _state.copyWith(users: [], posts: [], isLoading: false);
    notifyListeners();
  }
}
