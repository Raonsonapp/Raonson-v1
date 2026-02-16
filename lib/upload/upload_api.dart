import '../core/api.dart';

class UploadApi {
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

  static Future<void> createStory({
    required String user,
    required String mediaUrl,
    required String mediaType,
  }) async {
    await Api.post(
      '/stories',
      {
        'user': user,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType,
      },
    );
  }
}
