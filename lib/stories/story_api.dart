import '../core/api.dart';

class StoryApi {
  static Future<Map<String, dynamic>> fetchStories() async {
    return await Api.get('/stories');
  }

  static Future<void> createStory({
    required String user,
    required String mediaUrl,
    required String mediaType,
  }) async {
    await Api.post('/stories', body: {
      'user': user,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
    });
  }

  static Future<void> viewStory(String id, String user) async {
    await Api.post('/stories/$id/view', body: {'user': user});
  }

  static Future<int> likeStory(String id, String user) async {
    final res = await Api.post('/stories/$id/like', body: {'user': user});
    return res['likes'];
  }

  static Future<void> replyStory({
    required String id,
    required String user,
    required String text,
  }) async {
    await Api.post('/stories/$id/reply', body: {
      'user': user,
      'text': text,
    });
  }
}
