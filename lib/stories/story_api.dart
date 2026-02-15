import 'dart:convert';
import '../core/api.dart';

class StoryApi {
  // GET STORIES (grouped by user)
  static Future<Map<String, dynamic>> fetchStories() async {
    final res = await Api.get('/stories');
    return jsonDecode(res.body);
  }

  // CREATE STORY
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

  // VIEW STORY
  static Future<void> viewStory(String id, String user) async {
    await Api.post('/stories/$id/view', body: {
      'user': user,
    });
  }

  // LIKE STORY (optional, for UI)
  static Future<int> likeStory(String id, String user) async {
    final res = await Api.post('/stories/$id/like', body: {
      'user': user,
    });
    return jsonDecode(res.body)['likes'];
  }

  // REPLY STORY
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
