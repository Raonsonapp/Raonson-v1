import 'package:flutter/foundation.dart';

import '../../core/services/socket_service.dart';
import 'story_repository.dart';
import '../models/story_model.dart';

class StoryController extends ChangeNotifier {
  final StoryRepository _repository;

  StoryController(this._repository) {
    _subscribeSocket();
  }

  List<StoryModel> _stories = [];
  List<StoryModel> _myStories = [];
  bool _loading = false;

  List<StoryModel> get stories => _stories;
  List<StoryModel> get myStories => _myStories;
  bool get hasMyStory => _myStories.isNotEmpty;
  bool get isLoading => _loading;

  // ── WebSocket: story нав омад ─────────────────────────────────────
  void _subscribeSocket() {
    SocketService.instance.on('story:new', _onNewStory);
  }

  void _onNewStory(dynamic data) {
    if (data is! Map<String, dynamic>) return;
    try {
      final story = StoryModel.fromJson(data);

      // Агар ин story-и худи мо бошад → myStories-ро навкун
      final isMyStory = _myStories.isNotEmpty &&
          _myStories.first.user.id == story.user.id;
      if (isMyStory || story.user.id == story.user.id) {
        // stories-ро live навкун — дар аввал гузор
        final alreadyInFeed = _stories.any((s) => s.id == story.id);
        if (!alreadyInFeed) {
          _stories = [story, ..._stories];
        }
        // Агар story-и худи мо
        final alreadyMine = _myStories.any((s) => s.id == story.id);
        if (!alreadyMine && story.user.id == (_myStories.isNotEmpty ? _myStories.first.user.id : '')) {
          _myStories = [story, ..._myStories];
        }
        notifyListeners();
      } else {
        // Story-и дигар нафар — ба лента мефузояд
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
      final all = results[0];
      final my = results[1];
      _myStories = my;
      _stories = all;
    } catch (_) {
      _stories = [];
      _myStories = [];
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> viewStory(String storyId) async {
    await _repository.markStoryViewed(storyId);
  }

  @override
  void dispose() {
    SocketService.instance.off('story:new');
    super.dispose();
  }
}
