import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/story_model.dart';

class StoryRepository {
  /// GET STORIES
  Future<List<StoryModel>> fetchStories() async {
    final res = await ApiClient.get(
      ApiEndpoints.stories,
    );

    final List list = jsonDecode(res.body);
    return list.map((e) => StoryModel.fromJson(e)).toList();
  }

  /// MARK STORY AS VIEWED
  Future<void> markStoryViewed(String storyId) async {
    await ApiClient.post(
      '${ApiEndpoints.stories}/$storyId/view',
    );
  }
}
