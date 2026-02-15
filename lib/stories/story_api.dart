import '../core/api.dart';

class StoryApi {
  static Future<Map<String, dynamic>> fetchStories() async {
    return await Api.get('/stories');
  }

  static Future<void> createStory({
    required String user,
    required String mediaUrl,
    required String mediaType, // image | video
  }) async {
    await Api.post('/stories', body: {
      'user': user,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
    });
  }

  static Future<void> viewStory(String storyId, String user) async {
    await Api.post('/stories/$storyId/view', body: {
      'user': user,
    });
  }
}
