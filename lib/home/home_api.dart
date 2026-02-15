import 'dart:convert';
import 'package:http/http.dart' as http;
import 'post_model.dart';

class HomeApi {
  static const String baseUrl = 'https://YOUR_RENDER_URL';

  // ================= GET FEED =================
  static Future<List<Post>> fetchFeed() async {
    final res = await http.get(Uri.parse('$baseUrl/posts'));

    if (res.statusCode != 200) {
      throw Exception('Failed to load feed');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => Post.fromJson(e)).toList();
  }

  // ================= LIKE POST =================
  static Future<int> likePost(String postId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/posts/$postId/like'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user': 'raonson'}), // ⬅️ user дар body
    );

    if (res.statusCode != 200) {
      throw Exception('Like failed');
    }

    return jsonDecode(res.body)['likes'];
  }
}
