import 'package:flutter/foundation.dart';

import 'search_state.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';

class SearchController extends ChangeNotifier {
  SearchState _state = SearchState.initial();
  SearchState get state => _state;

  void updateQuery(String value) {
    _state = _state.copyWith(query: value);
    notifyListeners();

    if (value.isEmpty) {
      clearResults();
    } else {
      _mockSearch(value);
    }
  }

  Future<void> _mockSearch(String query) async {
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    final users = List.generate(
      5,
      (i) => UserModel(
        id: 'u$i',
        username: '${query}_user$i',
        avatar: '',
        verified: i.isEven,
        isPrivate: false,
        postsCount: 0,
        followersCount: 0,
        followingCount: 0,
      ),
    );

    final posts = List.generate(
      5,
      (i) => PostModel(
        id: 'p$i',
        user: users.first,
        caption: '$query post $i',
        media: const [{'url': '', 'type': 'image'}],
        likesCount: 0,
        commentsCount: 0,
        liked: false,
        saved: false,
        createdAt: DateTime.now(),
      ),
    );

    _state = _state.copyWith(
      isLoading: false,
      users: users,
      posts: posts,
    );
    notifyListeners();
  }

  void clearResults() {
    _state = SearchState.initial();
    notifyListeners();
  }
}
