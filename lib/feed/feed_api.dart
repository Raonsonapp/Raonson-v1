import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api/api.dart';
import 'feed_model.dart';

class FeedApi {
  static Future<List<FeedPost>> getFeed() async {
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/posts'),
    );

    final List data = jsonDecode(res.body);
    return data.map((e) => FeedPost.fromJson(e)).toList();
  }

  static Future<void> like(String postId) async {
    await http.post(
      Uri.parse('${Api.baseUrl}/likes/$postId'),
    );
  }

  static Future<void> save(String postId) async {
    await http.post(
      Uri.parse('${Api.baseUrl}/save/$postId'),
    );
  }
}
