import '../core/api.dart';

class UploadApi {
  static Future<void> createPost({
    required String caption,
    required List<Map<String, String>> media,
  }) async {
    await Api.post(
      '/posts',
      {
        'caption': caption,
        'media': media,
      },
    );
  }

  static Future<void> createStory({
    required String mediaUrl,
    required String mediaType,
  }) async {
    await Api.post(
      '/stories',
      {
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
      },
    );
  }
}
