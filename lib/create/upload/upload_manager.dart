import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../app/app_config.dart';
import '../../core/storage/token_storage.dart';

class UploadManager {
  Future<String?> _uploadFile(File file) async {
    final token = await TokenStorage.getAccessToken();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/upload');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final res = await request.send();
    final body = jsonDecode(await res.stream.bytesToString());

    if (res.statusCode >= 400) throw Exception('Upload failed: ${body['error']}');

    // url might be relative like /uploads/xxx.jpg - make it absolute
    String url = body['url'] as String? ?? '';
    if (url.startsWith('/')) {
      url = '${AppConfig.apiBaseUrl}$url';
    }
    return url;
  }

  String _mimeType(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    const videos = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
    return videos.contains(ext) ? 'video' : 'image';
  }

  Future<void> uploadPost({
    required List<File> media,
    required String caption,
    void Function(double)? onProgress,
  }) async {
    final token = await TokenStorage.getAccessToken();

    // Step 1: upload each file
    final List<Map<String, String>> mediaList = [];
    for (final file in media) {
      final url = await _uploadFile(file);
      if (url != null && url.isNotEmpty) {
        mediaList.add({'url': url, 'type': _mimeType(file)});
      }
    }
    if (mediaList.isEmpty) throw Exception('No media uploaded');

    // Step 2: create post with JSON
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/posts'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'caption': caption, 'media': mediaList}),
    );
    if (res.statusCode >= 400) {
      throw Exception('Post create failed: ${jsonDecode(res.body)['message']}');
    }
  }

  Future<void> uploadStory({
    required File file,
    String caption = '',
    void Function(double)? onProgress,
  }) async {
    final token = await TokenStorage.getAccessToken();

    // Step 1: upload file
    final url = await _uploadFile(file);
    if (url == null || url.isEmpty) throw Exception('Upload failed');

    // Step 2: create story with JSON
    final res = await http.post(
      Uri.parse('${AppConfig.apiBaseUrl}/stories'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'mediaUrl': url,
        'mediaType': _mimeType(file),
        'caption': caption,
      }),
    );
    if (res.statusCode >= 400) throw Exception('Story create failed');
  }
}
