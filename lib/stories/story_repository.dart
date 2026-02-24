import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/story_model.dart';

class StoryRepository {
  final ApiClient _api;
  StoryRepository(this._api);

  Future<List<StoryModel>> fetchStories() async {
    try {
      final res = await _api.get(ApiEndpoints.stories);
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final List list = body is List ? body : (body['stories'] ?? []);
      return list.map((e) => StoryModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<StoryModel>> fetchMyStories() async {
    try {
      final res = await _api.get('${ApiEndpoints.stories}/my');
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final List list = body is List ? body : [];
      return list.map((e) => StoryModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> markStoryViewed(String storyId) async {
    try {
      await _api.post('${ApiEndpoints.stories}/$storyId/view');
    } catch (_) {}
  }
}
