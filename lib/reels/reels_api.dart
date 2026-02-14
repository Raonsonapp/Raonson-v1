import 'dart:convert';
import '../core/api.dart';
import '../models/reel_model.dart';

class ReelsApi {
  static Future<List<Reel>> fetchReels() async {
    final res = await Api.get("/reels");
    final data = jsonDecode(res.body);

    return data.map<Reel>((e) => Reel(
      id: e['id'],
      videoUrl: e['videoUrl'],
      caption: e['caption'],
      likes: e['likes'],
    )).toList();
  }

  static Future<void> view(String id) async {
    await Api.post("/reels/$id/view");
  }

  static Future<void> like(String id) async {
    await Api.post("/reels/$id/like");
  }
}
