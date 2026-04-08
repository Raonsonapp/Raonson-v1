import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/post_model.dart';
import '../../core/services/socket_service.dart';
import '../feed_repository.dart';
import '../feed_exceptions.dart';
import 'feed_state.dart';

class FeedController extends ChangeNotifier {
  final FeedRepository _repository;

  VoidCallback? onUnauthorized;

  FeedState _state = FeedState.initial();
  FeedState get state => _state;

  int _page = 1;
  static const int _limit = 10;

  // ── Live ─────────────────────────────────────────────────────────
  /// Новые посты, пришедшие по WebSocket — ещё не показаны в ленте
  final List<PostModel> _pending = [];
  int get pendingCount => _pending.length;

  FeedController(this._repository) {
    _subscribeSocket();
  }

  // ── WebSocket ────────────────────────────────────────────────────
  void _subscribeSocket() {
    SocketService.instance.on('feed:new_post', _onNewPost);
  }

  void _onNewPost(dynamic data) {
    if (data is! Map<String, dynamic>) return;
    try {
      final post = PostModel.fromJson(data);
      // Агар ин пост аллакай дар лента бошад, тағир надеҳ
      final alreadyExists = _state.posts.any((p) => p.id == post.id);
      if (alreadyExists) return;

      _pending.insert(0, post);
      notifyListeners(); // UI "N та пости нав" нишон медиҳад
    } catch (e) {
      debugPrint('[Feed] WebSocket post parse error: $e');
    }
  }

  /// Постҳои pending-ро ба боли лента мегузорад (вақте истифодабаранда тугмаро мезанад)
  void flushPending() {
    if (_pending.isEmpty) return;
    final merged = [..._pending, ..._state.posts];
    _pending.clear();
    _state = _state.copyWith(posts: merged);
    notifyListeners();
  }

  // ── Initial load ─────────────────────────────────────────────────
  Future<void> loadInitialFeed() async {
    _page = 1;
    _pending.clear();
    _state = _state.copyWith(isLoading: true, hasError: false);
    notifyListeners();

    String lastError = '';

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final posts = await _repository.fetchFeed(
          limit: _limit,
          page: _page,
        );
        _state = _state.copyWith(
          isLoading: false,
          posts: posts,
          hasMore: posts.length == _limit,
        );
        notifyListeners();
        return;
      } on UnauthorizedException {
        _state = _state.copyWith(
          isLoading: false,
          hasMore: false,
          hasError: true,
          errorMessage: 'Лутфан дубора ворид шавед (401)',
        );
        notifyListeners();
        onUnauthorized?.call();
        return;
      } catch (e) {
        lastError = e.toString();
        if (attempt < 3) {
          await Future.delayed(const Duration(seconds: 5));
        }
      }
    }

    _state = _state.copyWith(
      isLoading: false,
      hasError: true,
      hasMore: false,
      errorMessage: lastError,
    );
    notifyListeners();
  }

  // ── Load more (pagination) ───────────────────────────────────────
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

  // ── Pull-to-refresh ──────────────────────────────────────────────
  Future<void> refresh() async {
    _page = 1;
    _pending.clear();
    _state = _state.copyWith(isRefreshing: true, hasError: false);
    notifyListeners();
    try {
      final posts = await _repository.fetchFeed(
          limit: _limit, page: _page, forceRefresh: true);
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
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    SocketService.instance.off('feed:new_post');
    super.dispose();
  }
}

// UnauthorizedException дар lib/feed/feed_exceptions.dart аст
