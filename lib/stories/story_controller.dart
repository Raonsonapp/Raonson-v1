import 'package:flutter/foundation.dart';

import '../core/services/socket_service.dart';
import 'story_repository.dart';
import '../models/story_model.dart';
import '../core/services/user_session.dart';

class StoryController extends ChangeNotifier {
  final StoryRepository _repository;

  StoryController(this._repository) {
    _subscribeSocket();
  }

  List<StoryModel> _stories   = [];
  List<StoryModel> _myStories = [];
  bool _loading = false;

  List<StoryModel> get stories   => _stories;
  List<StoryModel> get myStories => _myStories;
  bool get hasMyStory => _myStories.isNotEmpty;
  bool get isLoading  => _loading;

  void _subscribeSocket() {
    try {
      SocketService.instance.on('story:new', _onNewStory);
    } catch (_) {}
  }

  void _onNewStory(dynamic data) {
    if (data is! Map<String, dynamic>) return;
    try {
      final story = StoryModel.fromJson(data);
      final myId  = UserSession.userId ?? '';
      if (story.user.id == myId) {
        if (!_myStories.any((s) => s.id == story.id)) {
          _myStories = [story, ..._myStories];
          notifyListeners();
        }
      } else {
        if (!_stories.any((s) => s.id == story.id)) {
          _stories = [story, ..._stories];
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('[Story] socket parse: $e');
    }
  }

  Future<void> loadStories() async {
    _loading = true;
    notifyListeners();
    try {
      final res = await Future.wait([
        _repository.fetchStories(),
        _repository.fetchMyStories(),
      ]);
      _stories   = res[0];
      _myStories = res[1];
    } catch (_) {
      _stories   = [];
      _myStories = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Баъди тамошои story → ҳалқа dark green/grey мешавад
  Future<void> markViewed(String storyId) async {
    try {
      await _repository.markStoryViewed(storyId);
    } catch (_) {}

    // Кадом userId story дид
    String? userId;
    for (final s in _stories) {
      if (s.id == storyId) { userId = s.user.id; break; }
    }
    if (userId == null) return;

    // Ҳамаи story-ҳои ҳамон user → viewed=true
    _stories = _stories.map((s) =>
      s.user.id == userId ? _viewed(s) : s).toList();

    notifyListeners();
  }

  StoryModel _viewed(StoryModel s) => StoryModel(
    id:         s.id,
    user:       s.user,
    mediaUrl:   s.mediaUrl,
    mediaType:  s.mediaType,
    viewed:     true,
    isLiked:    s.isLiked,
    likesCount: s.likesCount,
    viewsCount: s.viewsCount,
    expiresAt:  s.expiresAt,
  );

  Future<void> viewStory(String storyId) => markViewed(storyId);

  @override
  void dispose() {
    try { SocketService.instance.off('story:new'); } catch (_) {}
    super.dispose();
  }
}
