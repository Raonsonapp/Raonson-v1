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
      debugPrint('[Story] WebSocket parse error: $e');
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

  /// Story дида шуд — ВА ҲАМ stories-и ҳамон user-ро viewed=true мекунем
  /// Ин мисли Instagram: агар 1 story-и user дида шавад → ҳалқа dark green мешавад
  Future<void> markViewed(String storyId) async {
    // API call
    await _repository.markStoryViewed(storyId);

    // Story-и дида шударо пайдо мекунем
    final viewedStory = _stories.firstWhere(
      (s) => s.id == storyId,
      orElse: () => _myStories.firstWhere(
        (s) => s.id == storyId,
        orElse: () => throw StateError('not found'),
      ),
    );

    // ҲАМ story-ҳои ҳамон userid-ро viewed=true мекунем
    // (як story дида шуд → ҳалқа dark green мешавад мисли Instagram)
    final userId = viewedStory.user.id;

    _stories = _stories.map((s) {
      if (s.user.id == userId) {
        return _copyWithViewed(s);
      }
      return s;
    }).toList();

    notifyListeners();
  }

  StoryModel _copyWithViewed(StoryModel s) => StoryModel(
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

  // Legacy compat
  Future<void> viewStory(String storyId) => markViewed(storyId);

  @override
  void dispose() {
    SocketService.instance.off('story:new');
    super.dispose();
  }
}
