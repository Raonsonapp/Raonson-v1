import '../core/api.dart';
import '../models/reel_model.dart';

class ReelsApi {
  static Future<List<Reel>> fetchReels() async {
    final data = await Api.get('/reels');
    return data.map<Reel>((e) => Reel.fromJson(e)).toList();
  }

  static Future<void> addView(String reelId) async {
    await Api.post('/reels/view/$reelId');
  }

  static Future<void> likeReel(String reelId, String token) async {
    await Api.post('/reels/like/$reelId', token: token);
  }
}
