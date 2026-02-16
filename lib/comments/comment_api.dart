import 'dart:convert';
import '../core/api.dart';

class CommentApi {
  static Future<List<dynamic>> fetch(String postId) async {
    final res = await Api.get('/comments/$postId');
    return jsonDecode(res.body);
  }

  static Future<void> add({
    required String postId,
    required String text,
    String? parentId,
  }) async {
    await Api.post('/comments/$postId', {
      'text': text,
      if (parentId != null) 'parentId': parentId,
    });
  }

  static Future<bool> like(String commentId) async {
    final res = await Api.post('/comments/like/$commentId', {});
    return jsonDecode(res.body)['liked'];
  }
}
