import '../models/reel_model.dart';

class ReelsApi {
  static Future<List<Reel>> getReels() async {
    await Future.delayed(const Duration(milliseconds: 300));

    return [
      Reel(id: '1', user: 'olivia_martin', caption: 'Sunset vibes 🌅'),
      Reel(id: '2', user: 'raonson', caption: 'My first reel 🔥'),
      Reel(id: '3', user: 'flutter_dev', caption: 'UI test 😎'),
    ];
  }
}
