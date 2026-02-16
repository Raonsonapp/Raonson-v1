import '../core/api.dart';

class UploadApi {
  // ================= CREATE POST =================
  static Future<void> createPost({
    required String user,
    required String caption,
    required List<Map<String, String>> media, // ✅ FIXED
  }) async {
    await Api.post(
      '/posts',
      body: {
        'user': user,
        'caption': caption,
        'media': media, // [{url, type}]
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
      body: {
        'user': user,
        'caption': caption,
        'videoUrl': videoUrl,
      },
    );
  }
}
