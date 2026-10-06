import 'dart:async';
import 'package:flutter/widgets.dart';
import '../../core/error/friendly_error.dart';
import '../../models/post_model.dart';
import '../../core/services/socket_service.dart';
import '../feed_repository.dart';
import '../feed_exceptions.dart';
import 'feed_state.dart';
import '../../create/upload/post_upload_service.dart';

class FeedController extends ChangeNotifier with WidgetsBindingObserver {
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
  bool _isAppActive = true;

  FeedController(this._repository) {
    WidgetsBinding.instance.addObserver(this);
    _subscribeSocket();
    _startPolling();
    // Баъди загрузкаи фонии пост — феедро нав мекунад.
    PostUploadService.instance.onPublished = () => onPostUploaded();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppActive = state == AppLifecycleState.resumed;
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
      if (!_isAppActive) return;
      if (!SocketService.instance.isConnected) {
        await _silentCheck();
      }
    });
  }

  Future<void> _silentCheck() async {
    try {
      final posts = await _repository.fetchFeed(
        limit: 5, page: 1, forceRefresh: true, mode: _mode);
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
  // ── Режими лента: '' (барои шумо) / following / favorites ────
  String _mode = '';
  String get mode => _mode;

  /// Мисли Instagram: логоро мезанед → «Обунаҳо» ё «Дӯстдоштаҳо».
  Future<void> setMode(String m) async {
    if (m == _mode) return;
    _mode = m;
    await refresh();
  }

  Future<void> loadInitialFeed() async {
    _page = 1;
    _pending.clear();
    _state = _state.copyWith(isLoading: true, hasError: false);
    notifyListeners();

    var fromCache = false;
    try {
      // FeedRepository аввал кэш медиҳад → ФАВРАН
      final posts = await _repository.fetchFeed(
        limit: _limit, page: _page, mode: _mode);
      fromCache = _repository.lastFromCache;
      _isOffline = false;
      _state = _state.copyWith(
        isLoading: false,
        posts: posts,
        hasMore: !fromCache && posts.length >= _limit,
        hasError: false,
        errorMessage: null,
      );
    } on UnauthorizedException {
      _state = _state.copyWith(
        isLoading: false, hasMore: false, hasError: true,
        errorMessage: 'Лутфан дубора ворид шавед');
      onUnauthorized?.call();
    } catch (e) {
      // Кэш умуман нест ва шабака нашуд → экрани хато (на «лента холист»).
      _isOffline = true;
      _state = _state.copyWith(
        isLoading: false,
        hasError: _state.posts.isEmpty,
        errorMessage: friendlyError(e),
        hasMore: false,
      );
    }
    notifyListeners();
    // Кэш нишон дода шуд → дар фон аз шабака нав мекунем (мисли Instagram).
    if (fromCache) await refresh(silent: true);
  }

  Future<void> loadMore() async {
    if (!_state.hasMore || _state.isLoading || _isOffline) return;
    _state = _state.copyWith(isLoading: true);
    notifyListeners();
    try {
      _page++;
      final posts = await _repository.fetchFeed(limit: _limit, page: _page, mode: _mode);
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

  /// [silent] — бе спиннер (навсозии фонӣ баъди нишон додани кэш).
  Future<void> refresh({bool silent = false}) async {
    _page = 1;
    _pending.clear();
    if (!silent) {
      _state = _state.copyWith(isRefreshing: true, hasError: false);
      notifyListeners();
    }
    try {
      final posts = await _repository.fetchFeed(
        limit: _limit, page: _page, forceRefresh: true, mode: _mode);
      // Repository ҳангоми хатои шабака кэшро бармегардонад.
      _isOffline = _repository.lastFromCache;
      if (_isOffline && silent) {
        // Кэш аллакай дар экран аст — танҳо баннер.
      } else {
        _state = _state.copyWith(
          isRefreshing: false, posts: posts,
          hasMore: !_isOffline && posts.length >= _limit,
          hasError: false, errorMessage: null);
      }
      if (!_isOffline) {
        for (final p in posts) { p.primeSync(); }
      }
    } on UnauthorizedException {
      _state = _state.copyWith(isRefreshing: false);
      onUnauthorized?.call();
    } catch (e) {
      _isOffline = true;
      _state = _state.copyWith(
        isRefreshing: false,
        hasError: _state.posts.isEmpty,
        errorMessage: friendlyError(e));
    }
    _state = _state.copyWith(isRefreshing: false);
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    SocketService.instance.off('feed:new_post');
    super.dispose();
  }
}
