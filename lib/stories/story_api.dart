import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class StoryApi {
  // GET STORIES (24h, grouped by user)
  static Future<Map<String, List<dynamic>>> fetchStories() async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/stories'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load stories');
    }

    final Map<String, dynamic> data = jsonDecode(res.body);

    return data.map(
      (key, value) => MapEntry(key, List<dynamic>.from(value)),
    );
  }

  // CREATE STORY
  static Future<void> uploadStory({
    required String user,
    required String mediaUrl,
    required String mediaType, // image | video
  }) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/stories'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user': user,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
      }),
    );
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
