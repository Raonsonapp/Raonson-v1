import 'dart:convert';
import 'package:http/http.dart' as http;

class HomeApi {
  static const String baseUrl = 'https://YOUR_BACKEND_URL';

  static Future<List<dynamic>> fetchFeed() async {
    final res = await http.get(Uri.parse('$baseUrl/feed'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load feed');
  }

  static Future<void> likePost(String postId) async {
    await http.post(Uri.parse('$baseUrl/posts/$postId/like'));
  }
}
