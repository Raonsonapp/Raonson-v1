import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/api.dart';
import '../core/token_storage.dart';
import 'comment_model.dart';

class CommentApi {
  static Future<List<Comment>> getComments(String postId) async {
    final token = await TokenStorage.read();

    final res = await http.get(
      Uri.parse('${Api.baseUrl}/comments/$postId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    final data = jsonDecode(res.body) as List;
    return data.map((e) => Comment.fromJson(e)).toList();
  }

  static Future<void> addComment(String postId, String text) async {
    final token = await TokenStorage.read();

    await http.post(
      Uri.parse('${Api.baseUrl}/comments/$postId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'text': text}),
    );
  }
}
