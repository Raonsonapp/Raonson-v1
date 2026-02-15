import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'story_model.dart';

class StoriesApi {
  /// GET stories (grouped by user)
  static Future<Map<String, List<Story>>> fetchStories() async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/stories'),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load stories');
    }

    final Map data = jsonDecode(res.body);

    final Map<String, List<Story>> result = {};
    data.forEach((user, list) {
      result[user] =
          (list as List).map((e) => Story.fromJson(e)).toList();
    });

    return result;
  }

  /// VIEW story
  static Future<void> viewStory(String id, String user) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/stories/$id/view'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user': user}),
    );
  }

  /// CREATE story
  static Future<void> createStory({
    required String user,
    required String mediaUrl,
    required String mediaType,
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
}
