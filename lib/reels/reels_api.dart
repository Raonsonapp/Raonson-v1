import 'dart:convert';
import '../core/api.dart';
import '../models/reel_model.dart';

class ReelsApi {
  static Future<void> view(String reelId) async {
    await Api.post('/reels/$reelId/view');
  }

  static Future<void> like(String reelId) async {
    await Api.post('/reels/$reelId/like');
  }
}
class ReelsApi {
  static Future<List<Reel>> fetchReels() async {
    final res = await Api.get("/reels");
    final List data = jsonDecode(res.body);

    return data.map<Reel>((e) => Reel(
      id: e['id'],
      videoUrl: e['videoUrl'],
      caption: e['caption'] ?? '',
      likes: e['likes'] ?? 0,
      views: e['views'] ?? 0,
    )).toList();
  }

  static Future<void> addView(String id) async {
    await Api.post("/reels/$id/view");
  }

  static Future<void> like(String id) async {
    await Api.post("/reels/$id/like");
  }
}
