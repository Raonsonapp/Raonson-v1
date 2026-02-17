import 'dart:io';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../../core/storage/token_storage.dart';

class UploadManager {
  final Dio _dio = ApiClient.instance.dio;
  final TokenStorage _tokenStorage = TokenStorage();

  /// =========================
  /// UPLOAD STORY
  /// =========================
  Future<void> uploadStory({
    required File file,
    String caption = '',
    void Function(double progress)? onProgress,
  }) async {
    final token = await _tokenStorage.getAccessToken();

    final formData = FormData.fromMap({
      'caption': caption,
      'media': await MultipartFile.fromFile(
        file.path,
        filename: file.uri.pathSegments.last,
      ),
    });

    await _dio.post(
      '/stories',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );
  }

  /// =========================
  /// UPLOAD POST
  /// =========================
  Future<void> uploadPost({
    required List<File> media,
    required String caption,
    void Function(double progress)? onProgress,
  }) async {
    final token = await _tokenStorage.getAccessToken();

    final files = <MultipartFile>[];
    for (final file in media) {
      files.add(
        await MultipartFile.fromFile(
          file.path,
          filename: file.uri.pathSegments.last,
        ),
      );
    }

    final formData = FormData.fromMap({
      'caption': caption,
      'media': files,
    });

    await _dio.post(
      '/posts',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );
  }
}
