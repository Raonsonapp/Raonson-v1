import '../core/api.dart';
import '../models/reel_model.dart';
import 'dart:convert';
import '../models/reel_model.dart';

class ReelsApi {
  static Future<List<Reel>> getReels() async {
    final res = await Api.get('/reels');

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Reel.fromJson(e)).toList();
    } else {
      throw Exception('Error loading reels');
  class ReelsApi {
  static Future<List<Reel>> getReels() async {
    // ⏱️ simulate network
    await Future.delayed(const Duration(milliseconds: 600));

    return [
      Reel(
        id: '1',
        videoUrl:
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        username: 'olivia_martin',
        avatar:
            'https://i.pravatar.cc/150?img=47',
        caption: 'Sunset vibes 🌅 #beachlife',
        likes: 1200000,
        comments: 56300,
        shares: 18700,
        liked: false,
      ),
      Reel(
        id: '2',
        videoUrl:
            'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4',
        username: 'ardamehr',
        avatar:
            'https://i.pravatar.cc/150?img=12',
        caption: 'Nature mood ✨',
        likes: 845000,
        comments: 23100,
        shares: 9200,
        liked: true,
      ),
    ];
  }
  }
