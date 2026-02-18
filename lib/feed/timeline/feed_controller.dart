import 'package:flutter/foundation.dart';
import '../../models/post_model.dart';
import '../feed_repository.dart';
import 'feed_state.dart';

class FeedController extends ChangeNotifier {
  final FeedRepository _repository;

  FeedState _state = FeedState.initial();
  FeedState get state => _state;

  int _offset = 0;
  static const int _limit = 10;

  FeedController(this._repository);

  Future<void> loadInitialFeed() async {
    _offset = 0;
    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      final posts = await _repository.fetchFeed(
        limit: _limit,
        offset: _offset,
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

  Future<void> loadMore() async {
    if (!_state.hasMore || _state.isLoading) return;

    _state = _state.copyWith(isLoading: true);
    notifyListeners();

    try {
      _offset += _limit;
      final posts = await _repository.fetchFeed(
        limit: _limit,
        offset: _offset,
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

  Future<void> refresh() async {
    _offset = 0;
    final posts = await _repository.fetchFeed(
      limit: _limit,
      offset: _offset,
    );

    _state = _state.copyWith(
      posts: posts,
      hasMore: posts.length == _limit,
    );
    notifyListeners();
  }
}
