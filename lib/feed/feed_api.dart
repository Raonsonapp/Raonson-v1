import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/token_storage.dart';
import 'post_model.dart';

class FeedApi {
  static Future<List<Post>> getFeed() async {
    final token = await TokenStorage.read();

    final res = await http.get(
      Uri.parse('${Api.baseUrl}/posts'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = jsonDecode(res.body) as List;
    return data.map((e) => Post.fromJson(e)).toList();
  }

  static Future<void> toggleLike(String postId) async {
    final token = await TokenStorage.read();

    await http.post(
      Uri.parse('${Api.baseUrl}/likes/$postId'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
  }
}
