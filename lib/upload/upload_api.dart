import 'dart:io';
import '../core/api.dart';

class UploadApi {
  static Future<void> createPost({
    required String user,
    required String caption,
    required List<File> files,
  }) async {
    await Api.multipart(
      path: '/posts',
      fields: {
        'user': user,
        'caption': caption,
      },
      files: files,
      fileField: 'media',
    );
  }

  static Future<void> createStory({
    required String user,
    required File file,
    required String mediaType,
  }) async {
    await Api.multipart(
      path: '/stories',
      fields: {
        'user': user,
        'mediaType': mediaType,
      },
      files: [file],
      fileField: 'media',
    );
  }
}
