import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/socket_service.dart';
import 'story_repository.dart';
import 'story_seen_sync.dart';
import '../models/story_model.dart';
import '../core/services/user_session.dart';

class StoryController extends ChangeNotifier {
  final StoryRepository _repository;
  StoryController(this._repository) {
    _subscribeSocket();
    _loadViewedCache();
    // Сторис аз сарлавҳаи пост / Reels / профил дида шуд → сатри
    // сторис ҳам фавран хокистарӣ (пеш танҳо аз худи сатр кор мекард).
    StorySeenSync.instance.lastViewed.addListener(_onSyncViewed);
  }

  void _onSyncViewed() {
    final id = StorySeenSync.instance.lastViewed.value;
    if (id == null || id.isEmpty) return;
    final known = _stories.any((s) => s.id == id && !s.viewed) ||
        _myStories.any((s) => s.id == id && !s.viewed);
    if (!known) return;
    _viewedIds.add(id);
    _saveViewedCache();
    _stories = _applyViewedCache(_stories);
    _myStories = _applyViewedCache(_myStories);
    notifyListeners();
  }

  List<StoryModel> _stories   = [];
  List<StoryModel> _myStories = [];
  bool _loading = false;
  // ── Локал viewed cache: storyId → viewed ────────────────────
  final Set<String> _viewedIds = {};
  static const _kPrefKey = 'story_viewed_ids';

  List<StoryModel> get stories   => _stories;
  List<StoryModel> get myStories => _myStories;
  bool get hasMyStory => _myStories.isNotEmpty;
  bool get isLoading  => _loading;

  // ── Load viewed IDs from SharedPreferences ───────────────────
  Future<void> _loadViewedCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kPrefKey) ?? [];
      _viewedIds.addAll(list);
    } catch (_) {}
  }

  // ── Save viewed IDs to SharedPreferences ─────────────────────
  Future<void> _saveViewedCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPrefKey, _viewedIds.toList());
    } catch (_) {}
  }

  // ── Apply local viewed cache to stories list ─────────────────
  List<StoryModel> _applyViewedCache(List<StoryModel> list) {
    return list.map((s) => _viewedIds.contains(s.id)
        ? StoryModel(id: s.id, user: s.user, mediaUrl: s.mediaUrl,
            mediaType: s.mediaType, viewed: true,
            isLiked: s.isLiked, likesCount: s.likesCount,
            viewsCount: s.viewsCount, expiresAt: s.expiresAt)
        : s).toList();
  }

  void _subscribeSocket() {
    try { SocketService.instance.on('story:new', _onNewStory); } catch (_) {}
  }

  void _onNewStory(dynamic data) {
    if (data is! Map<String, dynamic>) return;
    try {
      final s     = StoryModel.fromJson(data);
      // Сториси нав → ҳалқа дар ҳамаи экранҳо боз ранга.
      StorySeenSync.instance.markNewStory(s.user.id, storyId: s.id);
      final myId  = UserSession.userId ?? '';
      if (s.user.id == myId) {
        if (!_myStories.any((x) => x.id == s.id)) {
          _myStories = [s, ..._myStories];
          notifyListeners();
        }
      } else {
        if (!_stories.any((x) => x.id == s.id)) {
          _stories = [s, ..._stories];
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> loadStories() async {
    _loading = true;
    notifyListeners();
    try {
      final res  = await Future.wait([
        _repository.fetchStories(),
        _repository.fetchMyStories(),
      ]);
      // ── Apply local viewed cache (persistent across sessions) ─
      _stories   = _applyViewedCache(res[0]);
      _myStories = _applyViewedCache(res[1]);
      // Ҳамин рӯйхат — манбаи дақиқи ҳалқа барои ҳамаи экранҳо.
      StorySeenSync.instance.primeStories([..._stories, ..._myStories],
          completeFor: [if ((UserSession.userId ?? '').isNotEmpty) UserSession.userId!]);
    } catch (_) {
      _stories = []; _myStories = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Story дида шуд — ҳалқа хокистарӣ мешавад
  /// Viewed state дар SharedPreferences нигаҳ мешавад (persistent!)
  Future<void> markViewed(String storyId) async {
    try { await _repository.markStoryViewed(storyId); } catch (_) {}

    // ── Add to local cache ───────────────────────────────────
    _viewedIds.add(storyId);
    _saveViewedCache(); // async, бе await

    StoryModel markOne(StoryModel s) {
      if (s.id != storyId && s.viewed) return s;
      if (!_viewedIds.contains(s.id)) return s;
      return StoryModel(
        id: s.id, user: s.user, mediaUrl: s.mediaUrl,
        mediaType: s.mediaType, viewed: true,
        isLiked: s.isLiked, likesCount: s.likesCount,
        viewsCount: s.viewsCount, expiresAt: s.expiresAt);
    }

    // ── Update _stories ──────────────────────────────────────
    _stories = _stories.map((s) {
      if (s.id != storyId) return s;
      _viewedIds.add(s.id); // ба ҳамаи story-и ҳамон group
      return markOne(s);
    }).toList();

    // ── Update _myStories (story-и худ) ─────────────────────
    _myStories = _myStories.map((s) {
      if (s.id != storyId) return s;
      return markOne(s);
    }).toList();

    notifyListeners();
  }

  Future<void> viewStory(String id) => markViewed(id);

  @override
  void dispose() {
    StorySeenSync.instance.lastViewed.removeListener(_onSyncViewed);
    try { SocketService.instance.off('story:new'); } catch (_) {}
    super.dispose();
  }
}
