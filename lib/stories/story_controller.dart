import 'package:flutter/foundation.dart';

import 'story_repository.dart';
import '../models/story_model.dart';

class StoryController extends ChangeNotifier {
  final StoryRepository _repository;

  StoryController(this._repository);

  List<StoryModel> _stories = [];
  List<StoryModel> _myStories = [];
  bool _loading = false;

  List<StoryModel> get stories => _stories;
  List<StoryModel> get myStories => _myStories;
  bool get hasMyStory => _myStories.isNotEmpty;
  bool get isLoading => _loading;

  Future<void> loadStories() async {
    _loading = true;
    notifyListeners();
    try {
      final all = await _repository.fetchStories();
      final my = await _repository.fetchMyStories();
      _myStories = my;
      // Filter out own stories from main list
      final myIds = my.map((s) => s.id).toSet();
      _stories = all.where((s) => !myIds.contains(s.id)).toList();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> viewStory(String storyId) async {
    await _repository.markStoryViewed(storyId);
  }
}
