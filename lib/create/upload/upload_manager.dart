import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../app/app_config.dart';
import '../../core/storage/token_storage.dart';

class UploadManager {
  String _ext(File file) =>
      file.path.split('.').last.toLowerCase();

  MediaType _contentType(File file) {
    final ext = _ext(file);
    const videos = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
    if (videos.contains(ext)) return MediaType('video', 'mp4');
    if (ext == 'png') return MediaType('image', 'png');
    return MediaType('image', 'jpeg');
  }

  String _typeStr(File file) {
    const videos = ['mp4', 'mov', 'avi', 'mkv', 'webm'];
    return videos.contains(_ext(file)) ? 'video' : 'image';
  }

  Future<String> _uploadFile(File file) async {
    final token = await TokenStorage.getAccessToken();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/upload');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    // Explicit content-type prevents "Unsupported media type" error
    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: _contentType(file),
    ));

    final streamed = await request.send();
    final bodyStr = await streamed.stream.bytesToString();
    final body = jsonDecode(bodyStr);

    if (streamed.statusCode >= 400) {
      throw Exception('Upload failed: ${body['error'] ?? streamed.statusCode}');
    }

    String url = (body['url'] ?? '') as String;
    if (url.startsWith('/')) url = '${AppConfig.apiBaseUrl}$url';
    return url;
  }

  Future<void> uploadPost({
    required List<File> media,
    required String caption,
    void Function(double)? onProgress,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final List<Map<String, String>> mediaList = [];

    for (int i = 0; i < media.length; i++) {
      final url = await _uploadFile(media[i]);
      mediaList.add({'url': url, 'type': _typeStr(media[i])});
      onProgress?.call((i + 1) / media.length * 0.8);
    }

    if (mediaList.isEmpty) throw Exception('Файл upload нашуд');

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
      throw Exception(jsonDecode(res.body)['message'] ?? 'Post failed');
    }
  }

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
        'mediaType': _typeStr(file),
        'caption': caption,
      }),
    );

    onProgress?.call(1.0);
    if (res.statusCode >= 400) {
      throw Exception('Story failed: ${jsonDecode(res.body)['message']}');
    }
  }
}
