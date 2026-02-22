import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../app/app_config.dart';
import '../../core/storage/token_storage.dart';

class UploadManager {
  /// Step 1: Upload file to /upload -> returns URL
  Future<String> _uploadFile(File file) async {
    final token = await TokenStorage.getAccessToken();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/upload');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamed = await request.send();
    final body = jsonDecode(await streamed.stream.bytesToString());

    if (streamed.statusCode >= 400) {
      throw Exception('Upload failed: ${body['error'] ?? streamed.statusCode}');
    }

    String url = (body['url'] ?? '') as String;
    if (url.startsWith('/')) {
      url = '${AppConfig.apiBaseUrl}$url';
    }
    return url;
  }

  String _mediaType(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    return ['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)
        ? 'video'
        : 'image';
  }

  /// Upload post: file(s) -> /upload -> POST /posts JSON
  Future<void> uploadPost({
    required List<File> media,
    required String caption,
    void Function(double)? onProgress,
  }) async {
    final token = await TokenStorage.getAccessToken();

    // Upload each file and collect URLs
    final List<Map<String, String>> mediaList = [];
    for (int i = 0; i < media.length; i++) {
      final url = await _uploadFile(media[i]);
      mediaList.add({'url': url, 'type': _mediaType(media[i])});
      onProgress?.call((i + 1) / media.length * 0.8);
    }

    if (mediaList.isEmpty) throw Exception('Файл upload нашуд');

    // Create post with JSON
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/posts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'caption': caption, 'media': mediaList}),
    );

    onProgress?.call(1.0);

    if (res.statusCode >= 400) {
      final err = jsonDecode(res.body)['message'] ?? 'Post failed';
      throw Exception(err);
    }
  }

  /// Upload story: file -> /upload -> POST /stories JSON
  Future<void> uploadStory({
    required File file,
    String caption = '',
    void Function(double)? onProgress,
  }) async {
    final token = await TokenStorage.getAccessToken();

    final url = await _uploadFile(file);
    onProgress?.call(0.7);

    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/stories'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'mediaUrl': url,
        'mediaType': _mediaType(file),
        'caption': caption,
      }),
    );

    onProgress?.call(1.0);

    if (res.statusCode >= 400) {
      throw Exception('Story failed: ${jsonDecode(res.body)['message']}');
    }
  }
}
