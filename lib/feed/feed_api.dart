import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/token_storage.dart';
import 'feed_model.dart';

class FeedApi {
  static Future<List<FeedPost>> getFeed() async {
    final token = await TokenStorage.read();
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/posts'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body) as List;
    return data.map((e) => FeedPost.fromJson(e)).toList();
  }

  static Future<void> toggleLike(String postId) async {
    final token = await TokenStorage.read();
    await http.post(
      Uri.parse('${Api.baseUrl}/likes/$postId'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  static Future<void> toggleSave(String postId) async {
    final token = await TokenStorage.read();
    await http.post(
      Uri.parse('${Api.baseUrl}/save/$postId'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
