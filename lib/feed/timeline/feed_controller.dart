import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/post_model.dart';
import '../../core/services/socket_service.dart';
import '../feed_repository.dart';
import '../feed_exceptions.dart';
import 'feed_state.dart';
import '../../create/upload/post_upload_service.dart';

class FeedController extends ChangeNotifier {
  final FeedRepository _repository;

  VoidCallback? onUnauthorized;

  FeedState _state = FeedState.initial();
  FeedState get state => _state;

  int _page = 1;
  static const int _limit = 10;

  bool _isOffline = false;
  bool get isOffline => _isOffline;

  final List<PostModel> _pending = [];
  int get pendingCount => _pending.length;

  Timer? _pollTimer;

  FeedController(this._repository) {
    _subscribeSocket();
    _startPolling();
    // Баъди загрузкаи фонии пост — феедро нав мекунад.
    PostUploadService.instance.onPublished = () => onPostUploaded();
  }

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
      // ✅ Фавран ба feed илова кун — мисли Instagram
      _pending.insert(0, post);
      notifyListeners();
    } catch (_) {}
  }

  // ✅ REALTIME: пост фавран аз feed ҳазф мешавад
  void removePost(String postId) {
    final newPosts = _state.posts.where((p) => p.id != postId).toList();
    _pending.removeWhere((p) => p.id == postId);
    _state = _state.copyWith(posts: newPosts);
    notifyListeners();
  }

  // ✅ REALTIME: пост фавран навсозӣ мешавад
  void updatePost(String postId, {String? caption}) {
    final newPosts = _state.posts.map((p) {
      if (p.id != postId) return p;
      return p.copyWith(caption: caption ?? p.caption);
    }).toList();
    _state = _state.copyWith(posts: newPosts);
    notifyListeners();
  }

  // ✅ Баъди upload — фавран refresh
  Future<void> onPostUploaded() async {
    await refresh();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!SocketService.instance.isConnected) {
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
      _isOffline = false;
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

  // ✅ МУШКИЛИ АСОСӢ ИСЛОҲ ШУД:
  // loadInitialFeed → ФАВРАН кэш нишон медиҳад
  // Корбар blank screen намебинад!
  Future<void> loadInitialFeed() async {
    _page = 1;
    _pending.clear();
    _state = _state.copyWith(isLoading: true, hasError: false);
    notifyListeners();

    try {
      // FeedRepository аввал кэш медиҳад → ФАВРАН
      final posts = await _repository.fetchFeed(
        limit: _limit, page: _page);
      _isOffline = false;
      _state = _state.copyWith(
        isLoading: false,
        posts: posts,
        hasMore: posts.length >= _limit,
        hasError: false,
        errorMessage: null,
      );
    } on UnauthorizedException {
      _state = _state.copyWith(
        isLoading: false, hasMore: false, hasError: true,
        errorMessage: 'Лутфан дубора ворид шавед');
      onUnauthorized?.call();
    } catch (_) {
      // ✅ Хато → offline mode, кэш нишон деҳ
      _isOffline = true;
      _state = _state.copyWith(
        isLoading: false,
        hasError: false, // хато нишон надеҳ — content нишон деҳ
        hasMore: false,
      );
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (!_state.hasMore || _state.isLoading || _isOffline) return;
    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    try {
      _page++;
      final posts = await _repository.fetchFeed(limit: _limit, page: _page);
      _state = _state.copyWith(
        isLoading: false,
        posts: List<PostModel>.from(_state.posts)..addAll(posts),
        hasMore: posts.length >= _limit,
      );
    } catch (_) {
      _page--;
      _state = _state.copyWith(isLoading: false, hasMore: false);
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    _page = 1;
    _pending.clear();
    _state = _state.copyWith(isRefreshing: true, hasError: false);
    notifyListeners();
    try {
      final posts = await _repository.fetchFeed(
        limit: _limit, page: _page, forceRefresh: true);
      _isOffline = false;
      _state = _state.copyWith(
        isRefreshing: false, posts: posts,
        hasMore: posts.length >= _limit,
        hasError: false, errorMessage: null);
    } catch (_) {
      _isOffline = true;
      _state = _state.copyWith(
        isRefreshing: false, hasError: false);
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
