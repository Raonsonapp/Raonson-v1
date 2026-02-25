import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../app/app_config.dart';
import '../../core/storage/token_storage.dart';

class UploadManager {
  // Cloudinary direct upload (no backend needed!)
  static const _cloudName = 'dtp3kzqxi';
  static const _uploadPreset = 'raonson_preset'; // Create this in Cloudinary!

  String _ext(File file) => file.path.split('.').last.toLowerCase();

  bool _isVideo(File file) {
    const videos = ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'];
    return videos.contains(_ext(file));
  }

  String _typeStr(File file) => _isVideo(file) ? 'video' : 'image';

  MediaType _contentType(File file) {
    final ext = _ext(file);
    const videos = ['mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'];
    if (videos.contains(ext)) return MediaType('video', 'mp4');
    if (ext == 'png') return MediaType('image', 'png');
    return MediaType('image', 'jpeg');
  }

  /// Upload directly to Cloudinary (most reliable!)
  Future<String> _uploadToCloudinary(File file) async {
    final resourceType = _isVideo(file) ? 'video' : 'image';
    final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$_cloudName/$resourceType/upload');

    final request = http.MultipartRequest('POST', uri);
    request.fields['upload_preset'] = _uploadPreset;
    request.fields['folder'] = 'raonson';

    request.files.add(await http.MultipartFile.fromPath(
      'file',
      file.path,
      contentType: _contentType(file),
    ));

    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final bodyStr = await streamed.stream.bytesToString();

    if (streamed.statusCode >= 400) {
      // Fallback to backend upload
      return await _uploadToBackend(file);
    }

    final body = jsonDecode(bodyStr);
    final url = body['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      return await _uploadToBackend(file);
    }
    return url;
  }

  /// Fallback: upload via backend
  Future<String> _uploadToBackend(File file) async {
    final token = await TokenStorage.getAccessToken();
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/upload');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    request.files.add(await http.MultipartFile.fromPath(
      'file', file.path,
      contentType: _contentType(file),
    ));

    final streamed = await request.send().timeout(const Duration(seconds: 120));
    final bodyStr = await streamed.stream.bytesToString();
    final body = jsonDecode(bodyStr);

    if (streamed.statusCode >= 400) {
      throw Exception('Upload failed: ${body['error'] ?? streamed.statusCode}');
    }

    String url = (body['url'] ?? '') as String;
    if (url.isEmpty) throw Exception('Upload returned empty URL');
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
      final url = await _uploadToCloudinary(media[i]);
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
    ).timeout(const Duration(seconds: 60));

    onProgress?.call(1.0);
    if (res.statusCode >= 400) {
      final err = jsonDecode(res.body);
      throw Exception(err['message'] ?? 'Post yaratish xato');
    }
  }

  Future<void> uploadStory({
    required File file,
    String caption = '',
    void Function(double)? onProgress,
  }) async {
    final token = await TokenStorage.getAccessToken();
    final url = await _uploadToCloudinary(file);
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
    ).timeout(const Duration(seconds: 60));

    onProgress?.call(1.0);
    if (res.statusCode >= 400) {
      throw Exception('Story: ${jsonDecode(res.body)['message']}');
    }
  }
}
