import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api/api.dart';

class CommentApi {
  static Future<List<dynamic>> getComments(String postId) async {
    final res = await http.get(
      Uri.parse('${Api.baseUrl}/comments/$postId'),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load comments');
    }

    return jsonDecode(res.body);
  }

  static Future<void> addComment(String postId, String text) async {
    await http.post(
      Uri.parse('${Api.baseUrl}/comments/$postId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );
  }
}
