import '../core/api.dart';
import '../models/reel_model.dart';

class ReelsApi {
  static Future<List<Reel>> fetchReels() async {
    final data = await Api.get('/reels');

    return (data as List)
        .map((e) => Reel.fromJson(e))
        .toList();
  }

  static Future<void> like(String id) async {
    await Api.post('/reels/$id/like');
  }

  static Future<void> view(String id) async {
    await Api.post('/reels/$id/view');
  }
}
