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
    SocketService.instance.on('story:new', _onNewStory);
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
      debugPrint('[Story] socket parse error: $e');
    }
  }

  Future<void> loadStories() async {
    _loading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.fetchStories(),
        _repository.fetchMyStories(),
      ]);
      _myStories = results[1];
      _stories   = results[0];
    } catch (_) {
      _stories   = [];
      _myStories = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Баъди тамошои story → ҳалқа dark green мешавад.
  /// Мисли Instagram: вақте 1 story-и корбар дида шуд →
  /// ҲАМАИ story-ҳои ҳамон корбар viewed=true мешаванд → ҳалқа dark green
  Future<void> markViewed(String storyId) async {
    // Аввал API-га хабар медиҳем
    await _repository.markStoryViewed(storyId);

    // Кадом user-ни story дида шуд пайдо мекунем
    StoryModel? viewed;
    for (final s in _stories) {
      if (s.id == storyId) { viewed = s; break; }
    }
    if (viewed == null) return;

    final userId = viewed.user.id;

    // Ҳамаи story-ҳои ҳамон userId → viewed=true
    _stories = _stories.map((s) {
      if (s.user.id != userId) return s;
      return StoryModel(
        id:         s.id,
        user:       s.user,
        mediaUrl:   s.mediaUrl,
        mediaType:  s.mediaType,
        viewed:     true,       // ← viewed
        isLiked:    s.isLiked,
        likesCount: s.likesCount,
        viewsCount: s.viewsCount,
        expiresAt:  s.expiresAt,
      );
    }).toList();

    notifyListeners();
  }

  // Legacy compat
  Future<void> viewStory(String storyId) => markViewed(storyId);

  @override
  void dispose() {
    SocketService.instance.off('story:new');
    super.dispose();
  }
}
