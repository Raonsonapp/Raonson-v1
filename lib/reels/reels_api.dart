import 'dart:convert';
import '../core/api.dart';
import '../models/reel_model.dart';

class ReelsApi {
  // 🔹 GET REELS FEED
  static Future<List<Reel>> fetchReels() async {
    final res = await Api.get('/reels');

    final List data = jsonDecode(res.body);

    return data.map<Reel>((e) {
      return Reel(
        id: e['id'].toString(),
        username: e['username'] ?? 'user',
        caption: e['caption'] ?? '',
        videoUrl: e['videoUrl'],
        likes: e['likes'] ?? 0,
        views: e['views'] ?? 0,
        liked: false,
      );
    }).toList();
  }

  // 🔹 ADD VIEW
  static Future<void> view(String reelId) async {
    await Api.post('/reels/$reelId/view');
  }

  // 🔹 LIKE
  static Future<int> like(String reelId) async {
    final res = await Api.post('/reels/$reelId/like');
    final data = jsonDecode(res.body);
    return data['likes'];
  }
}
