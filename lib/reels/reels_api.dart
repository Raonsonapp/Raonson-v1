import '../models/reel_model.dart';

class ReelsApi {
  static Future<List<Reel>> getReels() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      Reel(
        id: '1',
        username: 'olivia_martin',
        caption: 'Sunset vibes 🌅',
        imageUrl: 'https://picsum.photos/800/1400?1',
      ),
      Reel(
        id: '2',
        username: 'alex_dev',
        caption: 'Night city ✨',
        imageUrl: 'https://picsum.photos/800/1400?2',
      ),
    ];
  }
}
