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

  // ── WebSocket: story нав омад ─────────────────────────────────────
  void _subscribeSocket() {
    SocketService.instance.on('story:new', _onNewStory);
  }

  void _onNewStory(dynamic data) {
    if (data is! Map<String, dynamic>) return;
    try {
      final story = StoryModel.fromJson(data);
      final myId  = UserSession.userId ?? '';

      if (story.user.id == myId) {
        // Ин story-и худамон аст
        final alreadyMine = _myStories.any((s) => s.id == story.id);
        if (!alreadyMine) {
          _myStories = [story, ..._myStories];
          notifyListeners();
        }
      } else {
        // Story-и дигар нафар
        final alreadyInFeed = _stories.any((s) => s.id == story.id);
        if (!alreadyInFeed) {
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

  /// Story дида шуд — UI-ро навмекунем (border хокистарӣ мешавад)
  Future<void> markViewed(String storyId) async {
    await _repository.markStoryViewed(storyId);

    // Stories-ро дар рӯйхат viewed=true мекунем
    _stories = _stories.map((s) {
      if (s.id == storyId) {
        return StoryModel(
          id:         s.id,
          user:       s.user,
          mediaUrl:   s.mediaUrl,
          mediaType:  s.mediaType,
          viewed:     true, // ← viewed шуд
          isLiked:    s.isLiked,
          likesCount: s.likesCount,
          viewsCount: s.viewsCount,
          expiresAt:  s.expiresAt,
        );
      }
      return s;
    }).toList();

    notifyListeners();
  }

  // Legacy
  Future<void> viewStory(String storyId) => markViewed(storyId);

  @override
  void dispose() {
    SocketService.instance.off('story:new');
    super.dispose();
  }
}
