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
      // Backend Array ё Object бармегардонад
      final List list = _extractList(body);
      return list
          .map((e) => StoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<StoryModel>> fetchMyStories() async {
    try {
      final res = await _api.get('${ApiEndpoints.stories}/my');
      if (res.statusCode >= 400) return [];
      final body = jsonDecode(res.body);
      final List list = _extractList(body);
      return list
          .map((e) => StoryModel.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> markStoryViewed(String storyId) async {
    try {
      await _api.post('${ApiEndpoints.stories}/$storyId/view');
    } catch (_) {}
  }

  // Backend array ё object бармегардонад — ҳарду ҳолро мегирем
  List _extractList(dynamic body) {
    if (body is List) return body;
    if (body is Map) {
      return body['stories'] ??
             body['data']    ??
             body['items']   ??
             [];
    }
    return [];
  }
}
