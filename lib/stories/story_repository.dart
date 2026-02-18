import 'dart:convert';

import '../core/api/api_client.dart';
import '../core/api/api_endpoints.dart';
import '../models/story_model.dart';

class StoryRepository {
  final ApiClient _api = ApiClient.instance;

  Future<List<StoryModel>> fetchStories() async {
    final res = await _api.getRequest(ApiEndpoints.stories);

    final List list = jsonDecode(res.body);
    return list.map((e) => StoryModel.fromJson(e)).toList();
  }

  Future<void> uploadStory(String mediaUrl) async {
    await _api.postRequest(
      ApiEndpoints.stories,
      body: {'media': mediaUrl},
    );
  }
}
