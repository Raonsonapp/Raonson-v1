import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class StoryApi {
  static Future<List<dynamic>> fetchStories() async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/stories'),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load stories');
    }
    return jsonDecode(res.body);
  }

  static Future<void> markViewed(String storyId) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/stories/$storyId/view'),
    );
  }
}
