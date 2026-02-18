import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/story_model.dart';

class StoryRepository {
  final ApiClient _api;

  StoryRepository(this._api);

  Future<List<StoryModel>> fetchStories() async {
    final res = await _api.get(ApiEndpoints.stories);
    return (jsonDecode(res.data) as List)
        .map((e) => StoryModel.fromJson(e))
        .toList();
  }

  Future<void> markStoryViewed(String storyId) async {
    await _api.post('${ApiEndpoints.stories}/$storyId/view');
  }
}
