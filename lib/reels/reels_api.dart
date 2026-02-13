import '../models/reel_model.dart';

class ReelsApi {
  static Future<List<Reel>> getReels() async {
    await Future.delayed(const Duration(milliseconds: 400));

    return [
      Reel(
        id: '1',
        username: 'olivia_martin',
        caption: 'Sunset vibes 🌅',
        videoUrl:
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        likes: 0,
        liked: false,
      ),
      Reel(
        id: '2',
        username: 'alex_dev',
        caption: 'City night ✨',
        videoUrl:
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
        likes: 0,
        liked: false,
      ),
    ];
  }
}
