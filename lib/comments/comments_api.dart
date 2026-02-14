import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import 'comment_model.dart';

class CommentsApi {
  static Future<List<Comment>> getComments(String reelId) async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/comments/$reelId'),
    );

    final List data = jsonDecode(res.body);
    return data.map((e) => Comment.fromJson(e)).toList();
  }

  static Future<void> addComment(
    String reelId,
    String text,
    String user,
  ) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/comments/$reelId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'user': user,
      }),
    );
  }
}
