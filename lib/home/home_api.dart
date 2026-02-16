import 'dart:convert';
import 'package:http/http.dart' as http;

class HomeApi {
  static const baseUrl = 'https://YOUR_RENDER_URL';

  static Future<List<dynamic>> fetchFeed() async {
    final res = await http.get(Uri.parse('$baseUrl/posts'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Feed error');
  }

  static Future<void> likePost(String postId) async {
    await http.post(
      Uri.parse('$baseUrl/posts/$postId/like'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user': 'raonson'}),
    );
  }
}
