import 'dart:convert';
import '../core/api.dart';

class UploadApi {
  static Future<void> uploadPost({
    required String caption,
    required String mediaUrl,
    required String mediaType, // image | video
  }) async {
    await Api.post('/posts', body: {
      'caption': caption,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
    });
  }

  static Future<void> uploadReel({
    required String caption,
    required String videoUrl,
  }) async {
    await Api.post('/reels', body: {
      'caption': caption,
      'videoUrl': videoUrl,
    });
  }
}
