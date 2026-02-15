import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class CommentApi {
  // GET COMMENTS
  static Future<List<dynamic>> fetchComments(String postId) async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/comments/$postId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load comments');
    }

    return jsonDecode(res.body);
  }

  // ADD COMMENT
  static Future<void> addComment(String postId, String text) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/comments/$postId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to add comment');
    }
  }
}
