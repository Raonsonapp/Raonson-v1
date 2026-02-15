import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class CommentApi {
  // GET COMMENTS (postId OR reelId)
  static Future<List<dynamic>> fetchComments({
    required String targetId,
    required String type, // 'post' | 'reel'
  }) async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/comments/$type/$targetId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load comments');
    }

    return jsonDecode(res.body);
  }

  // ADD COMMENT
  static Future<void> addComment({
    required String targetId,
    required String type, // 'post' | 'reel'
    required String user,
    required String text,
  }) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/comments/$type/$targetId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user': user,
        'text': text,
      }),
    );
  }
}
