import 'dart:convert';
import 'package:http/http.dart' as http;

class CommentApi {
  static const baseUrl = 'https://YOUR_RENDER_URL';

  static Future<List<dynamic>> fetchComments(String postId) async {
    final res = await http.get(Uri.parse('$baseUrl/comments/$postId'));
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Comments load failed');
  }

  static Future<void> addComment(String postId, String text) async {
    await http.post(
      Uri.parse('$baseUrl/comments/$postId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user': 'raonson',
        'text': text,
      }),
    );
  }
}
