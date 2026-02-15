import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'story_model.dart';

class StoriesApi {
  // GET STORIES (grouped by user)
  static Future<Map<String, List<Story>>> fetchStories() async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/stories'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load stories');
    }

    final Map<String, dynamic> data = jsonDecode(res.body);
    final Map<String, List<Story>> result = {};

    data.forEach((user, list) {
      result[user] =
          (list as List).map((e) => Story.fromJson(e)).toList();
    });

    return result;
  }

  // CREATE STORY
  static Future<void> createStory({
    required String user,
    required String mediaUrl,
    required String mediaType,
  }) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/stories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user': user,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to create story');
    }
  }

  // VIEW STORY
  static Future<void> viewStory(String storyId, String user) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/stories/$storyId/view'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user': user}),
    );
  }
}
