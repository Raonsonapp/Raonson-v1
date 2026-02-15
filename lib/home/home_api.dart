import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class HomeApi {
  // GET FEED
  static Future<List<dynamic>> fetchFeed() async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/feed'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load feed');
    }

    return jsonDecode(res.body);
  }

  // ❤️ LIKE POST
  static Future<void> likePost(String postId) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/posts/$postId/like'),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
