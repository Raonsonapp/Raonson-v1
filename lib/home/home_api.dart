import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'post_model.dart';

class HomeApi {
  // GET FEED
  static Future<List<Post>> fetchFeed() async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/posts'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load feed');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => Post.fromJson(e)).toList();
  }

  // LIKE POST
  static Future<int> likePost(String postId) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/posts/$postId/like'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user': 'raonson'}), // MVP
    );

    if (res.statusCode != 200) {
      throw Exception('Like failed');
    }

    final data = jsonDecode(res.body);
    return data['likes'];
  }
}
