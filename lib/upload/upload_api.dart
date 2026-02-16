import '../core/api.dart';

class UploadApi {
  // ================= CREATE POST =================
  static Future<void> createPost({
    required String user,
    required String caption,
    required List<Map<String, String>> media,
  }) async {
    await Api.post(
      '/posts',
      {
        'user': user,
        'caption': caption,
        'media': media,
      },
    );
  }

  // ================= CREATE REEL =================
  static Future<void> createReel({
    required String user,
    required String caption,
    required String videoUrl,
  }) async {
    await Api.post(
      '/reels',
      {
        'user': user,
        'caption': caption,
        'videoUrl': videoUrl,
      },
    );
  }
}
