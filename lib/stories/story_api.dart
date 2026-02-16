import 'dart:convert';
import 'package:http/http.dart' as http;

import '../core/constants.dart';

class StoryApi {
  /// GET STORIES (grouped by user)
  static Future<Map<String, dynamic>> fetchStories() async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/stories'),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load stories');
    }

    return jsonDecode(res.body);
  }

  /// CREATE STORY
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
      throw Exception('Story upload failed');
    }
  }

  /// VIEW STORY
  static Future<void> viewStory(String id, String user) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/stories/$id/view'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user': user}),
    );
  }
}
