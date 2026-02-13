import '../core/api.dart';
import 'dart:convert';

class ReelsApi {
  static Future<List<dynamic>> getReels() async {
    final res = await Api.get('/reels');
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Reels load error');
  }

  static Future<void> likeReel(String reelId) async {
    await Api.post('/reels/$reelId/like');
  }
}
