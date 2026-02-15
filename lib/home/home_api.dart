import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class HomeApi {
  static const _headers = {'Content-Type': 'application/json'};

  // FEED
  static Future<List<dynamic>> fetchFeed() async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/posts'),
    );
    if (res.statusCode != 200) {
      throw Exception('Failed to load feed');
    }
    return jsonDecode(res.body);
  }

  // LIKE
  static Future<int> likePost(String postId) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/posts/$postId/like'),
      headers: _headers,
    );
    if (res.statusCode != 200) {
      throw Exception('Like failed');
    }
    return jsonDecode(res.body)['likes'];
  }

  // SAVE / UNSAVE
  static Future<bool> toggleSave(String postId) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/posts/$postId/save'),
      headers: _headers,
      body: jsonEncode({'user': 'raonson'}),
    );
    if (res.statusCode != 200) {
      throw Exception('Save failed');
    }
    return jsonDecode(res.body)['saved'] == true;
  }
}
