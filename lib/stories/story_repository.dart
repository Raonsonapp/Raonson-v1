import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/storage/token_storage.dart';
import '../models/story_model.dart';

class StoryRepository {
  final Dio _dio = ApiClient.instance.dio;
  final TokenStorage _tokenStorage = TokenStorage();

  Future<List<StoryModel>> fetchStories() async {
    final token = await _tokenStorage.getAccessToken();

    final response = await _dio.get(
      '/stories',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final List data = response.data as List;
    return data.map((e) => StoryModel.fromJson(e)).toList();
  }

  Future<void> markStoryViewed(String storyId) async {
    final token = await _tokenStorage.getAccessToken();

    await _dio.post(
      '/stories/$storyId/view',
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );
  }
}
