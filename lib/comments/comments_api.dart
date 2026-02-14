import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class CommentsApi {
  static Future<List<dynamic>> fetchComments(String reelId) async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/comments/$reelId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load comments');
    }

    return jsonDecode(res.body);
  }

  static Future<void> addComment(String reelId, String text) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/comments/$reelId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Failed to add comment');
    }
  }
}
