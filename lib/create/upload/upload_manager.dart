import 'dart:io';
import 'package:http/http.dart' as http;

import '../../app/app_config.dart';
import '../../core/storage/token_storage.dart';

class UploadManager {
  /// =========================
  /// UPLOAD STORY
  /// =========================
  Future<void> uploadStory({
    required File file,
    String caption = '',
    void Function(double progress)? onProgress,
  }) async {
    final token = await TokenStorage.getAccessToken();

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/stories');

    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['caption'] = caption;

    request.files.add(
      await http.MultipartFile.fromPath(
        'media',
        file.path,
      ),
    );

    final streamed = await request.send();

    if (streamed.statusCode >= 400) {
      throw Exception('Story upload failed');
    }
  }

  /// =========================
  /// UPLOAD POST
  /// =========================
  Future<void> uploadPost({
    required List<File> media,
    required String caption,
    void Function(double progress)? onProgress,
  }) async {
    final token = await TokenStorage.getAccessToken();

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/posts');

    final request = http.MultipartRequest('POST', uri);

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['caption'] = caption;

    for (final file in media) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'media',
          file.path,
        ),
      );
    }

    final streamed = await request.send();

    if (streamed.statusCode >= 400) {
      throw Exception('Post upload failed');
    }
  }
}
