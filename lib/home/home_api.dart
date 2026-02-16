import 'dart:convert';
import '../core/api.dart';

class HomeApi {
  static Future<Map<String, dynamic>> fetchFeed(int page) async {
    final res = await Api.get('/posts/feed?page=$page&limit=10');
    return jsonDecode(res.body);
  }

  static Future<bool> toggleLike(String postId) async {
    final res = await Api.post('/posts/$postId/like', {});
    return jsonDecode(res.body)['liked'];
  }

  static Future<bool> toggleSave(String postId) async {
    final res = await Api.post('/posts/$postId/save', {});
    return jsonDecode(res.body)['saved'];
  }
}
