import 'dart:convert';
import 'package:http/http.dart' as http;
import 'feed_model.dart';

class FeedApi {
  static const String baseUrl =
      'https://raonson-v1.onrender.com';

  static Future<List<FeedPost>> getPosts() async {
    final res = await http.get(Uri.parse('$baseUrl/posts'));

    if (res.statusCode != 200) {
      throw Exception('Failed to load posts');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => FeedPost.fromJson(e)).toList();
  }

  static Future<void> likePost(String postId) async {
    await http.post(Uri.parse('$baseUrl/likes/$postId'));
  }

  static Future<void> savePost(String postId) async {
    await http.post(Uri.parse('$baseUrl/save/$postId'));
  }
}
