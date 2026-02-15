import '../core/api.dart';

class UploadApi {
  static Future<void> uploadPost({
    required String caption,
    required List<Map<String, String>> media,
  }) async {
    await Api.post(
      '/posts',
      body: {
        'caption': caption,
        'media': media,
      },
    );
  }

  static Future<void> uploadReel({
    required String caption,
    required String videoUrl,
  }) async {
    await Api.post(
      '/reels',
      body: {
        'caption': caption,
        'videoUrl': videoUrl,
      },
    );
  }
}
