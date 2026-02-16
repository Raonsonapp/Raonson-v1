import 'dart:io';
import '../core/api.dart';

class UploadApi {
  static Future<void> createPost({
    required String user,
    required String caption,
    required List<File> media, // ✅ media
  }) async {
    await Api.multipart(
      path: '/posts',
      fields: {
        'user': user,
        'caption': caption,
      },
      files: media,          // ✅
      fileField: 'media',
    );
  }

  static Future<void> createStory({
    required String user,
    required File media,
    required String mediaType,
  }) async {
    await Api.multipart(
      path: '/stories',
      fields: {
        'user': user,
        'mediaType': mediaType,
      },
      files: [media],
      fileField: 'media',
    );
  }
}
