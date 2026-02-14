import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import 'comment_model.dart';

class CommentApi {
  /// GET COMMENTS FOR REEL
  static Future<List<Comment>> fetchComments(String reelId) async {
    final res = await Api.get('/comments/$reelId');

    if (res.statusCode != 200) {
      throw Exception('Failed to load comments');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => Comment.fromJson(e)).toList();
  }

  /// ADD COMMENT
  static Future<Comment> addComment({
    required String reelId,
    required String text,
    required String token, // auth token
  }) async {
    final res = await http.post(
      Uri.parse('${Api.baseUrl}/comments/$reelId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'text': text}),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to add comment');
    }

    return Comment.fromJson(jsonDecode(res.body));
  }
}
