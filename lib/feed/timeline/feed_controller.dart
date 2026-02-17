import 'package:flutter/foundation.dart';

import 'feed_state.dart';
import '../feed_repository.dart';
import '../../models/post_model.dart';

class FeedController extends ChangeNotifier {
  final FeedRepository _repository;

  FeedState _state = FeedState.initial();
  FeedState get state => _state;

  int _page = 1;
  static const int _limit = 10;

  FeedController(this._repository);

  // ================= LOAD FEED =================

  Future<void> loadInitialFeed() async {
    if (_state.isLoading) return;

    _page = 1;
    _state = _state.copyWith(
      isLoading: true,
      hasError: false,
      errorMessage: null,
    );
    notifyListeners();

    try {
      final posts = await _repository.fetchFeed(
        page: _page,
        limit: _limit,
      );

      _state = _state.copyWith(
        isLoading: false,
        posts: posts,
        hasMore: posts.length == _limit,
      );
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        hasError: true,
        errorMessage: e.toString(),
      );
    }

    notifyListeners();
  }

  // ================= PAGINATION =================

  Future<void> loadMore() async {
    if (!_state.hasMore || _state.isLoading) return;

    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      _page++;
      final posts = await _repository.fetchFeed(
        page: _page,
        limit: _limit,
      );

      _state = _state.copyWith(
        isLoading: false,
        posts: List<PostModel>.from(_state.posts)..addAll(posts),
        hasMore: posts.length == _limit,
      );
    } catch (_) {
      _state = _state.copyWith(isLoading: false);
    }

    notifyListeners();
  }

  // ================= REFRESH =================

  Future<void> refresh() async {
    if (_state.isRefreshing) return;

    _state = _state.copyWith(isRefreshing: true);
    notifyListeners();

    try {
      _page = 1;
      final posts = await _repository.fetchFeed(
        page: _page,
        limit: _limit,
      );

      _state = _state.copyWith(
        isRefreshing: false,
        posts: posts,
        hasMore: posts.length == _limit,
      );
    } catch (_) {
      _state = _state.copyWith(isRefreshing: false);
    }

    notifyListeners();
  }
}
