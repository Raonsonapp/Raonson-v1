import 'package:flutter/foundation.dart';

import 'story_repository.dart';
import '../models/story_model.dart';

class StoryController extends ChangeNotifier {
  final StoryRepository _repository;

  StoryController(this._repository);

  List<StoryModel> _stories = [];
  bool _loading = false;

  List<StoryModel> get stories => _stories;
  bool get isLoading => _loading;

  Future<void> loadStories() async {
    _loading = true;
    notifyListeners();

    try {
      _stories = await _repository.fetchStories();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> viewStory(String storyId) async {
    await _repository.markStoryViewed(storyId);
  }
}
