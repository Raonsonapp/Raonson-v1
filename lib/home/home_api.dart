import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'post_model.dart';

class HomeApi {
  static Future<List<Post>> fetchFeed() async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/posts'),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load feed');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => Post.fromJson(e)).toList();
  }

  static Future<int> like(String postId) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/posts/$postId/like'),
    );
    return jsonDecode(res.body)['likes'];
  }

  static Future<bool> toggleSave(String postId) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/posts/$postId/save'),
    );
    return jsonDecode(res.body)['saved'];
  }
}
