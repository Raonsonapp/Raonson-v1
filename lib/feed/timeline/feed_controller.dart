import 'package:flutter/foundation.dart';
import '../../models/post_model.dart';
import '../feed_repository.dart';
import 'feed_state.dart';

class FeedController extends ChangeNotifier {
  final FeedRepository _repository;

  VoidCallback? onUnauthorized;

  FeedState _state = FeedState.initial();
  FeedState get state => _state;

  int _page = 1;
  static const int _limit = 10;

  FeedController(this._repository);

  Future<void> loadInitialFeed() async {
    _page = 1;
    _state = _state.copyWith(isLoading: true, hasError: false);
    notifyListeners();

    try {
      final posts = await _repository.fetchFeed(limit: _limit, page: _page);
      _state = _state.copyWith(
        isLoading: false,
        posts: posts,
        hasMore: posts.length == _limit,
      );
    } on UnauthorizedException {
      _state = _state.copyWith(isLoading: false, hasMore: false);
      notifyListeners();
      onUnauthorized?.call();
      return;
    } catch (e) {
      _state = _state.copyWith(
        isLoading: false,
        hasError: true,
        hasMore: false,
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
      _page++;
      final posts = await _repository.fetchFeed(limit: _limit, page: _page);
      _state = _state.copyWith(
        isLoading: false,
        posts: List<PostModel>.from(_state.posts)..addAll(posts),
        hasMore: posts.length == _limit,
      );
    } catch (_) {
      _page--;
      _state = _state.copyWith(isLoading: false, hasMore: false);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    _page = 1;
    _state = _state.copyWith(isRefreshing: true, hasError: false);
    notifyListeners();
    try {
      final posts = await _repository.fetchFeed(limit: _limit, page: _page);
      _state = _state.copyWith(
        isRefreshing: false,
        posts: posts,
        hasMore: posts.length == _limit,
      );
    } catch (e) {
      _state = _state.copyWith(
        isRefreshing: false,
        hasError: true,
        hasMore: false,
      );
    }
    notifyListeners();
  }
}

class UnauthorizedException implements Exception {}
