import '../core/api.dart';

class UploadApi {
  static Future<void> createPost({
    required String caption,
    required List<Map<String, String>> media,
  }) async {
    await Api.post(
      '/posts',
      body: {
        'user': 'raonson',
        'caption': caption,
        'media': media,
      },
    );
  }
}
