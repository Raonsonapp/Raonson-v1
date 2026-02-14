import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ReelsApi {
  static Future<List> fetchReels() async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/reels'),
    );
    return jsonDecode(res.body);
  }

  static Future<void> addView(String id) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/reels/$id/view'),
    );
  }

  static Future<void> like(String id) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/reels/$id/like'),
    );
  }

  static Future<List> getComments(String id) async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/comments/reels/$id'),
    );
    return jsonDecode(res.body);
  }

  static Future<void> addComment(String id, String text) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/comments/reels/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );
  }
}
