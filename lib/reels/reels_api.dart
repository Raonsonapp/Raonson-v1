import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';

class ReelsApi {
  static String get _base => Constants.baseUrl;

  // ======================
  // GET REELS FEED
  // ======================
  static Future<List<dynamic>> fetchReels() async {
    final res = await http.get(
      Uri.parse('$_base/reels'),
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load reels');
    }

    return jsonDecode(res.body);
  }

  // ======================
  // ADD VIEW
  // ======================
  static Future<void> addView(String reelId) async {
    await http.post(
      Uri.parse('$_base/reels/$reelId/view'),
    );
  }

  // ======================
  // LIKE (+1 MVP)
  // ======================
  static Future<void> like(String reelId) async {
    await http.post(
      Uri.parse('$_base/reels/$reelId/like'),
    );
  }

  // ======================
  // GET COMMENTS
  // ======================
  static Future<List<dynamic>> getComments(String reelId) async {
    final res = await http.get(
      Uri.parse('$_base/comments/reels/$reelId'),
    );

    if (res.statusCode != 200) {
      return [];
    }

    return jsonDecode(res.body);
  }

  // ======================
  // ADD COMMENT
  // ======================
  static Future<void> addComment(String reelId, String text) async {
    await http.post(
      Uri.parse('$_base/comments/reels/$reelId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );
  }

  // ======================
  // SAVE (MVP – LOCAL)
  // ======================
  static Future<void> save(String reelId) async {
    // MVP: backend надорад, баъдтар илова мекунем
    return;
  }

  // ======================
  // SHARE (MVP – UI ONLY)
  // ======================
  static Future<void> share(String reelId) async {
    // MVP: танҳо UI
    return;
  }
}
