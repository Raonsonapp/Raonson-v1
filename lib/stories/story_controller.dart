import 'package:flutter/foundation.dart';

import '../core/services/socket_service.dart';
import 'story_repository.dart';
import '../models/story_model.dart';
import '../core/services/user_session.dart';

class StoryController extends ChangeNotifier {
  final StoryRepository _repository;
  StoryController(this._repository) { _subscribeSocket(); }

  List<StoryModel> _stories   = [];
  List<StoryModel> _myStories = [];
  bool _loading = false;

  List<StoryModel> get stories   => _stories;
  List<StoryModel> get myStories => _myStories;
  bool get hasMyStory => _myStories.isNotEmpty;
  bool get isLoading  => _loading;

  void _subscribeSocket() {
    try { SocketService.instance.on('story:new', _onNewStory); } catch (_) {}
  }

  void _onNewStory(dynamic data) {
    if (data is! Map<String, dynamic>) return;
    try {
      final s     = StoryModel.fromJson(data);
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
      _stories   = res[0];
      _myStories = res[1];
    } catch (_) {
      _stories = []; _myStories = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Story дида шуд — ҳамаи story-ҳои ҳамон корбар viewed=true
  /// Ҳалқа: надида → cyan-green, дида → dark grey мисли Instagram
  Future<void> markViewed(String storyId) async {
    // API
    try { await _repository.markStoryViewed(storyId); } catch (_) {}

    // Кадом user story дид?
    String? userId;
    for (final s in _stories) {
      if (s.id == storyId) { userId = s.user.id; break; }
    }
    if (userId == null) return; // story топилмад

    // Ҳамаи stories-и ҳамон user → viewed=true
    bool changed = false;
    _stories = _stories.map((s) {
      if (s.user.id != userId || s.viewed) return s;
      changed = true;
      return StoryModel(
        id: s.id, user: s.user, mediaUrl: s.mediaUrl,
        mediaType: s.mediaType, viewed: true,
        isLiked: s.isLiked, likesCount: s.likesCount,
        viewsCount: s.viewsCount, expiresAt: s.expiresAt);
    }).toList();

    if (changed) notifyListeners();
  }

  Future<void> viewStory(String id) => markViewed(id);

  @override
  void dispose() {
    try { SocketService.instance.off('story:new'); } catch (_) {}
    super.dispose();
  }
}
