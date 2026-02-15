import 'dart:convert';
import 'package:http/http.dart' as http;
import 'story_model.dart';

class StoryApi {
  static const String baseUrl = 'https://YOUR_RENDER_BACKEND_URL';

  /// GET STORIES (grouped by user)
  static Future<Map<String, List<Story>>> fetchStories() async {
    final res = await http.get(Uri.parse('$baseUrl/stories'));

    if (res.statusCode != 200) {
      throw Exception('Failed to load stories');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final Map<String, List<Story>> result = {};

    data.forEach((user, list) {
      result[user] = (list as List)
          .map((e) => Story.fromJson(e))
          .toList();
    });

    return result;
  }

  /// VIEW STORY
  static Future<void> viewStory(String storyId, String user) async {
    await http.post(
      Uri.parse('$baseUrl/stories/$storyId/view'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user': user}),
    );
  }
}
