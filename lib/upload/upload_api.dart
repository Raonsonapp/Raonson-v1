import '../core/api.dart';

class UploadApi {
  static Future<void> createPost({
    required String caption,
    required List<String> mediaUrls,
  }) async {
    await Api.post('/posts', body: {
      'caption': caption,
      'media': mediaUrls,
    });
  }
}
