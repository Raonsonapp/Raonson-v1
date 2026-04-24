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

  // Pending — постҳои нав аз WebSocket
  final List<PostModel> _pending = [];
  int get pendingCount => _pending.length;

  // Polling backup — агар WebSocket кор накунад
  Timer? _pollTimer;
  DateTime? _lastFetchTime;

  FeedController(this._repository) {
    _subscribeSocket();
    _startPolling();
  }

  // ── WebSocket ────────────────────────────────────────────────────
  void _subscribeSocket() {
    SocketService.instance.on('feed:new_post', _onNewPost);
    SocketService.instance.autoConnect();
  }

  void _onNewPost(dynamic data) {
    if (data is! Map<String, dynamic>) return;
    try {
      final post = PostModel.fromJson(data);
      if (_state.posts.any((p) => p.id == post.id)) return;
      if (_pending.any((p) => p.id == post.id)) return;
      _pending.insert(0, post);
      notifyListeners();
    } catch (e) {
      debugPrint('[Feed] WS post parse error: $e');
    }
  }

  // ── Polling backup — ҳар 30 сония ──────────────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!SocketService.instance.isConnected) {
        // WebSocket offline — polling орқали тафтиш
        await _silentCheck();
      }
    });
  }

  Future<void> _silentCheck() async {
    try {
      final posts = await _repository.fetchFeed(
        limit: 5, page: 1, forceRefresh: true);
      if (posts.isEmpty) return;
      final newPosts = posts.where((p) =>
        !_state.posts.any((e) => e.id == p.id) &&
        !_pending.any((e) => e.id == p.id)).toList();
      if (newPosts.isEmpty) return;
      for (final p in newPosts.reversed) {
        _pending.insert(0, p);
      }
      notifyListeners();
    } catch (_) {}
  }

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

    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final posts = await _repository.fetchFeed(
          limit: _limit, page: _page);
        _lastFetchTime = DateTime.now();
        _state = _state.copyWith(
          isLoading: false,
          posts: posts,
          hasMore: posts.length == _limit,
        );
        notifyListeners();
        return;
      } on UnauthorizedException {
        _state = _state.copyWith(
          isLoading: false, hasMore: false, hasError: true,
          errorMessage: 'Лутфан дубора ворид шавед (401)');
        notifyListeners();
        onUnauthorized?.call();
        return;
      } catch (e) {
        if (attempt < 3) await Future.delayed(const Duration(seconds: 3));
        if (attempt == 3) {
          _state = _state.copyWith(
            isLoading: false, hasError: true,
            hasMore: false, errorMessage: e.toString());
          notifyListeners();
        }
      }
    }
  }

  // ── Load more ────────────────────────────────────────────────────
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
      _lastFetchTime = DateTime.now();
      _state = _state.copyWith(
        isRefreshing: false, posts: posts,
        hasMore: posts.length == _limit);
    } catch (e) {
      _state = _state.copyWith(
        isRefreshing: false, hasError: true,
        hasMore: false, errorMessage: e.toString());
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    SocketService.instance.off('feed:new_post');
    super.dispose();
  }
}
