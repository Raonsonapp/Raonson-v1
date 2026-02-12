import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api/api.dart';

class FeedApi {
  static Future<List<dynamic>> getPosts() async {
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/posts'),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load posts');
    }

    return jsonDecode(res.body);
  }

  static Future<void> likePost(String postId) async {
    await http.post(
      Uri.parse('${Api.baseUrl}/likes/$postId'),
    );
  }

  static Future<void> savePost(String postId) async {
    await http.post(
      Uri.parse('${Api.baseUrl}/save/$postId'),
    );
  }
}
