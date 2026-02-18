import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/story_model.dart';

class StoryRepository {
  /// =========================
  /// FETCH STORIES
  /// =========================
  Future<List<StoryModel>> fetchStories() async {
    final response = await ApiClient.get(ApiEndpoints.stories);

    final List list = jsonDecode(response.body) as List;
    return list.map((e) => StoryModel.fromJson(e)).toList();
  }

  /// =========================
  /// MARK STORY AS VIEWED
  /// =========================
  Future<void> markStoryViewed(String storyId) async {
    await ApiClient.post(
      '${ApiEndpoints.stories}/$storyId/view',
    );
  }
}
