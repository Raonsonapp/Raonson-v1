import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/reel_model.dart';
import '../core/constants.dart';

class ReelsApi {
  // GET FEED
  static Future<List<Reel>> fetchReels() async {
    final res = await http.get(
      Uri.parse('${Constants.baseUrl}/reels'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Failed to load reels');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => Reel.fromJson(e)).toList();
  }

  // VIEW
  static Future<void> addView(String reelId) async {
    await http.post(
      Uri.parse('${Constants.baseUrl}/reels/$reelId/view'),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // LIKE
  static Future<int> like(String reelId) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/reels/$reelId/like'),
      headers: {'Content-Type': 'application/json'},
    );

    if (res.statusCode != 200) {
      throw Exception('Like failed');
    }

    final data = jsonDecode(res.body);
    return data['likes'];
  }

  // SAVE / UNSAVE
  static Future<bool> toggleSave(String reelId) async {
    final res = await http.post(
      Uri.parse('${Constants.baseUrl}/reels/$reelId/save'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user': 'guest'}),
    );

    if (res.statusCode != 200) {
      throw Exception('Save failed');
    }

    final data = jsonDecode(res.body);
    return data['saved'] == true;
  }
}
