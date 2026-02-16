import 'dart:io';
import '../core/api.dart';

class UploadApi {
  static Future<void> uploadPost({
    required String user,
    required String caption,
    required List<File> files,
    required List<String> types,
  }) async {
    await Api.multipart(
      '/posts',
      fields: {
        'user': user,
        'caption': caption,
      },
      files: files,
      fileField: 'media',
      extra: {
        'types': types,
      },
    );
  }
}
